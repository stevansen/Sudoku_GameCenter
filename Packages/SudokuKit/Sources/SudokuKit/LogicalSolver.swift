/// Solves a puzzle the way a person would: always the cheapest technique that
/// makes progress, never guessing.
///
/// Its step log is what ``DifficultyRater`` turns into a difficulty, and what
/// the in-game hint system explains. Those two uses are why the solver exists
/// at all — correctness of the *result* is ``BruteForceSolver``'s department.
public enum LogicalSolver {
    /// Result of a logical solve attempt.
    public struct Outcome: Sendable {
        public let solved: Bool
        public let deductions: [Deduction]
        /// The grid as far as logic got it.
        public let grid: Grid

        /// Every technique used, cheapest first, without repetition.
        public var techniques: [Technique] {
            Array(Set(deductions.map(\.technique))).sorted()
        }

        public var hardestTechnique: Technique? { techniques.last }
    }

    /// Solves as far as the given techniques allow.
    /// - Parameter ceiling: the most expensive technique the solver may use.
    public static func solve(_ grid: Grid, ceiling: Technique? = nil) -> Outcome {
        guard var board = CandidateBoard(grid) else {
            return Outcome(solved: false, deductions: [], grid: grid)
        }
        let maximumCost = ceiling?.cost ?? Int.max
        let allowed = Technique.byCost.filter { $0.cost <= maximumCost }
        var deductions: [Deduction] = []

        while !board.isSolved {
            guard let deduction = firstDeduction(in: board, techniques: allowed) else { break }
            guard apply(deduction, to: &board) else { break }
            deductions.append(deduction)
        }
        return Outcome(solved: board.isSolved, deductions: deductions, grid: board.grid)
    }

    /// The next single step, for the hint system.
    public static func nextDeduction(_ grid: Grid) -> Deduction? {
        guard let board = CandidateBoard(grid) else { return nil }
        return firstDeduction(in: board, techniques: Technique.byCost)
    }

    static func firstDeduction(in board: CandidateBoard, techniques: [Technique]) -> Deduction? {
        for technique in techniques {
            if let deduction = find(technique, in: board) { return deduction }
        }
        return nil
    }

    static func find(_ technique: Technique, in board: CandidateBoard) -> Deduction? {
        switch technique {
        case .nakedSingle: findNakedSingle(board)
        case .hiddenSingle: findHiddenSingle(board)
        case .lockedCandidates: findLockedCandidates(board)
        case .nakedPair: findNakedSubset(board, size: 2, technique: .nakedPair)
        case .hiddenPair: findHiddenSubset(board, size: 2, technique: .hiddenPair)
        case .nakedTriple: findNakedSubset(board, size: 3, technique: .nakedTriple)
        case .hiddenTriple: findHiddenSubset(board, size: 3, technique: .hiddenTriple)
        case .nakedQuad: findNakedSubset(board, size: 4, technique: .nakedQuad)
        case .hiddenQuad: findHiddenSubset(board, size: 4, technique: .hiddenQuad)
        case .xWing: findFish(board, size: 2, technique: .xWing)
        case .swordfish: findFish(board, size: 3, technique: .swordfish)
        case .jellyfish: findFish(board, size: 4, technique: .jellyfish)
        case .xyWing: findXYWing(board)
        case .xyzWing: findXYZWing(board)
        case .wWing: findWWing(board)
        case .simpleColouring: findSimpleColouring(board)
        case .forcingChain: findForcingChain(board)
        }
    }

    /// - Returns: `false` if the deduction contradicts the board, which would mean a bug.
    static func apply(_ deduction: Deduction, to board: inout CandidateBoard) -> Bool {
        for placement in deduction.placements {
            guard board.assign(placement.digit, to: placement.cell) else { return false }
        }
        for elimination in deduction.eliminations {
            guard board.eliminate(elimination.digit, from: elimination.cell) else { return false }
        }
        return true
    }
}
