// KinoLel-App (iOS): Start
import AVFoundation
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Kernanforderung: Ton läuft bei gesperrtem Bildschirm / im Hintergrund weiter.
        // Kategorie "Wiedergabe" + UIBackgroundModes "audio" (project.yml).
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
        } catch {
            NSLog("KinoLel: Audio-Sitzung: %@", error.localizedDescription)
        }
        // Vor dem ersten WKWebView: erkennt Neuinstallation/Update für „Was ist neu“
        Neuigkeiten.vorbereiten()
        // Downloads: Hintergrund-Sitzung wieder verbinden, Netz beobachten
        Downloads.shared.starten()
        return true
    }

    /// Downloads wurden im Hintergrund fertig (App war geschlossen)
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        Downloads.shared.hintergrundFertig = completionHandler
        Downloads.shared.starten()
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let konfig = UISceneConfiguration(name: "Standard", sessionRole: connectingSceneSession.role)
        konfig.delegateClass = SceneDelegate.self
        return konfig
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let fensterSzene = scene as? UIWindowScene else { return }
        let fenster = UIWindow(windowScene: fensterSzene)
        fenster.rootViewController = WebViewController()
        fenster.backgroundColor = Marke.grund
        fenster.makeKeyAndVisible()
        window = fenster
    }
}
