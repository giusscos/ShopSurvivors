import SwiftUI

struct ContentView: View {
    @State private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                switch session.screen {
                case .intro:
                    LoreIntroView(session: session)
                case .title:
                    TitleView(session: session)
                case .howToPlay:
                    HowToPlayView(session: session)
                case .settings:
                    SettingsView(session: session)
                case .benchmark:
                    BenchmarkView(session: session)
                case .levelSelect:
                    MallHubView(session: session)
                case .playing(let storeId):
                    if let store = StoreLevel.byId(storeId) {
                        GameContainerView(session: session, store: store)
                            .id(session.runID)
                    } else {
                        MallHubView(session: session)
                    }
                }
            }

            if let store = session.pendingStoreForDifficulty {
                DifficultyPickerView(store: store) { tier in
                    session.startStore(store.withDifficulty(tier))
                } onCancel: {
                    session.pendingStoreForDifficulty = nil
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.18), value: session.pendingStoreForDifficulty?.id)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .task {
            Haptics.prepare()
            GameCenterManager.shared.authenticate()
            GameControllerManager.shared.startMonitoring()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                session.pauseForBackground()
            }
        }
    }
}

#Preview {
    ContentView()
}
