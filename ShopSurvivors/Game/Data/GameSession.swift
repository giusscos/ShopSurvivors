import Foundation
import Combine
import CoreGraphics
import QuartzCore

enum AppScreen: Equatable {
    case intro
    case title
    case howToPlay
    case settings
    case levelSelect
    case playing(storeId: String)
}

enum RunOutcome: Equatable {
    case won
    case lost
}

@MainActor
final class GameSession: ObservableObject {
    @Published var screen: AppScreen
    @Published var unlockedStoreIndex: Int = 0
    @Published var mallCleared: Bool = false

    /// High-frequency run stats — not @Published; UI refreshes via `hudRevision`.
    var budget: CGFloat = 100
    var startingBudget: CGFloat = 100
    var timeRemaining: TimeInterval = 120
    var runElapsed: TimeInterval = 0
    var couponCooldown: TimeInterval = 0
    /// Bumped ~12×/sec (or on force) so SwiftUI HUD can refresh without per-frame thrash.
    @Published private(set) var hudRevision: UInt = 0

    @Published var xp: Int = 0
    @Published var xpToNext: Int = 12
    @Published var playerLevel: Int = 1
    @Published var couponMaxCooldown: TimeInterval = 4.5
    @Published var isPausedForUpgrade: Bool = false
    @Published var isPaused: Bool = false
    @Published var isTutorialActive: Bool = false
    @Published var isAimingCoupon: Bool = false
    @Published var upgradeOffers: [UpgradeOffer] = []
    @Published var outcome: RunOutcome?
    @Published var weapons: [OwnedWeapon] = []
    @Published var moveSpeedMultiplier: CGFloat = 1
    @Published var willpowerMultiplier: CGFloat = 1
    @Published var pitchBanner: String = ""
    @Published var runID: UUID = UUID()
    @Published var pickupToast: String = ""
    @Published var luresDeployed: Int = 0
    /// When true, gameplay HUD shows a live FPS counter.
    @Published var showFPS: Bool = false {
        didSet { UserDefaults.standard.set(showFPS, forKey: showFPSKey) }
    }
    @Published var hapticsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: hapticsKey)
            Haptics.isEnabled = hapticsEnabled
        }
    }
    @Published var reducedFX: Bool = false {
        didSet { UserDefaults.standard.set(reducedFX, forKey: reducedFXKey) }
    }
    @Published var joystickOnRight: Bool = false {
        didSet { UserDefaults.standard.set(joystickOnRight, forKey: joystickOnRightKey) }
    }
    /// 0 = small, 1 = medium, 2 = large
    @Published var joystickSizePreset: Int = 1 {
        didSet {
            let clamped = min(2, max(0, joystickSizePreset))
            if joystickSizePreset != clamped {
                joystickSizePreset = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: joystickSizeKey)
        }
    }
    @Published var joystickOpacity: Double = 1.0 {
        didSet {
            let clamped = min(1.0, max(0.35, joystickOpacity))
            if abs(joystickOpacity - clamped) > 0.001 {
                joystickOpacity = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: joystickOpacityKey)
        }
    }
    /// Latest measured FPS (written by GameScene; HUD reads via `hudRevision`).
    var displayedFPS: Int = 0

    var joystickSize: CGFloat {
        switch joystickSizePreset {
        case 0: return 90
        case 2: return 135
        default: return 110
        }
    }

    /// Bumps when local bests change so hub UI refreshes.
    @Published var bestScoresRevision: Int = 0
    /// Non-nil while the difficulty picker overlay should be shown for a store.
    @Published var pendingStoreForDifficulty: StoreLevel?

    /// Joystick input written by SwiftUI, read by SpriteKit each frame.
    var moveVector: CGVector = .zero
    /// Latest camera center in world space (written by GameScene).
    var cameraWorldPosition: CGPoint = .zero
    /// World position to place coupon when aiming ends (set by GameScene / UI).
    var couponAimWorld: CGPoint?
    var couponDeployRequested: Bool = false

    private var upgradeQueue: [[UpgradeOffer]] = []
    private var settingsReturn: AppScreen = .title
    private var howToPlayReturn: AppScreen = .title

    private let unlockedKey = "unlockedStoreIndex"
    private let mallClearedKey = "mallCleared"
    private let tutorialKey = "hasCompletedTutorial"
    private let introKey = "hasSeenLoreIntro"
    private let showFPSKey = "showFPS"
    private let hapticsKey = "hapticsEnabled"
    private let reducedFXKey = "reducedFX"
    private let joystickOnRightKey = "joystickOnRight"
    private let joystickSizeKey = "joystickSizePreset"
    private let joystickOpacityKey = "joystickOpacity"
    private let bestBudgetPrefix = "bestBudget_"
    private let bestEndlessKey = "bestEndlessSeconds"
    private var toastClearTask: Task<Void, Never>?
    private var cloudObserver: NSObjectProtocol?
    private var lastHUDPublishTime: CFTimeInterval = 0
    private let hudPublishInterval: CFTimeInterval = 1.0 / 12.0

    init() {
        unlockedStoreIndex = UserDefaults.standard.integer(forKey: unlockedKey)
        mallCleared = UserDefaults.standard.bool(forKey: mallClearedKey)
        showFPS = UserDefaults.standard.bool(forKey: showFPSKey)
        let haptics = UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true
        hapticsEnabled = haptics
        Haptics.isEnabled = haptics
        reducedFX = UserDefaults.standard.bool(forKey: reducedFXKey)
        joystickOnRight = UserDefaults.standard.bool(forKey: joystickOnRightKey)
        let storedSize = UserDefaults.standard.object(forKey: joystickSizeKey) as? Int ?? 1
        joystickSizePreset = min(2, max(0, storedSize))
        let storedOpacity = UserDefaults.standard.object(forKey: joystickOpacityKey) as? Double ?? 1.0
        joystickOpacity = min(1.0, max(0.35, storedOpacity))
        let seenIntro = UserDefaults.standard.bool(forKey: introKey)
        screen = seenIntro ? .title : .intro
        syncFromCloud()
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.syncFromCloud()
                self.bestScoresRevision += 1
            }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    var hasCompletedTutorial: Bool {
        get { UserDefaults.standard.bool(forKey: tutorialKey) }
        set { UserDefaults.standard.set(newValue, forKey: tutorialKey) }
    }

    var hasSeenLoreIntro: Bool {
        get { UserDefaults.standard.bool(forKey: introKey) }
        set { UserDefaults.standard.set(newValue, forKey: introKey) }
    }

    var isGameplayFrozen: Bool {
        isPaused || isPausedForUpgrade || isTutorialActive || outcome != nil
    }

    /// Publishes a HUD refresh. High-frequency writers should leave `force` false.
    func publishHUD(force: Bool = false) {
        let now = CACurrentMediaTime()
        if force || now - lastHUDPublishTime >= hudPublishInterval {
            lastHUDPublishTime = now
            hudRevision &+= 1
        }
    }

    var currentStore: StoreLevel? {
        if case .playing(let id) = screen { return StoreLevel.byId(id) }
        return nil
    }

    private func resetGameState() {
        outcome = nil
        isPausedForUpgrade = false
        isPaused = false
        isTutorialActive = false
        isAimingCoupon = false
        upgradeQueue = []
        upgradeOffers = []
        pendingStoreForDifficulty = nil
    }

    func goTitle() {
        resetGameState()
        screen = .title
        AudioManager.shared.playMusic()
    }

    func completeLoreIntro() {
        hasSeenLoreIntro = true
        goTitle()
    }

    func requestLoreIntroReplay() {
        resetGameState()
        hasSeenLoreIntro = false
        screen = .intro
    }

    func goHowToPlay() {
        howToPlayReturn = (screen == .settings) ? .settings : .title
        resetGameState()
        screen = .howToPlay
    }

    func leaveHowToPlay() {
        if howToPlayReturn == .settings {
            screen = .settings
        } else {
            goTitle()
        }
    }

    func goSettings() {
        settingsReturn = (screen == .levelSelect) ? .levelSelect : .title
        resetGameState()
        screen = .settings
    }

    func leaveSettings() {
        if settingsReturn == .levelSelect {
            goLevelSelect()
        } else {
            goTitle()
        }
    }

    func goLevelSelect() {
        resetGameState()
        moveVector = .zero
        screen = .levelSelect
    }

    func startStore(_ store: StoreLevel) {
        budget = store.startingBudget
        startingBudget = store.startingBudget
        timeRemaining = store.isEndless ? 0 : store.duration
        runElapsed = 0
        xp = 0
        xpToNext = 12
        playerLevel = 1
        couponCooldown = 0
        couponMaxCooldown = 4.5
        isPausedForUpgrade = false
        isPaused = false
        isAimingCoupon = false
        upgradeOffers = []
        upgradeQueue = []
        outcome = nil
        weapons = [OwnedWeapon(kind: store.startingWeapon, level: 1)]
        moveSpeedMultiplier = 1
        willpowerMultiplier = 1
        pitchBanner = ""
        pickupToast = ""
        luresDeployed = 0
        moveVector = .zero
        couponAimWorld = nil
        couponDeployRequested = false
        runID = UUID()
        pendingStoreForDifficulty = nil
        isTutorialActive = !hasCompletedTutorial && !store.isEndless
        screen = .playing(storeId: store.id)
        publishHUD(force: true)
        AudioManager.shared.playMusic()
    }

    func completeTutorial() {
        hasCompletedTutorial = true
        isTutorialActive = false
    }

    func skipTutorial() {
        completeTutorial()
    }

    func requestTutorialReplay() {
        hasCompletedTutorial = false
    }

    func resetUnlocks() {
        unlockedStoreIndex = 0
        mallCleared = false
        UserDefaults.standard.set(0, forKey: unlockedKey)
        UserDefaults.standard.set(false, forKey: mallClearedKey)
        NSUbiquitousKeyValueStore.default.set(Int64(0), forKey: unlockedKey)
        NSUbiquitousKeyValueStore.default.set(false, forKey: mallClearedKey)
    }

    func togglePause() {
        guard outcome == nil, !isPausedForUpgrade, !isTutorialActive else { return }
        isPaused.toggle()
        if isPaused {
            isAimingCoupon = false
            couponAimWorld = nil
            couponDeployRequested = false
        }
    }

    func resume() {
        isPaused = false
    }

    /// Called when the app resigns active mid-run.
    func pauseForBackground() {
        guard case .playing = screen else { return }
        guard outcome == nil, !isPausedForUpgrade, !isTutorialActive else { return }
        isPaused = true
        isAimingCoupon = false
        couponAimWorld = nil
        couponDeployRequested = false
    }

    func unlockNextIfNeeded(clearedStoreId: String) {
        guard let idx = StoreLevel.all.firstIndex(where: { $0.id == clearedStoreId }) else { return }
        let next = idx + 1
        if next > unlockedStoreIndex && next < StoreLevel.all.count {
            unlockedStoreIndex = next
            UserDefaults.standard.set(unlockedStoreIndex, forKey: unlockedKey)
            NSUbiquitousKeyValueStore.default.set(Int64(unlockedStoreIndex), forKey: unlockedKey)
        } else if next >= StoreLevel.all.count {
            unlockedStoreIndex = max(unlockedStoreIndex, StoreLevel.all.count - 1)
            UserDefaults.standard.set(unlockedStoreIndex, forKey: unlockedKey)
            NSUbiquitousKeyValueStore.default.set(Int64(unlockedStoreIndex), forKey: unlockedKey)
            mallCleared = true
            UserDefaults.standard.set(true, forKey: mallClearedKey)
            NSUbiquitousKeyValueStore.default.set(true, forKey: mallClearedKey)
        }
    }

    func beginCouponAim() {
        guard couponCooldown <= 0, outcome == nil, !isPausedForUpgrade, !isPaused, !isTutorialActive else { return }
        guard !isAimingCoupon else { return }
        isAimingCoupon = true
        couponDeployRequested = false
    }

    func cancelCouponAim() {
        isAimingCoupon = false
        couponAimWorld = nil
        couponDeployRequested = false
    }

    func requestCouponDeploy() {
        guard isAimingCoupon, couponCooldown <= 0 else {
            cancelCouponAim()
            return
        }
        couponDeployRequested = true
    }

    func noteLureDeployed() {
        luresDeployed += 1
    }

    func presentUpgrades(_ offers: [UpgradeOffer]) {
        isAimingCoupon = false
        if isPausedForUpgrade {
            upgradeQueue.append(offers)
            return
        }
        upgradeOffers = offers
        isPausedForUpgrade = true
        AudioManager.shared.playSFX(.levelup)
        Haptics.levelUp()
    }

    func applyUpgrade(_ offer: UpgradeOffer) {
        switch offer.kind {
        case .unlockWeapon:
            if let w = offer.weapon, !weapons.contains(where: { $0.kind == w }) {
                weapons.append(OwnedWeapon(kind: w, level: 1))
                showToast("New weapon: \(w.displayName)")
            }
        case .weaponLevel:
            if let w = offer.weapon, let i = weapons.firstIndex(where: { $0.kind == w }) {
                weapons[i].level += 1
                showToast("\(w.displayName) → Lv\(weapons[i].level)")
            }
        case .moveSpeed:
            moveSpeedMultiplier += 0.12
            showToast("Move speed +12%")
        case .couponCooldown:
            couponMaxCooldown = max(1.5, couponMaxCooldown * 0.8)
            showToast("Faster coupons")
        case .willpower:
            willpowerMultiplier = max(0.4, willpowerMultiplier * 0.85)
            showToast("Friend resists pitches better")
        case .budgetRefill:
            budget = min(startingBudget, budget + startingBudget * 0.12)
            publishHUD(force: true)
            showToast("Budget topped up")
        }
        AudioManager.shared.playSFX(.ui)
        Haptics.ui()

        if let next = upgradeQueue.first {
            upgradeQueue.removeFirst()
            upgradeOffers = next
            isPausedForUpgrade = true
            AudioManager.shared.playSFX(.levelup)
            Haptics.levelUp()
        } else {
            isPausedForUpgrade = false
            upgradeOffers = []
        }
    }

    func endRun(won: Bool, storeId: String) {
        guard outcome == nil else { return }
        isAimingCoupon = false
        isPaused = false
        isTutorialActive = false
        upgradeQueue = []
        outcome = won ? .won : .lost
        AudioManager.shared.playSFX(won ? .win : .lose)
        if won {
            Haptics.win()
        } else {
            Haptics.lose()
        }

        let store = StoreLevel.byId(storeId)
        let baseId = StoreLevel.baseId(from: storeId)
        if store?.isEndless == true {
            recordEndlessBest(seconds: runElapsed)
            GameCenterManager.shared.submitEndlessScore(seconds: runElapsed)
            GameCenterManager.shared.evaluateEndlessAchievements(
                seconds: runElapsed,
                luresDeployed: luresDeployed,
                playerLevel: playerLevel
            )
        } else if won {
            unlockNextIfNeeded(clearedStoreId: baseId)
            recordBestBudget(budget, storeId: baseId)
            GameCenterManager.shared.submitWinScore(budget: budget, storeId: baseId)
            GameCenterManager.shared.evaluateAchievements(
                budget: budget,
                playerLevel: playerLevel,
                storeId: baseId,
                luresDeployed: luresDeployed
            )
        }
    }

    // MARK: - Local bests

    func bestBudget(for storeId: String) -> CGFloat {
        CGFloat(UserDefaults.standard.double(forKey: bestBudgetPrefix + storeId))
    }

    func bestEndlessSeconds() -> TimeInterval {
        UserDefaults.standard.double(forKey: bestEndlessKey)
    }

    private func recordBestBudget(_ value: CGFloat, storeId: String) {
        let key = bestBudgetPrefix + storeId
        let previous = UserDefaults.standard.double(forKey: key)
        if Double(value) > previous {
            UserDefaults.standard.set(Double(value), forKey: key)
            NSUbiquitousKeyValueStore.default.set(Double(value), forKey: key)
            bestScoresRevision += 1
        }
    }

    private func recordEndlessBest(seconds: TimeInterval) {
        let previous = UserDefaults.standard.double(forKey: bestEndlessKey)
        if seconds > previous {
            UserDefaults.standard.set(seconds, forKey: bestEndlessKey)
            NSUbiquitousKeyValueStore.default.set(seconds, forKey: bestEndlessKey)
            bestScoresRevision += 1
        }
    }

    func formattedBest(for store: StoreLevel) -> String? {
        if store.isEndless {
            let best = bestEndlessSeconds()
            guard best > 0 else { return nil }
            return "Best \(formatClock(best))"
        }
        let best = bestBudget(for: store.id)
        guard best > 0 else { return nil }
        return String(format: "Best $%.2f", Double(best))
    }

    func formatClock(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    func showToast(_ text: String) {
        pickupToast = text
        toastClearTask?.cancel()
        toastClearTask = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if !Task.isCancelled {
                pickupToast = ""
            }
        }
    }

    private func syncFromCloud() {
        let kvs = NSUbiquitousKeyValueStore.default
        let cloudUnlocked = Int(kvs.longLong(forKey: unlockedKey))
        if cloudUnlocked > unlockedStoreIndex {
            unlockedStoreIndex = cloudUnlocked
            UserDefaults.standard.set(cloudUnlocked, forKey: unlockedKey)
        }
        if kvs.bool(forKey: mallClearedKey), !mallCleared {
            mallCleared = true
            UserDefaults.standard.set(true, forKey: mallClearedKey)
        }
        for store in StoreLevel.all {
            let key = bestBudgetPrefix + store.id
            let cloudBest = kvs.double(forKey: key)
            if cloudBest > UserDefaults.standard.double(forKey: key) {
                UserDefaults.standard.set(cloudBest, forKey: key)
            }
        }
        let cloudEndless = kvs.double(forKey: bestEndlessKey)
        if cloudEndless > UserDefaults.standard.double(forKey: bestEndlessKey) {
            UserDefaults.standard.set(cloudEndless, forKey: bestEndlessKey)
        }
    }
}
