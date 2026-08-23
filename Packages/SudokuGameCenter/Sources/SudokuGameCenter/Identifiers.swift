import SudokuKit

/// The leaderboards this app reports to.
///
/// These strings must match what is entered in App Store Connect exactly — the
/// portal is the only place they can be created, and a typo shows up as silently
/// missing scores rather than as an error. `docs/gamecenter-setup.md` is the
/// source of truth for both sides.
public enum LeaderboardID: String, CaseIterable, Sendable {
    case totalPoints = "com.sudoku.leaderboard.total_points"
    case bestTimeEasy = "com.sudoku.leaderboard.best_time_easy"
    case bestTimeMedium = "com.sudoku.leaderboard.best_time_medium"
    case bestTimeHard = "com.sudoku.leaderboard.best_time_hard"
    case bestTimeExpert = "com.sudoku.leaderboard.best_time_expert"
    case bestTimeEvil = "com.sudoku.leaderboard.best_time_evil"
    case daily = "com.sudoku.leaderboard.daily"
    case weeklyPoints = "com.sudoku.leaderboard.weekly_points"
    case streak = "com.sudoku.leaderboard.streak"

    public static func bestTime(for difficulty: Difficulty) -> LeaderboardID {
        switch difficulty {
        case .easy: .bestTimeEasy
        case .medium: .bestTimeMedium
        case .hard: .bestTimeHard
        case .expert: .bestTimeExpert
        case .evil: .bestTimeEvil
        }
    }
}

/// The achievements this app reports progress for.
public enum AchievementID: String, CaseIterable, Sendable {
    case firstSolve = "com.sudoku.achievement.first_solve"
    case solve10 = "com.sudoku.achievement.solve_10"
    case solve50 = "com.sudoku.achievement.solve_50"
    case solve250 = "com.sudoku.achievement.solve_250"
    case solve1000 = "com.sudoku.achievement.solve_1000"
    case easyMaster = "com.sudoku.achievement.easy_master"
    case mediumMaster = "com.sudoku.achievement.medium_master"
    case hardMaster = "com.sudoku.achievement.hard_master"
    case expertMaster = "com.sudoku.achievement.expert_master"
    case evilMaster = "com.sudoku.achievement.evil_master"
    case flawless = "com.sudoku.achievement.flawless"
    case flawlessExpert = "com.sudoku.achievement.flawless_expert"
    case noHints50 = "com.sudoku.achievement.no_hints_50"
    case speedEasy = "com.sudoku.achievement.speed_easy_180"
    case speedHard = "com.sudoku.achievement.speed_hard_600"
    case speedEvil = "com.sudoku.achievement.speed_evil_1800"
    case streak7 = "com.sudoku.achievement.streak_7"
    case streak30 = "com.sudoku.achievement.streak_30"
    case streak365 = "com.sudoku.achievement.streak_365"
    case firstDaily = "com.sudoku.achievement.first_daily"
    case daily10 = "com.sudoku.achievement.daily_10"
    case daily100 = "com.sudoku.achievement.daily_100"
    case nightOwl = "com.sudoku.achievement.night_owl"
    case earlyBird = "com.sudoku.achievement.early_bird"
    case points10k = "com.sudoku.achievement.points_10k"
    case points100k = "com.sudoku.achievement.points_100k"
    case allPlatforms = "com.sudoku.achievement.all_platforms"
    case comeback = "com.sudoku.achievement.comeback"
    case techniqueXWing = "com.sudoku.achievement.technique_xwing"
    case perfectWeek = "com.sudoku.achievement.perfect_week"

    /// Points as configured in App Store Connect.
    ///
    /// Apple caps the sum for an app at 1000 **for its lifetime** — it cannot be
    /// raised later. These add up to 880, leaving room for achievements that do
    /// not exist yet. ``AchievementID/totalPoints`` is asserted in the tests so
    /// an addition cannot quietly break the cap.
    public var points: Int {
        switch self {
        case .firstSolve, .firstDaily, .nightOwl, .earlyBird: 5
        case .solve10, .flawless, .speedEasy, .comeback: 10
        case .easyMaster, .mediumMaster, .daily10: 15
        case .solve50, .hardMaster, .streak7, .allPlatforms: 20
        case .expertMaster, .techniqueXWing: 25
        case .evilMaster, .noHints50, .speedHard: 30
        case .flawlessExpert, .points10k: 35
        case .solve250: 40
        case .streak30, .perfectWeek: 45
        case .daily100: 50
        case .speedEvil: 60
        case .solve1000: 75
        case .points100k: 80
        case .streak365: 90
        }
    }

    public static var totalPoints: Int { allCases.reduce(0) { $0 + $1.points } }

    /// Apple's hard limit on the sum of an app's achievement points.
    public static let pointBudget = 1000

    public static func master(for difficulty: Difficulty) -> AchievementID {
        switch difficulty {
        case .easy: .easyMaster
        case .medium: .mediumMaster
        case .hard: .hardMaster
        case .expert: .expertMaster
        case .evil: .evilMaster
        }
    }
}
