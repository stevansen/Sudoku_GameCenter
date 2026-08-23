import Testing
@testable import SudokuGameCenter
import SudokuKit

@Suite("Identifiers")
struct IdentifierTests {
    /// Apple caps an app's achievement points at 1000 for its whole lifetime.
    /// The original plan added up to 1025, which would have been rejected — this
    /// test is here so that cannot happen again unnoticed.
    @Test func achievementPointsStayInsideApplesBudget() {
        #expect(AchievementID.totalPoints <= AchievementID.pointBudget)
        #expect(AchievementID.totalPoints == 880,
                "budget changed — update docs/gamecenter-setup.md to match")
    }

    @Test func thereAreNoDuplicateIdentifiers() {
        #expect(Set(AchievementID.allCases.map(\.rawValue)).count == AchievementID.allCases.count)
        #expect(Set(LeaderboardID.allCases.map(\.rawValue)).count == LeaderboardID.allCases.count)
    }

    @Test func everyIdentifierUsesTheAgreedPrefix() {
        for id in AchievementID.allCases {
            #expect(id.rawValue.hasPrefix("com.sudoku.achievement."), "\(id.rawValue)")
        }
        for id in LeaderboardID.allCases {
            #expect(id.rawValue.hasPrefix("com.sudoku.leaderboard."), "\(id.rawValue)")
        }
    }

    @Test func everyDifficultyHasItsOwnTimeBoardAndMasteryAchievement() {
        let boards = Difficulty.allCases.map { LeaderboardID.bestTime(for: $0) }
        let masters = Difficulty.allCases.map { AchievementID.master(for: $0) }
        #expect(Set(boards).count == 5)
        #expect(Set(masters).count == 5)
    }

    @Test func thereAre30AchievementsAnd9Leaderboards() {
        // The counts App Store Connect has to match.
        #expect(AchievementID.allCases.count == 30)
        #expect(LeaderboardID.allCases.count == 9)
    }
}
