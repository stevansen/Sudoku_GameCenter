# Hinweise für die App-Prüfung

Feld *App Review Information → Notes* in App Store Connect. Kurz halten; die
Prüfung liest viele davon.

```
Kein Account nötig. Die App ist ohne Anmeldung vollständig spielbar, es gibt
keine Käufe und keine Werbung.

Game Center: Bestenlisten und Erfolge werden nach der Anmeldung mit einer
beliebigen Sandbox-Apple-ID sichtbar. Wird die Anmeldung abgelehnt, läuft die App
im Offline-Modus vollständig weiter.

iCloud: Spielstände werden in der privaten CloudKit-Datenbank der Nutzerin oder
des Nutzers abgelegt, damit eine Partie auf einem anderen Gerät fortgesetzt
werden kann. Es gibt keinen eigenen Server und keine Datenerhebung.

Die Rätsel werden auf dem Gerät erzeugt, nicht heruntergeladen. Das Tagesrätsel
wird aus dem UTC-Datum abgeleitet und ist deshalb ohne Netzwerkverbindung für
alle identisch.
```

## Anmeldedaten

Keine. Feld *Sign-in required* auf **Nein**.

## Kontakt

Vor- und Nachname, Telefonnummer und E-Mail sind Pflichtfelder: `<TODO>`.

## Was die Prüfung erfahrungsgemäß bemängelt

- **Leere Bestenlisten**: Bestenlisten und Erfolge müssen in App Store Connect
  angelegt **und** in der Version verknüpft sein, sonst wirkt der Game-Center-
  Bereich der App leer und wird als „unvollständige Funktion" beanstandet.
- **Erfolgs-Bilder fehlen**: Jeder Erfolg braucht ein 512×512-Bild, sonst lässt
  sich die Game-Center-Konfiguration nicht zur Prüfung einreichen.
- **Screenshots aus dem Simulator mit Statusleisten-Platzhaltern**: echte
  Statusleiste oder saubere Attrappe verwenden.
- **Datenschutz-URL nicht erreichbar**: wird zuverlässig geprüft.
