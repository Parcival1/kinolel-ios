// KinoLel-App (iOS): Dialoge im Design der Weboberfläche (Lel 22.10.2026: „Text/Meldung in derselben Designfarbe etc.
// wie die App“) – dunkle Karte #1b1d2a mit feinem hellem Rand und runden Ecken, Schrift Inter, Hauptknopf gefüllt in
// Lavendel, normale Groß-/Kleinschreibung. Ersetzt die grauen iOS-Standarddialoge (Was ist neu, Update-Hinweis,
// Qualitätswahl, Download löschen).
import UIKit

/// Schrift der Weboberfläche (Inter, Ressourcen/Inter-*.otf, Info.plist UIAppFonts) – sonst Systemschrift
enum Schrift {
    static func normal(_ groesse: CGFloat) -> UIFont {
        UIFont(name: "Inter-Regular", size: groesse) ?? .systemFont(ofSize: groesse)
    }

    static func fett(_ groesse: CGFloat) -> UIFont {
        UIFont(name: "Inter-SemiBold", size: groesse) ?? .systemFont(ofSize: groesse, weight: .semibold)
    }
}

final class KinoLelDialog: UIViewController {
    enum Art {
        case haupt    // gefüllt, Lavendel
        case normal   // Text in Lavendel
        case wahl     // Auswahl (z. B. Qualität): helle Fläche, ganze Breite
    }

    struct Knopf {
        let titel: String
        var art: Art = .normal
        var aktiv = true
        var kennung: String?
        var aktion: (() -> Void)?
    }

    static let grund = UIColor(red: 0x1B / 255.0, green: 0x1D / 255.0, blue: 0x2A / 255.0, alpha: 1)

    private let titel: String
    private let text: NSAttributedString?
    private let knoepfe: [Knopf]
    private let titelKennung: String?
    /// Nach dem Schließen (egal mit welchem Knopf)
    var beimSchliessen: (() -> Void)?

    init(titel: String, text: String? = nil, attributiert: NSAttributedString? = nil, knoepfe: [Knopf], titelKennung: String? = nil) {
        self.titel = titel
        if let attributiert {
            self.text = attributiert
        } else if let text, !text.isEmpty {
            self.text = KinoLelDialog.absatz(text)
        } else {
            self.text = nil
        }
        self.knoepfe = knoepfe
        self.titelKennung = titelKennung
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) nicht unterstützt") }

    /// Fließtext im Dialog: hellgrau, Inter, etwas Zeilenabstand
    static func absatz(_ text: String, farbe: UIColor = UIColor(white: 0.85, alpha: 1)) -> NSAttributedString {
        let stil = NSMutableParagraphStyle()
        stil.lineSpacing = 3
        stil.paragraphSpacing = 8
        return NSAttributedString(string: text, attributes: [.font: Schrift.normal(16), .foregroundColor: farbe, .paragraphStyle: stil])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        let karte = UIView()
        karte.backgroundColor = Self.grund
        karte.layer.cornerRadius = 18
        karte.layer.cornerCurve = .continuous
        karte.layer.borderWidth = 1
        karte.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        karte.layer.shadowColor = UIColor.black.cgColor
        karte.layer.shadowOpacity = 0.5
        karte.layer.shadowRadius = 24
        karte.layer.shadowOffset = CGSize(width: 0, height: 8)
        karte.translatesAutoresizingMaskIntoConstraints = false
        karte.accessibilityViewIsModal = true
        view.addSubview(karte)

        let ueberschrift = UILabel()
        ueberschrift.text = titel
        ueberschrift.font = Schrift.fett(20)
        ueberschrift.textColor = .white
        ueberschrift.numberOfLines = 0
        ueberschrift.accessibilityTraits = .header
        ueberschrift.accessibilityIdentifier = titelKennung ?? "kinolel.dialog.titel"

        let stapel = UIStackView(arrangedSubviews: [ueberschrift])
        stapel.axis = .vertical
        stapel.spacing = 14
        stapel.translatesAutoresizingMaskIntoConstraints = false
        karte.addSubview(stapel)

        var textHoehe: NSLayoutConstraint?
        if let text {
            let feld = UITextView()
            feld.attributedText = text
            feld.isEditable = false
            feld.backgroundColor = .clear
            feld.textContainerInset = .zero
            feld.textContainer.lineFragmentPadding = 0
            feld.isScrollEnabled = true
            feld.showsVerticalScrollIndicator = true
            feld.indicatorStyle = .white
            feld.accessibilityIdentifier = "kinolel.dialog.text"
            stapel.addArrangedSubview(feld)
            // So hoch wie der Text, höchstens etwa die halbe Bildschirmhöhe (dann scrollbar)
            let breite = min(UIScreen.main.bounds.width - 40, 440) - 48
            let noetig = ceil(text.boundingRect(with: CGSize(width: breite, height: .greatestFiniteMagnitude),
                                                options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height) + 4
            textHoehe = feld.heightAnchor.constraint(equalToConstant: min(noetig, UIScreen.main.bounds.height * 0.5))
            textHoehe?.isActive = true
        }

        // Knöpfe: zwei einfache nebeneinander (rechts), sonst untereinander in ganzer Breite
        let nebeneinander = knoepfe.count <= 2 && !knoepfe.contains { $0.art == .wahl }
        let leiste = UIStackView()
        leiste.axis = nebeneinander ? .horizontal : .vertical
        leiste.spacing = nebeneinander ? 12 : 10
        leiste.alignment = nebeneinander ? .center : .fill
        leiste.distribution = nebeneinander ? .fillEqually : .fill
        for (i, knopf) in knoepfe.enumerated() {
            leiste.addArrangedSubview(knopfAnsicht(knopf, nummer: i))
        }
        stapel.setCustomSpacing(22, after: stapel.arrangedSubviews.last ?? ueberschrift)
        stapel.addArrangedSubview(leiste)

        NSLayoutConstraint.activate([
            karte.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            karte.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            karte.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -40).withPrioritaet(.defaultHigh),
            karte.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
            karte.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stapel.topAnchor.constraint(equalTo: karte.topAnchor, constant: 24),
            stapel.leadingAnchor.constraint(equalTo: karte.leadingAnchor, constant: 24),
            stapel.trailingAnchor.constraint(equalTo: karte.trailingAnchor, constant: -24),
            stapel.bottomAnchor.constraint(equalTo: karte.bottomAnchor, constant: -20)
        ])
        UIAccessibility.post(notification: .screenChanged, argument: ueberschrift)
    }

    private func knopfAnsicht(_ knopf: Knopf, nummer: Int) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(knopf.titel, for: .normal)
        b.titleLabel?.font = Schrift.fett(16)
        b.titleLabel?.numberOfLines = 0
        b.titleLabel?.textAlignment = .center
        b.layer.cornerRadius = 12
        b.layer.cornerCurve = .continuous
        b.isEnabled = knopf.aktiv
        b.alpha = knopf.aktiv ? 1 : 0.4
        b.tag = nummer
        b.accessibilityIdentifier = knopf.kennung
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        switch knopf.art {
        case .haupt:
            b.backgroundColor = Marke.lavendel
            b.setTitleColor(Marke.grund, for: .normal)
        case .normal:
            b.setTitleColor(Marke.lavendel, for: .normal)
        case .wahl:
            b.backgroundColor = UIColor.white.withAlphaComponent(0.06)
            b.layer.borderWidth = 1
            b.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
            b.setTitleColor(.white, for: .normal)
            b.titleLabel?.font = Schrift.normal(16)
        }
        b.addTarget(self, action: #selector(getippt(_:)), for: .touchUpInside)
        return b
    }

    @objc private func getippt(_ sender: UIButton) {
        let aktion = knoepfe[sender.tag].aktion
        dismiss(animated: true) { [beimSchliessen] in
            aktion?()
            beimSchliessen?()
        }
    }

    /// Dialog über dem obersten sichtbaren Bildschirm zeigen
    func zeigen(auf gastgeber: UIViewController) {
        var oben = gastgeber
        while let weiter = oben.presentedViewController, !weiter.isBeingDismissed { oben = weiter }
        oben.present(self, animated: true)
    }
}

private extension NSLayoutConstraint {
    func withPrioritaet(_ p: UILayoutPriority) -> NSLayoutConstraint {
        priority = p
        return self
    }
}
