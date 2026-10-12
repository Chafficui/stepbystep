import 'package:flutter_test/flutter_test.dart';
import 'package:stepbystep_app/core/geo.dart';

void main() {
  group('Geo.bearingDeg', () {
    test('identische Punkte -> 0', () {
      expect(Geo.bearingDeg(52.5, 13.4, 52.5, 13.4), 0.0);
    });

    test('Norden = 0', () {
      final b = Geo.bearingDeg(52.0, 13.0, 53.0, 13.0);
      expect(b, closeTo(0, 0.001));
    });

    test('Osten = 90', () {
      final b = Geo.bearingDeg(0.0, 13.0, 0.0, 14.0);
      expect(b, closeTo(90, 0.001));
    });

    test('Süden = 180', () {
      final b = Geo.bearingDeg(52.0, 13.0, 51.0, 13.0);
      expect(b, closeTo(180, 0.001));
    });

    test('Westen = 270', () {
      final b = Geo.bearingDeg(0.0, 13.0, 0.0, 12.0);
      expect(b, closeTo(270, 0.001));
    });

    test('Diagonale Nordost = 45', () {
      // Am Äquator ergibt 1° Breite / 1° Länge fast genau 45° (Großkreis).
      final b = Geo.bearingDeg(0.0, 0.0, 1.0, 1.0);
      expect(b, closeTo(45, 0.01));
    });

    test('Diagonale Südwest = 225', () {
      final b = Geo.bearingDeg(0.0, 0.0, -1.0, -1.0);
      expect(b, closeTo(225, 0.01));
    });

    test('Ergebnis immer in [0, 360)', () {
      final b = Geo.bearingDeg(52.0, 13.0, 51.9, 12.9);
      expect(b >= 0 && b < 360, isTrue);
    });
  });
}
