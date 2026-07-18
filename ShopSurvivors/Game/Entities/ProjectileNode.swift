import SpriteKit

final class ProjectileNode: SKSpriteNode {
    let damage: CGFloat
    let weapon: WeaponKind
    var life: TimeInterval
    var pierceLeft: Int

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

        physicsBody = SKPhysicsBody(circleOfRadius: min(size.width, size.height) * 0.4)
        physicsBody?.affectedByGravity = false
        physicsBody?.allowsRotation = false
        physicsBody?.categoryBitMask = PhysicsCategory.projectile
        physicsBody?.collisionBitMask = PhysicsCategory.none
        physicsBody?.contactTestBitMask = PhysicsCategory.clerk

        // Short readable tag so projectiles aren't mystery blobs
        let short: String = switch weapon {
        case .priceTags: "TAG"
        case .receipts: "RCP"
        case .barcodeLaser: "LASER"
        case .shoppingBag: "BAG"
        }
        let tag = SKLabelNode(fontNamed: "Menlo-Bold")
        tag.text = short
        tag.fontSize = 8
        tag.fontColor = .white
        tag.verticalAlignmentMode = .center
        tag.horizontalAlignmentMode = .center
        tag.position = CGPoint(x: 0, y: size.height * 0.55 + 6)
        tag.zPosition = 2
        // Laser beam is large — skip cluttered label
        if weapon != .barcodeLaser {
            addChild(tag)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
