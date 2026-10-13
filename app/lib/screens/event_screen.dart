import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
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
import '../brand/sbs_colors.dart';
import '../brand/sbs_logo.dart';
import '../brand/sbs_theme.dart';
import '../core/slot_calc.dart';
import 'checkin_screen.dart';
import 'end_screen.dart';
import 'live_tab.dart';
import 'map_screen.dart';
import 'rank_screen.dart';
import 'sos_bar.dart';

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

  /// Live-Werte für das Status-Sheet (aktualisiert bei jeder Änderung).
  late final ValueNotifier<StatusData> _statusN =
      ValueNotifier<StatusData>(_statusData());

  @override
  void initState() {
    super.initState();
    _loadEvent();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      _syncStatus();
      _checkLastAlertSent();
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(
          () => _online = !results.contains(ConnectivityResult.none));
      _syncStatus();
    });
    _trackingSub = _tracking.state.listen((s) {
      if (mounted) setState(() => _trackingState = s);
      _syncStatus();
    });
    _statsSub = _upload.stats.listen((s) {
      if (mounted) setState(() => _stats = s);
      _syncStatus();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _connectivitySub?.cancel();
    _trackingSub?.cancel();
    _statsSub?.cancel();
    _statusN.dispose();
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

  StatusData _statusData() => StatusData(
        tracking: _trackingState,
        online: _online,
        stats: _stats,
        batteryPercent: _battery.currentPercent,
        stale: _staleTracking,
      );

  void _syncStatus() {
    if (!mounted) return;
    _statusN.value = _statusData();
  }

  void _openStatusSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => StatusSheet(data: _statusN),
    );
  }

  /// Nächster fälliger Check-in (erste Erinnerungszeit nach jetzt).
  DateTime? _nextCheckin(EventConfig config) {
    final now = DateTime.now().toUtc();
    for (final t in SlotCalc.reminderTimes(config)) {
      if (t.isAfter(now)) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final now = DateTime.now();

    // Uhren-Drift-Warnung: |deviceNow - server_now| > 60 s.
    final driftWarning = config != null &&
        config.serverDrift(now).abs() > const Duration(seconds: 60);

    final running = _trackingState.kind == TrackingStateKind.running;

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
        tabContent = LiveTab(
          config: config,
          now: now,
          status: _statusData(),
          error: _error,
          driftWarning: driftWarning,
          nextCheckin: config == null ? null : _nextCheckin(config),
          onRefresh: _loadEvent,
          onToggleTracking: _toggleTracking,
          onAbort: _abort,
          onOpenStatus: _openStatusSheet,
          onOpenCheckin: () => setState(() => _selectedTab = 2),
          // Tracking läuft nach Event-Ende bewusst weiter (Abholung).
          endSection: EndScreenBody(tracking: _tracking, isRunning: running),
        );
    }

    String? statusText;
    if (_lastAlertId != null) {
      statusText = (_lastAlertSent ?? false)
          ? 'SOS gesendet'
          : 'SOS gespeichert – wird gesendet, sobald Netz da ist';
    }

    return EventShell(
      title: config?.name ?? 'Event',
      online: _online,
      selectedTab: _selectedTab,
      onTab: (i) => setState(() => _selectedTab = i),
      body: KeyedSubtree(key: ValueKey(_selectedTab), child: tabContent),
      sosBar: SosBar(
        onTriggered: () => _triggerAlert('sos'),
        statusText: statusText,
        statusSent: _lastAlertSent ?? false,
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


/// Rahmen des Event-Screens: AppBar, Tab-Inhalt, SOS-Leiste, Navigation.
class EventShell extends StatelessWidget {
  const EventShell({
    super.key,
    required this.title,
    required this.online,
    required this.selectedTab,
    required this.onTab,
    required this.body,
    required this.sosBar,
  });

  final String title;
  final bool online;
  final int selectedTab;
  final ValueChanged<int> onTab;
  final Widget body;
  final Widget sosBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const SbsLogo(width: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SbsText.display(18),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _OnlinePill(online: online),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: body),
          // Auf jedem Tab erreichbar: SOS-Leiste.
          sosBar,
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: onTab,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer),
              label: 'Live'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Karte'),
          NavigationDestination(
              icon: Icon(Icons.photo_camera_outlined),
              selectedIcon: Icon(Icons.photo_camera),
              label: 'Check-in'),
          NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined),
              selectedIcon: Icon(Icons.leaderboard),
              label: 'Rang'),
        ],
      ),
    );
  }
}

class _OnlinePill extends StatelessWidget {
  const _OnlinePill({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final c = online ? SbsColors.ok : SbsColors.signal;
    return Semantics(
      label: online ? 'Online' : 'Offline',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text((online ? 'Online' : 'Offline').toUpperCase(),
              style: SbsText.label(color: c, size: 10.5)),
        ],
      ),
    );
  }
}
