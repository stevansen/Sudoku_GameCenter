import Foundation
import Testing
@testable import SudokuUI
import SudokuGameCenter
import SudokuKit
import SudokuSync

@MainActor
@Suite("Cross-device sync")
struct SyncIntegrationTests {
    /// One shared key-value store stands in for iCloud; separate local stores
    /// stand in for two devices.
    func makeDevice(
        sharing cloud: InMemoryKeyValueStore, seed: UInt64
    ) -> (AppModel, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let model = AppModel(
            store: GameStore(directory: directory),
            factory: PuzzleFactory(seed: seed),
            gameCenter: MockGameCenterService(authenticated: false),
            queue: SubmissionQueue(directory: directory),
            keyValueStore: cloud)
        return (model, directory)
    }

    @Test func aGameStartedOnOneDeviceContinuesOnAnother() async {
        let cloud = InMemoryKeyValueStore()
        let (phone, phoneDirectory) = makeDevice(sharing: cloud, seed: 1)
        let (mac, macDirectory) = makeDevice(sharing: cloud, seed: 2)
        defer {
            try? FileManager.default.removeItem(at: phoneDirectory)
            try? FileManager.default.removeItem(at: macDirectory)
        }

        await phone.startGame(difficulty: .easy)
        let session = phone.session!
        let puzzleID = session.puzzle.id
        let cell = (0..<81).first { session.entries[$0] == 0 }!
        session.enter(Int(session.puzzle.solution[cell]), at: cell)
        _ = phone.didPlay()
        await phone.flushPendingWritesForTesting()

        // The Mac knows nothing locally — everything it needs came over as an id.
        await mac.load()
        #expect(mac.session?.puzzle.id == puzzleID)
        #expect(mac.session?.entries[cell] == session.entries[cell])
        #expect(mac.pendingConflict == nil, "a straightforward handover must not ask anything")
    }

    @Test func twoDivergingGamesAskInsteadOfPickingOne() async {
        let cloud = InMemoryKeyValueStore()
        let (phone, phoneDirectory) = makeDevice(sharing: cloud, seed: 1)
        let (mac, macDirectory) = makeDevice(sharing: cloud, seed: 99)
        defer {
            try? FileManager.default.removeItem(at: phoneDirectory)
            try? FileManager.default.removeItem(at: macDirectory)
        }

        // Both devices start their own game, offline from each other's point of view.
        await mac.startGame(difficulty: .hard)
        let macPuzzle = mac.session!.puzzle.id
        await mac.flushPendingWritesForTesting()

        await phone.startGame(difficulty: .easy)
        let phonePuzzle = phone.session!.puzzle.id
        await phone.flushPendingWritesForTesting()

        // The Mac comes back and finds a different puzzle waiting.
        await mac.load()
        let conflict = mac.pendingConflict
        #expect(conflict != nil)
        #expect(conflict?.reason == .differentPuzzle)
        // Nothing has been thrown away yet.
        #expect(mac.session?.puzzle.id == macPuzzle)

        await mac.resolveConflict(keepRemote: true)
        #expect(mac.session?.puzzle.id == phonePuzzle)
        #expect(mac.pendingConflict == nil)
    }

    @Test func keepingTheLocalSideRepublishesIt() async {
        let cloud = InMemoryKeyValueStore()
        let (phone, phoneDirectory) = makeDevice(sharing: cloud, seed: 1)
        let (mac, macDirectory) = makeDevice(sharing: cloud, seed: 99)
        defer {
            try? FileManager.default.removeItem(at: phoneDirectory)
            try? FileManager.default.removeItem(at: macDirectory)
        }

        // Order matters: whoever publishes last is what the other one finds.
        await mac.startGame(difficulty: .hard)
        let macPuzzle = mac.session!.puzzle.id
        await mac.flushPendingWritesForTesting()

        await phone.startGame(difficulty: .easy)
        await phone.flushPendingWritesForTesting()

        await mac.load()
        #expect(mac.pendingConflict != nil)
        await mac.resolveConflict(keepRemote: false)
        #expect(mac.session?.puzzle.id == macPuzzle)

        // The choice has to reach the other devices, or the next launch asks again.
        let coordinator = GameSyncCoordinator(store: cloud)
        #expect(await coordinator.remoteGame()?.puzzleID == macPuzzle.description)
    }

    @Test func theDailyPuzzleIsTheSameForEveryone() async {
        let cloud = InMemoryKeyValueStore()
        let (phone, phoneDirectory) = makeDevice(sharing: cloud, seed: 1)
        let (mac, macDirectory) = makeDevice(sharing: InMemoryKeyValueStore(), seed: 99)
        defer {
            try? FileManager.default.removeItem(at: phoneDirectory)
            try? FileManager.default.removeItem(at: macDirectory)
        }

        let day = Date(timeIntervalSince1970: 1_800_000_000)
        await phone.startDailyPuzzle(on: day)
        await mac.startDailyPuzzle(on: day)
        #expect(phone.session?.puzzle.id == mac.session?.puzzle.id)
        #expect(phone.session?.puzzle.givens == mac.session?.puzzle.givens)
    }
}
