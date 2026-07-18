import SwiftUI

struct ContentView: View {
    @StateObject private var session = GameSession()

    var body: some View {
        Group {
            switch session.screen {
            case .title:
                TitleView(session: session)
            case .levelSelect:
                LevelSelectView(session: session)
            case .playing(let storeId):
                if let store = StoreLevel.byId(storeId) {
                    GameContainerView(session: session, store: store)
                        .id(session.runID)
                } else {
                    LevelSelectView(session: session)
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
    }
}

#Preview {
    ContentView()
}
