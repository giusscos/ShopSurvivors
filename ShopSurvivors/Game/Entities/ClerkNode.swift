import SpriteKit

final class ClerkNode: SKSpriteNode {
    let clerkType: ClerkType
    var hp: CGFloat
    var pitchCooldown: TimeInterval = 0
    var lureTarget: CGPoint?
    var lureTimeRemaining: TimeInterval = 0
    var knockbackVelocity: CGVector = .zero
    var facingDX: CGFloat = 1
    let walk: WalkAnimator

    init(type: ClerkType) {
        self.clerkType = type
        self.hp = type.maxHP
        self.walk = WalkAnimator(baseName: type.spriteName)
        let tex = SKTexture(imageNamed: "\(type.spriteName)_idle")
        tex.filteringMode = .nearest
        super.init(texture: tex, color: .clear, size: CGSize(width: 32, height: 32))
        name = "clerk"
        zPosition = 15

        physicsBody = SKPhysicsBody(circleOfRadius: 12)
        physicsBody?.affectedByGravity = false
        physicsBody?.allowsRotation = false
        physicsBody?.linearDamping = 6
        physicsBody?.categoryBitMask = PhysicsCategory.clerk
        physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.clerk
        physicsBody?.contactTestBitMask = PhysicsCategory.projectile

        let tag = SKLabelNode(fontNamed: "Menlo-Bold")
        tag.text = type.displayName.uppercased()
        tag.fontSize = 7
        tag.fontColor = SKColor(white: 1, alpha: 0.75)
        tag.verticalAlignmentMode = .bottom
        tag.position = CGPoint(x: 0, y: 16)
        tag.zPosition = 2
        addChild(tag)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyDamage(_ amount: CGFloat, knockback: CGVector) {
        hp -= amount
        knockbackVelocity = knockback
        run(SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
        ]))
    }
}
