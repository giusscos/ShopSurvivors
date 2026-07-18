import SwiftUI

struct TitleView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.18, blue: 0.24),
                    Color(red: 0.12, green: 0.28, blue: 0.32),
                    Color(red: 0.2, green: 0.22, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ForEach(0..<8, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 2 == 0 ? 0.03 : 0.015))
                        .frame(width: geo.size.width / 8)
                        .offset(x: CGFloat(i) * geo.size.width / 8)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        AudioManager.shared.playSFX(.ui)
                        session.goHowToPlay()
                    } label: {
                        Text("How to Play")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    Button {
                        AudioManager.shared.playSFX(.ui)
                        session.goSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer(minLength: 0)

                VStack(spacing: 18) {
                    ArcedTitleText(
                        segments: [
                            ("SHOP ", Color(red: 0.2, green: 0.85, blue: 0.9)),
                            ("SURVIVORS", Color(red: 1.0, green: 0.55, blue: 0.25))
                        ],
                        fontSize: 44,
                        arcHeight: 36,
                        letterSpacing: 2
                    )
                    .frame(height: 100)

                    Text("Protect your partner's budget from relentless sales pitches.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                Spacer(minLength: 0)

                Button {
                    AudioManager.shared.playSFX(.ui)
                    session.goLevelSelect()
                } label: {
                    Text("ENTER THE MALL")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.18))
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Color(red: 1.0, green: 0.55, blue: 0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.bottom, 28)
            }
        }
    }
}

/// Lays letters along an upward arc (center higher than the edges).
private struct ArcedTitleText: View {
    let segments: [(String, Color)]
    var fontSize: CGFloat = 44
    var arcHeight: CGFloat = 36
    var letterSpacing: CGFloat = 2

    private var letters: [(Character, Color)] {
        segments.flatMap { text, color in text.map { ($0, color) } }
    }

    var body: some View {
        let chars = letters
        let count = max(chars.count, 1)

        HStack(spacing: letterSpacing) {
            ForEach(Array(chars.enumerated()), id: \.offset) { index, item in
                let t = count == 1 ? 0.5 : CGFloat(index) / CGFloat(count - 1)
                let centered = t - 0.5
                let y = -arcHeight * cos(centered * .pi)
                let angle = Double(centered) * 28

                Text(String(item.0))
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .foregroundStyle(item.1)
                    .rotationEffect(.degrees(angle))
                    .offset(y: y)
            }
        }
    }
}
