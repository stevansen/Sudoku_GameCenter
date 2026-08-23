/// A grid plus the candidate set of every empty cell — the working state of both solvers.
///
/// Assigning a digit removes it from the candidates of all 20 peers. That is
/// plain bookkeeping, not a solving technique: finding the *consequences* of
/// those candidate sets is what ``LogicalSolver`` charges for.
public struct CandidateBoard: Sendable, Hashable {
    public private(set) var values: [UInt8]
    public private(set) var candidates: [Candidates]
    public private(set) var filledCount: Int

    /// Returns `nil` if the grid contradicts itself (a given with no possible placement).
    public init?(_ grid: Grid) {
        values = Array(repeating: 0, count: 81)
        candidates = Array(repeating: .allDigits, count: 81)
        filledCount = 0
        for cell in 0..<81 where grid[cell] != 0 {
            guard assign(Int(grid[cell]), to: cell) else { return nil }
        }
    }

    public var isSolved: Bool { filledCount == 81 }

    public var grid: Grid { Grid(cells: values)! }

    public func isEmpty(_ cell: Int) -> Bool { values[cell] == 0 }

    /// Places `digit` in `cell` and removes it from every peer.
    /// - Returns: `false` if this creates a contradiction.
    @discardableResult
    public mutating func assign(_ digit: Int, to cell: Int) -> Bool {
        guard values[cell] == 0 else { return values[cell] == UInt8(digit) }
        guard candidates[cell].contains(digit) else { return false }
        values[cell] = UInt8(digit)
        candidates[cell] = 0
        filledCount += 1
        for peer in Units.peers[cell] where !eliminate(digit, from: peer) { return false }
        return true
    }

    /// Removes `digit` from the candidates of `cell`.
    /// - Returns: `false` if this leaves an empty cell with no candidate.
    @discardableResult
    public mutating func eliminate(_ digit: Int, from cell: Int) -> Bool {
        guard values[cell] == 0 else { return true }
        let bit = Candidates.mask(digit)
        guard candidates[cell] & bit != 0 else { return true }
        candidates[cell] &= ~bit
        return candidates[cell] != 0
    }

    /// Cells of `unit` that still list `digit` as a candidate.
    func positions(of digit: Int, in unit: [Int]) -> [Int] {
        let bit = Candidates.mask(digit)
        return unit.filter { candidates[$0] & bit != 0 }
    }

    /// The empty cell with the fewest candidates — the branching heuristic of the
    /// brute-force solver (*minimum remaining values*).
    func mostConstrainedCell() -> Int? {
        var best: Int?
        var bestCount = 10
        for cell in 0..<81 where values[cell] == 0 {
            let count = candidates[cell].count
            if count < bestCount {
                best = cell
                bestCount = count
                if count == 2 { break }
            }
        }
        return best
    }
}
