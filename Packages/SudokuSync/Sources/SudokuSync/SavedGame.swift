import Foundation
import SudokuKit

/// A game in progress, in the form that travels between devices.
///
/// The puzzle itself is never stored or sent — only its id. That is what makes
/// this record a few hundred bytes instead of several kilobytes, and it is why
/// the fast path can use the key-value store at all, which has a hard size limit.
public struct SavedGame: Codable, Sendable, Equatable {
    public var puzzleID: String
    public var entries: [UInt8]
    public var notes: [Candidates]
    public var elapsedSeconds: Int
    public var mistakes: Int
    public var hintsUsed: Int
    public var usedAutoCandidates: Bool
    public var startedAt: Date
    public var updatedAt: Date
    /// Monotonic. The first tie-breaker when two devices disagree.
    public var moveCount: Int
    public var deviceName: String

    public init(
        puzzleID: String, entries: [UInt8], notes: [Candidates], elapsedSeconds: Int,
        mistakes: Int, hintsUsed: Int, usedAutoCandidates: Bool, startedAt: Date,
        updatedAt: Date, moveCount: Int, deviceName: String
    ) {
        self.puzzleID = puzzleID
        self.entries = entries
        self.notes = notes
        self.elapsedSeconds = elapsedSeconds
        self.mistakes = mistakes
        self.hintsUsed = hintsUsed
        self.usedAutoCandidates = usedAutoCandidates
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.moveCount = moveCount
        self.deviceName = deviceName
    }

    /// Cells this record has filled in.
    public var filledCells: Int { entries.count { $0 != 0 } }

    /// Whether every digit this record holds also appears in `other`.
    /// True means one is simply further along the same road — no disagreement.
    public func isContainedIn(_ other: SavedGame) -> Bool {
        guard entries.count == other.entries.count else { return false }
        for index in entries.indices where entries[index] != 0 {
            if other.entries[index] != entries[index] { return false }
        }
        return true
    }

    /// Cells where the two records hold different digits.
    public func contradictions(with other: SavedGame) -> [Int] {
        guard entries.count == other.entries.count else { return [] }
        return entries.indices.filter { index in
            entries[index] != 0 && other.entries[index] != 0
                && entries[index] != other.entries[index]
        }
    }
}
