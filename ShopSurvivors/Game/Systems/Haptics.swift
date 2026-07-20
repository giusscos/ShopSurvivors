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

    static func shove() {
        guard isEnabled else { return }
        medium.impactOccurred(intensity: 0.7)
        // Re-prepare so the next impact does not stall the main thread.
        medium.prepare()
    }

    static func hit() {
        guard isEnabled else { return }
        light.impactOccurred(intensity: 0.45)
        light.prepare()
    }

    static func levelUp() {
        guard isEnabled else { return }
        heavy.impactOccurred(intensity: 0.9)
    }

    static func win() {
        guard isEnabled else { return }
        notify.notificationOccurred(.success)
    }

    static func lose() {
        guard isEnabled else { return }
        notify.notificationOccurred(.error)
    }

    static func ui() {
        guard isEnabled else { return }
        light.impactOccurred(intensity: 0.35)
    }
}
