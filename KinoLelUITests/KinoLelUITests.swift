// KinoLel-App (iOS): Oberflächentests im Simulator (XCUITest, nutzt die Test-Hilfen des Debug-Builds).
//  1. „Was ist neu“ erscheint nach einem Update genau einmal – auf Deutsch, Englisch und Ungarisch
//  2. Start ohne Internet: Hinweis auf dem Startbild, Download-Liste (leer, „Nur im WLAN“)
//  3. Nur mit KINOLEL_TEST_PW (GitHub-Secret): anmelden, Folge „Klein“ herunterladen, ohne Internet aus der Liste
//     abspielen, wieder online → Position wird nachgemeldet, Download löschen, abmelden.
//     Die Prüfung der App-Meldungen („KinoLel-Test: …“, Nachmelden) macht .github/scripts/oberflaechentest.sh.
import XCTest

final class KinoLelUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func app(_ argumente: [String] = [], sprache: String = "de", umgebung: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(sprache))", "-AppleLocale", sprache == "de" ? "de_DE" : sprache == "hu" ? "hu_HU" : "en_US"]
            + argumente
        app.launchEnvironment = umgebung
        return app
    }

    private func bild(_ name: String) {
        let anhang = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        anhang.name = name
        anhang.lifetime = .keepAlways
        add(anhang)
    }

    private func beginntMit(_ text: String) -> NSPredicate { NSPredicate(format: "label BEGINSWITH %@", text) }

    // MARK: 1. Was ist neu

    func test1Neuigkeiten() {
        for (sprache, titel) in [("de", "Neu in KinoLel 0.1.3"), ("en", "New in KinoLel 0.1.3"), ("hu", "Újdonságok – KinoLel 0.1.3")] {
            let a = app(["-KinoLelTestNeuigkeitenSeit", "0.1.2"], sprache: sprache)
            a.launch()
            let ueberschrift = a.staticTexts["kinolel.neuigkeiten.titel"]
            XCTAssertTrue(ueberschrift.waitForExistence(timeout: 60), "Meldung „Was ist neu“ fehlt (\(sprache))")
            XCTAssertEqual(ueberschrift.label, titel)
            bild("neuigkeiten-\(sprache)")
            a.buttons["kinolel.neuigkeiten.ok"].tap()
            XCTAssertTrue(ueberschrift.waitForNonExistence(timeout: 10), "Meldung lässt sich nicht schließen")
            a.terminate()
        }

        // Ohne „Update“ (Version schon gesehen): keine Meldung
        let b = app()
        b.launch()
        sleep(20)
        XCTAssertFalse(b.staticTexts["kinolel.neuigkeiten.titel"].exists, "Meldung darf nur einmal erscheinen")
        bild("zweiter-start")
        b.terminate()
    }

    // MARK: 2. Ohne Internet

    func test2OhneInternet() {
        let a = app(["-KinoLelTestOffline", "YES", "-KinoLelTestDownloads", "YES"])
        a.launch()
        XCTAssertTrue(a.tables["kinolel.downloads"].waitForExistence(timeout: 30), "Download-Liste öffnet sich nicht")
        XCTAssertTrue(a.switches["kinolel.downloads.nurwlan"].exists, "Schalter „Nur im WLAN“ fehlt")
        bild("downloads-liste")
        a.buttons["kinolel.downloads.fertig"].tap()
        let hinweis = a.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "nicht erreichbar")).firstMatch
        XCTAssertTrue(hinweis.waitForExistence(timeout: 40), "Hinweis „nicht erreichbar“ fehlt")
        bild("ohne-internet")
        a.terminate()
    }

    // MARK: 3. Herunterladen und offline ansehen

    func test3DownloadOffline() throws {
        let umgebung = ProcessInfo.processInfo.environment
        guard let kennwort = umgebung["KINOLEL_TEST_PW"], !kennwort.isEmpty,
              let id = umgebung["KINOLEL_TEST_ID"], !id.isEmpty else {
            throw XCTSkip("KINOLEL_TEST_PW/KINOLEL_TEST_ID fehlen – Download-Test übersprungen")
        }

        // Anmelden (Test-Hilfe der App), zur Folge springen, „Herunterladen“ → „Klein“
        let a = app(["-KinoLelTestZiel", "#/details?id=\(id)"], umgebung: ["KINOLEL_TEST_PW": kennwort])
        a.launch()
        let knopf = a.webViews.buttons["Herunterladen"]
        XCTAssertTrue(knopf.waitForExistence(timeout: 150), "Knopf „Herunterladen“ fehlt")
        bild("3a-detail")
        knopf.tap()
        let klein = a.buttons.matching(beginntMit("Klein (480p)")).firstMatch
        XCTAssertTrue(klein.waitForExistence(timeout: 30), "Qualitätswahl fehlt")
        bild("3b-qualitaet")
        klein.tap()
        bild("3c-gestartet")

        // Fertig, wenn der Knopf „Heruntergeladen …“ zeigt (höchstens 15 min)
        let fertig = a.webViews.buttons.matching(beginntMit("Heruntergeladen")).firstMatch
        XCTAssertTrue(fertig.waitForExistence(timeout: 900), "Download nicht fertig geworden")
        fertig.tap()
        let zeile = a.cells["kinolel.download.\(id)"]
        XCTAssertTrue(zeile.waitForExistence(timeout: 20), "Download fehlt in der Liste")
        XCTAssertEqual(zeile.value as? String, "fertig")
        bild("3d-liste")
        a.terminate()

        // Ohne Internet: Liste öffnet sich von selbst, Folge abspielen (Position wird alle 10 s gemerkt)
        let b = app(["-KinoLelTestOffline", "YES"])
        b.launch()
        let zeileOffline = b.cells["kinolel.download.\(id)"]
        XCTAssertTrue(zeileOffline.waitForExistence(timeout: 60), "Downloads öffnen sich ohne Internet nicht von selbst")
        bild("3e-offline-liste")
        zeileOffline.tap()
        sleep(25)
        bild("3f-offline-wiedergabe")
        b.terminate()

        // Wieder online: App meldet die Position nach; Download löschen; Test-Hilfe prüft Serverstand und meldet ab
        let c = app(["-KinoLelTestDownloads", "YES", "-KinoLelTestAbmelden", "YES", "-KinoLelTestZuruecksetzen", id])
        c.launch()
        let zeileOnline = c.cells["kinolel.download.\(id)"]
        XCTAssertTrue(zeileOnline.waitForExistence(timeout: 60), "Download-Liste online")
        bild("3g-online-liste")
        sleep(8)
        zeileOnline.buttons["kinolel.download.\(id).loeschen"].tap()
        let loeschen = c.buttons["kinolel.dialog.loeschen"]
        XCTAssertTrue(loeschen.waitForExistence(timeout: 10), "Rückfrage „Löschen“ fehlt")
        loeschen.tap()
        XCTAssertTrue(zeileOnline.waitForNonExistence(timeout: 10), "Download nicht gelöscht")
        bild("3h-geloescht")
        sleep(30)   // Nachmelden, Serverstand zurücksetzen, abmelden (Test-Hilfe der App)
        c.terminate()
    }
}
