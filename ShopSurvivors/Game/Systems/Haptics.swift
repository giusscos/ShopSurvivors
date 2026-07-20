import UIKit

@MainActor
enum Haptics {
    static var isEnabled = true

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notify = UINotificationFeedbackGenerator()

    static func prepare() {
        guard isEnabled else { return }
        light.prepare()
        medium.prepare()
        heavy.prepare()
        notify.prepare()
    }

    /// Fire after the current SpriteKit frame so `impactOccurred` cannot stall `update(_:)`.
    private static func fire(_ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    static func shove() {
        guard isEnabled else { return }
        fire { medium.impactOccurred(intensity: 0.7) }
    }

    static func hit() {
        guard isEnabled else { return }
        fire { light.impactOccurred(intensity: 0.45) }
    }

    static func levelUp() {
        guard isEnabled else { return }
        fire { heavy.impactOccurred(intensity: 0.9) }
    }

    static func win() {
        guard isEnabled else { return }
        fire { notify.notificationOccurred(.success) }
    }

    static func lose() {
        guard isEnabled else { return }
        fire { notify.notificationOccurred(.error) }
    }

    static func ui() {
        guard isEnabled else { return }
        fire { light.impactOccurred(intensity: 0.35) }
    }
}
