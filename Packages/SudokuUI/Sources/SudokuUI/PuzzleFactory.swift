import Foundation
import SudokuKit

/// Keeps a few puzzles ready per tier so "new game" never waits.
///
/// Generation is fast — single-digit milliseconds for the lower tiers — but it
/// is still work, and it has a long tail because it retries until the puzzle is
/// characteristic of its tier. A small pool makes that tail invisible.
public actor PuzzleFactory {
    private var pools: [Difficulty: [Puzzle]] = [:]
    private var nextSeed: UInt64
    private let poolSize: Int

    public init(seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max), poolSize: Int = 3) {
        self.nextSeed = seed
        self.poolSize = poolSize
    }

    /// A puzzle of the requested tier, from the pool if one is ready.
    public func puzzle(for difficulty: Difficulty) -> Puzzle {
        if var pool = pools[difficulty], let puzzle = pool.popLast() {
            pools[difficulty] = pool
            return puzzle
        }
        return generate(difficulty)
    }

    /// Tops every pool back up. Call it after handing one out, off the main actor.
    public func refill() {
        for difficulty in Difficulty.allCases {
            while pools[difficulty, default: []].count < poolSize {
                pools[difficulty, default: []].append(generate(difficulty))
            }
        }
    }

    private func generate(_ difficulty: Difficulty) -> Puzzle {
        nextSeed = nextSeed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return PuzzleGenerator.generate(difficulty: difficulty, seed: nextSeed)
    }
}
