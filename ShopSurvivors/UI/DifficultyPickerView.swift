import SwiftUI

struct DifficultyPickerView: View {
    let store: StoreLevel
    let onSelect: (DifficultyTier) -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text(store.name.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(store.accentColor))
                    Text("Choose Difficulty")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                HStack(alignment: .top, spacing: 10) {
                    ForEach(DifficultyTier.allCases) { tier in
                        difficultyCard(tier)
                            .frame(maxWidth: .infinity)
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.12, blue: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
        }
    }

    private func dismiss() {
        AudioManager.shared.playSFX(.ui)
        Haptics.ui()
        onCancel?()
    }

    private func difficultyCard(_ tier: DifficultyTier) -> some View {
        let variant = store.withDifficulty(tier)
        return Button {
            AudioManager.shared.playSFX(.ui)
            Haptics.ui()
            onSelect(tier)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(tier.displayName)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(tier.accentColor)

                Text(tier.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.vertical, 3)

                VStack(alignment: .leading, spacing: 4) {
                    statRow("Budget", String(format: "$%.0f", Double(variant.startingBudget)))
                    if !store.isEndless {
                        statRow("Time", "\(Int(variant.duration))s")
                    }
                    statRow("Max clerks", "\(variant.maxClerks)")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tier.accentColor.opacity(0.55), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(tier.displayName): \(tier.blurb). Budget \(String(format: "$%.0f", Double(variant.startingBudget)))")
        .accessibilityHint("Double tap to start")
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
