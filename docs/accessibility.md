# Barrierefreiheit — Prüfprotokoll

Stand 2026-08-23, Meilenstein 6. Geprüft gegen Apples Richtlinien und die
üblichen WCAG-Kriterien, soweit sie auf eine native App zutreffen.

## Behoben

| Punkt | Vorher | Jetzt |
|---|---|---|
| **Fehler nur über Farbe** | Falsche Ziffer rot auf rotem Grund | Zusätzlich ein Dreieck in der Zellenecke — Form trägt die Information mit |
| **VoiceOver kennt die Position nicht** | Zelle las nur „5, eingetragen“ | `accessibilityValue` nennt Zeile und Spalte |
| **Ziffernblock ignoriert Textgröße** | Feste 28 pt | Skaliert mit `.title2` und der Systemeinstellung |
| **Englisch fehlte vollständig** | Nur Deutsch, obwohl der Store-Text Englisch verspricht | 76 Strings in beiden Sprachen, per Test abgesichert |

Zur Farbmarkierung: Rot auf Grau ist für rot-grün-blinde Menschen unsichtbar,
und das betrifft etwa jeden zwölften Mann. Ein Sudoku, das einem nichts über
seine Fehler sagt, ist ein anderes, schlechteres Spiel.

## Bereits in Ordnung

- **Kontraste**: Ziffern in `Color.primary` beziehungsweise `.accentColor` auf
  Systemhintergrund — folgt Hell/Dunkel und „Erhöhter Kontrast“ automatisch.
- **Bewegung**: Die App animiert nichts, was „Bewegung reduzieren“ betreffen
  würde. Kommen Animationen dazu, ist die Einstellung zu respektieren.
- **Zielgrößen**: Ziffernknöpfe mindestens 48 pt hoch, Brettzellen auf dem iPhone
  rund 40 pt — über Apples Minimum von 44 pt liegt der Ziffernblock, die
  Brettzellen liegen bauartbedingt knapp darunter (ein 9×9-Raster passt anders
  nicht auf ein Telefon).
- **Tastatur**: Auf dem Mac ist das gesamte Spiel ohne Maus bedienbar —
  Pfeiltasten, Ziffern, ⌘Z, Leertaste, plus Menübefehle.
- **Focus Engine**: Auf dem Apple TV ist jede Zelle ein Fokusziel.

## Offen

- **VoiceOver-Rotor** für Zeilen, Spalten und Blöcke ist nicht eingerichtet.
  Navigiert wird derzeit Zelle für Zelle, was auf 81 Feldern mühsam ist.
- **Farbenblinden-Palette** als Einstellung fehlt; die Formmarkierung deckt den
  wichtigsten Fall ab, ersetzt sie aber nicht.
- **Mit echtem VoiceOver ungeprüft.** Die Labels sind gesetzt und im Code
  nachvollziehbar, aber niemand hat die App mit eingeschaltetem Screenreader
  bedient. Das gehört vor die Einreichung.

## Lokalisierung

Quellsprache ist Deutsch. Der Katalog
`Packages/SudokuUI/Localizations/Localizable.xcstrings` ist die editierbare
Wahrheit; `Scripts/generate-strings.py` erzeugt daraus die `.strings`-Dateien,
die tatsächlich ausgeliefert werden.

Warum nicht der Katalog direkt: Xkode kompiliert `.xcstrings` beim App-Build,
SwiftPM kopiert sie unverarbeitet durch. Läge nur der Katalog im Ressourcenordner,
fände `swift test` keine Übersetzung und jeder String fiele stillschweigend auf
seinen deutschen Schlüssel zurück. Lägen beide Formen dort, stritten die zwei
Build-Systeme um dieselbe Ausgabedatei.

Zwei Fallen, die dabei auffielen und beide lautlos scheitern:

1. **Swift bildet Schlüssel ohne Positionsangaben** (`%@`, nicht `%1$@`). Die
   Übersetzung darf sie verwenden, der Schlüssel nicht — sonst wird nichts
   gefunden und es erscheint Deutsch.
2. **Die App muss ihre Sprachen deklarieren.** Ohne `CFBundleLocalizations` in
   der `Info.plist` gilt sie als einsprachig deutsch, egal wie viele
   Übersetzungen in den Packages liegen. Genau das war der Zustand, bis es
   auffiel.
