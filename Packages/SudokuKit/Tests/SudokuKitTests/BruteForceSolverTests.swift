import Testing
@testable import SudokuKit

@Suite("Brute-force solver")
struct BruteForceSolverTests {
    @Test func solvesAKnownPuzzleToTheKnownSolution() throws {
        let puzzle = try #require(Grid(Fixtures.easyPuzzle))
        let solved = try #require(BruteForceSolver.solve(puzzle))
        #expect(solved.stringValue == Fixtures.easySolution)
    }

    @Test func solvesAPuzzleBuiltToBeHard() throws {
        let puzzle = try #require(Grid(Fixtures.hardPuzzle))
        let solved = try #require(BruteForceSolver.solve(puzzle))
        #expect(solved.isComplete)
        #expect(solved.isValid)
    }

    @Test func recognisesAUniqueSolution() throws {
        let easy = try #require(Grid(Fixtures.easyPuzzle))
        let hard = try #require(Grid(Fixtures.hardPuzzle))
        #expect(BruteForceSolver.hasUniqueSolution(easy))
        #expect(BruteForceSolver.hasUniqueSolution(hard))
    }

    @Test func recognisesAmbiguity() throws {
        let ambiguous = try #require(Fixtures.ambiguousGrid())
        #expect(!BruteForceSolver.hasUniqueSolution(ambiguous))
        #expect(BruteForceSolver.solutionCount(ambiguous, stopAt: 2) == 2)
        #expect(BruteForceSolver.solutionCount(Grid(), stopAt: 2) == 2)
    }

    @Test func rejectsAContradictoryGrid() throws {
        var grid = try #require(Grid(Fixtures.easyPuzzle))
        grid[row: 0, column: 2] = 5
        #expect(BruteForceSolver.solve(grid) == nil)
        #expect(BruteForceSolver.solutionCount(grid) == 0)
    }
}
