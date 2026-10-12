import 'package:flutter_test/flutter_test.dart';
import 'package:stepbystep_app/core/slot_calc.dart';
import 'package:stepbystep_app/models/event_config.dart';

void main() {
  final start = DateTime.utc(2026, 6, 1, 10, 0, 0);
  final end = start.add(const Duration(hours: 4)); // 14:00 UTC
  final config = EventConfig(
    name: 'Test-Event',
    revealTime: start,
    startTime: start,
    durationH: 4,
    endTime: end,
    checkinIntervalMin: 30,
    checkinWindowMin: 5,
    orgaPhone: '+49',
    serverNow: start,
  );

  group('slotFor', () {
    test('Startzeit ist Slot 0', () {
      expect(SlotCalc.slotFor(start, start, 30), 0);
    });

    test('kurz vor dem ersten Intervall-Ende ist Slot 0', () {
      expect(SlotCalc.slotFor(start.add(const Duration(minutes: 29, seconds: 59)),
          start, 30), 0);
    });

    test('genau am Intervall-Ende ist Slot 1', () {
      expect(SlotCalc.slotFor(start.add(const Duration(minutes: 30)), start, 30),
          1);
    });

    test('negativer Wert vor dem Start (pre-start)', () {
      expect(SlotCalc.slotFor(start.subtract(const Duration(minutes: 1)), start,
          30), -1);
      expect(SlotCalc.slotFor(start.subtract(const Duration(minutes: 30)), start,
          30), -1);
      expect(SlotCalc.slotFor(start.subtract(const Duration(minutes: 31)), start,
          30), -2);
    });

    test('große Intervalle', () {
      expect(SlotCalc.slotFor(start.add(const Duration(hours: 2, minutes: 1)),
          start, 30), 4);
    });

    test('DST-unabhängig: UTC-Arithmetik', () {
      // Zwei Zeitpunkte im lokalen Sommer/Winter, gleiche UTC-Differenz.
      final winterStart = DateTime.utc(2026, 1, 15, 10, 0, 0);
      final summerStart = DateTime.utc(2026, 7, 15, 10, 0, 0);
      expect(
        SlotCalc.slotFor(winterStart.add(const Duration(minutes: 45)),
            winterStart, 30),
        SlotCalc.slotFor(summerStart.add(const Duration(minutes: 45)),
            summerStart, 30),
      );
    });
  });

  group('reminderTimes', () {
    test('start + n*interval bis <= end', () {
      final times = SlotCalc.reminderTimes(config);
      expect(times, hasLength(8)); // 10:30, 11:00, ..., 14:00
      expect(times.first, start.add(const Duration(minutes: 30)));
      expect(times.last, end);
    });

    test('Ende mitten im Intervall wird nicht überschritten', () {
      final cfg = EventConfig(
        name: 'Test',
        revealTime: start,
        startTime: start,
        durationH: 1,
        endTime: start.add(const Duration(minutes: 70)),
        checkinIntervalMin: 30,
        checkinWindowMin: 5,
        orgaPhone: '+49',
        serverNow: start,
      );
      final times = SlotCalc.reminderTimes(cfg);
      expect(times, [start.add(const Duration(minutes: 30)), start.add(const Duration(minutes: 60))]);
    });

    test('Event kürzer als ein Intervall -> keine Erinnerungen', () {
      final cfg = EventConfig(
        name: 'Test',
        revealTime: start,
        startTime: start,
        durationH: 1,
        endTime: start.add(const Duration(minutes: 20)), // < 30 min Intervall
        checkinIntervalMin: 30,
        checkinWindowMin: 5,
        orgaPhone: '+49',
        serverNow: start,
      );
      expect(SlotCalc.reminderTimes(cfg), isEmpty);
    });

    test('leer bei ungültigem Intervall', () {
      final cfg = EventConfig(
        name: 'Test',
        revealTime: start,
        startTime: start,
        durationH: 1,
        endTime: end,
        checkinIntervalMin: 0,
        checkinWindowMin: 5,
        orgaPhone: '+49',
        serverNow: start,
      );
      expect(SlotCalc.reminderTimes(cfg), isEmpty);
    });
  });

  group('inCheckinWindow', () {
    test('innerhalb des ersten Fensters', () {
      expect(
        SlotCalc.inCheckinWindow(start.add(const Duration(minutes: 10)), start,
            30, 5),
        isTrue,
      );
    });
    test('außerhalb (nach Fenster)', () {
      expect(
        SlotCalc.inCheckinWindow(start.add(const Duration(minutes: 36)), start,
            30, 5),
        isFalse,
      );
    });
  });

  test('EventConfig.isRunning / isOver / isBeforeReveal', () {
    final cfg = config;
    expect(cfg.isBeforeReveal(start.subtract(const Duration(seconds: 1))), isTrue);
    expect(cfg.isRunning(start.add(const Duration(hours: 1))), isTrue);
    expect(cfg.isOver(end.add(const Duration(seconds: 1))), isTrue);
    expect(cfg.isRunning(end), isFalse);
  });
}
