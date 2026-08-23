import Foundation
import Observation
import SudokuGameCenter
import SudokuKit
import SudokuSync
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
    /// Whether the board is on screen. Lives here rather than in the view so the
    /// Mac menu bar can start a game without reaching into a view's state.
    public var isPlaying = false

    public private(set) var isSignedInToGameCenter = false

    /// Set when two devices disagree badly enough that the player has to decide.
    public private(set) var pendingConflict: SyncConflict?

    /// First run only.
    ///
    /// Written to both stores. The synced one means picking up the iPad does not
    /// introduce the app a second time; the local one means the introduction
    /// stays dismissed even when iCloud is switched off, unavailable, or — as in
    /// an unsigned build — silently dropping every write. Being told what the
    /// app does on every single launch is worse than seeing it twice.
    public private(set) var showsOnboarding = false
    static let onboardingKey = "has-seen-onboarding"

    /// A disagreement waiting for an answer. Both versions are kept until then —
    /// picking one for the player is how saved games get lost.
    public struct SyncConflict: Identifiable, Sendable {
        public let id = UUID()
        public let reason: DivergenceReason
        public let local: SavedGame?
        public let remote: SavedGame
    }

    private let store: GameStore
    private let factory: PuzzleFactory
    private let gameCenter: any GameCenterService
    private let queue: SubmissionQueue
    private let sync: GameSyncCoordinator
    private let flags: any KeyValueSyncing
    private let defaults: UserDefaults
    private var remoteWatch: Task<Void, Never>?
    private var moveCount = 0
    private var startedOn = AppModel.deviceName
    private var isDailyGame = false
    /// Set when a widget tap or an intent started this game, as opposed to it
    /// being restored from disk.
    private var startedOnDemand = false
    private var autosaveTask: Task<Void, Never>?

    public init(
        store: GameStore = GameStore(),
        factory: PuzzleFactory = PuzzleFactory(),
        gameCenter: (any GameCenterService)? = nil,
        queue: SubmissionQueue = SubmissionQueue(),
        keyValueStore: (any KeyValueSyncing)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.store = store
        self.factory = factory
        self.queue = queue
        #if canImport(Foundation) && !os(Linux)
        let resolved = keyValueStore ?? UbiquitousKeyValueStore()
        #else
        let resolved = keyValueStore ?? InMemoryKeyValueStore()
        #endif
        self.flags = resolved
        self.sync = GameSyncCoordinator(store: resolved)
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

    /// Loads the totals and any game that was left running — local or from
    /// another device.
    public func load() async {
        stats = await store.loadStats()
        let local = await store.loadCurrentGame()
        await adopt(local: local)
        watchForRemoteChanges()
        Task.detached(priority: .background) { [factory] in await factory.refill() }
        // Not awaited: signing in can put a screen in front of the player, and
        // the game must be ready whether or not they ever finish with it.
        Task { await connectGameCenter() }

        let seen = defaults.bool(forKey: Self.onboardingKey)
            || flags.flag(forKey: Self.onboardingKey)
        showsOnboarding = !seen

        #if DEBUG
        // The UI tests would otherwise spend every launch dismissing a sheet
        // they are not there to test. Debug only, like -open-game.
        if ProcessInfo.processInfo.arguments.contains("-skip-onboarding") {
            showsOnboarding = false
        }
        #endif

        await handlePendingLaunchRequest()

        #if DEBUG
        // Apple TV has no pointer, so its screens cannot be driven the way the
        // iOS ones are. This lets a build be launched straight into a game to be
        // looked at. Debug only — it never ships.
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-open-game"),
           index + 1 < ProcessInfo.processInfo.arguments.count,
           let difficulty = Difficulty(rawValue: ProcessInfo.processInfo.arguments[index + 1]) {
            await startGame(difficulty: difficulty)
        }
        #endif
    }

    /// Applies whatever the resolver decides about the local and remote records.
    private func adopt(local: SavedGame?) async {
        // A widget tap or an intent can start a game while this is still reading
        // from disk. Putting the saved game on top of it left the app showing
        // the overview with a back button and nothing behind it. The comparison
        // against other devices still has to run — only the replacing is
        // skipped, so a genuine conflict is still raised.
        let keepWhatIsPlaying = startedOnDemand
        func put(_ saved: SavedGame?) {
            guard !keepWhatIsPlaying else { return }
            restore(saved)
        }

        switch await sync.resolution(for: local) {
        case .useLocal:
            put(local)
        case .useRemote:
            guard let remote = await sync.remoteGame() else {
                put(local)
                return
            }
            put(remote)
            if !keepWhatIsPlaying {
                await store.save(remote)
            }
        case .ask(let reason):
            guard let remote = await sync.remoteGame() else {
                put(local)
                return
            }
            put(local)
            pendingConflict = SyncConflict(reason: reason, local: local, remote: remote)
        }
    }

    private func restore(_ saved: SavedGame?) {
        guard let saved, let restored = GameSession.restore(from: saved) else {
            session = nil
            return
        }
        session = restored
        moveCount = saved.moveCount
        startedOn = saved.deviceName
    }

    /// The player's answer to a conflict. Nothing was thrown away before this.
    public func resolveConflict(keepRemote: Bool) async {
        guard let conflict = pendingConflict else { return }
        pendingConflict = nil
        if keepRemote {
            restore(conflict.remote)
            await store.save(conflict.remote)
        } else {
            restore(conflict.local)
            await persist()
        }
    }

    private func watchForRemoteChanges() {
        remoteWatch?.cancel()
        remoteWatch = Task { [weak self] in
            guard let stream = await self?.sync.remoteChanges() else { return }
            for await _ in stream {
                guard let self else { return }
                await self.handleRemoteChange()
            }
        }
    }

    private func handleRemoteChange() async {
        // Ignore anything that arrives mid-game with the board already open:
        // swapping the grid under the player's hands is worse than being a
        // little out of date. It is picked up the next time they come back.
        guard pendingConflict == nil else { return }
        let local = session.map { $0.saved(deviceName: Self.deviceName, moveCount: moveCount) }
        await adopt(local: local)
    }

    /// Signs in and sends anything that was earned offline. Never blocks play.
    public func connectGameCenter() async {
        await gameCenter.authenticate()
        isSignedInToGameCenter = await gameCenter.isAuthenticated()
        await queue.flush(using: gameCenter)
    }

    /// Handles a `sudoku://` link — today only the widget's, which opens the
    /// daily puzzle. Returns whether the link meant anything.
    @discardableResult
    public func open(_ url: URL) async -> Bool {
        guard url.scheme == "sudoku" else { return false }
        switch url.host() {
        case "daily":
            await startDailyPuzzle()
            startedOnDemand = true
            return true
        default:
            return false
        }
    }

    /// Acts on whatever a Shortcuts or Siri intent asked for before the app was
    /// running. Call it on launch and whenever the app comes to the front.
    public func handlePendingLaunchRequest() async {
        #if canImport(AppIntents)
        guard let request = PendingLaunchRequest.take() else { return }
        if request == PendingLaunchRequest.Request.daily.rawValue {
            await startDailyPuzzle()
            startedOnDemand = true
        } else if let difficulty = Difficulty(rawValue: request) {
            await startGame(difficulty: difficulty)
            startedOnDemand = true
        }
        #endif
    }

    public func dismissOnboarding() {
        showsOnboarding = false
        defaults.set(true, forKey: Self.onboardingKey)
        flags.setFlag(true, forKey: Self.onboardingKey)
    }

    public var canContinue: Bool { session != nil && session?.completedAt == nil }

    /// Today's puzzle — the same one for every player in the world, because the
    /// seed comes from the UTC date and nothing else.
    public func startDailyPuzzle(difficulty: Difficulty = .medium, on date: Date = .now) async {
        isPreparing = true
        defer { isPreparing = false }
        let puzzle = PuzzleGenerator.daily(for: date, difficulty: difficulty)
        await begin(puzzle: puzzle, isDaily: true)
        isPlaying = true
    }

    public func startGame(difficulty: Difficulty) async {
        isPreparing = true
        defer { isPreparing = false }
        let puzzle = await factory.puzzle(for: difficulty)
        await begin(puzzle: puzzle, isDaily: false)
        isPlaying = true
        Task.detached(priority: .background) { [factory] in await factory.refill() }
    }

    public var hasSolvedTodaysPuzzle: Bool {
        let id = PuzzleGenerator.daily(for: .now).id.description
        return stats.solvedPuzzleIDs.contains(id)
    }

    private func begin(puzzle: Puzzle, isDaily: Bool) async {
        session = GameSession(puzzle: puzzle)
        moveCount = 0
        startedOn = Self.deviceName
        isDailyGame = isDaily
        lastResult = nil
        pendingConflict = nil
        await persist()
    }

    public func abandonGame() async {
        session = nil
        await store.clearCurrentGame()
        await sync.push(nil)
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

    /// Waits for the debounced autosave, so a test does not have to guess.
    public func flushPendingWritesForTesting() async {
        autosaveTask?.cancel()
        autosaveTask = nil
        await persist()
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
        let saved = session.saved(deviceName: Self.deviceName, moveCount: moveCount)
        await store.save(saved)
        await sync.push(saved)
    }

    private func finish(_ session: GameSession) async {
        var updated = stats
        let breakdown = updated.record(
            puzzle: session.puzzle, session: session,
            deviceName: Self.deviceName, isDaily: isDailyGame)
        stats = updated
        lastResult = breakdown
        await store.save(updated)
        await store.clearCurrentGame()
        await sync.push(nil)
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
            isDaily: isDailyGame,
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
        #else
        return "Unbekannt"
        #endif
    }
}
