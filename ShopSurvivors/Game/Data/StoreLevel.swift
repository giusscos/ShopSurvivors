import Foundation
import SwiftUI

enum DifficultyTier: Int, CaseIterable, Identifiable {
    case easy, normal, hard
    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .easy:   "EASY"
        case .normal: "NORMAL"
        case .hard:   "HARD"
        }
    }

    var blurb: String {
        switch self {
        case .easy:   "More budget · fewer clerks"
        case .normal: "Standard challenge"
        case .hard:   "Less budget · relentless spawn"
        }
    }

    var accentColor: Color {
        switch self {
        case .easy:   Color(red: 0.35, green: 0.9, blue: 0.55)
        case .normal: Color(red: 0.2, green: 0.85, blue: 0.9)
        case .hard:   Color(red: 1.0, green: 0.4, blue: 0.35)
        }
    }
}

struct StoreLevel: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    /// Campaign duration in seconds. `0` means endless (no timed win).
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
    /// Shelf count hint for arena variety.
    let shelfCount: Int
    var isEndless: Bool { duration <= 0 }

    /// Progress used for spawn ramp. Endless uses a soft cap so difficulty keeps climbing.
    func difficultyProgress(elapsed: TimeInterval) -> CGFloat {
        if isEndless {
            return min(1.25, CGFloat(elapsed / 180))
        }
        return min(1, CGFloat(elapsed / max(1, duration)))
    }

    func spawnInterval(at elapsed: TimeInterval) -> TimeInterval {
        let t = Double(min(1, difficultyProgress(elapsed: elapsed)))
        let interval = spawnIntervalStart + (spawnIntervalEnd - spawnIntervalStart) * t
        if isEndless, elapsed > 180 {
            let extra = min(0.2, (elapsed - 180) / 600)
            return max(0.28, interval - extra)
        }
        return interval
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
            maxClerks: 40,
            shelfCount: 12
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
            maxClerks: 45,
            shelfCount: 16
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
            maxClerks: 50,
            shelfCount: 20
        )
    ]

    /// Survive until the wallet is wiped. Score = seconds lasted.
    static let endless = StoreLevel(
        id: "endless",
        name: "Midnight Mall",
        subtitle: "No closing time — last as long as you can",
        duration: 0,
        startingBudget: 100,
        floorColor: Color(red: 0.1, green: 0.08, blue: 0.18),
        accentColor: Color(red: 0.75, green: 0.45, blue: 0.95),
        clerkWeights: [
            .pitcher: 0.25,
            .closer: 0.25,
            .sprinter: 0.25,
            .upseller: 0.25
        ],
        startingWeapon: .priceTags,
        spawnIntervalStart: 1.35,
        spawnIntervalEnd: 0.4,
        maxClerks: 60,
        shelfCount: 18
    )

    static func byId(_ id: String) -> StoreLevel? {
        if id == endless.id { return endless }
        if let store = all.first(where: { $0.id == id }) { return store }
        let base = baseId(from: id)
        guard let baseStore = all.first(where: { $0.id == base }) else { return nil }
        if id.hasSuffix("_easy") { return baseStore.withDifficulty(.easy) }
        if id.hasSuffix("_hard") { return baseStore.withDifficulty(.hard) }
        return nil
    }

    /// Campaign stores plus Endless once the mall is cleared.
    static func hubStores(mallCleared: Bool) -> [StoreLevel] {
        mallCleared ? all + [endless] : all
    }

    var baseId: String {
        for suffix in ["_easy", "_hard"] {
            if id.hasSuffix(suffix) { return String(id.dropLast(suffix.count)) }
        }
        return id
    }

    static func baseId(from id: String) -> String {
        for suffix in ["_easy", "_hard"] {
            if id.hasSuffix(suffix) { return String(id.dropLast(suffix.count)) }
        }
        return id
    }

    func withDifficulty(_ tier: DifficultyTier) -> StoreLevel {
        switch tier {
        case .easy:
            return StoreLevel(
                id: id + "_easy", name: name, subtitle: subtitle,
                duration: duration > 0 ? duration * 0.8 : 0,
                startingBudget: startingBudget * 1.4,
                floorColor: floorColor, accentColor: accentColor,
                clerkWeights: clerkWeights, startingWeapon: startingWeapon,
                spawnIntervalStart: spawnIntervalStart * 1.5,
                spawnIntervalEnd: spawnIntervalEnd * 1.5,
                maxClerks: max(15, maxClerks - 12),
                shelfCount: shelfCount
            )
        case .normal:
            return self
        case .hard:
            return StoreLevel(
                id: id + "_hard", name: name, subtitle: subtitle,
                duration: duration > 0 ? duration * 1.3 : 0,
                startingBudget: startingBudget * 0.65,
                floorColor: floorColor, accentColor: accentColor,
                clerkWeights: clerkWeights, startingWeapon: startingWeapon,
                spawnIntervalStart: spawnIntervalStart * 0.75,
                spawnIntervalEnd: spawnIntervalEnd * 0.75,
                maxClerks: maxClerks + 15,
                shelfCount: shelfCount
            )
        }
    }
}
