import Foundation
import SudokuKit

/// The facts about one finished puzzle that Game Center cares about.
public struct SolveEvent: Sendable, Hashable, Codable {
    public var difficulty: Difficulty
    public var seconds: Int
    public var mistakes: Int
    public var hintsUsed: Int
    public var pointsScored: Int
    public var techniques: [Technique]
    public var completedAt: Date
    public var isDaily: Bool
    /// Where the game was finished, and where it was started — different values
    /// mean it travelled between devices.
    public var finishedOn: String
    public var startedOn: String

    public init(
        difficulty: Difficulty, seconds: Int, mistakes: Int, hintsUsed: Int,
        pointsScored: Int, techniques: [Technique], completedAt: Date,
        isDaily: Bool, finishedOn: String, startedOn: String
    ) {
        self.difficulty = difficulty
        self.seconds = seconds
        self.mistakes = mistakes
        self.hintsUsed = hintsUsed
        self.pointsScored = pointsScored
        self.techniques = techniques
        self.completedAt = completedAt
        self.isDaily = isDaily
        self.finishedOn = finishedOn
        self.startedOn = startedOn
    }
}

/// The player's running totals, as far as achievements need them.
public struct PlayerTotals: Sendable, Hashable, Codable {
    public var totalPoints: Int
    public var solvedCount: Int
    public var solvedByDifficulty: [Difficulty: Int]
    public var solvedWithoutHints: Int
    public var dailySolved: Int
    public var streakDays: Int
    public var flawlessStreakDays: Int
    public var bestSecondsByDifficulty: [Difficulty: Int]
    /// Distinct device kinds a puzzle has been solved on: `iPhone`, `iPad`, `Mac`, …
    public var platforms: Set<String>

    public init(
        totalPoints: Int = 0, solvedCount: Int = 0,
        solvedByDifficulty: [Difficulty: Int] = [:], solvedWithoutHints: Int = 0,
        dailySolved: Int = 0, streakDays: Int = 0, flawlessStreakDays: Int = 0,
        bestSecondsByDifficulty: [Difficulty: Int] = [:], platforms: Set<String> = []
    ) {
        self.totalPoints = totalPoints
        self.solvedCount = solvedCount
        self.solvedByDifficulty = solvedByDifficulty
        self.solvedWithoutHints = solvedWithoutHints
        self.dailySolved = dailySolved
        self.streakDays = streakDays
        self.flawlessStreakDays = flawlessStreakDays
        self.bestSecondsByDifficulty = bestSecondsByDifficulty
        self.platforms = platforms
    }
}

/// How far along one achievement is.
public struct AchievementProgress: Sendable, Hashable, Codable {
    public let id: AchievementID
    /// 0...100. Game Center keeps the highest value ever reported, so sending a
    /// lower one is harmless — but never useful.
    public let percentComplete: Double

    public init(id: AchievementID, percentComplete: Double) {
        self.id = id
        self.percentComplete = min(100, max(0, percentComplete))
    }

    public var isComplete: Bool { percentComplete >= 100 }
}

/// One score waiting to be sent.
public struct ScoreSubmission: Sendable, Hashable, Codable {
    public let leaderboard: LeaderboardID
    public let value: Int
    public let submittedAt: Date

    public init(leaderboard: LeaderboardID, value: Int, submittedAt: Date = .now) {
        self.leaderboard = leaderboard
        self.value = value
        self.submittedAt = submittedAt
    }
}

extension LeaderboardID: Codable {}
extension AchievementID: Codable {}
