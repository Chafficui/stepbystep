import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/slot_calc.dart';
import '../models/event_config.dart';
import '../state/session_store.dart';

/// Lokale Check-in-Erinnerungen (Benachrichtigungen zum Check-in-Fenster).
///
/// - Initialisierung mit Zeitzonen-Setup (`tz.initializeTimeZones()`) und
///   Android-Channel „Erinnerungen".
/// - `scheduleReminders` plant für jeden Zeitpunkt aus `reminderTimes()`
///   eine Benachrichtigung (vergangene Zeitpunkte werden übersprungen).
/// - `syncWithConfig` vergleicht einen Fingerprint der relevanten
///   Event-Felder mit dem letzten Stand (shared prefs) und plant nur bei
///   Änderung neu — wird bei jedem (Re-)Fetch der Event-Konfig aufgerufen.
class ReminderScheduler {
  ReminderScheduler({FlutterLocalNotificationsPlugin? plugin, SessionStore? session})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _session = session ?? SessionStore();

  static const String channelId = 'checkin_reminders';
  static const String channelName = 'Erinnerungen';

  final FlutterLocalNotificationsPlugin _plugin;
  final SessionStore _session;
  bool _initialized = false;

  /// Muss vor dem ersten schedule/cancel aufgerufen werden.
  Future<void> init() async {
    if (_initialized) return;
    await _initTimezone();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'Erinnerungen an fällige Check-ins',
      importance: Importance.high,
    ));
    // Berechtigung anfragen (Onboarding fragt ebenfalls, aber hier zusätzlich
    // absichern, falls das Onboarding übersprungen wurde).
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> _initTimezone() async {
    tzdata.initializeTimeZones();
    try {
      final dynamic info = await FlutterTimezone.getLocalTimezone();
      final String name =
          info is String ? info : ((info.name as String?) ?? info.toString());
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fallback: UTC (Erinnerungen wären dann verschoben, aber funktional).
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  /// Alle fälligen Check-in-Erinnerungen planen (alte zuerst löschen).
  Future<void> scheduleReminders(EventConfig event) async {
    await init();
    await cancelAll();
    final now = DateTime.now().toUtc();
    final times = SlotCalc.reminderTimes(event);
    var id = 0;
    for (final time in times) {
      // Vergangene Zeitpunkte würden sofort feuern -> überspringen.
      if (!time.isAfter(now)) continue;
      id++;
      await _plugin.zonedSchedule(
        id,
        'Check-in fällig',
        'Check-in fällig: Foto oder Video schicken!',
        tz.TZDateTime.from(time, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: 'Erinnerungen an fällige Check-ins',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Alle geplanten Erinnerungen löschen (z. B. wenn das Event beendet ist).
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Fingerprint der relevanten Event-Felder; replant nur bei Änderung.
  /// Wird bei jedem (Re-)Fetch der Event-Konfig aufgerufen.
  Future<void> syncWithConfig(EventConfig event) async {
    final fingerprint = jsonEncode({
      'name': event.name,
      'start_time': event.startTime.toIso8601String(),
      'end_time': event.endTime.toIso8601String(),
      'interval': event.checkinIntervalMin,
      'times':
          SlotCalc.reminderTimes(event).map((t) => t.toIso8601String()).toList(),
    });
    final stored = await _session.getReminderFingerprint();
    if (stored == fingerprint) return;
    await scheduleReminders(event);
    await _session.setReminderFingerprint(fingerprint);
  }
}
