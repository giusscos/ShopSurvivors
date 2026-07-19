import SwiftUI

struct TitleView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        GeometryReader { geo in
            let insetL = max(geo.safeAreaInsets.leading, 12) + 8
            let insetR = max(geo.safeAreaInsets.trailing, 12) + 8
            let safeTop = max(geo.safeAreaInsets.top, 6)
            let safeBottom = max(geo.safeAreaInsets.bottom, 10)

            ZStack {
                // Background must be sized to the viewport — scaledToFill
                // without a fixed frame expands the ZStack and clips UI.
                Image("title_splash")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.55),
                                Color.black.opacity(0.08),
                                Color.black.opacity(0.08),
                                Color.black.opacity(0.72)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, safeTop)
                        .padding(.leading, insetL)
                        .padding(.trailing, insetR)

                    titleBlock
                        .padding(.top, 8)

                    Spacer(minLength: 24)

                    bottomBlock
                        .padding(.leading, insetL)
                        .padding(.trailing, insetR)
                        .padding(.bottom, safeBottom)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            AudioMuteButtons(size: 40, cornerRadius: 10)
            Spacer(minLength: 0)
            Button {
                AudioManager.shared.playSFX(.ui)
                Haptics.ui()
                session.goHowToPlay()
            } label: {
                Text("How to Play")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Button {
                AudioManager.shared.playSFX(.ui)
                Haptics.ui()
                session.goSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel("Settings")
        }
    }

    private var titleBlock: some View {
        ArcedTitleText(
            segments: [
                ("SHOP ", Color(red: 0.2, green: 0.85, blue: 0.9)),
                ("SURVIVORS", Color(red: 1.0, green: 0.55, blue: 0.25))
            ],
            fontSize: 38,
            arcHeight: 24,
            letterSpacing: 3
        )
        .frame(height: 72)
        .shadow(color: .black.opacity(0.65), radius: 4, y: 2)
        .accessibilityAddTraits(.isHeader)
    }

    private var bottomBlock: some View {
        VStack(spacing: 12) {
            Text("Protect your partner's budget from relentless sales pitches.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 380)

            Button {
                AudioManager.shared.playSFX(.ui)
                Haptics.ui()
                session.goLevelSelect()
            } label: {
                Text("ENTER THE MALL")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.18))
                    .frame(minWidth: 200)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color(red: 1.0, green: 0.55, blue: 0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                let angle = Double(centered) * 20

                Text(String(item.0))
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .foregroundStyle(item.1)
                    .rotationEffect(.degrees(angle))
                    .offset(y: y)
            }
        }
    }
}
