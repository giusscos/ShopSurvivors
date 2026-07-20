import SwiftUI

struct PauseOverlayView: View {
    @Bindable var session: GameSession
    @State private var musicOn = AudioManager.shared.musicEnabled
    @State private var sfxOn = AudioManager.shared.sfxEnabled

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("PAUSED")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))

                ScrollView {
                    VStack(spacing: 14) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                legendRow("Cyan XP gems", "Pick up for level-ups")
                                legendRow("Orange LURE", "Draws clerks away from your friend")
                                legendRow("AURA / RCP / LASER / BAG", "Auto-weapons")
                                legendRow("Pitch text", "Clerk draining budget near friend")
                                legendRow("Bump clerks", "Walk into them to shove them")
                                legendRow("Unlock stores", "Survive the timer with $ left")
                                if GameControllerManager.shared.isConnected {
                                    legendRow("Controller", "Left stick move · A drop LURE · Menu pause")
                                }
                            }
                            .padding(12)
                        }
                        .frame(maxHeight: 110)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        settingsCard("Audio") {
                            settingRow("Music") {
                                Toggle("", isOn: $musicOn)
                                    .onChange(of: musicOn) { _, on in
                                        AudioManager.shared.musicEnabled = on
                                        AudioManager.shared.playSFX(.ui)
                                        if on { AudioManager.shared.playMusic(forceRestart: true) }
                                    }
                            }
                            settingDivider()
                            settingRow("Sound Effects") {
                                Toggle("", isOn: $sfxOn)
                                    .onChange(of: sfxOn) { _, on in
                                        AudioManager.shared.sfxEnabled = on
                                        if on { AudioManager.shared.playSFX(.ui) }
                                    }
                            }
                        }

                        settingsCard("Feedback & Display") {
                            settingRow("Haptics") {
                                Toggle("", isOn: $session.hapticsEnabled)
                                    .onChange(of: session.hapticsEnabled) { _, on in
                                        AudioManager.shared.playSFX(.ui)
                                        if on { Haptics.ui() }
                                    }
                            }
                            settingDivider()
                            settingRow("Reduce FX") {
                                Toggle("", isOn: $session.reducedFX)
                                    .onChange(of: session.reducedFX) { _, _ in
                                        AudioManager.shared.playSFX(.ui)
                                    }
                            }
                            settingDivider()
                            settingRow("Show diagnostics") {
                                Toggle("", isOn: $session.showFPS)
                                    .onChange(of: session.showFPS) { _, _ in
                                        AudioManager.shared.playSFX(.ui)
                                    }
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        AudioManager.shared.playSFX(.ui)
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
                        AudioManager.shared.playSFX(.ui)
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
                    .fill(Color(red: 0.08, green: 0.14, blue: 0.18).opacity(0.97))
            )
            .padding(.horizontal, 24)
        }
        .onAppear {
            musicOn = AudioManager.shared.musicEnabled
            sfxOn = AudioManager.shared.sfxEnabled
            if musicOn { AudioManager.shared.playMusic() }
        }
    }

    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9).opacity(0.85))
                .tracking(0.6)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

            content()
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .tint(Color(red: 1.0, green: 0.55, blue: 0.25))
    }

    private func settingRow<C: View>(_ label: String, @ViewBuilder control: () -> C) -> some View {
        HStack {
            Text(label)
            Spacer()
            control().labelsHidden()
        }
        .padding(.vertical, 9)
    }

    private func settingDivider() -> some View {
        Divider()
            .overlay(Color.white.opacity(0.1))
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
