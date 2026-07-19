import SwiftUI

struct TutorialOverlayView: View {
    @ObservedObject var session: GameSession
    @State private var stepIndex = 0

    private let steps: [(title: String, body: String)] = [
        ("Move", "Use the left joystick to walk around the store."),
        ("Protect FRIEND", "Clerks path to your friend and drain budget when they get close."),
        ("Shove clerks", "Walk into clerks to knock them away from your friend."),
        ("Drop a LURE", "Hold LURE, drag onto the floor, and release to distract clerks."),
        ("XP & upgrades", "Defeat clerks, pick up cyan XP gems, then choose an upgrade."),
        ("Win the run", "Survive until the timer hits 0:00 with budget left.")
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("TUTORIAL")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))

                Text(steps[stepIndex].title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(steps[stepIndex].body)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                Text("Step \(stepIndex + 1) of \(steps.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))

                HStack(spacing: 12) {
                    Button {
                        AudioManager.shared.playSFX(.ui)
                        session.skipTutorial()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Button {
                        AudioManager.shared.playSFX(.ui)
                        if stepIndex + 1 >= steps.count {
                            session.completeTutorial()
                        } else {
                            stepIndex += 1
                        }
                    } label: {
                        Text(stepIndex + 1 >= steps.count ? "Got it" : "Next")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.18))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(Color(red: 1.0, green: 0.55, blue: 0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.14, blue: 0.18).opacity(0.96))
            )
            .padding(.horizontal, 24)
        }
    }
}
