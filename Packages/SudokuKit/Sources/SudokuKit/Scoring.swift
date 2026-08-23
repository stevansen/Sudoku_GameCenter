import Foundation

public enum GameMode: String, Sendable, Codable, Hashable {
    case normal, daily, practice

    public var factor: Double {
        switch self {
        case .normal: 1.0
        case .daily: 1.5
        case .practice: 0.0
        }
    }
}

/// Everything about a finished solve that affects the score.
public struct SolveRecord: Sendable, Hashable, Codable {
    public var difficulty: Difficulty
    /// Playing time without pauses.
    public var seconds: Int
    public var mistakes: Int
    public var hintsUsed: Int
    /// Whether the player let the app fill in the candidate notes.
    public var usedAutoCandidates: Bool
    /// Consecutive days played, including today.
    public var streakDays: Int
    public var mode: GameMode
    /// A puzzle only pays once; a repeat solve scores zero.
    public var isRepeat: Bool

    public init(
        difficulty: Difficulty, seconds: Int, mistakes: Int = 0, hintsUsed: Int = 0,
        usedAutoCandidates: Bool = false, streakDays: Int = 0,
        mode: GameMode = .normal, isRepeat: Bool = false
    ) {
        self.difficulty = difficulty
        self.seconds = seconds
        self.mistakes = mistakes
        self.hintsUsed = hintsUsed
        self.usedAutoCandidates = usedAutoCandidates
        self.streakDays = streakDays
        self.mode = mode
        self.isRepeat = isRepeat
    }
}

/// The factors behind a score, kept separate so the app can show the player how
/// the number came about.
public struct ScoreBreakdown: Sendable, Hashable, Codable {
    public let base: Int
    public let timeFactor: Double
    public let mistakeFactor: Double
    public let hintFactor: Double
    public let streakBonus: Double
    public let modeFactor: Double
    public let total: Int
}

public enum Scoring {
    public static func breakdown(for record: SolveRecord) -> ScoreBreakdown {
        let base = record.difficulty.basePoints
        let target = Double(record.difficulty.targetSeconds)
        let elapsed = Double(max(1, record.seconds))

        let timeFactor = min(2.0, max(0.5, target / elapsed))
        let mistakeFactor = max(0.4, pow(0.88, Double(record.mistakes)))
        var hintFactor = max(0.3, pow(0.80, Double(record.hintsUsed)))
        if record.usedAutoCandidates { hintFactor = min(hintFactor, 0.8) }
        let streakBonus = min(0.5, 0.05 * Double(max(0, record.streakDays)))
        let modeFactor = record.isRepeat ? 0.0 : record.mode.factor

        let total = Double(base) * timeFactor * mistakeFactor * hintFactor
            * (1 + streakBonus) * modeFactor

        return ScoreBreakdown(
            base: base, timeFactor: timeFactor, mistakeFactor: mistakeFactor,
            hintFactor: hintFactor, streakBonus: streakBonus, modeFactor: modeFactor,
            total: Int(total.rounded()))
    }

    public static func points(for record: SolveRecord) -> Int {
        breakdown(for: record).total
    }
}
