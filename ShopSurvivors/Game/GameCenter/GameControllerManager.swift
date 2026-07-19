import Combine
import GameController

@MainActor
final class GameControllerManager: ObservableObject {
    static let shared = GameControllerManager()

    @Published var isConnected = false

    private var monitorsStarted = false

    private init() {}

    func startMonitoring() {
        guard !monitorsStarted else { return }
        monitorsStarted = true

        isConnected = GCController.controllers().first?.extendedGamepad != nil

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isConnected = GCController.controllers().first?.extendedGamepad != nil
            }
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isConnected = GCController.controllers().first?.extendedGamepad != nil
            }
        }
    }

    // Call each game-loop frame only when isConnected is true.
    func pollMovement(into session: GameSession) {
        guard let pad = GCController.controllers().first?.extendedGamepad else { return }
        let rawX = pad.leftThumbstick.xAxis.value
        let rawY = pad.leftThumbstick.yAxis.value
        let deadzone: Float = 0.15
        let x = abs(rawX) > deadzone ? CGFloat(rawX) : 0
        let y = abs(rawY) > deadzone ? CGFloat(rawY) : 0
        session.moveVector = CGVector(dx: x, dy: y)
    }
}
