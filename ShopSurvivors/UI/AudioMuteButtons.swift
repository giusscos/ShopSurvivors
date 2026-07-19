import SwiftUI

/// Compact music / SFX mute toggles for title and mall chrome.
struct AudioMuteButtons: View {
    var size: CGFloat = 40
    var cornerRadius: CGFloat = 10

    @State private var musicOn = AudioManager.shared.musicEnabled
    @State private var sfxOn = AudioManager.shared.sfxEnabled

    var body: some View {
        HStack(spacing: 8) {
            muteButton(
                systemName: musicOn ? "music.note" : "music.note.slash",
                isOn: musicOn,
                label: musicOn ? "Mute music" : "Unmute music"
            ) {
                musicOn.toggle()
                AudioManager.shared.musicEnabled = musicOn
                AudioManager.shared.playSFX(.ui)
                if musicOn {
                    AudioManager.shared.playMusic(forceRestart: true)
                }
            }

            muteButton(
                systemName: sfxOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                isOn: sfxOn,
                label: sfxOn ? "Mute sound effects" : "Unmute sound effects"
            ) {
                sfxOn.toggle()
                AudioManager.shared.sfxEnabled = sfxOn
                if sfxOn {
                    AudioManager.shared.playSFX(.ui)
                }
            }
        }
        .onAppear {
            musicOn = AudioManager.shared.musicEnabled
            sfxOn = AudioManager.shared.sfxEnabled
        }
    }

    private func muteButton(
        systemName: String,
        isOn: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.ui()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: size * 0.375, weight: .bold))
                .foregroundStyle(isOn ? .white : .white.opacity(0.45))
                .frame(width: size, height: size)
                .background(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .accessibilityLabel(label)
    }
}
