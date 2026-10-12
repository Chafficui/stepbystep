# Manueller Testplan – Walking-Event-Tracking (MVP)

**Dauer:** ca. 24 Stunden · **Teilnehmende:** 2–6 Zwei-Personen-Teams · **Geräte:** 2 Android-Handys (idealerweise verschiedene Hersteller), Orga-Laptop

> **Wichtig – Zeiten:** Alle Zeiten in der App sind lokale Zeit; der Server rechnet UTC.
> Eine Uhrzeit-Drift > 60 s erzeugt in der App eine Warnung – **Handy-Uhr auf „automatisch" stellen**
> (Datum & Uhrzeit → automatisch/einstellen über Netzwerk)!

**Ausfüllen:** Pro Abschnitt „Ergebnis" (✓ bestanden / ✗ fehlgeschlagen) und „Notizen" ausfüllen.
Bei ✗: Gerätemodell, App-Version, Uhrzeit und beobachtetes Verhalten notieren.

---

## Vorbereitung

1. **Testevent anlegen** – auf dem Server ausführen:
   `./scripts/seed_test_event.sh`
   (setzt Event: `reveal_time` = jetzt, `start_time` in 15 Min., 24 Std. Dauer,
   Check-in alle 300 Min. – **Orga-Telefonnummer eintragen!**)
   Alternativ: im Dashboard unter „Event-Einstellungen" manuell setzen.
   Die Teams **TESTAAAA** und **TESTBBBB** sind angelegt.
2. **Geräte:** Zwei Android-Handys (verschiedene Hersteller ideal), voll geladen,
   ggf. Powerbank mitführen; Orga-Laptop mit geöffnetem Dashboard.
3. **Handy-Einstellungen:** Akku-Optimierung für die App **aus** (wird im Onboarding angefragt);
   Hersteller-spezifische Einstellungen laut README Abschnitt „Risiken"
   (Autostart/Hintergrundlauf zulässig, Akku-Optimierung für die App deaktivieren).
4. **Handy-Uhr** auf „automatisch" stellen (siehe Hinweis oben).
5. Startzeit des Tests notieren: **Uhrzeit: ________ Datum: ________**

---

## 1. Beitritt

| # | Schritt | Erwartetes Ergebnis |
|---|---------|---------------------|
| 1.1 | Mit **richtigem** Code beitreten | Team erscheint, Warteraum mit Countdown wird angezeigt |
| 1.2 | Mit **falschem** Code beitreten | Verständliche Fehlermeldung: „Team-Code unbekannt" |
| 1.3 | Zweites Gerät mit **gleichem** Code beitreten | 2. Teilnehmer tritt ein (Team voll mit 2 Personen) |
| 1.4 | **Dritter** Beitritt mit gleichem Code | Abgelehnt: „Team bereits voll" |
| 1.5 | App neu starten (Taskleiste/Neustart) | Teamzugehörigkeit bleibt erhalten (kein erneutes Eingeben des Codes) |
| 1.6 | Orga entfernt im Dashboard einen Teilnehmer → Neubeitritt | Neuer Beitritt mit demselben Code ist wieder möglich |

**Ergebnis:** ________
**Notizen:** ________

---

## 2. Hintergrund-Tracking

| # | Schritt | Erwartetes Ergebnis |
|---|---------|---------------------|
| 2.1 | Tracking starten, Display **sperren**, 30 Min. gehen | – |
| 2.2 | Im Dashboard die Spur des Teams prüfen | Spur vorhanden und **weitgehend lückenlos** (kleine Lücken möglich; keine Interpolation, aber **keine 30-Minuten-Lücke**) |
| 2.3 | am Handy auf die Dauernotifikation schauen | Benachrichtigung „Tracking läuft" ist sichtbar |

**Ergebnis:** ________
**Notizen:** ________

---

## 3. Offline-Nachlieferung

| # | Schritt | Erwartetes Ergebnis |
|---|---------|---------------------|
| 3.1 | **Flugmodus** an, 20 Min. weitergehen | – |
| 3.2 | In der App den Zähler „ungesendete Punkte" beobachten | Zähler **steigt** an |
| 3.3 | Netz wieder an (Flugmodus aus) | Zähler **fällt auf 0** |
| 3.4 | Dashboard-Prüfung | Alle im Flugmodus gesammelten Punkte erscheinen in der Spur |

**Ergebnis:** ________
**Notizen:** ________

---

## 4. App-Tötung

| # | Schritt | Erwartetes Ergebnis |
|---|---------|---------------------|
| 4.1 | App aus dem **„Letzte Apps"-Bereich wischen** (nicht nur schließen!) | – |
| 4.2 | **Android:** auf Dauernotifikation prüfen | Tracking läuft weiter (Benachrichtigung „Tracking läuft" bleibt) |
| 4.3 | **iOS:** (ggf. pausiert) App neu starten | Tracking nimmt automatisch fort; Flag „Tracking aktiv" lokal gesetzt |

**Ergebnis:** ________ (Gerät/OS: ________)
**Notizen:** ________

---

## 5. Check-ins (Foto & Video)

| # | Schritt | Erwartetes Ergebnis |
|---|---------|---------------------|
| 5.1 | Check-in: **Foto** aufnehmen | Foto wird angenommen/gesendet |
| 5.2 | Check-in: **Video** aufnehmen (max. 15 s) | Video wird angenommen/gesendet; Aufnahme endet nach spätestens 15 s |
| 5.3 | Prüfen der Medienquelle | **Nur Kamera** wählbar, **keine Galerie** |
| 5.4 | Check-in **im Flugmodus**: Foto + Video | Medien landen in der Warteschlange, Status „wird gesendet" |
| 5.5 | Netz an | Upload erfolgt automatisch; Medien erscheinen in der **Dashboard-Galerie** |

**Ergebnis:** ________
**Notizen:** ________

---

## 6. SOS

| # | Schritt | Erwartetes Ergebnis |
|---|---------|---------------------|
| 6.1 | SOS-Knopf **kürzer als 2 Sek.** drücken | Nichts passiert (kein Alarm) |
| 6.2 | SOS-Knopf **2 Sek.** gedrückt halten | Alarm wird ausgelöst |
| 6.3 | Anruf-Link öffnen | Anruf zur hinterlegten **Orga-Nummer** wird vorbereitet/geöffnet |
| 6.4 | Dashboard beobachten | **Roter SOS-Alarm** mit **Signalton** + **blinkendem Titel** |
| 6.5 | Im Dashboard „**Erledigt**" klicken | Alarm quittiert, Warnung verschwindet |
| 6.6 | SOS **im Flugmodus** auslösen | App zeigt klar „**gespeichert – wird gesendet**" |
| 6.7 | Netz zurück | SOS sendet sich automatisch nach |
| 6.8 | „**Aufgeben und abholen lassen**" drücken | **Bestätigungsdialog** erscheint |
| 6.9 | Bestätigen | Teamstatus im Dashboard wird „**abgebrochen**" |

**Ergebnis:** ________
**Notizen:** ________

---

## 7. Akkuverbrauch

| # | Schritt | Erwartetes Ergebnis |
|---|---------|---------------------|
| 7.1 | Akkustand beim Start notieren, 2 Std. Tracking bei **gesperrtem Display** | – |
| 7.2 | Akkustand nach 2 Std. notieren | Verbrauch wird protokolliert (kein festes Limit; unplausible Werte notieren) |

| Gerät (Hersteller/Modell) | Akku Start (%) | Akku Ende (%) | Verbrauch in 2 Std. (%) | Einstellungen (Akku-Opt. aus? Autostart?) |
|---|---|---|---|---|
| ________ | ________ | ________ | ________ | ________ |
| ________ | ________ | ________ | ________ | ________ |

**Ergebnis:** ________
**Notizen:** ________

---

## 8. Dashboard-Gesamtprüfung

| # | Schritt | Erwartetes Ergebnis |
|---|---------|---------------------|
| 8.1 | Teamliste prüfen | **Letzter Punkt**, **Akku**, **letzter Check-in** pro Team angezeigt |
| 8.2 | Hinweis „**Still**" prüfen (nach `silence_alarm_min = 360 Min.` ohne Punkt + Check-in) | Hinweis erscheint, wenn Schwelle unterschritten. **Im Test verkürzt prüfen:** Parameter in den Event-Einstellungen des Dashboards vorübergehend senken (z. B. auf 10–15 Min.) und danach zurücksetzen! |
| 8.3 | Hinweis „**Check-in überfällig**" prüfen | Erscheint, wenn der Check-in-Termin verstrichen ist (ggf. Check-in-Intervall in den Event-Einstellungen ebenfalls verkürzen) |
| 8.4 | Hinweis „**Geschwindigkeitsverdacht**" prüfen | Kurze Autofahrt **> 12 km/h** (z. B. 500 m mit dem Auto) erzeugt den Verdachtshinweis |
| 8.5 | Rangliste in der **App** aktualisieren | App zeigt **nur Platz** („Platz X von Y"), **nie Kilometer** |
| 8.6 | Rangliste im **Dashboard** aktualisieren | Dashboard zeigt **Kilometer** |

> **Hinweis:** Die Hinweis-Parameter (`silence_alarm_min` usw.) können in den Event-Einstellungen
> des Dashboards für einen schnelleren Test **temporär gesenkt** werden – danach zurücksetzen!

**Ergebnis:** ________
**Notizen:** ________

---

## 9. Server-Neustart

| # | Schritt | Erwartetes Ergebnis |
|---|---------|---------------------|
| 9.1 | Sicherstellen, dass die App trackt → auf dem VPS: `docker compose -f deploy/docker-compose.yml restart` | – |
| 9.2 | Nach dem Neustart die App prüfen | App weiter aktiv („Tracking aktiv"), keine Abmeldung |
| 9.3 | Weitere Punkte sammeln und im Dashboard prüfen | Punkte werden weiter hochgeladen, **keine Daten verloren** (keine Lücke über den Neustart) |
| 9.4 | Health-Endpunkt prüfen (`/healthz`) | Wieder **ok** |

**Ergebnis:** ________
**Notizen:** ________

---

## 10. Nach dem Test (Aufräumen & Backup)

| # | Schritt | Erwartetes Ergebnis |
|---|---------|---------------------|
| 10.1 | Auf dem Server: `scripts/delete_event_data.sh --yes` | Alle Positions-, Check-in- und Alarmdaten **+ Medien** gelöscht; Teams/Teilnehmer entfernt |
| 10.2 | Prüfen, dass das Testevent keine Daten mehr hat | Dashboard zeigt leeres/gegelöschtes Event |
| 10.3 | Backup einmalig **manuell** laufen lassen (`scripts/backup.sh`) | Backup läuft ohne Fehler durch |
| 10.4 | Archiv prüfen | Backup-Archiv vorhanden, Größe plausibel, entpackbar |

**Ergebnis:** ________
**Notizen:** ________

---

## Gesamtergebnis

| Abschnitt | Ergebnis (✓/✗) | Abschnitt | Ergebnis (✓/✗) |
|---|---|---|---|
| 1 Beitritt | ________ | 6 SOS | ________ |
| 2 Hintergrund-Tracking | ________ | 7 Akkuverbrauch | ________ |
| 3 Offline-Nachlieferung | ________ | 8 Dashboard-Gesamtprüfung | ________ |
| 4 App-Tötung | ________ | 9 Server-Neustart | ________ |
| 5 Check-ins | ________ | 10 Nach dem Test | ________ |

**Gesamt:** ________
**Tester / Datum:** ________
