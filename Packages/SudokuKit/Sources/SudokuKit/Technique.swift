/// A human solving technique, ordered by how hard it is to spot.
///
/// The `cost` values drive both the difficulty rating and the order in which
/// ``LogicalSolver`` tries techniques — always the cheapest that makes progress,
/// which is what a person does too.
public enum Technique: String, CaseIterable, Codable, Sendable, Hashable, Comparable {
    case nakedSingle
    case hiddenSingle
    case lockedCandidates
    case nakedPair
    case hiddenPair
    case nakedTriple
    case hiddenTriple
    case nakedQuad
    case hiddenQuad
    case xWing
    case swordfish
    case xyWing
    case wWing
    case simpleColouring
    case jellyfish
    case xyzWing
    case forcingChain

    public var cost: Int {
        switch self {
        case .nakedSingle: 1
        case .hiddenSingle: 2
        case .lockedCandidates: 5
        case .nakedPair, .hiddenPair: 8
        case .nakedTriple, .hiddenTriple: 14
        case .nakedQuad, .hiddenQuad: 20
        case .xWing: 28
        case .swordfish: 40
        case .xyWing, .wWing: 44
        case .simpleColouring: 50
        case .jellyfish, .xyzWing: 65
        case .forcingChain: 90
        }
    }

    /// The lowest tier whose puzzles may require this technique.
    public var minimumDifficulty: Difficulty {
        switch self {
        case .nakedSingle, .hiddenSingle: .easy
        case .lockedCandidates, .nakedPair, .hiddenPair: .medium
        case .nakedTriple, .hiddenTriple, .nakedQuad, .hiddenQuad, .xWing: .hard
        case .swordfish, .xyWing, .wWing, .simpleColouring: .expert
        case .jellyfish, .xyzWing, .forcingChain: .evil
        }
    }

    public static func < (lhs: Technique, rhs: Technique) -> Bool {
        (lhs.cost, lhs.rawValue) < (rhs.cost, rhs.rawValue)
    }

    /// All techniques, cheapest first — the solver's search order.
    public static let byCost: [Technique] = allCases.sorted()
}
