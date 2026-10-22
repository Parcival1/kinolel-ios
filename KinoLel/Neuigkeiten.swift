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
        let ansicht = NeuigkeitenViewController(eintraege: offen, fertig: fertig)
        offen = []
        gastgeber.present(ansicht, animated: true)
    }
}

final class NeuigkeitenViewController: UIViewController {
    private let eintraege: [Neuigkeiten.Eintrag]
    private let fertig: () -> Void

    init(eintraege: [Neuigkeiten.Eintrag], fertig: @escaping () -> Void) {
        self.eintraege = eintraege
        self.fertig = fertig
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let blatt = sheetPresentationController {
            blatt.detents = [.medium(), .large()]
            blatt.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) nicht unterstützt") }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = Marke.grund

        let ueberschrift = UILabel()
        ueberschrift.text = Text.neuTitel(Marke.version)
        ueberschrift.font = .preferredFont(forTextStyle: .title2).fett
        ueberschrift.textColor = Marke.lavendel
        ueberschrift.numberOfLines = 0
        ueberschrift.accessibilityIdentifier = "kinolel.neuigkeiten.titel"

        let text = UITextView()
        text.isEditable = false
        text.backgroundColor = .clear
        text.textContainerInset = .zero
        text.textContainer.lineFragmentPadding = 0
        text.attributedText = inhalt()
        text.accessibilityIdentifier = "kinolel.neuigkeiten.text"

        let knopf = UIButton(type: .system)
        knopf.setTitle(Text.neuOk, for: .normal)
        knopf.setTitleColor(Marke.grund, for: .normal)
        knopf.titleLabel?.font = .boldSystemFont(ofSize: 17)
        knopf.backgroundColor = Marke.lavendel
        knopf.layer.cornerRadius = 10
        knopf.accessibilityIdentifier = "kinolel.neuigkeiten.ok"
        knopf.addTarget(self, action: #selector(schliessen), for: .touchUpInside)

        for v in [ueberschrift, text, knopf] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        let rand = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            ueberschrift.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            ueberschrift.leadingAnchor.constraint(equalTo: rand.leadingAnchor, constant: 8),
            ueberschrift.trailingAnchor.constraint(equalTo: rand.trailingAnchor, constant: -8),
            text.topAnchor.constraint(equalTo: ueberschrift.bottomAnchor, constant: 16),
            text.leadingAnchor.constraint(equalTo: ueberschrift.leadingAnchor),
            text.trailingAnchor.constraint(equalTo: ueberschrift.trailingAnchor),
            text.bottomAnchor.constraint(equalTo: knopf.topAnchor, constant: -16),
            knopf.leadingAnchor.constraint(equalTo: ueberschrift.leadingAnchor),
            knopf.trailingAnchor.constraint(equalTo: ueberschrift.trailingAnchor),
            knopf.heightAnchor.constraint(equalToConstant: 50),
            knopf.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    /// Versionen fett (nur bei mehreren), Punkte mit hängendem Einzug
    private func inhalt() -> NSAttributedString {
        let ergebnis = NSMutableAttributedString()
        let normal = UIFont.preferredFont(forTextStyle: .body)
        let punkt = NSMutableParagraphStyle()
        punkt.headIndent = 18
        punkt.firstLineHeadIndent = 0
        punkt.tabStops = [NSTextTab(textAlignment: .left, location: 18)]
        punkt.paragraphSpacing = 8
        let kopf = NSMutableParagraphStyle()
        kopf.paragraphSpacingBefore = 6
        kopf.paragraphSpacing = 6
        for (i, eintrag) in eintraege.enumerated() {
            if eintraege.count > 1 {
                ergebnis.append(NSAttributedString(string: (i > 0 ? "\n" : "") + Text.neuVersion(eintrag.version) + "\n", attributes: [
                    .font: normal.fett, .foregroundColor: UIColor.white.withAlphaComponent(0.85), .paragraphStyle: kopf
                ]))
            }
            for p in eintrag.punkte {
                ergebnis.append(NSAttributedString(string: "•\t" + p + "\n", attributes: [
                    .font: normal, .foregroundColor: UIColor.white, .paragraphStyle: punkt
                ]))
            }
        }
        return ergebnis
    }

    @objc private func schliessen() { dismiss(animated: true) }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Knopf oder Wegwischen des Blatts: danach weitermachen (z. B. Update-Hinweis)
        if isBeingDismissed || presentingViewController == nil { fertig() }
    }
}

private extension UIFont {
    var fett: UIFont {
        guard let beschreibung = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: beschreibung, size: 0)
    }
}
