import SwiftUI
import SpriteKit
import Observation

@Observable
private final class BenchmarkRunState {
    var scenarioLabel = "Starting…"
    var activeWeapons: [String] = []
    var scenarioIndex = 0
    var progress = 0.0
}

struct BenchmarkView: View {
    var session: GameSession

    @State private var scene: BenchmarkScene
    @State private var runState = BenchmarkRunState()
    @State private var results: [BenchmarkScene.Result] = []
    @State private var isDone = false

    init(session: GameSession) {
        self.session = session
        let s = BenchmarkScene(size: CGSize(width: 844, height: 390))
        s.scaleMode = .resizeFill
        _scene = State(initialValue: s)
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.12, blue: 0.16).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if isDone {
                    resultsBody
                } else {
                    // Canvas must not read runState — progress ticks must not rebuild SpriteView.
                    VStack(spacing: 12) {
                        BenchmarkCanvas(scene: scene)
                        BenchmarkChrome(state: runState)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 8)
        }
        .onAppear { wireAndStart(scene) }
    }

    private var header: some View {
        ZStack {
            Text("BENCHMARK")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9))
            HStack {
                Button {
                    AudioManager.shared.playSFX(.ui)
                    Haptics.ui()
                    session.leaveBenchmark()
                } label: {
                    Label(isDone ? "Back" : "Cancel", systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var resultsBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionLabel("Results")

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("Scenario")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Avg").frame(width: 48, alignment: .trailing)
                        Text("Min").frame(width: 48, alignment: .trailing)
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                    Divider().background(Color.white.opacity(0.1))

                    ForEach(Array(results.enumerated()), id: \.offset) { idx, result in
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.label)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(result.weapons.isEmpty ? "No weapon fire" : result.weapons.joined(separator: " · "))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            fpsBadge(result.avgFPS, label: "avg")
                                .frame(width: 48, alignment: .trailing)
                            fpsBadge(result.minFPS, label: "min")
                                .frame(width: 48, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if idx < results.count - 1 {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                sectionLabel("Legend")

                HStack(spacing: 16) {
                    legendDot(color: Color(red: 0.35, green: 0.9, blue: 0.55), label: "≥ 50 — smooth")
                    legendDot(color: Color(red: 1.0, green: 0.85, blue: 0.3), label: "≥ 28 — playable")
                    legendDot(color: .red, label: "< 28 — drops")
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                let maxFPS = UIScreen.main.maximumFramesPerSecond
                Text("Scenarios mirror gameplay contact load. Avg over \(String(format: "%.1f", BenchmarkScene.scenarioDuration - BenchmarkScene.warmupDuration))s after warmup · \(maxFPS) Hz.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    AudioManager.shared.playSFX(.ui)
                    Haptics.ui()
                    runAgain()
                } label: {
                    Text("Run Again")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.2, green: 0.85, blue: 0.9).opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color(red: 0.2, green: 0.85, blue: 0.9).opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func fpsBadge(_ fps: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(fps)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(fpsColor(fps))
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.9).opacity(0.85))
            .tracking(0.6)
    }

    private func fpsColor(_ fps: Int) -> Color {
        if fps >= 50 { return Color(red: 0.35, green: 0.9, blue: 0.55) }
        if fps >= 28 { return Color(red: 1.0, green: 0.85, blue: 0.3) }
        return .red
    }

    private func wireAndStart(_ s: BenchmarkScene) {
        s.onScenarioChange = { [runState] idx, label, weapons in
            runState.scenarioIndex = idx
            runState.scenarioLabel = label
            runState.activeWeapons = weapons
            runState.progress = 0
        }
        s.onProgress = { [runState] p in
            runState.progress = p
        }
        s.onComplete = { r in
            results = r
            isDone = true
        }
        s.start()
    }

    private func runAgain() {
        let s = BenchmarkScene(size: CGSize(width: 844, height: 390))
        s.scaleMode = .resizeFill
        runState.scenarioLabel = "Starting…"
        runState.activeWeapons = []
        runState.scenarioIndex = 0
        runState.progress = 0
        results = []
        isDone = false
        scene = s
        wireAndStart(s)
    }
}

/// Owns SpriteView only — must not observe benchmark progress state.
private struct BenchmarkCanvas: View {
    let scene: BenchmarkScene

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: UIScreen.main.maximumFramesPerSecond)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)
    }
}

private struct BenchmarkChrome: View {
    @Bindable var state: BenchmarkRunState

    private static let warmupFrac = BenchmarkScene.warmupDuration / BenchmarkScene.scenarioDuration

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.scenarioLabel.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if !state.activeWeapons.isEmpty {
                        Text(state.activeWeapons.joined(separator: " · "))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                Spacer()
                Text("\(state.scenarioIndex + 1) / \(BenchmarkScene.scenarioCount)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }

            progressBar

            HStack {
                let inWarmup = state.progress < Self.warmupFrac
                Circle()
                    .fill(inWarmup ? Color.white.opacity(0.35) : Color(red: 0.2, green: 0.85, blue: 0.9))
                    .frame(width: 6, height: 6)
                Text(inWarmup ? "Warming up…" : "Measuring…")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if state.progress >= Self.warmupFrac {
                    let measuredFrac = (state.progress - Self.warmupFrac) / (1 - Self.warmupFrac)
                    let remaining = BenchmarkScene.scenarioDuration * (1 - Self.warmupFrac) * (1 - measuredFrac)
                    Text(String(format: "%.1fs left", max(0, remaining)))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let warmupW = geo.size.width * CGFloat(Self.warmupFrac)
            let measureW = geo.size.width - warmupW
            let fillW = geo.size.width * CGFloat(state.progress)

            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.4))
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: min(fillW, warmupW))
                if fillW > warmupW {
                    Capsule()
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.9))
                        .frame(width: min(fillW - warmupW, measureW))
                        .offset(x: warmupW)
                }
            }
        }
        .frame(height: 7)
    }
}

#Preview {
    BenchmarkView(session: GameSession())
}
