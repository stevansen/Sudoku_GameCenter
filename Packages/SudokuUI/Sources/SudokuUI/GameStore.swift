import Foundation
import SudokuKit

/// A game in progress, in the form that survives quitting the app.
///
/// The puzzle itself is not stored — only its id. Everything else is the
/// player's work on top of it. That is the whole point of the seed design:
/// this record is a few hundred bytes and regenerates its grid anywhere.
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
    /// Monotonic, and the first tie-breaker when two devices disagree.
    public var moveCount: Int
    public var deviceName: String
}

/// Totals and history. Kept separate from the running game because it is
/// appended to rather than rewritten.
public struct PlayerStats: Codable, Sendable, Equatable {
    public var totalPoints: Int = 0
    public var solvedPuzzleIDs: Set<String> = []
    public var solvedCountByDifficulty: [String: Int] = [:]
    public var bestSecondsByDifficulty: [String: Int] = [:]
    public var streakDays: Int = 0
    public var longestStreakDays: Int = 0
    /// Day of the last completed puzzle, as `yyyy-MM-dd` in the local calendar.
    public var lastPlayedDay: String?

    public init() {}

    public func hasSolved(_ id: PuzzleID) -> Bool { solvedPuzzleIDs.contains(id.description) }

    /// Folds a finished game into the totals and returns what it scored.
    public mutating func record(
        puzzle: Puzzle, session: GameSession, on date: Date = .now,
        calendar: Calendar = .current
    ) -> ScoreBreakdown {
        let today = Self.day(of: date, calendar: calendar)
        if let last = lastPlayedDay, last != today {
            let yesterday = Self.day(of: date.addingTimeInterval(-86_400), calendar: calendar)
            streakDays = last == yesterday ? streakDays + 1 : 1
        } else if lastPlayedDay == nil {
            streakDays = 1
        }
        lastPlayedDay = today
        longestStreakDays = max(longestStreakDays, streakDays)

        let isRepeat = solvedPuzzleIDs.contains(puzzle.id.description)
        let breakdown = Scoring.breakdown(
            for: session.record(streakDays: streakDays, isRepeat: isRepeat))

        totalPoints += breakdown.total
        solvedPuzzleIDs.insert(puzzle.id.description)
        let tier = puzzle.difficulty.rawValue
        solvedCountByDifficulty[tier, default: 0] += 1
        let best = bestSecondsByDifficulty[tier]
        if best == nil || session.elapsedSeconds < best! {
            bestSecondsByDifficulty[tier] = session.elapsedSeconds
        }
        return breakdown
    }

    static func day(of date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
}

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
