import UIKit

@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notify = UINotificationFeedbackGenerator()

    static func prepare() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        notify.prepare()
    }

    static func shove() {
        medium.impactOccurred(intensity: 0.7)
    }

    static func hit() {
        light.impactOccurred(intensity: 0.45)
    }

    static func levelUp() {
        heavy.impactOccurred(intensity: 0.9)
    }

    static func win() {
        notify.notificationOccurred(.success)
    }

    static func lose() {
        notify.notificationOccurred(.error)
    }

    static func ui() {
        light.impactOccurred(intensity: 0.35)
    }
}
