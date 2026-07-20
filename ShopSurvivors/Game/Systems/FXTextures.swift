import SpriteKit
import UIKit

enum FXTextures {
    /// Soft white circle for bag/level-up pulses — avoids live SKShapeNode tessellation.
    static let softCircle: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        return tex
    }()
}
