import Foundation
import Testing
@testable import SudokuUI
import SudokuKit

@MainActor
@Suite("Game session")
struct GameSessionTests {
    /// A fixed, cheap puzzle so the tests do not pay for generation.
    static let puzzle = PuzzleGenerator.generate(difficulty: .easy, seed: 1)

    func makeSession() -> GameSession { GameSession(puzzle: Self.puzzle) }

    func firstEmptyCell(_ session: GameSession) -> Int {
        (0..<81).first { session.entries[$0] == 0 }!
    }

    @Test func givensCannotBeChanged() {
        let session = makeSession()
        let given = (0..<81).first { session.isGiven($0) }!
        let before = session.entries[given]
        session.enter(5, at: given)
        #expect(session.entries[given] == before)
    }

    @Test func enteringAndClearingADigit() {
        let session = makeSession()
        let cell = firstEmptyCell(session)
        let correct = Int(session.puzzle.solution[cell])
        session.enter(correct, at: cell)
        #expect(session.entries[cell] == UInt8(correct))
        // Pressing the same digit again takes it back out.
        session.enter(correct, at: cell)
        #expect(session.entries[cell] == 0)
    }

    @Test func wrongDigitsCountAsMistakesOnlyWhenCheckingIsImmediate() {
        let session = makeSession()
        let cell = firstEmptyCell(session)
        let wrong = (1...9).first { $0 != Int(session.puzzle.solution[cell]) }!

        session.errorChecking = .off
        session.enter(wrong, at: cell)
        #expect(session.mistakes == 0)
        #expect(session.wrongCells().isEmpty)

        session.clear(at: cell)
        session.errorChecking = .immediate
        session.enter(wrong, at: cell)
        #expect(session.mistakes == 1)
        #expect(session.wrongCells().contains(cell))
    }

    @Test func undoTakesBackTheMistakeCountToo() {
        let session = makeSession()
        let cell = firstEmptyCell(session)
        let wrong = (1...9).first { $0 != Int(session.puzzle.solution[cell]) }!
        session.enter(wrong, at: cell)
        #expect(session.mistakes == 1)
        session.undo()
        #expect(session.mistakes == 0)
        #expect(session.entries[cell] == 0)
        session.redo()
        #expect(session.mistakes == 1)
        #expect(session.entries[cell] == UInt8(wrong))
    }

    @Test func notesToggleAndSurviveUndo() {
        let session = makeSession()
        let cell = firstEmptyCell(session)
        session.inputMode = .note
        session.enter(3, at: cell)
        session.enter(7, at: cell)
        #expect(session.notes[cell].digits == [3, 7])
        session.enter(3, at: cell)
        #expect(session.notes[cell].digits == [7])
        session.undo()
        #expect(session.notes[cell].digits == [3, 7])
    }

    /// Placing a digit clears it from the notes of every peer, and one undo has
    /// to take the whole thing back — otherwise undo would feel broken.
    @Test func placingADigitCleansPeerNotesAndUndoesAsOneStep() {
        let session = makeSession()
        let cell = firstEmptyCell(session)
        let digit = Int(session.puzzle.solution[cell])
        let peer = Units.peers[cell].first { session.entries[$0] == 0 }!

        session.inputMode = .note
        session.enter(digit, at: peer)
        #expect(session.notes[peer].contains(digit))

        session.inputMode = .digit
        session.enter(digit, at: cell)
        #expect(!session.notes[peer].contains(digit))

        session.undo()
        #expect(session.entries[cell] == 0)
        #expect(session.notes[peer].contains(digit))
    }

    @Test func conflictsAreShownEvenWithoutErrorChecking() {
        let session = makeSession()
        session.errorChecking = .off
        let given = (0..<81).first { session.isGiven($0) }!
        let digit = Int(session.puzzle.givens[given])
        let peer = Units.peers[given].first { session.entries[$0] == 0 }!
        session.enter(digit, at: peer)
        #expect(session.conflicts.contains(peer))
        #expect(session.conflicts.contains(given))
    }

    @Test func autoCandidatesFillOnlyWhatIsStillPossible() {
        let session = makeSession()
        session.fillAutoCandidates()
        #expect(session.usedAutoCandidates)
        let cell = firstEmptyCell(session)
        #expect(session.notes[cell].contains(Int(session.puzzle.solution[cell])))
        #expect(session.notes[cell].count < 9)
    }

    @Test func aHintNamesTheTechniqueAndCanBeApplied() {
        let session = makeSession()
        let hint = session.requestHint()
        #expect(hint != nil)
        #expect(session.hintsUsed == 1)
        #expect(!HintText.explanation(for: hint!).isEmpty)
        session.applyHint()
        let placement = hint!.placements.first!
        #expect(session.entries[placement.cell] == UInt8(placement.digit))
    }

    @Test func solvingTheGridFinishesTheGame() {
        let session = makeSession()
        for cell in 0..<81 where !session.isGiven(cell) {
            session.enter(Int(session.puzzle.solution[cell]), at: cell)
        }
        #expect(session.isSolved)
        #expect(session.completedAt != nil)
        #expect(session.mistakes == 0)
    }

    @Test func aPausedGameAcceptsNoInputAndStopsTheClock() {
        let session = makeSession()
        session.pause()
        session.tick()
        #expect(session.elapsedSeconds == 0)
        let cell = firstEmptyCell(session)
        session.enter(Int(session.puzzle.solution[cell]), at: cell)
        #expect(session.entries[cell] == 0)
        session.resume()
        session.tick()
        #expect(session.elapsedSeconds == 1)
    }
}
