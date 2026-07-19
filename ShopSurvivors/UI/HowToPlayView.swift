import SwiftUI

struct HowToPlayView: View {
    @ObservedObject var session: GameSession

    private let steps: [(title: String, body: String)] = [
        ("Move", "Use the left joystick to walk around the store."),
        ("Protect FRIEND", "Your friend browses on their own. Clerks that get close pitch and drain budget."),
        ("Shove clerks", "Walk into clerks to knock them back and interrupt pitches."),
        ("LURE coupons", "Hold LURE, drag onto the floor, and release to distract clerks."),
        ("XP & upgrades", "Defeat clerks, pick up cyan XP gems, and choose an upgrade on level-up."),
        ("Win the run", "Survive until the timer hits 0:00 with budget left to unlock the next store."),
        ("Midnight Mall", "Clear all three stores to unlock Endless — last as long as you can.")
    ]

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.12, blue: 0.16)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("HOW TO PLAY")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))

                    HStack {
                        Button {
                            AudioManager.shared.playSFX(.ui)
                            Haptics.ui()
                            session.leaveHowToPlay()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.18))
                                    .frame(width: 22, height: 22)
                                    .background(Color(red: 1.0, green: 0.55, blue: 0.25))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(step.body)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.55))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Button {
                    AudioManager.shared.playSFX(.ui)
                    Haptics.ui()
                    session.goLevelSelect()
                } label: {
                    Text("ENTER THE MALL")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(red: 1.0, green: 0.55, blue: 0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            // Keep chrome inside the system safe area (notch / home indicator).
            .padding(.horizontal, 8)
        }
    }
}

#Preview { HowToPlayView(session: GameSession()) }
