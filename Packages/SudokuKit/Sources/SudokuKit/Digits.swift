/// A set of candidate digits for one cell, stored as a bitmask.
/// Bit 0 represents the digit 1, bit 8 the digit 9.
public typealias Candidates = UInt16

extension Candidates {
    /// All nine digits.
    public static let allDigits: Candidates = 0b1_1111_1111

    /// The mask for a single digit (1...9).
    @inlinable
    public static func mask(_ digit: Int) -> Candidates {
        Candidates(1) << Candidates(digit - 1)
    }

    @inlinable
    public func contains(_ digit: Int) -> Bool {
        self & Candidates.mask(digit) != 0
    }

    /// Number of digits in the set.
    @inlinable
    public var count: Int { nonzeroBitCount }

    /// The single digit in the set, or `nil` if the set does not hold exactly one.
    @inlinable
    public var soleDigit: Int? {
        count == 1 ? trailingZeroBitCount + 1 : nil
    }

    /// The digits in the set, ascending.
    @inlinable
    public var digits: [Int] {
        var result: [Int] = []
        result.reserveCapacity(count)
        var rest = self
        while rest != 0 {
            let digit = rest.trailingZeroBitCount + 1
            result.append(digit)
            rest &= rest - 1
        }
        return result
    }
}
