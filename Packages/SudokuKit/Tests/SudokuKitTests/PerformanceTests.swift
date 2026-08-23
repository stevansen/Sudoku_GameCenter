import Testing
@testable import SudokuKit

/// Budgets are for a release build on Apple silicon. A debug build is an order
/// of magnitude slower, so the assertions only run in release —
/// `swift test -c release -Xswiftc -enable-testing`. They exist to catch
/// regressions, not to measure precisely.
@Suite("Performance")
struct PerformanceTests {
    static let budgets: [(Difficulty, Duration)] = [
        (.easy, .milliseconds(30)),
        (.medium, .milliseconds(80)),
        (.hard, .milliseconds(200)),
        (.expert, .milliseconds(600)),
        (.evil, .seconds(2)),
    ]

    /// The budget is a 95th percentile, not a maximum: generation is a search
    /// with a retry loop, so the slowest of a batch is several times the median
    /// and says little. The app hides even that behind a prefetched pool.
    @Test(arguments: budgets)
    func generationStaysWithinBudget(difficulty: Difficulty, budget: Duration) {
        let clock = ContinuousClock()
        let sampleSize = 40
        var timings: [Duration] = []
        for seed in UInt64(1)...UInt64(sampleSize) {
            let start = clock.now
            _ = PuzzleGenerator.generate(difficulty: difficulty, seed: seed &* 2_246_822_519)
            timings.append(clock.now - start)
        }
        timings.sort()
        let p95 = timings[Int(Double(sampleSize) * 0.95) - 1]

        #if DEBUG
        _ = p95  // timings are meaningless without optimisation
        #else
        #expect(p95 <= budget,
                "\(difficulty): p95 \(p95) exceeds \(budget) (median \(timings[sampleSize / 2]), max \(timings.last!))")
        #endif
    }

    @Test func solvingIsFastEnoughToRunOnEveryKeystroke() throws {
        // The app validates and hints as the player types, so a full logical
        // solve has to be cheap even on the hardest grid.
        let grid = try #require(Grid(Fixtures.hardPuzzle))
        let clock = ContinuousClock()
        let start = clock.now
        for _ in 0..<20 { _ = LogicalSolver.solve(grid) }
        let perSolve = (clock.now - start) / 20
        #if !DEBUG
        #expect(perSolve <= .milliseconds(50), "logical solve took \(perSolve)")
        #endif
        _ = perSolve
    }
}
