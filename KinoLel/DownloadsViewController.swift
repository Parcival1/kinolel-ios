// KinoLel-App (iOS): Liste „Downloads“ – Fortschritt, Qualität, Größe, Speicherplatz, „Nur im WLAN“, Abspielen (auch ohne
// Internet), Löschen. Geöffnet über das Profilmenü der Weboberfläche („Downloads“), den Download-Knopf eines fertigen
// Titels oder ohne Internet über das Startbild.
import UIKit

final class DownloadsViewController: UITableViewController {
    /// Download abspielen (WebViewController → PlayerController)
    var abspielen: ((OfflineTitel) -> Void)?

    private var eintraege: [OfflineTitel] = []
    private let wlanSchalter = UISwitch()
    private let leerText = UILabel()

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) nicht unterstützt") }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        title = Text.downloads
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: Text.fertig, style: .plain, target: self, action: #selector(schliessen))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "kinolel.downloads.fertig"
        tableView.backgroundColor = Marke.grund
        tableView.register(DownloadZelle.self, forCellReuseIdentifier: DownloadZelle.kennung)
        tableView.accessibilityIdentifier = "kinolel.downloads"

        wlanSchalter.onTintColor = Marke.lavendel
        wlanSchalter.addTarget(self, action: #selector(wlanGeaendert), for: .valueChanged)
        wlanSchalter.accessibilityIdentifier = "kinolel.downloads.nurwlan"

        leerText.text = Text.leer
        leerText.textColor = Marke.text
        leerText.numberOfLines = 0
        leerText.textAlignment = .center
        leerText.font = .preferredFont(forTextStyle: .body)

        NotificationCenter.default.addObserver(self, selector: #selector(aktualisieren), name: Downloads.geaendert, object: nil)
        aktualisieren()
    }

    @objc private func schliessen() { dismiss(animated: true) }

    @objc private func wlanGeaendert() { Downloads.shared.nurWlan = wlanSchalter.isOn }

    @objc private func aktualisieren() {
        let neu = Downloads.shared.liste
        let gleicheZeilen = neu.map(\.id) == eintraege.map(\.id)
        eintraege = neu
        wlanSchalter.isOn = Downloads.shared.nurWlan
        if gleicheZeilen, isViewLoaded {
            // Nur Inhalte erneuern – kein Springen der Liste während des Herunterladens
            for zelle in tableView.visibleCells {
                guard let zelle = zelle as? DownloadZelle, let pfad = tableView.indexPath(for: zelle),
                      pfad.section == 0, pfad.row < eintraege.count else { continue }
                zelle.zeige(eintraege[pfad.row], loeschen: { [weak self] in self?.loeschenFragen($0) })
            }
            tableView.reloadSections(IndexSet(integer: 1), with: .none)
        } else {
            tableView.reloadData()
        }
        tableView.backgroundView = eintraege.isEmpty ? leerText : nil
    }

    private var fussText: String {
        var text = Text.speicher(Downloads.menge(Downloads.shared.belegt), Downloads.menge(Downloads.frei)) + "\n" + Text.speicherort
        if !Downloads.shared.online { text = Text.offlineHinweis + "\n\n" + text }
        return text
    }

    private func loeschenFragen(_ t: OfflineTitel) {
        let frage = UIAlertController(title: Text.loeschen, message: t.name, preferredStyle: .alert)
        frage.addAction(UIAlertAction(title: Text.abbrechen, style: .cancel))
        frage.addAction(UIAlertAction(title: Text.loeschenKnopf, style: .destructive) { _ in Downloads.shared.loeschen(t.id) })
        present(frage, animated: true)
    }

    // MARK: Tabelle

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? eintraege.count : 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            let zelle = UITableViewCell(style: .default, reuseIdentifier: nil)
            var inhalt = zelle.defaultContentConfiguration()
            inhalt.text = Text.nurWlan
            zelle.contentConfiguration = inhalt
            zelle.accessoryView = wlanSchalter
            zelle.selectionStyle = .none
            return zelle
        }
        let zelle = tableView.dequeueReusableCell(withIdentifier: DownloadZelle.kennung, for: indexPath) as! DownloadZelle
        zelle.zeige(eintraege[indexPath.row], loeschen: { [weak self] in self?.loeschenFragen($0) })
        return zelle
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 1 ? fussText : nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0, indexPath.row < eintraege.count else { return }
        let t = eintraege[indexPath.row]
        switch t.zustand {
        case .fertig: abspielen?(t)
        case .fehler: Downloads.shared.erneut(t.id)
        default: break
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        guard indexPath.section == 0, indexPath.row < eintraege.count else { return nil }
        let id = eintraege[indexPath.row].id
        let aktion = UIContextualAction(style: .destructive, title: Text.loeschenKnopf) { _, _, fertig in
            Downloads.shared.loeschen(id)
            fertig(true)
        }
        aktion.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [aktion])
    }
}

/// Eine Zeile: Bild, Titel, Folge, Zustand, Fortschritt, Papierkorb
final class DownloadZelle: UITableViewCell {
    static let kennung = "download"
    private let fortschritt = UIProgressView(progressViewStyle: .default)
    private let papierkorb = UIButton(type: .system)
    private var titel: OfflineTitel?
    private var loeschen: ((OfflineTitel) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        fortschritt.progressTintColor = Marke.lavendel
        fortschritt.trackTintColor = UIColor(white: 1, alpha: 0.12)
        fortschritt.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fortschritt)
        NSLayoutConstraint.activate([
            fortschritt.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            fortschritt.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            fortschritt.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
        papierkorb.setImage(UIImage(systemName: "trash"), for: .normal)
        papierkorb.tintColor = Marke.text
        papierkorb.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        papierkorb.accessibilityLabel = Text.loeschen
        papierkorb.addTarget(self, action: #selector(papierkorbGetippt), for: .touchUpInside)
        accessoryView = papierkorb
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) nicht unterstützt") }

    @objc private func papierkorbGetippt() {
        if let titel { loeschen?(titel) }
    }

    func zeige(_ t: OfflineTitel, loeschen: @escaping (OfflineTitel) -> Void) {
        titel = t
        self.loeschen = loeschen
        papierkorb.accessibilityIdentifier = "kinolel.download.\(t.id).loeschen"
        accessibilityIdentifier = "kinolel.download.\(t.id)"

        var inhalt = UIListContentConfiguration.subtitleCell()
        inhalt.text = t.name
        inhalt.textProperties.numberOfLines = 2
        var zeilen: [String] = []
        if !t.folgenZeile.isEmpty { zeilen.append(t.folgenZeile) }
        zeilen.append(zustandText(t))
        inhalt.secondaryText = zeilen.joined(separator: "\n")
        inhalt.secondaryTextProperties.color = t.zustand == .fehler ? UIColor.systemRed : Marke.text
        inhalt.secondaryTextProperties.numberOfLines = 3
        if let bild = UIImage(contentsOfFile: Downloads.bildDatei(t.id).path) {
            inhalt.image = bild
        } else {
            inhalt.image = UIImage(systemName: "film")
            inhalt.imageProperties.tintColor = Marke.lavendel
        }
        inhalt.imageProperties.maximumSize = CGSize(width: 96, height: 64)
        inhalt.imageProperties.reservedLayoutSize = CGSize(width: 96, height: 54)
        inhalt.imageProperties.cornerRadius = 4
        inhalt.directionalLayoutMargins.bottom = 14
        contentConfiguration = inhalt
        backgroundColor = UIColor(white: 1, alpha: 0.06)

        // Fortschritt: beim Herunterladen der Download, danach die Fortsetzen-Stelle
        switch t.zustand {
        case .laedt, .wartet:
            fortschritt.isHidden = false
            fortschritt.progress = Float(t.prozent ?? 0) / 100
        case .fertig where t.positionTicks > 0 && t.dauerTicks > 0:
            fortschritt.isHidden = false
            fortschritt.progress = Float(Double(t.positionTicks) / Double(t.dauerTicks))
        default:
            fortschritt.isHidden = true
        }
        accessibilityValue = t.zustand.rawValue
    }

    private func zustandText(_ t: OfflineTitel) -> String {
        switch t.zustand {
        case .fertig:
            var teile = [t.qualitaet.name, Downloads.menge(t.geladen)]
            if t.gesehen {
                teile.append(Text.gesehen)
            } else if t.positionTicks > 0 && t.dauerTicks > t.positionTicks {
                teile.append(Text.restZeit(Int((t.dauerTicks - t.positionTicks) / 600_000_000)))
            }
            return teile.joined(separator: " · ")
        case .laedt:
            return Text.laedt(t.prozent)
        case .wartet:
            return Downloads.shared.nurWlan && !Downloads.shared.wlan ? Text.wartetWlanKurz : Text.wartet
        case .fehler:
            return Text.fehler
        }
    }
}
