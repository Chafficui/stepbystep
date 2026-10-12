import 'package:flutter_test/flutter_test.dart';
import 'package:stepbystep_app/core/geo.dart';

void main() {
  test('haversine: bekannte Distanzen (km)', () {
    // (lat1, lng1, lat2, lng2, erwartete km, Toleranz km)
    const cases = [
      (52.5200, 13.4050, 48.8566, 2.3522, 878.0, 5.0), // Berlin–Paris
      (52.5200, 13.4050, 48.1351, 11.5820, 504.5, 5.0), // Berlin–München
      (40.7128, -74.0060, 34.0522, -118.2437, 3936.0, 10.0), // NY–LA
      (51.5074, -0.1278, 48.8566, 2.3522, 343.5, 3.0), // London–Paris
      (47.3769, 8.5417, 46.2044, 6.1432, 254.0, 3.0), // Zürich–Genf
      // GPS-Größenordnung: 1 Minute Breite ≈ 1,85 km
      (0.0, 0.0, 0.0166667, 0.0, 1.853, 0.02),
      // 15 m – Sampler-Grenzwert
      (0.0, 0.0, 0.0, 0.00013458, 0.015, 0.002),
    ];
    for (final (la1, lo1, la2, lo2, expected, tol) in cases) {
      final d = Geo.haversineKm(la1, lo1, la2, lo2);
      expect(d, closeTo(expected, tol),
          reason: '$la1,$lo1 -> $la2,$lo2: $d != ~$expected');
    }
  });

  test('haversine: identische Punkte sind 0', () {
    expect(Geo.haversineKm(52.5, 13.4, 52.5, 13.4), 0.0);
  });

  test('haversine: symmetrisch', () {
    final a = Geo.haversineKm(52.5, 13.4, 48.85, 2.35);
    final b = Geo.haversineKm(48.85, 2.35, 52.5, 13.4);
    expect(a, closeTo(b, 1e-9));
  });

  test('haversineMeters entspricht km * 1000', () {
    expect(
      Geo.haversineMeters(52.52, 13.405, 52.5201, 13.405),
      closeTo(11.13, 0.2),
    );
  });
}
