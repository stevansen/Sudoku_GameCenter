import Foundation
import Testing
@testable import SudokuUI
import SudokuKit

@MainActor
@Suite("Store and stats")
struct StoreTests {
    @Test func aSavedGameRestoresFromItsIdAlone() async throws {
        let puzzle = PuzzleGenerator.generate(difficulty: .medium, seed: 4711)
        let session = GameSession(puzzle: puzzle)
        let cell = (0..<81).first { session.entries[$0] == 0 }!
        session.enter(Int(puzzle.solution[cell]), at: cell)

        let saved = session.saved(deviceName: "Test", moveCount: 1)
        // The grid is not in the record — only the id is.
        #expect(saved.puzzleID == puzzle.id.description)

        let restored = try #require(GameSession.restore(from: saved))
        #expect(restored.puzzle.givens == puzzle.givens)
        #expect(restored.entries == session.entries)
        #expect(restored.notes == session.notes)
    }

    @Test func theStoreRoundTripsThroughDisk() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = GameStore(directory: directory)

        #expect(await store.loadCurrentGame() == nil)

        let puzzle = PuzzleGenerator.generate(difficulty: .easy, seed: 9)
        let session = GameSession(puzzle: puzzle)
        let saved = session.saved(deviceName: "Test", moveCount: 3)
        await store.save(saved)
        #expect(await store.loadCurrentGame() == saved)

        await store.clearCurrentGame()
        #expect(await store.loadCurrentGame() == nil)
    }

    @Test func statsAccumulateAndAPuzzlePaysOnlyOnce() {
        let puzzle = PuzzleGenerator.generate(difficulty: .hard, seed: 12)
        var stats = PlayerStats()

        let session = GameSession(puzzle: puzzle)
        for cell in 0..<81 where !session.isGiven(cell) {
            session.enter(Int(puzzle.solution[cell]), at: cell)
        }

        let first = stats.record(puzzle: puzzle, session: session)
        #expect(first.total > 0)
        #expect(stats.totalPoints == first.total)
        #expect(stats.solvedCountByDifficulty["hard"] == 1)
        #expect(stats.streakDays == 1)
        #expect(stats.bestSecondsByDifficulty["hard"] == session.elapsedSeconds)

        let second = stats.record(puzzle: puzzle, session: session)
        #expect(second.total == 0, "the same puzzle must not pay twice")
        #expect(stats.totalPoints == first.total)
    }

    @Test func aStreakNeedsConsecutiveDays() {
        let puzzle = PuzzleGenerator.generate(difficulty: .easy, seed: 3)
        let session = GameSession(puzzle: puzzle)
        for cell in 0..<81 where !session.isGiven(cell) {
            session.enter(Int(puzzle.solution[cell]), at: cell)
        }
        var stats = PlayerStats()
        let day = Date(timeIntervalSince1970: 1_800_000_000)

        _ = stats.record(puzzle: puzzle, session: session, on: day)
        #expect(stats.streakDays == 1)
        _ = stats.record(puzzle: puzzle, session: session, on: day.addingTimeInterval(86_400))
        #expect(stats.streakDays == 2)
        // A day skipped resets it.
        _ = stats.record(puzzle: puzzle, session: session, on: day.addingTimeInterval(86_400 * 4))
        #expect(stats.streakDays == 1)
        #expect(stats.longestStreakDays == 2)
    }
}
