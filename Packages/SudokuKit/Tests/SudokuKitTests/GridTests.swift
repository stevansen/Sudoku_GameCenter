import Foundation
import Testing
@testable import SudokuKit

@Suite("Grid")
struct GridTests {
    @Test func parsesTheEightyOneCharacterForm() throws {
        let grid = try #require(Grid(Fixtures.easyPuzzle))
        #expect(grid[row: 0, column: 0] == 5)
        #expect(grid[row: 0, column: 2] == 0)
        #expect(grid.filledCount == 30)
        #expect(grid.stringValue == Fixtures.easyPuzzleDotted)  // empty cells normalise to '.'
    }

    @Test func ignoresWhitespaceSoPrettyGridsParse() throws {
        let grid = try #require(Grid(Fixtures.easyPuzzle))
        let stripped = grid.prettyDescription
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "+", with: "")
        let reparsed = try #require(Grid(stripped))
        #expect(reparsed == grid)
    }

    @Test func rejectsMalformedInput() {
        #expect(Grid("123") == nil)
        #expect(Grid(String(repeating: "x", count: 81)) == nil)
        #expect(Grid(cells: Array(repeating: 10, count: 81)) == nil)
    }

    @Test func validatesUnits() throws {
        var grid = try #require(Grid(Fixtures.easyPuzzle))
        #expect(grid.isValid)
        #expect(!grid.isComplete)
        grid[row: 0, column: 2] = 5  // duplicate 5 in row 0
        #expect(!grid.isValid)
        let solution = try #require(Grid(Fixtures.easySolution))
        #expect(solution.isComplete)
    }

    @Test func roundTripsThroughCodableAsAString() throws {
        let grid = try #require(Grid(Fixtures.easyPuzzle))
        let data = try JSONEncoder().encode(grid)
        #expect(String(data: data, encoding: .utf8) == "\"\(Fixtures.easyPuzzleDotted)\"")
        #expect(try JSONDecoder().decode(Grid.self, from: data) == grid)
    }
}

@Suite("Units")
struct UnitsTests {
    @Test func everyCellHasTwentyPeers() {
        for cell in 0..<81 {
            #expect(Units.peers[cell].count == 20)
            #expect(!Units.peers[cell].contains(cell))
        }
    }

    @Test func peersMatchTheSeesRelation() {
        for cell in stride(from: 0, to: 81, by: 7) {
            for other in 0..<81 {
                #expect(Units.peers[cell].contains(other) == Units.sees(cell, other))
            }
        }
    }

    @Test func thereAreTwentySevenUnitsOfNineCells() {
        #expect(Units.all.count == 27)
        #expect(Units.all.allSatisfy { $0.count == 9 })
        #expect(Set(Units.all.flatMap { $0 }).count == 81)
    }
}
