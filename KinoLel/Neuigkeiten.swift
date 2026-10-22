// KinoLel-App (iOS): einmalige Meldung „Neu in KinoLel x.y.z“ nach einem Update (Lel 22.10.2026) – wie in der Android-
// und Windows-App. Texte: Ressourcen/neuigkeiten.json (de/hu/en, für Laien verständlich).
// Neuinstallation: keine Meldung. Erstes Update auf eine Version mit dieser Meldung (noch nichts gespeichert): die zwei
// neuesten Einträge. Danach alles, was seit der zuletzt gezeigten Version dazugekommen ist.
import UIKit

enum Versionsnummer {
    /// „v0.1.2“ / „0.1.2-test“ → [0, 1, 2]
    static func teile(_ text: String) -> [Int] {
        var t = text.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("v") { t.removeFirst() }
        let kern = t.split(separator: "-", maxSplits: 1).first.map(String.init) ?? t
        return kern.split(separator: ".").map { Int($0) ?? 0 }
    }

    static func vergleiche(_ a: [Int], _ b: [Int]) -> Int {
        for i in 0..<max(a.count, b.count) {
            let unterschied = (i < a.count ? a[i] : 0) - (i < b.count ? b[i] : 0)
            if unterschied != 0 { return unterschied }
        }
        return 0
    }

    static func text(_ teile: [Int]) -> String { teile.map(String.init).joined(separator: ".") }
}

enum Neuigkeiten {
    struct Eintrag { let version: String; let punkte: [String] }

    private static let gesehenSchluessel = "kinolel.neuigkeitenGesehen"
    private static let ohneVorgaenger = 2
    /// Beim Start ermittelt (vor dem ersten WKWebView, siehe frueherGenutzt), gezeigt nach dem Laden der Seite
    private(set) static var offen: [Eintrag] = []

    /// Beim App-Start aufrufen: offene Einträge ermitteln und die aktuelle Version als gesehen merken
    static func vorbereiten() {
        let vorlieben = UserDefaults.standard
        let aktuell = Versionsnummer.teile(Marke.version)
        var gesehenText = vorlieben.string(forKey: gesehenSchluessel)
        #if DEBUG
        // Test im Simulator: so tun, als käme das Update von dieser Version (-KinoLelTestNeuigkeitenSeit 0.1.1)
        if let test = vorlieben.string(forKey: "KinoLelTestNeuigkeitenSeit") { gesehenText = test }
        #endif
        if let gesehenText, Versionsnummer.vergleiche(Versionsnummer.teile(gesehenText), aktuell) >= 0 { return }
        let aktualisiert = gesehenText != nil || frueherGenutzt()
        vorlieben.set(Versionsnummer.text(aktuell), forKey: gesehenSchluessel)
        guard aktualisiert else { return }

        guard let url = Bundle.main.url(forResource: "neuigkeiten", withExtension: "json"),
              let daten = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: daten) as? [String: Any],
              let versionen = json["versionen"] as? [[String: Any]] else { return }
        let sprache = Sprache.aktuell.rawValue
        let gesehen = gesehenText.map(Versionsnummer.teile)
        var liste: [(teile: [Int], eintrag: Eintrag)] = []
        for v in versionen {
            guard let text = v["version"] as? String else { continue }
            let teile = Versionsnummer.teile(text)
            guard Versionsnummer.vergleiche(teile, aktuell) <= 0 else { continue }
            if let gesehen, Versionsnummer.vergleiche(teile, gesehen) <= 0 { continue }
            let punkte = (v[sprache] as? [String]) ?? (v["de"] as? [String]) ?? []
            if !punkte.isEmpty { liste.append((teile, Eintrag(version: text, punkte: punkte))) }
        }
        liste.sort { Versionsnummer.vergleiche($0.teile, $1.teile) > 0 }
        offen = (gesehen == nil ? Array(liste.prefix(ohneVorgaenger)) : liste).map(\.eintrag)
        NSLog("KinoLel: Was ist neu – %ld Einträge", offen.count)
    }

    /// Gab es die App schon vorher? Ältere Versionen haben nichts gespeichert, aber die Weboberfläche lief schon
    /// (Daten des WKWebView unter Library/WebKit bzw. Cookies).
    private static func frueherGenutzt() -> Bool {
        let bibliothek = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return ["WebKit", "Cookies"].contains {
            FileManager.default.fileExists(atPath: bibliothek.appendingPathComponent($0).path)
        }
    }

    /// Meldung zeigen (einmal); fertig wird nach dem Schließen aufgerufen – oder sofort, wenn es nichts zu zeigen gibt
    static func zeigen(auf gastgeber: UIViewController, fertig: @escaping () -> Void) {
        guard !offen.isEmpty else { return fertig() }
        let dialog = KinoLelDialog(titel: Text.neuTitel(Marke.version), attributiert: inhalt(offen),
                                   knoepfe: [KinoLelDialog.Knopf(titel: Text.neuOk, art: .haupt, kennung: "kinolel.neuigkeiten.ok")],
                                   titelKennung: "kinolel.neuigkeiten.titel")
        dialog.beimSchliessen = fertig
        offen = []
        dialog.zeigen(auf: gastgeber)
    }

    /// Versionen fett (nur bei mehreren), Punkte mit hängendem Einzug
    private static func inhalt(_ eintraege: [Eintrag]) -> NSAttributedString {
        let ergebnis = NSMutableAttributedString()
        let punkt = NSMutableParagraphStyle()
        punkt.headIndent = 18
        punkt.tabStops = [NSTextTab(textAlignment: .left, location: 18)]
        punkt.paragraphSpacing = 8
        punkt.lineSpacing = 2
        let kopf = NSMutableParagraphStyle()
        kopf.paragraphSpacingBefore = 6
        kopf.paragraphSpacing = 6
        for (i, eintrag) in eintraege.enumerated() {
            if eintraege.count > 1 {
                ergebnis.append(NSAttributedString(string: (i > 0 ? "\n" : "") + Text.neuVersion(eintrag.version) + "\n", attributes: [
                    .font: Schrift.fett(16), .foregroundColor: UIColor.white, .paragraphStyle: kopf
                ]))
            }
            for p in eintrag.punkte {
                ergebnis.append(NSAttributedString(string: "•\t" + p + "\n", attributes: [
                    .font: Schrift.normal(16), .foregroundColor: UIColor(white: 0.88, alpha: 1), .paragraphStyle: punkt
                ]))
            }
        }
        return ergebnis
    }
}
