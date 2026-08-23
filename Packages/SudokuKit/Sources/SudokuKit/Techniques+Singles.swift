extension LogicalSolver {
    /// A cell with only one candidate left.
    static func findNakedSingle(_ board: CandidateBoard) -> Deduction? {
        for cell in 0..<81 where board.isEmpty(cell) {
            guard let digit = board.candidates[cell].soleDigit else { continue }
            return Deduction(
                technique: .nakedSingle,
                placements: [CellDigit(cell: cell, digit: digit)],
                highlights: [cell])
        }
        return nil
    }

    /// A digit that fits in only one cell of a unit.
    static func findHiddenSingle(_ board: CandidateBoard) -> Deduction? {
        for (unitIndex, unit) in Units.all.enumerated() {
            for digit in 1...9 {
                let positions = board.positions(of: digit, in: unit)
                guard positions.count == 1 else { continue }
                let cell = positions[0]
                guard board.candidates[cell].count > 1 else { continue }  // else it is a naked single
                return Deduction(
                    technique: .hiddenSingle,
                    placements: [CellDigit(cell: cell, digit: digit)],
                    highlights: unit,
                    unit: UnitReference(unitIndex: unitIndex))
            }
        }
        return nil
    }

    /// Pointing and claiming: a digit confined to the intersection of a box and a line.
    static func findLockedCandidates(_ board: CandidateBoard) -> Deduction? {
        // Pointing — inside a box, all candidates of a digit sit on one line.
        for box in 0..<9 {
            for digit in 1...9 {
                let positions = board.positions(of: digit, in: Units.boxes[box])
                guard positions.count >= 2 else { continue }
                for line in lines(sharedBy: positions) {
                    let targets = line.filter {
                        Units.boxOf[$0] != box && board.candidates[$0].contains(digit)
                    }
                    guard !targets.isEmpty else { continue }
                    return Deduction(
                        technique: .lockedCandidates,
                        eliminations: targets.map { CellDigit(cell: $0, digit: digit) },
                        highlights: positions,
                        unit: UnitReference(unitIndex: 18 + box))
                }
            }
        }
        // Claiming — inside a line, all candidates of a digit sit in one box.
        for lineIndex in 0..<18 {
            let line = Units.all[lineIndex]
            for digit in 1...9 {
                let positions = board.positions(of: digit, in: line)
                guard positions.count >= 2 else { continue }
                let box = Units.boxOf[positions[0]]
                guard positions.allSatisfy({ Units.boxOf[$0] == box }) else { continue }
                let targets = Units.boxes[box].filter {
                    !positions.contains($0) && board.candidates[$0].contains(digit)
                }
                guard !targets.isEmpty else { continue }
                return Deduction(
                    technique: .lockedCandidates,
                    eliminations: targets.map { CellDigit(cell: $0, digit: digit) },
                    highlights: positions,
                    unit: UnitReference(unitIndex: lineIndex))
            }
        }
        return nil
    }

    /// The row and/or column shared by all the given cells.
    private static func lines(sharedBy cells: [Int]) -> [[Int]] {
        var result: [[Int]] = []
        let row = Units.rowOf[cells[0]]
        if cells.allSatisfy({ Units.rowOf[$0] == row }) { result.append(Units.rows[row]) }
        let column = Units.columnOf[cells[0]]
        if cells.allSatisfy({ Units.columnOf[$0] == column }) { result.append(Units.columns[column]) }
        return result
    }
}
