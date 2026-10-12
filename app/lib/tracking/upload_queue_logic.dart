/// Reine Queue-/Entscheidungslogik für den Upload-Service (kein IO, kein
/// Flutter) — damit die Queue-Semantik ohne Server unit-testbar ist.
library;

/// Mindestens zu bestätigende Punkte pro Batch (Server-Contract: max. 200).
const int maxPointsPerBatch = 200;

/// Basis-Verzögerung zwischen Upload-Versuchen.
const Duration uploadBaseDelay = Duration(minutes: 2);

/// Obergrenze des exponentiellen Backoffs.
const Duration uploadMaxDelay = Duration(minutes: 30);

/// Ein ungesendeter GPS-Punkt aus der lokalen Queue.
class QueuedPoint {
  const QueuedPoint({
    required this.id,
    required this.lat,
    required this.lng,
    required this.accuracy,
    this.speed,
    this.battery,
    required this.recordedAtMs,
  });

  final String id;
  final double lat;
  final double lng;
  final double accuracy;
  final double? speed;
  final int? battery;
  final int recordedAtMs; // ms since epoch (UTC)

  Map<String, dynamic> toPayload() => {
        'id': id,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        if (speed != null) 'speed': speed,
        if (battery != null) 'battery': battery,
        'recorded_at': recordedAtMs,
      };
}

/// Eine ungesendete Alarm-Nachricht aus der lokalen Queue.
class QueuedAlert {
  const QueuedAlert({
    required this.id,
    required this.type, // 'sos' | 'abort'
    required this.lat,
    required this.lng,
    required this.createdAtMs,
  });

  final String id;
  final String type;
  final double lat;
  final double lng;
  final int createdAtMs; // ms since epoch (UTC)
}

/// sortiert Alarme: SOS zuerst (Alarm darf nicht hinter einem Backlog
/// kleben), innerhalb einer Art chronologisch (älteste zuerst).
List<QueuedAlert> orderedAlerts(List<QueuedAlert> alerts) {
  int rank(String type) => type == 'sos' ? 0 : 1;
  final copy = [...alerts]..sort((a, b) {
      final r = rank(a.type).compareTo(rank(b.type));
      return r != 0 ? r : a.createdAtMs.compareTo(b.createdAtMs);
    });
  return copy;
}

/// Nimmt nur die IDs, die der Server BESTÄTIGT hat (`accepted`), aus der
/// Menge der versendeten IDs (`sent`). Alles Nicht-Bestätigte bleibt in der
/// Queue (Punkte werden erst nach Server-Bestätigung als gesendet markiert).
List<String> idsToMarkAccepted(List<String> sent, List<String> accepted) {
  final sentSet = sent.toSet();
  return [
    for (final id in accepted)
      if (sentSet.contains(id)) id,
  ];
}

/// Zerlegt eine chronologisch sortierte Punktliste in Batches von maximal
/// [max] Punkten. Der Rest bleibt für den nächsten Durchlauf in der Queue.
List<List<QueuedPoint>> splitIntoBatches(List<QueuedPoint> points,
    {int max = maxPointsPerBatch}) {
  final batches = <List<QueuedPoint>>[];
  for (var i = 0; i < points.length; i += max) {
    final end = (i + max > points.length) ? points.length : i + max;
    batches.add(points.sublist(i, end));
  }
  return batches;
}

/// Entfernt Duplikate (gleiche UUID) und sortiert chronologisch ASC —
/// ein Punkt wird pro Batch nie doppelt hochgeladen.
List<QueuedPoint> dedupeAndSortChronologically(List<QueuedPoint> points) {
  final byId = <String, QueuedPoint>{for (final p in points) p.id: p};
  final list = byId.values.toList()
    ..sort((a, b) => a.recordedAtMs.compareTo(b.recordedAtMs));
  return list;
}

/// Nächster Retry-Abstand: 2, 4, 8, 16, 30, 30, ... Minuten.
/// [consecutiveFailures] = Anzahl Fehler seit dem letzten Erfolg (>= 1).
/// Nach einem Erfolg wird der Zähler auf 0 zurückgesetzt (=> 2 min).
Duration backoffFor(int consecutiveFailures,
    {Duration base = uploadBaseDelay, Duration max = uploadMaxDelay}) {
  if (consecutiveFailures < 1) return base;
  var delayMs = base.inMilliseconds;
  for (var i = 1; i < consecutiveFailures; i++) {
    delayMs *= 2;
    if (delayMs >= max.inMilliseconds) return max;
  }
  return Duration(milliseconds: delayMs);
}
