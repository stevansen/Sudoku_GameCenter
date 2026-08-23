import Foundation
import Testing
@testable import SudokuGameCenter
import SudokuKit

@Suite("Submission queue")
struct SubmissionQueueTests {
    func makeDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    @Test func whatCannotBeSentIsKeptAndRetried() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = MockGameCenterService(failure: GameCenterError("offline"))
        let queue = SubmissionQueue(directory: directory)

        await queue.send(
            scores: [ScoreSubmission(leaderboard: .totalPoints, value: 100)],
            achievements: [AchievementProgress(id: .firstSolve, percentComplete: 100)],
            using: service)

        #expect(await service.submitted.isEmpty)
        #expect(await queue.pendingScoreCount == 1)

        // Back online: the backlog goes out.
        await service.setFailure(nil)
        await queue.flush(using: service)
        #expect(await service.submitted.count == 1)
        #expect(await service.reported.count == 1)
        #expect(await queue.pendingScoreCount == 0)
    }

    @Test func aBacklogSurvivesRelaunching() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let offline = MockGameCenterService(failure: GameCenterError("offline"))
        let first = SubmissionQueue(directory: directory)
        await first.send(
            scores: [ScoreSubmission(leaderboard: .streak, value: 7)],
            achievements: [], using: offline)

        // A fresh queue over the same directory is what a relaunch looks like.
        let second = SubmissionQueue(directory: directory)
        #expect(await second.pendingScoreCount == 1)

        let service = MockGameCenterService()
        await second.flush(using: service)
        #expect(await service.submitted.first?.value == 7)
    }

    @Test func nothingIsSentWhileSignedOut() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = MockGameCenterService(authenticated: false)
        let queue = SubmissionQueue(directory: directory)
        await queue.send(
            scores: [ScoreSubmission(leaderboard: .totalPoints, value: 10)],
            achievements: [], using: service)
        #expect(await service.submitted.isEmpty)
        #expect(await queue.pendingScoreCount == 1)
    }

    @Test func abacklogIsCompactedToWhatStillMatters() {
        let scores = [
            ScoreSubmission(leaderboard: .totalPoints, value: 100),
            ScoreSubmission(leaderboard: .totalPoints, value: 350),
            ScoreSubmission(leaderboard: .totalPoints, value: 220),
            ScoreSubmission(leaderboard: .bestTimeHard, value: 900),
            ScoreSubmission(leaderboard: .bestTimeHard, value: 620),
        ]
        let best = SubmissionQueue.bestPerLeaderboard(scores)
        #expect(best.count == 2)
        #expect(best.first { $0.leaderboard == .totalPoints }?.value == 350)
        // Times are better when they are smaller.
        #expect(best.first { $0.leaderboard == .bestTimeHard }?.value == 620)

        let progress = SubmissionQueue.furthestPerAchievement([
            AchievementProgress(id: .streak7, percentComplete: 40),
            AchievementProgress(id: .streak7, percentComplete: 90),
            AchievementProgress(id: .flawless, percentComplete: 100),
        ])
        #expect(progress.count == 2)
        #expect(progress.first { $0.id == .streak7 }?.percentComplete == 90)
    }
}
