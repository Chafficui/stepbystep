# stepbystep

## 1. Überblick

stepbystep ist ein Tracking-MVP für ein 24-stündiges Gruppen-Walking-Event. Die Teilnehmer-App zeichnet die Route des Teams im Hintergrund auf — erst lokal, dann als Batch-Upload —, Check-ins werden per Foto/Video dokumentiert und ein SOS-Knopf löst einen Alarm auf dem Orga-Dashboard aus. Die Rangliste wird nach der Luftlinie zum Startpunkt berechnet; Teilnehmer sehen dabei nur ihren eigenen Platz, nicht die Werte anderer Teams.

| Komponente | Technologie | Ort |
| --- | --- | --- |
| Teilnehmer-App (Android/iOS, deutsche UI) | Flutter | `app/` |
| API | Node/TypeScript/Fastify (interner Port 8080) | `server/` |
| Orga-Dashboard | Eine HTML-Datei (+ Logo/Schrift in `dashboard/assets/`), Leaflet via jsdelivr-CDN, vom Server unter `/` ausgeliefert; Ansichten Live · Teams · Rangliste · Einstellungen | `dashboard/index.html` |
| Deployment | docker-compose (Prod: db/api/caddy), Caddy mit Let's Encrypt | `deploy/` |
| Design-System (Logo, Farben, Schrift, Animationen) | Saira (SIL OFL), Logo aus dem Intro vektorisiert | `BRAND.md` |
| Betriebsskripte | Backup, Seed, Datenlöschung | `scripts/` |

## 2. Voraussetzungen

- Linux-VPS mit **Docker** und **docker compose**.
- Eine **Subdomain**, deren A-Record auf die IP des VPS zeigt. Das ist der erste Schritt — ohne funktionierendes DNS kann Caddy kein Let's-Encrypt-Zertifikat holen.
- Zum Bauen der App: **Flutter SDK** (aktuelle stabile Version) auf dem eigenen Rechner.

## 3. Server installieren

```bash
git clone <repo> && cd stepbystep
cp deploy/.env.example deploy/.env   # Compose liest deploy/.env automatisch
nano deploy/.env
```

In `deploy/.env` setzen:

- `DOMAIN=event.example.com`
- `POSTGRES_*` — eigenes Passwort wählen
- `ORGA_PASSWORD` — starkes Passwort für das Dashboard
- `ORGA_SESSION_SECRET` — z. B. mit `openssl rand -hex 32` erzeugen

Dann starten:

```bash
docker compose -f deploy/docker-compose.yml up -d --build
curl https://<DOMAIN>/healthz    # {"status":"ok"}
```

Beim ersten Start laufen die SQL-Migrationen automatisch. Die Logs der API sieht man mit:

```bash
docker compose -f deploy/docker-compose.yml logs -f api
```

Hinweis: Die Ports **80/443** müssen in der Firewall des VPS-Hosters offen sein. Datenbank und API sind nur im internen Docker-Netz erreichbar, nach außen exponiert ausschließlich Caddy.

## 4. Event einrichten

Das Dashboard unter `https://<DOMAIN>/` öffnen und mit `ORGA_PASSWORD` anmelden. Unter **„Einstellungen"** (Seitenleiste bzw. Tab-Leiste auf dem Handy) konfigurieren:

| Einstellung | Bedeutung |
| --- | --- |
| Name | Name des Events |
| Startpunkt (lat/lng) | Geografischer Startpunkt |
| `reveal_time` | Ab diesem Zeitpunkt sehen Teilnehmer den Startpunkt |
| `start_time` | Offizieller Start des Events |
| `duration_h` | Dauer in Stunden (24) |
| `checkin_interval_min` | Abstand der Pflicht-Check-ins (300 = alle 5 Stunden) |
| `checkin_window_min` | Fenster um den Check-in-Zeitpunkt (30) |
| `silence_alarm_min` | Zeitfenster, in dem ein Alarm stumm bleibt (360) |
| `speed_flag_kmh` | Geschwindigkeit, ab der ein Team markiert wird (12) |
| `orga_phone` | Telefonnummer, die der SOS-Knopf als Anruf-Link nutzt |

Alle Einstellungen sind ohne Neubau der App änderbar. Teams werden in der Ansicht **„Teams"** über **„Team anlegen"** angelegt; der generierte Code (8 Zeichen, ohne `0/O/1/I`) wird an das Team weitergegeben.

Für einen Testlauf alternativ:

```bash
./scripts/seed_test_event.sh
```

Das setzt die Startzeit auf +15 Minuten und legt die Teams `TESTAAAA` und `TESTBBBB` an; mit `--dev` wird die Dev-Compose verwendet.

In der Teilnehmer-App über **„Team beitreten"** mit Code + Name einloggen; pro Team sind maximal 2 Geräte möglich. Vor dem Eventstart muss jedes Team ein **Teamfoto** aufnehmen (einmal pro Team); es erscheint im Dashboard als Pin auf der Karte und in der App als eigener Positions-Pin. Die Orga kann ein Foto in der Team-Schublade zurücksetzen. Sind App-Daten verloren gegangen, entfernt die Orga den Teilnehmer im Dashboard, danach ist ein Neubeitritt möglich.

## 5. App bauen und verteilen

Das Flutter-Projekt wurde ohne installierte Flutter-Toolchain erstellt. Daher einmalig:

```bash
cd app
flutter create . --platforms=android,ios   # ergänzt fehlende Plattformdateien, vorhandene bleiben
flutter pub get
dart run build_runner build -d            # drift-Datenbankcode generieren
flutter analyze && flutter test
```

Danach die Release-APK bauen:

```bash
flutter build apk --release --dart-define=API_URL=https://<DOMAIN>
```

Die APK liegt unter `build/app/outputs/flutter-apk/` und lässt sich per USB oder Link verteilen. Auf den Geräten muss „Unbekannte Quellen"/Sideloading erlaubt werden (ab Android 8 wird pro App gefragt).

Für iOS ist ein Apple-Developer-Account nötig; Verteilung über TestFlight oder Kabel-Installation. Hintergrund-Location ist nur auf echten Geräten testbar — der Simulator ist ungeeignet.

Hinweis: Erst wenn `flutter analyze` und `flutter test` sauber durchlaufen, bauen — der Code wurde ohne Toolchain geschrieben (siehe `DECISIONS.md`).

## 6. Lokaler Test ohne VPS

```bash
docker compose -f deploy/docker-compose.dev.yml up -d --build
./scripts/seed_test_event.sh --dev
```

- API/DB ohne TLS, API auf `http://<Rechner-IP>:8080`, DB auf `localhost:5433` (Passwort: `dev`).
- Debug-App im gleichen WLAN: `flutter run --dart-define=API_URL=http://<LAN-IP>:8080` — nur Debug-Builds erlauben HTTP, Release-Builds ausschließlich HTTPS.
- Dashboard: `http://localhost:8080/`.

## 7. Backup & Restore

`scripts/backup.sh` erstellt ein datiertes Archiv `stepbystep-backup-<Datum>.tar.gz` (DB-Dump via pg_dump + hochgeladene Check-in-Medien) unter `/var/backups/stepbystep/` (per `BACKUP_DIR` änderbar) und behält die 72 neuesten Archive.

Stündlicher Cron:

```
0 * * * * /pfad/zum/repo/scripts/backup.sh >> /var/log/stepbystep-backup.log 2>&1
```

Kopien außerhalb des VPS per rsync (Beispiel im Skriptkommentar). Restore-Skizze: Archiv entpacken, `psql`-Dump in die Datenbank einspielen, Uploads ins Volume zurückkopieren.

## 8. Datenschutz & Datenlöschung

- Positions-, Check-in- und Alarmdaten sehen nur das eigene Team und die Orga.
- Kilometerangaben erscheinen nur im Orga-Dashboard.
- Der Startpunkt ist serverseitig erst ab `reveal_time` für Teilnehmer sichtbar.
- Mediendateien liegen außerhalb des Webroots; Dateinamen werden serverseitig generiert.

Nach dem Event alle Daten löschen:

```bash
./scripts/delete_event_data.sh --yes
```

Das entfernt alle Positions-, Check-in- und Alarmdaten inklusive Medien. Das `--yes` ist nötig, sonst tut das Skript nichts.

## 9. Hersteller-Einstellungen für zuverlässiges Hintergrund-Tracking

Viele Hersteller beenden Hintergrunddienste aggressiv. Für zuverlässiges Tracking:

- **Xiaomi:** Akku-Sparmodus für die App auf „Keine Einschränkungen", App-Autostart erlauben, Energieverbrauch im Hintergrund erlauben.
- **Huawei:** App als „Geschützte App" markieren bzw. App-Launch manuell verwalten.
- **Samsung:** Akku → Hintergrundverbrauch → für die App „Uneingeschränkt".
- **Allgemein:** Akku-Optimierung für die App deaktivieren (wird im Onboarding angefragt) und die Dauernotifikation „Tracking läuft" nicht wegwischen.

Ehrlicher Hinweis: Das Hintergrund-Verhalten muss auf echten Geräten geprüft werden (siehe `TESTPLAN.md`, Punkte 2 und 4) — die App wurde in dieser Umgebung nur geschrieben, nie auf einem Gerät ausgeführt.

## 10. API-Übersicht

**Teilnehmer** (Bearer-Gerätetoken):

| Endpoint | Zweck |
| --- | --- |
| `POST /api/join` | Mit Team-Code + Name beitreten, liefert Gerätetoken |
| `GET /api/event` | Öffentliche Event-Konfiguration abrufen |
| `GET /api/me` | Eigene Teilnehmer-/Teamdaten abrufen |
| `POST /api/points/batch` | Aufgezeichnete Route als Batch hochladen |
| `POST /api/checkins` | Check-in (inkl. Foto/Video) einreichen |
| `POST /api/alerts` | SOS-Alarm auslösen |
| `GET /api/my-rank` | Eigener Platz in der Rangliste |

**Orga** (Bearer-Sitzungstoken):

| Endpoint | Zweck |
| --- | --- |
| `POST /api/orga/login` | Mit `ORGA_PASSWORD` anmelden, Sitzungstoken erhalten |
| `GET /api/orga/event` / `PUT /api/orga/event` | Event-Einstellungen lesen/ändern |
| `GET /api/orga/teams` / `POST /api/orga/teams` | Teams auflisten/anlegen |
| `DELETE /api/orga/teams/:id` | Team endgültig löschen (inkl. Positions-, Check-in- und Alarmdaten sowie Mediendateien) |
| `DELETE /api/orga/teams/:id/participants/:pid` | Teilnehmer aus Team entfernen (Neubeitritt ermöglichen) |
| `GET /api/orga/overview` | Live-Übersicht aller Teams |
| `GET /api/orga/track` | Aufgezeichnete Route eines Teams abrufen |
| `GET /api/orga/checkins` | Eingereichte Check-ins auflisten |
| `GET /api/orga/media/:id` | Check-in-Medium (Foto/Video) ausliefern |
| `POST /api/orga/alerts/:id/resolve` | Alarm als bearbeitet markieren |
| `POST /api/orga/ranking` / `GET /api/orga/ranking` | Rangliste berechnen/abrufen |

**Ohne Auth:**

| Endpoint | Zweck |
| --- | --- |
| `GET /healthz` | Health-Check |

## 11. Troubleshooting

- **Zertifikat schlägt fehl:** DNS-A-Record prüfen; sind die Ports 80/443 offen?
- **App verbindet nicht:** `API_URL` im `--dart-define` prüfen; Release-Builds verlangen HTTPS.
- **Dashboard bleibt leer:** Browserkonsole prüfen (CSP? CDN erreichbar?) und Login-Daten kontrollieren.
- **Container-Logs:** `docker compose -f deploy/docker-compose.yml logs -f api`
- **Datenbank:** `docker compose -f deploy/docker-compose.yml exec db psql -U <POSTGRES_USER> <POSTGRES_DB>`

## Weiterführend

- `TESTPLAN.md` — manuelles Testprotokoll
- `DECISIONS.md` — getroffene Entscheidungen
