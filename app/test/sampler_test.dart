import 'package:flutter_test/flutter_test.dart';
import 'package:stepbystep_app/core/sampler.dart';

DateTime _utc(int year, int month, int day, int h, int m, int s) =>
    DateTime.utc(year, month, day, h, m, s);

void main() {
  final now = _utc(2026, 6, 1, 12, 0, 0);
  final last = GeoSample(
    lat: 52.5200,
    lng: 13.4050,
    accuracy: 10,
    recordedAt: now.subtract(const Duration(minutes: 1)),
  );

  test('ohne letzten Punkt: immer akzeptieren', () {
    final d = Sampler.evaluate(
      last: null,
      candidateLat: 52.5200,
      candidateLng: 13.4050,
      candidateAccuracy: 50,
      candidateAt: now,
      now: now,
    );
    expect(d, isNotNull);
    expect(d!.isHeartbeat, isFalse);
    expect(d.isFallback, isFalse);
  });

  test('Distanzfilter: < 15 m innerhalb von 5 min wird verworfen', () {
    // ~11 m östlich
    final d = Sampler.evaluate(
      last: last,
      candidateLat: 52.5200,
      candidateLng: 13.4050 + 0.0001,
      candidateAccuracy: 10,
      candidateAt: now,
      now: now,
    );
    expect(d, isNull);
  });

  test('Distanzfilter: >= 15 m wird akzeptiert', () {
    final d = Sampler.evaluate(
      last: last,
      candidateLat: 52.5200,
      candidateLng: 13.4050 + 0.0002,
      candidateAccuracy: 10,
      candidateAt: now,
      now: now,
    );
    expect(d, isNotNull);
  });

  test('Herzschlag: < 15 m, aber > 5 min alt -> akzeptiert', () {
    final oldLast = GeoSample(
      lat: 52.5200,
      lng: 13.4050,
      accuracy: 10,
      recordedAt: now.subtract(const Duration(minutes: 6)),
    );
    final d = Sampler.evaluate(
      last: oldLast,
      candidateLat: 52.5200,
      candidateLng: 13.4050 + 0.00001,
      candidateAccuracy: 10,
      candidateAt: now,
      now: now,
    );
    expect(d, isNotNull);
    expect(d!.isHeartbeat, isTrue);
  });

  test('Genauigkeit > 100 m: verworfen, wenn letzter Punkt frisch', () {
    final d = Sampler.evaluate(
      last: last,
      candidateLat: 52.6,
      candidateLng: 13.5,
      candidateAccuracy: 150,
      candidateAt: now,
      now: now,
    );
    expect(d, isNull);
  });

  test('Genauigkeit-Fallback: > 100 m akzeptiert, wenn letzte Stelle '
      'älter als 10 min', () {
    final stale = GeoSample(
      lat: 52.5200,
      lng: 13.4050,
      accuracy: 10,
      recordedAt: now.subtract(const Duration(minutes: 11)),
    );
    final d = Sampler.evaluate(
      last: stale,
      candidateLat: 52.6,
      candidateLng: 13.5,
      candidateAccuracy: 150,
      candidateAt: now,
      now: now,
    );
    expect(d, isNotNull);
    expect(d!.isFallback, isTrue);
  });

  test('Genauigkeit genau 100 m ist ok (Grenze)', () {
    final d = Sampler.evaluate(
      last: last,
      candidateLat: 52.6,
      candidateLng: 13.5,
      candidateAccuracy: 100,
      candidateAt: now,
      now: now,
    );
    expect(d, isNotNull);
  });

  test('Herzschlag-Grenze: genau 5 min -> akzeptiert', () {
    final edge = GeoSample(
      lat: 52.5200,
      lng: 13.4050,
      accuracy: 10,
      recordedAt: now.subtract(const Duration(minutes: 5)),
    );
    final d = Sampler.evaluate(
      last: edge,
      candidateLat: 52.5200,
      candidateLng: 13.4050 + 0.00001,
      candidateAccuracy: 10,
      candidateAt: now,
      now: now,
    );
    expect(d, isNotNull);
    expect(d!.isHeartbeat, isTrue);
  });
}
