import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Alle angezeigten Uhrzeiten sind Event-Zeit (Europe/Berlin), unabhängig
/// von der Zeitzone des Handys. Nur die Anzeige ist betroffen; Planung und
/// Vergleiche bleiben instant-basiert.
bool _inited = false;

void _ensureInit() {
  if (_inited) return;
  tzdata.initializeTimeZones();
  _inited = true;
}

/// Zeitzone des Events.
tz.Location get berlin {
  _ensureInit();
  return tz.getLocation('Europe/Berlin');
}

/// Der Zeitpunkt [instant] in Berliner Wanduhrzeit.
tz.TZDateTime toEventTime(DateTime instant) =>
    tz.TZDateTime.from(instant, berlin);

/// Formatiert [instant] in Event-Zeit, z. B. `fmtEventTime(t, 'dd.MM. HH:mm')`.
String fmtEventTime(DateTime instant, String pattern) =>
    DateFormat(pattern, 'de_DE').format(toEventTime(instant));

/// "MEZ" (Winter) bzw. "MESZ" (Sommer).
String eventZoneAbbr(DateTime instant) =>
    toEventTime(instant).timeZoneName == 'CEST' ? 'MESZ' : 'MEZ';

/// Datum + Uhrzeit mit Zusatz " Uhr", z. B. `13.10. 10:25 Uhr`.
String fmtEventDateTime(DateTime instant) =>
    '${fmtEventTime(instant, 'dd.MM. HH:mm')} Uhr';
