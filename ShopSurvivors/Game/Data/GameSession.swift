import Foundation
import Combine
import CoreGraphics

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

    @Published var budget: CGFloat = 100
    @Published var startingBudget: CGFloat = 100
    @Published var timeRemaining: TimeInterval = 120
    @Published var runElapsed: TimeInterval = 0
    @Published var xp: Int = 0
    @Published var xpToNext: Int = 12
    @Published var playerLevel: Int = 1
    @Published var couponCooldown: TimeInterval = 0
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
    @Published var lastDrainFlash: Bool = false
    @Published var runID: UUID = UUID()
    @Published var pickupToast: String = ""
    @Published var luresDeployed: Int = 0
    /// Bumps when local bests change so hub UI refreshes.
    @Published var bestScoresRevision: Int = 0

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
    private let bestBudgetPrefix = "bestBudget_"
    private let bestEndlessKey = "bestEndlessSeconds"
    private var toastClearTask: Task<Void, Never>?

    init() {
        unlockedStoreIndex = UserDefaults.standard.integer(forKey: unlockedKey)
        mallCleared = UserDefaults.standard.bool(forKey: mallClearedKey)
        let seenIntro = UserDefaults.standard.bool(forKey: introKey)
        screen = seenIntro ? .title : .intro
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
        isTutorialActive = !hasCompletedTutorial && !store.isEndless
        screen = .playing(storeId: store.id)
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
        } else if next >= StoreLevel.all.count {
            unlockedStoreIndex = max(unlockedStoreIndex, StoreLevel.all.count - 1)
            UserDefaults.standard.set(unlockedStoreIndex, forKey: unlockedKey)
            mallCleared = true
            UserDefaults.standard.set(true, forKey: mallClearedKey)
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
        if store?.isEndless == true {
            recordEndlessBest(seconds: runElapsed)
            GameCenterManager.shared.submitEndlessScore(seconds: runElapsed)
            GameCenterManager.shared.evaluateEndlessAchievements(
                seconds: runElapsed,
                luresDeployed: luresDeployed,
                playerLevel: playerLevel
            )
        } else if won {
            unlockNextIfNeeded(clearedStoreId: storeId)
            recordBestBudget(budget, storeId: storeId)
            GameCenterManager.shared.submitWinScore(budget: budget, storeId: storeId)
            GameCenterManager.shared.evaluateAchievements(
                budget: budget,
                playerLevel: playerLevel,
                storeId: storeId,
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
            bestScoresRevision += 1
        }
    }

    private func recordEndlessBest(seconds: TimeInterval) {
        let previous = UserDefaults.standard.double(forKey: bestEndlessKey)
        if seconds > previous {
            UserDefaults.standard.set(seconds, forKey: bestEndlessKey)
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
}
