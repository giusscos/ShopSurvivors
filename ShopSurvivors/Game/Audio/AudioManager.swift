import AVFoundation
import Foundation

@MainActor
final class AudioManager {
    static let shared = AudioManager()

    private var musicPlayer: AVAudioPlayer?
    private var isSetup = false

    var musicEnabled: Bool {
        didSet {
            UserDefaults.standard.set(musicEnabled, forKey: "musicEnabled")
            if musicEnabled {
                playMusic(forceRestart: true)
            } else {
                musicPlayer?.stop()
            }
        }
    }

    private init() {
        musicEnabled = UserDefaults.standard.object(forKey: "musicEnabled") as? Bool ?? true
    }

    func setup() {
        guard !isSetup else {
            activateSession()
            return
        }
        isSetup = true
        activateSession()
        loadMusic()
    }

    private func activateSession() {
        do {
            // `.playback` ignores the hardware mute switch (ambient does not).
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func loadMusic() {
        guard let url = Bundle.main.url(forResource: "mall_survivors_theme", withExtension: "wav") else {
            print("Missing mall_survivors_theme.wav in bundle")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.45
            player.prepareToPlay()
            musicPlayer = player
        } catch {
            print("Music load error: \(error)")
        }
    }

    func playMusic(forceRestart: Bool = false) {
        setup()
        guard musicEnabled else { return }
        if musicPlayer == nil { loadMusic() }
        guard let player = musicPlayer else { return }
        if forceRestart {
            player.currentTime = 0
        }
        if !player.isPlaying {
            let ok = player.play()
            if !ok {
                print("AVAudioPlayer.play() returned false")
                activateSession()
                player.play()
            }
        }
    }

    func stopMusic() {
        musicPlayer?.stop()
    }
}
