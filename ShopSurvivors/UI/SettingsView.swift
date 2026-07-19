import SwiftUI

struct SettingsView: View {
    @ObservedObject var session: GameSession
    @State private var musicOn = AudioManager.shared.musicEnabled
    @State private var sfxOn = AudioManager.shared.sfxEnabled
    @State private var didReset = false
    @State private var didQueueTutorial = false

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.12, blue: 0.16)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("SETTINGS")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))

                    HStack {
                        Button {
                            AudioManager.shared.playSFX(.ui)
                            Haptics.ui()
                            session.leaveSettings()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 12) {
                        Toggle("Music", isOn: $musicOn)
                            .onChange(of: musicOn) { _, on in
                                AudioManager.shared.musicEnabled = on
                                AudioManager.shared.playSFX(.ui)
                                if on {
                                    AudioManager.shared.playMusic(forceRestart: true)
                                }
                            }

                        Toggle("Sound Effects", isOn: $sfxOn)
                            .onChange(of: sfxOn) { _, on in
                                AudioManager.shared.sfxEnabled = on
                                if on {
                                    AudioManager.shared.playSFX(.ui)
                                }
                            }

                        Divider().overlay(Color.white.opacity(0.15))

                        Button {
                            AudioManager.shared.playSFX(.ui)
                            Haptics.ui()
                            session.requestTutorialReplay()
                            didQueueTutorial = true
                        } label: {
                            settingsRow(
                                title: "Replay tutorial next run",
                                subtitle: didQueueTutorial
                                    ? "Queued — opens on your next store entry"
                                    : "Shows the first-run coaching overlay again"
                            )
                        }

                        Button {
                            AudioManager.shared.playSFX(.ui)
                            Haptics.ui()
                            session.requestLoreIntroReplay()
                        } label: {
                            settingsRow(
                                title: "Replay opening story",
                                subtitle: "Watch the manga intro again"
                            )
                        }

                        Button {
                            AudioManager.shared.playSFX(.ui)
                            Haptics.ui()
                            session.goHowToPlay()
                        } label: {
                            settingsRow(
                                title: "How to Play",
                                subtitle: "Controls, LURE, XP, and how to win"
                            )
                        }

                        Button {
                            AudioManager.shared.playSFX(.ui)
                            Haptics.ui()
                            session.resetUnlocks()
                            didReset = true
                        } label: {
                            settingsRow(
                                title: "Reset store unlocks",
                                subtitle: didReset
                                    ? "Progress cleared — only the first store is open"
                                    : "Locks Fashion, Grocery, and Endless again"
                            )
                        }
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(Color(red: 1.0, green: 0.55, blue: 0.25))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 8)
        }
        .onAppear {
            musicOn = AudioManager.shared.musicEnabled
            sfxOn = AudioManager.shared.sfxEnabled
        }
    }

    private func settingsRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView(session: GameSession())
}
