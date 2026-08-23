import Foundation
import Testing
@testable import SudokuKit

@Suite("Generator")
struct GeneratorTests {
    @Test(arguments: Difficulty.allCases)
    func producesUniquelySolvablePuzzles(difficulty: Difficulty) {
        for seed in UInt64(1)...8 {
            let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: seed &* 2_654_435_761)
            #expect(puzzle.solution.isComplete && puzzle.solution.isValid)
            #expect(BruteForceSolver.solve(puzzle.givens)?.stringValue == puzzle.solution.stringValue)
            // Verified with the independent solver, not the one that built it.
            #expect(BruteForceSolver.hasUniqueSolution(puzzle.givens), "\(puzzle.id) is ambiguous")
            #expect(puzzle.givenCount >= 17)
        }
    }

    @Test(arguments: Difficulty.allCases)
    func isDeterministic(difficulty: Difficulty) {
        let id = PuzzleID(difficulty: difficulty, seed: 0xDEAD_BEEF_CAFE_1234)
        let first = PuzzleGenerator.generate(id)
        let second = PuzzleGenerator.generate(id)
        #expect(first.givens == second.givens)
        #expect(first.solution == second.solution)
        #expect(first.rating == second.rating)
    }

    @Test func differentSeedsProduceDifferentPuzzles() {
        let grids = (UInt64(1)...10).map {
            PuzzleGenerator.generate(difficulty: .medium, seed: $0).givens.stringValue
        }
        #expect(Set(grids).count == grids.count)
    }

    @Test func theDailyPuzzleDependsOnlyOnTheUtcDate() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let morning = utc.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 6))!
        let evening = utc.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 23))!
        let nextDay = utc.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 6))!

        #expect(PuzzleGenerator.dailySeed(for: morning, difficulty: .medium)
            == PuzzleGenerator.dailySeed(for: evening, difficulty: .medium))
        #expect(PuzzleGenerator.dailySeed(for: morning, difficulty: .medium)
            != PuzzleGenerator.dailySeed(for: nextDay, difficulty: .medium))
        #expect(PuzzleGenerator.dailySeed(for: morning, difficulty: .medium)
            != PuzzleGenerator.dailySeed(for: morning, difficulty: .hard))
    }

    @Test func symmetricGridsRemoveCellsInPairs() {
        let puzzle = PuzzleGenerator.generate(
            difficulty: .medium, seed: 42,
            options: GeneratorOptions(symmetry: .rotational180))
        for cell in 0..<81 where cell != 40 {
            #expect((puzzle.givens[cell] == 0) == (puzzle.givens[80 - cell] == 0))
        }
    }

    @Test func puzzleIdRoundTripsThroughItsStringForm() throws {
        let id = PuzzleID(difficulty: .expert, seed: 0x3F9A_12C4_0B7E_5518)
        #expect(id.description
            == "v\(PuzzleID.currentVersion)-expert-3f9a12c40b7e5518")
        #expect(PuzzleID(id.description) == id)
        let data = try JSONEncoder().encode(id)
        #expect(try JSONDecoder().decode(PuzzleID.self, from: data) == id)
        #expect(PuzzleID("nonsense") == nil)
    }

    /// An id written by an older build still has to name the same grid. The
    /// puzzle is not stored anywhere — only its id is — so if a version change
    /// altered what a seed produces, a game in progress would come back as a
    /// different puzzle with the player's entries scattered over it.
    @Test func anOlderIdStillNamesItsOwnGrid() throws {
        let stored = "v1-hard-000000000000007b"
        let id = try #require(PuzzleID(stored))
        #expect(id.version == 1)
        #expect(id.description == stored)

        let first = PuzzleGenerator.generate(id)
        let again = PuzzleGenerator.generate(id)
        #expect(first.givens == again.givens)
        #expect(first.id.description == stored)

        // And it is not simply the same as what version 2 makes of that seed.
        let current = PuzzleGenerator.generate(
            PuzzleID(difficulty: .hard, seed: 0x7B, version: 2))
        #expect(current.givens != first.givens,
                "sonst prüft dieser Test nichts")
    }
}
