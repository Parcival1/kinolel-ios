# KinoLel – iPhone-App

iPhone-/iPad-App für [KinoLel](https://kinolel.de). Sie öffnet direkt die Anmeldung von `https://kinolel.de`
(keine Serverauswahl) und zeigt die gewohnte KinoLel-Oberfläche inkl. Sprachwahl Deutsch/Magyar.
Filme laufen im **nativen iOS-Player (AVPlayer)** – dadurch **läuft der Ton weiter, wenn der Bildschirm gesperrt oder
die App verlassen wird**, mit Titel, Bild und Steuerung auf dem Sperrbildschirm; Bild-in-Bild wird unterstützt.

Aufbau: WKWebView (Jellyfin-Weboberfläche von kinolel.de) + kleine Brücke (`KinoLel/Ressourcen/*.js`), die Videos an den
nativen Player übergibt und dessen Fortschritt an Jellyfin zurückmeldet. Die Brücke ist von
[Jellyfin for iOS](https://github.com/jellyfin/jellyfin-ios) abgeleitet; dieses Projekt steht daher unter der
**Mozilla Public License 2.0** ([LICENSE](LICENSE)).

## Hintergrund-Wiedergabe (Kernanforderung)

| Baustein | Datei |
|---|---|
| `UIBackgroundModes = audio`, Audio-Sitzung `.playback` / `.moviePlayback` | `project.yml`, `AppDelegate.swift` |
| Beim Sperren/Verlassen Bild vom Player lösen und weiterspielen (Apple-Vorgabe), beim Zurückkommen wieder verbinden | `PlayerController.swift` (`imHintergrund`, `imVordergrund`) |
| Sperrbildschirm: Titel, Bild, Fortschritt, Wiedergabe/Pause, ±Spulen, Positionsregler | `PlayerController.swift` (`sperrbildschirm`, `befehleEinrichten`) |
| Bild-in-Bild (Home-Taste während Wiedergabe) | `PlayerController.swift` |
| Unterbrechungen (Anruf) → danach weiter | `PlayerController.swift` (`unterbrechung`) |

Jellyfin-Weboberfläche: Musik läuft im Web-Player weiter (Jellyfin 12 setzt die Audio-Sitzung „playback“).

## Marke

Name, Server, Kennung (`de.kinolel.app`) und Version stehen an **einer** Stelle: `settings.base` in [`project.yml`](project.yml).
Name endgültig „KinoLel“. Bilder: `marke/ios_bilder.py` (aus dem KinoLel-Logo).

## Bauen

GitHub Actions (`.github/workflows/ios.yml`, macOS-Runner): `xcodegen generate` → `xcodebuild` →
unsignierte `.ipa` + Rauchtest im Simulator (Bildschirmfotos). Tag `v*` → Vorab-Version unter Releases.
Lokal auf einem Mac: `brew install xcodegen && xcodegen generate && open KinoLel.xcodeproj`.

Zum Installieren auf einem iPhone muss die App signiert werden – siehe [TESTANLEITUNG.md](TESTANLEITUNG.md).
