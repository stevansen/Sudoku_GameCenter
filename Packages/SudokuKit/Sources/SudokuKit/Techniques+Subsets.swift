extension LogicalSolver {
    /// `size` cells in a unit that between them hold exactly `size` digits —
    /// those digits belong to those cells and to no other cell of the unit.
    static func findNakedSubset(_ board: CandidateBoard, size: Int, technique: Technique) -> Deduction? {
        for (unitIndex, unit) in Units.all.enumerated() {
            let candidateCells = unit.filter {
                let count = board.candidates[$0].count
                return count >= 2 && count <= size
            }
            guard candidateCells.count > size else { continue }

            for group in combinations(candidateCells, choose: size) {
                let union = group.reduce(Candidates(0)) { $0 | board.candidates[$1] }
                guard union.count == size else { continue }

                var eliminations: [CellDigit] = []
                for cell in unit where !group.contains(cell) && board.isEmpty(cell) {
                    for digit in (board.candidates[cell] & union).digits {
                        eliminations.append(CellDigit(cell: cell, digit: digit))
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return Deduction(
                    technique: technique,
                    eliminations: eliminations,
                    highlights: group,
                    unit: UnitReference(unitIndex: unitIndex))
            }
        }
        return nil
    }

    /// `size` digits in a unit that fit in only `size` cells — those cells hold
    /// nothing else.
    static func findHiddenSubset(_ board: CandidateBoard, size: Int, technique: Technique) -> Deduction? {
        for (unitIndex, unit) in Units.all.enumerated() {
            var positionsByDigit: [Int: [Int]] = [:]
            for digit in 1...9 {
                let positions = board.positions(of: digit, in: unit)
                if positions.count >= 2 && positions.count <= size {
                    positionsByDigit[digit] = positions
                }
            }
            let digits = positionsByDigit.keys.sorted()
            guard digits.count >= size else { continue }

            for group in combinations(digits, choose: size) {
                var cells = Set<Int>()
                for digit in group { cells.formUnion(positionsByDigit[digit]!) }
                guard cells.count == size else { continue }

                let groupMask = group.reduce(Candidates(0)) { $0 | Candidates.mask($1) }
                var eliminations: [CellDigit] = []
                for cell in cells.sorted() {
                    for digit in (board.candidates[cell] & ~groupMask).digits {
                        eliminations.append(CellDigit(cell: cell, digit: digit))
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return Deduction(
                    technique: technique,
                    eliminations: eliminations,
                    highlights: cells.sorted(),
                    unit: UnitReference(unitIndex: unitIndex))
            }
        }
        return nil
    }
}
