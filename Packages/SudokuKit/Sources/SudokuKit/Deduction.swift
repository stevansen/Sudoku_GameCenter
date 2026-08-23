/// A digit in a cell — either something to place or something to rule out.
public struct CellDigit: Sendable, Hashable, Codable {
    public let cell: Int
    public let digit: Int

    public init(cell: Int, digit: Int) {
        self.cell = cell
        self.digit = digit
    }
}

/// One logical step: what a technique found and what follows from it.
///
/// Deliberately free of prose. The UI turns this into a sentence in the user's
/// language; the engine stays localisation-free and testable.
public struct Deduction: Sendable, Hashable {
    public let technique: Technique
    /// Digits that can be placed with certainty.
    public let placements: [CellDigit]
    /// Candidates that can be ruled out.
    public let eliminations: [CellDigit]
    /// Cells the technique reasoned about, for highlighting.
    public let highlights: [Int]
    /// The unit the pattern was found in, where that is meaningful.
    public let unit: UnitReference?

    init(
        technique: Technique,
        placements: [CellDigit] = [],
        eliminations: [CellDigit] = [],
        highlights: [Int] = [],
        unit: UnitReference? = nil
    ) {
        self.technique = technique
        self.placements = placements
        self.eliminations = eliminations
        self.highlights = highlights
        self.unit = unit
    }
}

/// Every combination of `k` elements, in stable order.
func combinations<T>(_ items: [T], choose k: Int) -> [[T]] {
    guard k > 0 else { return [[]] }
    guard items.count >= k else { return [] }
    if k == items.count { return [items] }
    var result: [[T]] = []
    var indices = Array(0..<k)
    while true {
        result.append(indices.map { items[$0] })
        var position = k - 1
        while position >= 0 && indices[position] == items.count - k + position {
            position -= 1
        }
        if position < 0 { break }
        indices[position] += 1
        for next in (position + 1)..<k { indices[next] = indices[next - 1] + 1 }
    }
    return result
}
