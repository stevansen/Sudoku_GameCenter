import Foundation
import Testing
@testable import SudokuUI
import SudokuGameCenter
import SudokuKit
import SudokuSync

@MainActor
@Suite("App intents")
struct AppIntentTests {
    func makeModel() -> (AppModel, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let model = AppModel(
            store: GameStore(directory: directory),
            factory: PuzzleFactory(seed: 77),
            gameCenter: MockGameCenterService(authenticated: false),
            queue: SubmissionQueue(directory: directory),
            keyValueStore: InMemoryKeyValueStore())
        return (model, directory)
    }

    /// An intent may run while the app is not launched, so it cannot touch the
    /// model. It writes the request down; the app acts on it when it appears.
    @Test func aParkedRequestStartsTheRequestedTier() async {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        PendingLaunchRequest.store(Difficulty.expert.rawValue)
        await model.handlePendingLaunchRequest()

        #expect(model.session?.puzzle.difficulty == .expert)
        #expect(model.isPlaying)
    }

    @Test func aParkedDailyRequestOpensTodaysPuzzle() async {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        PendingLaunchRequest.store(PendingLaunchRequest.Request.daily.rawValue)
        await model.handlePendingLaunchRequest()

        let today = PuzzleGenerator.daily(for: .now)
        #expect(model.session?.puzzle.id == today.id)
    }

    /// Acting on it twice would restart the game every time the app is brought
    /// forward, throwing away whatever the player just did.
    @Test func aRequestIsActedOnOnlyOnce() async {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        PendingLaunchRequest.store(Difficulty.easy.rawValue)
        await model.handlePendingLaunchRequest()
        let first = model.session?.puzzle.id

        await model.handlePendingLaunchRequest()
        #expect(model.session?.puzzle.id == first, "the game must not restart")
    }

    @Test func nothingHappensWithoutARequest() async {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        _ = PendingLaunchRequest.take()
        await model.handlePendingLaunchRequest()
        #expect(model.session == nil)
        #expect(!model.isPlaying)
    }
}
