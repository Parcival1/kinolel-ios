// KinoLel-App (iOS): eigene Texte der App auf Deutsch, Ungarisch und Englisch (dieselben Texte wie in der Android-App).
import Foundation

enum Sprache: String {
    case de, hu, en

    /// Erste passende Gerätesprache – sonst Deutsch (wie die Android-App)
    static var aktuell: Sprache {
        for kennung in Locale.preferredLanguages {
            if let sprache = Sprache(rawValue: String(kennung.prefix(2)).lowercased()) { return sprache }
        }
        return .de
    }

    /// Sprachkürzel, mit denen Jellyfin Untertitel kennzeichnet (ISO 639-2)
    var jellyfinKuerzel: [String] {
        switch self {
        case .de: return ["ger", "deu", "de"]
        case .hu: return ["hun", "hu"]
        case .en: return ["eng", "en"]
        }
    }
}

/// Text in der aktuellen Sprache
func T(_ de: String, _ hu: String, _ en: String) -> String {
    switch Sprache.aktuell {
    case .de: return de
    case .hu: return hu
    case .en: return en
    }
}

enum Text {
    static var app: String { Marke.appName }

    // Startbild
    static var verbinde: String { T("Verbindung zu \(app) wird hergestellt …", "\(app) – kapcsolódás …", "Connecting to \(app) …") }
    static var nichtErreichbar: String {
        T("\(app) ist gerade nicht erreichbar.\nBitte Internetverbindung prüfen – es wird weiter versucht.",
          "\(app) most nem érhető el.\nKérjük, ellenőrizd az internetkapcsolatot – tovább próbálkozunk.",
          "\(app) cannot be reached right now.\nPlease check your internet connection – retrying automatically.")
    }
    static var nochmal: String { T("Erneut versuchen", "Újra", "Try again") }
    static var offlineHinweis: String {
        T("Ohne Internet kannst du deine Downloads ansehen.", "Internet nélkül is megnézheted a letöltéseidet.",
          "Without internet you can watch your downloads.")
    }
    static func offlineDownloads(_ anzahl: Int) -> String {
        T("Meine Downloads (\(anzahl))", "Letöltéseim (\(anzahl))", "My downloads (\(anzahl))")
    }

    // Downloads: Auswahl
    static func dlUeberschrift(_ name: String) -> String { T("Herunterladen: \(name)", "Letöltés: \(name)", "Download: \(name)") }
    static func dlFolgen(_ anzahl: Int) -> String { T("\(anzahl) Folgen", "\(anzahl) epizód", "\(anzahl) episodes") }
    static func dlTitel(_ anzahl: Int) -> String { T("\(anzahl) Titel", "\(anzahl) cím", "\(anzahl) titles") }
    static var qOriginal: String { T("Original (beste Qualität)", "Eredeti (legjobb minőség)", "Original (best quality)") }
    static var qHoch: String { T("Hoch (1080p)", "Magas (1080p)", "High (1080p)") }
    static var qMittel: String { T("Mittel (720p)", "Közepes (720p)", "Medium (720p)") }
    static var qKlein: String { T("Klein (480p)", "Kicsi (480p)", "Small (480p)") }
    static var zuGross: String { T("zu wenig Speicher", "nincs elég hely", "not enough space") }
    static func frei(_ menge: String) -> String {
        T("Frei auf dem Gerät: \(menge)", "Szabad hely az eszközön: \(menge)", "Free on this device: \(menge)")
    }
    static var hinweisKlein: String {
        T("Kleinere Stufen wandelt der Server beim Herunterladen um – das dauert etwas länger.",
          "A kisebb minőséget a szerver letöltés közben alakítja át – ez kicsit tovább tart.",
          "Smaller qualities are converted by the server while downloading – this takes a bit longer.")
    }
    static var nurWlanHinweis: String {
        T("Es wird nur im WLAN heruntergeladen (änderbar unter „Downloads“).",
          "Letöltés csak Wi-Fi-n (módosítható a „Letöltések” alatt).",
          "Downloads only on Wi-Fi (change in “Downloads”).")
    }
    static func gestartet(_ anzahl: Int) -> String {
        T("Download gestartet (\(anzahl)) – zu sehen unter „Downloads“.",
          "Letöltés elindult (\(anzahl)) – a „Letöltések” között látható.",
          "Download started (\(anzahl)) – see “Downloads”.")
    }
    static func wartetWlan(_ anzahl: Int) -> String {
        T("Download vorgemerkt (\(anzahl)) – startet, sobald WLAN da ist.",
          "Letöltés előjegyezve (\(anzahl)) – Wi-Fi esetén indul.",
          "Download queued (\(anzahl)) – starts as soon as Wi-Fi is available.")
    }
    static var keineVerbindung: String {
        T("Herunterladen gerade nicht möglich – keine Verbindung zu \(app).",
          "A letöltés most nem lehetséges – nincs kapcsolat a \(app)lel.",
          "Downloading is not possible right now – no connection to \(app).")
    }
    static var nichts: String { T("Hier gibt es nichts zum Herunterladen.", "Itt nincs mit letölteni.", "There is nothing to download here.") }
    static var abbrechen: String { T("Abbrechen", "Mégse", "Cancel") }

    // Downloads: Liste
    static var downloads: String { T("Downloads", "Letöltések", "Downloads") }
    static var fertig: String { T("Fertig", "Kész", "Done") }
    static var nurWlan: String { T("Nur im WLAN herunterladen", "Letöltés csak Wi-Fi-n", "Download on Wi-Fi only") }
    static var leer: String {
        T("Noch keine Downloads.\nTippe bei einem Film oder einer Folge auf „Herunterladen“.",
          "Még nincs letöltés.\nEgy filmnél vagy epizódnál koppints a „Letöltés” gombra.",
          "No downloads yet.\nTap “Download” on a movie or episode.")
    }
    static func laedt(_ prozent: Int?) -> String {
        let p = prozent.map { " – \($0) %" } ?? ""
        return T("Wird heruntergeladen\(p)", "Letöltés folyamatban\(p)", "Downloading\(p)")
    }
    static var wartetWlanKurz: String { T("Wartet … (WLAN?)", "Várakozik … (Wi-Fi?)", "Waiting … (Wi-Fi?)") }
    static var wartet: String { T("Wartet …", "Várakozik …", "Waiting …") }
    static var fehler: String { T("Fehlgeschlagen – tippen zum Wiederholen", "Sikertelen – koppints az újrapróbáláshoz", "Failed – tap to retry") }
    static var loeschen: String { T("Download löschen", "Letöltés törlése", "Delete download") }
    static var loeschenKnopf: String { T("Löschen", "Törlés", "Delete") }
    static func speicher(_ belegt: String, _ frei: String) -> String {
        T("Downloads: \(belegt) · frei: \(frei)", "Letöltések: \(belegt) · szabad: \(frei)", "Downloads: \(belegt) · free: \(frei)")
    }
    static var speicherort: String {
        T("Im geschützten App-Speicher (nicht in Fotos oder Dateien, wird beim Löschen der App entfernt)",
          "Védett alkalmazás-tárhelyen (nem jelenik meg a Fotókban vagy a Fájlokban, az alkalmazás törlésekor törlődik)",
          "In protected app storage (not in Photos or Files, removed when deleting the app)")
    }
    static func folge(_ staffel: Int?, _ folge: Int?) -> String {
        guard let staffel, let folge else { return "" }
        return T("S\(staffel) F\(folge)", "\(staffel). évad \(folge). rész", "S\(staffel) E\(folge)")
    }
    static func restZeit(_ minuten: Int) -> String { T("noch \(minuten) Min.", "még \(minuten) perc", "\(minuten) min left") }
    static var gesehen: String { T("gesehen", "megnézve", "watched") }

    // Was ist neu
    static func neuTitel(_ version: String) -> String {
        T("Neu in \(app) \(version)", "Újdonságok – \(app) \(version)", "New in \(app) \(version)")
    }
    static func neuVersion(_ version: String) -> String { T("Version \(version)", "\(version). verzió", "Version \(version)") }
    static var neuOk: String { T("Alles klar", "Rendben", "Got it") }

    // Update
    static var updateTitel: String { T("Update verfügbar", "Frissítés elérhető", "Update available") }
    static func updateText(_ version: String) -> String {
        T("\(app) \(version) ist verfügbar.\n„Aktualisieren“ öffnet SideStore: dort unter „My Apps“ bei \(app) auf „Update“ tippen.",
          "Elérhető a(z) \(app) \(version).\nA „Frissítés” megnyitja a SideStore-t: ott a „My Apps” alatt koppints a(z) \(app) melletti „Update” gombra.",
          "\(app) \(version) is available.\n“Update” opens SideStore: tap “Update” next to \(app) under “My Apps”.")
    }
    static var updateJetzt: String { T("Aktualisieren", "Frissítés", "Update") }
    static var updateSpaeter: String { T("Später", "Később", "Later") }
}
