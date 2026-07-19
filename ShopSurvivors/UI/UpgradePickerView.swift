import SwiftUI

struct UpgradePickerView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("LEVEL UP!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.25))

                Text("Pick a deal")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 14) {
                    ForEach(session.upgradeOffers) { offer in
                        Button {
                            session.applyUpgrade(offer)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(offer.kind.title(weapon: offer.weapon))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                Text(offer.kind.blurb(weapon: offer.weapon))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.65))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxHeight: .infinity, alignment: .top)
                            }
                            .padding(14)
                            .frame(width: 180, height: 120, alignment: .topLeading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.12, green: 0.22, blue: 0.28))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color(red: 0.2, green: 0.85, blue: 0.9), lineWidth: 2)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(offer.kind.title(weapon: offer.weapon)): \(offer.kind.blurb(weapon: offer.weapon))")
                        .accessibilityHint("Double tap to apply this upgrade")
                    }
                }
            }
            .padding(24)
        }
    }
}
