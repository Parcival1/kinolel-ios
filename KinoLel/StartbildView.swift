// KinoLel-App (iOS): Startbild wie auf kinolel.de – Logo + Lavendel-Ladekreis, Hinweis bei Ausfall.
// Ohne Verbindung: Knopf „Meine Downloads (n)“ (wie die Android-App).
import UIKit

final class StartbildView: UIView {
    private let ring = CAShapeLayer()
    private let ringGrund = CAShapeLayer()
    private let logo = UIImageView(image: UIImage(named: "StartLogo"))
    private let status = UILabel()
    let knopf = UIButton(type: .system)
    let downloadsKnopf = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Marke.grund

        let kreis = UIView()
        kreis.translatesAutoresizingMaskIntoConstraints = false
        addSubview(kreis)
        let pfad = UIBezierPath(arcCenter: CGPoint(x: 88, y: 88), radius: 80, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        for (schicht, farbe) in [(ringGrund, Marke.lavendel.withAlphaComponent(0.14)), (ring, Marke.lavendel)] {
            schicht.path = pfad.cgPath
            schicht.fillColor = UIColor.clear.cgColor
            schicht.strokeColor = farbe.cgColor
            schicht.lineWidth = 5
            schicht.lineCap = .round
            schicht.frame = CGRect(x: 0, y: 0, width: 176, height: 176)
            kreis.layer.addSublayer(schicht)
        }
        ring.strokeEnd = 0.27
        let drehen = CABasicAnimation(keyPath: "transform.rotation.z")
        drehen.fromValue = 0
        drehen.toValue = Double.pi * 2
        drehen.duration = 1.1
        drehen.repeatCount = .infinity
        drehen.isRemovedOnCompletion = false
        ring.add(drehen, forKey: "drehen")

        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false
        kreis.addSubview(logo)

        status.textColor = Marke.text
        status.font = .preferredFont(forTextStyle: .body)
        status.textAlignment = .center
        status.numberOfLines = 0
        status.alpha = 0
        status.translatesAutoresizingMaskIntoConstraints = false
        addSubview(status)

        knopf.setTitle(Text.nochmal, for: .normal)
        knopf.setTitleColor(Marke.grund, for: .normal)
        knopf.titleLabel?.font = .boldSystemFont(ofSize: 17)
        knopf.backgroundColor = Marke.lavendel
        knopf.layer.cornerRadius = 6
        knopf.contentEdgeInsets = UIEdgeInsets(top: 10, left: 22, bottom: 10, right: 22)
        knopf.isHidden = true
        knopf.translatesAutoresizingMaskIntoConstraints = false
        addSubview(knopf)

        downloadsKnopf.setTitleColor(Marke.lavendel, for: .normal)
        downloadsKnopf.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        downloadsKnopf.isHidden = true
        downloadsKnopf.accessibilityIdentifier = "kinolel.start.downloads"
        downloadsKnopf.translatesAutoresizingMaskIntoConstraints = false
        addSubview(downloadsKnopf)

        NSLayoutConstraint.activate([
            kreis.widthAnchor.constraint(equalToConstant: 176),
            kreis.heightAnchor.constraint(equalToConstant: 176),
            kreis.centerXAnchor.constraint(equalTo: centerXAnchor),
            kreis.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            logo.centerXAnchor.constraint(equalTo: kreis.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: kreis.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 100),
            logo.heightAnchor.constraint(equalToConstant: 90),
            status.topAnchor.constraint(equalTo: kreis.bottomAnchor, constant: 28),
            status.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 16),
            status.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -16),
            knopf.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 16),
            knopf.centerXAnchor.constraint(equalTo: centerXAnchor),
            downloadsKnopf.topAnchor.constraint(equalTo: knopf.bottomAnchor, constant: 14),
            downloadsKnopf.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) nicht unterstützt") }

    func zeigeVerbinde() {
        status.text = Text.verbinde
        knopf.isHidden = true
        UIView.animate(withDuration: 0.4) { self.status.alpha = 1 }
    }

    /// downloads: Anzahl fertiger Downloads – dann Hinweis und Knopf „Meine Downloads (n)“
    func zeigeFehler(downloads: Int = 0) {
        status.text = Text.nichtErreichbar + (downloads > 0 ? "\n\n" + Text.offlineHinweis : "")
        downloadsKnopf.setTitle(Text.offlineDownloads(downloads), for: .normal)
        downloadsKnopf.isHidden = downloads == 0
        knopf.isHidden = false
        UIView.animate(withDuration: 0.4) { self.status.alpha = 1 }
    }

    func zuruecksetzen() {
        status.alpha = 0
        knopf.isHidden = true
        downloadsKnopf.isHidden = true
    }
}
