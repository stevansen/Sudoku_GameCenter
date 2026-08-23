import Foundation
import SudokuKit

/// Keeps a few puzzles ready per tier so "new game" never waits.
///
/// The tiers are not equally cheap. Easy and medium take about 40 ms; hard takes
/// nearly four seconds, because it retries until the puzzle actually needs the
/// techniques that define the tier. Filling three of everything therefore costs
/// around fourteen seconds — and this being an actor, the first real request
/// used to queue behind all of it. On a cold start the Mac sat there for twelve
/// seconds with its buttons greyed out.
///
/// So: the expensive tiers keep one spare rather than three, the cheap ones are
/// filled first, and the refill yields between puzzles so that somebody actually
/// asking for a game overtakes it.
public actor PuzzleFactory {
    private var pools: [Difficulty: [Puzzle]] = [:]
    private var nextSeed: UInt64
    private let poolSize: Int

    public init(seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max), poolSize: Int = 3) {
        self.nextSeed = seed
        self.poolSize = poolSize
    }

    /// How many to keep ready. One of the slow tiers is worth having; three is
    /// twelve seconds of work for a spare nobody asked for.
    private func poolSize(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy, .medium: poolSize
        default: max(1, poolSize / 3)
        }
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
    ///
    /// Cheapest tiers first, and — the part that matters — the generating happens
    /// *off* this actor. Yielding between puzzles is not enough on its own: a
    /// hard puzzle takes over two seconds to produce, and for those two seconds
    /// the actor would be held, so somebody asking for a game still waits. Doing
    /// the work in a detached task suspends the actor for its duration, and the
    /// request is served from the pool straight away.
    public func refill() async {
        for difficulty in Difficulty.allCases.sorted(by: { $0.generationCost < $1.generationCost }) {
            while pools[difficulty, default: []].count < poolSize(for: difficulty) {
                if Task.isCancelled { return }
                let seed = advanceSeed()
                let puzzle = await Task.detached(priority: .background) {
                    PuzzleGenerator.generate(difficulty: difficulty, seed: seed)
                }.value
                pools[difficulty, default: []].append(puzzle)
            }
        }
    }

    private func generate(_ difficulty: Difficulty) -> Puzzle {
        PuzzleGenerator.generate(difficulty: difficulty, seed: advanceSeed())
    }

    private func advanceSeed() -> UInt64 {
        nextSeed = nextSeed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return nextSeed
    }
}
