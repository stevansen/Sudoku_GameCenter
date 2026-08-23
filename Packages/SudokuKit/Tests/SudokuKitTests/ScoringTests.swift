import Testing
@testable import SudokuKit

@Suite("Scoring")
struct ScoringTests {
    @Test func aSolveAtTargetTimeScoresTheBase() {
        let record = SolveRecord(difficulty: .medium, seconds: Difficulty.medium.targetSeconds)
        #expect(Scoring.points(for: record) == 250)
    }

    @Test func theTimeFactorIsClampedBothWays() {
        let lightning = SolveRecord(difficulty: .hard, seconds: 1)
        let crawl = SolveRecord(difficulty: .hard, seconds: 10 * Difficulty.hard.targetSeconds)
        #expect(Scoring.breakdown(for: lightning).timeFactor == 2.0)
        #expect(Scoring.breakdown(for: crawl).timeFactor == 0.5)
        #expect(Scoring.points(for: lightning) == 1000)
        #expect(Scoring.points(for: crawl) == 250)
    }

    @Test func mistakesAndHintsCostPointsButNeverAllOfThem() {
        let target = Difficulty.expert.targetSeconds
        let clean = SolveRecord(difficulty: .expert, seconds: target)
        let sloppy = SolveRecord(difficulty: .expert, seconds: target, mistakes: 3)
        let guided = SolveRecord(difficulty: .expert, seconds: target, hintsUsed: 3)
        let hopeless = SolveRecord(difficulty: .expert, seconds: target, mistakes: 50, hintsUsed: 50)

        #expect(Scoring.points(for: sloppy) < Scoring.points(for: clean))
        #expect(Scoring.points(for: guided) < Scoring.points(for: sloppy))
        #expect(Scoring.breakdown(for: hopeless).mistakeFactor == 0.4)
        #expect(Scoring.breakdown(for: hopeless).hintFactor == 0.3)
        #expect(Scoring.points(for: hopeless) > 0)
    }

    @Test func notesAreFreeButAutoCandidatesAreNot() {
        let target = Difficulty.medium.targetSeconds
        let plain = SolveRecord(difficulty: .medium, seconds: target)
        let assisted = SolveRecord(difficulty: .medium, seconds: target, usedAutoCandidates: true)
        #expect(Scoring.breakdown(for: assisted).hintFactor == 0.8)
        #expect(Scoring.points(for: assisted) == Int((Double(Scoring.points(for: plain)) * 0.8).rounded()))
    }

    @Test func theStreakBonusCapsAtFiftyPercent() {
        let target = Difficulty.easy.targetSeconds
        #expect(Scoring.breakdown(for: SolveRecord(difficulty: .easy, seconds: target, streakDays: 4)).streakBonus == 0.2)
        #expect(Scoring.breakdown(for: SolveRecord(difficulty: .easy, seconds: target, streakDays: 40)).streakBonus == 0.5)
        #expect(Scoring.points(for: SolveRecord(difficulty: .easy, seconds: target, streakDays: 40)) == 150)
    }

    @Test func dailyPaysMoreAndRepeatsAndPracticePayNothing() {
        let target = Difficulty.hard.targetSeconds
        #expect(Scoring.points(for: SolveRecord(difficulty: .hard, seconds: target, mode: .daily)) == 750)
        #expect(Scoring.points(for: SolveRecord(difficulty: .hard, seconds: target, mode: .practice)) == 0)
        #expect(Scoring.points(for: SolveRecord(difficulty: .hard, seconds: target, isRepeat: true)) == 0)
    }
}
