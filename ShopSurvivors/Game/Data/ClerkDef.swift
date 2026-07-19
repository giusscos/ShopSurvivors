import Foundation
import CoreGraphics

enum ClerkType: String, CaseIterable, Identifiable {
    case pitcher
    case closer
    case sprinter
    case upseller

    var id: String { rawValue }

    private struct Stats {
        let displayName: String
        let spriteName: String
        let moveSpeed: CGFloat
        let maxHP: CGFloat
        /// Budget drained per second while in pitch range of companion.
        let drainPerSecond: CGFloat
        let pitchRadius: CGFloat
        let xpReward: Int
        let pitchLines: [String]
    }

    private static let table: [ClerkType: Stats] = [
        .pitcher:  Stats(displayName: "Pitcher",  spriteName: "clerk_pitcher",  moveSpeed: 70,  maxHP: 30, drainPerSecond: 4,   pitchRadius: 48, xpReward: 3, pitchLines: ["50% off!", "Limited time!", "Just looking?"]),
        .closer:   Stats(displayName: "Closer",   spriteName: "clerk_closer",   moveSpeed: 45,  maxHP: 55, drainPerSecond: 9,   pitchRadius: 42, xpReward: 6, pitchLines: ["Extended warranty!", "Last one!", "Sign here!"]),
        .sprinter: Stats(displayName: "Sprinter", spriteName: "clerk_sprinter", moveSpeed: 110, maxHP: 18, drainPerSecond: 2.5, pitchRadius: 40, xpReward: 2, pitchLines: ["Excuse me!", "Flash sale!", "Wait!"]),
        .upseller: Stats(displayName: "Upseller", spriteName: "clerk_upseller", moveSpeed: 60,  maxHP: 40, drainPerSecond: 5,   pitchRadius: 55, xpReward: 5, pitchLines: ["Bundle deal!", "Buy 2 get 1!", "Members save more!"]),
    ]

    private var stats: Stats { Self.table[self]! }

    var displayName: String { stats.displayName }
    var spriteName: String { stats.spriteName }
    var moveSpeed: CGFloat { stats.moveSpeed }
    var maxHP: CGFloat { stats.maxHP }
    var drainPerSecond: CGFloat { stats.drainPerSecond }
    var pitchRadius: CGFloat { stats.pitchRadius }
    var xpReward: Int { stats.xpReward }
    var pitchLines: [String] { stats.pitchLines }

    /// Extra drain multiplier when another clerk is nearby (upseller only).
    var packBonus: CGFloat {
        self == .upseller ? 1.6 : 1.0
    }
}
