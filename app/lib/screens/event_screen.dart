import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../db/app_database.dart';
import '../models/event_config.dart';
import '../services/reminder_scheduler.dart';
import '../state/services.dart';
import '../state/session_store.dart';
import '../tracking/tracking_controller.dart';
import '../tracking/tracking_service.dart';
import '../tracking/upload_service.dart';
import 'checkin_screen.dart';
import 'end_screen.dart';
import 'map_screen.dart';
import 'rank_screen.dart';

/// Wartezimmer + laufendes Event (Shell).
///
/// Countdown zu reveal/start (Serverzeiten, lokal angezeigt),
/// Verbindungsstatus, Uhren-Drift-Warnung und „Tracking starten/stoppen"
/// (echter TrackingService), Upload-Status und Stale-Warnung.
class EventScreen extends StatefulWidget {
  const EventScreen({
    super.key,
    required this.sessionStore,
    this.tracking,
    this.upload,
    this.battery,
  });

  final SessionStore sessionStore;

  /// Optional injizierbar (Tests); default: [AppServices.instance].
  final TrackingController? tracking;
  final UploadService? upload;
  final BatteryStatusSource? battery;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

/// Minimal-Interface für den Akkustand (für Tests ersetzbar).
abstract class BatteryStatusSource {
  int? get currentPercent;
}

/// Adapter auf den echten BatteryMonitor.
class _BatteryAdapter implements BatteryStatusSource {
  const _BatteryAdapter();

  @override
  int? get currentPercent => AppServices.instance.battery.currentPercent;
}

class _EventScreenState extends State<EventScreen> {
  final ApiClient _api = ApiClient();
  TrackingController get _tracking =>
      widget.tracking ?? AppServices.instance.tracking;
  UploadService get _upload => widget.upload ?? AppServices.instance.upload;
  BatteryStatusSource get _battery =>
      widget.battery ?? const _BatteryAdapter();

  Timer? _ticker;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<TrackingState>? _trackingSub;
  StreamSubscription<UploadStats>? _statsSub;

  final ReminderScheduler _reminders = ReminderScheduler();
  int _selectedTab = 0;

  /// Zuletzt ausgelöster SOS-/Abbruch-Alarm (für den Status-Text).
  String? _lastAlertId;
  bool? _lastAlertSent;

  EventConfig? _config;
  String? _error;
  bool _online = true;
  TrackingState _trackingState = const TrackingState.stopped();
  UploadStats _stats = const UploadStats(
      unsentPoints: 0, unsentAlerts: 0, unsentCheckins: 0);

  @override
  void initState() {
    super.initState();
    _loadEvent();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      _checkLastAlertSent();
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(
          () => _online = !results.contains(ConnectivityResult.none));
    });
    _trackingSub = _tracking.state.listen((s) {
      if (mounted) setState(() => _trackingState = s);
    });
    _statsSub = _upload.stats.listen((s) {
      if (mounted) setState(() => _stats = s);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _connectivitySub?.cancel();
    _trackingSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadEvent() async {
    try {
      final token = await widget.sessionStore.token;
      final json = await _api.getEvent(token);
      if (!mounted) return;
      final config = EventConfig.fromJson(json);
      setState(() => _config = config);
      // Check-in-Erinnerungen bei jedem (Re-)Fetch neu synchronisieren;
      // nach Event-Ende alle geplanten Erinnerungen löschen.
      try {
        if (config.isOver(DateTime.now())) {
          await _reminders.cancelAll();
        } else {
          await _reminders.syncWithConfig(config);
        }
      } catch (_) {
        // Erinnerungen sind optional — App funktioniert ohne weiter.
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Verbindung fehlgeschlagen.');
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _localTime(DateTime utc) =>
      DateFormat('dd.MM. HH:mm').format(utc.toLocal());

  /// Letzter erfolgreicher Upload, lokal als HH:mm (oder „noch keine").
  String _lastUploadLabel() {
    final t = _stats.lastSuccessAt;
    if (t == null) return 'Letzter Upload: noch keine';
    return 'Letzter Upload: ${DateFormat('HH:mm').format(t.toLocal())}';
  }

  /// Stale-Warnung: Tracking aktiv, aber > 10 min kein neuer Punkt.
  bool get _staleTracking {
    if (_trackingState.kind != TrackingStateKind.running) return false;
    final last = _tracking is TrackingService
        ? (_tracking as TrackingService).lastPointAt
        : null;
    if (last == null) return false;
    return DateTime.now().toUtc().difference(last.toUtc()) >
        const Duration(minutes: 10);
  }

  String get _trackingStatusLabel {
    final s = _trackingState;
    switch (s.kind) {
      case TrackingStateKind.running:
        return 'Tracking aktiv';
      case TrackingStateKind.stopped:
        return 'Tracking pausiert';
      case TrackingStateKind.error:
        return 'Fehler: ${s.message ?? 'unbekannt'}';
    }
  }

  Future<void> _toggleTracking() async {
    final granted = await _checkLocationAlways();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Standort „Immer" fehlt – Tracking deaktiviert.')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (_trackingState.kind == TrackingStateKind.running) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tracking beenden'),
          content: const Text(
              'Soll die Aufzeichnung wirklich beendet werden? Bereits '
              'gesammelte Punkte bleiben lokal erhalten.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Beenden')),
          ],
        ),
      );
      if (confirm == true) await _tracking.stop();
    } else {
      await _tracking.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final now = DateTime.now();

    // Uhren-Drift-Warnung: |deviceNow - server_now| > 60 s.
    final driftWarning =
        config != null && config.serverDrift(now).abs() > const Duration(seconds: 60);

    final waiting = config != null &&
        (config.isBeforeReveal(now) ||
            (config.isRunning(now) &&
                now.toUtc().isBefore(config.startTime.toUtc())));

    final running = _trackingState.kind == TrackingStateKind.running;
    final over = config != null && config.isOver(now);

    // Tab-Inhalt: Event-Status (Start-Tab), Karte, Check-in, Rangliste.
    Widget tabContent;
    switch (_selectedTab) {
      case 1:
        tabContent = MapScreen(
          config: config,
          tracking:
              _tracking is TrackingService ? _tracking as TrackingService : null,
        );
        break;
      case 2:
        tabContent = config == null
            ? const Center(child: CircularProgressIndicator())
            : CheckinScreen(config: config, upload: _upload);
        break;
      case 3:
        tabContent = const RankScreen();
        break;
      default:
        tabContent = RefreshIndicator(
          onRefresh: _loadEvent,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red)),
                ),
              if (driftWarning)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: Colors.amber,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          '⚠️ Uhrzeit des Handys prüfen – sie weicht deutlich '
                          'von der Serverzeit ab.'),
                    ),
                  ),
                ),
              if (_staleTracking)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: Colors.red,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          '⚠️ Seit 10 Minuten kein neuer Punkt – Tracking '
                          'prüfen!',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              if (config == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (over) ...[
                  // Ende-Banner + Abschluss-Seite (inline). Tracking läuft
                  // bewusst weiter (Daten für die Abholung).
                  const Card(
                    color: Colors.deepOrange,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          '🏁 Das Event ist beendet. Danke fürs Mitmachen!',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  EndScreenBody(tracking: _tracking, isRunning: running),
                ] else ...[
                  if (config.isBeforeReveal(now))
                    _CountdownCard(
                      title: 'Enthüllung der Route in',
                      target: config.revealTime,
                      fmt: _fmt,
                      subtitle:
                          'Enthüllung: ${_localTime(config.revealTime)}',
                    )
                  else if (now.toUtc()
                      .isBefore(config.startTime.toUtc()))
                    _CountdownCard(
                      title: 'Start in',
                      target: config.startTime,
                      fmt: _fmt,
                      subtitle: 'Start: ${_localTime(config.startTime)}',
                    )
                  else
                    _CountdownCard(
                      title: 'Event endet in',
                      target: config.endTime,
                      fmt: _fmt,
                      subtitle: 'Ende: ${_localTime(config.endTime)}',
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Check-ins: alle ${config.checkinIntervalMin} Minuten '
                    '(Fenster ${config.checkinWindowMin} Min). '
                    'Orga-Telefon: ${config.orgaPhone}',
                  ),
                  const SizedBox(height: 16),
                  if (waiting || config.isRunning(now))
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                      ),
                      icon: Icon(running ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        running ? 'Tracking stoppen' : 'Tracking starten',
                        style: const TextStyle(fontSize: 20),
                      ),
                      onPressed: _toggleTracking,
                    ),
                ],
              ],
            ],
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(config?.name ?? 'Event'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _online ? Icons.wifi : Icons.wifi_off,
              color: _online ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: tabContent),
          // Immer sichtbar: Status-Karte und SOS-Bereich.
          _persistentStatusArea(config, over, running),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.event), label: 'Event'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Karte'),
          NavigationDestination(
              icon: Icon(Icons.photo_camera), label: 'Check-in'),
          NavigationDestination(
              icon: Icon(Icons.leaderboard), label: 'Rangliste'),
        ],
      ),
    );
  }

  /// Immer sichtbarer Bereich unter dem Tab-Inhalt: Status-Karte
  /// (Tracking/Upload/Akku) und der SOS-/Abbruch-Bereich.
  Widget _persistentStatusArea(EventConfig? config, bool over, bool running) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_trackingStatusLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      'Ungesendete Punkte: ${_stats.unsentPoints} · '
                      'Alarme: ${_stats.unsentAlerts} · '
                      'Check-ins: ${_stats.unsentCheckins}'),
                  const SizedBox(height: 4),
                  Text(_lastUploadLabel()),
                  if (_battery.currentPercent != null)
                    Text('Akkustand: ${_battery.currentPercent}%'),
                ],
              ),
            ),
          ),
          _sosArea(config),
        ],
      ),
    );
  }

  /// SOS-Bereich: Hint, Halte-Button (2 s) und Abbruch-Button mit
  /// Statuszeile. Schreibt IMMER zuerst lokal (offline-fähig).
  Widget _sosArea(EventConfig? config) {
    String? statusText;
    if (_lastAlertId != null) {
      statusText = (_lastAlertSent ?? false)
          ? 'SOS gesendet'
          : 'SOS gespeichert – wird gesendet, sobald Netz da ist';
    }
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              'Bei akuter Gefahr zuerst 112 anrufen!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _HoldToTriggerButton(
                    onTriggered: () => _triggerAlert('sos'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    icon: const Icon(Icons.flag),
                    label: const Text('Aufgeben und\nabholen lassen',
                        textAlign: TextAlign.center),
                    onPressed: _abort,
                  ),
                ),
              ],
            ),
            if (statusText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(statusText,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (_lastAlertSent ?? false)
                            ? Colors.green
                            : Colors.orange)),
              ),
          ],
        ),
      ),
    );
  }

  /// Prüft, ob der zuletzt ausgelöste Alarm bereits gesendet wurde
  /// (Statuszeile: „SOS gesendet" vs. „wird gesendet, sobald Netz da ist").
  Future<void> _checkLastAlertSent() async {
    final id = _lastAlertId;
    if (id == null || _lastAlertSent == true) return;
    final db = AppServices.instance.db;
    final row =
        await (db.select(db.pendingAlerts)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    final sent = row?.sentAt != null;
    if (mounted && sent != _lastAlertSent) {
      setState(() => _lastAlertSent = sent);
    }
  }

  /// SOS/Abbruch: ZUERST lokal in die Queue (funktioniert offline), dann
  /// sofortiger Upload-Versuch; bei SOS zusätzlich den Orga-Wähl-Dialog
  /// öffnen. Der Upload-Service sendet Alarme vor Punkten.
  Future<void> _triggerAlert(String type) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();

    // Letzte bekannte Position: Rohposition, sonst letzter DB-Punkt.
    double lat = 0.0;
    double lng = 0.0;
    final tracking = _tracking;
    final raw = tracking is TrackingService ? tracking.lastRawPosition : null;
    if (raw != null) {
      lat = raw.latitude;
      lng = raw.longitude;
    } else {
      final last = await AppServices.instance.db.lastPoint();
      if (last != null) {
        lat = last.lat;
        lng = last.lng;
      }
    }

    await AppServices.instance.db.insertAlert(PendingAlertsCompanion.insert(
      id: id,
      type: type,
      lat: lat,
      lng: lng,
      createdAt: now.millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    setState(() {
      _lastAlertId = id;
      _lastAlertSent = null;
    });
    unawaited(_upload.flushNow());

    final phone = _config?.orgaPhone;
    if (type == 'sos' && phone != null && phone.isNotEmpty) {
      try {
        await launchUrl(
          Uri.parse('tel:$phone'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        // Dialer nicht verfügbar — Alarm ist trotzdem lokal gespeichert.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Wähl-App konnte nicht geöffnet werden.')),
          );
        }
      }
    }
  }

  Future<void> _abort() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aufgeben?'),
        content: const Text(
            'Wirklich aufgeben und abholen lassen? Die Orga wird '
            'informiert und deine Position übermittelt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aufgeben')),
        ],
      ),
    );
    if (confirm == true) await _triggerAlert('abort');
  }

  Future<bool> _checkLocationAlways() async {
    // Blocker-Prüfung: Tracking-Button bleibt ohne „Immer" deaktiviert.
    final status = await Permission.locationAlways.status;
    return status.isGranted;
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.title,
    required this.target,
    required this.fmt,
    required this.subtitle,
  });

  final String title;
  final DateTime target;
  final String Function(Duration) fmt;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final remaining = target.toLocal().difference(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              remaining.isNegative ? 'Jetzt!' : fmt(remaining),
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

/// SOS-Halte-Button: Auslösen erst nach 2 Sekunden Halten. Loslassen oder
/// Abbruch vorher setzt den Fortschritt zurück (nichts passiert).
/// Visualisierung: rote Füllung wächst über die Haltezeit.
class _HoldToTriggerButton extends StatefulWidget {
  const _HoldToTriggerButton({
    required this.onTriggered,
  });

  final VoidCallback onTriggered;
  static const holdDuration = Duration(seconds: 2);

  @override
  State<_HoldToTriggerButton> createState() => _HoldToTriggerButtonState();
}

class _HoldToTriggerButtonState extends State<_HoldToTriggerButton> {
  static const int _tickMs = 50;

  Timer? _timer;
  double _progress = 0.0;
  bool _fired = false;

  bool get _holding => _timer != null;

  void _start() {
    if (_holding) return;
    setState(() {
      _progress = 0.0;
      _fired = false;
    });
    _timer = Timer.periodic(
      const Duration(milliseconds: _tickMs),
      (t) {
        final p = (t.tick * _tickMs) /
            _HoldToTriggerButton.holdDuration.inMilliseconds;
        if (p >= 1.0) {
          _cancelTimer();
          if (mounted) {
            setState(() {
              _progress = 1.0;
              _fired = true;
            });
          }
          widget.onTriggered();
          // Nach kurzer Anzeige zurücksetzen.
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_holding) setState(() => _progress = 0.0);
          });
        } else if (mounted) {
          setState(() => _progress = p);
        }
      },
    );
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _cancel() {
    if (!_holding) return;
    _cancelTimer();
    if (mounted && !_fired) {
      setState(() => _progress = 0.0);
    }
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SOS senden: zwei Sekunden gedrückt halten',
      button: true,
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _cancel(),
        onPointerCancel: (_) => _cancel(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 56,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.red.shade100),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _progress.clamp(0.0, 1.0),
                    child: Container(color: Colors.red),
                  ),
                ),
                Center(
                  child: Text(
                    _holding ? 'Weiter halten …' : 'SOS halten (2 s)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _progress > 0.6 ? Colors.white : Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
