import Foundation
import Testing
@testable import SudokuGameCenter
import SudokuKit

@Suite("Achievement rules")
struct AchievementEvaluatorTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func date(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: hour))!
    }

    static func event(
        difficulty: Difficulty = .medium, seconds: Int = 600, mistakes: Int = 0,
        hints: Int = 0, points: Int = 250, techniques: [Technique] = [.nakedSingle],
        hour: Int = 12, isDaily: Bool = false,
        finishedOn: String = "iPhone", startedOn: String = "iPhone"
    ) -> SolveEvent {
        SolveEvent(
            difficulty: difficulty, seconds: seconds, mistakes: mistakes, hintsUsed: hints,
            pointsScored: points, techniques: techniques, completedAt: date(hour: hour),
            isDaily: isDaily, finishedOn: finishedOn, startedOn: startedOn)
    }

    func percent(_ id: AchievementID, _ progress: [AchievementProgress]) -> Double? {
        progress.first { $0.id == id }?.percentComplete
    }

    func evaluate(_ event: SolveEvent, _ totals: PlayerTotals) -> [AchievementProgress] {
        AchievementEvaluator.progress(for: event, totals: totals, calendar: Self.calendar)
    }

    @Test func theFirstSolveUnlocksTheFirstAchievement() {
        let progress = evaluate(Self.event(), PlayerTotals(solvedCount: 1))
        #expect(percent(.firstSolve, progress) == 100)
        #expect(percent(.solve10, progress) == 10)
        #expect(percent(.solve1000, progress) == 0.1)
    }

    @Test func volumeAchievementsCapAtOneHundred() {
        let progress = evaluate(Self.event(), PlayerTotals(totalPoints: 250_000, solvedCount: 5_000))
        #expect(percent(.solve1000, progress) == 100)
        #expect(percent(.points100k, progress) == 100)
    }

    @Test func masteryCountsOnlyTheTierThatWasPlayed() {
        let totals = PlayerTotals(solvedByDifficulty: [.expert: 5, .easy: 25])
        let progress = evaluate(Self.event(difficulty: .expert), totals)
        #expect(percent(.expertMaster, progress) == 20)
        #expect(percent(.easyMaster, progress) == nil, "a tier not played must not be reported")
    }

    @Test func flawlessNeedsNoMistakesAndTheExpertVersionNoHintsEither() {
        #expect(percent(.flawless, evaluate(Self.event(mistakes: 0), PlayerTotals())) == 100)
        #expect(percent(.flawless, evaluate(Self.event(mistakes: 1), PlayerTotals())) == nil)

        let clean = Self.event(difficulty: .expert, mistakes: 0, hints: 0)
        #expect(percent(.flawlessExpert, evaluate(clean, PlayerTotals())) == 100)
        let guided = Self.event(difficulty: .expert, mistakes: 0, hints: 1)
        #expect(percent(.flawlessExpert, evaluate(guided, PlayerTotals())) == nil)
    }

    @Test func speedAchievementsBelongToTheirOwnTier() {
        #expect(percent(.speedEasy, evaluate(Self.event(difficulty: .easy, seconds: 179), PlayerTotals())) == 100)
        #expect(percent(.speedEasy, evaluate(Self.event(difficulty: .easy, seconds: 181), PlayerTotals())) == nil)
        // A fast easy game must not unlock the hard one.
        #expect(percent(.speedHard, evaluate(Self.event(difficulty: .easy, seconds: 10), PlayerTotals())) == nil)
        #expect(percent(.speedEvil, evaluate(Self.event(difficulty: .evil, seconds: 1_700), PlayerTotals())) == 100)
    }

    @Test func theTwoTimeOfDayAchievementsDoNotOverlap() {
        let night = evaluate(Self.event(hour: 2), PlayerTotals())
        #expect(percent(.nightOwl, night) == 100)
        #expect(percent(.earlyBird, night) == nil)

        let morning = evaluate(Self.event(hour: 5), PlayerTotals())
        #expect(percent(.earlyBird, morning) == 100)
        #expect(percent(.nightOwl, morning) == nil)

        #expect(percent(.nightOwl, evaluate(Self.event(hour: 12), PlayerTotals())) == nil)
    }

    @Test func dailyAchievementsOnlyCountOnADailyPuzzle() {
        let totals = PlayerTotals(dailySolved: 5)
        let daily = evaluate(Self.event(isDaily: true), totals)
        #expect(percent(.firstDaily, daily) == 100)
        #expect(percent(.daily10, daily) == 50)

        let normal = evaluate(Self.event(isDaily: false), totals)
        #expect(percent(.firstDaily, normal) == nil)
        #expect(percent(.daily10, normal) == nil)
    }

    @Test func crossDeviceAchievements() {
        let travelled = Self.event(finishedOn: "Mac", startedOn: "iPhone")
        #expect(percent(.comeback, evaluate(travelled, PlayerTotals())) == 100)
        #expect(percent(.comeback, evaluate(Self.event(), PlayerTotals())) == nil)

        let two = PlayerTotals(platforms: ["iPhone", "Mac"])
        #expect(percent(.allPlatforms, evaluate(Self.event(), two))! - 66.66 < 0.1)
        let all = PlayerTotals(platforms: ["iPhone", "iPad", "Mac", "Apple TV"])
        #expect(percent(.allPlatforms, evaluate(Self.event(), all)) == 100)
    }

    @Test func theTechniqueAchievementFollowsWhatTheSolverNeeded() {
        let withXWing = Self.event(techniques: [.nakedSingle, .hiddenPair, .xWing])
        #expect(percent(.techniqueXWing, evaluate(withXWing, PlayerTotals())) == 100)
        #expect(percent(.techniqueXWing, evaluate(Self.event(), PlayerTotals())) == nil)
    }

    @Test func scoresAreOnlySentWhenTheyMeanSomething() {
        let totals = PlayerTotals(
            totalPoints: 1_234, streakDays: 3, bestSecondsByDifficulty: [.medium: 600])
        let best = AchievementEvaluator.submissions(for: Self.event(seconds: 600), totals: totals)
        #expect(best.contains { $0.leaderboard == .bestTimeMedium })
        #expect(best.contains { $0.leaderboard == .totalPoints && $0.value == 1_234 })
        #expect(!best.contains { $0.leaderboard == .daily })

        // A slower game does not touch the best-time board.
        let slower = AchievementEvaluator.submissions(for: Self.event(seconds: 900), totals: totals)
        #expect(!slower.contains { $0.leaderboard == .bestTimeMedium })

        let daily = AchievementEvaluator.submissions(for: Self.event(isDaily: true), totals: totals)
        #expect(daily.contains { $0.leaderboard == .daily })
    }
}
