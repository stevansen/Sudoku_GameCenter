extension LogicalSolver {
    /// All cells that share a unit with both `a` and `b`.
    static func cellsSeeingBoth(_ a: Int, _ b: Int) -> [Int] {
        var rest = Units.peerMask[a] & Units.peerMask[b]
        var result: [Int] = []
        while rest != 0 {
            result.append(rest.trailingZeroBitCount)
            rest &= rest - 1
        }
        return result
    }

    /// XY-Wing: a bivalue pivot `xy` with pincers `xz` and `yz`. Whichever way the
    /// pivot falls, one pincer becomes `z` — so nothing that sees both can be `z`.
    static func findXYWing(_ board: CandidateBoard) -> Deduction? {
        for pivot in 0..<81 where board.candidates[pivot].count == 2 {
            let pincers = Units.peers[pivot].filter { board.candidates[$0].count == 2 }
            guard pincers.count >= 2 else { continue }

            for pair in combinations(pincers, choose: 2) {
                let (a, b) = (pair[0], pair[1])
                let pivotMask = board.candidates[pivot]
                let maskA = board.candidates[a], maskB = board.candidates[b]
                let shared = maskA & maskB
                guard shared.count == 1, pivotMask & shared == 0,
                      (maskA & pivotMask).count == 1, (maskB & pivotMask).count == 1,
                      (maskA | maskB | pivotMask).count == 3
                else { continue }

                let digit = shared.soleDigit!
                let targets = cellsSeeingBoth(a, b).filter {
                    $0 != pivot && board.candidates[$0].contains(digit)
                }
                guard !targets.isEmpty else { continue }
                return Deduction(
                    technique: .xyWing,
                    eliminations: targets.map { CellDigit(cell: $0, digit: digit) },
                    highlights: [pivot, a, b])
            }
        }
        return nil
    }

    /// XYZ-Wing: like an XY-Wing, but the pivot itself can also be `z`, so the
    /// eliminations must see all three cells.
    static func findXYZWing(_ board: CandidateBoard) -> Deduction? {
        for pivot in 0..<81 where board.candidates[pivot].count == 3 {
            let pivotMask = board.candidates[pivot]
            let pincers = Units.peers[pivot].filter {
                board.candidates[$0].count == 2 && board.candidates[$0] & ~pivotMask == 0
            }
            guard pincers.count >= 2 else { continue }

            for pair in combinations(pincers, choose: 2) {
                let (a, b) = (pair[0], pair[1])
                let maskA = board.candidates[a], maskB = board.candidates[b]
                guard maskA != maskB, maskA | maskB == pivotMask else { continue }
                let shared = maskA & maskB
                guard shared.count == 1 else { continue }

                let digit = shared.soleDigit!
                let targets = cellsSeeingBoth(a, b).filter {
                    $0 != pivot && Units.sees($0, pivot) && board.candidates[$0].contains(digit)
                }
                guard !targets.isEmpty else { continue }
                return Deduction(
                    technique: .xyzWing,
                    eliminations: targets.map { CellDigit(cell: $0, digit: digit) },
                    highlights: [pivot, a, b])
            }
        }
        return nil
    }

    /// W-Wing: two identical bivalue cells `xy` joined by a strong link on `y`.
    /// One of them must be `x`, so nothing seeing both can be.
    static func findWWing(_ board: CandidateBoard) -> Deduction? {
        let bivalue = (0..<81).filter { board.candidates[$0].count == 2 }
        guard bivalue.count >= 2 else { return nil }

        // Strong links: units where a digit has exactly two possible cells.
        var strongLinks: [Int: [(Int, Int)]] = [:]
        for unit in Units.all {
            for digit in 1...9 {
                let positions = board.positions(of: digit, in: unit)
                if positions.count == 2 {
                    strongLinks[digit, default: []].append((positions[0], positions[1]))
                }
            }
        }

        for pair in combinations(bivalue, choose: 2) {
            let (a, b) = (pair[0], pair[1])
            let mask = board.candidates[a]
            guard mask == board.candidates[b], !Units.sees(a, b) else { continue }

            for linkDigit in mask.digits {
                let other = (mask & ~Candidates.mask(linkDigit)).soleDigit!
                for (p, q) in strongLinks[linkDigit] ?? [] {
                    guard ![a, b].contains(p), ![a, b].contains(q) else { continue }
                    let connects = (Units.sees(p, a) && Units.sees(q, b))
                        || (Units.sees(q, a) && Units.sees(p, b))
                    guard connects else { continue }

                    let targets = cellsSeeingBoth(a, b).filter {
                        board.candidates[$0].contains(other)
                    }
                    guard !targets.isEmpty else { continue }
                    return Deduction(
                        technique: .wWing,
                        eliminations: targets.map { CellDigit(cell: $0, digit: other) },
                        highlights: [a, b, p, q])
                }
            }
        }
        return nil
    }
}
