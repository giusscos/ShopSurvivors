import SpriteKit

final class ClerkNode: SKSpriteNode {
    let clerkType: ClerkType
    var hp: CGFloat
    var pitchCooldown: TimeInterval = 0
    var lureTarget: CGPoint?
    var lureTimeRemaining: TimeInterval = 0
    var knockbackVelocity: CGVector = .zero
    var facingDX: CGFloat = 1
    /// Set each frame by soft-separation when another clerk is within pack range.
    var hasPackNeighbor = false
    let walk: WalkAnimator
    private let nameTag: SKLabelNode

    init(type: ClerkType) {
        self.clerkType = type
        self.hp = type.maxHP
        self.walk = WalkAnimator(baseName: type.spriteName)
        let tex = SKTexture(imageNamed: "\(type.spriteName)_idle")
        tex.filteringMode = .nearest

        let tag = SKLabelNode(fontNamed: "Menlo-Bold")
        tag.text = type.displayName.uppercased()
        tag.fontSize = 7
        tag.fontColor = SKColor(white: 1, alpha: 0.75)
        tag.verticalAlignmentMode = .bottom
        tag.position = CGPoint(x: 0, y: 16)
        tag.zPosition = 2
        self.nameTag = tag

        super.init(texture: tex, color: .clear, size: CGSize(width: 32, height: 32))
        name = "clerk"
        zPosition = 15
        // No physics body — movement and separation are manual (avoids clerk pile-up solver cost).
        addChild(tag)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyDamage(_ amount: CGFloat, knockback: CGVector, flash: Bool) {
        hp -= amount
        knockbackVelocity = knockback
        guard flash else { return }
        // Instant tint; GameScene decays colorBlendFactor (no SKAction churn).
        color = .white
        colorBlendFactor = 0.75
    }

    func setNameTagHidden(_ hidden: Bool) {
        nameTag.isHidden = hidden
    }

    func syncNameTagFacing() {
        guard !nameTag.isHidden else { return }
        nameTag.xScale = xScale < 0 ? -1 : 1
    }
}
