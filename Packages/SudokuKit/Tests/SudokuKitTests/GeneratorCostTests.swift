import Foundation
import Testing
@testable import SudokuKit

/// Generation is dominated by attempts that get thrown away.
///
/// Digging in point-symmetric pairs stops about four givens short of where free
/// digging stops, and at that density the puzzle can be solved with singles
/// alone — which is exactly what the tiers requiring a technique reject. So hard
/// needs around sixteen attempts before one is characteristic of its tier.
///
/// That cost is the price of the symmetry, and the symmetry is wanted: it was
/// dropped once, for speed, and put back. What pays for it is running the
/// attempts across cores rather than one after another. These tests watch the
/// count, which is what the cost is made of.
@Suite("Generation cost", .serialized)
struct GeneratorCostTests {
    /// Counted, not timed.
    ///
    /// A wall-clock budget cannot be asserted here: the suites run alongside each
    /// other, and generation now spreads its attempts across the same cores the
    /// rest of the tests are using. Under that load a tier that takes 0.6 s alone
    /// takes eight. The attempt count is what the cost is actually made of, and
    /// it does not move with the machine.
    @Test(arguments: [
        (Difficulty.easy, 2), (.medium, 4), (.hard, 40), (.expert, 40), (.evil, 40),
    ])
    func aTierIsFoundWithinSoManyAttempts(difficulty: Difficulty, budget: Int) {
        let id = PuzzleID(difficulty: difficulty, seed: 20260823)
        let options = GeneratorOptions.default
        var used = 0

        for index in 0..<options.maxAttempts {
            used = index + 1
            if case .met = PuzzleGenerator.attempt(index, of: id, options: options) { break }
        }

        #expect(used <= budget,
                "\(difficulty.rawValue) brauchte \(used) Versuche, erlaubt \(budget)")
        #expect(PuzzleGenerator.generate(id).difficulty == difficulty)
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
