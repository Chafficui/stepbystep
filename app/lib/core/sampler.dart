import 'geo.dart';

/// Ein GPS-Beispielwert mit Zeitpunkt.
class GeoSample {
  const GeoSample({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.recordedAt,
  });

  final double lat;
  final double lng;
  final double accuracy;
  final DateTime recordedAt;
}

/// Ergebnis der Sampler-Entscheidung.
class SampleDecision {
  const SampleDecision({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.recordedAt,
    this.isHeartbeat = false,
    this.isFallback = false,
  });

  final double lat;
  final double lng;
  final double accuracy;
  final DateTime recordedAt;

  /// true, wenn ohne Bewegung als Heartbeat akzeptiert (>= 5 min).
  final bool isHeartbeat;

  /// true, wenn trotz schlechter Genauigkeit als Fallback akzeptiert.
  final bool isFallback;

  GeoSample toSample() => GeoSample(
        lat: lat,
        lng: lng,
        accuracy: accuracy,
        recordedAt: recordedAt,
      );
}

/// Reine Entscheidunglogik für GPS-Sampling (unit-testbar, kein Flutter).
class Sampler {
  Sampler._();

  /// Maximale akzeptierte Genauigkeit (Meter), außer im Fallback.
  static const double maxAccuracyMeters = 100;

  /// Mindest-Distanz (Meter) seit dem letzten akzeptierten Punkt.
  static const double minDistanceMeters = 15;

  /// Nach so viel Minuten ohne akzeptierten Punkt wird ein Heartbeat
  /// akzeptiert (auch ohne Bewegung).
  static const Duration heartbeatInterval = Duration(minutes: 5);

  /// Ab dieser "Lücke" akzeptieren wir auch ungenaue Punkte als Fallback.
  static const Duration fallbackAfter = Duration(minutes: 10);

  /// Bewertet einen Kandidaten-Punkt.
  ///
  /// - Ohne letzten akzeptierten Punkt: immer akzeptieren.
  /// - `accuracy > 100`: verwerfen, außer der letzte akzeptierte Punkt ist
  ///   älter als 10 Minuten (dann als Fallback akzeptieren).
  /// - Distanz >= 15 m zum letzten akzeptierten Punkt: akzeptieren.
  /// - Letzter akzeptierter Punkt älter als 5 Minuten: als Heartbeat
  ///   akzeptieren (auch ohne Bewegung).
  /// - Sonst: null (verwerfen).
  static SampleDecision? evaluate({
    GeoSample? last,
    required double candidateLat,
    required double candidateLng,
    required double candidateAccuracy,
    required DateTime candidateAt,
    required DateTime now,
  }) {
    if (last == null) {
      return SampleDecision(
        lat: candidateLat,
        lng: candidateLng,
        accuracy: candidateAccuracy,
        recordedAt: candidateAt,
      );
    }

    final age = now.difference(last.recordedAt);

    if (candidateAccuracy > maxAccuracyMeters) {
      if (age > fallbackAfter) {
        return SampleDecision(
          lat: candidateLat,
          lng: candidateLng,
          accuracy: candidateAccuracy,
          recordedAt: candidateAt,
          isFallback: true,
        );
      }
      return null;
    }

    final distanceMeters = Geo.haversineMeters(
      last.lat,
      last.lng,
      candidateLat,
      candidateLng,
    );

    if (distanceMeters >= minDistanceMeters) {
      return SampleDecision(
        lat: candidateLat,
        lng: candidateLng,
        accuracy: candidateAccuracy,
        recordedAt: candidateAt,
      );
    }

    if (age >= heartbeatInterval) {
      return SampleDecision(
        lat: candidateLat,
        lng: candidateLng,
        accuracy: candidateAccuracy,
        recordedAt: candidateAt,
        isHeartbeat: true,
      );
    }

    return null;
  }
}
