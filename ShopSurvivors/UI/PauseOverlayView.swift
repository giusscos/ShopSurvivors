import SwiftUI

struct PauseOverlayView: View {
    @ObservedObject var session: GameSession
    @State private var musicOn = AudioManager.shared.musicEnabled

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("PAUSED")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        legendRow("Cyan XP gems", "Pick up for level-ups")
                        legendRow("Orange LURE", "Draws clerks away from your friend")
                        legendRow("TAG / RCP / LASER / BAG", "Auto-weapons")
                        legendRow("Pitch text", "Clerk draining budget near friend")
                        legendRow("Bump clerks", "Walk into them to shove them")
                        legendRow("Unlock stores", "Survive the timer with $ left")
                    }
                    .padding(12)
                }
                .frame(maxHeight: 140)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Toggle("Music", isOn: $musicOn)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(Color(red: 1.0, green: 0.55, blue: 0.25))
                    .frame(maxWidth: 200)
                    .onChange(of: musicOn) { _, on in
                        AudioManager.shared.musicEnabled = on
                        if on {
                            AudioManager.shared.playMusic(forceRestart: true)
                        }
                    }

                HStack(spacing: 12) {
                    Button {
                        session.resume()
                    } label: {
                        Text("Resume")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.18))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(red: 1.0, green: 0.55, blue: 0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Button {
                        session.goLevelSelect()
                    } label: {
                        Text("Quit Store")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.14, blue: 0.18).opacity(0.95))
            )
            .padding(.horizontal, 24)
        }
        .onAppear {
            musicOn = AudioManager.shared.musicEnabled
            // Keep soundtrack audible while paused (toggle still works).
            if musicOn {
                AudioManager.shared.playMusic()
            }
        }
    }

    private func legendRow(_ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))
                .frame(width: 130, alignment: .leading)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
