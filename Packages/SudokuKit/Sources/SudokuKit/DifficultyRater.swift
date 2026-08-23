/// Turns a logical solve into a difficulty.
///
/// The number of givens is deliberately not part of the score: a 30-given grid
/// can be trivial or brutal depending on which patterns it forces.
public enum DifficultyRater {
    public struct Rating: Sendable, Hashable {
        public let score: Int
        public let difficulty: Difficulty
        /// Every technique the solve needed, cheapest first.
        public let techniques: [Technique]
        public let stepCount: Int

        public var hardestTechnique: Technique? { techniques.last }
    }

    /// - Returns: `nil` if logic alone does not finish the grid.
    public static func rate(_ grid: Grid) -> Rating? {
        let outcome = LogicalSolver.solve(grid)
        guard outcome.solved else { return nil }
        return rating(for: outcome)
    }

    static func rating(for outcome: LogicalSolver.Outcome) -> Rating? {
        guard outcome.solved, let hardest = outcome.hardestTechnique else { return nil }
        let stepCost = outcome.deductions.reduce(0) { $0 + $1.technique.cost }
        // The hardest step counts extra: a single X-Wing changes the character of
        // a puzzle far more than another twenty naked singles do.
        let score = stepCost + 3 * hardest.cost
        // For a grid of unknown origin the score band is the classifier; the
        // generator instead knows the tier from the parameters it built with.
        return Rating(
            score: score,
            difficulty: Difficulty.forScore(score),
            techniques: outcome.techniques,
            stepCount: outcome.deductions.count)
    }
}
