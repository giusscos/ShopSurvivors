import SwiftUI

struct LevelSelectView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.12, blue: 0.16)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button {
                        session.goTitle()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Text("CHOOSE A STORE")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))
                    Spacer()
                    Color.clear.frame(width: 60)
                }

                Text("Survive each store’s timer with budget left to unlock the next.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

                HStack(spacing: 16) {
                    ForEach(Array(StoreLevel.all.enumerated()), id: \.element.id) { index, store in
                        let locked = index > session.unlockedStoreIndex
                        StoreCard(store: store, locked: locked, unlockHint: index == session.unlockedStoreIndex + 1) {
                            if !locked {
                                session.startStore(store)
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}

private struct StoreCard: View {
    let store: StoreLevel
    let locked: Bool
    var unlockHint: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(store.floorColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(store.accentColor.opacity(0.7), lineWidth: 2)
                    )
                    .overlay {
                        if locked {
                            VStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.title)
                                    .foregroundStyle(.white.opacity(0.7))
                                if unlockHint {
                                    Text("Clear previous store")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        } else {
                            Text(store.name.split(separator: " ").first.map(String.init) ?? "")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(store.accentColor)
                        }
                    }
                    .frame(height: 100)

                Text(store.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(store.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)

                HStack {
                    Label("$\(Int(store.startingBudget))", systemImage: "dollarsign.circle")
                    Spacer()
                    Label(formatTime(store.duration), systemImage: "timer")
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(store.accentColor)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(locked ? 0.04 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(locked ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
