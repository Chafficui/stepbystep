import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../state/session_store.dart';

/// Beobachtet den Akkustand, cached den aktuellen Prozentwert und warnt
/// einmalig unter 20 % und einmalig unter 10 % (per lokale Benachrichtigung).
///
/// Der gecachte Wert wird vom TrackingService für jeden GPS-Punkt
/// mitgeschrieben (nicht-blockierend — kein await auf den Plattform-Call).
class BatteryMonitor {
  BatteryMonitor({
    required SessionStore sessionStore,
    FlutterLocalNotificationsPlugin? notifications,
    Future<int?> Function()? readLevel,
  })  : _session = sessionStore,
        _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
        _readLevel = readLevel;

  final SessionStore _session;
  final FlutterLocalNotificationsPlugin _notifications;

  /// Plattform-Call, der den Akkustand liefert (injectierbar für Tests).
  final Future<int?> Function()? _readLevel;

  Battery? _battery;
  StreamSubscription<BatteryState>? _sub;
  final StreamController<int?> _changes = StreamController<int?>.broadcast();

  int? _percent;
  bool _warn20 = false;
  bool _warn10 = false;

  /// Aktueller Akkustand in Prozent (null = noch nicht bekannt).
  int? get currentPercent => _percent;

  /// Stream der Akkustand-Änderungen (auch der erste bekannte Wert).
  Stream<int?> get changes => _changes.stream;

  /// Muss einmal beim App-Start aufgerufen werden (Plugin-Init + Listener).
  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Bereits gezeigte Warnungen wiederherstellen (jede Stufe nur EINMAL).
    _warn20 = await _session.getBatteryWarn20Shown();
    _warn10 = await _session.getBatteryWarn10Shown();

    final reader = _readLevel ?? _readBatteryLevel;
    _percent = await reader();
    if (_percent != null) _changes.add(_percent);

    _battery = Battery();
    _sub = _battery!.onBatteryStateChanged.listen((_) async {
      final level = await (reader)();
      if (level == null || level == _percent) return;
      _percent = level;
      _changes.add(_percent);
      await _maybeWarn(level);
    });
  }

  /// Holt den Akkustand; bei Plattform-Fehlern wird null geliefert
  /// (kein Crash, Punkt wird dann ohne Akkustand gespeichert).
  Future<int?> _readBatteryLevel() async {
    try {
      return await _battery?.batteryLevel;
    } catch (e) {
      debugPrint('batteryLevel fehlgeschlagen (ohne Details): $e');
      return null;
    }
  }

  /// Aktuellen Stand holen und ggf. warnen (auch ohne State-Änderung nutzbar).
  Future<int?> refresh() async {
    final level = await (_readLevel ?? _readBatteryLevel)();
    if (level != null && level != _percent) {
      _percent = level;
      _changes.add(_percent);
    }
    if (level != null) await _maybeWarn(level);
    return _percent;
  }

  Future<void> _maybeWarn(int percent) async {
    if (percent < 10 && !_warn10) {
      _warn10 = true;
      await _session.setBatteryWarn10Shown(true);
      await _show('Akkustand unter 10%', 'Fast keine Energie mehr – '
          'bitte sofort laden, sonst endet die Aufzeichnung!');
    } else if (percent < 20 && !_warn20) {
      _warn20 = true;
      await _session.setBatteryWarn20Shown(true);
      await _show(
          'Akkustand unter 20%', 'Akkustand unter 20% – Ladegerät suchen.');
    }
  }

  Future<void> _show(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'battery',
        'Akkustand',
        channelDescription: 'Warnungen bei niedrigem Akkustand',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _notifications.show(1001, title, body, details);
    } catch (e) {
      // Benachrichtigungen sind optional; niemals für einen Crash sorgen.
      debugPrint('Benachrichtigung fehlgeschlagen: $e');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _battery = null;
    await _changes.close();
  }
}
