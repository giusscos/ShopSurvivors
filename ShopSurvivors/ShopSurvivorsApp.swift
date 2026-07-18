import SwiftUI

@main
struct ShopSurvivorsApp: App {
    init() {
        AudioManager.shared.setup()
        AudioManager.shared.playMusic()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .persistentSystemOverlays(.hidden)
        }
    }
}
