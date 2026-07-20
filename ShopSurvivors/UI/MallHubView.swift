import SwiftUI
import SpriteKit

struct MallHubView: View {
    var session: GameSession
    @State private var scene: StoreHubScene
    @State private var joystickVector: CGVector = .zero
    /// Remounts the joystick to cancel any in-progress drag when the picker opens/closes.
    @State private var joystickEpoch = 0

    private var isDifficultyPickerOpen: Bool {
        session.pendingStoreForDifficulty != nil
    }

    init(session: GameSession) {
        self.session = session
        let s = StoreHubScene(size: CGSize(width: 844, height: 390))
        s.scaleMode = .resizeFill
        s.configure(session: session)
        _scene = State(initialValue: s)
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: UIScreen.main.maximumFramesPerSecond)
                .ignoresSafeArea()
                .id("\(session.unlockedStoreIndex)-\(session.mallCleared)-\(session.bestScoresRevision)")

            VStack {
                HStack {
                    HStack(spacing: 8) {
                        Button {
                            AudioManager.shared.playSFX(.ui)
                            Haptics.ui()
                            session.goTitle()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        AudioMuteButtons(size: 36, cornerRadius: 8)
                    }

                    Spacer()

                    Text("MALL CORRIDOR")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            AudioManager.shared.playSFX(.ui)
                            Haptics.ui()
                            _ = GameCenterManager.shared.showDashboard()
                        } label: {
                            Image(systemName: GameCenterManager.shared.isAuthenticated ? "trophy.fill" : "trophy")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .accessibilityLabel("Game Center")
                        .accessibilityHint("Opens leaderboards and achievements")
                        Button {
                            AudioManager.shared.playSFX(.ui)
                            Haptics.ui()
                            session.goSettings()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if let msg = GameCenterManager.shared.statusMessage, !GameCenterManager.shared.isAuthenticated {
                    Text(msg)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                }

                Spacer()

                HStack(alignment: .bottom) {
                    if !GameControllerManager.shared.isConnected && !GameControllerManager.shared.keyboardActive, !session.joystickOnRight {
                        mallJoystick
                    }
                    if session.joystickOnRight {
                        Text(session.mallCleared
                             ? "Walk into a door — Midnight Mall is open"
                             : "Walk into a door to shop")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.leading, 24)
                            .padding(.bottom, 24)
                        Spacer()
                        if !GameControllerManager.shared.isConnected && !GameControllerManager.shared.keyboardActive {
                            mallJoystick
                        }
                    } else {
                        Spacer()
                        Text(session.mallCleared
                             ? "Walk into a door — Midnight Mall is open"
                             : "Walk into a door to shop")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .onAppear {
            joystickVector = .zero
            session.moveVector = .zero
            AudioManager.shared.playMusic(forceRestart: false)
        }
        .onChange(of: joystickVector.dx) { _, _ in
            guard !isDifficultyPickerOpen else { return }
            session.moveVector = joystickVector
        }
        .onChange(of: joystickVector.dy) { _, _ in
            guard !isDifficultyPickerOpen else { return }
            session.moveVector = joystickVector
        }
        .onChange(of: session.pendingStoreForDifficulty) { _, _ in
            joystickVector = .zero
            session.moveVector = .zero
            joystickEpoch += 1
        }
        .onChange(of: session.unlockedStoreIndex) { _, _ in
            rebuildScene()
        }
        .onChange(of: session.mallCleared) { _, _ in
            rebuildScene()
        }
        .onChange(of: session.bestScoresRevision) { _, _ in
            rebuildScene()
        }
    }

    private func rebuildScene() {
        let s = StoreHubScene(size: CGSize(width: 844, height: 390))
        s.scaleMode = .resizeFill
        s.configure(session: session)
        scene = s
    }

    private var mallJoystick: some View {
        VirtualJoystick(
            vector: $joystickVector,
            size: session.joystickSize,
            locked: isDifficultyPickerOpen
        )
        .id(joystickEpoch)
        .padding(session.joystickOnRight ? .trailing : .leading, 28)
        .padding(.bottom, 16)
        .opacity(session.joystickOpacity)
    }
}
