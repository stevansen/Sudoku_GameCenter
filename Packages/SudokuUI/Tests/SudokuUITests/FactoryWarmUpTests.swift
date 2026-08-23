import Foundation
import Testing
@testable import SudokuUI
import SudokuKit

/// The warm-up used to be the thing that made the app slow.
///
/// `PuzzleFactory` is an actor, and filling three puzzles of every tier takes
/// around fourteen seconds — hard alone is over two seconds each. Every request
/// queued behind all of it, so on a cold start the Mac sat for twelve seconds
/// with its difficulty buttons greyed out, looking broken.
///
/// Timings are machine-dependent, so these assert generously. They are here to
/// catch the shape of that bug coming back — a request stuck behind the warm-up
/// — not to police milliseconds.
@Suite("Warm-up", .serialized)
struct FactoryWarmUpTests {
    @Test func askingForAGameOvertakesTheWarmUp() async {
        let factory = PuzzleFactory(seed: 4242)
        let warming = Task { await factory.refill() }
        // Let the warm-up actually get going before asking.
        try? await Task.sleep(for: .milliseconds(200))

        let asked = Date()
        _ = await factory.puzzle(for: .hard)
        let waited = Date().timeIntervalSince(asked)

        #expect(waited < 6, "eine Anfrage stand hinter dem Vorwärmen an: \(waited)s")
        warming.cancel()
        _ = await warming.value
    }

    /// The cheap tiers are filled first, so the common case is ready almost at
    /// once even while the slow tiers are still being produced.
    @Test func theCheapTiersAreReadyFirst() async {
        let factory = PuzzleFactory(seed: 77)
        let warming = Task { await factory.refill() }
        try? await Task.sleep(for: .milliseconds(500))

        let asked = Date()
        _ = await factory.puzzle(for: .easy)
        let waited = Date().timeIntervalSince(asked)

        #expect(waited < 1, "leichte Stufen sollten längst bereitliegen: \(waited)s")
        warming.cancel()
        _ = await warming.value
    }

    /// Cancelling has to actually stop it, or a backgrounded app keeps a core
    /// busy producing puzzles nobody asked for.
    @Test func theWarmUpStopsWhenCancelled() async {
        let factory = PuzzleFactory(seed: 5)
        let warming = Task { await factory.refill() }
        try? await Task.sleep(for: .milliseconds(100))
        warming.cancel()

        let start = Date()
        _ = await warming.value
        #expect(Date().timeIntervalSince(start) < 4, "das Vorwärmen lief nach dem Abbruch weiter")
    }

    @Test func everyTierStillComesOutAtTheRequestedDifficulty() async {
        let factory = PuzzleFactory(seed: 31)
        for difficulty in Difficulty.allCases {
            let puzzle = await factory.puzzle(for: difficulty)
            #expect(puzzle.difficulty == difficulty)
        }
    }
}
