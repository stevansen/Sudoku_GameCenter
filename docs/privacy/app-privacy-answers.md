# App Store Connect — „App-Datenschutz" (Nutrition Label)

Antworten für den Fragebogen unter *App Store Connect → App → App-Datenschutz*.

## Erhebt diese App Daten?

**Nein.**

Begründung, falls die Prüfung nachfragt: Die App speichert Spielstände und
Einstellungen ausschließlich lokal beziehungsweise in der **privaten**
iCloud-Datenbank der Nutzerin oder des Nutzers. Nach Apples eigener Definition
gilt das nicht als Erhebung, solange der Entwickler keinen Zugriff auf die Daten
hat — und den haben wir nicht: CloudKit-Container mit privater Datenbank, keine
serverseitige Komponente, kein eigenes Backend.

Punktzahlen und Erfolge gehen an **Game Center**, also an Apple. Auch das ist
keine Erhebung durch uns.

Voraussetzung dafür, dass diese Antwort richtig bleibt:

- keine Analyse-SDKs (kein Firebase, kein Amplitude, keine Crash-Reporter Dritter),
- keine Werbenetzwerke,
- kein eigener Server, der irgendetwas protokolliert,
- Absturzberichte ausschließlich über Apples eigenes System (das zählt nicht als
  Erhebung durch den Entwickler).

**Ändert sich eine dieser Voraussetzungen, muss dieser Fragebogen neu beantwortet
werden.** Eine falsche Angabe ist ein Ablehnungsgrund und rechtlich heikel.

## Tracking

**Nein.** Kein App-Tracking über Apps und Websites hinweg, folglich auch kein
`AppTrackingTransparency`-Dialog. Entsprechend `NSPrivacyTracking = false` im
Privacy-Manifest.

## Privacy-Manifest

`Configuration/PrivacyInfo.xcprivacy` muss in **jedes** Target eingebunden werden,
das ausgeliefert wird (App, Widget-Extension, Watch-App). Deklariert ist
ausschließlich der Zugriff auf `UserDefaults` mit dem Grund `CA92.1`.

Sollte die App später Dateizeitstempel lesen (etwa für den Rätsel-Vorrat im
App-Group-Container), kommt `NSPrivacyAccessedAPICategoryFileTimestamp` mit dem
Grund `C617.1` hinzu.
