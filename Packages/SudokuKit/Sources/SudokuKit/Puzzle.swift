/// A generated puzzle together with everything known about its difficulty.
public struct Puzzle: Sendable, Hashable, Codable {
    public let id: PuzzleID
    public let givens: Grid
    public let solution: Grid
    public let difficulty: Difficulty
    /// Raw rating score from ``DifficultyRater``.
    public let rating: Int
    /// Every technique the logical solve needed, cheapest first.
    public let techniques: [Technique]

    public var givenCount: Int { givens.filledCount }
    public var hardestTechnique: Technique? { techniques.last }

    public init(
        id: PuzzleID, givens: Grid, solution: Grid,
        difficulty: Difficulty, rating: Int, techniques: [Technique]
    ) {
        self.id = id
        self.givens = givens
        self.solution = solution
        self.difficulty = difficulty
        self.rating = rating
        self.techniques = techniques
    }
}
