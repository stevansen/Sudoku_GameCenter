import Foundation
import Testing
@testable import SudokuUI
import SudokuGameCenter
import SudokuKit
import SudokuSync

/// A store that accepts writes and loses them, the way NSUbiquitousKeyValueStore
/// behaves when iCloud is off or the entitlement is missing. It reports success,
/// which is what makes it worth testing against.
final class DroppingKeyValueStore: KeyValueSyncing, @unchecked Sendable {
    func data(forKey key: String) -> Data? { nil }
    func set(_ data: Data?, forKey key: String) {}
    func synchronize() -> Bool { true }
    func externalChanges() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

@MainActor
@Suite("Onboarding")
struct OnboardingTests {
    func makeModel(
        sharing store: any KeyValueSyncing,
        defaults: UserDefaults
    ) -> (AppModel, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let model = AppModel(
            store: GameStore(directory: directory),
            factory: PuzzleFactory(seed: 5),
            gameCenter: MockGameCenterService(authenticated: false),
            queue: SubmissionQueue(directory: directory),
            keyValueStore: store,
            defaults: defaults)
        return (model, directory)
    }

    /// A defaults suite of its own, so one test cannot settle another.
    func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "onboarding-\(UUID().uuidString)")!
    }

    @Test func itAppearsOnTheFirstRun() async {
        let (model, directory) = makeModel(
            sharing: InMemoryKeyValueStore(), defaults: makeDefaults())
        defer { try? FileManager.default.removeItem(at: directory) }

        await model.load()
        #expect(model.showsOnboarding)
    }

    @Test func itDoesNotComeBackAfterBeingDismissed() async {
        let store = InMemoryKeyValueStore()
        let defaults = makeDefaults()
        let (first, directory) = makeModel(sharing: store, defaults: defaults)
        defer { try? FileManager.default.removeItem(at: directory) }

        await first.load()
        first.dismissOnboarding()
        #expect(!first.showsOnboarding)

        let (second, secondDirectory) = makeModel(sharing: store, defaults: defaults)
        defer { try? FileManager.default.removeItem(at: secondDirectory) }
        await second.load()
        #expect(!second.showsOnboarding, "a relaunch must not introduce the app again")
    }

    /// The case the simulator caught and the first version of these tests did
    /// not: with iCloud dropping every write, the flag has nowhere to live but
    /// locally — and the app introduced itself on every single launch.
    @Test func itStaysDismissedWhenICloudLosesTheWrite() async {
        let defaults = makeDefaults()
        let (first, directory) = makeModel(sharing: DroppingKeyValueStore(), defaults: defaults)
        defer { try? FileManager.default.removeItem(at: directory) }

        await first.load()
        first.dismissOnboarding()

        let (second, secondDirectory) = makeModel(
            sharing: DroppingKeyValueStore(), defaults: defaults)
        defer { try? FileManager.default.removeItem(at: secondDirectory) }
        await second.load()
        #expect(!second.showsOnboarding, "without iCloud the local flag has to carry it")
    }

    /// The flag lives in the synced store, so picking up the iPad does not mean
    /// being introduced to the app a second time.
    @Test func dismissingItOnOneDeviceSettlesTheOther() async {
        let shared = InMemoryKeyValueStore()
        let (phone, phoneDirectory) = makeModel(sharing: shared, defaults: makeDefaults())
        defer { try? FileManager.default.removeItem(at: phoneDirectory) }
        await phone.load()
        phone.dismissOnboarding()

        // A different device: its own local defaults, the same iCloud store.
        let (pad, padDirectory) = makeModel(sharing: shared, defaults: makeDefaults())
        defer { try? FileManager.default.removeItem(at: padDirectory) }
        await pad.load()
        #expect(!pad.showsOnboarding)
    }
}
