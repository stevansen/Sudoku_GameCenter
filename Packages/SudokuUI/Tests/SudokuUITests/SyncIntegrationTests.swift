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

    /// Two devices, each finishing something the other never saw. Both totals
    /// have to end up holding both games — not the newer one's.
    @Test func totalsFromTwoDevicesMeetInTheMiddle() async {
        let cloud = InMemoryKeyValueStore()
        let (phone, phoneDirectory) = makeDevice(sharing: cloud, seed: 11)
        let (mac, macDirectory) = makeDevice(sharing: cloud, seed: 22)
        defer {
            try? FileManager.default.removeItem(at: phoneDirectory)
            try? FileManager.default.removeItem(at: macDirectory)
        }

        await phone.load()
        await mac.load()

        await finishAGame(on: phone, difficulty: .easy)
        let phonePoints = phone.stats.totalPoints
        #expect(phonePoints > 0)

        await finishAGame(on: mac, difficulty: .medium)
        // The Mac merged the phone's totals in on the way, so it already holds both.
        #expect(mac.stats.totalPoints > phonePoints)
        #expect(mac.stats.solvedPuzzleIDs.count == 2)

        // And the phone catches up the next time it looks.
        await phone.load()
        #expect(phone.stats.totalPoints == mac.stats.totalPoints)
        #expect(phone.stats.solvedPuzzleIDs == mac.stats.solvedPuzzleIDs)
    }

    /// Nothing is counted twice, however many times the two meet.
    @Test func repeatedSyncsDoNotInflateTheTotals() async {
        let cloud = InMemoryKeyValueStore()
        let (phone, phoneDirectory) = makeDevice(sharing: cloud, seed: 33)
        let (mac, macDirectory) = makeDevice(sharing: cloud, seed: 44)
        defer {
            try? FileManager.default.removeItem(at: phoneDirectory)
            try? FileManager.default.removeItem(at: macDirectory)
        }

        await phone.load()
        await finishAGame(on: phone, difficulty: .easy)
        let settled = phone.stats.totalPoints

        for _ in 0..<4 {
            await mac.load()
            await phone.load()
        }
        #expect(phone.stats.totalPoints == settled)
        #expect(mac.stats.totalPoints == settled)
        #expect(phone.stats.solvedPuzzleIDs.count == 1)
    }

    private func finishAGame(on model: AppModel, difficulty: Difficulty) async {
        await model.startGame(difficulty: difficulty)
        guard let session = model.session else { return }
        for cell in 0..<81 where session.entries[cell] == 0 {
            session.enter(Int(session.puzzle.solution[cell]), at: cell)
        }
        // didPlay hands back the task that folds the game into the totals; the
        // stats are not there until it has run.
        await model.didPlay()?.value
        await model.flushPendingWritesForTesting()
    }
}
