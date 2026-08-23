import Testing
@testable import SudokuKit

/// A puzzle id together with the grid and rating it must always produce.
struct Golden {
    let id: String
    let givens: String
    let rating: Int

    init(_ id: String, _ givens: String, _ rating: Int) {
        self.id = id
        self.givens = givens
        self.rating = rating
    }
}

@Suite("Goldens")
struct GoldenTests {
    /// Captured from the v1 generator. These are the contract behind
    /// ``PuzzleID``: a stored id must still open the same puzzle months later,
    /// on another device, in another build. If a change to the generator, the
    /// solver or the rater moves any of these, that change silently invalidates
    /// every id already in the wild — bump `PuzzleID.currentVersion`, keep the
    /// old path, and add a new table rather than editing this one.
    static let goldens: [Golden] = [
        Golden("v1-easy-0000000000000001", "...178.947.9.541.6.1...37...5.9...4...7.2.6...6...5.1...65...8.4.538.9.182.469...", 47),
        Golden("v1-easy-0000000000005eed", "....95..7324..7...5...12.6...293.5..751...396..3.764...6.25...3...1..7522..74....", 53),
        Golden("v1-easy-00000000deadbeef", "..49.582.2.7..8.....6..234.1....3.8.9.28.17.6.3.2....5.513..6.....5..9.8.691.42..", 48),
        Golden("v1-easy-ffffffffffffffff", "9....1.231..54.....349..1.629..1..3...73.68...5..9..417.9..526.....29..552.4....9", 48),
        Golden("v1-medium-0000000000000001", "...1.8.94..9..41.6.1...37...5.9...4...7.2.6...6...5.1...65...8.4.53..9..82.4.9...", 53),
        Golden("v1-medium-0000000000005eed", "....9....324..7...5...12.6...29..5..751...396..3..64...6.25...3...1..752....4....", 72),
        Golden("v1-medium-00000000deadbeef", "..49..82.2.7..8.....6..234.1....3.....28.17.....2....5.513..6.....5..9.8.69..42..", 54),
        Golden("v1-medium-ffffffffffffffff", "9....1.231...4.....349....629..1..3...7...8...5..9..417....526.....2...552.4....9", 54),
        Golden("v1-hard-0000000000000001", "4......36....3.8.7.....2...6...15.23..59.31..12.68...5...1.....8.9.7....57......9", 100),
        Golden("v1-hard-0000000000005eed", "......87....9.8..4....16...53..61..9.71...32.6..23..17...62....2..1.7....95......", 87),
        Golden("v1-hard-00000000deadbeef", ".8......16.......4...41.8.27..8..1...1.265.4...3..9..84.8.56...2.......31......8.", 88),
        Golden("v1-hard-ffffffffffffffff", ".7..3......917..43.319.26........5.1.6.....2.2.4........36.948.84..139......2..3.", 86),
        Golden("v1-expert-0000000000000001", "3....6..4...15.23..6...........6..8193..2..4778..3...........9..59.48...2..9....8", 307),
        Golden("v1-expert-0000000000005eed", "7.5.6.....3.8..46..9........78..21..1...5...4..97..52........8..24..7.1.....8.9.2", 303),
        Golden("v1-expert-00000000deadbeef", "35.7.2....78.6.2..4........69..7..4.....3.....1..8..75........9..2.5.63....6.1.28", 313),
        Golden("v1-expert-ffffffffffffffff", ".7..39..1...4.2.6........9...27....653.....281....49...8........9.1.7...3..59..1.", 306),
        Golden("v1-evil-0000000000000001", "...9....7....7..3..5.1..4.....3..65.3.8..2.9..4.......9...2..417.............93.8", 636),
        Golden("v1-evil-0000000000005eed", "..54.....231....6..9..3..5..7...21......5.3.4.......28..3.......2...7.1..5718....", 947),
        Golden("v1-evil-00000000deadbeef", "....3751..6......3...6...8...9..5....7...6.5.5..9...68..4..9....8..4.2...9.1....7", 1246),
        Golden("v1-evil-ffffffffffffffff", "..2.1....8....39..46......39...4.....7..31......2.8...7..........67.2.14.4....52.", 832),
    ]

    @Test(arguments: goldens)
    func aSeedAlwaysProducesTheSamePuzzle(golden: Golden) throws {
        let id = try #require(PuzzleID(golden.id))
        let puzzle = PuzzleGenerator.generate(id)
        #expect(puzzle.id == id, "the generator must return the id it was asked for")
        #expect(puzzle.givens.stringValue == golden.givens)
        #expect(puzzle.rating == golden.rating)
        #expect(puzzle.difficulty == id.difficulty)
    }
}

extension Golden: CustomTestStringConvertible {
    var testDescription: String { id }
}
