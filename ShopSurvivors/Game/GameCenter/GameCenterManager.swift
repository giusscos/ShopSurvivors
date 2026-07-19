import Combine
import GameKit
import UIKit

// MARK: - Leaderboard & Achievement IDs

enum GameCenterID {
    enum Leaderboard {
        static let electronics = "leaderboard_electronics_budget"
        static let fashion     = "leaderboard_fashion_budget"
        static let grocery     = "leaderboard_grocery_budget"
        static let endless     = "leaderboard_endless_survival"

        static func forStoreId(_ id: String) -> String? {
            switch id {
            case "electronics": return electronics
            case "fashion":     return fashion
            case "grocery":     return grocery
            case "endless":     return endless
            default:            return nil
            }
        }
    }

    enum Achievement {
        static let firstEscape = "achievement_first_escape"
        static let mallMaster  = "achievement_mall_master"
        static let bigSaver    = "achievement_big_saver"
        static let highRoller  = "achievement_high_roller"
        static let veteran     = "achievement_veteran"
        static let couponKing  = "achievement_coupon_king"
        static let nightOwl    = "achievement_night_owl"
    }
}

// MARK: - Manager

@MainActor
final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    @Published var isAuthenticated = false
    @Published var authFailed = false
    @Published var statusMessage: String?

    private let totalWinsKey = "gcTotalWins"

    private override init() { super.init() }

    // MARK: - Authentication

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let vc = viewController {
                    self.authFailed = false
                    self.statusMessage = nil
                    self.presentFromRoot(vc)
                } else if let error {
                    self.isAuthenticated = false
                    self.authFailed = true
                    self.statusMessage = "Game Center unavailable. Scores stay on this device."
                    print("Game Center auth error: \(error.localizedDescription)")
                } else {
                    self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                    self.authFailed = !self.isAuthenticated
                    self.statusMessage = self.isAuthenticated
                        ? nil
                        : "Sign in to Game Center to sync leaderboards."
                }
            }
        }
    }

    func retryAuthentication() {
        statusMessage = "Connecting to Game Center…"
        authFailed = false
        authenticate()
    }

    // MARK: - Score Submission
    // Campaign score = budget in cents (e.g. $50.45 -> 5045).
    // Endless score = whole seconds survived.

    func submitWinScore(budget: CGFloat, storeId: String) {
        guard GKLocalPlayer.local.isAuthenticated,
              let boardID = GameCenterID.Leaderboard.forStoreId(storeId) else { return }
        let score = Int(budget * 100)
        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [boardID]
                )
            } catch {
                print("Score submit failed: \(error.localizedDescription)")
            }
        }
    }

    func submitEndlessScore(seconds: TimeInterval) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let score = max(0, Int(seconds))
        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [GameCenterID.Leaderboard.endless]
                )
            } catch {
                print("Endless score submit failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Achievements

    func evaluateAchievements(budget: CGFloat, playerLevel: Int, storeId: String, luresDeployed: Int) {
        report(GameCenterID.Achievement.firstEscape)

        if budget >= 80 { report(GameCenterID.Achievement.bigSaver) }
        if playerLevel >= 8 { report(GameCenterID.Achievement.highRoller) }
        if storeId == StoreLevel.all.last?.id { report(GameCenterID.Achievement.mallMaster) }
        if luresDeployed >= 10 { report(GameCenterID.Achievement.couponKing) }

        let wins = UserDefaults.standard.integer(forKey: totalWinsKey) + 1
        UserDefaults.standard.set(wins, forKey: totalWinsKey)
        report(GameCenterID.Achievement.veteran, percent: min(Double(wins) / 5.0 * 100, 100))
    }

    func evaluateEndlessAchievements(seconds: TimeInterval, luresDeployed: Int, playerLevel: Int) {
        if seconds >= 120 { report(GameCenterID.Achievement.nightOwl) }
        if luresDeployed >= 10 { report(GameCenterID.Achievement.couponKing) }
        if playerLevel >= 8 { report(GameCenterID.Achievement.highRoller) }
    }

    private func report(_ id: String, percent: Double = 100) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percent
        achievement.showsCompletionBanner = true
        Task {
            do {
                try await GKAchievement.report([achievement])
            } catch {
                print("Achievement report failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - UI Presentation

    @discardableResult
    func showLeaderboard(storeId: String) -> Bool {
        guard GKLocalPlayer.local.isAuthenticated else {
            statusMessage = "Sign in to Game Center to view leaderboards."
            authFailed = true
            retryAuthentication()
            return false
        }
        let id = GameCenterID.Leaderboard.forStoreId(storeId) ?? GameCenterID.Leaderboard.electronics
        let vc = GKGameCenterViewController(leaderboardID: id, playerScope: .global, timeScope: .allTime)
        vc.gameCenterDelegate = self
        presentFromRoot(vc)
        return true
    }

    @discardableResult
    func showDashboard() -> Bool {
        guard GKLocalPlayer.local.isAuthenticated else {
            statusMessage = "Sign in to Game Center to open the dashboard."
            authFailed = true
            retryAuthentication()
            return false
        }
        let vc = GKGameCenterViewController(state: .dashboard)
        vc.gameCenterDelegate = self
        presentFromRoot(vc)
        return true
    }

    private func presentFromRoot(_ vc: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(vc, animated: true)
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
