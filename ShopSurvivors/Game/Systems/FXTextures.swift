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

    /// Wifi-wave arc fan (apex at left-center) for barcode laser cones.
    static let softWedge: SKTexture = {
        let size = CGSize(width: 128, height: 128)
        let apex = CGPoint(x: 4, y: size.height * 0.5)
        // Half-angle chosen so arcs fill the texture's triangular region (~25°).
        // When the sprite is scaled to (range, farWidth) the arcs widen to the weapon's ~40°.
        let halfAngle: CGFloat = 0.44

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            // Small dot at origin
            let dot = UIBezierPath(ovalIn: CGRect(x: apex.x - 4, y: apex.y - 4, width: 8, height: 8))
            UIColor.white.setFill()
            dot.fill()

            // Concentric arcs: (radius, lineWidth, alpha) — inner arcs are brightest
            let arcs: [(CGFloat, CGFloat, CGFloat)] = [
                (22, 8, 1.0),
                (48, 7, 0.80),
                (76, 6, 0.60),
                (106, 5, 0.38),
            ]

            for (radius, lineWidth, alpha) in arcs {
                let arc = UIBezierPath(
                    arcCenter: apex,
                    radius: radius,
                    startAngle: -halfAngle,
                    endAngle: halfAngle,
                    clockwise: true
                )
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                UIColor.white.withAlphaComponent(alpha).setStroke()
                arc.stroke()
            }
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        return tex
    }()
}
