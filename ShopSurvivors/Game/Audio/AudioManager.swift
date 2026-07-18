import AVFoundation
import Foundation

enum SFX: String, CaseIterable {
    case hit = "sfx_hit"
    case defeat = "sfx_defeat"
    case shove = "sfx_shove"
    case xp = "sfx_xp"
    case coupon = "sfx_coupon"
    case pitch = "sfx_pitch"
    case levelup = "sfx_levelup"
    case win = "sfx_win"
    case lose = "sfx_lose"
    case ui = "sfx_ui"
    case door = "sfx_door"
    case clerkPitcher = "sfx_clerk_pitcher"
    case clerkCloser = "sfx_clerk_closer"
    case clerkSprinter = "sfx_clerk_sprinter"
    case clerkUpseller = "sfx_clerk_upseller"
    case companion = "sfx_companion"

    static func clerkVoice(_ type: ClerkType) -> SFX {
        switch type {
        case .pitcher: .clerkPitcher
        case .closer: .clerkCloser
        case .sprinter: .clerkSprinter
        case .upseller: .clerkUpseller
        }
    }
}

@MainActor
final class AudioManager {
    static let shared = AudioManager()

    private var musicPlayer: AVAudioPlayer?
    private var sfxPlayers: [String: [AVAudioPlayer]] = [:]
    private let sfxPoolSize = 3
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

    var sfxEnabled: Bool {
        didSet {
            UserDefaults.standard.set(sfxEnabled, forKey: "sfxEnabled")
        }
    }

    private init() {
        musicEnabled = UserDefaults.standard.object(forKey: "musicEnabled") as? Bool ?? true
        sfxEnabled = UserDefaults.standard.object(forKey: "sfxEnabled") as? Bool ?? true
    }

    func setup() {
        guard !isSetup else {
            activateSession()
            return
        }
        isSetup = true
        activateSession()
        loadMusic()
        preloadSFX()
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

    private func preloadSFX() {
        for sfx in SFX.allCases {
            guard let url = Bundle.main.url(forResource: sfx.rawValue, withExtension: "wav") else {
                print("Missing \(sfx.rawValue).wav in bundle")
                continue
            }
            var pool: [AVAudioPlayer] = []
            for _ in 0..<sfxPoolSize {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    pool.append(player)
                } catch {
                    print("SFX load error \(sfx.rawValue): \(error)")
                }
            }
            if !pool.isEmpty {
                sfxPlayers[sfx.rawValue] = pool
            }
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

    func playSFX(_ sfx: SFX, volume: Float = 1) {
        setup()
        guard sfxEnabled else { return }
        if sfxPlayers[sfx.rawValue] == nil {
            preloadSFX()
        }
        guard let pool = sfxPlayers[sfx.rawValue], !pool.isEmpty else { return }
        let player = pool.first(where: { !$0.isPlaying }) ?? pool[0]
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}
