import SpriteKit

final class CouponNode: SKSpriteNode {
    var life: TimeInterval = 4.5
    let lureRadius: CGFloat = 140

    init() {
        let tex = SKTexture(imageNamed: "coupon")
        tex.filteringMode = .nearest
        super.init(texture: tex, color: .clear, size: CGSize(width: 32, height: 26))
        name = "coupon"
        zPosition = 12

        physicsBody = SKPhysicsBody(circleOfRadius: 10)
        physicsBody?.affectedByGravity = false
        physicsBody?.categoryBitMask = PhysicsCategory.coupon
        physicsBody?.collisionBitMask = PhysicsCategory.none
        physicsBody?.contactTestBitMask = PhysicsCategory.none

        let ring = SKShapeNode(circleOfRadius: lureRadius)
        ring.strokeColor = SKColor(red: 1, green: 0.75, blue: 0.2, alpha: 0.45)
        ring.lineWidth = 2
        ring.fillColor = SKColor(red: 1, green: 0.8, blue: 0.2, alpha: 0.08)
        ring.zPosition = -1
        ring.name = "lureRing"
        addChild(ring)

        let tag = SKLabelNode(fontNamed: "Menlo-Bold")
        tag.text = "LURE"
        tag.fontSize = 11
        tag.fontColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        tag.verticalAlignmentMode = .bottom
        tag.position = CGPoint(x: 0, y: 18)
        tag.zPosition = 2
        addChild(tag)

        let hint = SKLabelNode(fontNamed: "Menlo-Bold")
        hint.text = "clerks go here"
        hint.fontSize = 8
        hint.fontColor = SKColor(white: 1, alpha: 0.7)
        hint.verticalAlignmentMode = .top
        hint.position = CGPoint(x: 0, y: -18)
        hint.zPosition = 2
        addChild(hint)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
