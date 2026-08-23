#if canImport(GameKit)
import Foundation
import GameKit

/// The real thing.
///
/// Authentication is set up once and never blocks: if the player declines or has
/// no connection, every call below turns into a no-op and ``SubmissionQueue``
/// keeps what could not be sent.
public final class GameKitService: GameCenterService {
    public init() {}

    @MainActor
    public func authenticate() async {
        guard !GKLocalPlayer.local.isAuthenticated else { return }
        await withCheckedContinuation { continuation in
            var resumed = false
            GKLocalPlayer.local.authenticateHandler = { viewController, _ in
                if let viewController {
                    Self.present(viewController)
                }
                // Resume on the first callback whatever it says — including the
                // one that only hands over a sign-in screen. Waiting for a final
                // answer would mean waiting for the player to finish typing, and
                // the caller would sit there with the app not yet loaded.
                // The handler fires again later; `isAuthenticated()` is the
                // source of truth from then on.
                if !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
        }
    }

    public func isAuthenticated() async -> Bool {
        await MainActor.run { GKLocalPlayer.local.isAuthenticated }
    }

    public func submit(_ submissions: [ScoreSubmission]) async throws {
        guard await isAuthenticated() else { throw GameCenterError("not signed in") }
        for submission in submissions {
            try await GKLeaderboard.submitScore(
                submission.value, context: 0, player: GKLocalPlayer.local,
                leaderboardIDs: [submission.leaderboard.rawValue])
        }
    }

    public func report(_ progress: [AchievementProgress]) async throws {
        guard await isAuthenticated() else { throw GameCenterError("not signed in") }
        // Reported in one batch: Game Center shows one banner per achievement
        // either way, but a batch is a single round trip.
        let achievements = progress.map { item -> GKAchievement in
            let achievement = GKAchievement(identifier: item.id.rawValue)
            achievement.percentComplete = item.percentComplete
            achievement.showsCompletionBanner = true
            return achievement
        }
        try await GKAchievement.report(achievements)
    }

    public func loadAchievementProgress() async -> [AchievementID: Double] {
        guard await isAuthenticated() else { return [:] }
        guard let achievements = try? await GKAchievement.loadAchievements() else { return [:] }
        return achievements.reduce(into: [:]) { result, achievement in
            guard let id = AchievementID(rawValue: achievement.identifier) else { return }
            result[id] = achievement.percentComplete
        }
    }

    /// Shows the floating Game Center button.
    @MainActor
    public static func showAccessPoint(_ visible: Bool = true) {
        GKAccessPoint.shared.location = .topTrailing
        GKAccessPoint.shared.showHighlights = true
        GKAccessPoint.shared.isActive = visible
    }

    @MainActor
    private static func present(_ viewController: PlatformViewController) {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        root?.present(viewController, animated: true)
        #elseif os(macOS)
        // The controller GameKit hands back conforms to GKViewController at
        // runtime, but is typed as NSViewController.
        guard let dialog = viewController as? (NSViewController & GKViewController) else { return }
        GKDialogController.shared().parentWindow = NSApplication.shared.keyWindow
        GKDialogController.shared().present(dialog)
        #endif
    }
}

#if os(macOS)
import AppKit
public typealias PlatformViewController = NSViewController
#else
import UIKit
public typealias PlatformViewController = UIViewController
#endif
#endif
