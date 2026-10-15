// KinoLel-App (iOS): Weboberfläche von kinolel.de im WKWebView (fester Server, keine Serverauswahl).
// Die Anmeldeseite inkl. Sprachwahl Deutsch/Magyar kommt von kinolel.de (kinolel.js, localStorage "kl-sprache").
import UIKit
import WebKit

final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    private let startbild = StartbildView()
    private let player = PlayerController()
    private var geladen = false
    private var hinweisTimer: Timer?
    private var neuTimer: Timer?

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Marke.grund

        let inhalt = WKUserContentController()
        inhalt.add(SchwacherHandler(self), name: "kinolel")
        for quelle in [Skripte.appInfo(), Skripte.lade("nativeshell"), Skripte.lade("videoplayer")] {
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
        laden()
    }

    // MARK: Laden / Ausfall

    private func laden() {
        neuTimer?.invalidate()
        hinweisTimer?.invalidate()
        startbild.zuruecksetzen()
        hinweisTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            guard let self, !self.geladen else { return }
            self.startbild.zeigeVerbinde()
        }
        let ziel = Marke.serverURL.appendingPathComponent("web/")
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
        startbild.zeigeFehler()
        neuTimer?.invalidate()
        neuTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in self?.laden() }
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
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { ausfall(error) }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        ausfall(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        geladen = false
        webView.reload()
    }

    // MARK: Links

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
        let eigen = url.host == Marke.serverURL.host || url.scheme == "about" || url.scheme == "blob" || url.scheme == "data"
        if !eigen && navigationAction.navigationType == .linkActivated {
            UIApplication.shared.open(url)
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }

    // target=_blank / window.open (z. B. KinoLel Wünsche) -> Safari
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { UIApplication.shared.open(url) }
        return nil
    }

    // MARK: Nachrichten aus der Weboberfläche (nativeshell.js / videoplayer.js)

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let nachricht = message.body as? [String: Any], let ereignis = nachricht["event"] as? String else { return }
        let daten = nachricht["data"]
        switch ereignis {
        case "video.play":
            if let d = daten as? [String: Any] { player.abspielen(d) }
        case "video.playPause": player.playPause()
        case "video.pause": player.pause()
        case "video.unpause": player.weiter()
        case "video.stop": player.stoppen(manuell: false)
        case "video.seek":
            if let ms = daten as? Double { player.springe(ms: ms) }
        case "openUrl":
            if let text = (daten as? [String: Any])?["url"] as? String, let url = URL(string: text, relativeTo: Marke.serverURL) {
                UIApplication.shared.open(url)
            }
        case "console.error", "console.warn":
            NSLog("KinoLel Web %@: %@", ereignis, String(describing: daten ?? ""))
        default:
            break
        }
    }
}

/// Verhindert einen Speicher-Kreis WKUserContentController -> Handler -> WebView
private final class SchwacherHandler: NSObject, WKScriptMessageHandler {
    weak var ziel: WKScriptMessageHandler?
    init(_ ziel: WKScriptMessageHandler) { self.ziel = ziel }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        ziel?.userContentController(userContentController, didReceive: message)
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
