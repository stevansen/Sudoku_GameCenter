import Foundation
import SudokuGameCenter
import SudokuKit

/// Totals and history, in a shape two devices can merge without a clock.
///
/// The obvious way to sync totals is "newest wins", and it is wrong here: points
/// are a sum of what was earned, not a high score. Two devices played offline for
/// a week, one of them wins, and the other week is gone.
///
/// So nothing aggregate is stored. What is stored is the evidence — which puzzles
/// were solved, for how many points, on which days — in sets and per-key
/// dictionaries. Those merge by union, maximum and minimum, which is
/// commutative, associative and idempotent: it does not matter which device
/// merges first, or how many times. Everything a player sees is derived from
/// that evidence, so the totals cannot drift apart from the facts underneath.
public struct PlayerStats: Codable, Sendable, Equatable {
    /// Points earned per puzzle. The maximum wins on merge, so replaying one on
    /// another device cannot inflate the total.
    public private(set) var pointsByPuzzleID: [String: Int] = [:]
    /// Best time per puzzle. The minimum wins.
    public private(set) var secondsByPuzzleID: [String: Int] = [:]
    public private(set) var solvedWithoutHintIDs: Set<String> = []
    public private(set) var dailySolvedIDs: Set<String> = []
    /// Days, `yyyy-MM-dd`, on which something was finished. The streaks are runs
    /// through this set rather than counters that have to be kept in step.
    public private(set) var playedDays: Set<String> = []
    public private(set) var flawlessDays: Set<String> = []
    public private(set) var platforms: Set<String> = []

    /// Points from a stats file written before any of the above existed.
    ///
    /// There is nothing to attribute them to, so they ride along as one number
    /// and merge by maximum. Two devices that each carried pre-release totals
    /// would keep the larger rather than the sum — the only case this model does
    /// not handle exactly, and it can only happen to data that predates it.
    public private(set) var pointsBeforeMerging: Int = 0

    public init() {}

    // MARK: - What the player sees

    public var solvedPuzzleIDs: Set<String> { Set(pointsByPuzzleID.keys) }

    public var totalPoints: Int {
        pointsByPuzzleID.values.reduce(0, +) + pointsBeforeMerging
    }

    public var solvedCountByDifficulty: [String: Int] {
        var counts: [String: Int] = [:]
        for id in pointsByPuzzleID.keys {
            guard let tier = PuzzleID(id)?.difficulty.rawValue else { continue }
            counts[tier, default: 0] += 1
        }
        return counts
    }

    public var bestSecondsByDifficulty: [String: Int] {
        var best: [String: Int] = [:]
        for (id, seconds) in secondsByPuzzleID {
            guard let tier = PuzzleID(id)?.difficulty.rawValue else { continue }
            best[tier] = min(best[tier] ?? .max, seconds)
        }
        return best
    }

    public var solvedWithoutHints: Int { solvedWithoutHintIDs.count }
    public var dailySolved: Int { dailySolvedIDs.count }

    public var lastPlayedDay: String? { playedDays.max() }
    public var lastFlawlessDay: String? { flawlessDays.max() }

    /// The run of consecutive days ending on the most recent one played.
    public var streakDays: Int { Self.runEndingAtLatest(of: playedDays) }
    public var flawlessStreakDays: Int { Self.runEndingAtLatest(of: flawlessDays) }
    public var longestStreakDays: Int { Self.longestRun(in: playedDays) }

    /// The shape ``SudokuGameCenter`` works in.
    public var totals: PlayerTotals {
        PlayerTotals(
            totalPoints: totalPoints,
            solvedCount: pointsByPuzzleID.count,
            solvedByDifficulty: Dictionary(uniqueKeysWithValues: solvedCountByDifficulty
                .compactMap { key, value in Difficulty(rawValue: key).map { ($0, value) } }),
            solvedWithoutHints: solvedWithoutHints,
            dailySolved: dailySolved,
            streakDays: streakDays,
            flawlessStreakDays: flawlessStreakDays,
            bestSecondsByDifficulty: Dictionary(uniqueKeysWithValues: bestSecondsByDifficulty
                .compactMap { key, value in Difficulty(rawValue: key).map { ($0, value) } }),
            platforms: platforms)
    }

    public func hasSolved(_ id: PuzzleID) -> Bool {
        pointsByPuzzleID[id.description] != nil
    }

    // MARK: - Recording

    /// Folds a finished game into the totals and returns what it scored.
    @discardableResult
    public mutating func record(
        puzzle: Puzzle, session: GameSession, on date: Date = .now,
        calendar: Calendar = .current, deviceName: String = "", isDaily: Bool = false
    ) -> ScoreBreakdown {
        let today = Self.day(of: date, calendar: calendar)
        let key = puzzle.id.description
        let isRepeat = pointsByPuzzleID[key] != nil

        // Today counts before the streak is read, because the bonus is for the
        // run this game is part of.
        playedDays.insert(today)

        let breakdown = Scoring.breakdown(
            for: session.record(streakDays: streakDays, isRepeat: isRepeat))

        pointsByPuzzleID[key] = max(pointsByPuzzleID[key] ?? 0, breakdown.total)
        secondsByPuzzleID[key] = min(secondsByPuzzleID[key] ?? .max, session.elapsedSeconds)

        if session.hintsUsed == 0 { solvedWithoutHintIDs.insert(key) }
        if isDaily { dailySolvedIDs.insert(key) }
        if !deviceName.isEmpty { platforms.insert(deviceName) }
        if session.mistakes == 0 { flawlessDays.insert(today) }

        return breakdown
    }

    // MARK: - Merging

    /// Folds another device's evidence into this one.
    ///
    /// Union, maximum, minimum — every one of them idempotent, so merging twice
    /// changes nothing and the order two devices meet in does not matter.
    public func merged(with other: PlayerStats) -> PlayerStats {
        var merged = self
        merged.pointsByPuzzleID.merge(other.pointsByPuzzleID, uniquingKeysWith: max)
        merged.secondsByPuzzleID.merge(other.secondsByPuzzleID, uniquingKeysWith: min)
        merged.solvedWithoutHintIDs.formUnion(other.solvedWithoutHintIDs)
        merged.dailySolvedIDs.formUnion(other.dailySolvedIDs)
        merged.playedDays.formUnion(other.playedDays)
        merged.flawlessDays.formUnion(other.flawlessDays)
        merged.platforms.formUnion(other.platforms)
        merged.pointsBeforeMerging = max(pointsBeforeMerging, other.pointsBeforeMerging)
        return merged
    }

    // MARK: - Days

    static func day(of date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// Days are `yyyy-MM-dd`, so they sort as strings; stepping back a day means
    /// real date arithmetic, which is what this does.
    static func previousDay(_ day: String) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day),
              let earlier = calendar.date(byAdding: .day, value: -1, to: date)
        else { return nil }
        return formatter.string(from: earlier)
    }

    static func runEndingAtLatest(of days: Set<String>) -> Int {
        guard var day = days.max() else { return 0 }
        var length = 1
        while let earlier = previousDay(day), days.contains(earlier) {
            length += 1
            day = earlier
        }
        return length
    }

    static func longestRun(in days: Set<String>) -> Int {
        var longest = 0
        for day in days {
            // Only measure from the start of a run, or this is quadratic for no
            // reason.
            if let earlier = previousDay(day), days.contains(earlier) { continue }
            var length = 1
            var current = day
            while let next = nextDay(current), days.contains(next) {
                length += 1
                current = next
            }
            longest = max(longest, length)
        }
        return longest
    }

    static func nextDay(_ day: String) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day),
              let later = calendar.date(byAdding: .day, value: 1, to: date)
        else { return nil }
        return formatter.string(from: later)
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case pointsByPuzzleID, secondsByPuzzleID, solvedWithoutHintIDs, dailySolvedIDs
        case playedDays, flawlessDays, platforms, pointsBeforeMerging
        // Written by builds before the totals became mergeable.
        case totalPoints, solvedPuzzleIDs, bestSecondsByDifficulty, lastPlayedDay
    }

    /// Hand-written so that a stats file from an older build still loads.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pointsByPuzzleID = try container.decodeIfPresent([String: Int].self, forKey: .pointsByPuzzleID) ?? [:]
        secondsByPuzzleID = try container.decodeIfPresent([String: Int].self, forKey: .secondsByPuzzleID) ?? [:]
        solvedWithoutHintIDs = try container.decodeIfPresent(Set<String>.self, forKey: .solvedWithoutHintIDs) ?? []
        dailySolvedIDs = try container.decodeIfPresent(Set<String>.self, forKey: .dailySolvedIDs) ?? []
        playedDays = try container.decodeIfPresent(Set<String>.self, forKey: .playedDays) ?? []
        flawlessDays = try container.decodeIfPresent(Set<String>.self, forKey: .flawlessDays) ?? []
        platforms = try container.decodeIfPresent(Set<String>.self, forKey: .platforms) ?? []
        pointsBeforeMerging = try container.decodeIfPresent(Int.self, forKey: .pointsBeforeMerging) ?? 0

        // An older file: keep what can be attributed, and carry the rest as one
        // unattributable number rather than throwing the player's points away.
        if pointsByPuzzleID.isEmpty,
           let solved = try container.decodeIfPresent(Set<String>.self, forKey: .solvedPuzzleIDs) {
            for id in solved { pointsByPuzzleID[id] = 0 }
            pointsBeforeMerging = try container.decodeIfPresent(Int.self, forKey: .totalPoints) ?? 0
            if let day = try container.decodeIfPresent(String.self, forKey: .lastPlayedDay) {
                playedDays.insert(day)
            }
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pointsByPuzzleID, forKey: .pointsByPuzzleID)
        try container.encode(secondsByPuzzleID, forKey: .secondsByPuzzleID)
        try container.encode(solvedWithoutHintIDs, forKey: .solvedWithoutHintIDs)
        try container.encode(dailySolvedIDs, forKey: .dailySolvedIDs)
        try container.encode(playedDays, forKey: .playedDays)
        try container.encode(flawlessDays, forKey: .flawlessDays)
        try container.encode(platforms, forKey: .platforms)
        try container.encode(pointsBeforeMerging, forKey: .pointsBeforeMerging)
    }
}
