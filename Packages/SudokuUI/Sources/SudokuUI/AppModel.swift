import Foundation
import Observation
import SudokuGameCenter
import SudokuKit
#if os(iOS)
import UIKit
#endif

/// Everything the app knows: the running game, the totals, and the plumbing
/// between them and storage.
@MainActor
@Observable
public final class AppModel {
    public private(set) var session: GameSession?
    public private(set) var stats = PlayerStats()
    public private(set) var lastResult: ScoreBreakdown?
    public private(set) var isPreparing = false

    public private(set) var isSignedInToGameCenter = false

    private let store: GameStore
    private let factory: PuzzleFactory
    private let gameCenter: any GameCenterService
    private let queue: SubmissionQueue
    private var moveCount = 0
    private var startedOn = AppModel.deviceName
    private var autosaveTask: Task<Void, Never>?

    public init(
        store: GameStore = GameStore(),
        factory: PuzzleFactory = PuzzleFactory(),
        gameCenter: (any GameCenterService)? = nil,
        queue: SubmissionQueue = SubmissionQueue()
    ) {
        self.store = store
        self.factory = factory
        self.queue = queue
        if let gameCenter {
            self.gameCenter = gameCenter
        } else {
            #if canImport(GameKit)
            self.gameCenter = GameKitService()
            #else
            self.gameCenter = UnavailableGameCenterService()
            #endif
        }
    }

    /// Loads the totals and any game that was left running.
    public func load() async {
        stats = await store.loadStats()
        if let saved = await store.loadCurrentGame(),
           let restored = GameSession.restore(from: saved) {
            session = restored
            moveCount = saved.moveCount
        }
        Task.detached(priority: .background) { [factory] in await factory.refill() }
        // Not awaited: signing in can put a screen in front of the player, and
        // the game must be ready whether or not they ever finish with it.
        Task { await connectGameCenter() }
    }

    /// Signs in and sends anything that was earned offline. Never blocks play.
    public func connectGameCenter() async {
        await gameCenter.authenticate()
        isSignedInToGameCenter = await gameCenter.isAuthenticated()
        await queue.flush(using: gameCenter)
    }

    public var canContinue: Bool { session != nil && session?.completedAt == nil }

    public func startGame(difficulty: Difficulty) async {
        isPreparing = true
        defer { isPreparing = false }
        let puzzle = await factory.puzzle(for: difficulty)
        session = GameSession(puzzle: puzzle)
        moveCount = 0
        startedOn = Self.deviceName
        lastResult = nil
        await persist()
        Task.detached(priority: .background) { [factory] in await factory.refill() }
    }

    public func abandonGame() async {
        session = nil
        await store.clearCurrentGame()
    }

    /// Called after every change to the board.
    ///
    /// Returns the task that settles the finished game, so a test can await it
    /// instead of guessing how long reporting takes.
    @discardableResult
    public func didPlay() -> Task<Void, Never>? {
        moveCount += 1
        guard let session else { return nil }
        guard session.completedAt != nil else {
            scheduleAutosave()
            return nil
        }
        return Task { await finish(session) }
    }

    public func tick() {
        guard let session, !session.isPaused, session.completedAt == nil else { return }
        session.tick()
        if session.elapsedSeconds % 5 == 0 { scheduleAutosave() }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.persist()
        }
    }

    private func persist() async {
        guard let session, session.completedAt == nil else { return }
        await store.save(session.saved(deviceName: Self.deviceName, moveCount: moveCount))
    }

    private func finish(_ session: GameSession) async {
        var updated = stats
        let breakdown = updated.record(
            puzzle: session.puzzle, session: session,
            deviceName: Self.deviceName, isDaily: false)
        stats = updated
        lastResult = breakdown
        await store.save(updated)
        await store.clearCurrentGame()
        await reportToGameCenter(session: session, breakdown: breakdown, totals: updated.totals)
    }

    private func reportToGameCenter(
        session: GameSession, breakdown: ScoreBreakdown, totals: PlayerTotals
    ) async {
        let event = SolveEvent(
            difficulty: session.puzzle.difficulty,
            seconds: session.elapsedSeconds,
            mistakes: session.mistakes,
            hintsUsed: session.hintsUsed,
            pointsScored: breakdown.total,
            techniques: session.puzzle.techniques,
            completedAt: session.completedAt ?? .now,
            isDaily: false,
            finishedOn: Self.deviceName,
            startedOn: startedOn)

        // Queued rather than sent directly: the queue is what makes an offline
        // win survive to the next sign-in.
        await queue.send(
            scores: AchievementEvaluator.submissions(for: event, totals: totals),
            achievements: AchievementEvaluator.progress(for: event, totals: totals),
            using: gameCenter)
    }

    public func dismissResult() {
        lastResult = nil
        session = nil
    }

    /// Distinguishes iPhone from iPad, because the "at home everywhere"
    /// achievement asks for both.
    static var deviceName: String {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #elseif os(macOS)
        return "Mac"
        #elseif os(tvOS)
        return "Apple TV"
        #elseif os(watchOS)
        return "Apple Watch"
        #elseif os(visionOS)
        return "Vision Pro"
        #else
        return "Unbekannt"
        #endif
    }
}
