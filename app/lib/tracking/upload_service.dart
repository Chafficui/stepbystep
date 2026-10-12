import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../api/api_client.dart';
import '../db/app_database.dart';
import '../state/session_store.dart';
import 'upload_queue_logic.dart';

/// Statistik für die UI (ungesendete Mengen + letzter Erfolg).
class UploadStats {
  const UploadStats({
    required this.unsentPoints,
    required this.unsentAlerts,
    required this.unsentCheckins,
    this.lastSuccessAt,
  });

  final int unsentPoints;
  final int unsentAlerts;
  final int unsentCheckins;
  final DateTime? lastSuccessAt; // UTC
}

/// Hintergrund-Upload der lokal gepufferten Daten.
///
/// - startet einmal beim App-Start und lebt, solange der Prozess lebt
/// - alle 2 Minuten + sofort bei Netzwerk-Rückkehr + sofort via [flushNow]
/// - Punkte: max. 200 pro Batch, chronologisch ASC, nur nach
///   Server-Bestätigung (`accepted`) als gesendet markiert
/// - Fehler: exponentieller Backoff (2, 4, 8 ... max. 30 min), nichts wird
///   je gelöscht
/// - SOS-Alarme haben Vorrang vor Punkten (Alarm klebt nicht im Backlog)
/// - AuthException (401): Upload pausieren, Callback [onAuthExpired]
///   (Sitzungs-Layer); lokale Daten/medien bleiben unangetastet
class UploadService {
  UploadService({
    required AppDatabase db,
    required ApiClient api,
    required SessionStore session,
    void Function()? onAuthExpired,
    this.periodicDelay = uploadBaseDelay,
  })  : _db = db,
        _api = api,
        _session = session,
        _onAuthExpired = onAuthExpired;

  final AppDatabase _db;
  final ApiClient _api;
  final SessionStore _session;
  final void Function()? _onAuthExpired;

  /// Normaler Abstand zwischen Upload-Versuchen (Testbarkeit: injectierbar).
  final Duration periodicDelay;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final StreamController<UploadStats> _statsCtrl =
      StreamController<UploadStats>.broadcast();

  int _consecutiveFailures = 0;
  bool _paused = false;
  bool _inFlight = false;
  DateTime? _lastSuccessAt;

  /// Live-Statistik für die UI.
  Stream<UploadStats> get stats => _statsCtrl.stream;

  UploadStats get currentStats => UploadStats(
        unsentPoints: _cachedUnsentPoints,
        unsentAlerts: _cachedUnsentAlerts,
        unsentCheckins: _cachedUnsentCheckins,
        lastSuccessAt: _lastSuccessAt,
      );

  int _cachedUnsentPoints = 0;
  int _cachedUnsentAlerts = 0;
  int _cachedUnsentCheckins = 0;

  /// Muss einmal beim App-Start aufgerufen werden.
  void start() {
    if (_timer != null) return;
    _schedule(periodicDelay);
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (connected) flushNow();
    });
    unawaited(flushNow());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _statsCtrl.close();
  }

  /// Sofortiger Upload-Versuch (z. B. nach Netzwerk-Rückkehr oder durch UI).
  Future<void> flushNow() => _tick();

  /// Nach 401 (oder ohne Sitzung beim Start): Uploads pausieren, bis eine
  /// neue Sitzung da ist ([resume]). Es wird nichts gelöscht. Das Pausieren
  /// selbst wirft den Timer nicht weg — [resume] startet ihn wieder.
  void pause() => _paused = true;

  void resume() {
    _paused = false;
    // Timer neu aufziehen, falls er während der Pause verfallen war.
    _timer ??= Timer(periodicDelay, _tick);
    unawaited(flushNow());
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _tick);
  }

  Duration get _currentDelay => backoffFor(
        _consecutiveFailures + 1,
        base: periodicDelay,
      );

  Future<void> _tick() async {
    if (_paused || _inFlight) return;
    _inFlight = true;
    try {
      final token = await _session.token;
      if (token == null || token.isEmpty) {
        _paused = true; // keine Sitzung -> still legen
        return;
      }
      await _flushAlerts(token);
      await _flushPoints(token);
      await flushCheckins(_api);
      _consecutiveFailures = 0; // Erfolg -> Backoff zurücksetzen
      _lastSuccessAt = DateTime.now().toUtc();
    } on AuthException {
      _paused = true;
      _onAuthExpired?.call();
    } on ApiException {
      _consecutiveFailures++;
    } catch (_) {
      _consecutiveFailures++;
    } finally {
      _inFlight = false;
      await _refreshStats();
      if (!_paused) _schedule(_currentDelay);
    }
  }

  /// SOS zuerst, dann abort, jeweils chronologisch; nur bei Erfolg als gesendet
  /// markieren (idempotent per id).
  Future<void> _flushAlerts(String token) async {
    final rows = await _db.unsentAlerts();
    final alerts = orderedAlerts([
      for (final r in rows)
        QueuedAlert(
          id: r.id,
          type: r.type,
          lat: r.lat,
          lng: r.lng,
          createdAtMs: r.createdAt,
        ),
    ]);
    for (final a in alerts) {
      try {
        await _api.postAlert(
          token,
          id: a.id,
          type: a.type,
          lat: a.lat,
          lng: a.lng,
          createdAt:
              DateTime.fromMillisecondsSinceEpoch(a.createdAtMs, isUtc: true),
        );
        await _db.markAlertsSent([a.id]);
      } on AuthException {
        rethrow;
      } on ApiException {
        // nächster Alarm im nächsten Durchlauf; keiner wird gelöscht
        return;
      }
    }
  }

  Future<void> _flushPoints(String token) async {
    while (!_paused) {
      final rows = await _db.unsentPoints();
      if (rows.isEmpty) return;
      final points = dedupeAndSortChronologically([
        for (final r in rows)
          QueuedPoint(
            id: r.id,
            lat: r.lat,
            lng: r.lng,
            accuracy: r.accuracy,
            speed: r.speed,
            battery: r.battery,
            recordedAtMs: r.recordedAt,
          ),
      ]);
      final batch = splitIntoBatches(points).first;
      final sentIds = batch.map((p) => p.id).toList();
      final accepted = await _api.postPointsBatch(
        token,
        batch.map((p) => p.toPayload()).toList(),
      );
      final toMark = idsToMarkAccepted(sentIds, accepted);
      if (toMark.isNotEmpty) await _db.markPointsSent(toMark);
      // Nicht bestätigte Punkte bleiben ungesendet (niemals löschen) und
      // werden später erneut versucht. Bei Fortschritt (mind. ein Punkt
      // akzeptiert) direkt das nächste Batch aus der Queue holen statt
      // den Rest auf den nächsten Tick zu schieben.
      if (toMark.isEmpty) return; // kein Fortschritt -> nächster Durchlauf
      if (rows.length < maxPointsPerBatch) return; // Queue damit leer
    }
  }

  /// Check-ins hochladen (Foto/Video via multipart). Kann auch direkt vom
  /// Check-in-Screen aufgerufen werden, um frische Medien sofort zu senden.
  Future<void> flushCheckins(ApiClient api) async {
    final token = await _session.token;
    if (token == null || token.isEmpty) return;
    final rows = await _db.unsentCheckins();
    for (final r in rows) {
      try {
        await api.postCheckin(
          token,
          id: r.id,
          capturedAt:
              DateTime.fromMillisecondsSinceEpoch(r.capturedAt, isUtc: true),
          mediaType: r.mediaType,
          filePath: r.filePath,
        );
        await _db.markCheckinsSent([r.id]);
      } on AuthException {
        rethrow;
      } catch (_) {
        return; // Rest im nächsten Durchlauf
      }
    }
  }

  Future<void> _refreshStats() async {
    _cachedUnsentPoints = await _db.unsentPointCount();
    _cachedUnsentAlerts = await _db.unsentAlertCount();
    _cachedUnsentCheckins = await _db.unsentCheckinCount();
    if (!_statsCtrl.isClosed) {
      _statsCtrl.add(currentStats);
    }
  }
}
