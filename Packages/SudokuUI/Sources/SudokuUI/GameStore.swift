import Foundation
import SudokuGameCenter
import SudokuKit
import SudokuSync

/// Reads and writes the two records above as JSON.
///
/// Milestone 4 replaces this with SwiftData plus CloudKit mirroring; until then
/// a file is enough and keeps the whole store testable without a database.
public actor GameStore {
    private let directory: URL
    private let fileManager = FileManager.default

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appendingPathComponent("Sudoku", isDirectory: true)
        }
    }

    private var currentGameURL: URL { directory.appendingPathComponent("current-game.json") }
    private var statsURL: URL { directory.appendingPathComponent("stats.json") }

    public func loadCurrentGame() -> SavedGame? { read(SavedGame.self, from: currentGameURL) }

    public func save(_ game: SavedGame) { write(game, to: currentGameURL) }

    public func clearCurrentGame() { try? fileManager.removeItem(at: currentGameURL) }

    public func loadStats() -> PlayerStats { read(PlayerStats.self, from: statsURL) ?? PlayerStats() }

    public func save(_ stats: PlayerStats) { write(stats, to: statsURL) }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func write(_ value: some Encodable, to url: URL) {
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

extension GameSession {
    /// Snapshots the session for storage.
    public func saved(deviceName: String, moveCount: Int, now: Date = .now) -> SavedGame {
        SavedGame(
            puzzleID: puzzle.id.description, entries: entries, notes: notes,
            elapsedSeconds: elapsedSeconds, mistakes: mistakes, hintsUsed: hintsUsed,
            usedAutoCandidates: usedAutoCandidates, startedAt: startedAt, updatedAt: now,
            moveCount: moveCount, deviceName: deviceName)
    }

    /// Rebuilds a session from a saved game, regenerating the puzzle from its id.
    public static func restore(from saved: SavedGame) -> GameSession? {
        guard let id = PuzzleID(saved.puzzleID) else { return nil }
        let session = GameSession(puzzle: PuzzleGenerator.generate(id), startedAt: saved.startedAt)
        session.restoreState(
            entries: saved.entries, notes: saved.notes, elapsedSeconds: saved.elapsedSeconds,
            mistakes: saved.mistakes, hintsUsed: saved.hintsUsed,
            usedAutoCandidates: saved.usedAutoCandidates)
        return session
    }
}
