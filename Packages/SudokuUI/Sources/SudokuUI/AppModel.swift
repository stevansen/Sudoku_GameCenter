import Foundation
import Observation
import SudokuKit

/// Everything the app knows: the running game, the totals, and the plumbing
/// between them and storage.
@MainActor
@Observable
public final class AppModel {
    public private(set) var session: GameSession?
    public private(set) var stats = PlayerStats()
    public private(set) var lastResult: ScoreBreakdown?
    public private(set) var isPreparing = false

    private let store: GameStore
    private let factory: PuzzleFactory
    private var moveCount = 0
    private var autosaveTask: Task<Void, Never>?

    public init(store: GameStore = GameStore(), factory: PuzzleFactory = PuzzleFactory()) {
        self.store = store
        self.factory = factory
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
    }

    public var canContinue: Bool { session != nil && session?.completedAt == nil }

    public func startGame(difficulty: Difficulty) async {
        isPreparing = true
        defer { isPreparing = false }
        let puzzle = await factory.puzzle(for: difficulty)
        session = GameSession(puzzle: puzzle)
        moveCount = 0
        lastResult = nil
        await persist()
        Task.detached(priority: .background) { [factory] in await factory.refill() }
    }

    public func abandonGame() async {
        session = nil
        await store.clearCurrentGame()
    }

    /// Called after every change to the board.
    public func didPlay() {
        moveCount += 1
        guard let session else { return }
        if session.completedAt != nil {
            Task { await finish(session) }
        } else {
            scheduleAutosave()
        }
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
        let breakdown = updated.record(puzzle: session.puzzle, session: session)
        stats = updated
        lastResult = breakdown
        await store.save(updated)
        await store.clearCurrentGame()
        // Milestone 3 reports the score and any achievements to Game Center here.
    }

    public func dismissResult() {
        lastResult = nil
        session = nil
    }

    static var deviceName: String {
        #if os(iOS) || os(tvOS) || os(visionOS)
        return "iOS"
        #elseif os(macOS)
        return "Mac"
        #elseif os(watchOS)
        return "Watch"
        #else
        return "Unbekannt"
        #endif
    }
}
