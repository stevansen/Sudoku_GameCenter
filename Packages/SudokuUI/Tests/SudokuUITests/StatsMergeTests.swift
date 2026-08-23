import Foundation
import Testing
@testable import SudokuUI
import SudokuGameCenter
import SudokuKit
import SudokuSync

/// Totals have to survive two devices playing without seeing each other.
///
/// "Newest wins" would be wrong: points are a sum of what was earned, not a high
/// score, so a week of offline play on the losing device would simply vanish.
@Suite("Merging totals")
struct StatsMergeTests {
    func solve(_ stats: inout PlayerStats, difficulty: Difficulty, seed: UInt64,
               on day: Date, seconds: Int = 300, mistakes: Int = 0, hints: Int = 0,
               device: String = "iPhone") {
        let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: seed)
        let session = GameSession(puzzle: puzzle)
        session.restoreState(
            entries: puzzle.solution.cells, notes: Array(repeating: 0, count: 81),
            elapsedSeconds: seconds, mistakes: mistakes, hintsUsed: hints,
            usedAutoCandidates: false)
        stats.record(puzzle: puzzle, session: session, on: day, deviceName: device)
    }

    static let day = Date(timeIntervalSince1970: 1_760_000_000)

    @Test func pointsFromBothDevicesAreKept() {
        var phone = PlayerStats(), mac = PlayerStats()
        solve(&phone, difficulty: .easy, seed: 1, on: Self.day, device: "iPhone")
        solve(&mac, difficulty: .medium, seed: 2, on: Self.day, device: "Mac")

        let merged = phone.merged(with: mac)
        #expect(merged.totalPoints == phone.totalPoints + mac.totalPoints)
        #expect(merged.solvedPuzzleIDs.count == 2)
        #expect(merged.platforms == ["iPhone", "Mac"])
    }

    /// The same puzzle solved on both devices is one solve, not two.
    @Test func theSamePuzzleIsNotCountedTwice() {
        var phone = PlayerStats(), mac = PlayerStats()
        solve(&phone, difficulty: .hard, seed: 7, on: Self.day, seconds: 400)
        solve(&mac, difficulty: .hard, seed: 7, on: Self.day, seconds: 250)

        let merged = phone.merged(with: mac)
        #expect(merged.solvedPuzzleIDs.count == 1)
        #expect(merged.totalPoints == max(phone.totalPoints, mac.totalPoints))
        #expect(merged.bestSecondsByDifficulty["hard"] == 250, "die bessere Zeit gewinnt")
    }

    /// Order and repetition must not matter, or two devices syncing back and
    /// forth would drift.
    @Test func mergingIsCommutativeAndIdempotent() {
        var phone = PlayerStats(), mac = PlayerStats()
        solve(&phone, difficulty: .easy, seed: 3, on: Self.day)
        solve(&mac, difficulty: .evil, seed: 4, on: Self.day.addingTimeInterval(86_400))

        let oneWay = phone.merged(with: mac)
        let otherWay = mac.merged(with: phone)
        #expect(oneWay == otherWay)
        #expect(oneWay.merged(with: mac) == oneWay)
        #expect(oneWay.merged(with: oneWay) == oneWay)
    }

    @Test func streaksAreDerivedFromTheDaysThemselves() {
        var phone = PlayerStats(), mac = PlayerStats()
        // Two devices, alternating days — neither has a streak alone.
        solve(&phone, difficulty: .easy, seed: 11, on: Self.day)
        solve(&mac, difficulty: .easy, seed: 12, on: Self.day.addingTimeInterval(86_400))
        solve(&phone, difficulty: .easy, seed: 13, on: Self.day.addingTimeInterval(86_400 * 2))

        let merged = phone.merged(with: mac)
        #expect(merged.streakDays == 3, "drei aufeinanderfolgende Tage über beide Geräte")
        #expect(merged.longestStreakDays == 3)
    }

    @Test func aGapEndsTheStreakButNotTheRecord() {
        var stats = PlayerStats()
        solve(&stats, difficulty: .easy, seed: 21, on: Self.day)
        solve(&stats, difficulty: .easy, seed: 22, on: Self.day.addingTimeInterval(86_400))
        solve(&stats, difficulty: .easy, seed: 23, on: Self.day.addingTimeInterval(86_400 * 5))

        #expect(stats.streakDays == 1)
        #expect(stats.longestStreakDays == 2)
    }

    @Test func hintlessAndDailyCountsMergeWithoutDoubleCounting() {
        var phone = PlayerStats(), mac = PlayerStats()
        solve(&phone, difficulty: .easy, seed: 31, on: Self.day, hints: 0)
        solve(&mac, difficulty: .easy, seed: 31, on: Self.day, hints: 0)   // dasselbe Rätsel
        solve(&mac, difficulty: .easy, seed: 32, on: Self.day, hints: 3)

        let merged = phone.merged(with: mac)
        #expect(merged.solvedWithoutHints == 1)
    }

    /// A stats file from a build before any of this existed still has to load,
    /// and its points must not simply disappear.
    @Test func anOlderFileKeepsItsPoints() throws {
        let legacy = """
        {"totalPoints":4321,"solvedPuzzleIDs":["v1-hard-000000000000007b"],\
        "streakDays":3,"lastPlayedDay":"2026-08-20","platforms":["Mac"]}
        """.data(using: .utf8)!

        let stats = try JSONDecoder().decode(PlayerStats.self, from: legacy)
        #expect(stats.totalPoints == 4321)
        #expect(stats.solvedPuzzleIDs.count == 1)
        #expect(stats.platforms == ["Mac"])
        #expect(stats.lastPlayedDay == "2026-08-20")
    }

    @Test func totalsSurviveAnEncodeDecodeRound() throws {
        var stats = PlayerStats()
        solve(&stats, difficulty: .expert, seed: 41, on: Self.day, seconds: 900)
        let data = try JSONEncoder().encode(stats)
        let restored = try JSONDecoder().decode(PlayerStats.self, from: data)
        #expect(restored == stats)
        #expect(restored.totalPoints == stats.totalPoints)
    }
}
