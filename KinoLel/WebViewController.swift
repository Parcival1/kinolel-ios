// KinoLel-App (iOS): Weboberfläche von kinolel.de im WKWebView (fester Server, keine Serverauswahl).
// Die Anmeldeseite inkl. Sprachwahl Deutsch/Magyar kommt von kinolel.de (kinolel.js, localStorage "kl-sprache").
import UIKit
import WebKit

final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler,
    WKScriptMessageHandlerWithReply {
    private var webView: WKWebView!
    private let startbild = StartbildView()
    private let player = PlayerController()
    private var geladen = false
    private var hinweisTimer: Timer?
    private var neuTimer: Timer?
    private var startFertig = false        // erste Seite geladen oder ausgefallen → „Was ist neu“, Update-Hinweis
    private var offlineGeoeffnet = false   // Downloads ohne Internet schon einmal von selbst geöffnet
    #if DEBUG
    private var testGestartet = false
    private var testListeGezeigt = false
    #endif

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Marke.grund

        let inhalt = WKUserContentController()
        inhalt.add(SchwacherHandler(self), name: "kinolel")
        inhalt.addScriptMessageHandler(SchwacherAntwortHandler(self), contentWorld: .page, name: "kinolelFrage")
        for quelle in [Skripte.appInfo(), Skripte.lade("nativeshell"), Skripte.lade("videoplayer"), Skripte.lade("kinolelDownloads")] {
            inhalt.addUserScript(WKUserScript(source: quelle, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }

        let konfig = WKWebViewConfiguration()
        konfig.userContentController = inhalt
        konfig.allowsInlineMediaPlayback = true
        konfig.allowsPictureInPictureMediaPlayback = true
        konfig.mediaTypesRequiringUserActionForPlayback = []
        konfig.websiteDataStore = .default()
        // Wie Safari erkannt werden (Jellyfin-Web wählt danach das Abspielprofil), plus eigene Kennung
        let ios = UIDevice.current.systemVersion.split(separator: ".").first ?? "17"
        konfig.applicationNameForUserAgent = "Version/\(ios).0 Mobile/15E148 Safari/604.1 KinoLel/\(Marke.version)"

        webView = WKWebView(frame: .zero, configuration: konfig)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = Marke.grund
        webView.scrollView.backgroundColor = Marke.grund
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        startbild.translatesAutoresizingMaskIntoConstraints = false
        startbild.knopf.addTarget(self, action: #selector(nochmal), for: .touchUpInside)
        startbild.downloadsKnopf.addTarget(self, action: #selector(downloadsZeigen), for: .touchUpInside)
        view.addSubview(startbild)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            startbild.topAnchor.constraint(equalTo: view.topAnchor),
            startbild.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            startbild.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            startbild.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        player.webView = webView
        player.gastgeber = self
        // Lel 22.10.2026: bei jedem Zurückkehren in die App nach Updates suchen (beim Start nach „Was ist neu“)
        NotificationCenter.default.addObserver(self, selector: #selector(imVordergrund), name: UIScene.willEnterForegroundNotification,
                                               object: nil)
        laden()
    }

    @objc private func imVordergrund() {
        guard startFertig else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            Aktualisierung.pruefen(auf: self)
        }
    }

    #if DEBUG
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Test: Download-Liste gleich öffnen (-KinoLelTestDownloads YES), auch ohne Internet
        if !testListeGezeigt && UserDefaults.standard.bool(forKey: "KinoLelTestDownloads") {
            testListeGezeigt = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.downloadsZeigen() }
        }
    }
    #endif

    // MARK: Laden / Ausfall

    private func laden() {
        neuTimer?.invalidate()
        hinweisTimer?.invalidate()
        startbild.zuruecksetzen()
        hinweisTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            guard let self, !self.geladen else { return }
            self.startbild.zeigeVerbinde()
        }
        var ziel = Marke.serverURL.appendingPathComponent("web/")
        #if DEBUG
        if Downloads.testOffline, let ohneNetz = URL(string: "https://offline.invalid/web/") { ziel = ohneNetz }
        #endif
        webView.load(URLRequest(url: ziel, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20))
    }

    @objc private func nochmal() { laden() }

    private func ausfall(_ fehler: Error) {
        let ns = fehler as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
        NSLog("KinoLel: Laden fehlgeschlagen: %@", fehler.localizedDescription)
        geladen = false
        hinweisTimer?.invalidate()
        view.bringSubviewToFront(startbild)
        startbild.isHidden = false
        startbild.alpha = 1
        let fertige = Downloads.shared.anzahlFertig
        startbild.zeigeFehler(downloads: fertige)
        neuTimer?.invalidate()
        neuTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in self?.laden() }

        // Ohne Internet die Downloads von selbst öffnen (einmal je Start, wie die Android-App)
        var ohneNetz = !Downloads.shared.online || (ns.domain == NSURLErrorDomain && ns.code == NSURLErrorNotConnectedToInternet)
        #if DEBUG
        if Downloads.testOffline { ohneNetz = true }
        #endif
        if ohneNetz && fertige > 0 && !offlineGeoeffnet && presentedViewController == nil {
            offlineGeoeffnet = true
            downloadsZeigen()
        }
        startAbgeschlossen()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !geladen else { return }
        geladen = true
        hinweisTimer?.invalidate()
        // Die Seite zeigt selbst das gleiche Lade-Overlay -> nahtlos überblenden
        UIView.animate(withDuration: 0.35, delay: 0.3, options: []) {
            self.startbild.alpha = 0
        } completion: { _ in
            self.startbild.isHidden = true
        }
        // Offline geschaute Downloads: Position an Jellyfin melden (Anmeldung kommt aus der Seite)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { Downloads.shared.nachmelden() }
        startAbgeschlossen()
        #if DEBUG
        testHilfen()
        #endif
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { ausfall(error) }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        ausfall(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        geladen = false
        webView.reload()
    }

    // MARK: Nach dem Start: „Was ist neu“, dann Update-Hinweis

    private func startAbgeschlossen() {
        guard !startFertig else { return }
        startFertig = true
        meldungenZeigen()
    }

    /// Nicht über den Player, die Download-Liste oder eine andere Meldung legen – dann später erneut versuchen
    private func meldungenZeigen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self else { return }
            guard self.presentedViewController == nil else { return self.meldungenZeigen() }
            Neuigkeiten.zeigen(auf: self) { [weak self] in
                guard let self else { return }
                Aktualisierung.pruefen(auf: self)
            }
        }
    }

    // MARK: Links

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
        let eigen = url.host == Marke.serverURL.host || url.scheme == "about" || url.scheme == "blob" || url.scheme == "data"
        if !eigen && navigationAction.navigationType == .linkActivated {
            oeffneExtern(url)
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }

    // target=_blank / window.open (z. B. KinoLel Wünsche) -> App „KinoLel Wünsche“ bzw. Safari
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { oeffneExtern(url) }
        return nil
    }

    /// Links auf KinoLel Wünsche direkt in der App „KinoLel Wünsche“ öffnen (kinolelwuensche://), alles andere in Safari
    /// (wie die Android-App ab 0.1.2)
    private func oeffneExtern(_ url: URL) {
        let wuensche = ["wuensche.kinolel.de", "kivansagok.kinolel.de"]
        if let host = url.host?.lowercased(), wuensche.contains(host),
           var teile = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            teile.scheme = "kinolelwuensche"
            if let app = teile.url {
                UIApplication.shared.open(app) { geoeffnet in
                    if !geoeffnet { UIApplication.shared.open(url) }
                }
                return
            }
        }
        UIApplication.shared.open(url)
    }

    // MARK: Nachrichten aus der Weboberfläche (nativeshell.js / videoplayer.js)

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let nachricht = message.body as? [String: Any], let ereignis = nachricht["event"] as? String else { return }
        let daten = nachricht["data"]
        switch ereignis {
        case "video.play":
            NSLog("KinoLel: Befehl video.play")
            if let d = daten as? [String: Any] { player.abspielen(d) }
        case "video.playPause", "video.pause", "video.unpause", "video.stop", "video.seek":
            // Auch Befehle vom Server (Pause/Weiter/Stopp/Spulen) kommen über den playbackManager hier an
            NSLog("KinoLel: Befehl %@", ereignis)
            switch ereignis {
            case "video.playPause": player.playPause()
            case "video.pause": player.pause()
            case "video.unpause": player.weiter()
            case "video.stop": player.stoppen(manuell: false)
            default: if let ms = daten as? Double { player.springe(ms: ms) }
            }
        case "nachricht":
            // Nachricht vom Server (Dashboard „Nachricht senden“, KinoLel-Streams-Grenze): über dem nativen Player zeigen.
            // Ohne laufenden Player zeigt sie die Weboberfläche selbst.
            guard player.laeuft, let d = daten as? [String: Any] else { break }
            let dauer = ((d["dauer"] as? Double) ?? 0) / 1000
            NSLog("KinoLel: Nachricht vom Server über dem Player")
            Hinweis.zeigen(d["text"] as? String ?? "", kopf: d["kopf"] as? String, sekunden: dauer > 0 ? dauer : 10, in: view.window)
        case "downloads.oeffnen":
            downloadsZeigen()
        case "openUrl":
            if let text = (daten as? [String: Any])?["url"] as? String, let url = URL(string: text, relativeTo: Marke.serverURL) {
                oeffneExtern(url.absoluteURL)
            }
        case "console.error", "console.warn":
            NSLog("KinoLel Web %@: %@", ereignis, String(describing: daten ?? ""))
        default:
            break
        }
    }

    /// Anfragen mit Antwort (window.KinoLelNative.frage → Promise)
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) {
        guard let nachricht = message.body as? [String: Any], let ereignis = nachricht["event"] as? String else {
            return replyHandler(nil, "ungültige Anfrage")
        }
        let daten = nachricht["data"]
        switch ereignis {
        case "anmeldung":
            if let d = daten as? [String: Any] { anmeldungMerken(d) }
            replyHandler(true, nil)
        case "dl.status":
            replyHandler(Downloads.shared.status(daten as? [String] ?? []), nil)
        case "dl.anfragen":
            downloadAnfragen(daten as? [String: Any] ?? [:])
            replyHandler(true, nil)
        default:
            replyHandler(nil, "unbekannt: \(ereignis)")
        }
    }

    // MARK: Downloads

    private func anmeldungMerken(_ d: [String: Any]) {
        guard let token = d["token"] as? String, !token.isEmpty, let userId = d["userId"] as? String,
              let deviceId = d["deviceId"] as? String else { return }
        Schluesselbund.schreiben(Anmeldung(token: token, userId: userId, deviceId: deviceId))
    }

    /// Knopf „Herunterladen“ bzw. „…“-Menü → Qualität wählen → Downloads starten
    private func downloadAnfragen(_ d: [String: Any]) {
        if let a = d["anmeldung"] as? [String: Any] { anmeldungMerken(a) }
        guard (d["fehler"] as? Bool) != true,
              let json = try? JSONSerialization.data(withJSONObject: d["titel"] as? [Any] ?? []),
              let titel = try? JSONDecoder().decode([WebTitel].self, from: json) else {
            return Hinweis.zeigen(Text.keineVerbindung, in: view.window)
        }
        let mitQuelle = titel.filter { $0.quelle != nil }
        let stufen = DownloadQualitaet.verfuegbar(mitQuelle)
        guard !stufen.isEmpty, let anmeldung = Schluesselbund.lesen() else {
            return Hinweis.zeigen(Text.nichts, in: view.window)
        }
        qualitaetWaehlen(mitQuelle, stufen, anmeldung)
    }

    private func qualitaetWaehlen(_ titel: [WebTitel], _ stufen: [DownloadQualitaet], _ anmeldung: Anmeldung) {
        let name: String
        if titel.count == 1 {
            name = titel[0].name ?? ""
        } else if titel.allSatisfy({ $0.typ == "Episode" }) {
            name = Text.dlFolgen(titel.count)
        } else {
            name = Text.dlTitel(titel.count)
        }
        let frei = Downloads.frei
        var hinweise = [Text.frei(Downloads.menge(frei))]
        if stufen.contains(where: { $0 != .original }) { hinweise.append(Text.hinweisKlein) }
        if Downloads.shared.nurWlan { hinweise.append(Text.nurWlanHinweis) }

        var knoepfe: [KinoLelDialog.Knopf] = stufen.map { stufe in
            let groesse = titel.reduce(Int64(0)) { $0 + stufe.groesse($1) }
            let passt = frei <= 0 || groesse < frei
            let text = passt ? (groesse > 0 ? "\(stufe.name) · ≈ \(Downloads.menge(groesse))" : stufe.name) : "\(stufe.name) · \(Text.zuGross)"
            return KinoLelDialog.Knopf(titel: text, art: .wahl, aktiv: passt, kennung: "kinolel.qualitaet.\(stufe.rawValue)") { [weak self] in
                let neu = Downloads.shared.einreihen(titel, qualitaet: stufe, anmeldung: anmeldung)
                guard neu > 0 else { self?.downloadsZeigen(); return }
                let sofort = !Downloads.shared.nurWlan || Downloads.shared.wlan
                Hinweis.zeigen(sofort ? Text.gestartet(neu) : Text.wartetWlan(neu), in: self?.view.window)
            }
        }
        knoepfe.append(KinoLelDialog.Knopf(titel: Text.abbrechen))
        KinoLelDialog(titel: Text.dlUeberschrift(name), text: hinweise.joined(separator: "\n\n"), knoepfe: knoepfe).zeigen(auf: self)
    }

    @objc private func downloadsZeigen() {
        if let nav = presentedViewController as? UINavigationController, nav.viewControllers.first is DownloadsViewController { return }
        let liste = DownloadsViewController()
        liste.abspielen = { [weak self] t in self?.player.lokalAbspielen(t) }
        let nav = UINavigationController(rootViewController: liste)
        nav.overrideUserInterfaceStyle = .dark
        nav.navigationBar.tintColor = Marke.lavendel
        (presentedViewController ?? self).present(nav, animated: true)
    }

    // MARK: Tests im Simulator

    #if DEBUG
    /// XCUITest (nur Debug-Build): Anmeldung mit Kennwort aus der Testumgebung (KINOLEL_TEST_PW, nie in Logs),
    /// Sprung zu einem Titel (-KinoLelTestZiel '#/details?id=…'), Download-Liste öffnen (-KinoLelTestDownloads YES),
    /// Abmelden (-KinoLelTestAbmelden YES; vorher Serverposition von -KinoLelTestZuruecksetzen <id> melden und auf 0
    /// setzen), Fernsteuerung vom Server (-KinoLelTestFernsteuerung <id>: Play, Pause, Nachricht, Weiter, Spulen, Stopp an
    /// die eigene Sitzung – prüft den Weg Server → Weboberfläche → nativer Player). Ergebnisse als „KinoLel-Test: …“.
    private func testHilfen() {
        guard !testGestartet else { return }
        testGestartet = true
        let vorlieben = UserDefaults.standard
        let umgebung = ProcessInfo.processInfo.environment
        let kennwort = umgebung["KINOLEL_TEST_PW"] ?? ""
        let ziel = vorlieben.string(forKey: "KinoLelTestZiel") ?? ""
        let abmelden = vorlieben.bool(forKey: "KinoLelTestAbmelden")
        let zuruecksetzen = vorlieben.string(forKey: "KinoLelTestZuruecksetzen") ?? ""
        let fern = vorlieben.string(forKey: "KinoLelTestFernsteuerung") ?? ""
        guard !kennwort.isEmpty || !ziel.isEmpty || abmelden || !fern.isEmpty else { return }
        let werte: [Any] = [umgebung["KINOLEL_TEST_BENUTZER"] ?? "kinolel-hilfe", kennwort, ziel, abmelden, zuruecksetzen, fern]
        guard let json = try? JSONSerialization.data(withJSONObject: werte), let text = String(data: json, encoding: .utf8) else { return }
        let skript = """
        (async function (w) {
          const [benutzer, kennwort, ziel, abmelden, zuruecksetzen, fern] = w;
          const log = (t) => postKinoLel('console.warn', 'KinoLel-Test: ' + t);
          const warte = async (f, s) => { for (let i = 0; i < s * 2; i++) { try { if (f()) return true; } catch (e) {} await new Promise(r => setTimeout(r, 500)); } return false; };
          const angemeldet = () => !!(window.ApiClient && ApiClient.accessToken() && ApiClient.getCurrentUserId());
          // Werte so setzen, dass auch React-Formulare sie übernehmen (Jellyfin 12.3); bis zu drei Versuche
          const setze = (feld, wert) => {
            Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(feld, wert);
            feld.dispatchEvent(new Event('input', { bubbles: true }));
            feld.dispatchEvent(new Event('change', { bubbles: true }));
          };
          for (let versuch = 1; kennwort && versuch <= 3 && !angemeldet(); versuch++) {
            if (!await warte(() => angemeldet() || document.querySelector('#txtManualName'), 60) || angemeldet()) break;
            setze(document.querySelector('#txtManualName'), benutzer);
            setze(document.querySelector('#txtManualPassword'), kennwort);
            await new Promise(r => setTimeout(r, 300));
            document.querySelector('#loginPage .manualLoginForm button[type=submit]').click();
            log('Anmeldung abgeschickt (Versuch ' + versuch + ')');
            if (await warte(() => angemeldet(), 20)) break;
            const hinweis = document.querySelector('.toast, .errorMessage, .dialog .dialogContent, [role=alert]');
            log('Anmeldung noch nicht durch: ' + (hinweis ? hinweis.textContent.trim().slice(0, 120) : 'kein Hinweis') + ', Seite ' + location.hash);
          }
          if (!await warte(() => angemeldet() && /^#\\/home/.test(location.hash), 60)) { log('nicht angemeldet'); return; }
          log('angemeldet');
          if (abmelden) {
            // Erst die App nachmelden lassen (5 s nach dem Laden), dann Serverstand prüfen und zurücksetzen
            await new Promise(r => setTimeout(r, 15000));
            if (zuruecksetzen) {
              const it = await ApiClient.getItem(ApiClient.getCurrentUserId(), zuruecksetzen);
              log('Serverposition ' + ((it.UserData && it.UserData.PlaybackPositionTicks) || 0));
              await ApiClient.ajax({ type: 'POST', url: ApiClient.getUrl('UserItems/' + zuruecksetzen + '/UserData'),
                data: JSON.stringify({ PlaybackPositionTicks: 0, Played: false }), contentType: 'application/json' });
              log('Serverposition zurückgesetzt');
            }
            await ApiClient.logout();
            log('abgemeldet');
            return;
          }
          if (fern) {
            // Befehle vom Server an die eigene Sitzung (wie Dashboard/Streams-Grenze)
            const warten = (ms) => new Promise(r => setTimeout(r, ms));
            await warten(3000);
            const sitzungen = await ApiClient.getSessions({ deviceId: ApiClient.deviceId() });
            const s = (sitzungen || []).find(x => x.DeviceId === ApiClient.deviceId());
            if (!s) { log('Fernsteuerung: keine Sitzung'); return; }
            log('Fernsteuerung: Sitzung fernsteuerbar=' + s.SupportsRemoteControl + ', Befehle=' + (s.SupportedCommands || []).length);
            await ApiClient.sendPlayCommand(s.Id, { ItemIds: fern, PlayCommand: 'PlayNow' }); log('Fernsteuerung: Play gesendet');
            await warten(15000);
            await ApiClient.sendPlayStateCommand(s.Id, 'Pause'); log('Fernsteuerung: Pause gesendet');
            await warten(4000);
            await ApiClient.sendMessageCommand(s.Id, { Header: 'KinoLel-Test', Text: 'Nachricht über dem Player', TimeoutMs: 5000 });
            log('Fernsteuerung: Nachricht gesendet');
            await warten(4000);
            await ApiClient.sendPlayStateCommand(s.Id, 'Unpause'); log('Fernsteuerung: Weiter gesendet');
            await warten(4000);
            await ApiClient.sendPlayStateCommand(s.Id, 'Seek', { SeekPositionTicks: 600000000 }); log('Fernsteuerung: Spulen gesendet');
            await warten(4000);
            await ApiClient.sendPlayStateCommand(s.Id, 'Stop'); log('Fernsteuerung: Stopp gesendet');
            await warten(3000);
            log('Fernsteuerung fertig');
            return;
          }
          if (ziel) { location.hash = ziel + '&serverId=' + ApiClient.serverId(); log('Ziel geöffnet'); }
        })(\(text));
        """
        webView.evaluateJavaScript(skript, completionHandler: nil)
    }
    #endif
}

/// Verhindert einen Speicher-Kreis WKUserContentController -> Handler -> WebView
private final class SchwacherHandler: NSObject, WKScriptMessageHandler {
    weak var ziel: WKScriptMessageHandler?
    init(_ ziel: WKScriptMessageHandler) { self.ziel = ziel }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        ziel?.userContentController(userContentController, didReceive: message)
    }
}

private final class SchwacherAntwortHandler: NSObject, WKScriptMessageHandlerWithReply {
    weak var ziel: WKScriptMessageHandlerWithReply?
    init(_ ziel: WKScriptMessageHandlerWithReply) { self.ziel = ziel }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) {
        guard let ziel else { return replyHandler(nil, "beendet") }
        ziel.userContentController(userContentController, didReceive: message, replyHandler: replyHandler)
    }
}

/// Eingebettete Skripte aus dem App-Paket
enum Skripte {
    static func lade(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("KinoLel: Skript %@ fehlt", name)
            return ""
        }
        return text
    }

    /// App-Infos und Abspielprofil des nativen Players für die Weboberfläche
    static func appInfo() -> String {
        let info: [String: Any] = [
            "appName": Marke.appName,
            "appVersion": Marke.version,
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            "deviceName": UIDevice.current.name
        ]
        let infoJSON = (try? JSONSerialization.data(withJSONObject: info)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        var profil = "{}"
        if let url = Bundle.main.url(forResource: "profil", withExtension: "json"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            profil = text
        }
        return "window.KinoLelAppInfo = \(infoJSON);\nwindow.KinoLelVideoProfil = \(profil);\n"
    }
}
