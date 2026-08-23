import Foundation
import SudokuKit

extension GameSession {
    /// Puts a stored state back on the board. Undo history is not restored —
    /// it belongs to the sitting, not to the game.
    func restoreState(
        entries: [UInt8], notes: [Candidates], elapsedSeconds: Int,
        mistakes: Int, hintsUsed: Int, usedAutoCandidates: Bool
    ) {
        guard entries.count == 81, notes.count == 81 else { return }
        setRestored(entries: entries, notes: notes, elapsedSeconds: elapsedSeconds,
                    mistakes: mistakes, hintsUsed: hintsUsed,
                    usedAutoCandidates: usedAutoCandidates)
    }
}
