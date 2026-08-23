extension LogicalSolver {
    /// Nishio: assume a candidate, propagate singles, and if that runs into a
    /// contradiction the candidate was wrong.
    ///
    /// This is the last resort — it is the one technique that tries something out
    /// rather than seeing it, which is why it costs the most and only appears at
    /// the top tier. Bounded to single-propagation, so it never becomes a
    /// disguised brute-force search.
    static func findForcingChain(_ board: CandidateBoard) -> Deduction? {
        for cell in 0..<81 where board.isEmpty(cell) {
            for digit in board.candidates[cell].digits {
                var trial = board
                let survives = trial.assign(digit, to: cell) && BruteForceSolver.propagate(&trial)
                guard !survives else { continue }
                return Deduction(
                    technique: .forcingChain,
                    eliminations: [CellDigit(cell: cell, digit: digit)],
                    highlights: [cell])
            }
        }
        return nil
    }
}
