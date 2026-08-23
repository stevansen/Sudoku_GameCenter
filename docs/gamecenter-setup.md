# Game Center — Konfiguration in App Store Connect

Bestenlisten und Erfolge lassen sich **nicht aus dem Code anlegen**. Diese Datei
ist die Vorlage zum Abtippen in App Store Connect → *Dienste → Game Center*.
Die IDs hier sind verbindlich — der Code referenziert exakt diese Zeichenketten.

Anlegen unter der App `com.sudoku.app`. Alle vier Plattform-Targets teilen sich
dieselbe Game-Center-Konfiguration, wenn sie zur selben App gehören.

---

## Bestenlisten (9)

Alle als **Einzelbestenliste**, Punkteformat *Ganzzahl* bzw. *Zeit*, Sortierung
wie angegeben. Sprachen: Deutsch (Primär) und Englisch.

| ID | Titel (de) | Titel (en) | Sortierung | Format | Aktualisierung |
|---|---|---|---|---|---|
| `com.sudoku.leaderboard.total_points` | Gesamtpunkte | Total Points | Höchster zuerst | Ganzzahl | Bester Wert |
| `com.sudoku.leaderboard.best_time_easy` | Bestzeit Leicht | Best Time Easy | Niedrigster zuerst | Zeit (mm:ss) | Bester Wert |
| `com.sudoku.leaderboard.best_time_medium` | Bestzeit Mittel | Best Time Medium | Niedrigster zuerst | Zeit (mm:ss) | Bester Wert |
| `com.sudoku.leaderboard.best_time_hard` | Bestzeit Schwer | Best Time Hard | Niedrigster zuerst | Zeit (mm:ss) | Bester Wert |
| `com.sudoku.leaderboard.best_time_expert` | Bestzeit Experte | Best Time Expert | Niedrigster zuerst | Zeit (mm:ss) | Bester Wert |
| `com.sudoku.leaderboard.best_time_evil` | Bestzeit Teuflisch | Best Time Evil | Niedrigster zuerst | Zeit (mm:ss) | Bester Wert |
| `com.sudoku.leaderboard.daily` | Tagesrätsel | Daily Puzzle | Höchster zuerst | Ganzzahl | Bester Wert |
| `com.sudoku.leaderboard.weekly_points` | Punkte diese Woche | Points This Week | Höchster zuerst | Ganzzahl | Bester Wert |
| `com.sudoku.leaderboard.streak` | Längste Serie | Longest Streak | Höchster zuerst | Ganzzahl | Bester Wert |

**Wiederkehrende Bestenlisten**: `daily` mit Dauer *1 Tag*, `weekly_points` mit
Dauer *7 Tage*, Startzeitpunkt jeweils 00:00 UTC — passend zum Tagesrätsel, das
seinen Seed aus dem UTC-Datum zieht.

Bestenlisten-Set (optional, aber empfohlen): `com.sudoku.leaderboardset.times`
fasst die fünf Bestzeiten zusammen.

---

## Erfolge (30)

Apple begrenzt die **Summe aller Erfolgspunkte auf 1000** und die Anzahl auf 100.
Diese Liste nutzt **880 Punkte** und lässt bewusst 120 für später frei — das
Limit gilt für die Lebensdauer der App und lässt sich nicht erhöhen.

Alle Erfolge: *nicht ausblendbar* (sichtbar vor dem Erreichen), Ausnahme
`night_owl` und `early_bird` (versteckt, kleine Entdeckungen).

Präfix für alle IDs: `com.sudoku.achievement.`

| ID-Suffix | Titel (de) | Titel (en) | Bedingung | Punkte | Versteckt |
|---|---|---|---|---|---|
| `first_solve` | Erster Erfolg | First Solve | Erstes Sudoku gelöst | 5 | nein |
| `solve_10` | Sammler I | Collector I | 10 Rätsel gelöst | 10 | nein |
| `solve_50` | Sammler II | Collector II | 50 Rätsel gelöst | 20 | nein |
| `solve_250` | Sammler III | Collector III | 250 Rätsel gelöst | 40 | nein |
| `solve_1000` | Sammler IV | Collector IV | 1000 Rätsel gelöst | 75 | nein |
| `easy_master` | Meister: Leicht | Master: Easy | 25 leichte Rätsel | 15 | nein |
| `medium_master` | Meister: Mittel | Master: Medium | 25 mittlere Rätsel | 15 | nein |
| `hard_master` | Meister: Schwer | Master: Hard | 25 schwere Rätsel | 20 | nein |
| `expert_master` | Meister: Experte | Master: Expert | 25 Experten-Rätsel | 25 | nein |
| `evil_master` | Meister: Teuflisch | Master: Evil | 25 teuflische Rätsel | 30 | nein |
| `flawless` | Makellos | Flawless | Gelöst ohne Fehler | 10 | nein |
| `flawless_expert` | Makellos auf Experte | Flawless Expert | Experte ohne Fehler und ohne Hinweis | 35 | nein |
| `no_hints_50` | Eigenständig | On Your Own | 50 Rätsel ohne Hinweis | 30 | nein |
| `speed_easy_180` | Blitz | Flash | Leicht unter 3 Minuten | 10 | nein |
| `speed_hard_600` | Kettenblitz | Chain Lightning | Schwer unter 10 Minuten | 30 | nein |
| `speed_evil_1800` | Unmenschlich | Inhuman | Teuflisch unter 30 Minuten | 60 | nein |
| `streak_7` | Serie I | Streak I | 7 Tage in Folge | 20 | nein |
| `streak_30` | Serie II | Streak II | 30 Tage in Folge | 45 | nein |
| `streak_365` | Serie III | Streak III | 365 Tage in Folge | 90 | nein |
| `first_daily` | Tagesform | Daily Habit | Erstes Tagesrätsel gelöst | 5 | nein |
| `daily_10` | Tagesrätsel-Fan I | Daily Fan I | 10 Tagesrätsel gelöst | 15 | nein |
| `daily_100` | Tagesrätsel-Fan II | Daily Fan II | 100 Tagesrätsel gelöst | 50 | nein |
| `night_owl` | Nachteule | Night Owl | Rätsel zwischen 0 und 4 Uhr gelöst | 5 | **ja** |
| `early_bird` | Frühaufsteher | Early Bird | Rätsel vor 6 Uhr gelöst | 5 | **ja** |
| `points_10k` | Punktejäger I | Point Hunter I | 10.000 Gesamtpunkte | 35 | nein |
| `points_100k` | Punktejäger II | Point Hunter II | 100.000 Gesamtpunkte | 80 | nein |
| `all_platforms` | Überall zu Hause | At Home Everywhere | Je ein Rätsel auf iPhone, iPad und Mac | 20 | nein |
| `comeback` | Fortsetzung folgt | To Be Continued | Partie auf einem anderen Gerät beendet | 10 | nein |
| `technique_xwing` | Fischer | Fisherman | Rätsel gelöst, das ein X-Wing erforderte | 25 | nein |
| `perfect_week` | Perfekte Woche | Perfect Week | 7 Tage in Folge je ≥ 1 Rätsel ohne Fehler | 45 | nein |

**Summe: 880 / 1000.** Vor jeder Erweiterung nachrechnen.

Für jeden Erfolg braucht App Store Connect ein **Bild, 512 × 512 px, PNG oder
JPEG, ohne Alphakanal**. Siehe [assets-spec.md](app-store/assets-spec.md).

---

## Umsetzung im Code

- IDs als `enum` mit `String`-Rohwerten in `SudokuGameCenter`, damit ein Tippfehler
  ein Compilerfehler ist.
- Fortschritt über `GKAchievement.percentComplete`, gebündelt gemeldet.
- Fehlgeschlagene Meldungen lokal in eine Warteschlange, beim nächsten
  erfolgreichen Login nachreichen.
- Erfolgsstand zusätzlich lokal spiegeln — für die Offline-Anzeige und damit nach
  einer Neuinstallation nichts doppelt gemeldet wird.
- `technique_xwing` ist nur möglich, weil der logische Solver protokolliert,
  welche Techniken ein Rätsel erzwungen hat.
