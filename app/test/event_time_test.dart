import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stepbystep_app/core/event_time.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de_DE', null));

  test('Winter: UTC+1', () {
    final t = DateTime.utc(2026, 1, 15, 10, 25);
    expect(toEventTime(t).hour, 11);
    expect(fmtEventTime(t, 'dd.MM. HH:mm'), '15.01. 11:25');
    expect(eventZoneAbbr(t), 'MEZ');
  });

  test('Sommer: UTC+2', () {
    final t = DateTime.utc(2026, 10, 13, 8, 25);
    expect(toEventTime(t).hour, 10);
    expect(fmtEventTime(t, 'dd.MM. HH:mm'), '13.10. 10:25');
    expect(fmtEventDateTime(t), '13.10. 10:25 Uhr');
    expect(eventZoneAbbr(t), 'MESZ');
  });

  test('Tageswechsel', () {
    final t = DateTime.utc(2026, 7, 1, 22, 30);
    expect(fmtEventTime(t, 'dd.MM. HH:mm'), '02.07. 00:30');
  });
}
