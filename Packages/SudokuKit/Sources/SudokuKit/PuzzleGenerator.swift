import Foundation

public struct GeneratorOptions: Sendable {
    public enum Symmetry: Sendable, Hashable {
        case none
        /// Remove cells in point-symmetric pairs — prettier grids, but it costs
        /// difficulty, so the top tier does without.
        case rotational180
    }

    /// `nil` picks per difficulty: symmetric up to expert, free-form for evil.
    public var symmetry: Symmetry?
    /// How many seeds to try before settling for the closest match. Digging a
    /// puzzle that genuinely needs its tier's techniques succeeds in roughly one
    /// attempt in twenty, so this has to be generous.
    public var maxAttempts: Int

    public init(symmetry: Symmetry? = nil, maxAttempts: Int = 96) {
        self.symmetry = symmetry
        self.maxAttempts = maxAttempts
    }

    public static let `default` = GeneratorOptions()

    func symmetry(for difficulty: Difficulty) -> Symmetry {
        symmetry ?? (difficulty == .evil ? .none : .rotational180)
    }
}

/// Builds puzzles from a seed, reproducibly.
public enum PuzzleGenerator {
    /// Builds the puzzle described by `id`.
    ///
    /// Generation is a search — a seed does not produce a fitting puzzle on the
    /// first try — so this walks a deterministic sequence of attempts derived
    /// from the seed. Everything about that walk is a pure function of `id` and
    /// `options`, which is what keeps the same id producing the same grid on
    /// every device. In particular the returned puzzle always carries the *requested*
    /// id: the id is the puzzle's identity, so handing back a different one would
    /// quietly break sync and the shared daily puzzle.
    public static func generate(_ id: PuzzleID, options: GeneratorOptions = .default) -> Puzzle {
        var fallback: Puzzle?

        for attempt in 0..<max(1, options.maxAttempts) {
            let seed = attempt == 0 ? id.seed : mix(id.seed, UInt64(attempt))
            var rng = SplitMix64(seed: seed)

            let solution = solvedGrid(using: &rng)
            let givens = dig(from: solution, difficulty: id.difficulty, options: options, using: &rng)

            // Cheap rejection before the expensive part. Four attempts in five
            // miss the tier, and deciding that with a singles-only solve costs a
            // fraction of a full rating, which has to try every technique at
            // every step. Equivalent to ``meetsTier``: the solver always takes
            // the cheapest step available, so being solvable within a lower
            // ceiling means exactly that nothing above it was ever required.
            if let below = id.difficulty.techniqueTierBelowRequirement,
               LogicalSolver.solve(givens, ceiling: below).solved {
                continue
            }
            guard let rating = DifficultyRater.rate(givens) else { continue }

            if meetsTier(id.difficulty, rating: rating) {
                return Puzzle(
                    id: id, givens: givens, solution: solution, difficulty: id.difficulty,
                    rating: rating.score, techniques: rating.techniques)
            }
            // Not characteristic of the tier yet — keep the first near miss in
            // case every attempt falls short, and report what it actually is.
            if fallback == nil {
                fallback = Puzzle(
                    id: id, givens: givens, solution: solution, difficulty: rating.difficulty,
                    rating: rating.score, techniques: rating.techniques)
            }
        }
        if let fallback { return fallback }

        // Unreachable in practice: digging guarantees a solve within the ceiling,
        // so rating always succeeds. Kept non-recursive so a pathological case
        // cannot loop.
        var rng = SplitMix64(seed: mix(id.seed, 0xFFFF))
        let solution = solvedGrid(using: &rng)
        let givens = dig(from: solution, difficulty: .easy, options: options, using: &rng)
        let rating = DifficultyRater.rate(givens)
        return Puzzle(
            id: id, givens: givens, solution: solution,
            difficulty: rating?.difficulty ?? .easy, rating: rating?.score ?? 0,
            techniques: rating?.techniques ?? [])
    }

    /// Whether a rated puzzle is characteristic of the tier it was built for.
    static func meetsTier(_ difficulty: Difficulty, rating: DifficultyRater.Rating) -> Bool {
        guard let required = difficulty.requiredTechniqueTier else { return true }
        guard let hardest = rating.hardestTechnique else { return false }
        return hardest.minimumDifficulty.rank >= required.rank
    }

    public static func generate(
        difficulty: Difficulty, seed: UInt64, options: GeneratorOptions = .default
    ) -> Puzzle {
        generate(PuzzleID(difficulty: difficulty, seed: seed), options: options)
    }

    /// The puzzle of the day — identical for everyone, derived from the UTC date
    /// alone, so it needs no server.
    public static func daily(
        for date: Date, difficulty: Difficulty = .medium, options: GeneratorOptions = .default
    ) -> Puzzle {
        generate(PuzzleID(difficulty: difficulty, seed: dailySeed(for: date, difficulty: difficulty)),
                 options: options)
    }

    public static func dailySeed(for date: Date, difficulty: Difficulty) -> UInt64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
        return fnv1a64("daily|\(day)|\(difficulty.rawValue)")
    }

    // MARK: - Steps

    /// Randomised backtracking over the full space of valid grids.
    static func solvedGrid(using rng: inout SplitMix64) -> Grid {
        var board = CandidateBoard(Grid())!
        _ = fill(&board, using: &rng)
        return board.grid
    }

    private static func fill(_ board: inout CandidateBoard, using rng: inout SplitMix64) -> Bool {
        guard let cell = board.mostConstrainedCell() else { return true }
        for digit in board.candidates[cell].digits.shuffled(using: &rng) {
            var branch = board
            guard branch.assign(digit, to: cell) else { continue }
            if fill(&branch, using: &rng) {
                board = branch
                return true
            }
        }
        return false
    }

    /// Removes cells for as long as the puzzle stays uniquely solvable and stays
    /// within the tier's technique ceiling.
    ///
    /// The ceiling caps what the puzzle may demand, the floor decides how sparse
    /// it gets, and greedy removal pushes it to whichever of the two binds first.
    static func dig(
        from solution: Grid, difficulty: Difficulty,
        options: GeneratorOptions, using rng: inout SplitMix64
    ) -> Grid {
        var grid = solution
        var remaining = 81
        digPass(&grid, remaining: &remaining, ceiling: difficulty.techniqueCeiling,
                floor: difficulty.minimumGivens, order: (0..<81).shuffled(using: &rng),
                symmetry: options.symmetry(for: difficulty))
        return grid
    }

    /// Removes every cell that can go while keeping the grid uniquely solvable
    /// and solvable within `ceiling`.
    private static func digPass(
        _ grid: inout Grid, remaining: inout Int, ceiling: Technique,
        floor: Int, order: [Int], symmetry: GeneratorOptions.Symmetry
    ) {
        for cell in order {
            let group = symmetry == .rotational180 && cell != 40 ? [cell, 80 - cell] : [cell]
            guard group.allSatisfy({ grid[$0] != 0 }) else { continue }
            guard remaining - group.count >= floor else { continue }

            let removed = group.map { grid[$0] }
            for target in group { grid[target] = 0 }

            if BruteForceSolver.hasUniqueSolution(grid),
               LogicalSolver.solve(grid, ceiling: ceiling).solved {
                remaining -= group.count
            } else {
                for (target, value) in zip(group, removed) { grid[target] = value }
            }
        }
    }

    /// Test hook for calibrating the tier boundaries.
    static func digPassForDiagnostics(
        _ grid: inout Grid, remaining: inout Int, ceiling: Technique,
        floor: Int, order: [Int], symmetry: GeneratorOptions.Symmetry
    ) {
        digPass(&grid, remaining: &remaining, ceiling: ceiling, floor: floor,
                order: order, symmetry: symmetry)
    }

    /// Derives the seed of a retry so that the whole attempt loop stays deterministic.
    static func mix(_ seed: UInt64, _ attempt: UInt64) -> UInt64 {
        var rng = SplitMix64(seed: seed ^ (attempt &* 0x9E37_79B9_7F4A_7C15))
        return rng.next()
    }
}
