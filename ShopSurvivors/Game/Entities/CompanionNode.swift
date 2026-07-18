import SpriteKit

final class CompanionNode: SKSpriteNode {
    var browseTarget: CGPoint?
    var browsePause: TimeInterval = 0
    var facingDX: CGFloat = 1
    let walk = WalkAnimator(baseName: "companion")
    let browseSpeed: CGFloat = 55

    init() {
        let tex = SKTexture(imageNamed: "companion_idle")
        tex.filteringMode = .nearest
        super.init(texture: tex, color: .clear, size: CGSize(width: 34, height: 34))
        name = "companion"
        zPosition = 18

        physicsBody = SKPhysicsBody(circleOfRadius: 13)
        physicsBody?.affectedByGravity = false
        physicsBody?.allowsRotation = false
        physicsBody?.linearDamping = 10
        physicsBody?.categoryBitMask = PhysicsCategory.companion
        physicsBody?.collisionBitMask = PhysicsCategory.wall
        physicsBody?.contactTestBitMask = PhysicsCategory.none

        let tag = SKLabelNode(fontNamed: "Menlo-Bold")
        tag.text = "FRIEND"
        tag.fontSize = 9
        tag.fontColor = SKColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 1)
        tag.verticalAlignmentMode = .bottom
        tag.position = CGPoint(x: 0, y: 20)
        tag.zPosition = 2
        addChild(tag)

        let status = SKLabelNode(fontNamed: "Menlo-Bold")
        status.name = "status"
        status.text = "shopping…"
        status.fontSize = 8
        status.fontColor = .white
        status.verticalAlignmentMode = .top
        status.position = CGPoint(x: 0, y: -20)
        status.zPosition = 2
        addChild(status)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setStatus(_ text: String) {
        (childNode(withName: "status") as? SKLabelNode)?.text = text
    }
}
