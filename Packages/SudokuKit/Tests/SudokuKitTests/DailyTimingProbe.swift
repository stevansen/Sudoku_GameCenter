import Foundation
import Testing
@testable import SudokuKit

/// A widget has a small time budget. If generating today's puzzle is slow, the
/// widget has to read a stored one instead of deriving it.
@Test func generatingTodaysPuzzleIsFastEnoughForAWidget() {
    let start = Date()
    _ = PuzzleGenerator.daily(for: .now)
    let milliseconds = Date().timeIntervalSince(start) * 1000
    print("### daily generation: \(Int(milliseconds)) ms")
    #expect(milliseconds < 2000)
}
