import Combine
import GameKit
import UIKit

// MARK: - Leaderboard & Achievement IDs

enum GameCenterID {
    enum Leaderboard {
        static let electronics = "leaderboard_electronics_budget"
        static let fashion     = "leaderboard_fashion_budget"
        static let grocery     = "leaderboard_grocery_budget"

        static func forStoreId(_ id: String) -> String? {
            switch id {
            case "electronics": return electronics
            case "fashion":     return fashion
            case "grocery":     return grocery
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
    }
}

// MARK: - Manager

@MainActor
final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    @Published var isAuthenticated = false

    private let totalWinsKey = "gcTotalWins"

    private override init() { super.init() }

    // MARK: - Authentication

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let vc = viewController {
                    self.presentFromRoot(vc)
                } else {
                    self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                }
            }
        }
    }

    // MARK: - Score Submission
    // Score = budget in cents (e.g. $50.45 -> 5045) for sub-dollar precision.
    // Configure the leaderboard in App Store Connect with "Fixed Point: 2 decimals" formatting.

    func submitWinScore(budget: CGFloat, storeId: String) {
        guard GKLocalPlayer.local.isAuthenticated,
              let boardID = GameCenterID.Leaderboard.forStoreId(storeId) else { return }
        let score = Int(budget * 100)
        Task {
            try? await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [boardID]
            )
        }
    }

    // MARK: - Achievements

    func evaluateAchievements(budget: CGFloat, playerLevel: Int, storeId: String) {
        report(GameCenterID.Achievement.firstEscape)

        if budget >= 80 { report(GameCenterID.Achievement.bigSaver) }
        if playerLevel >= 8 { report(GameCenterID.Achievement.highRoller) }
        if storeId == StoreLevel.all.last?.id { report(GameCenterID.Achievement.mallMaster) }

        let wins = UserDefaults.standard.integer(forKey: totalWinsKey) + 1
        UserDefaults.standard.set(wins, forKey: totalWinsKey)
        report(GameCenterID.Achievement.veteran, percent: min(Double(wins) / 5.0 * 100, 100))
    }

    private func report(_ id: String, percent: Double = 100) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percent
        achievement.showsCompletionBanner = true
        Task { try? await GKAchievement.report([achievement]) }
    }

    // MARK: - UI Presentation

    func showLeaderboard(storeId: String) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let id = GameCenterID.Leaderboard.forStoreId(storeId) ?? GameCenterID.Leaderboard.electronics
        let vc = GKGameCenterViewController(leaderboardID: id, playerScope: .global, timeScope: .allTime)
        vc.gameCenterDelegate = self
        presentFromRoot(vc)
    }

    func showDashboard() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let vc = GKGameCenterViewController(state: .dashboard)
        vc.gameCenterDelegate = self
        presentFromRoot(vc)
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
