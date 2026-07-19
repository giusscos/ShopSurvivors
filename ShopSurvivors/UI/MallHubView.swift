import SwiftUI
import SpriteKit

struct MallHubView: View {
    @ObservedObject var session: GameSession
    @ObservedObject private var gc = GameCenterManager.shared
    @ObservedObject private var controllerManager = GameControllerManager.shared
    @State private var scene: StoreHubScene
    @State private var joystickVector: CGVector = .zero

    init(session: GameSession) {
        self.session = session
        let s = StoreHubScene(size: CGSize(width: 844, height: 390))
        s.scaleMode = .resizeFill
        s.configure(session: session)
        _scene = State(initialValue: s)
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 120, options: [.allowsTransparency])
                .ignoresSafeArea()
                .id(session.unlockedStoreIndex)

            VStack {
                HStack {
                    Button {
                        AudioManager.shared.playSFX(.ui)
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
                        if gc.isAuthenticated {
                            Button {
                                AudioManager.shared.playSFX(.ui)
                                GameCenterManager.shared.showDashboard()
                            } label: {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        Button {
                            AudioManager.shared.playSFX(.ui)
                            session.goSettings()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                HStack(alignment: .bottom) {
                    if !controllerManager.isConnected {
                        VirtualJoystick(vector: $joystickVector)
                            .padding(.leading, 28)
                            .padding(.bottom, 16)
                    }
                    Spacer()
                    Text("Walk into a door to shop")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            joystickVector = .zero
            session.moveVector = .zero
            AudioManager.shared.playMusic(forceRestart: false)
        }
        .onChange(of: joystickVector.dx) { _, _ in
            session.moveVector = joystickVector
        }
        .onChange(of: joystickVector.dy) { _, _ in
            session.moveVector = joystickVector
        }
        .onChange(of: session.unlockedStoreIndex) { _, _ in
            // Rebuild hub so newly unlocked doors open.
            let s = StoreHubScene(size: CGSize(width: 844, height: 390))
            s.scaleMode = .resizeFill
            s.configure(session: session)
            scene = s
        }
    }
}
