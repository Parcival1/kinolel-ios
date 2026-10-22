# KinoLel auf dem iPhone mit SideStore (kostenlos)

Apple lässt Apps außerhalb des App Stores nur mit einer **Signatur** auf das iPhone. Mit einer **kostenlosen Apple-ID**
gilt sie **7 Tage**. **SideStore** ist eine App, die diese Signatur **auf dem iPhone selbst** erneuert – nach der
einmaligen Einrichtung am PC braucht es den PC normalerweise nicht mehr.

Über die **KinoLel-Quelle** zeigt SideStore die Apps **KinoLel** und **KinoLel Wünsche** an, und neue Versionen
erscheinen dort als Update.

## Gut zu wissen (Regeln von Apple für kostenlose Apple-IDs)

| Regel | Für KinoLel |
|---|---|
| Höchstens **3 Apps** gleichzeitig – **SideStore zählt mit** | SideStore + KinoLel + KinoLel Wünsche = genau 3 ✅ |
| Höchstens 10 neue Apps pro Woche | kein Problem |
| Signatur gilt **7 Tage** | SideStore frischt auf (siehe „Jede Woche“) – sonst starten die Apps nicht mehr |
| Auffrischen nur mit **WLAN** und eingeschalteter **LocalDevVPN**-App | LocalDevVPN ist eine kleine Hilfs-App aus dem App Store |

Empfehlung: eine **eigene, kostenlose Apple-ID nur für SideStore** anlegen (nicht die Haupt-Apple-ID). Sie muss nicht
die Apple-ID des iPhones sein.

## Was du brauchst

- iPhone oder iPad mit **iOS 16 oder neuer** und Code-Sperre
- **Windows-PC** (oder Mac/Linux) und ein **USB-Kabel**
- WLAN
- etwa **30 Minuten** für die einmalige Einrichtung

## Einmalig einrichten

**Auf dem iPhone**
1. Im App Store die App **LocalDevVPN** installieren
   ([Link](https://apps.apple.com/app/localdevvpn/id6755608044)).

**Am PC (Windows)**
2. **iTunes direkt von Apple** installieren (nicht aus dem Microsoft Store):
   <https://www.apple.com/itunes/download/win64>
3. **iloader** installieren: <https://github.com/nab138/iloader/releases/latest/download/iloader-windows-x64.msi>
   (Mac/Linux: siehe <https://iloader.app>).
4. iPhone per Kabel anschließen. Auf dem iPhone **„Vertrauen“** tippen und den Code eingeben.
5. **iloader** öffnen → mit der Apple-ID anmelden (Groß-/Kleinschreibung beachten) → das iPhone auswählen →
   **„Install SideStore (Stable)“**.

**Wieder auf dem iPhone**
6. **Einstellungen → Allgemein → VPN & Geräteverwaltung** → unter „Entwickler-App“ die Apple-ID antippen →
   **„… vertrauen“** (je nach iOS-Version auch **„Erlauben & neu starten“**).
7. **Einstellungen → Datenschutz & Sicherheit** → ganz unten **„Entwicklermodus“** einschalten → das iPhone startet neu →
   danach **„Aktivieren“** bestätigen. (Erscheint der Punkt nicht, diesen Schritt auslassen.)
8. **LocalDevVPN** öffnen → **„Connect“**.
9. **SideStore** öffnen → mit **derselben Apple-ID** anmelden → **„My Apps“** → bei SideStore auf **„7 DAYS“** tippen.
   Fragt SideStore nach einem Zertifikat, **„Yes“** bzw. **„Refresh Now“** wählen.
10. **KinoLel-Quelle hinzufügen:** SideStore → **„Sources“** → **„+“** → diese Adresse eingeben:

    ```
    https://kinolel.de/web/kinolel/sidestore.json
    ```

11. In der Quelle **KinoLel** öffnen → **„Free“/„Get“** tippen, ebenso **KinoLel Wünsche**. Beide Symbole erscheinen auf
    dem Home-Bildschirm.

Der PC wird danach nur noch gebraucht, wenn etwas schiefgeht (siehe unten).

## Jede Woche (spätestens alle 7 Tage)

**Von Hand (1 Minute):** WLAN an → **LocalDevVPN** öffnen → „Connect“ → **SideStore** → „My Apps“ → **„Refresh All“**.
Die Zahl neben jeder App zeigt die verbleibenden Tage.

**Automatisch (empfohlen):** SideStore frischt auch selbst im Hintergrund auf, solange LocalDevVPN verbunden ist.
Zusätzlich kann ein Kurzbefehl das jede Nacht anstoßen:
1. App **Kurzbefehle** → **„Automation“** → **„+“** → **„Tageszeit“** (z. B. 3:00 Uhr, **täglich**) →
   **„Sofort ausführen“** → **„Weiter“**.
2. Aktion **„SideStore“** suchen → **„Refresh Apps“** / **„Apps aktualisieren“** wählen → bei der Aktion
   „Beim Ausführen anzeigen“ **ausschalten** → „Fertig“.
3. Den Kurzbefehl einmal von Hand starten und alle Fragen erlauben.
4. **LocalDevVPN** verbunden lassen. Das iPhone sollte nachts im WLAN sein.

## Updates

Gibt es eine neue Version, zeigt SideStore sie unter **„My Apps“ → „Updates“**. Auch KinoLel selbst meldet sich
(„Update verfügbar“ → **„Aktualisieren“** öffnet SideStore). Dort bei der App auf **„Update“** tippen.
Nach dem ersten Start einer neuen Version zeigt die App einmal kurz, was neu ist.

## Wenn etwas nicht geht

| Problem | Lösung |
|---|---|
| App startet nicht mehr / „nicht mehr verfügbar“ | 7 Tage nicht aufgefrischt → LocalDevVPN verbinden → SideStore → „Refresh All“ |
| SideStore selbst startet nicht mehr | am PC mit **iloader** SideStore erneut installieren (Schritt 5) – die KinoLel-Apps und deine Downloads bleiben |
| Auffrischen schlägt fehl (z. B. nach einem iOS-Update) | die „Pairing-Datei“ ist abgelaufen → iPhone an den PC, **iloader** öffnen und die Pairing-Datei neu aufs iPhone übertragen |
| „Maximum App limit reached“ | es sind schon 3 Apps über SideStore installiert – eine andere über SideStore löschen |
| Keine Bestätigungs-Code-Anzeige der Apple-ID | Code unter Einstellungen → [dein Name] → Anmelden & Sicherheit holen |

Hilfe zu SideStore: <https://docs.sidestore.io>

## Alternative ohne Einrichtung: KinoLel als Web-App

In **Safari** <https://kinolel.de> öffnen → **Teilen** → **„Zum Home-Bildschirm“**. KinoLel startet dann wie eine App
(eigenes Symbol, Vollbild, Startbild, ohne Internet eine verständliche Seite).
Grenzen: **kein Herunterladen**, und beim **Sperren des Bildschirms oder Wechsel in eine andere App stoppt die
Wiedergabe** in der Regel (Apple erlaubt Web-Apps keine zuverlässige Hintergrund-Wiedergabe). Für Filme unterwegs
und im Hintergrund daher die App über SideStore nehmen.

## Für Entwickler

- Quelle: `https://kinolel.de/web/kinolel/sidestore.json` (AltStore-Format, das SideStore liest), erzeugt stündlich
  von CT 103 `/dokumentation/werkzeuge/sidestore_quelle.py` aus den GitHub-Releases von `kinolel-ios` und
  `kinolel-wuensche-ios` (auch Vorabversionen). Beschreibung je Version = deutsche Einträge aus `neuigkeiten.json`.
- Die IPA ist unsigniert; SideStore signiert sie mit der Apple-ID. Die Apps nutzen keine besonderen Berechtigungen
  (`appPermissions` leer). `CFBundleVersion` bleibt `1`; Updates erkennt SideStore an der Version.
