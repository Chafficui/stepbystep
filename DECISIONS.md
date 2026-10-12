# Entscheidungen (MVP)

| Bereich | Entscheidung | Begründung |
|---|---|---|
| Lokale Entwicklung / TLS | Separate `docker-compose.dev.yml` ohne Caddy; HTTP nur für Debug-Builds erlaubt (Debug-Manifest), Release-Builds ausschließlich HTTPS | So ist der MVP ohne VPS/Domain testbar, während die Produktion verschlüsselt bleibt. |
| Orga-Sitzung | Stateless: HMAC-signiertes Token aus `ORGA_SESSION_SECRET`, 24 h Gültigkeit, keine Session-Tabelle | Einfacher und überlebt Server-Neustarts. |
| Dashboard-Rendering | Eine Datei mit Inline-Script, deshalb CSP `script-src 'unsafe-inline'`; strikt kein `innerHTML` — alle Nutzereingaben (Team-/Teilnehmernamen) nur per `textContent` | Vom Auftrag gefordert (eine Datei mit Inline-Script), ohne XSS-Angriffsfläche durch Nutzerdaten zu öffnen. |
| GPX-Export | Nicht umgesetzt | Im Auftrag nur optional („falls Zeit bleibt") und das Wire-Risiko im MVP wäre höher als der Nutzen. |
| Push-Nachrichten | Kein FCM/APNs; Check-in-Erinnerungen als lokale Benachrichtigungen (`inexactAllowWhileIdle`, ohne Exact-Alarm-Berechtigung) | Auftragsausschluss; lokale Erinnerungen erfüllen den Zweck ohne externen Push-Dienst. |
| Team-Codes | 8 Zeichen aus Alphabet ohne 0/O/1/I (`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`), serverseitig generiert | Verwechselungssicher (kein L/O, keine 0/1) und tippsicher (≈ 10¹² Kombinationen). |
| Rate-Limit | 10/Min./IP auf Join und Orga-Login, `trustProxy: true` | Hinter Caddy zählt so die echte Client-IP statt der Proxy-IP, sonst würden alle Nutzer einen gemeinsamen Zähler teilen. |
| Punkte-Upload | Unbestätigte Punkte werden endlos wiederholt (Backoff bis 30 Min.), nie verworfen; serverseitig werden nur >5 Min. in der Zukunft liegende Punkte übersprungen (Uhren-Drift-Schutz), der Client wiederholt sie dann erneut | Datenverlust-Schutz hat Vorrang vor Effizienz, und der 5-Minuten-Filter verhindert, dass Drift-Punkte die Historie verfälschen. |
| Idempotenz | Überall: jede Punkt-/Check-in-/Alarm-Nachricht trägt eine client-erzeugte UUID; der Server ignoriert Bekannte | Wiederholte Uploads sind dadurch ungefährlich (Retries, Neustarts, Mehrfach-Zustellungen). |
| Wiederbeitritt | Über gespeicherte `device_id` idempotent; der Server meldet immer das tatsächliche Team des Teilnehmers zurück, selbst wenn ein anderer Code eingegeben wurde; verlorene App-Daten: Orga entfernt den Teilnehmer im Dashboard → Neubeitritt möglich | Doppelte Teams werden vermieden und ein Datenverlust auf dem Gerät ist ohne Support-Eingriff heilbar. |
| Herzschlag-Punkte | Alle 5 Minuten mit aktuellem Zeitstempel (nicht der ursprünglichen Position) | Sonst wären Standstill-Punkte falsch datiert. |
| Bewegungsfilter | Punkt ab 15 m seit letztem akzeptierten Punkt; Genauigkeit >100 m wird verworfen, außer seit >10 Min. gab es keinen besseren Punkt | Balance aus Datenmenge und Lückenlosigkeit. |
| Check-in-Intervall | 300 Minuten (= 5 Std.) als Standard, jederzeit im Dashboard änderbar, ohne App-Neubau | So im Auftrag als Standard definiert („alle paar Stunden") und ohne Store-Release anpassbar. |
| Nicht umgesetzte Features | Kein Story-Export, kein Chat, keine Navigation, keine Offline-Kacheln, keine Drittanbieter-Cloud | Auftragsausschlüsse, konsequent nicht umgesetzt. |
| Speeding-Hinweis | Gleitendes Fenster ≥10 Min., > `speed_flag_kmh`, Punkte mit Genauigkeit >100 m ignoriert; nur eine Information für die Orga, keine automatische Sanktion | GPS-Artefakte erzeugen sonst Fehlbeschuldigungen, und die Bewertung bleibt beim Menschen. |
| App-Toolchain | App-Projekt ohne Flutter-Toolchain handgeschrieben und deshalb nicht lokal analysiert; erster Schritt beim Menschen ist `flutter create .` + `build_runner` | Ehrliche Trennung: „automatisiert getestet" (Server-Unit-Tests) vs. „nur gebaut/analysiert" (App, Integrationstests) vs. „ungetestet" (Geräte/VPS). |
| Uhrzeit-Drift | Drift >60 s erzeugt nur eine Warnung („Uhrzeit des Handys prüfen"), keine Blockierung | Blockieren könnte Teilnehmer im Feld aussperren. |
| Server-Integrationstests | Laufen nur mit Docker (in der Build-Umgebung nicht verfügbar, daher übersprungen) | Die Testsuite ist vollständig vorhanden und muss auf dem VPS/einer Docker-Maschine einmal ausgeführt werden. |
| Referrer-Policy | `strict-origin-when-cross-origin` statt `no-referrer` (Server-Header und Caddyfile) | OSM-Kachelserver verlangen eine Identifizierung per Referer oder User-Agent und blocken ohne Referer („usage policy") — Origin statt voller URL genügt. |
| Ranking leer | `GET /api/orga/ranking` liefert bei leerer Rangliste `200` mit `computed_at: null` statt `404` | Verhindert wiederkehrende Konsolen-Fehler beim Laden des Dashboards; semantisch keine Abwesenheit einer Ressource. |

## Offene Punkte / bekannte Einschränkungen

- `delete_event_data.sh` meldet sich auf Englisch (Code-Konvention), erwünscht falls Deutsch gewünscht wird.
- Videos: `image_picker` 1.1.x bietet keinen Parameter für die Videoauflösung; Ziel <5 MB über 15 s Standard-Auflösung, ggf. auf Geräten prüfen.
- iOS-Hintergrund-Location und Hersteller-Speicherplatz (Xiaomi/Huawei/Samsung) sind nur auf echten Geräten verifizierbar (siehe TESTPLAN).
- Der Flutter-Code wurde nie kompiliert (keine Toolchain in der Build-Umgebung) — vor dem Testlauf zwingend `flutter analyze && flutter test` ausführen und Fehler fixen.
- Server-Integrationstests sind in der Build-Umgebung nicht gelaufen (siehe Tabelle) — vor dem Livegang auf einer Docker-Maschine ausführen.
