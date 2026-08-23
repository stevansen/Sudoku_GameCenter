import Foundation

/// Why two devices disagree badly enough to involve the player.
public enum DivergenceReason: String, Sendable, Equatable, Codable {
    /// Two different puzzles are in progress.
    case differentPuzzle
    /// The same puzzle, but with different digits in the same cells.
    case contradictingEntries
}

/// What to do with a local and a remote record.
public enum SyncResolution: Sendable, Equatable {
    case useLocal
    case useRemote
    /// Neither can be discarded without possibly throwing away real work.
    case ask(DivergenceReason)
}

/// Decides which of two versions of a game wins.
///
/// The rule behind every branch: **never discard work silently.** A lost saved
/// game is invisible until it hurts and cannot be undone, so where the records
/// genuinely disagree this asks rather than guesses. Everywhere else it stays
/// out of the way — being asked about a conflict that is not one is its own kind
/// of bad.
public enum ConflictResolver {
    /// How far apart two move counts may be before the further one is simply
    /// assumed to be the real one.
    public static let decisiveMoveLead = 3

    public static func resolve(local: SavedGame?, remote: SavedGame?) -> SyncResolution {
        switch (local, remote) {
        case (nil, nil), (.some, nil):
            return .useLocal
        case (nil, .some):
            return .useRemote
        case let (.some(local), .some(remote)):
            return resolve(local: local, remote: remote)
        }
    }

    static func resolve(local: SavedGame, remote: SavedGame) -> SyncResolution {
        if local == remote { return .useLocal }

        guard local.puzzleID == remote.puzzleID else {
            // Two different games are in progress. Whichever is dropped, someone
            // loses a puzzle they were in the middle of.
            return .ask(.differentPuzzle)
        }

        // One is simply further along the same road.
        if local.isContainedIn(remote) && local.filledCells < remote.filledCells { return .useRemote }
        if remote.isContainedIn(local) && remote.filledCells < local.filledCells { return .useLocal }

        if local.contradictions(with: remote).isEmpty {
            // Same digits, different notes or clock. Nothing is at stake, so the
            // more advanced record wins on its own.
            return byProgress(local: local, remote: remote)
        }

        // They really do disagree. A clear lead in moves settles it; a close call
        // does not.
        let lead = local.moveCount - remote.moveCount
        if lead > decisiveMoveLead { return .useLocal }
        if -lead > decisiveMoveLead { return .useRemote }
        return .ask(.contradictingEntries)
    }

    private static func byProgress(local: SavedGame, remote: SavedGame) -> SyncResolution {
        if local.moveCount != remote.moveCount {
            return local.moveCount > remote.moveCount ? .useLocal : .useRemote
        }
        if local.updatedAt != remote.updatedAt {
            return local.updatedAt > remote.updatedAt ? .useLocal : .useRemote
        }
        return .useLocal
    }
}
