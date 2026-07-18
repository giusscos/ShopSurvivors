import SwiftUI

struct ResultView: View {
    @ObservedObject var session: GameSession
    let store: StoreLevel

    private var nextStore: StoreLevel? {
        guard session.outcome == .won,
              let idx = StoreLevel.all.firstIndex(where: { $0.id == store.id }),
              idx + 1 < StoreLevel.all.count else { return nil }
        return StoreLevel.all[idx + 1]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text(session.outcome == .won ? "BUDGET SURVIVED" : "WALLET WIPED")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(session.outcome == .won
                        ? Color(red: 0.35, green: 0.9, blue: 0.55)
                        : Color(red: 1.0, green: 0.4, blue: 0.35))

                Text(session.outcome == .won
                     ? "You escaped \(store.name) with $\(Int(session.budget)) left."
                     : "The clerks closed the deal. Try again!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                if session.outcome == .won {
                    if let next = nextStore {
                        Text("Unlocked: \(next.name)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))
                    } else {
                        Text("All stores cleared — mall master!")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))
                    }
                } else {
                    Text("Tip: survive until the timer hits 0:00 with budget left.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button {
                        session.startStore(store)
                    } label: {
                        resultButton("Retry", filled: false)
                    }

                    if let next = nextStore {
                        Button {
                            session.startStore(next)
                        } label: {
                            resultButton("Next Store", filled: true)
                        }
                    }

                    Button {
                        session.goLevelSelect()
                    } label: {
                        resultButton("Stores", filled: session.outcome != .won || nextStore == nil)
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
