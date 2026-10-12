import '../models/event_config.dart';

/// Reine Slot-/Erinnerungs-Berechnung (nur UTC-Arithmetik, DST-unabhängig).
class SlotCalc {
  SlotCalc._();

  /// Slot-Index eines Check-ins:
  /// `floor((capturedAt - startTime) / intervalMin)`.
  ///
  /// Vor dem Start (negativer Wert) ergibt das einen negativen Slot;
  /// die Berechnung ist UTC-basiert und damit Sommerzeit-unabhängig.
  static int slotFor(
    DateTime capturedAt,
    DateTime startTime,
    int intervalMin,
  ) {
    assert(intervalMin > 0, 'intervalMin muss > 0 sein');
    final diffMs =
        capturedAt.toUtc().millisecondsSinceEpoch -
            startTime.toUtc().millisecondsSinceEpoch;
    return (diffMs / (intervalMin * 60000)).floor();
  }

  /// Alle Erinnerungszeitpunkte: `startTime + n*interval` für alle
  /// n >= 1 mit `zeitpunkt <= endTime`. Nur UTC-Arithmetik.
  static List<DateTime> reminderTimes(EventConfig config) {
    if (config.checkinIntervalMin <= 0) return const [];
    final result = <DateTime>[];
    final startMs = config.startTime.toUtc().millisecondsSinceEpoch;
    final stepMs = config.checkinIntervalMin * 60000;
    var n = 1;
    while (true) {
      final tMs = startMs + n * stepMs;
      final t = DateTime.fromMillisecondsSinceEpoch(tMs, isUtc: true);
      if (t.isAfter(config.endTime)) break;
      result.add(t);
      n++;
    }
    return result;
  }

  /// true, wenn `capturedAt` innerhalb des Check-in-Fensters liegt
  /// (`slot*interval` bis `(slot+1)*interval + windowMin`).
  static bool inCheckinWindow(
    DateTime capturedAt,
    DateTime startTime,
    int intervalMin,
    int windowMin,
  ) {
    final slot = slotFor(capturedAt, startTime, intervalMin);
    final slotStart = DateTime.fromMillisecondsSinceEpoch(
      startTime.toUtc().millisecondsSinceEpoch + slot * intervalMin * 60000,
      isUtc: true,
    );
    final windowEnd =
        slotStart.add(Duration(minutes: intervalMin + windowMin));
    final t = capturedAt.toUtc();
    return !t.isBefore(slotStart) && !t.isAfter(windowEnd);
  }
}
