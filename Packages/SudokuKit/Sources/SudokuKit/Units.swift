/// Static geometry of a 9x9 sudoku, computed once.
///
/// Cells are indexed row-major, 0...80. A *unit* is a row, column or box; every
/// cell belongs to exactly three of them. A cell's *peers* are the 20 other
/// cells that share a unit with it.
public enum Units {
    public static let rows: [[Int]] = (0..<9).map { row in (0..<9).map { row * 9 + $0 } }

    public static let columns: [[Int]] = (0..<9).map { column in (0..<9).map { $0 * 9 + column } }

    public static let boxes: [[Int]] = (0..<9).map { box in
        let originRow = (box / 3) * 3, originColumn = (box % 3) * 3
        return (0..<9).map { (originRow + $0 / 3) * 9 + originColumn + $0 % 3 }
    }

    /// All 27 units: rows 0...8, columns 9...17, boxes 18...26.
    public static let all: [[Int]] = rows + columns + boxes

    public static let rowOf: [Int] = (0..<81).map { $0 / 9 }
    public static let columnOf: [Int] = (0..<81).map { $0 % 9 }
    public static let boxOf: [Int] = (0..<81).map { ($0 / 9 / 3) * 3 + ($0 % 9) / 3 }

    /// The three unit indices (into ``all``) each cell belongs to.
    public static let unitsOf: [[Int]] = (0..<81).map { cell in
        [rowOf[cell], 9 + columnOf[cell], 18 + boxOf[cell]]
    }

    /// The 20 peers of each cell.
    public static let peers: [[Int]] = (0..<81).map { cell in
        var peers = Set<Int>()
        for unit in unitsOf[cell] { peers.formUnion(all[unit]) }
        peers.remove(cell)
        return peers.sorted()
    }

    /// Peers as bitmasks over the 81 cells, for fast "do these cells see each other" tests.
    static let peerMask: [UInt128] = (0..<81).map { cell in
        peers[cell].reduce(UInt128(0)) { $0 | (UInt128(1) << UInt128($1)) }
    }

    /// Whether two cells share a unit.
    @inlinable
    public static func sees(_ a: Int, _ b: Int) -> Bool {
        a != b && (rowOf[a] == rowOf[b] || columnOf[a] == columnOf[b] || boxOf[a] == boxOf[b])
    }

    /// A human-readable cell reference such as `R3C5`.
    public static func reference(_ cell: Int) -> String {
        "R\(rowOf[cell] + 1)C\(columnOf[cell] + 1)"
    }
}

/// Which kind of unit a deduction was found in.
public enum UnitKind: String, Sendable, Codable, Hashable {
    case row, column, box

    init(unitIndex: Int) {
        switch unitIndex {
        case 0..<9: self = .row
        case 9..<18: self = .column
        default: self = .box
        }
    }
}

/// A reference to one of the 27 units.
public struct UnitReference: Sendable, Codable, Hashable {
    public let kind: UnitKind
    /// 1-based index of the row, column or box.
    public let number: Int

    public init(unitIndex: Int) {
        self.kind = UnitKind(unitIndex: unitIndex)
        self.number = unitIndex % 9 + 1
    }
}
