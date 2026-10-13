# SBS24 – Design-System

Grundlage ist das Logo-Intro (`sbs24_intro.mp4`, 5 s, 1920×1080): eine
gebrochene Stoppuhr-Lünette mit fünf Minuten-Strichen, ein Zeiger, der einmal
herumläuft und die Lünette „zeichnet", dann fährt „SBS" mit Bewegungsunschärfe
von links ein, „24" folgt, ein dünner Ring pulst einmal nach außen. Alles
monochrom: knochenweißes Logo auf fast schwarzem Grund.

## Logo

- Vektorisiert aus dem Video-Frame bei 3,6 s. ViewBox `0 0 840 770`,
  Füllregel `evenodd`, Farbe `#EEEDE6`.
- Web: `dashboard/assets/logo.svg` mit den Gruppen `#arc` (Lünette, 2 Pfade),
  `#ticks` (5 Striche, oben → rechts), `#sbs` (S, B, S), `#num` (2, 4).
- App: `app/lib/brand/logo_paths.dart` (gleiche Gruppen als kodierte Pfadlisten,
  generiert — nicht von Hand ändern).
- Drehpunkt des Zeigers / Mittelpunkt der Lünette: `(441, 386)` im ViewBox.
  Winkel der Striche von dort (0° = 3 Uhr, im Uhrzeigersinn positiv):
  −84°, −58°, −35°, −15°, +3°. Lünette oben: −155°…−84°, unten: +94°…+169°.

## Farben (nur dunkel)

| Token | Wert | Verwendung |
|---|---|---|
| `bg` | `#050605` | Seitenhintergrund |
| `surface` | `#0D0E0D` | Karten, Leisten |
| `surface-2` | `#151715` | Eingaben, Hover, verschachtelte Flächen |
| `line` | `#262826` | Trennlinien, Rahmen |
| `line-strong` | `#3A3C39` | aktive Rahmen, Striche |
| `fg` | `#EEEDE6` | Text, Logo, Primär-Schaltflächen (Füllung) |
| `fg-muted` | `#9A9C95` | Sekundärtext |
| `fg-faint` | `#5E605A` | Platzhalter, deaktiviert |
| `on-fg` | `#050605` | Text auf knochenweißer Füllung |
| `signal` | `#FF453A` | SOS, Gefahr, überfällig |
| `warn` | `#FFB020` | Abbruch, Tempo-Hinweis, Akku niedrig |
| `ok` | `#4ADE80` | aktiv / gesendet / online (sparsam) |
| `info` | `#A5A6FF` | Stumm-Hinweis |

Farbe trägt nur Status. Alles andere ist Schwarz/Weiß/Grau.

## Typografie

Saira (SIL OFL, selbst gehostet – keine Google-Server):
- Display/Überschriften: Saira **800 kursiv**, GROSSBUCHSTABEN, Laufweite
  +0,02 em. Das ist der Charakter des Logos.
- Kennzahlen / Uhrzeiten / Codes: Saira **700 kursiv**, `tabular-nums`.
- Labels: Saira 600, GROSSBUCHSTABEN, 11–12 px, Laufweite +0,12 em, `fg-muted`.
- Fließtext: Saira 400/500.

Web: `dashboard/assets/fonts/saira-*.woff2`. App: `app/assets/fonts/Saira-*.ttf`.

## Motive

- **Stoppuhr-Ring**: Fortschritt (Eventzeit, nächster Check-in, Halte-Taste)
  wird als Lünetten-Bogen mit Strichen gezeigt, nicht als Balken.
- **Striche**: kurze, schräg gestellte Striche als Trenner und Ladeanzeige.
- **Kursive Schräge**: Primär-Schaltflächen und Badges mit leichter
  Schrägstellung (−8°) oder schräg angeschnittenen Ecken.
- Ecken: 4 px (klein), 10 px (Karten). Keine weichen Schatten, sondern
  1-px-Rahmen in `line`.

## Bewegung

Intro-Zeitplan (Referenz, Gesamtdauer 2,6 s; Tippen/Klicken überspringt):

| t (s) | Ereignis | Easing |
|---|---|---|
| 0,00–1,10 | Zeiger (dünne Linie vom Drehpunkt, Länge ≈ Lünettenradius) dreht von −90° einmal im Uhrzeigersinn um 360°; ein konischer Schleier hinter dem Zeiger deckt Lünette + Striche auf (was der Zeiger überstrichen hat, ist sichtbar). Zeiger blendet am Ende aus. | `cubic-bezier(.6,0,.2,1)` |
| 1,05–1,45 | „SBS" fährt von −60 % x herein, Unschärfe 12 px → 0, Deckkraft 0 → 1 | `cubic-bezier(.16,1,.3,1)` (expo-out) |
| 1,40–1,80 | „24" fährt von +40 % x / +10 % y herein, gleiche Unschärfe | expo-out |
| 1,75–2,45 | Ring (Kreis um den Drehpunkt, 1,5 px, `fg` 40 %) skaliert 0,85 → 1,25 und blendet aus | ease-out |
| 2,45–2,60 | Halten; danach weicher Übergang in die Oberfläche | — |

Wiederverwendung im UI:
- Überschriften/Ansichtswechsel: kurzes Einfahren von links (−24 px, Unschärfe
  6 px → 0, 380 ms, expo-out), gestaffelt 40 ms je Element.
- Neuer SOS-Alarm: derselbe Ring-Puls in `signal`, wiederholt, bis quittiert.
- Fortschritts-Ringe zeichnen sich beim Erscheinen per Zeiger-Sweep (600 ms).
- `prefers-reduced-motion` / „Animationen entfernen": keine Bewegung, nur
  Überblendung.
