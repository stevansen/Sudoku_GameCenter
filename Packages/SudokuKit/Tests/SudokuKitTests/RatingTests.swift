import Testing
@testable import SudokuKit

@Suite("Difficulty rating")
struct RatingTests {
    @Test func ratesTheReferencePuzzleAsMedium() throws {
        let grid = try #require(Grid(Fixtures.easyPuzzle))
        let rating = try #require(DifficultyRater.rate(grid))
        // Naked singles alone crack it — full peer propagation turns every hidden
        // single in this grid into a naked one — but at 30 givens the solve is
        // long enough to land in the medium band rather than the easy one.
        #expect(rating.hardestTechnique == .nakedSingle)
        #expect(rating.stepCount == 51)
        #expect(rating.score == 54)
        #expect(rating.difficulty == .medium)
    }

    /// A tier has to deliver what its name promises: the top three tiers must
    /// genuinely *require* techniques of their own class, and every tier must
    /// come back labelled as what was asked for.
    @Test(arguments: Difficulty.allCases)
    func generatedPuzzlesAreCharacteristicOfTheirTier(difficulty: Difficulty) {
        for seed in UInt64(1)...10 {
            let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: seed &* 1_000_003)
            #expect(puzzle.difficulty == difficulty)
            guard let required = difficulty.requiredTechniqueTier else { continue }
            let hardest = puzzle.hardestTechnique
            #expect(hardest?.minimumDifficulty.rank ?? -1 >= required.rank,
                    "\(puzzle.id) only needed \(hardest.map(\.rawValue) ?? "nothing")")
        }
    }

    /// Sparser grids mean longer chains of deduction, and the score has to see it.
    @Test func theLadderRisesAcrossTiers() {
        let medians = Difficulty.allCases.map { difficulty in
            let scores = (UInt64(1)...9).map {
                PuzzleGenerator.generate(difficulty: difficulty, seed: $0 &* 7_919).rating
            }
            return scores.sorted()[4]
        }
        #expect(medians == medians.sorted(), "tier medians are not monotone: \(medians)")
    }

    @Test func harderTiersNeedHarderTechniques() {
        let easy = PuzzleGenerator.generate(difficulty: .easy, seed: 5)
        let expert = PuzzleGenerator.generate(difficulty: .expert, seed: 5)
        #expect(easy.rating < expert.rating)
        #expect((easy.hardestTechnique?.cost ?? 0) <= (expert.hardestTechnique?.cost ?? 0))
    }

    @Test func aTierNeverExceedsItsTechniqueCeiling() {
        for difficulty in Difficulty.allCases {
            for seed in UInt64(1)...5 {
                let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: seed &* 31)
                let ceiling = difficulty.techniqueCeiling.cost
                #expect(puzzle.techniques.allSatisfy { $0.cost <= ceiling },
                        "\(puzzle.id) needed \(puzzle.hardestTechnique!)")
            }
        }
    }
}
