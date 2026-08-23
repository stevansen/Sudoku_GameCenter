/// Constraint propagation plus backtracking. Used to verify uniqueness during
/// generation and as the independent cross-check in tests — never to rate a
/// puzzle, which is ``LogicalSolver``'s job.
public enum BruteForceSolver {
    /// Applies naked and hidden singles until nothing changes.
    /// - Returns: `false` on contradiction.
    static func propagate(_ board: inout CandidateBoard) -> Bool {
        var progressed = true
        while progressed {
            progressed = false
            for cell in 0..<81 where board.isEmpty(cell) {
                guard let digit = board.candidates[cell].soleDigit else { continue }
                guard board.assign(digit, to: cell) else { return false }
                progressed = true
            }
            for unit in Units.all {
                for digit in 1...9 {
                    let positions = board.positions(of: digit, in: unit)
                    guard positions.count == 1, board.isEmpty(positions[0]) else { continue }
                    guard board.assign(digit, to: positions[0]) else { return false }
                    progressed = true
                }
            }
        }
        return true
    }

    /// The first solution found, or `nil` if there is none.
    public static func solve(_ grid: Grid) -> Grid? {
        guard var board = CandidateBoard(grid) else { return nil }
        return search(&board, limit: 1).first
    }

    /// Number of solutions, counting no further than `limit`.
    ///
    /// Stopping at 2 is what makes the generator's uniqueness check affordable:
    /// we never care *how* ambiguous a grid is, only whether it is.
    public static func solutionCount(_ grid: Grid, stopAt limit: Int = 2) -> Int {
        guard var board = CandidateBoard(grid) else { return 0 }
        return search(&board, limit: limit).count
    }

    public static func hasUniqueSolution(_ grid: Grid) -> Bool {
        solutionCount(grid, stopAt: 2) == 1
    }

    private static func search(_ board: inout CandidateBoard, limit: Int) -> [Grid] {
        guard propagate(&board) else { return [] }
        guard let cell = board.mostConstrainedCell() else { return [board.grid] }

        var solutions: [Grid] = []
        for digit in board.candidates[cell].digits {
            var branch = board
            guard branch.assign(digit, to: cell) else { continue }
            solutions += search(&branch, limit: limit - solutions.count)
            if solutions.count >= limit { break }
        }
        return solutions
    }
}
