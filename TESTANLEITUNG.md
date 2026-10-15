# KinoLel für iPhone – Testanleitung

Die Testversion ist **unsigniert** (`KinoLel-<Version>-unsigniert.ipa`). Apple lässt Apps nur signiert auf iPhones.
Wege zum Testen:

| Weg | Kosten | Haken |
|---|---|---|
| **Sideloadly** (Windows/Mac) oder **AltStore** mit eigener Apple-ID | 0 € | App läuft **7 Tage**, dann neu signieren; max. 3 solcher Apps je Apple-ID; je Gerät am PC einrichten |
| **Apple Developer Program** → **TestFlight** | 99 €/Jahr | Familie installiert über die TestFlight-App per Einladung, Builds 90 Tage gültig; Build-Signatur im GitHub-Build einrichtbar |
| Apple Developer Program → App Store (nicht gelistet) | 99 €/Jahr | Prüfung durch Apple; später möglich |

## Mit Sideloadly (kostenlos, zum Ausprobieren)
1. Sideloadly auf dem PC installieren (sideloadly.io), iPhone per Kabel anschließen, „Diesem Computer vertrauen“.
2. `.ipa` in Sideloadly ziehen, Apple-ID eingeben → Start.
3. iPhone: Einstellungen → Allgemein → VPN & Geräteverwaltung → Apple-ID → **Vertrauen**.
   Ab iOS 16: Einstellungen → Datenschutz & Sicherheit → **Entwicklermodus** einschalten (Neustart).

## Prüfen
| # | Was | Erwartung |
|---|---|---|
| 1 | Start | KinoLel-Logo mit Ladekreis, dann **direkt die Anmeldung** von kinolel.de |
| 2 | Sprache | **Deutsch / Magyar** über der Anmeldung; Wahl bleibt nach Anmelden und Neustart |
| 3 | Film abspielen | Startet im iOS-Vollbild-Player (Untertitel/Tonspur über die Player-Symbole) |
| 4 | **Bildschirm sperren** | **Ton läuft weiter.** Sperrbildschirm zeigt Titel, Bild, Pause/Weiter, Spulen |
| 5 | Home-Taste/wischen | Bild-in-Bild-Fenster; schließt man es, läuft der Ton weiter bzw. stoppt beim „X“ |
| 6 | Zurück in die App | Bild läuft an derselben Stelle weiter |
| 7 | Anruf während Wiedergabe | Danach geht es weiter |
| 8 | Fortschritt | Im Browser bei „Weiterschauen“ steht die richtige Stelle |
