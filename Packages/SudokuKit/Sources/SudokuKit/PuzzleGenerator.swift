import Foundation

public struct GeneratorOptions: Sendable {
    public enum Symmetry: Sendable, Hashable {
        case none
        /// Remove cells in point-symmetric pairs — prettier grids, but it costs
        /// difficulty, so the top tier does without.
        case rotational180
    }

    /// `nil` picks per difficulty and generator version.
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

    /// Point symmetry makes a prettier grid and stops the digging about four
    /// givens short of where it would otherwise stop — and at that density the
    /// puzzle can be solved with singles alone. For the tiers that must *require*
    /// a technique that is fatal: measured over twelve attempts, hard produced
    /// nothing usable while symmetric and five in twelve without, at the same
    /// cost per dig. So from version 2 the symmetry is kept only where no
    /// technique is required of the puzzle — easy and medium.
    ///
    /// Version 1 keeps its old rule so that ids already stored still regenerate
    /// the grid they were saved with.
    func symmetry(for difficulty: Difficulty, version: Int) -> Symmetry {
        if let symmetry { return symmetry }
        if version <= 1 {
            return difficulty == .evil ? .none : .rotational180
        }
        return difficulty.requiredTechniqueTier == nil ? .rotational180 : .none
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
        let total = max(1, options.maxAttempts)

        // The attempts are independent — each is a pure function of the id and
        // its index — so they are evaluated a batch at a time across the cores
        // instead of one after another. Hard needs about sixteen attempts before
        // one is characteristic of its tier, and waiting for those in sequence is
        // where the seconds went.
        //
        // The result does not change. Batches are taken in order and the lowest
        // index that succeeds is returned, which is the same attempt the
        // sequential loop would have stopped at. That matters more than the
        // speed: the id *is* the puzzle, and a stored id must keep naming the
        // grid it named before.
        // The first attempt is taken alone. Easy and medium succeed on it almost
        // every time, and running a batch of eight to find that out costs them
        // eight times the work for nothing — measured, it tripled them. Only once
        // the first attempt has failed is it worth spreading out.
        var start = 0
        while start < total {
            let width = start == 0 ? 1 : batchSize
            let count = min(width, total - start)
            let outcomes = evaluate(attempts: start..<(start + count), of: id, options: options)

            for offset in 0..<count {
                switch outcomes[offset] {
                case .met(let puzzle):
                    return puzzle
                case .missed(let puzzle):
                    if fallback == nil { fallback = puzzle }
                case .rejected:
                    continue
                }
            }
            start += count
        }
        if let fallback { return fallback }

        // Unreachable in practice: digging guarantees a solve within the ceiling,
        // so rating always succeeds. Kept non-recursive so a pathological case
        // cannot loop.
        var rng = SplitMix64(seed: mix(id.seed, 0xFFFF))
        let solution = solvedGrid(using: &rng)
        let givens = dig(from: solution, difficulty: .easy, options: options,
                         version: id.version, using: &rng)
        let rating = DifficultyRater.rate(givens)
        return Puzzle(
            id: id, givens: givens, solution: solution,
            difficulty: rating?.difficulty ?? .easy, rating: rating?.score ?? 0,
            techniques: rating?.techniques ?? [])
    }

    /// How one attempt turned out.
    enum Outcome {
        /// Characteristic of the tier it was built for.
        case met(Puzzle)
        /// A real puzzle, but of some other tier. Kept in case nothing fits.
        case missed(Puzzle)
        /// Not worth rating, or not ratable.
        case rejected
    }

    /// How many attempts to run at once. One per core, but never so many that a
    /// tier needing a single attempt pays for a crowd of them.
    static var batchSize: Int {
        max(1, min(8, ProcessInfo.processInfo.activeProcessorCount))
    }

    /// Runs a batch of attempts concurrently and returns them in index order.
    static func evaluate(
        attempts: Range<Int>, of id: PuzzleID, options: GeneratorOptions
    ) -> [Outcome] {
        let count = attempts.count
        if count == 1 {
            return [attempt(attempts.lowerBound, of: id, options: options)]
        }

        let results = Results(count: count)
        DispatchQueue.concurrentPerform(iterations: count) { offset in
            let outcome = attempt(attempts.lowerBound + offset, of: id, options: options)
            results.set(outcome, at: offset)
        }
        return results.ordered()
    }

    /// Somewhere for concurrent attempts to put their results. Each writes its
    /// own slot; the lock is only there to satisfy the compiler that they do.
    private final class Results: @unchecked Sendable {
        private let lock = NSLock()
        private var slots: [Outcome?]

        init(count: Int) { slots = Array(repeating: nil, count: count) }

        func set(_ outcome: Outcome, at index: Int) {
            lock.lock(); defer { lock.unlock() }
            slots[index] = outcome
        }

        func ordered() -> [Outcome] {
            lock.lock(); defer { lock.unlock() }
            return slots.map { $0 ?? .rejected }
        }
    }

    /// One attempt: build a grid, dig it, and decide what it turned out to be.
    static func attempt(
        _ index: Int, of id: PuzzleID, options: GeneratorOptions
    ) -> Outcome {
        let seed = index == 0 ? id.seed : mix(id.seed, UInt64(index))
        var rng = SplitMix64(seed: seed)

        let solution = solvedGrid(using: &rng)
        let givens = dig(from: solution, difficulty: id.difficulty, options: options,
                         version: id.version, using: &rng)

        // Cheap rejection before the expensive part. Four attempts in five miss
        // the tier, and deciding that with a singles-only solve costs a fraction
        // of a full rating, which has to try every technique at every step.
        // Equivalent to ``meetsTier``: the solver always takes the cheapest step
        // available, so being solvable within a lower ceiling means exactly that
        // nothing above it was ever required.
        if let below = id.difficulty.techniqueTierBelowRequirement,
           LogicalSolver.solve(givens, ceiling: below).solved {
            return .rejected
        }
        guard let rating = DifficultyRater.rate(givens) else { return .rejected }

        if meetsTier(id.difficulty, rating: rating) {
            return .met(Puzzle(
                id: id, givens: givens, solution: solution, difficulty: id.difficulty,
                rating: rating.score, techniques: rating.techniques))
        }
        return .missed(Puzzle(
            id: id, givens: givens, solution: solution, difficulty: rating.difficulty,
            rating: rating.score, techniques: rating.techniques))
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
        options: GeneratorOptions, version: Int = PuzzleID.currentVersion,
        using rng: inout SplitMix64
    ) -> Grid {
        var grid = solution
        var remaining = 81
        digPass(&grid, remaining: &remaining, ceiling: difficulty.techniqueCeiling,
                floor: difficulty.minimumGivens, order: (0..<81).shuffled(using: &rng),
                symmetry: options.symmetry(for: difficulty, version: version))
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
