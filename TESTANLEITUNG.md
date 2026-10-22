# KinoLel für iPhone – Testanleitung

Die Testversion ist **unsigniert** (`KinoLel-<Version>-unsigniert.ipa`). Apple lässt Apps nur signiert auf iPhones.

**Empfohlen (Lel 22.10.2026): SideStore** – kostenlos mit Apple-ID, erneuert die 7-Tage-Signatur auf dem iPhone selbst,
Updates erscheinen in SideStore. Schritt für Schritt: **[SIDESTORE.md](SIDESTORE.md)**.
Quelle für SideStore: `https://kinolel.de/web/kinolel/sidestore.json` (KinoLel + KinoLel Wünsche).

Weitere Wege:

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
| 9 | **Downloads** (ab 0.1.2) | Auf einer Film-/Folgenseite neben „Abspielen“ der Knopf **„Herunterladen“** (bei Staffeln „Staffel herunterladen“), auch im „…“-Menü. Tippen → Qualität wählen (Original, wenn das iPhone die Datei direkt kann, sonst Hoch/Mittel/Klein mit Größe und freiem Speicher) |
| 10 | Fortschritt | Knopf zeigt Prozent; Profilbild → **„Downloads“** zeigt die Liste mit Fortschritt, Qualität, Größe und Speicherplatz. Standard: **nur im WLAN** (Schalter in der Liste) |
| 11 | App schließen während des Downloads | Download läuft im Hintergrund weiter (iOS entscheidet über das Tempo) |
| 12 | **Flugmodus**, App starten | Startbild meldet „nicht erreichbar“ und öffnet **„Meine Downloads“** von selbst; Antippen spielt ohne Internet |
| 13 | Danach wieder online | Bei „Weiterschauen“ (auch im Browser) steht die offline erreichte Stelle |
| 14 | Download löschen | Papierkorb in der Liste (oder nach links wischen) → „Löschen“ |
| 15 | Heruntergeladenen Titel online abspielen | Spielt aus der Datei (kein Datenverbrauch), Fortschritt wie gewohnt |
| 16 | Nachricht vom Server (Dashboard → Gerät → Nachricht) während der Wiedergabe | Erscheint oben **über dem Player**; Pause/Stopp vom Dashboard wirken auf den Player |
| 17 | **Was ist neu** | Nach einem Update einmal die Meldung „Neu in KinoLel …“, beim nächsten Start nicht mehr (Neuinstallation: keine Meldung) |
| 18 | Update-Hinweis | Gibt es eine neuere Testversion, fragt die App (höchstens alle 6 Stunden); „Aktualisieren“ öffnet SideStore (sonst die Download-Seite) |
| 19 | iPhone auf Englisch | App-eigene Texte (Startbild, Downloads, Meldungen) auf Englisch |

## Automatische Tests (GitHub, ohne Signatur)
Jeder Build läuft im **iOS-Simulator** durch (Ergebnis „oberflaechentest“ mit Bildschirmfotos):
- „Was ist neu“ auf Deutsch, Englisch, Ungarisch – genau einmal
- Start ohne Internet: Hinweis, Download-Liste, Schalter „Nur im WLAN“
- bei Versionen (Tag `v*`) mit dem Secret `KINOLEL_TEST_PW` (Konto kinolel-hilfe): eine kurze Folge „Klein“
  herunterladen, ohne Internet aus der Liste abspielen, wieder online → Position bei Jellyfin, Download löschen,
  abmelden (nur bei Versionen, damit nicht jeder Build den Server/das NAS belastet)

Nicht im Simulator prüfbar (nur auf dem echten iPhone): Sperrbildschirm/Hintergrundton, Bild-in-Bild, Anruf,
echter Flugmodus/Mobilfunk, Downloads bei geschlossener App über längere Zeit.
