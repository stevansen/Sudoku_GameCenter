/// The five difficulty tiers, defined by the techniques a puzzle demands
/// rather than by how many digits it gives away.
public enum Difficulty: String, CaseIterable, Codable, Sendable, Hashable {
    case easy, medium, hard, expert, evil

    /// Roughly what one puzzle of this tier costs to generate, in milliseconds —
    /// median of five on an Apple silicon Mac, **built for release**.
    ///
    /// Not a schedule, a running order: it decides what the factory warms up
    /// first. Worth keeping because the cost is not what the ordering of the
    /// tiers suggests — evil is dearest, hard is dearer than expert, because hard
    /// must need more than singles while staying under a chain, a narrower target
    /// than either neighbour.
    ///
    /// Unoptimised these are roughly thirty times larger (hard 375 ms, evil
    /// 561 ms). Every performance measurement in `docs/decisions.md` up to this
    /// point was taken in a debug build and is that much too pessimistic; the
    /// ordering held, the absolute figures did not.
    public var generationCost: Int {
        switch self {
        case .easy: 1
        case .medium: 1
        case .expert: 7
        case .hard: 12
        case .evil: 23
        }
    }

    /// Where digging stops for this tier.
    ///
    /// This *is* a difficulty knob, and measurement is why. Technique
    /// requirements separate the top tiers cleanly, but between the lower ones
    /// they do not: at 30 givens singles solve every grid, and even at the
    /// uniqueness limit they solve four out of five. So the lower tiers are
    /// graded by how much work the solve is — how sparse the grid is — and the
    /// upper tiers by what the solve demands. See `docs/decisions.md`.
    ///
    /// Below roughly 26 the floor stops binding anyway: uniqueness gives out first.
    public var minimumGivens: Int {
        switch self {
        case .easy: 36
        case .medium: 30
        case .hard: 24
        case .expert: 22
        case .evil: 20
        }
    }

    /// The tier whose techniques a puzzle must *require* to earn this label,
    /// or `nil` where the technique ceiling and the given count already define it.
    var requiredTechniqueTier: Difficulty? {
        switch self {
        case .easy, .medium: nil
        case .hard: .medium      // must need at least locked candidates or a pair
        case .expert: .expert    // must need a wing, a swordfish or colouring
        case .evil: .evil        // must need a forcing chain, a jellyfish or an XYZ-wing
        }
    }

    /// The hardest technique a puzzle of this tier may require.
    public var techniqueCeiling: Technique {
        switch self {
        case .easy: .hiddenSingle
        case .medium: .nakedPair
        case .hard: .xWing
        case .expert: .simpleColouring
        case .evil: .forcingChain
        }
    }

    /// Target solving time, used by ``Scoring``.
    public var targetSeconds: Int {
        switch self {
        case .easy: 6 * 60
        case .medium: 12 * 60
        case .hard: 20 * 60
        case .expert: 32 * 60
        case .evil: 50 * 60
        }
    }

    /// Base points awarded for solving a puzzle of this tier.
    public var basePoints: Int {
        switch self {
        case .easy: 100
        case .medium: 250
        case .hard: 500
        case .expert: 900
        case .evil: 1500
        }
    }

    /// The ceiling a puzzle of this tier must *not* be solvable within, or `nil`
    /// where the tier makes no technique demand.
    var techniqueTierBelowRequirement: Technique? {
        guard let required = requiredTechniqueTier, required.rank > 0 else { return nil }
        return Difficulty.allCases[required.rank - 1].techniqueCeiling
    }

    /// Position in the ordering, for comparing tiers.
    var rank: Int { Difficulty.allCases.firstIndex(of: self)! }

    /// Score band, calibrated against the generator's measured output rather than
    /// chosen up front. Used to classify a grid that did not come from the
    /// generator — an imported puzzle, say. The bands touch but do not overlap;
    /// the tiers themselves do overlap slightly at the edges, so a score near a
    /// boundary is a judgement call, not a fact.
    public var scoreRange: ClosedRange<Int> {
        switch self {
        case .easy: 0...52
        case .medium: 53...72
        case .hard: 73...220
        case .expert: 221...440
        case .evil: 441...1_000_000
        }
    }

    /// The tier a rating score falls into.
    public static func forScore(_ score: Int) -> Difficulty {
        allCases.first { $0.scoreRange.contains(score) } ?? .evil
    }
}
