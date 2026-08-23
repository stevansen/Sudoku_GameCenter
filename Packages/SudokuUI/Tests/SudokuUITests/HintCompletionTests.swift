import Foundation
import Testing
@testable import SudokuUI
import SudokuKit

/// A player who is stuck presses the hint button. It has to keep working until
/// the puzzle is finished.
///
/// It did not. A step that only rules candidates out leaves the board unchanged,
/// and the next hint recomputes its candidates from that same board and finds
/// the very same step. On the tiers defined by needing such techniques that is
/// not an edge case — a hard puzzle stalled at 33 empty cells after 25 hints.
@Suite("Solving on hints alone", .serialized)
struct HintCompletionTests {
    @Test(arguments: Difficulty.allCases)
    func everyTierCanBeFinishedOnHints(difficulty: Difficulty) {
        let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: 20260823)
        let session = GameSession(puzzle: puzzle)

        var hints = 0
        while session.filledCount < 81 {
            hints += 1
            guard hints <= 200 else {
                let empty = 81 - session.filledCount
                Issue.record("\(difficulty.rawValue): über 200 Hinweise, noch \(empty) leer")
                return
            }
            let before = session.filledCount
            guard session.requestHint() != nil else {
                let empty = 81 - session.filledCount
                Issue.record("\(difficulty.rawValue): kein Hinweis mehr, noch \(empty) leer")
                return
            }
            session.applyHint()

            guard session.filledCount > before else {
                let empty = 81 - session.filledCount
                Issue.record("\(difficulty.rawValue): Hinweis \(hints) hat nichts eingetragen — festgefahren bei \(empty) leeren Feldern")
                return
            }
        }

        #expect(session.isSolved, "voll, aber nicht richtig")
        #expect(session.mistakes == 0, "ein Hinweis hat etwas Falsches gesetzt")
    }

    /// The explanation is about the step; the placement may come from further
    /// along. Both have to be there, or the card offers nothing to press.
    @Test func anEliminationOnlyStepStillOffersSomethingToDo() {
        let puzzle = PuzzleGenerator.generate(difficulty: .hard, seed: 4242)
        let session = GameSession(puzzle: puzzle)

        var sawEliminationOnly = false
        for _ in 0..<80 where session.filledCount < 81 {
            guard let deduction = session.requestHint() else { break }
            if deduction.placements.isEmpty {
                sawEliminationOnly = true
                #expect(session.hintPlacement != nil,
                        "\(deduction.technique) erklärt etwas, bietet aber nichts an")
            }
            session.applyHint()
        }
        #expect(sawEliminationOnly,
                "kein Ausschluss-Hinweis vorgekommen — dieser Test prüft dann nichts")
    }
}
