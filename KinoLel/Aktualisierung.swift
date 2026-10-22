// KinoLel-App (iOS): Hinweis auf eine neue Version (wie die Android-App).
// Lel 22.10.2026: bei jedem Öffnen und Zurückkehren prüfen (höchstens einmal pro Minute); „Später“ gilt 4 Stunden für
// dieselbe Version. Gefragt wird die Versionsliste auf kinolel.de (stündlich aus den GitHub-Releases, CT 103
// apps_links.py), GitHub nur, wenn sie nicht erreichbar ist (dort ohne Anmeldung 60 Abfragen/Stunde je Anschluss).
// Ohne App Store kann sich eine iPhone-App nicht selbst installieren. Installiert wird über SideStore (Quelle
// https://kinolel.de/web/kinolel/sidestore.json): „Aktualisieren“ öffnet SideStore, sonst AltStore, sonst die
// Download-Seite der neuen Version (z. B. für Sideloadly).
import UIKit

enum Aktualisierung {
    private static let repo = "Parcival1/kinolel-ios"
    private static let listenSchluessel = "ios"
    private static let minAbstand: TimeInterval = 60
    private static let spaeterDauer: TimeInterval = 4 * 60 * 60
    private static let zuletztSchluessel = "kinolel.updateZuletzt"
    private static let spaeterVersionSchluessel = "kinolel.updateSpaeterVersion"
    private static let spaeterZeitSchluessel = "kinolel.updateSpaeterZeit"
    private static var zeigt = false

    static func pruefen(auf gastgeber: UIViewController) {
        let jetzt = Date().timeIntervalSince1970
        guard !zeigt, jetzt - UserDefaults.standard.double(forKey: zuletztSchluessel) >= minAbstand else { return }
        UserDefaults.standard.set(jetzt, forKey: zuletztSchluessel)
        suchen { neu in
            DispatchQueue.main.async { [weak gastgeber] in
                guard let neu, let gastgeber else { return }
                zeigen(neu.version, neu.seite, auf: gastgeber)
            }
        }
    }

    private static func zeigen(_ version: [Int], _ seite: URL, auf gastgeber: UIViewController) {
        let text = Versionsnummer.text(version)
        let vorlieben = UserDefaults.standard
        if vorlieben.string(forKey: spaeterVersionSchluessel) == text,
           Date().timeIntervalSince1970 - vorlieben.double(forKey: spaeterZeitSchluessel) < spaeterDauer { return }
        // Nicht über den Player oder andere Fenster legen – beim nächsten Öffnen erneut
        guard !zeigt, gastgeber.view.window != nil, gastgeber.presentedViewController == nil else {
            vorlieben.removeObject(forKey: zuletztSchluessel)
            return
        }
        zeigt = true
        let dialog = KinoLelDialog(titel: Text.updateTitel, text: Text.updateText(text), knoepfe: [
            KinoLelDialog.Knopf(titel: Text.updateSpaeter) {
                vorlieben.set(text, forKey: spaeterVersionSchluessel)
                vorlieben.set(Date().timeIntervalSince1970, forKey: spaeterZeitSchluessel)
            },
            KinoLelDialog.Knopf(titel: Text.updateJetzt, art: .haupt, kennung: "kinolel.update.jetzt") {
                oeffne(["sidestore://", "altstore://"], sonst: seite)
            }
        ])
        dialog.beimSchliessen = { zeigt = false }
        dialog.zeigen(auf: gastgeber)
    }

    /// Neuere Version (oder nil): erst die Versionsliste auf kinolel.de, sonst GitHub
    private static func suchen(_ fertig: @escaping ((version: [Int], seite: URL)?) -> Void) {
        let aktuell = Versionsnummer.teile(Marke.version)
        let liste = Marke.serverURL.appendingPathComponent("web/kinolel/apps.json")
        var anfrage = URLRequest(url: liste, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        anfrage.setValue("\(Marke.appName)-iOS/\(Marke.version)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: anfrage) { daten, antwort, _ in
            guard (antwort as? HTTPURLResponse)?.statusCode == 200, let daten,
                  let json = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any],
                  let eintrag = json[listenSchluessel] as? [String: Any],
                  let versionText = eintrag["version"] as? String,
                  let seite = (eintrag["seite"] as? String).flatMap({ URL(string: $0) }) else {
                NSLog("KinoLel-Update: Versionsliste nicht lesbar, frage GitHub")
                return ausGithub(aktuell, fertig)
            }
            let version = Versionsnummer.teile(versionText)
            fertig(Versionsnummer.vergleiche(version, aktuell) > 0 ? (version: version, seite: seite) : nil)
        }.resume()
    }

    private static func ausGithub(_ aktuell: [Int], _ fertig: @escaping ((version: [Int], seite: URL)?) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=10") else { return fertig(nil) }
        var anfrage = URLRequest(url: url, timeoutInterval: 15)
        anfrage.setValue("\(Marke.appName)-iOS/\(Marke.version)", forHTTPHeaderField: "User-Agent")
        anfrage.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: anfrage) { daten, _, _ in
            guard let daten, let releases = (try? JSONSerialization.jsonObject(with: daten)) as? [[String: Any]] else {
                return fertig(nil)
            }
            var beste = aktuell
            var seite: URL?
            for release in releases where (release["draft"] as? Bool) != true {
                let version = Versionsnummer.teile(release["tag_name"] as? String ?? "")
                let anhaenge = release["assets"] as? [[String: Any]] ?? []
                guard Versionsnummer.vergleiche(version, beste) > 0,
                      anhaenge.contains(where: { ($0["name"] as? String ?? "").hasSuffix(".ipa") }),
                      let adresse = (release["html_url"] as? String).flatMap({ URL(string: $0) }) else { continue }
                beste = version
                seite = adresse
            }
            if let seite {
                fertig((version: beste, seite: seite))
            } else {
                fertig(nil)
            }
        }.resume()
    }

    /// Erste App öffnen, die sich meldet (SideStore, AltStore) – sonst die Download-Seite
    private static func oeffne(_ adressen: [String], sonst seite: URL) {
        guard let erste = adressen.first, let url = URL(string: erste) else { return UIApplication.shared.open(seite) }
        UIApplication.shared.open(url) { geoeffnet in
            if !geoeffnet { oeffne(Array(adressen.dropFirst()), sonst: seite) }
        }
    }
}
