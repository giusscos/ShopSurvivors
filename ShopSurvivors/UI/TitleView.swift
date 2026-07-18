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

            // Soft aisle stripes
            GeometryReader { geo in
                ForEach(0..<8, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 2 == 0 ? 0.03 : 0.015))
                        .frame(width: geo.size.width / 8)
                        .offset(x: CGFloat(i) * geo.size.width / 8)
                }
            }
            .ignoresSafeArea()

            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("SHOP")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))
                    Text("SURVIVORS")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.25))
                    Text("Protect your partner's budget from\nrelentless sales pitches.\nBump clerks · drop LURE coupons · grab XP.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        session.goLevelSelect()
                    } label: {
                        Text("ENTER THE MALL")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.18))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Color(red: 1.0, green: 0.55, blue: 0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.top, 8)
                }

                Image("title_splash")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 220)
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            }
            .padding(40)
        }
    }
}
