import Foundation
import Testing
@testable import SudokuKit

/// Generation used to be dominated by attempts that were thrown away.
///
/// Digging in point-symmetric pairs stops about four givens short of where free
/// digging stops, and at that density the puzzle can be solved with singles
/// alone — which is exactly what the tiers requiring a technique reject. Hard
/// took sixteen attempts and nearly four seconds. Measured over twelve digs it
/// produced *nothing* usable while symmetric and five in twelve without.
///
/// Timings are machine-dependent, so the bounds here are generous. They exist to
/// catch a return of that shape, not to police milliseconds.
@Suite("Generation cost", .serialized)
struct GeneratorCostTests {
    @Test(arguments: [
        (Difficulty.easy, 1.0), (.medium, 1.0), (.hard, 1.5), (.expert, 4.0), (.evil, 4.0),
    ])
    func aTierIsProducedWithoutAPileOfWastedAttempts(difficulty: Difficulty, budget: Double) {
        let start = Date()
        let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: 20260823)
        let elapsed = Date().timeIntervalSince(start)

        #expect(puzzle.difficulty == difficulty)
        #expect(elapsed < budget,
                "\(difficulty.rawValue) brauchte \(elapsed)s, Budget \(budget)s")
    }

    /// The measurement behind the change, kept as a test so the reasoning does
    /// not rot: for a tier that must require a technique, symmetric digging
    /// leaves the grid too dense to qualify.
    @Test func symmetricDiggingLeavesHardPuzzlesTooDense() {
        var symmetricGivens = 0
        var freeGivens = 0
        let rounds = 6

        for attempt in 0..<rounds {
            for (symmetry, isFree) in [(GeneratorOptions.Symmetry.rotational180, false),
                                       (.none, true)] {
                var rng = SplitMix64(seed: PuzzleGenerator.mix(4242, UInt64(attempt)))
                let solution = PuzzleGenerator.solvedGrid(using: &rng)
                var grid = solution
                var remaining = 81
                PuzzleGenerator.digPassForDiagnostics(
                    &grid, remaining: &remaining, ceiling: Difficulty.hard.techniqueCeiling,
                    floor: Difficulty.hard.minimumGivens,
                    order: (0..<81).shuffled(using: &rng), symmetry: symmetry)
                if isFree { freeGivens += remaining } else { symmetricGivens += remaining }
            }
        }

        let symmetric = Double(symmetricGivens) / Double(rounds)
        let free = Double(freeGivens) / Double(rounds)
        #expect(symmetric > free + 2,
                "symmetrisch \(symmetric), frei \(free) — der Unterschied ist der ganze Grund")
    }

    /// Version 2 digs freely exactly where a technique is required, and keeps the
    /// symmetry where none is.
    @Test func symmetryIsKeptOnlyWhereNoTechniqueIsRequired() {
        let options = GeneratorOptions.default
        for difficulty in Difficulty.allCases {
            let expected: GeneratorOptions.Symmetry =
                difficulty.requiredTechniqueTier == nil ? .rotational180 : .none
            #expect(options.symmetry(for: difficulty, version: 2) == expected)
        }
        // Version 1 kept its own rule, and has to go on keeping it.
        #expect(options.symmetry(for: .hard, version: 1) == .rotational180)
        #expect(options.symmetry(for: .evil, version: 1) == .none)
    }
}
