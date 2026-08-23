import Foundation

/// What the app needs from Game Center.
///
/// Everything goes through this protocol so the rest of the app never touches
/// GameKit directly — which matters because GameKit cannot be driven from a test
/// and barely from a simulator.
public protocol GameCenterService: Sendable {
    /// Signs the player in. Must never block the game: if it fails, play carries
    /// on offline and the queue holds anything that could not be sent.
    func authenticate() async
    func isAuthenticated() async -> Bool
    func submit(_ submissions: [ScoreSubmission]) async throws
    func report(_ progress: [AchievementProgress]) async throws
    /// Progress Game Center already knows about, so nothing is reported twice.
    func loadAchievementProgress() async -> [AchievementID: Double]
}

/// Records what it was asked to do. Used by the tests and on any platform or
/// build where signing in is not wanted.
public actor MockGameCenterService: GameCenterService {
    public private(set) var authenticated = false
    public private(set) var submitted: [ScoreSubmission] = []
    public private(set) var reported: [AchievementProgress] = []
    public private(set) var knownProgress: [AchievementID: Double] = [:]
    /// When set, the next call throws — the way to test the retry queue.
    public var failure: (any Error)?

    public init(authenticated: Bool = true, failure: (any Error)? = nil) {
        self.authenticated = authenticated
        self.failure = failure
    }

    public func authenticate() async { authenticated = true }
    public func isAuthenticated() async -> Bool { authenticated }

    public func submit(_ submissions: [ScoreSubmission]) async throws {
        if let failure { throw failure }
        submitted += submissions
    }

    public func report(_ progress: [AchievementProgress]) async throws {
        if let failure { throw failure }
        reported += progress
        for item in progress {
            knownProgress[item.id] = max(knownProgress[item.id] ?? 0, item.percentComplete)
        }
    }

    public func loadAchievementProgress() async -> [AchievementID: Double] { knownProgress }

    public func setFailure(_ error: (any Error)?) { failure = error }
}

/// For builds and platforms where Game Center is not available at all.
/// Everything it is asked to do fails, which is exactly what the queue expects.
public struct UnavailableGameCenterService: GameCenterService {
    public init() {}
    public func authenticate() async {}
    public func isAuthenticated() async -> Bool { false }
    public func submit(_ submissions: [ScoreSubmission]) async throws {
        throw GameCenterError("Game Center is unavailable")
    }
    public func report(_ progress: [AchievementProgress]) async throws {
        throw GameCenterError("Game Center is unavailable")
    }
    public func loadAchievementProgress() async -> [AchievementID: Double] { [:] }
}

public struct GameCenterError: Error, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
}
