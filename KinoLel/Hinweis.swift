// KinoLel-App (iOS): kurzer Hinweis oben im Fenster – über allem, auch über dem Vollbild-Player (wie ein Android-Toast).
// Für Download-Meldungen und für Nachrichten vom Server (Dashboard „Nachricht senden“, KinoLel-Streams-Grenze).
import UIKit

enum Hinweis {
    static func zeigen(_ text: String, kopf: String? = nil, sekunden: TimeInterval = 4, in fenster: UIWindow?) {
        guard let fenster, !(text.isEmpty && (kopf ?? "").isEmpty) else { return }
        let band = UIView()
        band.backgroundColor = UIColor(red: 0x16 / 255.0, green: 0x1B / 255.0, blue: 0x2A / 255.0, alpha: 0.97)
        band.layer.cornerRadius = 12
        band.layer.borderColor = Marke.lavendel.withAlphaComponent(0.6).cgColor
        band.layer.borderWidth = 1
        band.alpha = 0
        band.translatesAutoresizingMaskIntoConstraints = false

        let inhalt = NSMutableAttributedString()
        let schrift = UIFont.preferredFont(forTextStyle: .subheadline)
        if let kopf, !kopf.isEmpty {
            inhalt.append(NSAttributedString(string: kopf + (text.isEmpty ? "" : "\n"), attributes: [
                .font: UIFont.boldSystemFont(ofSize: schrift.pointSize + 1), .foregroundColor: Marke.lavendel
            ]))
        }
        inhalt.append(NSAttributedString(string: text, attributes: [.font: schrift, .foregroundColor: UIColor.white]))
        let beschriftung = UILabel()
        beschriftung.attributedText = inhalt
        beschriftung.numberOfLines = 0
        beschriftung.translatesAutoresizingMaskIntoConstraints = false
        band.addSubview(beschriftung)
        band.isAccessibilityElement = true
        band.accessibilityLabel = [kopf, text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". ")
        band.accessibilityIdentifier = "kinolel.hinweis"

        fenster.addSubview(band)
        NSLayoutConstraint.activate([
            band.topAnchor.constraint(equalTo: fenster.safeAreaLayoutGuide.topAnchor, constant: 8),
            band.centerXAnchor.constraint(equalTo: fenster.centerXAnchor),
            band.leadingAnchor.constraint(greaterThanOrEqualTo: fenster.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            band.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
            beschriftung.topAnchor.constraint(equalTo: band.topAnchor, constant: 12),
            beschriftung.bottomAnchor.constraint(equalTo: band.bottomAnchor, constant: -12),
            beschriftung.leadingAnchor.constraint(equalTo: band.leadingAnchor, constant: 16),
            beschriftung.trailingAnchor.constraint(equalTo: band.trailingAnchor, constant: -16)
        ])
        let breit = band.widthAnchor.constraint(equalTo: fenster.safeAreaLayoutGuide.widthAnchor, constant: -24)
        breit.priority = .defaultHigh
        breit.isActive = true

        let weg = { [weak band] in
            guard let band, band.superview != nil else { return }
            UIView.animate(withDuration: 0.3, animations: { band.alpha = 0 }) { _ in band.removeFromSuperview() }
        }
        band.addGestureRecognizer(Antipper(weg))
        UIView.animate(withDuration: 0.25) { band.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + max(2, sekunden), execute: weg)
        UIAccessibility.post(notification: .announcement, argument: band.accessibilityLabel)
    }
}

/// Tippen schließt den Hinweis
private final class Antipper: UITapGestureRecognizer {
    private let aktion: () -> Void

    init(_ aktion: @escaping () -> Void) {
        self.aktion = aktion
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(getippt))
    }

    @objc private func getippt() { aktion() }
}
