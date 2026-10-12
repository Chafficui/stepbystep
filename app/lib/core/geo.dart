import 'dart:math' as math;

/// Reine Geometrie-Helfer (keine Flutter-Abhängigkeit, unit-testbar).
class Geo {
  Geo._();

  /// Erdradius in Kilometern.
  static const double earthRadiusKm = 6371.0;

  /// Distanz zwischen zwei Koordinaten in Kilometern (Haversine-Formel).
  static double haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Distanz zwischen zwei Koordinaten in Metern.
  static double haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return haversineKm(lat1, lng1, lat2, lng2) * 1000.0;
  }

  /// Richtung (Azimut) von Punkt 1 nach Punkt 2 in Grad (0..360, 0 = Norden,
  /// 90 = Osten). Identische Punkte ergeben 0.0.
  static double bearingDeg(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final phi1 = _rad(lat1);
    final phi2 = _rad(lat2);
    final dLng = _rad(lng2 - lng1);
    final y = math.sin(dLng) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
    final deg = math.atan2(y, x) * 180.0 / math.pi;
    return (deg + 360.0) % 360.0;
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}
