import Foundation

/// A small, fast, cross-device key-value store.
///
/// Behind this sits `NSUbiquitousKeyValueStore`, which propagates in seconds
/// where CloudKit takes its time. That difference is the whole point: it covers
/// "put the iPhone down, carry on at the Mac", which is the moment the feature
/// actually has to work.
public protocol KeyValueSyncing: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    @discardableResult
    func synchronize() -> Bool
    /// Fires when another device changed something.
    func externalChanges() -> AsyncStream<Void>
}

extension KeyValueSyncing {
    /// A simple on/off flag. Stored as data like everything else so that no
    /// conformance has to know about it.
    public func flag(forKey key: String) -> Bool {
        data(forKey: key).map { $0.first == 1 } ?? false
    }

    public func setFlag(_ value: Bool, forKey key: String) {
        set(Data([value ? 1 : 0]), forKey: key)
        _ = synchronize()
    }
}

#if canImport(Foundation) && !os(Linux)
/// The real store. Needs the `com.apple.developer.ubiquity-kvstore-identifier`
/// entitlement; without it every write is silently local-only.
public final class UbiquitousKeyValueStore: KeyValueSyncing, @unchecked Sendable {
    private let store: NSUbiquitousKeyValueStore

    public init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
        store.synchronize()
    }

    public func data(forKey key: String) -> Data? { store.data(forKey: key) }

    public func set(_ data: Data?, forKey key: String) {
        if let data {
            store.set(data, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
        store.synchronize()
    }

    @discardableResult
    public func synchronize() -> Bool { store.synchronize() }

    public func externalChanges() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                let notifications = NotificationCenter.default.notifications(
                    named: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
                for await _ in notifications { continuation.yield(()) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
#endif

/// For tests, and for anywhere iCloud is switched off.
public final class InMemoryKeyValueStore: KeyValueSyncing, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    public init() {}

    public func data(forKey key: String) -> Data? {
        lock.withLock { storage[key] }
    }

    public func set(_ data: Data?, forKey key: String) {
        lock.withLock { storage[key] = data }
    }

    @discardableResult
    public func synchronize() -> Bool { true }

    public func externalChanges() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock { continuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) }
            }
        }
    }

    /// Pretends another device wrote something.
    public func simulateRemoteWrite(_ data: Data?, forKey key: String) {
        set(data, forKey: key)
        let observers = lock.withLock { Array(continuations.values) }
        for observer in observers { observer.yield(()) }
    }
}
