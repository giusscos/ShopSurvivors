import SpriteKit

final class PlayerNode: SKSpriteNode {
    var facing: CGVector = CGVector(dx: 1, dy: 0)
    var baseSpeed: CGFloat = 160
    let walk = WalkAnimator(baseName: "player")

    init() {
        let tex = SKTexture(imageNamed: "player_idle")
        tex.filteringMode = .nearest
        super.init(texture: tex, color: .clear, size: CGSize(width: 36, height: 36))
        name = "player"
        zPosition = 20

        let tag = SKLabelNode(fontNamed: "Menlo-Bold")
        tag.text = "YOU"
        tag.fontSize = 9
        tag.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.95, alpha: 1)
        tag.verticalAlignmentMode = .bottom
        tag.position = CGPoint(x: 0, y: 20)
        tag.zPosition = 2
        addChild(tag)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
