# Release-Checkliste

Von null bis zur Veröffentlichung. Was du selbst tun musst, ist mit **[du]**
markiert — das sind Schritte, die einen Apple-Account, ein Passwort oder eine
Zahlungsmethode brauchen und deshalb nicht automatisierbar sind.

**Vorbedingung**: Meilensteine 2 bis 6 des [Build-Prompts](../../README.md) sind
fertig. Stand heute existiert nur die Engine — es gibt noch kein App-Target und
damit nichts einzureichen.

---

## A — Konto und Team

- [ ] **[du]** Mitgliedschaft im Apple Developer Program aktiv (99 USD/Jahr).
- [ ] **[du]** Team-ID notiert (Developer-Portal → *Membership*). Sie kommt in
      `Configuration/ExportOptions.plist`.
- [ ] **[du]** App-Store-Connect-API-Schlüssel erzeugt (*Users and Access → Keys*),
      `.p8` sicher abgelegt — **nicht ins Repo**, die `.gitignore` blockt sie.

## B — Identifier und Capabilities

Developer-Portal → *Certificates, Identifiers & Profiles*.

- [ ] **[du]** App-IDs anlegen: `com.sudoku.app`, `com.sudoku.app.tv`,
      `com.sudoku.app.watchkitapp`, `com.sudoku.app.widgets`.
- [ ] **[du]** Für jede: **Game Center**, **iCloud**, **App Groups**,
      **Push Notifications** aktivieren.
- [ ] **[du]** iCloud-Container `iCloud.com.sudoku.app` erstellen und den App-IDs
      zuordnen.
- [ ] **[du]** App-Group `group.com.sudoku.app` erstellen und zuordnen.

## C — Xcode-Projekt

- [ ] Bundle-IDs der Targets stimmen mit B überein.
- [ ] `Configuration/Sudoku.entitlements.example` als echte `.entitlements`
      übernommen und dem Target zugewiesen.
- [ ] Schlüssel aus `Configuration/Info-additions.plist.example` in die
      `Info.plist` übernommen — besonders `ITSAppUsesNonExemptEncryption`,
      sonst fragt jeder Upload nach der Exportkonformität.
- [ ] `Configuration/PrivacyInfo.xcprivacy` in **jedem** ausgelieferten Target
      eingebunden (App, Widget, Watch-App).
- [ ] `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION` monoton steigend.
      Regel: Build-Nummer bei jedem Upload erhöhen, auch bei identischem Code —
      App Store Connect nimmt dieselbe Nummer kein zweites Mal an.
- [ ] Release-Build mit aktivierten Optimierungen, Bitcode ist irrelevant
      (abgeschafft), Debug-Symbole werden hochgeladen.
- [ ] `swift test -c release -Xswiftc -enable-testing` grün.

## D — App Store Connect: Eintrag

- [ ] **[du]** App anlegen, Primärsprache **Deutsch**, Bundle-ID `com.sudoku.app`,
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
wird. Für macOS, tvOS und visionOS dasselbe mit
`-destination 'generic/platform=macOS'` und so weiter.

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
