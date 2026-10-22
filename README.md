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

## Wie die Android-App (ab 0.1.2)

| Funktion | Datei |
|---|---|
| **Downloads** wie bei Netflix: Knopf „Herunterladen“ in der Weboberfläche, Qualitätswahl, Hintergrund-Download (nacheinander, standardmäßig nur WLAN), Liste „Downloads“, ohne Internet öffnet sie sich von selbst, Position offline merken und nachmelden | `Downloads.swift`, `DownloadsViewController.swift`, `Ressourcen/kinolelDownloads.js` |
| Format: MP4 – Original, wenn iPhone-tauglich (MP4/MOV mit H.264 oder HEVC „hvc1“), H.264 in MKV wird verlustfrei umgepackt, sonst H.264/AAC vom Server (`stream.mp4`); ein Untertitel eingebettet (mov_text) | `Downloads.swift` (`pfad`) |
| Server-Befehle (Pause/Weiter/Stopp/Spulen) laufen über den playbackManager an den Player; Nachrichten vom Server erscheinen über dem Player; kein Doppelstart (Fokus der Kachel wird gelöst); eine Sitzung je Gerät (Player nutzt die Adresse der Weboberfläche) | `Ressourcen/videoplayer.js`, `Ressourcen/nativeshell.js`, `Hinweis.swift` |
| **Was ist neu**: einmalige Meldung nach einem Update (de/hu/en) | `Neuigkeiten.swift`, `Ressourcen/neuigkeiten.json` |
| Hinweis auf neue Versionen (GitHub-Releases, höchstens alle 6 h); „Aktualisieren“ öffnet SideStore | `Aktualisierung.swift` |
| Links auf KinoLel Wünsche öffnen die App „KinoLel Wünsche“ (`kinolelwuensche://`) | `WebViewController.swift` |
| App-eigene Texte Deutsch/Ungarisch/Englisch | `Texte.swift` |

Neue Version: `MARKETING_VERSION` in `project.yml` erhöhen und oben in `Ressourcen/neuigkeiten.json` einen Eintrag
(de/hu/en, für Laien verständlich) ergänzen.

## Marke

Name, Server, Kennung (`de.kinolel.app`) und Version stehen an **einer** Stelle: `settings.base` in [`project.yml`](project.yml).
Name endgültig „KinoLel“. Bilder: `marke/ios_bilder.py` (aus dem KinoLel-Logo).

## Bauen

GitHub Actions (`.github/workflows/ios.yml`, macOS-Runner): `xcodegen generate` → `xcodebuild` →
unsignierte `.ipa` + Rauchtest im Simulator (Bildschirmfotos) + Oberflächentests (`KinoLelUITests`,
`.github/scripts/oberflaechentest.sh`; der Download-Teil braucht das Secret `KINOLEL_TEST_PW`). Tag `v*` → Vorab-Version.
Lokal auf einem Mac: `brew install xcodegen && xcodegen generate && open KinoLel.xcodeproj`.

Zum Installieren auf einem iPhone muss die App signiert werden – empfohlen kostenlos mit **SideStore**
([SIDESTORE.md](SIDESTORE.md), Quelle `https://kinolel.de/web/kinolel/sidestore.json`), sonst siehe
[TESTANLEITUNG.md](TESTANLEITUNG.md).
