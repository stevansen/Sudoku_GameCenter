#if canImport(AppIntents)
import AppIntents
import Foundation
import SudokuKit

/// The difficulty tiers, as Shortcuts and Siri see them.
public enum DifficultyAppValue: String, AppEnum {
    case easy, medium, hard, expert, evil

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Schwierigkeit")
    }

    public static var caseDisplayRepresentations: [DifficultyAppValue: DisplayRepresentation] {
        [
            .easy: DisplayRepresentation(title: "Leicht"),
            .medium: DisplayRepresentation(title: "Mittel"),
            .hard: DisplayRepresentation(title: "Schwer"),
            .expert: DisplayRepresentation(title: "Experte"),
            .evil: DisplayRepresentation(title: "Teuflisch"),
        ]
    }

    var difficulty: Difficulty { Difficulty(rawValue: rawValue) ?? .medium }
}

/// What an intent asked for, parked until the app is running.
///
/// An intent cannot reach into a live `AppModel` — it may well run while the app
/// is not launched at all. So it writes the request down and the app picks it up
/// when it comes to the front.
public enum PendingLaunchRequest {
    static let key = "pending-launch-request"

    public enum Request: String {
        case daily
    }

    static func store(_ value: String, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: key)
    }

    /// Reads the request and clears it, so it is acted on exactly once.
    static func take(from defaults: UserDefaults = .standard) -> String? {
        guard let value = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return value
    }
}

public struct StartSudokuIntent: AppIntent {
    public static let title: LocalizedStringResource = "Sudoku starten"
    public static let description = IntentDescription("Startet ein neues Sudoku in der gewählten Schwierigkeit.")
    public static let openAppWhenRun = true

    @Parameter(title: "Schwierigkeit")
    public var difficulty: DifficultyAppValue

    public init() {
        self.difficulty = .medium
    }

    public init(difficulty: DifficultyAppValue) {
        self.difficulty = difficulty
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Starte ein \(\.$difficulty)-Sudoku")
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        PendingLaunchRequest.store(difficulty.rawValue)
        return .result()
    }
}

public struct DailyPuzzleIntent: AppIntent {
    public static let title: LocalizedStringResource = "Tagesrätsel öffnen"
    public static let description = IntentDescription("Öffnet das Rätsel des Tages, das für alle Spielerinnen und Spieler gleich ist.")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        PendingLaunchRequest.store(PendingLaunchRequest.Request.daily.rawValue)
        return .result()
    }
}

public struct SudokuShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DailyPuzzleIntent(),
            phrases: [
                "Öffne das Tagesrätsel in \(.applicationName)",
                "Open the daily puzzle in \(.applicationName)",
            ],
            shortTitle: "Tagesrätsel",
            systemImageName: "calendar")
        AppShortcut(
            intent: StartSudokuIntent(),
            phrases: [
                "Starte ein Sudoku in \(.applicationName)",
                "Start a sudoku in \(.applicationName)",
            ],
            shortTitle: "Neues Sudoku",
            systemImageName: "square.grid.3x3")
    }
}
#endif
