import Foundation
import Testing
@testable import SudokuSync
import SudokuKit

@Suite("Conflict resolution")
struct ConflictResolverTests {
    static let base = Date(timeIntervalSince1970: 1_800_000_000)

    func game(
        puzzle: String = "v1-medium-000000000000002a",
        filled: [Int: UInt8] = [:],
        moves: Int = 0,
        updatedAt: Date = base,
        device: String = "iPhone",
        notes: [Int: Candidates] = [:]
    ) -> SavedGame {
        var entries = [UInt8](repeating: 0, count: 81)
        for (cell, value) in filled { entries[cell] = value }
        var noteArray = [Candidates](repeating: 0, count: 81)
        for (cell, value) in notes { noteArray[cell] = value }
        return SavedGame(
            puzzleID: puzzle, entries: entries, notes: noteArray, elapsedSeconds: 60,
            mistakes: 0, hintsUsed: 0, usedAutoCandidates: false, startedAt: Self.base,
            updatedAt: updatedAt, moveCount: moves, deviceName: device)
    }

    @Test func aSingleSideAlwaysWins() {
        #expect(ConflictResolver.resolve(local: nil, remote: nil) == .useLocal)
        #expect(ConflictResolver.resolve(local: game(), remote: nil) == .useLocal)
        #expect(ConflictResolver.resolve(local: nil, remote: game()) == .useRemote)
    }

    @Test func identicalRecordsAreNotAConflict() {
        let record = game(filled: [0: 5], moves: 1)
        #expect(ConflictResolver.resolve(local: record, remote: record) == .useLocal)
    }

    /// The common case: the other device simply got further on the same puzzle.
    /// Nothing is at stake, so nothing should be asked.
    @Test func theFurtherRecordWinsWhenItOnlyAddsToTheOther() {
        let behind = game(filled: [0: 5], moves: 1)
        let ahead = game(filled: [0: 5, 1: 3, 2: 9], moves: 3)
        #expect(ConflictResolver.resolve(local: behind, remote: ahead) == .useRemote)
        #expect(ConflictResolver.resolve(local: ahead, remote: behind) == .useLocal)
    }

    @Test func twoDifferentPuzzlesAlwaysAsk() {
        let local = game(puzzle: "v1-easy-0000000000000001", filled: [0: 5], moves: 10)
        let remote = game(puzzle: "v1-evil-0000000000000002", filled: [3: 7], moves: 1)
        // Even with a big lead: whichever is dropped, a real game disappears.
        #expect(ConflictResolver.resolve(local: local, remote: remote) == .ask(.differentPuzzle))
    }

    @Test func contradictingDigitsAskWhenNeitherSideIsClearlyAhead() {
        let local = game(filled: [0: 5, 1: 3], moves: 4, device: "iPhone")
        let remote = game(filled: [0: 8, 1: 3], moves: 5, device: "iPad")
        #expect(ConflictResolver.resolve(local: local, remote: remote) == .ask(.contradictingEntries))
    }

    @Test func aClearLeadInMovesSettlesAContradiction() {
        let local = game(filled: [0: 5], moves: 20)
        let remote = game(filled: [0: 8], moves: 2)
        #expect(ConflictResolver.resolve(local: local, remote: remote) == .useLocal)
        #expect(ConflictResolver.resolve(local: remote, remote: local) == .useRemote)
    }

    @Test func theLeadHasToBeBiggerThanTheThreshold() {
        let lead = ConflictResolver.decisiveMoveLead
        let local = game(filled: [0: 5], moves: 10)
        let barely = game(filled: [0: 8], moves: 10 - lead)
        #expect(ConflictResolver.resolve(local: local, remote: barely) == .ask(.contradictingEntries))
        let clearly = game(filled: [0: 8], moves: 10 - lead - 1)
        #expect(ConflictResolver.resolve(local: local, remote: clearly) == .useLocal)
    }

    /// Same digits, different pencil marks. Nothing can be lost that matters, so
    /// this must resolve itself rather than interrupt anyone.
    @Test func differingNotesAloneNeverAsk() {
        let local = game(filled: [0: 5], moves: 3, notes: [4: 0b101])
        let remote = game(filled: [0: 5], moves: 7, notes: [4: 0b011])
        #expect(ConflictResolver.resolve(local: local, remote: remote) == .useRemote)
    }

    @Test func aTieOnMovesFallsBackToTheClock() {
        let older = game(filled: [0: 5], moves: 3, updatedAt: Self.base)
        let newer = game(filled: [0: 5], moves: 3, updatedAt: Self.base.addingTimeInterval(60),
                         notes: [1: 0b1])
        #expect(ConflictResolver.resolve(local: older, remote: newer) == .useRemote)
        #expect(ConflictResolver.resolve(local: newer, remote: older) == .useLocal)
    }

    @Test func containmentAndContradictionAreComputedOverTheWholeBoard() {
        let small = game(filled: [0: 5])
        let large = game(filled: [0: 5, 80: 9])
        #expect(small.isContainedIn(large))
        #expect(!large.isContainedIn(small))
        #expect(small.contradictions(with: large).isEmpty)

        let clashing = game(filled: [0: 4, 80: 9])
        #expect(large.contradictions(with: clashing) == [0])
    }
}
