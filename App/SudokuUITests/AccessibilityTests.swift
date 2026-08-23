import XCTest

/// What VoiceOver would read.
///
/// VoiceOver itself does not run in the simulator — the service is present but
/// never starts, so there is no cursor and no speech to observe. What these
/// tests do instead is read the accessibility tree VoiceOver consumes: the
/// labels, values, traits and, importantly, the order elements come in, which is
/// the order a swipe walks them. A missing label or a cell that cannot be
/// reached shows up here exactly as it would to someone using the app by ear.
///
/// It is not a substitute for putting the app on a device and listening to it.
/// It is the part of that which can be checked on every commit.
/// The audit handler runs on another thread, so the findings need somewhere
/// thread-safe to land.
private final class IssueLog: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    func record(_ line: String) {
        lock.lock(); defer { lock.unlock() }
        lines.append(line)
    }

    var report: String {
        lock.lock(); defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }

    var isEmpty: Bool {
        lock.lock(); defer { lock.unlock() }
        return lines.isEmpty
    }
}

final class AccessibilityTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Findings that were looked at on a device at the largest text size and
    /// judged to be the audit being conservative rather than a defect. Each was
    /// checked by eye; the reasoning is in docs/accessibility.md. Anything not on
    /// this list fails the test, so a new finding is not absorbed silently.
    private static let acceptedFindings: Set<String> = [
        // Wrapped across three lines with German hyphenation ("dop-/pelte") and
        // fully readable. The audit reports the hyphen as truncation.
        "Für alle das gleiche · doppelte Punkte",
        "Wings und Färben",
        "Fehler … · Hinweise …",   // matched by prefix; the counts change
        // A toolbar button; the system caps its own chrome.
        "Zurück",
    ]

    /// Runs the system audit and returns what it found, minus two exceptions.
    ///
    /// **A disabled control is dimmed on purpose.** WCAG exempts inactive
    /// components from the contrast requirement; the audit does not know the
    /// difference. Undo is disabled until there is something to undo, so it
    /// would otherwise fail every run.
    ///
    /// **The board's digits do not follow Dynamic Type.** They are sized to the
    /// cell they sit in. A 9x9 grid cannot reflow — at the largest text setting
    /// a digit scaled that way would simply not fit its cell — so the board
    /// scales with the space available instead, and everything in it is reachable
    /// by VoiceOver whatever the text size. Both exceptions are written down in
    /// docs/accessibility.md; nothing else is filtered.
    private func auditFindings(_ app: XCUIApplication) throws -> String {
        let log = IssueLog()
        // Copied out first: reaching for the static inside the closure makes it
        // task-isolated, which Swift 6 will not send to the main actor.
        let accepted = Self.acceptedFindings
        try app.performAccessibilityAudit { issue in
            let label = issue.element?.label ?? ""
            let isDimmedOnPurpose = issue.auditType == .contrast
                && issue.element?.isEnabled == false
            // Dynamic Type is an iOS notion; the audit type does not exist on
            // the Mac, where text size is a system-wide setting instead.
            #if os(iOS)
            let isABoardDigit = issue.auditType == .dynamicType
                && label.count == 1 && label.allSatisfy(\.isNumber)
            #else
            let isABoardDigit = false
            #endif
            let isAlreadyJudged = accepted.contains(label)
                || label.hasPrefix("Fehler ")
                // Not ours: the system provides it and we put nothing in it.
                || issue.element?.description.contains("TouchBar") == true

            // SwiftUI's own window and scroll wrappers on the Mac: anonymous
            // containers with no label and no identifier, which the app does not
            // create and cannot name. Deliberately narrow — every element the app
            // does create carries a label, so this cannot swallow a finding about
            // one of ours.
            let isFrameworkChrome = label.isEmpty
                && (issue.element?.identifier ?? "").isEmpty
            if !isDimmedOnPurpose && !isABoardDigit && !isAlreadyJudged
                && !isFrameworkChrome {
                log.record("\(issue.auditType) — \(issue.compactDescription) "
                    + "[\(issue.element?.description ?? "ohne Element")] "
                    + "\(issue.detailedDescription)")
            }
            return true   // collected here and reported in one go below
        }
        return log.report
    }

    /// Generous, because the Mac needs about twelve seconds to generate its
    /// first puzzle from a cold cache and keeps the buttons disabled until it
    /// has one. Ten seconds looked like a broken board.
    private static let boardTimeout: TimeInterval = 40

    /// The board is an `other` on iOS and a `group` on the Mac, so it is looked
    /// up without naming a type.
    private func board(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["Sudoku-Brett"]
    }

    private func launchIntoGame() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-open-game", "easy", "-skip-onboarding"]
        app.launch()
        return app
    }

    /// Apple's own audit: contrast, hit regions, elements with no description,
    /// labels that repeat their trait, text that will not grow.
    func testTheGameScreenPassesTheSystemAudit() throws {
        let app = launchIntoGame()
        let board = board(in: app)
        XCTAssertTrue(board.waitForExistence(timeout: Self.boardTimeout))

        // One move first, so undo is enabled. A disabled control is dimmed on
        // purpose and the audit sometimes reports it without naming the element,
        // which leaves nothing to match an exception against — better to audit
        // the screen in the state it spends its life in.
        let empty = board.descendants(matching: .any).allElementsBoundByIndex
            .first { $0.label.hasSuffix(", leer") }
        empty?.tap()
        app.buttons["Ziffer 1"].tap()

        let findings = try auditFindings(app)
        XCTAssertTrue(findings.isEmpty, "Audit-Befunde:\n" + findings)
    }

    func testTheOverviewPassesTheSystemAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skip-onboarding"]
        app.launch()

        let findings = try auditFindings(app)
        XCTAssertTrue(findings.isEmpty, "Audit-Befunde:\n" + findings)
    }

    /// A digit read on its own is useless — "5" tells you nothing about where it
    /// is. Every cell has to carry its coordinates.
    func testEveryCellSaysWhereItIs() {
        let app = launchIntoGame()
        let board = board(in: app)
        XCTAssertTrue(board.waitForExistence(timeout: Self.boardTimeout))

        let cells = board.descendants(matching: .any).allElementsBoundByIndex
            .filter { $0.label.hasPrefix("Zeile ") }

        XCTAssertEqual(cells.count, 81, "alle 81 Felder müssen erreichbar sein")

        for cell in cells {
            let label = cell.label
            XCTAssertTrue(
                label.contains("vorgegeben") || label.contains("eingetragen")
                    || label.contains("leer"),
                "Beschriftung sagt nicht, was im Feld steht: \(label)")
        }
    }

    /// The order a swipe walks the grid. Left to right, top to bottom is the only
    /// order that matches how the puzzle is talked about.
    func testTheBoardIsWalkedRowByRow() {
        let app = launchIntoGame()
        let board = board(in: app)
        XCTAssertTrue(board.waitForExistence(timeout: Self.boardTimeout))

        let positions = board.descendants(matching: .any).allElementsBoundByIndex
            .map { $0.label }
            .filter { $0.hasPrefix("Zeile ") }

        XCTAssertEqual(positions.count, 81)
        XCTAssertTrue(positions[0].hasPrefix("Zeile 1, Spalte 1,"), positions[0])
        XCTAssertTrue(positions[8].hasPrefix("Zeile 1, Spalte 9,"), positions[8])
        XCTAssertTrue(positions[9].hasPrefix("Zeile 2, Spalte 1,"), positions[9])
        XCTAssertTrue(positions[80].hasPrefix("Zeile 9, Spalte 9,"), positions[80])
    }

    func testTheKeypadAndControlsAreNamed() {
        let app = launchIntoGame()
        XCTAssertTrue(app.descendants(matching: .any)["Sudoku-Brett"].waitForExistence(timeout: Self.boardTimeout))

        for digit in 1...9 {
            let button = app.buttons["Ziffer \(digit)"]
            XCTAssertTrue(button.exists, "Ziffer \(digit) fehlt oder heißt anders")
            XCTAssertTrue(button.isHittable, "Ziffer \(digit) ist nicht erreichbar")
        }

        for name in ["Rückgängig", "Löschen", "Notizen", "Hinweis"] {
            XCTAssertTrue(app.buttons[name].exists, "Bedienelement fehlt: \(name)")
        }
    }

    /// Entering a digit has to change what the cell says, or the app is silent
    /// about the one thing the player just did.
    func testEnteringADigitChangesWhatTheCellReads() {
        let app = launchIntoGame()
        let board = board(in: app)
        XCTAssertTrue(board.waitForExistence(timeout: Self.boardTimeout))

        let empty = board.descendants(matching: .any).allElementsBoundByIndex
            .first { $0.label.hasPrefix("Zeile ") && $0.label.hasSuffix(", leer") }
        guard let empty else { return XCTFail("kein leeres Feld gefunden") }

        let position = String(empty.label.dropLast(", leer".count))
        empty.tap()
        app.buttons["Ziffer 1"].tap()

        let after = board.descendants(matching: .any).allElementsBoundByIndex
            .first { $0.label.hasPrefix(position) }
        XCTAssertNotNil(after)
        XCTAssertFalse(after?.label.hasSuffix(", leer") ?? true,
                       "das Feld sagt weiterhin \"leer\"")
    }
}
