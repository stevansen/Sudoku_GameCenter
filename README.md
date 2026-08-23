# Sudoku

A procedurally generated sudoku for every Apple platform, with Game Center
leaderboards, achievements, and a game that follows you across your devices.

Status: **Milestone 1 complete** — `SudokuKit`, the engine. No app target yet.

## Layout

```
Packages/SudokuKit/     the engine: grid, solvers, generator, rating, scoring
docs/decisions.md       why things are the way they are, with the measurements
```

Planned, per the build plan: `SudokuStore` (SwiftData + CloudKit),
`SudokuGameCenter` (GameKit), `SudokuUI` (shared SwiftUI), and the app targets.

## Build and test

```bash
cd Packages/SudokuKit && swift test
```

Performance budgets only assert in a release build, because a debug build is an
order of magnitude slower:

```bash
cd Packages/SudokuKit && swift test -c release -Xswiftc -enable-testing
```

## The engine in one page

A puzzle is not stored, it is **regenerated from its id**:

```swift
let puzzle = PuzzleGenerator.generate(difficulty: .expert, seed: 0x5EED)
puzzle.id            // v1-expert-0000000000005eed
puzzle.givens        // the grid
puzzle.rating        // 303
puzzle.techniques    // [.nakedSingle, .hiddenSingle, .lockedCandidates, .xyWing]
```

The same id yields the same grid on every device and in every build, which is
what makes cross-device sync cheap (under 300 bytes) and lets the daily puzzle be
identical worldwide without a server:

```swift
let today = PuzzleGenerator.daily(for: .now, difficulty: .medium)
```

Solving, hinting and scoring:

```swift
LogicalSolver.nextDeduction(grid)     // the next step, with the technique that found it
BruteForceSolver.hasUniqueSolution(grid)
Scoring.breakdown(for: SolveRecord(difficulty: .hard, seconds: 840, mistakes: 1))
```

Measured on Apple silicon, release build, 25 puzzles per tier:

| Tier | average | worst | givens | typical hardest technique |
|---|---|---|---|---|
| easy | 0.6 ms | 1.0 ms | 36–37 | naked single |
| medium | 1.2 ms | 2.9 ms | 30–31 | hidden single |
| hard | 28 ms | 97 ms | 25–31 | locked candidates, hidden pair |
| expert | 62 ms | 141 ms | 25–31 | W-wing, XY-wing, colouring |
| evil | 29 ms | 64 ms | 22–26 | forcing chain |

## Before the app can ship

These cannot be done from code and need an Apple Developer account:

- App IDs `com.sudoku.app` (+ `.tv`, `.watchkitapp`, `.widgets`) with the
  Game Center, iCloud and App Groups capabilities.
- The iCloud container `iCloud.com.sudoku.app`.
- Every leaderboard and achievement created in App Store Connect. The IDs will
  live in `docs/gamecenter-setup.md`, written in Milestone 3.
