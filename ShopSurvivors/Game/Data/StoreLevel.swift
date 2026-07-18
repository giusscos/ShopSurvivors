import Foundation
import SwiftUI

struct StoreLevel: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let duration: TimeInterval
    let startingBudget: CGFloat
    let floorColor: Color
    let accentColor: Color
    let clerkWeights: [ClerkType: Double]
    let startingWeapon: WeaponKind
    /// Seconds between spawns at t=0, then ramps down.
    let spawnIntervalStart: TimeInterval
    let spawnIntervalEnd: TimeInterval
    let maxClerks: Int

    func spawnInterval(at elapsed: TimeInterval) -> TimeInterval {
        let t = min(1, elapsed / duration)
        return spawnIntervalStart + (spawnIntervalEnd - spawnIntervalStart) * t
    }

    func weightedClerk() -> ClerkType {
        let total = clerkWeights.values.reduce(0, +)
        var r = Double.random(in: 0..<total)
        for (type, weight) in clerkWeights {
            r -= weight
            if r <= 0 { return type }
        }
        return .pitcher
    }

    static let all: [StoreLevel] = [
        StoreLevel(
            id: "electronics",
            name: "Electronics Megamart",
            subtitle: "Warranty pushers inbound",
            duration: 120,
            startingBudget: 120,
            floorColor: Color(red: 0.12, green: 0.22, blue: 0.32),
            accentColor: Color(red: 0.25, green: 0.72, blue: 0.85),
            clerkWeights: [
                .pitcher: 0.45,
                .closer: 0.25,
                .sprinter: 0.15,
                .upseller: 0.15
            ],
            startingWeapon: .priceTags,
            spawnIntervalStart: 1.6,
            spawnIntervalEnd: 0.55,
            maxClerks: 40
        ),
        StoreLevel(
            id: "fashion",
            name: "Fashion Boutique",
            subtitle: "It looks amazing on you",
            duration: 150,
            startingBudget: 100,
            floorColor: Color(red: 0.28, green: 0.16, blue: 0.18),
            accentColor: Color(red: 0.95, green: 0.55, blue: 0.35),
            clerkWeights: [
                .pitcher: 0.35,
                .closer: 0.35,
                .sprinter: 0.1,
                .upseller: 0.2
            ],
            startingWeapon: .receipts,
            spawnIntervalStart: 1.5,
            spawnIntervalEnd: 0.5,
            maxClerks: 45
        ),
        StoreLevel(
            id: "grocery",
            name: "Grocery Warehouse",
            subtitle: "Free samples aren't free",
            duration: 180,
            startingBudget: 80,
            floorColor: Color(red: 0.16, green: 0.2, blue: 0.14),
            accentColor: Color(red: 0.55, green: 0.78, blue: 0.35),
            clerkWeights: [
                .pitcher: 0.3,
                .closer: 0.15,
                .sprinter: 0.25,
                .upseller: 0.3
            ],
            startingWeapon: .shoppingBag,
            spawnIntervalStart: 1.4,
            spawnIntervalEnd: 0.45,
            maxClerks: 50
        )
    ]

    static func byId(_ id: String) -> StoreLevel? {
        all.first { $0.id == id }
    }
}
