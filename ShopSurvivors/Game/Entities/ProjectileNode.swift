import SpriteKit

final class ProjectileNode: SKSpriteNode {
    let damage: CGFloat
    let weapon: WeaponKind
    var life: TimeInterval
    var pierceLeft: Int
    /// Manual velocity for receipts (no physics body).
    var velocity: CGVector = .zero

    init(weapon: WeaponKind, damage: CGFloat, life: TimeInterval = 1.2, pierce: Int = 1) {
        self.weapon = weapon
        self.damage = damage
        self.life = life
        self.pierceLeft = pierce
        let tex = SKTexture(imageNamed: weapon.spriteName)
        tex.filteringMode = .nearest
        let size: CGSize = switch weapon {
        case .priceTags: CGSize(width: 20, height: 20)
        case .receipts: CGSize(width: 22, height: 16)
        case .barcodeLaser: CGSize(width: 48, height: 10)
        case .shoppingBag: CGSize(width: 28, height: 28)
        }
        super.init(texture: tex, color: .clear, size: size)
        name = "projectile"
        zPosition = 25
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
