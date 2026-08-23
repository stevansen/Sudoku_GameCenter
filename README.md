# Sudoku

A procedurally generated sudoku for every Apple platform, with Game Center
leaderboards, achievements, and a game that follows you across your devices.

Status: **Milestone 5 complete** — one codebase, five platforms, all built and
run at least once.

## Layout

```
App/                    the Xcode project and app target (com.sudoku.app)
Packages/SudokuKit/     the engine: grid, solvers, generator, rating, scoring
Packages/SudokuUI/      game state, persistence and the shared SwiftUI screens
Packages/SudokuGameCenter/  GameKit behind a protocol, achievement rules, offline retry queue
Packages/SudokuSync/    cross-device handover: conflict resolution and the key-value fast path
Configuration/          entitlements, privacy manifest, Info.plist and export templates
docs/decisions.md       why things are the way they are, with the measurements
docs/gamecenter-setup.md   the leaderboard and achievement IDs to enter in App Store Connect
docs/app-store/         release checklist, metadata (de/en), age rating, review notes, asset specs
docs/privacy/           privacy policy (de/en) and the App Privacy questionnaire answers
```

Planned, per the build plan: tvOS and watchOS targets (Milestone 5) and the
polish pass (Milestone 6). Statistics and history do **not** sync between
devices yet — see `docs/decisions.md`.

## Build and test

```bash
cd Packages/SudokuKit && swift test
cd Packages/SudokuUI && swift test
cd Packages/SudokuGameCenter && swift test
cd Packages/SudokuSync && swift test

# the app
cd App && xcodebuild -scheme Sudoku \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
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

Game Center goes through one protocol, so nothing else in the app touches
GameKit — which matters because GameKit cannot be driven from a test:

```swift
let progress = AchievementEvaluator.progress(for: event, totals: totals)
await queue.send(scores: submissions, achievements: progress, using: service)
```

Anything that cannot be sent is kept on disk and goes out at the next sign-in,
compacted to the best value per leaderboard.

Handover between devices sends the id and the player's work on top of it —
a few hundred bytes, small enough for the key-value store, which propagates in
seconds where CloudKit takes its time. Where two devices genuinely disagree it
asks rather than guesses:

```swift
switch ConflictResolver.resolve(local: local, remote: remote) {
case .useLocal, .useRemote: break          // one is simply further along
case .ask(let reason): break               // real divergence — the player decides
}
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

## Platforms

| Platform | Code | Built | Run |
|---|---|---|---|
| iOS | shared | yes | yes, verified in the simulator |
| iPadOS | shared + wide layout | yes | portrait verified; landscape layout unverified |
| macOS | shared + menu bar + keyboard | yes | launches; window contents not verified (no screen-recording permission here) |
| tvOS | focus-based board, wider layout, 5x2 keypad | yes | yes, verified in the simulator |
| visionOS | shared, wide layout | yes | yes, verified in the simulator |
| watchOS | not started (Milestone 6) | — | — |

Each platform family needs its own icon shape, which is why the asset catalog
carries three: a flat `AppIcon` for iOS and macOS, a layered image stack with
top-shelf images for tvOS, and a solid image stack for visionOS, selected by
SDK-conditional build settings.

Building for all five needs roughly 40 GB of platform runtimes and simulator
data. Worth knowing before starting.

## Shipping

Everything that can be prepared without a built app is prepared — start at
[docs/app-store/release-checklist.md](docs/app-store/release-checklist.md), which
is ordered end to end and marks the steps only a human with an Apple account can
do. Submission itself has to wait for the app targets (Milestones 2–6).

Not preparable here, because they need your account, your money or your design:
the Developer Program membership and Team ID, a public privacy-policy and support
URL, the app icon and screenshots, and the tax and banking details.
