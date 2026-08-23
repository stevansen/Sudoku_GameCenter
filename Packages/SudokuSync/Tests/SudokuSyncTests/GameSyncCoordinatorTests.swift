import Foundation
import Testing
@testable import SudokuSync
import SudokuKit

@Suite("Sync coordinator")
struct GameSyncCoordinatorTests {
    func game(moves: Int = 1, device: String = "iPhone") -> SavedGame {
        SavedGame(
            puzzleID: "v1-hard-000000000000007b",
            entries: [UInt8](repeating: 0, count: 81),
            notes: [Candidates](repeating: 0, count: 81),
            elapsedSeconds: 30, mistakes: 0, hintsUsed: 0, usedAutoCandidates: false,
            startedAt: .init(timeIntervalSince1970: 1_800_000_000),
            updatedAt: .init(timeIntervalSince1970: 1_800_000_100),
            moveCount: moves, deviceName: device)
    }

    @Test func aPublishedGameComesBackIntact() async {
        let coordinator = GameSyncCoordinator(store: InMemoryKeyValueStore())
        #expect(await coordinator.remoteGame() == nil)
        let saved = game()
        await coordinator.push(saved)
        #expect(await coordinator.remoteGame() == saved)
    }

    @Test func finishingAGameClearsIt() async {
        let coordinator = GameSyncCoordinator(store: InMemoryKeyValueStore())
        await coordinator.push(game())
        await coordinator.push(nil)
        #expect(await coordinator.remoteGame() == nil)
    }

    /// A record written by a future build must be ignored rather than misread.
    @Test func anUnknownSchemaVersionIsIgnored() async {
        let store = InMemoryKeyValueStore()
        let payload = """
        {"version": 99, "game": {"puzzleID": "v1-easy-0000000000000001"}}
        """
        store.set(Data(payload.utf8), forKey: GameSyncCoordinator.currentGameKey)
        let coordinator = GameSyncCoordinator(store: store)
        #expect(await coordinator.remoteGame() == nil)
    }

    @Test func aWriteFromAnotherDeviceIsAnnounced() async throws {
        let store = InMemoryKeyValueStore()
        let coordinator = GameSyncCoordinator(store: store)
        let stream = await coordinator.remoteChanges()

        let received = Task { () -> Bool in
            for await _ in stream { return true }
            return false
        }
        // Give the stream a moment to start listening before the write lands.
        try await Task.sleep(for: .milliseconds(50))
        store.simulateRemoteWrite(Data("{}".utf8), forKey: "anything")

        #expect(await received.value)
    }

    @Test func aRemoteGameIsComparedAgainstTheLocalOne() async {
        let store = InMemoryKeyValueStore()
        let coordinator = GameSyncCoordinator(store: store)
        await coordinator.push(game(moves: 20, device: "iPad"))
        #expect(await coordinator.resolution(for: game(moves: 1)) == .useRemote)
        #expect(await coordinator.resolution(for: game(moves: 30)) == .useLocal)
        #expect(await coordinator.resolution(for: nil) == .useRemote)
    }
}
