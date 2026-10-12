import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/api_client.dart';
import '../models/event_config.dart';
import '../state/session_store.dart';
import '../tracking/tracking_controller.dart';

/// Wartezimmer + laufendes Event (Shell).
///
/// Countdown zu reveal/start (Serverzeiten, lokal angezeigt),
/// Verbindungsstatus, Uhren-Drift-Warnung und „Tracking starten".
class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.sessionStore});

  final SessionStore sessionStore;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final ApiClient _api = ApiClient();
  final TrackingController _tracking = _StubTrackingController();
  Timer? _ticker;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  EventConfig? _config;
  String? _error;
  bool _online = true;
  TrackingState _trackingState = TrackingState.stopped;

  @override
  void initState() {
    super.initState();
    _loadEvent();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      if (!mounted) return;
      setState(
          () => _online = !results.contains(ConnectivityResult.none));
    });
    _tracking.state.listen((s) {
      if (mounted) setState(() => _trackingState = s);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadEvent() async {
    try {
      final token = await widget.sessionStore.token;
      final json = await _api.getEvent(token);
      if (!mounted) return;
      setState(() => _config = EventConfig.fromJson(json));
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
      body: RefreshIndicator(
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
            if (config == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (config.isBeforeReveal(now))
                _CountdownCard(
                  title: 'Enthüllung der Route in',
                  target: config.revealTime,
                  fmt: _fmt,
                  subtitle: 'Enthüllung: ${_localTime(config.revealTime)}',
                )
              else if (now.toUtc().isBefore(config.startTime.toUtc()))
                _CountdownCard(
                  title: 'Start in',
                  target: config.startTime,
                  fmt: _fmt,
                  subtitle: 'Start: ${_localTime(config.startTime)}',
                )
              else if (config.isRunning(now))
                _CountdownCard(
                  title: 'Event endet in',
                  target: config.endTime,
                  fmt: _fmt,
                  subtitle: 'Ende: ${_localTime(config.endTime)}',
                )
              else
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Das Event ist beendet. Danke fürs Mitmachen!'),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Check-ins: alle ${config.checkinIntervalMin} Minuten '
                '(Fenster ${config.checkinWindowMin} Min). '
                'Orga-Telefon: ${config.orgaPhone}',
              ),
              const SizedBox(height: 24),
              if (waiting || config.isRunning(now))
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                  ),
                  icon: Icon(_trackingState == TrackingState.running
                      ? Icons.stop
                      : Icons.play_arrow),
                  label: Text(
                    _trackingState == TrackingState.running
                        ? 'Tracking stoppen'
                        : 'Tracking starten',
                    style: const TextStyle(fontSize: 20),
                  ),
                  onPressed: () async {
                    final granted =
                        await _checkLocationAlways();
                    if (!granted) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Standort „Immer" fehlt – Tracking '
                                  'deaktiviert.')),
                        );
                      }
                      return;
                    }
                    if (_trackingState == TrackingState.running) {
                      await _tracking.stop();
                    } else {
                      await _tracking.start();
                    }
                  },
                ),
            ],
          ],
        ),
      ),
    );
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

/// Platzhalter bis der echte Tracking-Service umgesetzt ist.
class _StubTrackingController implements TrackingController {
  final StreamController<TrackingState> _controller =
      StreamController.broadcast();

  @override
  Stream<TrackingState> get state => _controller.stream;

  @override
  Future<void> start() async {
    _controller.add(TrackingState.running);
  }

  @override
  Future<void> stop() async {
    _controller.add(TrackingState.stopped);
  }
}
