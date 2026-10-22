// KinoLel-App (iOS): Downloads wie bei Netflix (Lel 20.10.2026: „… downloaden und dann direkt in der App anschauen.
// Auch wenn kein Internet vorhanden ist.“) – wie in der Android-App:
//  - Format MP4 (AVPlayer spielt kein MKV/TS). „Original“ direkt, wenn die Datei schon iPhone-tauglich ist (MP4/MOV mit
//    H.264 oder HEVC „hvc1“), H.264 in anderen Behältern wird verlustfrei umgepackt. Kleinere Stufen wandelt der Server
//    beim Herunterladen um (H.264/AAC, „stream.mp4“). Ein Untertitel (Standard oder App-Sprache) wird eingebettet.
//  - Hintergrund-URLSession: lädt weiter, wenn die App zu ist; immer nur ein Download gleichzeitig (schont Server und
//    NAS); standardmäßig nur im WLAN.
//  - Geschützter App-Speicher (Application Support, nicht im iCloud-Backup).
//  - Wiedergabe-Position offline merken und später an Jellyfin melden (POST /UserItems/{id}/UserData).
import Foundation
import Network
import Security

// MARK: Titel aus der Weboberfläche (kinolelDownloads.js, Funktion „kompakt“)

struct WebTitel: Decodable {
    struct Video: Decodable { let codec: String?; let tag: String?; let profil: String?; let breite: Int?; let hoehe: Int? }
    struct Ton: Decodable { let index: Int; let codec: String?; let sprache: String?; let standard: Bool? }
    struct Untertitel: Decodable { let index: Int; let codec: String?; let sprache: String?; let standard: Bool? }
    struct Quelle: Decodable {
        let id: String
        let container: String?
        let groesse: Int64?
        let video: Video?
        let audio: [Ton]?
        let untertitel: [Untertitel]?
        let standardAudio: Int?
        let standardUntertitel: Int?
    }
    let id: String
    let name: String?
    let typ: String?
    let serie: String?
    let staffel: Int?
    let folge: Int?
    let dauer: Int64?
    let position: Int64?
    let gesehen: Bool?
    let bild: String?
    let quelle: Quelle?
}

extension WebTitel.Quelle {
    private var videoCodec: String { (video?.codec ?? "").lowercased() }
    /// 10-Bit-H.264 kann das iPhone nicht abspielen
    private var zehnBit: Bool { (video?.profil ?? "").contains("10") }

    private var tonPasst: Bool {
        guard let ton = audio?.first(where: { $0.index == standardAudio }) ?? audio?.first else { return true }
        return ["aac", "mp3", "ac3", "eac3", "alac", "flac"].contains((ton.codec ?? "").lowercased())
    }

    /// Die Originaldatei spielt das iPhone direkt ab
    var direkt: Bool {
        let behaelter = (container ?? "").lowercased().split(separator: ",").map(String.init)
        guard behaelter.contains(where: { ["mp4", "m4v", "mov"].contains($0) }) else { return false }
        let bildPasst = (videoCodec == "h264" && !zehnBit) || (videoCodec == "hevc" && (video?.tag ?? "").lowercased() == "hvc1")
        return bildPasst && tonPasst
    }

    /// H.264 in anderem Behälter (z. B. MKV): ohne Qualitätsverlust in MP4 umpacken
    var umpackbar: Bool { videoCodec == "h264" && !zehnBit }

    var hoehe: Int { video?.hoehe ?? 0 }
}

// MARK: Gespeicherte Downloads

enum DownloadQualitaet: String, Codable, CaseIterable {
    case original, hoch, mittel, klein

    var name: String {
        switch self {
        case .original: return Text.qOriginal
        case .hoch: return Text.qHoch
        case .mittel: return Text.qMittel
        case .klein: return Text.qKlein
        }
    }

    /// Umwandlung: Größe, Video- und Tonbitrate (wie Android)
    var stufe: (breite: Int, hoehe: Int, video: Int64, ton: Int64)? {
        switch self {
        case .original: return nil
        case .hoch: return (1920, 1080, 5_000_000, 192_000)
        case .mittel: return (1280, 720, 2_500_000, 160_000)
        case .klein: return (854, 480, 1_200_000, 128_000)
        }
    }

    /// Erwartete Größe in Bytes
    func groesse(_ t: WebTitel) -> Int64 {
        guard let stufe else { return t.quelle?.groesse ?? 0 }
        let sekunden = Double(t.dauer ?? 0) / 10_000_000
        return Int64(Double(stufe.video + stufe.ton) * sekunden / 8)
    }

    /// Stufen, die für diese Titel sinnvoll sind
    static func verfuegbar(_ titel: [WebTitel]) -> [DownloadQualitaet] {
        let quellen = titel.compactMap(\.quelle)
        guard !quellen.isEmpty else { return [] }
        var liste: [DownloadQualitaet] = []
        if quellen.allSatisfy({ $0.direkt || $0.umpackbar }) { liste.append(.original) }
        let hoehe = quellen.map(\.hoehe).max() ?? 0
        if hoehe == 0 || hoehe > 720 { liste.append(.hoch) }
        if hoehe == 0 || hoehe > 480 { liste.append(.mittel) }
        liste.append(.klein)
        return liste
    }
}

enum DownloadZustand: String, Codable {
    case wartet, laedt, fertig, fehler
}

struct OfflineTitel: Codable {
    var id: String
    var name: String
    var typ: String
    var serie: String?
    var staffel: Int?
    var folge: Int?
    var dauerTicks: Int64
    var qualitaet: DownloadQualitaet
    var pfad: String            // Server-Pfad ohne Anmeldung
    var fortsetzbar: Bool       // Originaldatei: nach Abbruch an derselben Stelle weiter
    var erwartet: Int64
    var geladen: Int64
    var zustand: DownloadZustand
    var fehler: String?
    var versuche: Int
    var positionTicks: Int64
    var gesehen: Bool
    var meldungOffen: Bool      // offline geschaut, Position noch nicht an Jellyfin gemeldet
    var zuletzt: Date?
    var hinzugefuegt: Date
    var bildPfad: String?

    var prozent: Int? {
        if zustand == .fertig { return 100 }
        guard erwartet > 0, geladen > 0 else { return zustand == .laedt ? 0 : nil }
        return min(99, Int(geladen * 100 / erwartet))
    }

    /// „Serie · S1 F2“ bzw. leer bei Filmen
    var folgenZeile: String {
        guard let serie else { return "" }
        let folge = Text.folge(staffel, self.folge)
        return folge.isEmpty ? serie : "\(serie) · \(folge)"
    }
}

extension OfflineTitel {
    // Nachsichtig lesen, damit spätere Versionen neue Felder ergänzen können, ohne Downloads zu verlieren
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        pfad = try c.decode(String.self, forKey: .pfad)
        qualitaet = try c.decodeIfPresent(DownloadQualitaet.self, forKey: .qualitaet) ?? .original
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        typ = try c.decodeIfPresent(String.self, forKey: .typ) ?? ""
        serie = try c.decodeIfPresent(String.self, forKey: .serie)
        staffel = try c.decodeIfPresent(Int.self, forKey: .staffel)
        folge = try c.decodeIfPresent(Int.self, forKey: .folge)
        dauerTicks = try c.decodeIfPresent(Int64.self, forKey: .dauerTicks) ?? 0
        fortsetzbar = try c.decodeIfPresent(Bool.self, forKey: .fortsetzbar) ?? false
        erwartet = try c.decodeIfPresent(Int64.self, forKey: .erwartet) ?? 0
        geladen = try c.decodeIfPresent(Int64.self, forKey: .geladen) ?? 0
        zustand = try c.decodeIfPresent(DownloadZustand.self, forKey: .zustand) ?? .wartet
        fehler = try c.decodeIfPresent(String.self, forKey: .fehler)
        versuche = try c.decodeIfPresent(Int.self, forKey: .versuche) ?? 0
        positionTicks = try c.decodeIfPresent(Int64.self, forKey: .positionTicks) ?? 0
        gesehen = try c.decodeIfPresent(Bool.self, forKey: .gesehen) ?? false
        meldungOffen = try c.decodeIfPresent(Bool.self, forKey: .meldungOffen) ?? false
        zuletzt = try c.decodeIfPresent(Date.self, forKey: .zuletzt)
        hinzugefuegt = try c.decodeIfPresent(Date.self, forKey: .hinzugefuegt) ?? Date()
        bildPfad = try c.decodeIfPresent(String.self, forKey: .bildPfad)
    }
}

// MARK: Anmeldung (aus der Weboberfläche, im Schlüsselbund)

struct Anmeldung: Codable, Equatable {
    var token: String
    var userId: String
    var deviceId: String

    /// Nur das Token: Jellyfin ordnet die Anfragen damit derselben Sitzung/demselben Gerät zu wie die Weboberfläche
    var kopf: String { "MediaBrowser Token=\"\(token)\"" }
}

enum Schluesselbund {
    private static let dienst = "de.kinolel.app.anmeldung"

    static func lesen() -> Anmeldung? {
        let anfrage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ergebnis: CFTypeRef?
        guard SecItemCopyMatching(anfrage as CFDictionary, &ergebnis) == errSecSuccess, let daten = ergebnis as? Data else { return nil }
        return try? JSONDecoder().decode(Anmeldung.self, from: daten)
    }

    static func schreiben(_ anmeldung: Anmeldung) {
        guard anmeldung != lesen(), let daten = try? JSONEncoder().encode(anmeldung) else { return }
        let basis: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: dienst]
        SecItemDelete(basis as CFDictionary)
        var neu = basis
        neu[kSecValueData as String] = daten
        neu[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(neu as CFDictionary, nil)
    }
}

// MARK: Verwaltung

final class Downloads: NSObject, URLSessionDownloadDelegate {
    static let shared = Downloads()
    static let geaendert = Notification.Name("KinoLelDownloadsGeaendert")
    private static let sitzungsKennung = "de.kinolel.app.downloads"

    private(set) var titel: [String: OfflineTitel] = [:]
    private var aufgaben: [String: URLSessionDownloadTask] = [:]
    private var abgebrochen = Set<String>()
    private var gestartet = false
    private var meldetGerade = false
    private var meldungGeplant = false
    private var letztesSpeichern = Date.distantPast
    /// Vom System übergeben, wenn Downloads im Hintergrund fertig wurden (AppDelegate)
    var hintergrundFertig: (() -> Void)?

    private let netz = NWPathMonitor()
    private(set) var online = true
    private(set) var wlan = true

    #if DEBUG
    /// Test im Simulator: so tun, als gäbe es kein Internet (Startargument -KinoLelTestOffline YES)
    static var testOffline: Bool { UserDefaults.standard.bool(forKey: "KinoLelTestOffline") }
    #endif

    private lazy var sitzung: URLSession = {
        let konfig = URLSessionConfiguration.background(withIdentifier: Downloads.sitzungsKennung)
        konfig.httpMaximumConnectionsPerHost = 1   // nacheinander – schont Server und NAS
        konfig.sessionSendsLaunchEvents = true
        konfig.isDiscretionary = false
        konfig.allowsCellularAccess = true          // je Anfrage eingeschränkt („Nur im WLAN“)
        konfig.timeoutIntervalForRequest = 180
        return URLSession(configuration: konfig, delegate: self, delegateQueue: .main)
    }()

    // MARK: Ablage

    static let ordner: URL = {
        var ordner = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        var werte = URLResourceValues()
        werte.isExcludedFromBackup = true
        try? ordner.setResourceValues(werte)
        return ordner
    }()
    private static var listenDatei: URL { ordner.appendingPathComponent("downloads.json") }
    static func titelOrdner(_ id: String) -> URL { ordner.appendingPathComponent(id, isDirectory: true) }
    static func videoDatei(_ id: String) -> URL { titelOrdner(id).appendingPathComponent("video.mp4") }
    static func bildDatei(_ id: String) -> URL { titelOrdner(id).appendingPathComponent("bild.jpg") }
    private static func fortsetzDatei(_ id: String) -> URL { titelOrdner(id).appendingPathComponent("fortsetzen.dat") }

    static func normId(_ id: String) -> String { id.replacingOccurrences(of: "-", with: "").lowercased() }

    static var frei: Int64 {
        let werte = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return werte?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    static func menge(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }

    var nurWlan: Bool {
        get { UserDefaults.standard.object(forKey: "kinolel.nurWlan") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "kinolel.nurWlan")
            // Noch wartende Downloads mit der neuen Einstellung neu anstoßen
            for (id, t) in titel where t.zustand == .wartet {
                guard let alt = aufgaben.removeValue(forKey: id) else { continue }
                abgebrochen.insert(id)
                alt.cancel()
                try? FileManager.default.removeItem(at: Self.fortsetzDatei(id))
                aufgabeStarten(id)
            }
            melden()
        }
    }

    // MARK: Start

    func starten() {
        guard !gestartet else { return }
        gestartet = true
        laden()
        netz.pathUpdateHandler = { [weak self] pfad in
            DispatchQueue.main.async { self?.netzGeaendert(pfad) }
        }
        netz.start(queue: DispatchQueue(label: "de.kinolel.netz"))
        sitzung.getAllTasks { [weak self] liste in
            DispatchQueue.main.async { self?.abgleichen(liste) }
        }
    }

    /// Nach einem Neustart der App: laufende Hintergrund-Downloads wieder zuordnen, verlorene neu starten
    private func abgleichen(_ liste: [URLSessionTask]) {
        for aufgabe in liste {
            guard let id = aufgabe.taskDescription, titel[id] != nil, let download = aufgabe as? URLSessionDownloadTask else {
                aufgabe.cancel()
                continue
            }
            aufgaben[id] = download
        }
        for (id, t) in titel where (t.zustand == .wartet || t.zustand == .laedt) && aufgaben[id] == nil {
            aufgabeStarten(id)
        }
        melden()
    }

    private func netzGeaendert(_ pfad: NWPath) {
        let warOnline = online
        online = pfad.status == .satisfied
        wlan = online && !pfad.isExpensive   // Mobilfunk und persönlicher Hotspot gelten als „teuer“
        #if DEBUG
        if Downloads.testOffline { online = false; wlan = false }
        #endif
        if online && !warOnline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.nachmelden() }
        }
        melden()
    }

    private func laden() {
        guard let daten = try? Data(contentsOf: Self.listenDatei),
              let liste = try? JSONDecoder().decode([OfflineTitel].self, from: daten) else { return }
        titel = Dictionary(liste.map { ($0.id, $0) }, uniquingKeysWith: { erster, _ in erster })
        for (id, t) in titel where t.zustand == .fertig && !FileManager.default.fileExists(atPath: Self.videoDatei(id).path) {
            titel[id] = nil
        }
    }

    private func speichern() {
        letztesSpeichern = Date()
        guard let daten = try? JSONEncoder().encode(Array(titel.values)) else { return }
        try? daten.write(to: Self.listenDatei, options: .atomic)
    }

    /// Oberflächen benachrichtigen (gebündelt, höchstens zweimal pro Sekunde)
    private func melden() {
        guard !meldungGeplant else { return }
        meldungGeplant = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.meldungGeplant = false
            NotificationCenter.default.post(name: Downloads.geaendert, object: nil)
        }
    }

    // MARK: Abfragen

    /// Alle Downloads – Folgen einer Serie zusammen und in Reihenfolge
    var liste: [OfflineTitel] {
        titel.values.sorted {
            let a = $0.serie ?? $0.name, b = $1.serie ?? $1.name
            if a != b { return a.localizedStandardCompare(b) == .orderedAscending }
            if ($0.staffel ?? 0) != ($1.staffel ?? 0) { return ($0.staffel ?? 0) < ($1.staffel ?? 0) }
            if ($0.folge ?? 0) != ($1.folge ?? 0) { return ($0.folge ?? 0) < ($1.folge ?? 0) }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    var anzahlFertig: Int { titel.values.filter { $0.zustand == .fertig }.count }

    var belegt: Int64 { titel.values.reduce(0) { $0 + $1.geladen } }

    func lokaleDatei(_ id: String) -> URL? {
        let id = Self.normId(id)
        guard titel[id]?.zustand == .fertig else { return nil }
        let datei = Self.videoDatei(id)
        return FileManager.default.fileExists(atPath: datei.path) ? datei : nil
    }

    /// Zustand für die Knöpfe in der Weboberfläche: { id: { s: wartet|laedt|fertig|fehler, p: Prozent oder -1 } }
    func status(_ ids: [String]) -> [String: [String: Any]] {
        var ergebnis: [String: [String: Any]] = [:]
        for roh in ids {
            let id = Self.normId(roh)
            guard let t = titel[id] else { continue }
            ergebnis[id] = ["s": t.zustand.rawValue, "p": t.prozent ?? -1]
        }
        return ergebnis
    }

    // MARK: Herunterladen

    /// Server-Pfad für einen Titel in der gewählten Stufe
    static func pfad(_ t: WebTitel, _ q: DownloadQualitaet, deviceId: String) -> (pfad: String, fortsetzbar: Bool)? {
        guard let quelle = t.quelle else { return nil }
        var teile = URLComponents()
        if q == .original && quelle.direkt {
            teile.path = "/Videos/\(t.id)/stream"
            teile.queryItems = [URLQueryItem(name: "static", value: "true"), URLQueryItem(name: "mediaSourceId", value: quelle.id)]
            guard let text = teile.string else { return nil }
            return (text, true)
        }
        var werte: [(String, String)] = [("static", "false"), ("container", "mp4"), ("mediaSourceId", quelle.id),
                                          ("deviceId", deviceId), ("videoCodec", "h264")]
        if let ton = quelle.standardAudio, ton >= 0 { werte.append(("audioStreamIndex", String(ton))) }
        if let stufe = q.stufe {
            werte += [("audioCodec", "aac"), ("maxWidth", String(stufe.breite)), ("maxHeight", String(stufe.hoehe)),
                      ("videoBitRate", String(stufe.video)), ("audioBitRate", String(stufe.ton)), ("maxAudioChannels", "2")]
        } else {
            // Original umpacken: Bild und (wenn möglich) Ton unverändert übernehmen
            werte += [("audioCodec", "aac,ac3,eac3,mp3"), ("allowVideoStreamCopy", "true"), ("allowAudioStreamCopy", "true"),
                      ("audioBitRate", "320000"), ("maxAudioChannels", "6")]
        }
        if let untertitel = untertitel(quelle) {
            werte += [("subtitleStreamIndex", String(untertitel)), ("subtitleMethod", "Embed"), ("subtitleCodec", "mov_text")]
        }
        teile.path = "/Videos/\(t.id)/stream.mp4"
        teile.queryItems = werte.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let text = teile.string else { return nil }
        return (text, false)
    }

    /// Eingebetteter Untertitel: Standard-Untertitel des Titels, sonst einer in der App-Sprache
    private static func untertitel(_ q: WebTitel.Quelle) -> Int? {
        let liste = q.untertitel ?? []
        if let standard = q.standardUntertitel, standard >= 0, liste.contains(where: { $0.index == standard }) { return standard }
        let kuerzel = Sprache.aktuell.jellyfinKuerzel
        return liste.first { kuerzel.contains(($0.sprache ?? "").lowercased()) }?.index
    }

    /// Titel vormerken; Ergebnis: Anzahl neuer Downloads
    func einreihen(_ liste: [WebTitel], qualitaet: DownloadQualitaet, anmeldung: Anmeldung) -> Int {
        var neu = 0
        for w in liste {
            let id = Self.normId(w.id)
            if let alt = titel[id], alt.zustand != .fehler { continue }   // schon da oder unterwegs
            guard let ziel = Self.pfad(w, qualitaet, deviceId: anmeldung.deviceId) else { continue }
            if let alt = aufgaben.removeValue(forKey: id) {
                abgebrochen.insert(id)
                alt.cancel()
            }
            try? FileManager.default.removeItem(at: Self.titelOrdner(id))
            try? FileManager.default.createDirectory(at: Self.titelOrdner(id), withIntermediateDirectories: true)
            titel[id] = OfflineTitel(
                id: id, name: w.name ?? "", typ: w.typ ?? "", serie: w.serie, staffel: w.staffel, folge: w.folge,
                dauerTicks: w.dauer ?? 0, qualitaet: qualitaet, pfad: ziel.pfad, fortsetzbar: ziel.fortsetzbar,
                erwartet: qualitaet.groesse(w), geladen: 0, zustand: .wartet, fehler: nil, versuche: 0,
                positionTicks: w.position ?? 0, gesehen: w.gesehen ?? false, meldungOffen: false, zuletzt: nil,
                hinzugefuegt: Date(), bildPfad: w.bild)
            aufgabeStarten(id)
            bildLaden(id)
            neu += 1
        }
        speichern()
        melden()
        return neu
    }

    private func aufgabeStarten(_ id: String) {
        guard var t = titel[id] else { return }
        guard let anmeldung = Schluesselbund.lesen() else {
            t.zustand = .fehler
            t.fehler = "Nicht angemeldet"
            titel[id] = t
            return
        }
        let aufgabe: URLSessionDownloadTask
        if t.fortsetzbar, let daten = try? Data(contentsOf: Self.fortsetzDatei(id)) {
            try? FileManager.default.removeItem(at: Self.fortsetzDatei(id))
            aufgabe = sitzung.downloadTask(withResumeData: daten)
        } else {
            var text = t.pfad
            if !t.fortsetzbar { text += "&playSessionId=" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() }
            guard let url = URL(string: text, relativeTo: Marke.serverURL)?.absoluteURL else { return }
            var anfrage = URLRequest(url: url)
            anfrage.setValue(anmeldung.kopf, forHTTPHeaderField: "Authorization")
            anfrage.allowsCellularAccess = !nurWlan
            aufgabe = sitzung.downloadTask(with: anfrage)
            t.geladen = 0
        }
        aufgabe.taskDescription = id
        aufgaben[id] = aufgabe
        t.zustand = .wartet
        t.fehler = nil
        titel[id] = t
        aufgabe.resume()
    }

    /// Fehlgeschlagenen Download erneut versuchen
    func erneut(_ id: String) {
        guard var t = titel[id], t.zustand == .fehler else { return }
        t.versuche = 0
        titel[id] = t
        aufgabeStarten(id)
        speichern()
        melden()
    }

    func loeschen(_ id: String) {
        if let aufgabe = aufgaben.removeValue(forKey: id) {
            abgebrochen.insert(id)
            aufgabe.cancel()
        }
        titel[id] = nil
        try? FileManager.default.removeItem(at: Self.titelOrdner(id))
        NSLog("KinoLel-Downloads: %@ gelöscht", id)
        speichern()
        melden()
    }

    private func bildLaden(_ id: String) {
        guard let pfad = titel[id]?.bildPfad, let url = URL(string: pfad, relativeTo: Marke.serverURL)?.absoluteURL else { return }
        var anfrage = URLRequest(url: url)
        if let anmeldung = Schluesselbund.lesen() { anfrage.setValue(anmeldung.kopf, forHTTPHeaderField: "Authorization") }
        URLSession.shared.dataTask(with: anfrage) { [weak self] daten, antwort, _ in
            guard let daten, (antwort as? HTTPURLResponse)?.statusCode == 200 else { return }
            DispatchQueue.main.async {
                guard let self, self.titel[id] != nil else { return }
                try? daten.write(to: Self.bildDatei(id), options: .atomic)
                self.melden()
            }
        }.resume()
    }

    // MARK: URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription, var t = titel[id] else { return }
        t.zustand = .laedt
        t.geladen = totalBytesWritten
        if totalBytesExpectedToWrite > 0 {
            t.erwartet = totalBytesExpectedToWrite
        } else if t.geladen > t.erwartet {
            t.erwartet = t.geladen + t.geladen / 10   // Schätzung war zu klein
        }
        titel[id] = t
        if Date().timeIntervalSince(letztesSpeichern) > 10 { speichern() }
        melden()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription, var t = titel[id] else { return }
        let code = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        if !(200..<300).contains(code) {
            NSLog("KinoLel-Downloads: %@ Serverfehler %ld", id, code)
            t.zustand = .fehler
            t.fehler = "HTTP \(code)"
        } else {
            let ziel = Self.videoDatei(id)
            do {
                try FileManager.default.createDirectory(at: Self.titelOrdner(id), withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: ziel)
                try FileManager.default.moveItem(at: location, to: ziel)
                let attribute = try? FileManager.default.attributesOfItem(atPath: ziel.path)
                let groesse = (attribute?[.size] as? NSNumber)?.int64Value ?? t.geladen
                t.geladen = groesse
                t.erwartet = groesse
                t.zustand = .fertig
                t.fehler = nil
                NSLog("KinoLel-Downloads: %@ fertig (%lld Bytes, %@)", id, groesse, t.qualitaet.rawValue)
            } catch {
                t.zustand = .fehler
                t.fehler = error.localizedDescription
            }
        }
        titel[id] = t
        speichern()
        melden()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription else { return }
        if aufgaben[id] === task { aufgaben[id] = nil }
        if abgebrochen.remove(id) != nil { return }   // gelöscht oder neu angestoßen
        guard var t = titel[id], let error else { return }
        let ns = error as NSError
        NSLog("KinoLel-Downloads: %@ unterbrochen: %@", id, error.localizedDescription)
        if t.fortsetzbar, let daten = ns.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            try? daten.write(to: Self.fortsetzDatei(id))
        }
        t.versuche += 1
        if t.versuche <= 3 {
            t.zustand = .wartet
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                guard let self, self.titel[id]?.zustand == .wartet, self.aufgaben[id] == nil else { return }
                self.aufgabeStarten(id)
            }
        } else {
            t.zustand = .fehler
            t.fehler = error.localizedDescription
        }
        titel[id] = t
        speichern()
        melden()
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.hintergrundFertig?()
            self.hintergrundFertig = nil
        }
    }

    // MARK: Wiedergabe-Position

    /// Position merken (alle 10 s und beim Beenden). offline = ohne Weboberfläche geschaut → später an Jellyfin melden.
    func positionMerken(_ id: String, sekunden: Double, offline: Bool) {
        guard var t = titel[id], sekunden.isFinite, sekunden >= 0 else { return }
        let ticks = Int64(sekunden * 10_000_000)
        if t.dauerTicks > 0 && ticks >= t.dauerTicks * 9 / 10 {
            t.gesehen = true
            t.positionTicks = 0
        } else {
            t.gesehen = false
            t.positionTicks = ticks
        }
        t.zuletzt = Date()
        if offline { t.meldungOffen = true }
        titel[id] = t
        speichern()
        melden()
    }

    /// Offline geschaute Positionen an Jellyfin melden, sobald wieder Verbindung besteht
    func nachmelden() {
        guard !meldetGerade, online, let anmeldung = Schluesselbund.lesen() else { return }
        let offen = titel.values.filter { $0.meldungOffen }
        guard !offen.isEmpty else { return }
        meldetGerade = true
        Task { @MainActor in
            defer { self.meldetGerade = false }
            for t in offen {
                guard await self.melde(t, anmeldung) else {
                    NSLog("KinoLel-Offline: Melden später")
                    return
                }
                // Nur zurücksetzen, wenn inzwischen nicht weitergeschaut wurde
                if var aktuell = self.titel[t.id], aktuell.zuletzt == t.zuletzt {
                    aktuell.meldungOffen = false
                    self.titel[t.id] = aktuell
                }
                NSLog("KinoLel-Offline: Position von %@ gemeldet", t.id)
            }
            self.speichern()
        }
    }

    private func melde(_ t: OfflineTitel, _ anmeldung: Anmeldung) async -> Bool {
        guard let url = URL(string: "/UserItems/\(t.id)/UserData?userId=\(anmeldung.userId)", relativeTo: Marke.serverURL)?.absoluteURL
        else { return false }
        var anfrage = URLRequest(url: url)
        anfrage.httpMethod = "POST"
        anfrage.setValue(anmeldung.kopf, forHTTPHeaderField: "Authorization")
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var daten: [String: Any] = ["PlaybackPositionTicks": t.positionTicks, "Played": t.gesehen]
        if let zuletzt = t.zuletzt { daten["LastPlayedDate"] = ISO8601DateFormatter().string(from: zuletzt) }
        anfrage.httpBody = try? JSONSerialization.data(withJSONObject: daten)
        do {
            let (_, antwort) = try await URLSession.shared.data(for: anfrage)
            return (200..<300).contains((antwort as? HTTPURLResponse)?.statusCode ?? 0)
        } catch {
            return false
        }
    }
}
