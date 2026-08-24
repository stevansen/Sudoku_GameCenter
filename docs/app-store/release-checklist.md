# Release-Checkliste

Von null bis zur Veröffentlichung. Was du selbst tun musst, ist mit **[du]**
markiert — das sind Schritte, die einen Apple-Account, ein Passwort oder eine
Zahlungsmethode brauchen und deshalb nicht automatisierbar sind.

**Vorbedingung**: Meilensteine 2 bis 6 sind fertig. App-Target, Widget-
Erweiterung, Privacy-Manifest und Entitlements liegen im Projekt.

---

## A — Konto und Team

- [ ] **[du]** Mitgliedschaft im Apple Developer Program aktiv (99 USD/Jahr).
- [ ] **[du]** Team-ID notiert (Developer-Portal → *Membership*). Sie kommt in
      `Configuration/ExportOptions.plist`.
- [ ] **[du]** App-Store-Connect-API-Schlüssel erzeugt (*Users and Access → Keys*),
      `.p8` sicher abgelegt — **nicht ins Repo**, die `.gitignore` blockt sie.

## B — Identifier und Capabilities

Developer-Portal → *Certificates, Identifiers & Profiles*.

- [ ] **[du]** App-IDs anlegen: `com.hellweger.sudoku.app` und `com.hellweger.sudoku.app.widgets`.
      (Kein `.tv`, kein `.watchkitapp` — tvOS läuft unter derselben Bundle-ID,
      watchOS und visionOS sind nicht im Umfang.)
- [ ] **[du]** Für `com.hellweger.sudoku.app`: **Game Center** und **iCloud (Key-Value
      Storage)** aktivieren. Mehr nicht — die App verwendet weder CloudKit noch
      App-Groups noch Push, und was man deklariert und nicht benutzt, fällt bei
      der Prüfung auf.

## C — Xcode-Projekt

- [x] Bundle-IDs der Targets stimmen mit B überein.
- [x] `App/Sudoku.entitlements` liegt im Projekt und ist zugewiesen — Game Center
      und der Schlüsselwertspeicher, sonst nichts.
- [x] `ITSAppUsesNonExemptEncryption`, `LSApplicationCategoryType` und
      `NSUserActivityTypes` stehen in der `Info.plist`.
- [x] `PrivacyInfo.xcprivacy` liegt in **beiden** ausgelieferten Targets
      (App und Widget) und landet im Bundle.
- [ ] **[du]** `DEVELOPMENT_TEAM` setzen. Ohne Team verwirft Xcode die
      Entitlements beim Signieren (ad-hoc), und `$(TeamIdentifierPrefix)` bleibt
      leer — der Schlüsselwertspeicher schreibt dann ins Nichts.
- [ ] `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION` monoton steigend.
      Regel: Build-Nummer bei jedem Upload erhöhen, auch bei identischem Code —
      App Store Connect nimmt dieselbe Nummer kein zweites Mal an.
- [ ] Release-Build mit aktivierten Optimierungen, Bitcode ist irrelevant
      (abgeschafft), Debug-Symbole werden hochgeladen.

      Die Entitlements hängen an der **Release**-Konfiguration. Im Debug sind sie
      abgeschaltet, weil macOS ohne Entwicklerzertifikat gar nicht baut, sobald
      welche gesetzt sind — ohne Team wäre sonst nichts mehr zu testen. Mit Team
      schaltet man sie im Debug so dazu:

      ```bash
      xcodebuild -scheme Sudoku -configuration Debug \
        SUDOKU_ENTITLEMENTS=Sudoku.entitlements build
      ```
- [x] `swift test -c release -Xswiftc -enable-testing` grün — 138 Tests, alle vier
      Pakete. Optimiert läuft die Engine-Suite in 3,8 s statt 165 s.
- [ ] **[du]** Release-Build der **Mac**-App: geht erst mit gesetztem
      `DEVELOPMENT_TEAM`. Die Entitlements hängen an der Release-Konfiguration,
      und macOS baut mit Entitlements ohne Entwicklerzertifikat nicht. iOS und
      tvOS bauen Release auch ohne Team.

## D — App Store Connect: Eintrag

- [ ] **[du]** App anlegen, Primärsprache **Deutsch**, Bundle-ID `com.hellweger.sudoku.app`,
      SKU frei wählbar (z. B. `SUDOKU-001`).
- [ ] Metadaten aus [de-DE.md](de-DE.md) und [en-US.md](en-US.md) eintragen.
- [ ] Kategorien: *Spiele → Rätsel*, sekundär *Spiele → Denkspiele*.
- [ ] Altersfreigabe nach [age-rating.md](age-rating.md) → Ergebnis 4+.
- [ ] App-Datenschutz nach [app-privacy-answers.md](../privacy/app-privacy-answers.md)
      → „Keine Daten erhoben".
- [ ] **[du]** Datenschutz-URL hinterlegen. Der Text liegt in
      [datenschutz-de.md](../privacy/datenschutz-de.md) und
      [privacy-policy-en.md](../privacy/privacy-policy-en.md) und muss von dir
      irgendwo öffentlich erreichbar veröffentlicht werden.
- [ ] **[du]** Support-URL hinterlegen (Pflichtfeld, muss erreichbar sein).
- [ ] Prüfhinweise aus [review-notes.md](review-notes.md) eintragen,
      *Sign-in required* = Nein.
- [ ] **[du]** Preis: kostenlos. Verfügbarkeit: alle Länder oder Auswahl.
- [ ] **[du]** Steuer- und Bankdaten vollständig — auch bei kostenlosen Apps ist
      der Vertrag „Free Apps" zu akzeptieren, sonst bleibt die App hängen.

## E — Game Center

- [ ] **[du]** 9 Bestenlisten und 30 Erfolge exakt nach
      [gamecenter-setup.md](../gamecenter-setup.md) anlegen.
- [ ] 30 Erfolgs-Bilder à 512 × 512 hochladen.
- [ ] Game-Center-Konfiguration mit der Version **verknüpfen** — ohne das bleibt
      der Game-Center-Bereich in der geprüften App leer.

## F — Grafiken

- [ ] App-Symbol 1024 × 1024, ohne Alphakanal.
- [ ] Screenshots je unterstützter Gerätefamilie nach
      [assets-spec.md](assets-spec.md).

## G — Archivieren und hochladen

```bash
# iOS/iPadOS
xcodebuild -scheme Sudoku -destination 'generic/platform=iOS' \
  -archivePath build/Sudoku-iOS.xcarchive archive

xcodebuild -exportArchive -archivePath build/Sudoku-iOS.xcarchive \
  -exportOptionsPlist Configuration/ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates
```

Für den direkten Upload `destination` in der `ExportOptions.plist` auf `upload`
setzen; sonst entsteht ein `.ipa`, das über die **Transporter**-App hochgeladen
wird. Für macOS und tvOS dasselbe mit `-destination 'generic/platform=macOS'`
beziehungsweise `'generic/platform=tvOS'`.

- [ ] Build erscheint in App Store Connect (dauert 5 bis 30 Minuten).
- [ ] Etwaige E-Mail über „ITMS"-Warnungen gelesen — fehlende Symbole und
      veraltete API-Nutzung tauchen hier zuerst auf.

## H — TestFlight

- [ ] Interne Tester (bis 100, keine Prüfung nötig) — mindestens einmal auf einem
      echten Gerät gespielt, auf **allen** eingereichten Plattformen.
- [ ] Externe Tester nur bei Bedarf; deren Freigabe braucht eine eigene Prüfung.
- [ ] Game Center in der **Sandbox** getestet: Anmeldung, Punktemeldung,
      Erfolgsfortschritt, Verhalten bei abgelehnter Anmeldung.
- [ ] iCloud-Sync zwischen zwei Geräten mit derselben Apple-ID getestet,
      einschließlich des Konfliktdialogs.

## I — Einreichen

**Was eine Einreichung blockiert, in der Reihenfolge, in der es auffiel.** Die API
meldet immer nur „appStoreVersions … is not in valid state", nie welches Feld
fehlt — man beseitigt die Gründe also einzeln und probiert erneut.

| Voraussetzung | über API? | Stand |
|---|---|---|
| Build hochgeladen **und der Version zugeordnet** | ja | ✅ |
| Prüfangaben: Name, **Telefon mit Ländervorwahl**, E-Mail, Hinweise | ja | ✅ |
| `contentRightsDeclaration` beantwortet | ja | ✅ |
| **Preisplan** — ohne ihn geht nichts | ja | ✅ kostenlos |
| **Verfügbarkeit** (Territorien) | entsteht mit dem Preisplan | ✅ 175 Länder |
| **Game Center mit der Version verknüpft** (`gameCenterAppVersions`, danach `enabled`) | ja, aber zweistufig | ✅ |
| **App-Datenschutz** („Werden Daten erfasst?") | **nein — nur Weboberfläche** | ⬜ **[du]** |

Der Datenschutz-Fragebogen ist in dieser API-Version schlicht nicht vorhanden:
der App-Eintrag hat 41 Beziehungen, keine davon betrifft ihn. Antworten liegen
fertig in [app-privacy-answers.md](../privacy/app-privacy-answers.md) — durchweg
„keine Daten erhoben".

Zwei Fallstricke beim Anlegen über die API:

- `gameCenterAppVersions` nimmt `enabled` **nicht** beim Anlegen an; erst
  erzeugen, dann per PATCH aktivieren.
- `reviewSubmissions` erlaubt **kein DELETE**. Ein Entwurf, der beim ersten
  Versuch entsteht, bleibt stehen — er lässt sich aber wiederverwenden.

- [ ] Version zur Prüfung einreichen, Freigabe **manuell** wählen — dann
      entscheidest du, wann sie erscheint.
- [ ] Erwartete Dauer: 24 bis 48 Stunden.

## J — Nach der Freigabe

- [ ] Ersten Absturzbericht-Zeitraum beobachten (Xcode → *Organizer*).
- [ ] `aps-environment` im Release-Build steht auf `production` (Xcode setzt das
      beim App-Store-Export automatisch, einmal prüfen).
- [ ] Version und Build im Repo taggen: `v1.0.0`.

---

## Was nur du liefern kannst

| Gegenstand | Warum |
|---|---|
| Apple-Developer-Mitgliedschaft, Team-ID | kostenpflichtig, personengebunden |
| App-Store-Connect-Zugang, API-Schlüssel | Zugangsdaten |
| Öffentliche Datenschutz- und Support-URL | Hosting-Entscheidung |
| Impressumsangaben in der Datenschutzerklärung | rechtliche Verantwortung |
| App-Symbol und Screenshots | Gestaltung |
| Steuer- und Bankdaten | vertraglich |
