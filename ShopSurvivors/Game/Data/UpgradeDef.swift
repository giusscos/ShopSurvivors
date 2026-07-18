import Foundation

enum UpgradeKind: String, CaseIterable, Identifiable {
    case unlockWeapon
    case weaponLevel
    case moveSpeed
    case couponCooldown
    case willpower
    case budgetRefill

    var id: String { rawValue }

    func title(weapon: WeaponKind? = nil) -> String {
        switch self {
        case .unlockWeapon: "New: \(weapon?.displayName ?? "Weapon")"
        case .weaponLevel: "Upgrade \(weapon?.displayName ?? "Weapon")"
        case .moveSpeed: "Sneaker Speed"
        case .couponCooldown: "Coupon Printer"
        case .willpower: "Companion Willpower"
        case .budgetRefill: "Rainy Day Fund"
        }
    }

    func blurb(weapon: WeaponKind? = nil) -> String {
        switch self {
        case .unlockWeapon: weapon?.blurb ?? "Unlock a new auto-weapon"
        case .weaponLevel: "Increase damage and fire rate"
        case .moveSpeed: "+12% move speed"
        case .couponCooldown: "−20% coupon cooldown"
        case .willpower: "Clerks drain 15% slower"
        case .budgetRefill: "Restore 12% of starting budget"
        }
    }
}

struct UpgradeOffer: Identifiable, Equatable {
    let id = UUID()
    let kind: UpgradeKind
    var weapon: WeaponKind?
}
