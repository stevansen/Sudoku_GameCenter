extension LogicalSolver {
    /// Simple colouring: follow the conjugate-pair chains of one digit and
    /// alternate two colours along them. Exactly one colour is true, which makes
    /// two conclusions available — a colour that contradicts itself is false, and
    /// any cell seeing both colours cannot hold the digit.
    static func findSimpleColouring(_ board: CandidateBoard) -> Deduction? {
        for digit in 1...9 {
            var neighbours: [Int: [Int]] = [:]
            for unit in Units.all {
                let positions = board.positions(of: digit, in: unit)
                guard positions.count == 2 else { continue }
                neighbours[positions[0], default: []].append(positions[1])
                neighbours[positions[1], default: []].append(positions[0])
            }

            var visited = Set<Int>()
            for start in neighbours.keys.sorted() where !visited.contains(start) {
                var colour: [Int: Int] = [start: 0]
                var component: [Int] = []
                var queue = [start]
                visited.insert(start)
                while let cell = queue.popLast() {
                    component.append(cell)
                    for neighbour in neighbours[cell]! where !visited.contains(neighbour) {
                        colour[neighbour] = 1 - colour[cell]!
                        visited.insert(neighbour)
                        queue.append(neighbour)
                    }
                }
                component.sort()
                guard component.count >= 4 else { continue }

                let coloured = (0...1).map { value in component.filter { colour[$0] == value } }

                // A colour appearing twice in one unit must be the false one.
                for group in coloured {
                    let clashes = combinations(group, choose: 2).contains { Units.sees($0[0], $0[1]) }
                    guard clashes else { continue }
                    return Deduction(
                        technique: .simpleColouring,
                        eliminations: group.map { CellDigit(cell: $0, digit: digit) },
                        highlights: component)
                }

                // A cell outside the chain seeing both colours cannot hold the digit.
                var eliminations: [CellDigit] = []
                for cell in 0..<81
                where board.candidates[cell].contains(digit) && !component.contains(cell) {
                    let seesFirst = coloured[0].contains { Units.sees($0, cell) }
                    let seesSecond = coloured[1].contains { Units.sees($0, cell) }
                    if seesFirst && seesSecond {
                        eliminations.append(CellDigit(cell: cell, digit: digit))
                    }
                }
                guard eliminations.isEmpty == false else { continue }
                return Deduction(
                    technique: .simpleColouring,
                    eliminations: eliminations,
                    highlights: component)
            }
        }
        return nil
    }
}
