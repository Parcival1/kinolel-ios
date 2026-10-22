// KinoLel-App (iOS): Hinweis auf eine neue Version (wie die Android-App: GitHub-Releases, höchstens alle 6 Stunden).
// Ohne App Store kann sich eine iPhone-App nicht selbst installieren. Installiert wird über SideStore (Quelle
// https://kinolel.de/web/kinolel/sidestore.json, Lel 22.10.2026): „Aktualisieren“ öffnet SideStore, sonst AltStore,
// sonst die Download-Seite der neuen Version (z. B. für Sideloadly).
import UIKit

enum Aktualisierung {
    private static let repo = "Parcival1/kinolel-ios"
    private static let abstand: TimeInterval = 6 * 60 * 60
    private static let zuletztSchluessel = "kinolel.updateZuletzt"

    static func pruefen(auf gastgeber: UIViewController) {
        let jetzt = Date().timeIntervalSince1970
        guard jetzt - UserDefaults.standard.double(forKey: zuletztSchluessel) >= abstand,
              let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=10") else { return }
        UserDefaults.standard.set(jetzt, forKey: zuletztSchluessel)
        var anfrage = URLRequest(url: url, timeoutInterval: 15)
        anfrage.setValue("\(Marke.appName)-iOS/\(Marke.version)", forHTTPHeaderField: "User-Agent")
        anfrage.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: anfrage) { [weak gastgeber] daten, _, _ in
            guard let daten, let releases = (try? JSONSerialization.jsonObject(with: daten)) as? [[String: Any]] else { return }
            var beste = Versionsnummer.teile(Marke.version)
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
            guard let seite else { return }
            DispatchQueue.main.async {
                // Nicht über den Player oder andere Fenster legen – dann beim nächsten Start erneut
                guard let gastgeber, gastgeber.view.window != nil, gastgeber.presentedViewController == nil else {
                    UserDefaults.standard.removeObject(forKey: zuletztSchluessel)
                    return
                }
                KinoLelDialog(titel: Text.updateTitel, text: Text.updateText(Versionsnummer.text(beste)), knoepfe: [
                    KinoLelDialog.Knopf(titel: Text.updateSpaeter),
                    KinoLelDialog.Knopf(titel: Text.updateJetzt, art: .haupt, kennung: "kinolel.update.jetzt") {
                        oeffne(["sidestore://", "altstore://"], sonst: seite)
                    }
                ]).zeigen(auf: gastgeber)
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
