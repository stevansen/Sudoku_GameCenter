import Foundation
import Testing
@testable import SudokuUI
import SudokuGameCenter
import SudokuKit

@MainActor
@Suite("Game Center wiring")
struct GameCenterIntegrationTests {
    func makeModel(
        service: MockGameCenterService
    ) -> (AppModel, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let model = AppModel(
            store: GameStore(directory: directory),
            factory: PuzzleFactory(seed: 12_345),
            gameCenter: service,
            queue: SubmissionQueue(directory: directory))
        return (model, directory)
    }

    func solve(_ model: AppModel) async {
        guard let session = model.session else { return }
        for cell in 0..<81 where !session.isGiven(cell) {
            session.enter(Int(session.puzzle.solution[cell]), at: cell)
        }
        await model.didPlay()?.value
    }

    @Test func finishingAGameReportsScoresAndAchievements() async {
        let service = MockGameCenterService()
        let (model, directory) = makeModel(service: service)
        defer { try? FileManager.default.removeItem(at: directory) }

        await model.startGame(difficulty: .easy)
        await solve(model)

        let submitted = await service.submitted
        let reported = await service.reported

        #expect(submitted.contains { $0.leaderboard == .totalPoints })
        #expect(submitted.contains { $0.leaderboard == .bestTimeEasy })
        #expect(reported.contains { $0.id == .firstSolve && $0.isComplete })
        // Solved without a single wrong digit, so the flawless achievement fires.
        #expect(reported.contains { $0.id == .flawless && $0.isComplete })
        #expect(model.stats.totalPoints > 0)
    }

    /// The point of the queue: a win earned with no connection is not lost.
    @Test func aWinEarnedOfflineIsSentAfterSigningIn() async {
        let service = MockGameCenterService(authenticated: false)
        let (model, directory) = makeModel(service: service)
        defer { try? FileManager.default.removeItem(at: directory) }

        await model.startGame(difficulty: .easy)
        await solve(model)

        #expect(await service.submitted.isEmpty, "nothing should go out while signed out")
        #expect(model.stats.totalPoints > 0, "the points are still earned locally")

        await model.connectGameCenter()

        #expect(await service.submitted.isEmpty == false)
        #expect(await service.reported.contains { $0.id == .firstSolve })
    }
}
