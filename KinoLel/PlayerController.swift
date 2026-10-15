// KinoLel-App (iOS): nativer Video-Player (AVPlayer) mit Hintergrund-Wiedergabe.
//
// Kernanforderung (Lel): Wird der Bildschirm gesperrt oder die App verlassen, läuft der Ton weiter.
// Umsetzung nach Apple-Vorgabe („Playing audio from a video asset in the background“):
//  - Audio-Sitzung .playback (AppDelegate) + UIBackgroundModes audio (project.yml)
//  - beim Wechsel in den Hintergrund den Player vom Bild (AVPlayerViewController) lösen und weiterspielen,
//    beim Zurückkommen wieder verbinden – außer Bild-in-Bild läuft gerade
//  - Sperrbildschirm/Kontrollzentrum: Titel, Bild, Fortschritt (MPNowPlayingInfoCenter) und
//    Wiedergabe/Pause/Spulen (MPRemoteCommandCenter)
import AVKit
import MediaPlayer
import UIKit
import WebKit

final class PlayerController: NSObject, AVPlayerViewControllerDelegate {
    weak var webView: WKWebView?
    weak var gastgeber: UIViewController?

    private var player: AVPlayer?
    private var ansicht: KinoLelPlayerViewController?
    private var zeitBeobachter: Any?
    private var zustandBeobachtung: NSKeyValueObservation?
    private var endeBeobachter: NSObjectProtocol?
    private var aktuelleURL: String?
    private var titel = ""
    private var untertitel = ""
    private var bild: MPMediaItemArtwork?
    private var bildAktiv = false          // Bild-in-Bild läuft
    private var wiederherstellen = false
    private var spielteVorHintergrund = false
    private var befehleAktiv = false

    override init() {
        super.init()
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(wirdInaktiv), name: UIScene.willDeactivateNotification, object: nil)
        nc.addObserver(self, selector: #selector(imHintergrund), name: UIScene.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(imVordergrund), name: UIScene.willEnterForegroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(unterbrechung(_:)), name: AVAudioSession.interruptionNotification,
                       object: AVAudioSession.sharedInstance())
    }

    // MARK: Steuerung aus der Weboberfläche

    func abspielen(_ daten: [String: Any]) {
        guard let text = daten["url"] as? String, let url = URL(string: text, relativeTo: Marke.serverURL),
              let gastgeber else { return }
        stoppen(manuell: false, melden: false)

        aktuelleURL = text
        titel = (daten["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? Marke.appName
        untertitel = daten["subtitle"] as? String ?? ""
        bild = nil

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("KinoLel: Audio-Sitzung aktivieren: %@", error.localizedDescription)
        }

        let eintrag = AVPlayerItem(url: url.absoluteURL)
        let p = AVPlayer(playerItem: eintrag)
        p.allowsExternalPlayback = true
        player = p

        let startTicks = (daten["playerStartPositionTicks"] as? Double) ?? 0
        if startTicks > 0 {
            let sekunden = startTicks / 10_000_000
            p.seek(to: CMTime(seconds: sekunden, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }

        let pvc = KinoLelPlayerViewController()
        pvc.player = p
        pvc.delegate = self
        pvc.allowsPictureInPicturePlayback = true
        pvc.canStartPictureInPictureAutomaticallyFromInline = true
        pvc.updatesNowPlayingInfoCenter = false // Sperrbildschirm pflegen wir selbst (auch ohne Bild)
        pvc.modalPresentationStyle = .fullScreen
        pvc.beimSchliessen = { [weak self] in
            guard let self, !self.bildAktiv, !self.wiederherstellen else { return }
            self.stoppen(manuell: true)
        }
        ansicht = pvc

        zeitBeobachter = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 10), queue: .main) { [weak self] _ in
            self?.melden()
            self?.sperrbildschirm()
        }
        zustandBeobachtung = p.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.melden()
                self?.sperrbildschirm()
            }
        }
        endeBeobachter = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: eintrag,
                                                                queue: .main) { [weak self] _ in
            self?.stoppen(manuell: false)
        }

        befehleEinrichten()
        bildLaden(daten["backdropUrl"] as? String)

        let oben = gastgeber.presentedViewController ?? gastgeber
        oben.present(pvc, animated: true) { p.play() }
    }

    func playPause() {
        guard let p = player else { return }
        if p.timeControlStatus == .paused { p.play() } else { p.pause() }
    }

    func pause() { player?.pause() }
    func weiter() { player?.play() }

    func springe(ms: Double) {
        player?.seek(to: CMTime(seconds: ms / 1000, preferredTimescale: 600))
    }

    /// Wiedergabe beenden. manuell = der Nutzer hat den Player geschlossen (Weboberfläche beendet die Wiedergabe dann auch).
    func stoppen(manuell: Bool, melden: Bool = true) {
        guard player != nil || ansicht != nil else { return }
        if let z = zeitBeobachter { player?.removeTimeObserver(z) }
        zeitBeobachter = nil
        zustandBeobachtung = nil
        if let e = endeBeobachter { NotificationCenter.default.removeObserver(e) }
        endeBeobachter = nil
        player?.pause()
        player = nil

        if let pvc = ansicht {
            pvc.beimSchliessen = nil
            if pvc.presentingViewController != nil && !pvc.isBeingDismissed { pvc.dismiss(animated: true) }
        }
        ansicht = nil
        aktuelleURL = nil
        bildAktiv = false
        befehleEntfernen()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        if melden {
            js(["uri": NSNull(), "isPlaying": false, "positionMillis": 0, "didPlayerCloseManually": manuell])
        }
    }

    // MARK: Zustand an die Weboberfläche (Fortschritt wird so an Jellyfin gemeldet)

    private func melden() {
        guard let p = player, let url = aktuelleURL else { return }
        let pos = p.currentTime().seconds
        var status: [String: Any] = [
            "uri": url,
            "isPlaying": p.timeControlStatus != .paused,
            "positionMillis": pos.isFinite ? Int(pos * 1000) : 0,
            "didPlayerCloseManually": false
        ]
        if let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 { status["durationMillis"] = Int(d * 1000) }
        js(status)
    }

    private func js(_ status: [String: Any]) {
        guard let daten = try? JSONSerialization.data(withJSONObject: status),
              let text = String(data: daten, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.KinoLelVideo && window.KinoLelVideo._reportStatus(\(text));", completionHandler: nil)
    }

    // MARK: Hintergrund (Kernanforderung)

    @objc private func wirdInaktiv() {
        spielteVorHintergrund = player?.timeControlStatus != .paused && player != nil
    }

    @objc private func imHintergrund() {
        guard let p = player, let pvc = ansicht, !bildAktiv else { return }
        // Bild lösen, damit iOS das Video nicht anhält – der Ton läuft weiter
        pvc.player = nil
        if spielteVorHintergrund || p.timeControlStatus != .paused { p.play() }
        sperrbildschirm()
    }

    @objc private func imVordergrund() {
        guard let p = player, let pvc = ansicht, pvc.player == nil else { return }
        pvc.player = p
    }

    @objc private func unterbrechung(_ n: Notification) {
        guard let info = n.userInfo, let typWert = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let typ = AVAudioSession.InterruptionType(rawValue: typWert), typ == .ended else { return }
        // z. B. nach einem Anruf weiterspielen, wenn iOS es erlaubt
        if let o = info[AVAudioSessionInterruptionOptionKey] as? UInt,
           AVAudioSession.InterruptionOptions(rawValue: o).contains(.shouldResume) {
            try? AVAudioSession.sharedInstance().setActive(true)
            player?.play()
        }
    }

    // MARK: Sperrbildschirm / Kontrollzentrum

    private func sperrbildschirm() {
        guard let p = player, let eintrag = p.currentItem else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: titel,
            MPNowPlayingInfoPropertyPlaybackRate: p.timeControlStatus == .paused ? 0.0 : Double(p.rate == 0 ? 1 : p.rate),
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue
        ]
        let pos = p.currentTime().seconds
        if pos.isFinite { info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = pos }
        let dauer = eintrag.duration.seconds
        if dauer.isFinite && dauer > 0 { info[MPMediaItemPropertyPlaybackDuration] = dauer }
        if !untertitel.isEmpty { info[MPMediaItemPropertyArtist] = untertitel }
        info[MPMediaItemPropertyAlbumTitle] = Marke.appName
        if let bild { info[MPMediaItemPropertyArtwork] = bild }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func befehleEinrichten() {
        guard !befehleAktiv else { return }
        befehleAktiv = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            guard let p = self?.player else { return .noActionableNowPlayingItem }
            p.play(); return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            guard let p = self?.player else { return .noActionableNowPlayingItem }
            p.pause(); return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard self?.player != nil else { return .noActionableNowPlayingItem }
            self?.playPause(); return .success
        }
        c.skipForwardCommand.preferredIntervals = [30]
        c.skipForwardCommand.addTarget { [weak self] _ in self?.relativ(30) ?? .noActionableNowPlayingItem }
        c.skipBackwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.addTarget { [weak self] _ in self?.relativ(-15) ?? .noActionableNowPlayingItem }
        c.changePlaybackPositionCommand.addTarget { [weak self] e in
            guard let p = self?.player, let ereignis = e as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            p.seek(to: CMTime(seconds: ereignis.positionTime, preferredTimescale: 600))
            return .success
        }
        for befehl in [c.playCommand, c.pauseCommand, c.togglePlayPauseCommand, c.skipForwardCommand,
                       c.skipBackwardCommand, c.changePlaybackPositionCommand] {
            befehl.isEnabled = true
        }
    }

    private func befehleEntfernen() {
        guard befehleAktiv else { return }
        befehleAktiv = false
        let c = MPRemoteCommandCenter.shared()
        for befehl in [c.playCommand, c.pauseCommand, c.togglePlayPauseCommand, c.skipForwardCommand,
                       c.skipBackwardCommand, c.changePlaybackPositionCommand] {
            befehl.removeTarget(nil)
        }
    }

    private func relativ(_ sekunden: Double) -> MPRemoteCommandHandlerStatus {
        guard let p = player else { return .noActionableNowPlayingItem }
        let ziel = max(0, p.currentTime().seconds + sekunden)
        p.seek(to: CMTime(seconds: ziel, preferredTimescale: 600))
        return .success
    }

    private func bildLaden(_ text: String?) {
        guard let text, let url = URL(string: text, relativeTo: Marke.serverURL) else { return }
        URLSession.shared.dataTask(with: url.absoluteURL) { [weak self] daten, _, _ in
            guard let daten, let bild = UIImage(data: daten) else { return }
            DispatchQueue.main.async {
                self?.bild = MPMediaItemArtwork(boundsSize: bild.size) { _ in bild }
                self?.sperrbildschirm()
            }
        }.resume()
    }

    // MARK: Bild-in-Bild

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        bildAktiv = true
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        bildAktiv = false
        // Bild-in-Bild mit „X“ geschlossen (ohne Rückkehr in den Player) -> Wiedergabe beenden
        if !wiederherstellen && ansicht?.presentingViewController == nil {
            stoppen(manuell: true)
        }
    }

    func playerViewController(_ playerViewController: AVPlayerViewController,
                              restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        guard let pvc = ansicht, let gastgeber else { return completionHandler(false) }
        if pvc.presentingViewController != nil { return completionHandler(true) }
        wiederherstellen = true
        let oben = gastgeber.presentedViewController ?? gastgeber
        oben.present(pvc, animated: true) {
            self.wiederherstellen = false
            completionHandler(true)
        }
    }
}

/// Meldet, wenn der Nutzer den Vollbild-Player schließt („Fertig“ oder nach unten wischen)
final class KinoLelPlayerViewController: AVPlayerViewController {
    var beimSchliessen: (() -> Void)?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil {
            beimSchliessen?()
        }
    }
}
