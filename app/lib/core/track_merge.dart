import '../api/api_client.dart' show TrackPoint;

/// Reine Logik zum Zusammenführen der Team-Spur (Server) mit lokalen
/// Punkten. Keine Interpolation: es entstehen nur echte Punkte.
class TrackMerge {
  TrackMerge._();

  /// Maximale Anzahl gehaltener Punkte (entspricht dem Server-Limit).
  static const int maxPoints = 5000;

  /// Hängt [incoming] an [existing] an: aufsteigend nach `recordedAt`,
  /// Duplikate (gleiche Zeit + Koordinate) entfernt, auf die letzten
  /// [maxPoints] begrenzt.
  static List<TrackPoint> mergeServer(
    List<TrackPoint> existing,
    List<TrackPoint> incoming,
  ) {
    final seen = <String>{};
    final all = <TrackPoint>[];
    for (final p in [...existing, ...incoming]) {
      if (seen.add(_key(p))) all.add(p);
    }
    all.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return all.length > maxPoints
        ? all.sublist(all.length - maxPoints)
        : all;
  }

  /// Server-Spur + lokale Punkte, die NEUER sind als der letzte
  /// Server-Punkt (offline / noch nicht gesendet). Ergebnis aufsteigend.
  static List<TrackPoint> withLocal(
    List<TrackPoint> server,
    List<TrackPoint> local,
  ) {
    final base = mergeServer(server, const []);
    final latest = base.isEmpty ? null : base.last.recordedAt;
    final extra = [
      for (final p in local)
        if (latest == null || p.recordedAt.isAfter(latest)) p,
    ];
    return mergeServer(base, extra);
  }

  /// `since` für den nächsten inkrementellen Abruf (letzter Server-Punkt).
  static DateTime? since(List<TrackPoint> server) =>
      server.isEmpty ? null : server.last.recordedAt;

  static String _key(TrackPoint p) =>
      '${p.recordedAt.millisecondsSinceEpoch}|${p.lat}|${p.lng}';
}
