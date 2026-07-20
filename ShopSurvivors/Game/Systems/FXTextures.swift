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

    /// Soft white isosceles wedge (apex at left-center) for barcode laser cones.
    static let softWedge: SKTexture = {
        let size = CGSize(width: 128, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 2, y: size.height * 0.5))
            path.addLine(to: CGPoint(x: size.width - 2, y: size.height * 0.06))
            path.addLine(to: CGPoint(x: size.width - 2, y: size.height * 0.94))
            path.close()
            UIColor.white.setFill()
            path.fill()
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        return tex
    }()
}
