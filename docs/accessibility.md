# Barrierefreiheit — Prüfprotokoll

Stand 2026-08-23, Meilenstein 6. Geprüft gegen Apples Richtlinien und die
üblichen WCAG-Kriterien, soweit sie auf eine native App zutreffen.

## Behoben

| Punkt | Vorher | Jetzt |
|---|---|---|
| **Fehler nur über Farbe** | Falsche Ziffer rot auf rotem Grund | Zusätzlich ein Dreieck in der Zellenecke — Form trägt die Information mit |
| **VoiceOver kennt die Position nicht** | Zelle las nur „5, eingetragen“ | `accessibilityValue` nennt Zeile und Spalte |
| **Ziffernblock ignoriert Textgröße** | Feste 28 pt | Skaliert mit `.title2` und der Systemeinstellung |
| **Nur Deutsch** | Der Store-Text versprach Englisch, die App konnte es nicht | 78 Strings in **Deutsch, Italienisch und Englisch**, per Test abgesichert |

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

## Was der Testlauf gefunden hat (2026-08-23)

`App/SudokuUITests/AccessibilityTests.swift` liest den Baum, den VoiceOver
vorliest, und lässt Xcodes eigene Prüfung (`performAccessibilityAudit`) über
beide Bildschirme laufen. **VoiceOver selbst läuft im Simulator nicht** — der
Dienst `com.apple.VoiceOverTouch` ist vorhanden, startet aber nicht; es gibt
weder Cursor noch Ansage. Der Test prüft daher die Daten, nicht die Sprachausgabe.

Er fand auf Anhieb sechs Sachen, davon zwei schwerwiegend:

| Befund | Warum es zählt | Behoben durch |
|---|---|---|
| **Das Brett war ein einziges Element.** `.accessibilityLabel` auf dem Container versteckt alle Kinder — VoiceOver las „Sudoku-Brett" und bot keinen Weg hinein. Alle 81 Felder unerreichbar. | Das Spiel war per Screenreader **nicht spielbar**. Die Beschriftungen an den Zellen waren gesetzt, halfen aber niemandem. | `.accessibilityElement(children: .contain)` |
| **Falsche Ziffer rot auf rot getöntem Grund**, unter 4,5:1 — „Contrast failed", nicht nur knapp. | Ausgerechnet der Fehlerzustand war der am schlechtesten lesbare. | Eigene Rotwerte je Erscheinungsbild |
| Sekundärtext durchgehend bei ~3,5:1 (SwiftUIs `.secondary` ist rund #8E8E93 auf Weiß). | Betraf jede Beschriftung auf beiden Bildschirmen. | `Theme.secondaryText` bei ~7:1 |
| Notizmodus wurde **nur über die Tönung** angezeigt. | Für einen Screenreader gar nicht vorhanden. | `.isSelected`-Merkmal |
| Kopfzeile mit `.lineLimit(1)` und `.minimumScaleFactor(0.7)`. | Erzwang eine Zeile und schrumpfte den Text unter die gewählte Größe. | Beides entfernt, Umbruch erlaubt |
| Bei größter Textgröße: **das Brett schrumpfte auf ein Drittel**, während „Rückgängig" als „Rüc/kgä/ngig" drei Zeilen fraß. Die Kopfzeile trennte „Punkte" zu „Punkt-/e". | Das Spielfeld ist der Zweck der App. | Bedienleiste nur mit Symbolen, Kopfzeile stapelt vertikal |

Angesehen und als Prüfungs-Vorsicht eingestuft, nicht als Fehler — jeweils bei
größter Textgröße mit eigenen Augen kontrolliert, der Text ist vollständig
lesbar und lediglich mit deutscher Silbentrennung umbrochen:
„Für alle das gleiche · doppelte Punkte", „Wings und Färben",
„Fehler … · Hinweise …" sowie der System-Zurück-Knopf. Sie stehen als benannte
Ausnahmen im Test; alles andere lässt ihn fehlschlagen, damit ein **neuer**
Befund nicht stillschweigend mit durchrutscht.

Zwei bauartbedingte Ausnahmen, ebenfalls im Test begründet:

- **Deaktivierte Bedienelemente** sind absichtlich gedimmt; WCAG nimmt inaktive
  Komponenten vom Kontrastkriterium aus.
- **Die Brettziffern folgen nicht der Textgröße.** Sie sind auf die Zelle
  bemessen; ein 9×9-Raster kann nicht umbrechen. Stattdessen skaliert das Brett
  mit dem verfügbaren Platz, und über VoiceOver ist jedes Feld unabhängig von der
  Textgröße erreichbar.

## Offen

- **VoiceOver-Rotor** für Zeilen, Spalten und Blöcke ist nicht eingerichtet.
  Navigiert wird derzeit Zelle für Zelle, was auf 81 Feldern mühsam ist.
- **Farbenblinden-Palette** als Einstellung fehlt; die Formmarkierung deckt den
  wichtigsten Fall ab, ersetzt sie aber nicht.
- **Mit echtem VoiceOver auf einem Gerät weiterhin ungeprüft.** Der Baum stimmt
  und wird bei jedem Lauf geprüft, aber Sprachausgabe, Gesten und der Rotor
  lassen sich im Simulator nicht ausprobieren. Auf dem Mac ginge es mit echtem
  VoiceOver — das übernimmt allerdings die ganze Maschine und gehört deshalb dem
  Nutzer selbst überlassen.

## Lokalisierung

Drei Sprachen: Deutsch, Italienisch, Englisch. Quellsprache ist Deutsch. Der Katalog
`Packages/SudokuUI/Localizations/Localizable.xcstrings` ist die editierbare
Wahrheit; `Scripts/generate-strings.py` erzeugt daraus die `.strings`-Dateien,
die tatsächlich ausgeliefert werden.

Warum nicht der Katalog direkt: Xcode kompiliert `.xcstrings` beim App-Build,
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
   auffiel. Das gilt auch für die Widget-Erweiterung, die ihre eigene
   `Info.plist` hat.
