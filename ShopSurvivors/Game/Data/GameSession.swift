import Foundation
import Combine
import CoreGraphics

enum AppScreen: Equatable {
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
    @Published var screen: AppScreen = .title
    @Published var unlockedStoreIndex: Int = 0

    @Published var budget: CGFloat = 100
    @Published var startingBudget: CGFloat = 100
    @Published var timeRemaining: TimeInterval = 120
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

    /// Joystick input written by SwiftUI, read by SpriteKit each frame.
    var moveVector: CGVector = .zero
    /// Latest camera center in world space (written by GameScene).
    var cameraWorldPosition: CGPoint = .zero
    /// World position to place coupon when aiming ends (set by GameScene / UI).
    var couponAimWorld: CGPoint?
    var couponDeployRequested: Bool = false

    private let unlockedKey = "unlockedStoreIndex"
    private let tutorialKey = "hasCompletedTutorial"
    private var toastClearTask: Task<Void, Never>?

    init() {
        unlockedStoreIndex = UserDefaults.standard.integer(forKey: unlockedKey)
    }

    var hasCompletedTutorial: Bool {
        get { UserDefaults.standard.bool(forKey: tutorialKey) }
        set { UserDefaults.standard.set(newValue, forKey: tutorialKey) }
    }

    var isGameplayFrozen: Bool {
        isPaused || isPausedForUpgrade || isTutorialActive || outcome != nil
    }

    func goTitle() {
        screen = .title
        outcome = nil
        isPausedForUpgrade = false
        isPaused = false
        isTutorialActive = false
        isAimingCoupon = false
        AudioManager.shared.playMusic()
    }

    func goHowToPlay() {
        screen = .howToPlay
        outcome = nil
        isPausedForUpgrade = false
        isPaused = false
        isTutorialActive = false
        isAimingCoupon = false
    }

    func goSettings() {
        screen = .settings
        outcome = nil
        isPausedForUpgrade = false
        isPaused = false
        isTutorialActive = false
        isAimingCoupon = false
    }

    func goLevelSelect() {
        screen = .levelSelect
        outcome = nil
        isPausedForUpgrade = false
        isPaused = false
        isTutorialActive = false
        isAimingCoupon = false
        moveVector = .zero
    }

    func startStore(_ store: StoreLevel) {
        budget = store.startingBudget
        startingBudget = store.startingBudget
        timeRemaining = store.duration
        xp = 0
        xpToNext = 12
        playerLevel = 1
        couponCooldown = 0
        couponMaxCooldown = 4.5
        isPausedForUpgrade = false
        isPaused = false
        isAimingCoupon = false
        upgradeOffers = []
        outcome = nil
        weapons = [OwnedWeapon(kind: store.startingWeapon, level: 1)]
        moveSpeedMultiplier = 1
        willpowerMultiplier = 1
        pitchBanner = ""
        pickupToast = ""
        moveVector = .zero
        couponAimWorld = nil
        couponDeployRequested = false
        runID = UUID()
        isTutorialActive = !hasCompletedTutorial
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
        UserDefaults.standard.set(0, forKey: unlockedKey)
    }

    func togglePause() {
        guard outcome == nil, !isPausedForUpgrade, !isTutorialActive else { return }
        isPaused.toggle()
        if isPaused {
            isAimingCoupon = false
            couponAimWorld = nil
            couponDeployRequested = false
        }
        // Keep music playing during pause — only the Music toggle mutes it.
    }

    func resume() {
        isPaused = false
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

    func presentUpgrades(_ offers: [UpgradeOffer]) {
        isAimingCoupon = false
        upgradeOffers = offers
        isPausedForUpgrade = true
        AudioManager.shared.playSFX(.levelup)
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
        isPausedForUpgrade = false
        upgradeOffers = []
        AudioManager.shared.playSFX(.ui)
    }

    func endRun(won: Bool, storeId: String) {
        guard outcome == nil else { return }
        isAimingCoupon = false
        isPaused = false
        isTutorialActive = false
        outcome = won ? .won : .lost
        AudioManager.shared.playSFX(won ? .win : .lose)
        if won { unlockNextIfNeeded(clearedStoreId: storeId) }
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
