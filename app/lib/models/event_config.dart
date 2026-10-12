/// Konfiguration des Events, wie sie `GET /api/event` liefert.
///
/// Alle Zeiten sind ISO-8601-UTC-Strings ("Z") und werden als
/// DateTime (UTC) geparst; Anzeige erfolgt lokal via intl.
class EventConfig {
  const EventConfig({
    required this.name,
    this.startLat,
    this.startLng,
    required this.revealTime,
    required this.startTime,
    required this.durationH,
    required this.endTime,
    required this.checkinIntervalMin,
    required this.checkinWindowMin,
    required this.orgaPhone,
    required this.serverNow,
  });

  final String name;
  final double? startLat;
  final double? startLng;
  final DateTime revealTime;
  final DateTime startTime;
  final int durationH;
  final DateTime endTime;
  final int checkinIntervalMin;
  final int checkinWindowMin;
  final String orgaPhone;

  /// Server-Zeit zum Zeitpunkt des Abrufs (für Drift-Berechnung).
  final DateTime serverNow;

  factory EventConfig.fromJson(Map<String, dynamic> json) {
    return EventConfig(
      name: json['name'] as String,
      startLat: (json['start_lat'] as num?)?.toDouble(),
      startLng: (json['start_lng'] as num?)?.toDouble(),
      revealTime: parseUtc(json['reveal_time'] as String),
      startTime: parseUtc(json['start_time'] as String),
      durationH: json['duration_h'] as int,
      endTime: parseUtc(json['end_time'] as String),
      checkinIntervalMin: json['checkin_interval_min'] as int,
      checkinWindowMin: json['checkin_window_min'] as int,
      orgaPhone: json['orga_phone'] as String,
      serverNow: parseUtc(json['server_now'] as String),
    );
  }

  /// Parst ISO-8601-UTC-Strings robust (mit oder ohne "Z").
  static DateTime parseUtc(String s) {
    var value = s.trim();
    if (!value.endsWith('Z')) {
      // Server verspricht UTC; fehlendes "Z" ergänzen.
      if (value.contains('+') || RegExp(r'-\d{2}:\d{2}$').hasMatch(value)) {
        return DateTime.parse(value).toUtc();
      }
      value = '${value}Z';
    }
    return DateTime.parse(value).toUtc();
  }

  /// Wie weit geht die Server-Uhr vorn/hinter (deviceNow - serverNow)?
  Duration serverDrift(DateTime deviceNow) =>
      deviceNow.difference(serverNow.toUtc());

  /// Noch vor `revealTime` (Strecke/Orga-Infos versteckt)?
  bool isBeforeReveal(DateTime now) =>
      now.toUtc().isBefore(revealTime.toUtc());

  /// Event läuft (nach Start, vor Ende)?
  bool isRunning(DateTime now) {
    final t = now.toUtc();
    return !t.isBefore(startTime.toUtc()) && t.isBefore(endTime.toUtc());
  }

  /// Event vorbei?
  bool isOver(DateTime now) => now.toUtc().isAfter(endTime.toUtc());
}
