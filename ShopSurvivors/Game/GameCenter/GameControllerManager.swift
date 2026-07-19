import Combine
import GameController

@MainActor
final class GameControllerManager: ObservableObject {
    static let shared = GameControllerManager()

    @Published var isConnected = false
    @Published var keyboardActive = false

    private var monitorsStarted = false

    private init() {}

    func startMonitoring() {
        guard !monitorsStarted else { return }
        monitorsStarted = true

        isConnected = GameControllerManager.physicalControllerConnected()

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isConnected = GameControllerManager.physicalControllerConnected()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isConnected = GameControllerManager.physicalControllerConnected()
            }
        }
    }

    private static func physicalControllerConnected() -> Bool {
        GCController.controllers().contains {
            guard $0.extendedGamepad != nil else { return false }
            let name = ($0.vendorName ?? "").lowercased()
            return !name.contains("keyboard") && !name.contains("virtual")
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

    // Call each game-loop frame when GCKeyboard.coalesced is non-nil.
    // Returns true if any movement key is currently held.
    @discardableResult
    func pollKeyboard(into session: GameSession) -> Bool {
        guard let kb = GCKeyboard.coalesced?.keyboardInput else {
            if keyboardActive { keyboardActive = false }
            return false
        }
        let left  = (kb.button(forKeyCode: .leftArrow)?.isPressed  ?? false)
                 || (kb.button(forKeyCode: .keyA)?.isPressed       ?? false)
        let right = (kb.button(forKeyCode: .rightArrow)?.isPressed ?? false)
                 || (kb.button(forKeyCode: .keyD)?.isPressed       ?? false)
        let up    = (kb.button(forKeyCode: .upArrow)?.isPressed    ?? false)
                 || (kb.button(forKeyCode: .keyW)?.isPressed       ?? false)
        let down  = (kb.button(forKeyCode: .downArrow)?.isPressed  ?? false)
                 || (kb.button(forKeyCode: .keyS)?.isPressed       ?? false)
        var dx: CGFloat = right ? 1 : (left ? -1 : 0)
        var dy: CGFloat = up    ? 1 : (down ? -1 : 0)
        let active = dx != 0 || dy != 0
        if active {
            let len = hypot(dx, dy)
            dx /= len; dy /= len
            session.moveVector = CGVector(dx: dx, dy: dy)
        }
        if keyboardActive != active {
            keyboardActive = active
            if !active { session.moveVector = .zero }
        }
        return active
    }
}
