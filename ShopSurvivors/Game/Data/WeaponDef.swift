import Foundation
import CoreGraphics

enum WeaponKind: String, CaseIterable, Identifiable, Codable {
    case priceTags
    case receipts
    case barcodeLaser
    case shoppingBag

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .priceTags: "Price Aura"
        case .receipts: "Receipts"
        case .barcodeLaser: "Barcode Laser"
        case .shoppingBag: "Shopping Bag"
        }
    }

    var shortLabel: String {
        switch self {
        case .priceTags: "AURA"
        case .receipts: "RCP"
        case .barcodeLaser: "LASER"
        case .shoppingBag: "BAG"
        }
    }

    var blurb: String {
        switch self {
        case .priceTags: "Small damage ring around you"
        case .receipts: "Fire paper projectiles at nearest clerks"
        case .barcodeLaser: "Short-range barcode scan cone"
        case .shoppingBag: "Pulse knockback around you"
        }
    }

    var spriteName: String {
        switch self {
        case .priceTags: "proj_pricetag"
        case .receipts: "proj_receipt"
        case .barcodeLaser: "proj_laser"
        case .shoppingBag: "proj_bag"
        }
    }

    func damage(level: Int) -> CGFloat {
        let base: CGFloat = switch self {
        case .priceTags: 8
        case .receipts: 12
        case .barcodeLaser: 6
        case .shoppingBag: 10
        }
        return base * (1 + 0.25 * CGFloat(level - 1))
    }

    func cooldown(level: Int) -> TimeInterval {
        let base: TimeInterval = switch self {
        case .priceTags: 0.35
        case .receipts: 0.55
        case .barcodeLaser: 1.4
        case .shoppingBag: 2.2
        }
        return max(0.12, base * pow(0.92, Double(level - 1)))
    }

    /// Close-range aura (Price Aura). Kept well below LURE's 140 radius.
    func auraRadius(level: Int) -> CGFloat {
        42 + CGFloat(level - 1) * 5
    }

    /// Facing cone length for Barcode Laser (medium-short; beyond aura, not a long beam).
    func laserRange(level: Int) -> CGFloat {
        120 + CGFloat(level - 1) * 8
    }

    /// Half-angle in radians (~40° base, slight widen per level).
    func laserHalfAngle(level: Int) -> CGFloat {
        let degrees = 40 + CGFloat(level - 1) * 2
        return degrees * (.pi / 180)
    }
}

struct OwnedWeapon: Identifiable, Equatable {
    var kind: WeaponKind
    var level: Int

    var id: String { kind.rawValue }
}
