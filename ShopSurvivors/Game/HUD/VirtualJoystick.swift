import SwiftUI

struct VirtualJoystick: View {
    @Binding var vector: CGVector
    var size: CGFloat = 110

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.35))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
                .frame(width: size, height: size)

            Circle()
                .fill(Color(red: 0.2, green: 0.75, blue: 0.8))
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(dragOffset)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let maxR = size * 0.32
                    var dx = value.translation.width
                    var dy = value.translation.height
                    let len = hypot(dx, dy)
                    if len > maxR {
                        dx = dx / len * maxR
                        dy = dy / len * maxR
                    }
                    dragOffset = CGSize(width: dx, height: dy)
                    // SpriteKit Y is up; SwiftUI drag Y is down
                    vector = CGVector(dx: dx / maxR, dy: -dy / maxR)
                }
                .onEnded { _ in
                    dragOffset = .zero
                    vector = .zero
                }
        )
    }
}
