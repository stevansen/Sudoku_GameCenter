# Apple-Einrichtung — Klickstrecke

Für den Teil, den nur du machen kannst. Voraussetzung: aktive
Developer-Mitgliedschaft (vorhanden). Reihenfolge ist wichtig — jeder Schritt
schaltet den nächsten frei.

Alles hier läuft **ohne fertige App**. Es lohnt sich, das jetzt zu erledigen,
weil sonst am Ende alles gleichzeitig blockiert.

---

## 1 — Team-ID ablesen  ·  2 Minuten

developer.apple.com → *Account* → **Membership details**.

Notiere die **Team ID** (10 Zeichen, z. B. `A1B2C3D4E5`). Sie kommt später in
`Configuration/ExportOptions.plist` an die Stelle `TODO_TEAM_ID`.

> Sag sie mir, dann trage ich sie ein. Sie ist kein Geheimnis — sie steht später
> in jeder ausgelieferten App.

## 2 — App-ID registrieren  ·  5 Minuten

developer.apple.com → *Certificates, Identifiers & Profiles* → **Identifiers** →
**+** → *App IDs* → *App*.

| Feld | Wert |
|---|---|
| Description | `Sudoku` |
| Bundle ID | **Explicit**, `com.sudoku.app` |

Capabilities ankreuzen:

- [ ] **Game Center**
- [ ] **iCloud** (Include CloudKit support)
- [ ] **App Groups**
- [ ] **Push Notifications**

Nur diese vier. Alles andere bleibt aus.

> Die IDs für tvOS, Watch und Widgets (`com.sudoku.app.tv`,
> `com.sudoku.app.watchkitapp`, `com.sudoku.app.widgets`) erst anlegen, wenn die
> Targets existieren — sonst hängen unbenutzte Identifier herum.

## 3 — iCloud-Container und App-Group  ·  5 Minuten

Immer noch unter *Identifiers*:

**iCloud Containers** → **+**

| Feld | Wert |
|---|---|
| Description | `Sudoku` |
| Identifier | `iCloud.com.sudoku.app` |

**App Groups** → **+**

| Feld | Wert |
|---|---|
| Description | `Sudoku` |
| Identifier | `group.com.sudoku.app` |

Danach zurück zur App-ID `com.sudoku.app`, dort bei *iCloud* und *App Groups*
auf **Configure** und die eben erstellten Einträge zuordnen. Dieser Zuordnungs-
schritt wird gern vergessen; ohne ihn schlägt später das Signieren fehl.

## 4 — App in App Store Connect anlegen  ·  10 Minuten

appstoreconnect.apple.com → *Apps* → **+** → *Neue App*.

| Feld | Wert |
|---|---|
| Plattformen | iOS, macOS *(weitere später ergänzbar)* |
| Name | `Sudoku` — falls vergeben: `Sudoku Kern` |
| Primärsprache | **Deutsch** |
| Bundle-ID | `com.sudoku.app` (aus Schritt 2) |
| SKU | `SUDOKU-001` |
| Benutzerzugriff | Vollständiger Zugriff |

Der Name wird hier **reserviert**. Wenn `Sudoku` belegt ist, erfährst du es genau
jetzt — deshalb steht dieser Schritt so früh.

## 5 — Verträge prüfen  ·  5 Minuten

App Store Connect → *Geschäft und Steuern* (Agreements, Tax, and Banking).

Auch für eine kostenlose App muss der Vertrag **„Free Apps"** aktiv sein. Steht
er auf *ausstehend*, bleibt die App bei der Einreichung hängen — ohne
verständliche Fehlermeldung.

Bank- und Steuerdaten brauchst du nur für bezahlte Apps.

## 6 — Game Center befüllen  ·  60 bis 90 Minuten

App Store Connect → App `Sudoku` → *Dienste* → **Game Center**.

Werte **exakt** aus [gamecenter-setup.md](../gamecenter-setup.md) übernehmen —
der Code referenziert genau diese IDs, ein Tippfehler fällt erst im Betrieb auf.

1. **9 Bestenlisten** anlegen. Bei `daily` die Dauer *1 Tag*, bei
   `weekly_points` *7 Tage*, Start jeweils **00:00 UTC**.
2. **30 Erfolge** anlegen. Jeder braucht ein Bild 512 × 512, sonst lässt sich die
   Konfiguration nicht einreichen. Punktesumme 880 — nachrechnen lassen sich die
   Werte in der Tabelle.
3. Jeweils **Deutsch** und **Englisch (USA)** als Sprachen anlegen.

Das ist der langwierigste Teil und der einzige, den man nicht nachholen kann,
ohne die Einreichung zu verzögern. Er lässt sich in Etappen erledigen.

## 7 — Metadaten eintragen  ·  20 Minuten

App Store Connect → App → *App-Informationen* und *Version 1.0*.

Texte aus [de-DE.md](de-DE.md) und [en-US.md](en-US.md), Kategorien *Spiele →
Rätsel* und *Spiele → Denkspiele*, Altersfreigabe nach
[age-rating.md](age-rating.md), App-Datenschutz nach
[app-privacy-answers.md](../privacy/app-privacy-answers.md).

Fehlt noch von dir: **Datenschutz-URL** und **Support-URL**. Beide sind
Pflichtfelder und werden von der Prüfung aufgerufen. Der Text der
Datenschutzerklärung liegt fertig in `docs/privacy/`; er muss nur irgendwo
öffentlich erreichbar stehen — eine GitHub-Pages-Seite oder ein Gist genügt.

---

## Was danach noch fehlt

Nur noch die App selbst: Xcode-Projekt, App-Target, Symbol, Screenshots, Build.
Screenshots gehen erst, wenn die App läuft.
