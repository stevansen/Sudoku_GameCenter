import Foundation
import SudokuKit

/// Works out which achievements a finished puzzle moved, and how far.
///
/// Pure: no GameKit, no I/O, no clock of its own. That is deliberate — the rules
/// are the part that can be wrong, and this way every one of them is a test
/// rather than something you find out about from a player.
public enum AchievementEvaluator {
    public static func progress(
        for event: SolveEvent, totals: PlayerTotals, calendar: Calendar = .current
    ) -> [AchievementProgress] {
        var result: [AchievementProgress] = []

        func add(_ id: AchievementID, _ percent: Double) {
            guard percent > 0 else { return }
            result.append(AchievementProgress(id: id, percentComplete: percent))
        }
        func fraction(_ value: Int, of target: Int) -> Double {
            Double(value) / Double(target) * 100
        }

        // Volume
        add(.firstSolve, totals.solvedCount >= 1 ? 100 : 0)
        add(.solve10, fraction(totals.solvedCount, of: 10))
        add(.solve50, fraction(totals.solvedCount, of: 50))
        add(.solve250, fraction(totals.solvedCount, of: 250))
        add(.solve1000, fraction(totals.solvedCount, of: 1000))
        add(.points10k, fraction(totals.totalPoints, of: 10_000))
        add(.points100k, fraction(totals.totalPoints, of: 100_000))

        // Mastery of the tier just played
        let solvedInTier = totals.solvedByDifficulty[event.difficulty] ?? 0
        add(.master(for: event.difficulty), fraction(solvedInTier, of: 25))

        // Skill
        if event.mistakes == 0 { add(.flawless, 100) }
        if event.difficulty == .expert && event.mistakes == 0 && event.hintsUsed == 0 {
            add(.flawlessExpert, 100)
        }
        add(.noHints50, fraction(totals.solvedWithoutHints, of: 50))
        if event.techniques.contains(.xWing) { add(.techniqueXWing, 100) }

        // Speed
        if event.difficulty == .easy && event.seconds < 180 { add(.speedEasy, 100) }
        if event.difficulty == .hard && event.seconds < 600 { add(.speedHard, 100) }
        if event.difficulty == .evil && event.seconds < 1800 { add(.speedEvil, 100) }

        // Habit
        add(.streak7, fraction(totals.streakDays, of: 7))
        add(.streak30, fraction(totals.streakDays, of: 30))
        add(.streak365, fraction(totals.streakDays, of: 365))
        add(.perfectWeek, fraction(totals.flawlessStreakDays, of: 7))
        if event.isDaily {
            add(.firstDaily, 100)
            add(.daily10, fraction(totals.dailySolved, of: 10))
            add(.daily100, fraction(totals.dailySolved, of: 100))
        }

        // Time of day. The two do not overlap, so each is its own small discovery.
        let hour = calendar.component(.hour, from: event.completedAt)
        if hour < 4 { add(.nightOwl, 100) }
        if (4..<6).contains(hour) { add(.earlyBird, 100) }

        // Across devices
        let wanted: Set<String> = ["iPhone", "iPad", "Mac"]
        add(.allPlatforms, fraction(totals.platforms.intersection(wanted).count, of: wanted.count))
        if event.finishedOn != event.startedOn { add(.comeback, 100) }

        return result
    }

    /// The scores a finished puzzle produces.
    public static func submissions(
        for event: SolveEvent, totals: PlayerTotals, submittedAt: Date? = nil
    ) -> [ScoreSubmission] {
        let stamp = submittedAt ?? event.completedAt
        var result: [ScoreSubmission] = [
            ScoreSubmission(leaderboard: .totalPoints, value: totals.totalPoints, submittedAt: stamp),
            ScoreSubmission(leaderboard: .weeklyPoints, value: event.pointsScored, submittedAt: stamp),
            ScoreSubmission(leaderboard: .streak, value: totals.streakDays, submittedAt: stamp),
        ]
        // Best time is reported only when this game *is* the best — Game Center
        // keeps the better value anyway, but sending noise makes the queue harder
        // to reason about when something goes wrong.
        if totals.bestSecondsByDifficulty[event.difficulty] == event.seconds {
            result.append(ScoreSubmission(
                leaderboard: .bestTime(for: event.difficulty),
                value: event.seconds, submittedAt: stamp))
        }
        if event.isDaily {
            result.append(ScoreSubmission(
                leaderboard: .daily, value: event.pointsScored, submittedAt: stamp))
        }
        return result
    }
}
