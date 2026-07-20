import SwiftUI

struct ResultView: View {
    var session: GameSession
    let store: StoreLevel

    private var nextStore: StoreLevel? {
        guard session.outcome == .won,
              let idx = StoreLevel.all.firstIndex(where: { $0.id == store.baseId }),
              idx + 1 < StoreLevel.all.count else { return nil }
        return StoreLevel.all[idx + 1]
    }

    private var unlocksEndless: Bool {
        session.outcome == .won && store.baseId == StoreLevel.all.last?.id
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text(resultTitle)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(titleColor)

                Text(resultBody)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                if let best = session.formattedBest(for: store) {
                    Text(best)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))
                }

                if session.outcome == .won {
                    if unlocksEndless {
                        Text("Unlocked: Midnight Mall (Endless)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))
                    } else if let next = nextStore {
                        Text("Unlocked: \(next.name)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))
                    } else if !store.isEndless {
                        Text("All stores cleared — mall master!")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))
                    }
                } else if !store.isEndless {
                    Text("Tip: survive until the timer hits 0:00 with budget left.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }

                Button {
                    AudioManager.shared.playSFX(.ui)
                    Haptics.ui()
                    _ = GameCenterManager.shared.showLeaderboard(storeId: store.baseId)
                } label: {
                    Label(GameCenterManager.shared.isAuthenticated ? "Leaderboard" : "Sign in for Leaderboard", systemImage: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.22, green: 0.55, blue: 0.95).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let msg = GameCenterManager.shared.statusMessage, !GameCenterManager.shared.isAuthenticated {
                    Text(msg)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button {
                        AudioManager.shared.playSFX(.ui)
                        Haptics.ui()
                        session.startStore(store)
                    } label: {
                        resultButton("Retry", filled: false)
                    }

                    if let next = nextStore {
                        Button {
                            AudioManager.shared.playSFX(.ui)
                            Haptics.ui()
                            session.pendingStoreForDifficulty = next
                        } label: {
                            resultButton("Next Store", filled: true)
                        }
                    } else if unlocksEndless {
                        Button {
                            AudioManager.shared.playSFX(.ui)
                            Haptics.ui()
                            session.startStore(StoreLevel.endless)
                        } label: {
                            resultButton("Endless", filled: true)
                        }
                    }

                    Button {
                        AudioManager.shared.playSFX(.ui)
                        Haptics.ui()
                        session.goLevelSelect()
                    } label: {
                        resultButton("Stores", filled: session.outcome != .won || (nextStore == nil && !unlocksEndless))
                    }
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.1, green: 0.16, blue: 0.2))
            )
        }
    }

    private var resultTitle: String {
        if store.isEndless {
            return "RUN OVER"
        }
        return session.outcome == .won ? "BUDGET SURVIVED" : "WALLET WIPED"
    }

    private var titleColor: Color {
        if store.isEndless {
            return Color(red: 0.75, green: 0.45, blue: 0.95)
        }
        return session.outcome == .won
            ? Color(red: 0.35, green: 0.9, blue: 0.55)
            : Color(red: 1.0, green: 0.4, blue: 0.35)
    }

    private var resultBody: String {
        if store.isEndless {
            return "You lasted \(session.formatClock(session.runElapsed)) in Midnight Mall."
        }
        let difficulty = store.difficulty.displayName.capitalized
        if session.outcome == .won {
            return String(format: "%@ · You escaped \(store.name) with $%.2f left.", difficulty, Double(session.budget))
        }
        return "\(difficulty) · The clerks closed the deal. Try again!"
    }

    private func resultButton(_ title: String, filled: Bool) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(filled ? Color(red: 0.08, green: 0.15, blue: 0.18) : .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(filled ? Color(red: 1.0, green: 0.55, blue: 0.25) : Color.white.opacity(0.12))
            )
    }
}
