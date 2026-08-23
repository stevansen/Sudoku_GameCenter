@testable import SudokuKit

enum Fixtures {
    /// The example grid from the Wikipedia article, solvable with singles alone.
    static let easyPuzzle =
        "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    static let easySolution =
        "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    /// The same puzzle in the canonical form ``Grid/stringValue`` emits.
    static let easyPuzzleDotted = String(easyPuzzle.map { $0 == "0" ? "." : $0 })

    /// "Everest" (Arto Inkala, 2012) — built to defeat human technique.
    static let hardPuzzle =
        "800000000003600000070090200050007000000045700000100030001000068008500010090000400"

    /// A grid with two solutions: four cells forming a swappable rectangle.
    /// Rows in the same band keep every box valid after the swap, so the puzzle
    /// genuinely has no single answer.
    static func ambiguousGrid() -> Grid? {
        let solution = Grid(easySolution)!
        for band in 0..<3 {
            let rows = (band * 3)..<(band * 3 + 3)
            for firstRow in rows {
                for secondRow in rows where secondRow > firstRow {
                    for firstColumn in 0..<9 {
                        for secondColumn in (firstColumn + 1)..<9 {
                            let a = solution[row: firstRow, column: firstColumn]
                            let b = solution[row: firstRow, column: secondColumn]
                            guard solution[row: secondRow, column: firstColumn] == b,
                                  solution[row: secondRow, column: secondColumn] == a
                            else { continue }
                            var grid = solution
                            grid[row: firstRow, column: firstColumn] = 0
                            grid[row: firstRow, column: secondColumn] = 0
                            grid[row: secondRow, column: firstColumn] = 0
                            grid[row: secondRow, column: secondColumn] = 0
                            return grid
                        }
                    }
                }
            }
        }
        return nil
    }
}
