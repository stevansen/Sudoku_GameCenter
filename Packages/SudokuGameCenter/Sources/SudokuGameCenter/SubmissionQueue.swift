import Foundation

/// Holds what could not be sent and sends it on the next opportunity.
///
/// Scores earned offline are still earned. Without this they would simply be
/// lost, which is the kind of thing players notice and never forgive.
public actor SubmissionQueue {
    private struct Pending: Codable, Sendable {
        var scores: [ScoreSubmission] = []
        var achievements: [AchievementProgress] = []

        var isEmpty: Bool { scores.isEmpty && achievements.isEmpty }
    }

    private let fileURL: URL
    private var pending: Pending

    public init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sudoku", isDirectory: true)
        self.fileURL = base.appendingPathComponent("gamecenter-queue.json")
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode(Pending.self, from: data) {
            self.pending = stored
        } else {
            self.pending = Pending()
        }
    }

    public var pendingScoreCount: Int { pending.scores.count }
    public var pendingAchievementCount: Int { pending.achievements.count }

    /// Sends what it can and keeps the rest.
    public func send(
        scores: [ScoreSubmission], achievements: [AchievementProgress],
        using service: any GameCenterService
    ) async {
        pending.scores += scores
        pending.achievements += achievements
        await flush(using: service)
    }

    /// Retries everything held. Safe to call on every launch and after signing in.
    public func flush(using service: any GameCenterService) async {
        guard !pending.isEmpty else { return }
        guard await service.isAuthenticated() else {
            persist()
            return
        }

        // Only the highest value per leaderboard and per achievement is worth
        // sending — a backlog of ten scores for the same board is nine wasted
        // round trips.
        let scores = Self.bestPerLeaderboard(pending.scores)
        let achievements = Self.furthestPerAchievement(pending.achievements)

        do {
            if !scores.isEmpty { try await service.submit(scores) }
            if !achievements.isEmpty { try await service.report(achievements) }
            pending = Pending()
        } catch {
            // Keep the compacted form: same meaning, less to retry.
            pending = Pending(scores: scores, achievements: achievements)
        }
        persist()
    }

    static func bestPerLeaderboard(_ scores: [ScoreSubmission]) -> [ScoreSubmission] {
        var best: [LeaderboardID: ScoreSubmission] = [:]
        for score in scores {
            let existing = best[score.leaderboard]
            let better = switch score.leaderboard {
            // Times are better when smaller; everything else when bigger.
            case .bestTimeEasy, .bestTimeMedium, .bestTimeHard, .bestTimeExpert, .bestTimeEvil:
                existing.map { score.value < $0.value } ?? true
            default:
                existing.map { score.value > $0.value } ?? true
            }
            if better { best[score.leaderboard] = score }
        }
        return best.values.sorted { $0.leaderboard.rawValue < $1.leaderboard.rawValue }
    }

    static func furthestPerAchievement(_ progress: [AchievementProgress]) -> [AchievementProgress] {
        var furthest: [AchievementID: AchievementProgress] = [:]
        for item in progress {
            if (furthest[item.id]?.percentComplete ?? -1) < item.percentComplete {
                furthest[item.id] = item
            }
        }
        return furthest.values.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    private func persist() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if pending.isEmpty {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        guard let data = try? JSONEncoder().encode(pending) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
