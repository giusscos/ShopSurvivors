import SpriteKit

/// 3-frame walk cycle using `name_idle`, `name_walk1`, `name_walk2`.
final class WalkAnimator {
    private static var textureCache: [String: [SKTexture]] = [:]

    private let textures: [SKTexture]
    private var frameIndex = 0
    private var timer: TimeInterval = 0
    private let frameDuration: TimeInterval = 0.18
    private var lastFacingSign: CGFloat = 0

    init(baseName: String) {
        if let cached = Self.textureCache[baseName] {
            textures = cached
            return
        }

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
        Self.textureCache[baseName] = loaded
        textures = loaded
    }

    func update(sprite: SKSpriteNode, moving: Bool, facingDX: CGFloat, dt: TimeInterval) {
        let facingSign: CGFloat
        if facingDX < -0.15 {
            facingSign = -1
        } else if facingDX > 0.15 {
            facingSign = 1
        } else {
            facingSign = lastFacingSign == 0 ? 1 : lastFacingSign
        }

        if facingSign != lastFacingSign {
            lastFacingSign = facingSign
            sprite.xScale = facingSign
            if let clerk = sprite as? ClerkNode {
                clerk.syncNameTagFacing()
            } else {
                let labelScale: CGFloat = facingSign < 0 ? -1 : 1
                for case let label as SKLabelNode in sprite.children {
                    label.xScale = labelScale
                }
            }
        }

        guard moving else {
            if frameIndex != 0 {
                frameIndex = 0
                sprite.texture = textures[0]
            }
            timer = 0
            return
        }

        timer += dt
        if timer >= frameDuration {
            timer -= frameDuration
            let next = frameIndex == 1 ? 2 : 1
            if next != frameIndex {
                frameIndex = next
                sprite.texture = textures[frameIndex]
            }
        }
    }
}
