import SwiftUI

struct HowToPlayView: View {
    @ObservedObject var session: GameSession

    private let steps: [(title: String, body: String)] = [
        ("Move", "Use the left joystick to walk around the store."),
        ("Protect FRIEND", "Your friend browses on their own. Clerks that get close pitch and drain budget."),
        ("Shove clerks", "Walk into clerks to knock them back and interrupt pitches."),
        ("LURE coupons", "Hold LURE, drag onto the floor, and release to distract clerks."),
        ("XP & upgrades", "Defeat clerks, pick up cyan XP gems, and choose an upgrade on level-up."),
        ("Win the run", "Survive until the timer hits 0:00 with budget left to unlock the next store.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    AudioManager.shared.playSFX(.ui)
                    session.goTitle()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Text("HOW TO PLAY")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))
                Spacer()
                Color.clear.frame(width: 60)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.18))
                                .frame(width: 26, height: 26)
                                .background(Color(red: 1.0, green: 0.55, blue: 0.25))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(step.body)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 24)
            .frame(maxHeight: .infinity)

            Button {
                AudioManager.shared.playSFX(.ui)
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
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Color(red: 0.07, green: 0.12, blue: 0.16).ignoresSafeArea())
    }
}

#Preview { HowToPlayView(session: GameSession()) }
