import Foundation
import SudokuKit

/// Moves the running game between devices and decides what happens when two
/// versions of it meet.
public actor GameSyncCoordinator {
    /// Bumped if the stored shape ever changes, so an older build's record is
    /// ignored rather than misread.
    static let schemaVersion = 1
    static let currentGameKey = "current-game.v1"

    private struct Envelope: Codable, Sendable {
        var version: Int
        var game: SavedGame
    }

    private let store: any KeyValueSyncing
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(store: any KeyValueSyncing) {
        self.store = store
    }

    /// Publishes the local game to the other devices.
    public func push(_ game: SavedGame?) {
        guard let game else {
            store.set(nil, forKey: Self.currentGameKey)
            return
        }
        guard let data = try? encoder.encode(Envelope(version: Self.schemaVersion, game: game))
        else { return }
        store.set(data, forKey: Self.currentGameKey)
    }

    /// The game another device last published, if any.
    public func remoteGame() -> SavedGame? {
        guard let data = store.data(forKey: Self.currentGameKey),
              let envelope = try? decoder.decode(Envelope.self, from: data),
              envelope.version == Self.schemaVersion
        else { return nil }
        return envelope.game
    }

    /// What should happen to the local game given what is out there.
    public func resolution(for local: SavedGame?) -> SyncResolution {
        ConflictResolver.resolve(local: local, remote: remoteGame())
    }

    /// Fires whenever another device publishes something.
    public func remoteChanges() -> AsyncStream<Void> {
        store.externalChanges()
    }
}
