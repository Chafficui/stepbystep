import 'dart:async';
import 'dart:io' show Platform;

import 'package:drift/drift.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../core/sampler.dart';
import '../db/app_database.dart';
import '../state/session_store.dart';
import 'battery_monitor.dart';
import 'tracking_controller.dart';

/// Echte Hintergrund-Positionsverfolgung.
///
/// Pipeline: Positions-Stream -> Sampler-Entscheidung -> JEDER akzeptierte
/// Punkt ZUERST in die lokale drift-DB (UUID pro Punkt, sentAt = null).
/// Der Upload passiert unabhängig davon im [Upload-Service].
///
/// Robustheit:
/// - Android: Foreground-Service mit Benachrichtigung + WakeLock.
/// - iOS: allowBackgroundLocationUpdates + Fitness-Aktivität.
/// - 5-Minuten-Heartbeat: nimmt die letzte bekannte Rohposition und legt
///   sie durch den Sampler (Heartbeat-Regel), damit auch ohne Bewegung
///   regelmäßig ein Punkt entsteht.
/// - Auto-Resume: `tracking_active` wird VOR dem Stream-Start gesetzt
///   (Crash-Sicherheit) und nur bei explizitem `stop()` gelöscht.
class TrackingService implements TrackingController {
  TrackingService({
    required AppDatabase db,
    required SessionStore sessionStore,
    BatteryMonitor? batteryMonitor,
  })  : _db = db,
        _session = sessionStore,
        _battery = batteryMonitor;

  static const Duration heartbeatPeriod = Duration(minutes: 5);
  static const int distanceFilterMeters = 10;

  final AppDatabase _db;
  final SessionStore _session;
  final BatteryMonitor? _battery;

  final StreamController<TrackingState> _stateCtrl =
      StreamController<TrackingState>.broadcast();
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;

  Position? _lastRaw;
  GeoSample? _lastAccepted;
  DateTime? _lastPointAt;
  bool _starting = false;

  /// Zeitstempel des zuletzt lokal gespeicherten Punkts (für die
  /// Stale-Daten-Warnung der UI). Liefert null, wenn noch kein Punkt da ist.
  DateTime? get lastPointAt => _lastPointAt;

  /// Letzte bekannte Roheposition (für Heartbeat/UI), ungefiltert.
  Position? get lastRawPosition => _lastRaw;

  @override
  Stream<TrackingState> get state => _stateCtrl.stream;

  void _emit(TrackingState s) {
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  LocationSettings _settings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Tracking läuft',
          notificationText: 'Deine Route wird aufgezeichnet',
          enableWakeLock: true,
          setOngoing: true,
          notificationChannelName: 'Tracking',
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.fitness,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );
  }

  @override
  Future<void> start() async {
    if (_starting || _positionSub != null) return;
    _starting = true;
    try {
      // ZUERST Flag setzen (Crash-Sicherheit), dann starten.
      await _session.setTrackingActive(true);

      final status = await Permission.locationAlways.status;
      if (!status.isGranted) {
        await _session.setTrackingActive(false);
        _emit(const TrackingState.error(
            'Standortberechtigung „Immer" fehlt – Tracking nicht möglich.'));
        return;
      }

      // Sampler-Startwert: letzter lokal gespeicherter Punkt (App-Restart).
      final lastRow = await _db.lastPoint();
      if (lastRow != null) {
        _lastAccepted = GeoSample(
          lat: lastRow.lat,
          lng: lastRow.lng,
          accuracy: lastRow.accuracy,
          recordedAt:
              DateTime.fromMillisecondsSinceEpoch(lastRow.recordedAt, isUtc: true),
        );
        _lastPointAt = _lastAccepted!.recordedAt;
      }

      _positionSub = Geolocator.getPositionStream(locationSettings: _settings())
          .listen(
        _onPosition,
        onError: (Object e) {
          _emit(TrackingState.error(
              'Positionsdaten fehlgeschlagen (${_safeMessage(e)}). '
              'Tracking wird beim nächsten Start fortgesetzt.'));
        },
        cancelOnError: false,
      );

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(heartbeatPeriod, (_) => _heartbeat());

      _emit(const TrackingState.running());
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _session.setTrackingActive(false);
    _emit(const TrackingState.stopped());
  }

  Future<void> _onPosition(Position pos) async {
    _lastRaw = pos;

    // Berechtigung entzogen? -> sauber stoppen, deutsche Meldung.
    final status = await Permission.locationAlways.status;
    if (!status.isGranted) {
      await stop();
      _emit(const TrackingState.error(
          'Standortberechtigung wurde entzogen – Tracking gestoppt.'));
      return;
    }

    await _record(pos);
  }

  /// Heartbeat: letzte Rohposition durch den Sampler laufen lassen, damit
  /// auch ohne Bewegung spätestens nach 5 Minuten ein Punkt entsteht.
  Future<void> _heartbeat() async {
    final pos = _lastRaw;
    if (pos == null) return;
    // Heartbeat-Punkte erhalten den Zeitpunkt der Erzeugung (jetzt) als
    // `recordedAt` — nicht den alten Zeitstempel der gecachten Rohposition,
    // damit die Punkte nicht rückdatiert werden.
    await _record(pos, recordedAtOverride: DateTime.now().toUtc());
  }

  Future<void> _record(Position pos, {DateTime? recordedAtOverride}) async {
    final recordedAt = recordedAtOverride ?? pos.timestamp.toUtc();
    final decision = Sampler.evaluate(
      last: _lastAccepted,
      candidateLat: pos.latitude,
      candidateLng: pos.longitude,
      candidateAccuracy: pos.accuracy,
      candidateAt: recordedAt,
      now: DateTime.now().toUtc(),
    );
    if (decision == null) return;

    final id = const Uuid().v4();
    await _db.insertPoint(PointsCompanion.insert(
      id: id,
      lat: decision.lat,
      lng: decision.lng,
      accuracy: decision.accuracy,
      speed: Value(pos.speed),
      battery: Value(_battery?.currentPercent),
      recordedAt: recordedAt.millisecondsSinceEpoch,
    ));

    _lastAccepted = decision.toSample();
    _lastPointAt = recordedAt;
  }

  String _safeMessage(Object e) {
    // KEINE Koordinaten/Tokens loggen – nur Klassenname.
    return e.runtimeType.toString();
  }
}
