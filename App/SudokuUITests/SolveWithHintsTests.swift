import XCTest

/// Plays a hard puzzle to the end using nothing but the hint button.
///
/// This is the thing a stuck player actually does, and it exercises the whole
/// chain: the solver finds the next deduction, the card explains it, and the
/// board takes it. If any technique the tier needs produces advice the app
/// cannot act on, the run stalls here rather than in someone's hands.
final class SolveWithHintsTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// A dozen rounds, not the whole puzzle.
    ///
    /// Playing all 53 cells through the interface takes nineteen minutes, almost
    /// all of it spent asking the accessibility tree how many cells are still
    /// empty. It was worth doing once — it is what found the stall — but it does
    /// not belong in a suite that runs on every change. That the puzzle can be
    /// *finished* on hints is checked per tier in HintCompletionTests, against
    /// the model, in about five seconds. This checks the part only the interface
    /// can answer: that every hint actually offers a button to press.
    func testEveryHintOffersSomethingToPress() {
        let app = XCUIApplication()
        app.launchArguments = ["-skip-onboarding", "-open-game", "hard"]
        app.launch()

        let board = app.descendants(matching: .any)["Sudoku-Brett"]
        XCTAssertTrue(board.waitForExistence(timeout: 60))

        func emptyCells() -> Int {
            board.descendants(matching: .any).allElementsBoundByIndex
                .filter { $0.label.hasSuffix(", leer") }.count
        }

        let hint = app.buttons["Hinweis"]
        let place = app.buttons["Eintragen"]
        let acknowledge = app.buttons["Verstanden"]

        let before = emptyCells()
        XCTAssertGreaterThan(before, 0, "das Brett ist schon voll")

        for round in 1...12 {
            guard hint.waitForExistence(timeout: 10) else {
                XCTFail("kein Hinweis-Knopf mehr in Runde \(round)")
                return
            }
            hint.tap()

            // The point of the whole exercise. A hint that only rules candidates
            // out leaves the board untouched, and asking again returns the same
            // step — so it has to offer the placement it opens up instead.
            guard place.waitForExistence(timeout: 10) else {
                let what = acknowledge.exists ? "nur \"Verstanden\"" : "gar nichts"
                XCTFail("Runde \(round): der Hinweis bot \(what) — damit kommt niemand weiter")
                return
            }
            place.tap()
        }

        let after = emptyCells()
        XCTAssertEqual(before - after, 12, "zwölf Hinweise, \(before - after) Felder gefüllt")
    }
}
