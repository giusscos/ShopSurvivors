import SwiftUI

struct ContentView: View {
    @StateObject private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
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
