extension LogicalSolver {
    /// X-Wing (2), Swordfish (3), Jellyfish (4).
    ///
    /// If a digit in `size` rows is confined to the same `size` columns, it must
    /// occupy those intersections — so it can go nowhere else in those columns.
    /// The same argument runs with rows and columns swapped.
    static func findFish(_ board: CandidateBoard, size: Int, technique: Technique) -> Deduction? {
        for digit in 1...9 {
            for baseIsRow in [true, false] {
                if let deduction = fish(board, digit: digit, size: size,
                                        technique: technique, baseIsRow: baseIsRow) {
                    return deduction
                }
            }
        }
        return nil
    }

    private static func fish(
        _ board: CandidateBoard, digit: Int, size: Int,
        technique: Technique, baseIsRow: Bool
    ) -> Deduction? {
        let baseUnits = baseIsRow ? Units.rows : Units.columns
        let coverUnits = baseIsRow ? Units.columns : Units.rows
        let coverIndexOf = baseIsRow ? Units.columnOf : Units.rowOf

        // Base lines where the digit has 2...size possible positions.
        var positionsByBase: [Int: [Int]] = [:]
        for (index, unit) in baseUnits.enumerated() {
            let positions = board.positions(of: digit, in: unit)
            if positions.count >= 2 && positions.count <= size { positionsByBase[index] = positions }
        }
        let bases = positionsByBase.keys.sorted()
        guard bases.count >= size else { return nil }

        for group in combinations(bases, choose: size) {
            var covers = Set<Int>()
            var pattern: [Int] = []
            for base in group {
                pattern += positionsByBase[base]!
                for cell in positionsByBase[base]! { covers.insert(coverIndexOf[cell]) }
            }
            guard covers.count == size else { continue }

            var eliminations: [CellDigit] = []
            for cover in covers.sorted() {
                for cell in coverUnits[cover]
                where !pattern.contains(cell) && board.candidates[cell].contains(digit) {
                    eliminations.append(CellDigit(cell: cell, digit: digit))
                }
            }
            guard !eliminations.isEmpty else { continue }
            return Deduction(
                technique: technique, eliminations: eliminations, highlights: pattern)
        }
        return nil
    }
}
