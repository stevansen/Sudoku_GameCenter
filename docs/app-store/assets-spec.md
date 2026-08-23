# Grafiken — was gebraucht wird

Apple ändert die geforderten Größen gelegentlich. Diese Tabellen sind der Stand
2026-08; **vor dem Upload in App Store Connect gegenprüfen**, dort stehen die
jeweils gültigen Werte am Upload-Feld.

## App-Symbol

| Verwendung | Größe | Format |
|---|---|---|
| App Store (alle Plattformen) | 1024 × 1024 | PNG, **ohne Alphakanal**, keine runden Ecken, sRGB oder Display P3 |
| iOS / iPadOS / macOS / watchOS | 1024 × 1024 im Asset-Katalog | Xcode leitet alle weiteren Größen ab |
| tvOS | geschichteter Bildstapel, 1280 × 768 | mindestens 2 Ebenen für den Parallaxe-Effekt |
| tvOS Top Shelf | 1920 × 720 (und 4640 × 1440 für breit) | PNG |

Runde Ecken, Schlagschatten oder ein Alphakanal führen zur automatischen
Zurückweisung beim Upload.

## Screenshots

Pro Sprache und Gerätefamilie sind bis zu 10 möglich; **mindestens einer ist
Pflicht**, empfohlen sind drei bis fünf. Apple skaliert von der größten Größe auf
kleinere Geräte herunter — es reicht also je Familie ein Satz.

| Gerätefamilie | Größe (Hochformat) | Pflicht |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 oder 1290 × 2796 | ja |
| iPad 13" | 2064 × 2752 oder 2048 × 2732 | ja, wenn iPad unterstützt |
| Mac | 2880 × 1800 (16:10) | ja, wenn macOS unterstützt |
| Apple TV | 3840 × 2160 oder 1920 × 1080 | ja, wenn tvOS unterstützt |
| Apple Watch | 410 × 502 (46 mm) | ja, wenn watchOS unterstützt |

Vorschlag für die fünf Motive, in dieser Reihenfolge:

1. **Das Brett mitten im Spiel** — Notizen sichtbar, Ziffernblock, laufende Zeit.
2. **Ein Hinweis, der die Technik erklärt** — das Alleinstellungsmerkmal.
3. **Die Stufenauswahl** mit den fünf Stufen und ihrer Beschreibung.
4. **Die Punkte-Aufschlüsselung** nach dem Lösen.
5. **Dasselbe Spiel auf iPhone und Mac** nebeneinander — der Cross-Device-Punkt.

Keine Platzhalter-Statusleiste, keine Simulator-Artefakte, kein Text, der etwas
verspricht, was die App nicht tut.

## Erfolgs-Bilder (Game Center)

**30 Stück, je 512 × 512 px, PNG oder JPEG, ohne Alphakanal.** Ohne sie lässt
sich die Game-Center-Konfiguration nicht einreichen. Die Liste der Erfolge steht
in [gamecenter-setup.md](../gamecenter-setup.md).

Bestenlisten-Bilder sind optional, ebenfalls 512 × 512.

## App-Vorschau (Video, optional)

15 bis 30 Sekunden, dieselbe Auflösung wie die Screenshots der jeweiligen
Familie, aufgenommen vom echten Gerät. Bis zu drei pro Familie und Sprache.
