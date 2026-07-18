import Foundation
import CoreGraphics

enum ClerkType: String, CaseIterable, Identifiable {
    case pitcher
    case closer
    case sprinter
    case upseller

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pitcher: "Pitcher"
        case .closer: "Closer"
        case .sprinter: "Sprinter"
        case .upseller: "Upseller"
        }
    }

    var spriteName: String {
        switch self {
        case .pitcher: "clerk_pitcher"
        case .closer: "clerk_closer"
        case .sprinter: "clerk_sprinter"
        case .upseller: "clerk_upseller"
        }
    }

    var moveSpeed: CGFloat {
        switch self {
        case .pitcher: 70
        case .closer: 45
        case .sprinter: 110
        case .upseller: 60
        }
    }

    var maxHP: CGFloat {
        switch self {
        case .pitcher: 30
        case .closer: 55
        case .sprinter: 18
        case .upseller: 40
        }
    }

    /// Budget drained per second while in pitch range of companion.
    var drainPerSecond: CGFloat {
        switch self {
        case .pitcher: 4
        case .closer: 9
        case .sprinter: 2.5
        case .upseller: 5
        }
    }

    var pitchRadius: CGFloat {
        switch self {
        case .pitcher: 48
        case .closer: 42
        case .sprinter: 40
        case .upseller: 55
        }
    }

    var xpReward: Int {
        switch self {
        case .pitcher: 3
        case .closer: 6
        case .sprinter: 2
        case .upseller: 5
        }
    }

    var pitchLines: [String] {
        switch self {
        case .pitcher:
            ["50% off!", "Limited time!", "Just looking?"]
        case .closer:
            ["Extended warranty!", "Last one!", "Sign here!"]
        case .sprinter:
            ["Excuse me!", "Flash sale!", "Wait!"]
        case .upseller:
            ["Bundle deal!", "Buy 2 get 1!", "Members save more!"]
        }
    }

    /// Extra drain multiplier when another clerk is nearby (upseller only).
    var packBonus: CGFloat {
        self == .upseller ? 1.6 : 1.0
    }
}
