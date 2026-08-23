import Testing
@testable import SudokuKit

@Suite("Logical solver")
struct LogicalSolverTests {
    @Test func solvesAnEasyPuzzleWithSinglesAlone() throws {
        let grid = try #require(Grid(Fixtures.easyPuzzle))
        let outcome = LogicalSolver.solve(grid)
        #expect(outcome.solved)
        #expect(outcome.grid.stringValue == Fixtures.easySolution)
        // Peer propagation turns this grid's hidden singles into naked ones.
        #expect(outcome.hardestTechnique == .nakedSingle)
    }

    @Test func respectsTheTechniqueCeiling() throws {
        let grid = try #require(Grid(Fixtures.hardPuzzle))
        let withSinglesOnly = LogicalSolver.solve(grid, ceiling: .hiddenSingle)
        #expect(!withSinglesOnly.solved)
        #expect(withSinglesOnly.techniques.allSatisfy { $0.cost <= Technique.hiddenSingle.cost })
    }

    @Test func offersAFirstStepAsAHint() throws {
        let grid = try #require(Grid(Fixtures.easyPuzzle))
        let hint = try #require(LogicalSolver.nextDeduction(grid))
        #expect(hint.technique == .nakedSingle || hint.technique == .hiddenSingle)
        #expect(hint.placements.count == 1)
    }

    /// The decisive correctness test: every step any technique produces is checked
    /// against the puzzle's one true solution. A placement must match it, and an
    /// elimination must never remove the digit that belongs there. This covers all
    /// techniques at once — an unsound one cannot hide behind a lucky fixture.
    @Test(arguments: Difficulty.allCases)
    func neverContradictsTheSolution(difficulty: Difficulty) throws {
        for seed in UInt64(1)...6 {
            let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: seed &* 7919)
            let solution = puzzle.solution
            var board = try #require(CandidateBoard(puzzle.givens))

            while let deduction = LogicalSolver.firstDeduction(in: board, techniques: Technique.byCost) {
                for placement in deduction.placements {
                    #expect(
                        solution[placement.cell] == UInt8(placement.digit),
                        "\(deduction.technique) placed \(placement.digit) in \(Units.reference(placement.cell)), solution has \(solution[placement.cell])")
                }
                for elimination in deduction.eliminations {
                    #expect(
                        solution[elimination.cell] != UInt8(elimination.digit),
                        "\(deduction.technique) ruled out the correct digit \(elimination.digit) in \(Units.reference(elimination.cell))")
                }
                #expect(LogicalSolver.apply(deduction, to: &board))
            }
            #expect(board.isSolved, "logic stalled on \(puzzle.id)")
        }
    }

    @Test func everyTechniqueIsReachable() {
        // Techniques nothing can ever trigger would be dead weight in the rating.
        var seen = Set<Technique>()
        for difficulty in Difficulty.allCases {
            for seed in UInt64(1)...12 {
                let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: seed &* 104_729)
                seen.formUnion(puzzle.techniques)
            }
        }
        #expect(seen.contains(.nakedSingle))
        #expect(seen.contains(.hiddenSingle))
        #expect(seen.contains(.lockedCandidates))
        #expect(seen.contains(.nakedPair))
        #expect(seen.count >= 6, "only reached \(seen.sorted())")
    }
}
