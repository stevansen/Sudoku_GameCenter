/// A 9x9 sudoku grid. `0` marks an empty cell.
public struct Grid: Sendable, Hashable {
    public private(set) var cells: [UInt8]

    /// An empty grid.
    public init() {
        cells = Array(repeating: 0, count: 81)
    }

    /// Fails if `cells` does not hold exactly 81 values in `0...9`.
    public init?(cells: [UInt8]) {
        guard cells.count == 81, cells.allSatisfy({ $0 <= 9 }) else { return nil }
        self.cells = cells
    }

    /// Parses the common 81-character form; `.`, `0` and `-` mark empty cells.
    /// Whitespace and newlines are ignored, so pretty-printed grids parse too.
    public init?(_ string: String) {
        var cells: [UInt8] = []
        cells.reserveCapacity(81)
        for character in string where !character.isWhitespace {
            switch character {
            case ".", "0", "-": cells.append(0)
            case "1"..."9": cells.append(UInt8(character.wholeNumberValue!))
            default: return nil
            }
        }
        guard cells.count == 81 else { return nil }
        self.cells = cells
    }

    public subscript(cell: Int) -> UInt8 {
        get { cells[cell] }
        set { cells[cell] = newValue }
    }

    public subscript(row row: Int, column column: Int) -> UInt8 {
        get { cells[row * 9 + column] }
        set { cells[row * 9 + column] = newValue }
    }

    /// Number of filled cells.
    public var filledCount: Int { cells.count { $0 != 0 } }

    public var isComplete: Bool { !cells.contains(0) }

    /// Whether no unit holds a digit twice. An incomplete grid can be valid.
    public var isValid: Bool {
        for unit in Units.all {
            var seen: Candidates = 0
            for cell in unit where cells[cell] != 0 {
                let bit = Candidates.mask(Int(cells[cell]))
                if seen & bit != 0 { return false }
                seen |= bit
            }
        }
        return true
    }

    /// The 81-character form, using `.` for empty cells.
    public var stringValue: String {
        String(cells.map { $0 == 0 ? "." : Character(String($0)) })
    }

    /// A 9x9 rendering with box separators, for debugging and tests.
    public var prettyDescription: String {
        var lines: [String] = []
        for row in 0..<9 {
            if row % 3 == 0 && row != 0 { lines.append("------+-------+------") }
            let cells = (0..<9).map { column -> String in
                let value = self[row: row, column: column]
                return value == 0 ? "." : String(value)
            }
            var line = ""
            for (index, cell) in cells.enumerated() {
                if index % 3 == 0 && index != 0 { line += "| " }
                line += cell + " "
            }
            lines.append(line.trimmingCharacters(in: .whitespaces))
        }
        return lines.joined(separator: "\n")
    }
}

extension Grid: Codable {
    /// Encoded as the compact 81-character string rather than an array of numbers.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let grid = Grid(string) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Not a valid 81-character sudoku grid")
        }
        self = grid
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

extension Grid: CustomStringConvertible {
    public var description: String { stringValue }
}
