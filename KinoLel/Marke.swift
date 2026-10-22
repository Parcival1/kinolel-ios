// KinoLel-App (iOS) – Werte aus project.yml (über Info.plist). Name endgültig „KinoLel“.
import UIKit

enum Marke {
    static let appName = Bundle.main.object(forInfoDictionaryKey: "KinoLelAppName") as? String ?? "KinoLel"
    static let serverURL: URL = {
        let text = Bundle.main.object(forInfoDictionaryKey: "KinoLelServerURL") as? String ?? "https://kinolel.de"
        return URL(string: text) ?? URL(string: "https://kinolel.de")!
    }()
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    static let lavendel = UIColor(red: 0x9A / 255.0, green: 0xA4 / 255.0, blue: 0xFF / 255.0, alpha: 1)
    static let grund = UIColor(red: 0x0B / 255.0, green: 0x0F / 255.0, blue: 0x18 / 255.0, alpha: 1)
    static let text = UIColor(white: 1, alpha: 0.75)
    // App-Sprache (de/hu/en): Texte.swift
}
