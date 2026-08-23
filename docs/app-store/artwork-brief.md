# Grafik-Briefing — Symbol und Screenshots

Vorlage für dich oder eine Designerin. Technische Größen stehen in
[assets-spec.md](assets-spec.md); hier geht es um den Inhalt.

## Gestalterische Leitlinie

Die App verkauft **Klarheit**, nicht Verspieltheit. Ein Sudoku ist ein Raster aus
Linien und Ziffern — das Beste, was eine Gestaltung tun kann, ist dieses Raster
ernst nehmen und nichts hinzuerfinden. Keine Cartoon-Bleistifte, keine
Konfetti-Effekte, keine Verläufe über das ganze Brett.

Wenn ein Wort die Richtung vorgibt: **ruhig**.

## App-Symbol

**Idee**: ein einzelner 3 × 3-Block, nicht das ganze 9 × 9-Raster. Bei 60 Pixel
Kantenlänge auf dem Home-Bildschirm ist ein volles Gitter ein grauer Fleck; ein
Neuner-Block bleibt lesbar und ist trotzdem eindeutig Sudoku.

- Gitterlinien kräftig, gleichmäßig, kein Schlagschatten.
- Eine einzige gesetzte Ziffer als Blickfang, die restlichen Felder leer.
  Vorschlag: die **5** in der Mitte — mittig, symmetrisch, gut lesbar.
- Zwei Farben plus Hintergrund. Vorschlag: tiefes Blaugrau für die Linien,
  ein kräftiger Akzent für die Ziffer.
- Vollflächiger Hintergrund, **kein** Alphakanal, **keine** runden Ecken
  (die setzt das System).
- Dark-Mode-Variante mitliefern, falls das Symbol als Alternativsymbol angeboten
  werden soll.

**Prüfung**: auf 60 × 60 herunterskaliert ansehen. Wenn die Ziffer dann
verschwimmt, ist das Symbol zu fein gezeichnet.

## Fünf Screenshots

Reihenfolge ist die Verkaufsreihenfolge — der erste wird am häufigsten gesehen,
oft als einziger.

| # | Motiv | Überschrift (de) | Überschrift (en) |
|---|---|---|---|
| 1 | Brett mitten im Spiel, Notizen sichtbar, Ziffernblock, laufende Zeit | Ein Rätsel, das es vorher nicht gab | A puzzle that did not exist before |
| 2 | Hinweis-Ansicht: hervorgehobene Zelle plus Erklärung der Technik | Hinweise, die etwas erklären | Hints that explain |
| 3 | Stufenauswahl mit allen fünf Stufen und ihrer Beschreibung | Fünf Stufen, die etwas bedeuten | Five tiers that mean something |
| 4 | Punkte-Aufschlüsselung nach dem Lösen | Nachvollziehbar bis auf den Punkt | Every point accounted for |
| 5 | Dasselbe Spiel auf iPhone und Mac nebeneinander | Weiterspielen, wo du aufgehört hast | Continue where you stopped |

Regeln für die Umsetzung:

- Überschrift **oben**, Gerät darunter — nicht umgekehrt. In der Vorschau des
  Stores wird der untere Rand oft abgeschnitten.
- Echte Statusleiste oder eine saubere Attrappe. Simulator-Platzhalter
  (`9:41` ist in Ordnung, `Carrier` nicht) führen zu Beanstandungen.
- Nichts zeigen, was die App nicht kann. Die Prüfung vergleicht.
- Beide Sprachen: die Store-Einträge sind de und en, die Screenshots sollten es
  auch sein.

## 30 Erfolgs-Bilder

Der unterschätzte Posten: **30 Stück, je 512 × 512, ohne Alphakanal**. Ohne sie
lässt sich die Game-Center-Konfiguration nicht einreichen.

Empfehlung, um den Aufwand klein zu halten: ein gemeinsames Grundmotiv — derselbe
3 × 3-Block wie im App-Symbol — und darauf je ein Piktogramm oder eine Ziffer,
gruppiert nach den vier Achsen der Erfolge:

| Achse | Erfolge | Motivfamilie |
|---|---|---|
| Menge | `solve_*`, `points_*` | gefüllter werdendes Raster |
| Können | `flawless*`, `no_hints_50`, `technique_xwing` | Häkchen, Auge, X-Muster |
| Tempo | `speed_*` | Stoppuhr, Blitz |
| Gewohnheit | `streak_*`, `daily_*`, `perfect_week` | Kalenderblatt, Flamme |

Fünf Grundmotive mit Varianten in Farbe und Beschriftung decken alle 30 ab.
Die vollständige Liste mit Titeln steht in
[gamecenter-setup.md](../gamecenter-setup.md).
