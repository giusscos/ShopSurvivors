import SwiftUI

/// One-time manga-style lore intro shown on first launch.
struct LoreIntroView: View {
    @ObservedObject var session: GameSession
    @State private var pageIndex = 0
    @State private var appeared = false
    @State private var actionPulse = false
    @State private var isAdvancing = false

    private let pages: [LorePage] = [
        LorePage(
            chapter: "01",
            title: "SALE DAY",
            caption: "Your friend walks into the mall with a full budget.\nThe clerks can smell it.",
            kind: .arrival
        ),
        LorePage(
            chapter: "02",
            title: "THE PITCH",
            caption: "Commission hunters close in.\nEvery pitch drains the wallet.",
            kind: .swarm
        ),
        LorePage(
            chapter: "03",
            title: "FIGHT BACK",
            caption: "Shove clerks away.\nDrop LURE coupons to pull them off your friend.",
            kind: .action
        ),
        LorePage(
            chapter: "04",
            title: "SURVIVE",
            caption: "Protect the budget until the store closes.\nTimer hits zero with money left — you win.",
            kind: .survive
        )
    ]

    private var currentPage: LorePage {
        pages[min(max(pageIndex, 0), pages.count - 1)]
    }

    private var isLastPage: Bool {
        pageIndex >= pages.count - 1
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.09)
                .ignoresSafeArea()

            MangaHalftoneBackground()
                .ignoresSafeArea()
                .opacity(0.35)

            VStack(spacing: 0) {
                HStack {
                    Text("SHOP SURVIVORS")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9).opacity(0.7))
                    Spacer()
                    Button {
                        AudioManager.shared.playSFX(.ui)
                        finishIntro()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 6)

                GeometryReader { geo in
                    let sideTextWidth = min(260, geo.size.width * 0.34)
                    let gap: CGFloat = 16
                    let panelW = max(180, geo.size.width - sideTextWidth - gap - 32)
                    let panelH = max(140, geo.size.height - 8)

                    HStack(alignment: .center, spacing: gap) {
                        MangaPanelFrame(width: panelW, height: panelH) {
                            LorePanelArt(
                                kind: currentPage.kind,
                                size: CGSize(width: panelW, height: panelH),
                                actionPulse: actionPulse
                            )
                        }
                        .scaleEffect(appeared ? 1 : 0.94)
                        .opacity(appeared ? 1 : 0)
                        .id(pageIndex)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            AudioManager.shared.playSFX(.ui)
                            advance()
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Text("CH. \(currentPage.chapter)")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.25))
                                Text(currentPage.title)
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }

                            Text(currentPage.caption)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 6) {
                                ForEach(0..<pages.count, id: \.self) { i in
                                    Capsule()
                                        .fill(i == pageIndex
                                              ? Color(red: 1.0, green: 0.55, blue: 0.25)
                                              : Color.white.opacity(0.25))
                                        .frame(width: i == pageIndex ? 18 : 8, height: 6)
                                        .animation(.spring(response: 0.35), value: pageIndex)
                                }
                            }
                            .padding(.top, 2)

                            Spacer(minLength: 0)

                            Button {
                                AudioManager.shared.playSFX(.ui)
                                advance()
                            } label: {
                                Text(isLastPage ? "ENTER THE MALL" : "NEXT")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.18))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(red: 1.0, green: 0.55, blue: 0.25))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .disabled(isAdvancing)

                            Text("or tap the panel")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                                .frame(maxWidth: .infinity)
                        }
                        .frame(width: sideTextWidth, alignment: .leading)
                        .opacity(appeared ? 1 : 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
            }

            VignetteOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                actionPulse = true
            }
        }
    }

    private func advance() {
        guard !isAdvancing else { return }

        if isLastPage {
            finishIntro()
            return
        }

        isAdvancing = true
        withAnimation(.easeInOut(duration: 0.22)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            let next = min(pageIndex + 1, pages.count - 1)
            pageIndex = next
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                appeared = true
            }
            isAdvancing = false
        }
    }

    private func finishIntro() {
        isAdvancing = true
        session.completeLoreIntro()
    }
}

// MARK: - Data

private struct LorePage {
    let chapter: String
    let title: String
    let caption: String
    let kind: LorePanelKind
}

private enum LorePanelKind {
    case arrival
    case swarm
    case action
    case survive
}

// MARK: - Panel chrome

private struct MangaPanelFrame<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 0.12, green: 0.16, blue: 0.2))
                .frame(width: width + 8, height: height + 8)

            content
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                .frame(width: width, height: height)

            MangaCornerSlash()
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                .frame(width: 70, height: 50)
                .frame(width: width, height: height, alignment: .topTrailing)
                .padding(10)
                .allowsHitTesting(false)
        }
        .frame(width: width + 8, height: height + 8)
    }
}

private struct MangaCornerSlash: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in 0..<5 {
            let y = CGFloat(i) * 9
            p.move(to: CGPoint(x: rect.maxX - 8, y: y))
            p.addLine(to: CGPoint(x: rect.maxX - 55 + CGFloat(i) * 4, y: y + 18))
        }
        return p
    }
}

// MARK: - Panel art scenes

private struct LorePanelArt: View {
    let kind: LorePanelKind
    let size: CGSize
    let actionPulse: Bool

    var body: some View {
        ZStack {
            panelBackdrop

            switch kind {
            case .arrival:
                arrivalScene
            case .swarm:
                swarmScene
            case .action:
                actionScene
            case .survive:
                surviveScene
            }
        }
    }

    private var panelBackdrop: some View {
        LinearGradient(
            colors: backdropColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backdropColors: [Color] {
        switch kind {
        case .arrival:
            return [
                Color(red: 0.18, green: 0.35, blue: 0.42),
                Color(red: 0.12, green: 0.22, blue: 0.28),
                Color(red: 0.25, green: 0.28, blue: 0.18)
            ]
        case .swarm:
            return [
                Color(red: 0.35, green: 0.12, blue: 0.14),
                Color(red: 0.22, green: 0.1, blue: 0.16),
                Color(red: 0.15, green: 0.12, blue: 0.2)
            ]
        case .action:
            return [
                Color(red: 0.15, green: 0.32, blue: 0.38),
                Color(red: 0.1, green: 0.2, blue: 0.26),
                Color(red: 0.35, green: 0.28, blue: 0.12)
            ]
        case .survive:
            return [
                Color(red: 0.1, green: 0.28, blue: 0.32),
                Color(red: 0.08, green: 0.18, blue: 0.24),
                Color(red: 0.2, green: 0.35, blue: 0.22)
            ]
        }
    }

    // MARK: Scenes

    private var arrivalScene: some View {
        ZStack {
            // Storefront glow
            Ellipse()
                .fill(Color(red: 1.0, green: 0.7, blue: 0.3).opacity(0.25))
                .frame(width: 180, height: 60)
                .offset(y: size.height * 0.18)
                .blur(radius: 12)

            HStack(spacing: 28) {
                PixelSprite("player", scale: 3.2)
                    .offset(y: actionPulse ? -4 : 2)
                PixelSprite("companion", scale: 3.2)
                    .offset(y: actionPulse ? 2 : -4)
            }
            .offset(y: 8)

            mangaBubble("Let's go!", x: -90, y: -78)
            mangaBubble("$ $ $", x: 95, y: -70, accent: true)
        }
    }

    private var swarmScene: some View {
        ZStack {
            PixelSprite("companion", scale: 2.8)
                .offset(x: 70, y: 20)
                .opacity(0.95)

            ForEach(0..<4, id: \.self) { i in
                let names = ["clerk_pitcher", "clerk_closer", "clerk_sprinter", "clerk_upseller"]
                let offsets: [(CGFloat, CGFloat)] = [(-110, 10), (-55, -25), (-80, 45), (-20, 30)]
                PixelSprite(names[i], scale: 2.4)
                    .offset(
                        x: offsets[i].0 + (actionPulse ? 6 : -4),
                        y: offsets[i].1
                    )
            }

            Text("−$")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.35))
                .offset(x: 120, y: actionPulse ? -50 : -40)
                .opacity(actionPulse ? 1 : 0.55)
                .scaleEffect(actionPulse ? 1.1 : 0.9)

            mangaBubble("BUY NOW!", x: -40, y: -85, accent: true)
        }
    }

    private var actionScene: some View {
        ZStack {
            // Impact flash
            Circle()
                .fill(Color.white.opacity(actionPulse ? 0.18 : 0.05))
                .frame(width: 120, height: 120)
                .offset(x: -30, y: 10)
                .blur(radius: 8)

            PixelSprite("clerk_pitcher", scale: 2.6)
                .offset(x: actionPulse ? 55 : 35, y: actionPulse ? -15 : 5)
                .rotationEffect(.degrees(actionPulse ? 18 : 6))

            PixelSprite("player", scale: 3.0)
                .offset(x: -50, y: 15)

            PixelSprite("coupon", scale: 2.2)
                .offset(x: 100, y: actionPulse ? 35 : 45)
                .scaleEffect(actionPulse ? 1.15 : 1.0)

            // Motion whoosh
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: actionPulse ? 50 : 28, height: 4)
                .offset(x: -5, y: -5)
                .rotationEffect(.degrees(-20))

            mangaBubble("SHOVE!", x: -95, y: -75, accent: true)
            mangaBubble("LURE", x: 115, y: -60)
        }
    }

    private var surviveScene: some View {
        ZStack {
            // Timer ring
            Circle()
                .stroke(Color(red: 0.2, green: 0.85, blue: 0.9).opacity(0.35), lineWidth: 6)
                .frame(width: 90, height: 90)
                .offset(y: -50)

            Text("0:00")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))
                .offset(y: -50)

            HStack(spacing: 36) {
                PixelSprite("player", scale: 2.8)
                PixelSprite("companion", scale: 2.8)
            }
            .offset(y: 45)
            .offset(y: actionPulse ? -3 : 3)

            Text("BUDGET SAFE")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.4, green: 0.95, blue: 0.55))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
                .offset(y: actionPulse ? 95 : 90)
        }
    }

    private func mangaBubble(_ text: String, x: CGFloat, y: CGFloat, accent: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(accent ? Color(red: 0.08, green: 0.12, blue: 0.14) : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accent ? Color(red: 1.0, green: 0.55, blue: 0.25) : Color.black.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
            )
            .offset(x: x, y: y)
    }
}

private struct PixelSprite: View {
    let name: String
    var scale: CGFloat = 2

    init(_ name: String, scale: CGFloat = 2) {
        self.name = name
        self.scale = scale
    }

    var body: some View {
        Image(name)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 28 * scale, height: 36 * scale)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
    }
}

// MARK: - Atmosphere

private struct VignetteOverlay: View {
    var body: some View {
        RadialGradient(
            colors: [
                Color.clear,
                Color.clear,
                Color.black.opacity(0.28),
                Color.black.opacity(0.55)
            ],
            center: .center,
            startRadius: 100,
            endRadius: 480
        )
        .allowsHitTesting(false)
    }
}

private struct MangaHalftoneBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 10
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let r = 1.2 + ((x + y).truncatingRemainder(dividingBy: 30)) / 40
                    let rect = CGRect(x: x, y: y, width: r, height: r)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.07)))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

#Preview {
    LoreIntroView(session: GameSession())
}
