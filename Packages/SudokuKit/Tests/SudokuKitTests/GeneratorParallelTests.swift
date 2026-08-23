import Foundation
import Testing
@testable import SudokuKit

/// Attempts are evaluated across cores. The result must not depend on that.
///
/// The id *is* the puzzle — nothing stores the grid — so if running the attempts
/// concurrently changed which one came back, every saved game and the shared
/// daily puzzle would quietly move under everyone.
@Suite("Parallel generation", .serialized)
struct GeneratorParallelTests {
    /// What the loop did before it was parallelised: attempts in order, first
    /// success wins, first near miss kept as a fallback.
    func generateSequentially(_ id: PuzzleID, options: GeneratorOptions = .default) -> Puzzle {
        var fallback: Puzzle?
        for index in 0..<max(1, options.maxAttempts) {
            switch PuzzleGenerator.attempt(index, of: id, options: options) {
            case .met(let puzzle): return puzzle
            case .missed(let puzzle): if fallback == nil { fallback = puzzle }
            case .rejected: continue
            }
        }
        return fallback ?? PuzzleGenerator.generate(id, options: options)
    }

    @Test(arguments: Difficulty.allCases)
    func theBatchesReturnWhatTheSequentialLoopWouldHave(difficulty: Difficulty) {
        for seed in [UInt64(1), 20260823, 0xDEAD_BEEF] {
            let id = PuzzleID(difficulty: difficulty, seed: seed)
            let parallel = PuzzleGenerator.generate(id)
            let sequential = generateSequentially(id)
            #expect(parallel.givens == sequential.givens,
                    "\(id.description) kam anders heraus")
            #expect(parallel.solution == sequential.solution)
            #expect(parallel.rating == sequential.rating)
        }
    }

    @Test func generationStaysReproducible() {
        let id = PuzzleID(difficulty: .hard, seed: 4242)
        let runs = (0..<4).map { _ in PuzzleGenerator.generate(id) }
        for run in runs.dropFirst() {
            #expect(run.givens == runs[0].givens)
        }
    }

    /// The point of the exercise: the symmetric tiers stay symmetric, and they
    /// arrive in a reasonable time anyway.
    @Test(arguments: [
        (Difficulty.easy, 1.0), (.medium, 1.0), (.hard, 2.0), (.expert, 3.0), (.evil, 3.0),
    ])
    func aTierArrivesInTime(difficulty: Difficulty, budget: Double) {
        let start = Date()
        let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: 20260823)
        let elapsed = Date().timeIntervalSince(start)
        print("### \(difficulty.rawValue): \(Int(elapsed * 1000)) ms")
        #expect(puzzle.difficulty == difficulty)
        #expect(elapsed < budget, "\(difficulty.rawValue) brauchte \(elapsed)s")
    }

    @Test func theSymmetricTiersAreStillSymmetric() {
        for difficulty in [Difficulty.easy, .medium, .hard, .expert] {
            let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: 7)
            for cell in 0..<81 where cell != 40 {
                #expect((puzzle.givens[cell] == 0) == (puzzle.givens[80 - cell] == 0),
                        "\(difficulty.rawValue) ist nicht punktsymmetrisch")
            }
        }
    }
}
