import SwiftUI
import SpriteKit

struct GameContainerView: View {
    @ObservedObject var session: GameSession
    let store: StoreLevel

    @State private var scene: GameScene
    @State private var joystickVector: CGVector = .zero

    init(session: GameSession, store: StoreLevel) {
        self.session = session
        self.store = store
        let s = GameScene(size: CGSize(width: 844, height: 390))
        s.scaleMode = .resizeFill
        s.configure(session: session, store: store)
        _scene = State(initialValue: s)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: scene, preferredFramesPerSecond: 120, options: [.allowsTransparency])
                    .ignoresSafeArea()

                VStack {
                    topHUD
                    if !session.pickupToast.isEmpty {
                        Text(session.pickupToast)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.15, green: 0.35, blue: 0.4).opacity(0.9))
                            .clipShape(Capsule())
                            .transition(.opacity)
                    }
                    Spacer()
                    bottomHUD(geo: geo)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if session.isAimingCoupon {
                    VStack {
                        Text("Release to drop LURE")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                            .padding(.top, 52)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }

                if session.isPausedForUpgrade {
                    UpgradePickerView(session: session)
                }

                if session.isTutorialActive {
                    TutorialOverlayView(session: session)
                }

                if session.isPaused {
                    PauseOverlayView(session: session)
                }

                if session.outcome != nil {
                    ResultView(session: session, store: store)
                }
            }
            .coordinateSpace(name: "game")
        }
        .onAppear {
            joystickVector = .zero
            session.moveVector = .zero
            AudioManager.shared.playMusic(forceRestart: false)
        }
        .onChange(of: joystickVector.dx) { _, _ in
            session.moveVector = joystickVector
        }
        .onChange(of: joystickVector.dy) { _, _ in
            session.moveVector = joystickVector
        }
    }

    private func screenToWorld(_ point: CGPoint, in viewSize: CGSize) -> CGPoint {
        let dx = point.x - viewSize.width / 2
        let dy = viewSize.height / 2 - point.y
        return CGPoint(
            x: session.cameraWorldPosition.x + dx,
            y: session.cameraWorldPosition.y + dy
        )
    }

    private var topHUD: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                budgetBar
                Spacer()
                VStack(spacing: 4) {
                    if !session.pitchBanner.isEmpty {
                        Text(session.pitchBanner)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())
                    }
                    Text("Protect FRIEND · shove clerks")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                HStack(spacing: 8) {
                    timerBadge
                    pauseButton
                }
            }
            xpBar
        }
    }

    private var pauseButton: some View {
        Button {
            session.togglePause()
        } label: {
            Image(systemName: "pause.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .disabled(session.outcome != nil || session.isPausedForUpgrade || session.isAimingCoupon || session.isTutorialActive)
    }

    private var budgetBar: some View {
        let pct = max(0, session.budget / max(1, session.startingBudget))
        return HStack(spacing: 8) {
            Text("$\(Int(session.budget))")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(pct < 0.25 ? Color.red : Color(red: 0.35, green: 0.9, blue: 0.55))
                .frame(minWidth: 52, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.4))
                    Capsule()
                        .fill(pct < 0.25
                              ? Color.red
                              : Color(red: 0.35, green: 0.9, blue: 0.55))
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(width: 140, height: 12)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var timerBadge: some View {
        Text(formatTime(session.timeRemaining))
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var xpBar: some View {
        let pct = CGFloat(session.xp) / CGFloat(max(1, session.xpToNext))
        return HStack(spacing: 8) {
            Text("LV \(session.playerLevel)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule()
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.9))
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 8)
            Text("XP")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9).opacity(0.8))
        }
        .frame(maxWidth: 240)
    }

    private func bottomHUD(geo: GeometryProxy) -> some View {
        HStack(alignment: .bottom) {
            VirtualJoystick(vector: $joystickVector)
                .padding(.leading, 8)
                .opacity(session.isPaused || session.isTutorialActive ? 0.3 : 1)
                .disabled(session.isPaused || session.isPausedForUpgrade || session.isTutorialActive)

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                weaponChips
                couponControl(geo: geo)
            }
        }
    }

    private var weaponChips: some View {
        HStack(spacing: 6) {
            ForEach(session.weapons) { w in
                HStack(spacing: 4) {
                    Image(w.kind.spriteName)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 14, height: 14)
                    Text("\(w.kind.shortLabel) Lv\(w.level)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
            }
        }
    }

    /// Hold on the button and drag onto the arena; release to drop.
    private func couponControl(geo: GeometryProxy) -> some View {
        let ready = session.couponCooldown <= 0
        return ZStack {
            Circle()
                .fill(ready
                      ? (session.isAimingCoupon
                         ? Color(red: 1.0, green: 0.7, blue: 0.35)
                         : Color(red: 1.0, green: 0.55, blue: 0.25))
                      : Color.gray.opacity(0.5))
                .frame(width: 68, height: 68)
            VStack(spacing: 2) {
                Image("coupon")
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 28, height: 22)
                if ready {
                    Text(session.isAimingCoupon ? "DROP" : "HOLD LURE")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.14))
                } else {
                    Text(String(format: "%.1f", session.couponCooldown))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.trailing, 12)
        .padding(.bottom, 4)
        .opacity(ready ? 1 : 0.7)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("game"))
                .onChanged { value in
                    guard ready,
                          session.outcome == nil,
                          !session.isPausedForUpgrade,
                          !session.isPaused,
                          !session.isTutorialActive else { return }
                    session.beginCouponAim()
                    session.couponAimWorld = screenToWorld(value.location, in: geo.size)
                }
                .onEnded { value in
                    guard session.isAimingCoupon else { return }
                    session.couponAimWorld = screenToWorld(value.location, in: geo.size)
                    session.requestCouponDeploy()
                }
        )
        .allowsHitTesting(ready && session.outcome == nil && !session.isPausedForUpgrade && !session.isPaused && !session.isTutorialActive)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
