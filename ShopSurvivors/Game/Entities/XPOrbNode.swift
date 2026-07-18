import SpriteKit

final class XPOrbNode: SKSpriteNode {
    let amount: Int

    init(amount: Int) {
        self.amount = amount
        let tex = SKTexture(imageNamed: "xp_orb")
        tex.filteringMode = .nearest
        super.init(texture: tex, color: .clear, size: CGSize(width: 22, height: 22))
        name = "xpOrb"
        zPosition = 10

        physicsBody = SKPhysicsBody(circleOfRadius: 10)
        physicsBody?.affectedByGravity = false
        physicsBody?.categoryBitMask = PhysicsCategory.xpOrb
        physicsBody?.collisionBitMask = PhysicsCategory.none
        physicsBody?.contactTestBitMask = PhysicsCategory.player

        let tag = SKLabelNode(fontNamed: "Menlo-Bold")
        tag.text = "+\(amount) XP"
        tag.fontSize = 9
        tag.fontColor = SKColor(red: 0.3, green: 0.95, blue: 1.0, alpha: 1)
        tag.verticalAlignmentMode = .bottom
        tag.position = CGPoint(x: 0, y: 14)
        tag.zPosition = 2
        addChild(tag)

        run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.35),
            SKAction.scale(to: 1.0, duration: 0.35)
        ])))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
