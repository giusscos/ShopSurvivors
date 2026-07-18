import SpriteKit

enum PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 0b1
    static let companion: UInt32 = 0b10
    static let clerk: UInt32 = 0b100
    static let projectile: UInt32 = 0b1000
    static let xpOrb: UInt32 = 0b10000
    static let coupon: UInt32 = 0b100000
    static let wall: UInt32 = 0b1000000
}
