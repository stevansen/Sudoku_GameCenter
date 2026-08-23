import Testing
@testable import SudokuKit

@Suite("Calibration", .disabled("diagnostic — run by hand after touching the generator or the rater"))
struct Calibration {
    /// Prints score, given-count, technique and timing distributions per tier.
    /// The numbers in `docs/decisions.md`, the score bands in ``Difficulty`` and
    /// the budgets in ``PerformanceTests`` all come from this. Re-run it in
    /// release before changing any of them:
    /// `swift test -c release -Xswiftc -enable-testing --filter Calibration`
    /// (temporarily drop the `.disabled` trait above).
    @Test func measureDistribution() {
        let clock = ContinuousClock()
        for difficulty in Difficulty.allCases {
            var scores: [Int] = []
            var givens: [Int] = []
            var hardest: [String] = []
            var total = Duration.zero
            var worst = Duration.zero
            for seed in UInt64(1)...25 {
                let start = clock.now
                let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: seed &* 1_000_003)
                let elapsed = clock.now - start
                total += elapsed
                worst = max(worst, elapsed)
                scores.append(puzzle.rating)
                givens.append(puzzle.givenCount)
                hardest.append(puzzle.hardestTechnique?.rawValue ?? "-")
            }
            print("\(difficulty.rawValue) avg=\(total / 25) worst=\(worst)")
            print("   scores=\(scores.sorted()) givens=\(givens.sorted())")
            print("   hardest=\(Dictionary(grouping: hardest, by: { $0 }).mapValues(\.count))")
        }
    }
}
