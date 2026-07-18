import SpriteKit

/// 3-frame walk cycle using `name_idle`, `name_walk1`, `name_walk2`.
final class WalkAnimator {
    private let textures: [SKTexture]
    private var frameIndex = 0
    private var timer: TimeInterval = 0
    private let frameDuration: TimeInterval = 0.14

    init(baseName: String) {
        let names = ["\(baseName)_idle", "\(baseName)_walk1", "\(baseName)_walk2"]
        var loaded: [SKTexture] = []
        for n in names {
            var t = SKTexture(imageNamed: n)
            if t.size().width < 1 {
                t = SKTexture(imageNamed: baseName)
            }
            t.filteringMode = .nearest
            loaded.append(t)
        }
        while loaded.count < 3 {
            loaded.append(loaded.last ?? SKTexture(imageNamed: baseName))
        }
        textures = loaded
    }

    func update(sprite: SKSpriteNode, moving: Bool, facingDX: CGFloat, dt: TimeInterval) {
        if facingDX < -0.15 {
            sprite.xScale = -1
        } else if facingDX > 0.15 {
            sprite.xScale = 1
        }

        // Keep name tags readable when the parent sprite faces left.
        let labelScale: CGFloat = sprite.xScale < 0 ? -1 : 1
        for case let label as SKLabelNode in sprite.children {
            label.xScale = labelScale
        }

        guard moving else {
            frameIndex = 0
            timer = 0
            sprite.texture = textures[0]
            return
        }

        timer += dt
        if timer >= frameDuration {
            timer = 0
            frameIndex = frameIndex == 1 ? 2 : 1
            sprite.texture = textures[frameIndex]
        }
    }
}
