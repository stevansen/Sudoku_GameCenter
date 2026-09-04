# Decisions

Why the engine is built the way it is. Numbers come from
`swift test -c release -Xswiftc -enable-testing --filter Calibration`
(the suite is disabled by default; drop the trait to run it).

---

## A puzzle is its seed

`PuzzleID = (version, difficulty, seed)` and generation is a pure function of it.
Nothing else about a puzzle is ever stored or transmitted.

This buys three things at once: a sync record under 300 bytes, a daily puzzle
that is identical worldwide without a server, and golden tests that would catch
any change silently invalidating existing ids.

The price is a hard constraint: the generator may never use
`SystemRandomNumberGenerator`, and any change to the generator, the solver or the
rater that moves a golden must bump `PuzzleID.currentVersion` and keep the old
path alive. `GoldenTests` exists to make that impossible to do by accident.

A related rule the tests enforce: `generate(id)` always returns a puzzle carrying
the *requested* id. An earlier version fell back to a differently-seeded call when
its attempt budget ran out, which handed back an id that did not describe the
grid — exactly the kind of quiet breakage the whole design is meant to prevent.

## Difficulty: techniques *and* sparseness, not one or the other

The design started from a single principle — rate a puzzle by which human
techniques it demands, never by how many digits it gives away. Measurement forced
a correction.

What the data shows, over 25 puzzles per configuration:

| Technique ceiling | Given floor | Score range | Hardest technique actually needed |
|---|---|---|---|
| hidden single | 36 | 47–55 | naked single (23/25) |
| naked pair | 30 | 53–70 | singles only (25/25) |
| X-wing | 26 | 56–98 | singles only (20/25) |
| colouring | 23 | 56–391 | singles (16/25), wings/colouring (6/25) |
| forcing chain | 20 | 56–730 | as above, plus forcing chains |

Two findings:

1. **Uniqueness binds before technique does.** Digging greedily stops at 24–26
   givens because removing anything else would allow a second solution — not
   because the techniques ran out. Below about 26 the given floor stops mattering.
2. **There is no natural gap between medium and hard.** Triples, quads and
   X-wings are almost never *required*: whenever one would apply, a cheaper
   technique usually applies elsewhere first, so the solve never needs it. A tier
   defined as "must need a triple or an X-wing" is reachable in well under 5% of
   attempts, and an earlier two-pass construction built to force it produced
   nothing at all for that tier in 20 attempts.

So the ladder uses both knobs, and says so:

| Tier | Ceiling | Floor | Must require |
|---|---|---|---|
| easy | hidden single | 36 | — |
| medium | naked pair | 30 | — |
| hard | X-wing | 24 | more than singles |
| expert | colouring | 22 | a wing, swordfish or colouring |
| evil | forcing chain | 20 | a forcing chain, jellyfish or XYZ-wing |

The lower tiers are graded by how sparse the grid is — which is real difficulty
for a human, just not *technique* difficulty — and the upper tiers by what the
solve demands. Every tier now comes out characteristic of its label on 25 of 25
samples.

The score bands in `Difficulty.scoreRange` were calibrated against this output
afterwards, not chosen in advance. They classify a grid that did not come from
the generator; the generator itself knows the tier from what it built with.

## The logical solver earns its keep twice

It rates puzzles *and* powers the hint system — a hint names the technique and
the unit it applies to, not just the digit. That second use is why the technique
catalogue is worth its size.

It never guesses. `BruteForceSolver` does the guessing, and is used only to
verify uniqueness during generation and as the independent cross-check in tests.
Keeping them apart is what lets `LogicalSolverTests.neverContradictsTheSolution`
check every technique against the one true solution.

## The engine carries no prose

`Deduction` reports a technique, cells, and the unit involved — no sentences. The
UI composes the wording in the player's language. Keeps the engine
localisation-free and its tests about logic rather than strings.

## Deviations from the build plan

- **`remotePairs` is not implemented.** It shares a cost tier with jellyfish and
  XYZ-wing, both of which are implemented, so the tier is covered. Adding a
  technique that never changes an outcome would be dead weight in the rating.
- **The given-count floor stayed**, contrary to the plan's "difficulty comes from
  techniques, not givens". See above for the measurements that forced it.
- **Naked and hidden singles collapse in practice.** Because assignment
  propagates to all 20 peers immediately, most hidden singles have already become
  naked singles by the time they are looked for. The reference puzzle from the
  Wikipedia article needs nothing but naked singles.

## Milestone 2 deviations

- **A JSON file, not SwiftData, for now.** The plan called for SwiftData without
  CloudKit at this stage. A `Codable` file store is a fraction of the code, needs
  no model container to test, and Milestone 4 replaces it wholesale when CloudKit
  mirroring arrives — writing SwiftData twice would have been the wasteful path.
  `GameStore` is an actor with four methods, so the swap is contained.
- **No string catalogue yet.** `Bundle.module` only exists for packages that ship
  resources, and localisation is Milestone 6. German is the source language and
  every user-facing string already goes through `String(localized:)`, so adding
  the catalogue later is mechanical.
- **`Info.plist` lives beside the target folder, not inside it.** Xcode's
  synchronized file groups copy everything in the folder as a resource, which
  collides with the generated one. Keeping it one level up is the fix.

## Milestone 3 decisions

- **Achievement rules are a pure function.** `AchievementEvaluator` takes the
  facts of a finished game plus the player's totals and returns progress. No
  GameKit, no clock, no I/O — because the rules are the part that can be wrong,
  and this way each one is a test instead of a bug report from a player.
- **Everything queues.** Scores go through `SubmissionQueue` even when signed in.
  A win earned on a train is still a win; sending directly would lose it. The
  queue survives relaunching and compacts a backlog to the best value per board.
- **The point budget is asserted.** Apple caps achievement points at 1000 for an
  app's lifetime. A test pins the total at 880, so adding an achievement without
  rebalancing fails the build rather than the submission.
- **`authenticate()` resumes on the first callback.** GameKit's handler fires more
  than once and may only hand over a sign-in screen. Waiting for a final answer
  means waiting for the player to finish typing — with the app not yet loaded
  behind it. Sign-in now runs in its own task and `isAuthenticated()` is the
  source of truth afterwards.
- **`PlayerStats` decodes by hand.** Milestone 3 added five counters to it.
  Synthesised decoding would reject every file written by the earlier build and
  the player would silently lose their totals.

## Milestone 4 decisions

- **The key-value store, not CloudKit, carries the running game.**
  `NSUbiquitousKeyValueStore` propagates in seconds where CloudKit takes its
  time, and the moment the feature has to work is "put the phone down, carry on
  at the Mac". It only works at all because a saved game is an id plus the
  player's moves — a few hundred bytes, against a hard 1 MB limit.
- **Conflict resolution is a pure function**, with one rule behind every branch:
  never discard work silently. A lost saved game is invisible until it hurts and
  cannot be undone. So where the records genuinely disagree it asks, and
  everywhere else it stays out of the way — being asked about a conflict that is
  not one is its own kind of bad. The cases:

  | Situation | What happens |
  |---|---|
  | One side only | that side |
  | Same puzzle, one strictly further | the further one |
  | Same digits, different notes or clock | more moves, then newer |
  | Same puzzle, contradicting digits, clear lead in moves | the leader |
  | Same puzzle, contradicting digits, close call | **ask** |
  | Two different puzzles | **ask**, whatever the lead |

- **A remote change mid-game is ignored** until the player leaves the board.
  Swapping the grid under someone's hands is worse than being briefly out of date.
- **Statistics and history do not sync yet.** Only the running game does. Merging
  additive counters across devices without a CRDT or per-record history is a real
  problem — taking the maximum quietly loses points, taking the sum invents them.
  Game Center already carries the parts that matter across devices (points,
  best times, streak), so the gap is local totals only. This needs CloudKit with
  a proper record per solve, which needs a container that does not exist yet.

## Milestone 5 decisions

- **The board is laid out as real rows and columns**, not one absolutely
  positioned layer with offsets. `.offset` is a render-time transform: it moves
  what you see without moving the view's frame, and tvOS's focus engine navigates
  by frames. The old version would have looked right on Apple TV and been
  impossible to play.
- **Navigation state moved into `AppModel`.** The Mac menu bar has to be able to
  start a game, and reaching into a view's `@State` from a `Commands` block is not
  possible. `isPlaying` living in the model is the smaller compromise.
- **The undo/redo menu items replace the system ones.** SwiftUI's built-in items
  drive an `UndoManager` this game does not use, so they would have been dead.
- **tvOS is verified.** Once the runtime was installed it built first try and
  ran, and the focus ring moves across the board — which is the payoff for the
  layout change above. Three things needed fixing that only a television shows:
  the content column was sized for a phone and left two thirds of a 16:9 screen
  empty, the header wrapped mid-word, and nine keypad buttons in a row became
  nine tiny targets to steer a focus ring through (now five across, two rows).
- **A debug-only launch argument** (`-open-game <tier>`) opens the app straight
  into a game. Apple TV has no pointer, so its screens cannot be driven the way
  the iOS ones are; without this the board could not be looked at at all. Wrapped
  in `#if DEBUG`, so it never ships.
- **visionOS was built, then dropped.** It ran unchanged once its runtime was
  installed — the wide layout written for iPad landscape suited a window floating
  in a room, and the only platform-specific work was an icon. It was then taken
  out of scope by decision, not by difficulty, and the SDK removed with it.
  Should it ever come back: add `.visionOS(.v2)` to the four package manifests,
  put `xros xrsimulator` back in `SUPPORTED_PLATFORMS` with device family 7, and
  add a solid image stack named `AppIcon-vision` with an
  `ASSETCATALOG_COMPILER_APPICON_NAME[sdk=xr*]` setting pointing at it.
- **watchOS was dropped before it was written.** A 9×9 grid is not usable on a
  40 mm screen, so a watch app meant a 6×6 variant with its own generator,
  scoring and hint text — a second game, not a second layout. That is a product
  decision rather than a porting job, and it was not worth the surface area.
  The `.watchOS(.v11)` lines in the manifests and the `!os(watchOS)` guards
  around the Game Center views were removed with it; nothing else referred to it.
- **The icon is a 3x3 grid, not a 9x9 one.** At 40 points a full sudoku grid is
  grey mush. Three by three still reads as "sudoku" and stays legible down to the
  16-point macOS size. It is rendered by `Scripts/render-icons.swift` rather than
  drawn by hand, so every size comes from one description and the tvOS layers
  cannot drift from the flat one.
- **The catalogues were empty until Milestone 6.** They had the placeholder
  entries an Xcode template writes and no image files at all, so the app shipped
  with no icon — a grey square on the home screen — and would have failed
  submission. It took looking at the home screen to notice; nothing in the build
  complains.
- **Pre-warming made the app slow, not fast.** `PuzzleFactory` filled three
  puzzles of every tier at launch to keep "new game" instant. It is an actor, so
  the first real request queued behind all of it — around fourteen seconds on a
  cold start, with the difficulty buttons greyed out the whole time. Three
  changes: the expensive tiers keep one spare instead of three, the cheap ones
  are warmed first, and the generating happens in a detached task so the actor
  is not held while it runs. Yielding between puzzles was not enough on its own,
  because a single hard puzzle takes over two seconds and holds the actor for all
  of it. Warm-up is now 1.8 s and a request behind it waits about 0.3 s.
- **Point symmetry was what made the hard tiers slow, and it was not obvious.**
  Hard took 3.9 s per puzzle — more than evil — and the time was not in rating or
  solving but in *digging grids and throwing them away*: sixteen attempts, fifteen
  rejected. Digging in symmetric pairs stops about four givens short of where free
  digging stops (28 against 24), and at that density the puzzle can be solved with
  singles alone, which is exactly what the tier rejects. Measured over twelve
  digs, hard produced **nothing usable while symmetric and five in twelve
  without**, at the same cost per dig.

  Version 2 dropped the symmetry for those tiers and took hard from 3.9 s to
  0.19 s. **It was reverted**: the symmetry is wanted more than the speed. The
  grids are prettier with it and that is a real part of the thing.

  So the cost stands — hard needs about sixteen attempts — and it is paid for
  differently: see below.
- **The attempts run across cores, not one after another.** Each attempt is a
  pure function of the id and its index, so there is nothing to serialise them
  for. Generation takes the first attempt alone — easy and medium succeed on it
  almost every time, and running a batch of eight to discover that tripled their
  cost — and only spreads out once that has failed. Medians, symmetry restored:
  easy 55 ms, medium 95 ms, expert 275 ms, hard 645 ms, evil 1005 ms. Hard was
  3.9 s.

  Batches are taken in order and the lowest index that succeeds is returned,
  which is the attempt the sequential loop would have stopped at. That matters
  more than the speed — a stored id has to keep naming the grid it named before —
  and there is a test that runs both and compares.
- **Generation timing cannot be asserted in the test suite.** The suites run
  alongside each other and generation now uses the same cores they do; a tier
  that takes 0.6 s on its own takes eight seconds under that load. The tests
  count attempts instead, which is what the cost is actually made of and does not
  move with the machine.
- **Only the capabilities the app actually uses are declared.** The templates
  carried CloudKit, App Groups and push notifications; none of them is used.
  Statistics do not sync, the widget derives the daily puzzle from the date and
  needs no shared container, and there are no notifications. What ships is Game
  Center and the ubiquitous key-value store, which are the two the code genuinely
  reaches for. Declaring more invites a reviewer to ask what it is for.
- **The entitlements hang off the Release configuration.** macOS refuses to build
  at all with entitlements present and no development certificate, so leaving them
  on in Debug would mean nobody without a paid team could build or test the Mac
  app. Release carries them — you cannot ship without a team anyway — and Debug
  takes them on request with `SUDOKU_ENTITLEMENTS=Sudoku.entitlements`.
- **Every timing above was measured in a debug build, and they are all about
  thirty times too pessimistic.** The release test run made that plain: the engine
  suite takes 3.8 s optimised against 165 s unoptimised, and generating a hard
  puzzle takes 12 ms rather than 375 ms. Evil, the dearest tier, is 23 ms.

  So the twelve-second cold start that started the performance work was a debug
  artefact. In what ships, the whole warm-up is well under a tenth of a second.
  The changes still stand — fewer wasted attempts is fewer wasted attempts, and
  the ordering between tiers held exactly — but the problem they solved was
  smaller than it looked.

  The parallel attempt batching is kept rather than removed. In release it buys
  single-digit milliseconds, which would not justify it on its own; in a debug
  build it is worth a factor of three, and that is the build the tests and every
  development run use. `Difficulty.generationCost` now carries release figures,
  because that is what the app actually does.
- **The Mac App Store needs the sandbox, and the entitlements have to be baked
  in at archive time.** Validation rejected the package twice before this was
  right. `com.apple.security.app-sandbox` is required on the app *and* on the
  widget extension, and since iOS and tvOS are always sandboxed and have no such
  key, macOS gets its own entitlements files selected by
  `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`. Game Center talks to Apple's servers, so
  the sandbox also needs `network.client`; the game itself plays offline.

  The second failure was subtler: archiving unsigned and letting the export sign
  produces entitlements derived from the provisioning profile, not from the
  project — so the sandbox key silently disappeared. The macOS archive is signed
  as it is built.

  **The same mistake was still sitting in the tvOS build.** It was archived
  unsigned for a different reason — automatic signing wanted a development profile
  and there is no registered device — and nobody checked what came out. The
  uploaded tvOS build had *no entitlements at all*: no Game Center, no key-value
  store. It uploaded and validated cleanly; App Store Connect only refused at
  submission, with "add the com.apple.developer.game-center entitlement". tvOS now
  signs at archive time too, like macOS. iOS was unaffected — it was archived with
  signing from the start, and its uploaded binary carries the entitlements.

  The lesson generalises: **check the artefact, not the build log.**
  `codesign -d --entitlements :-` on what is actually going to be uploaded takes
  five seconds and is the only thing that answers the question.

  That manual signing belongs to **Release only**. Applying it to Debug as well
  made the Mac build fail with "embedded binary is not signed with the same
  certificate as the parent app", because the widget was then signing for
  distribution while the app signed ad-hoc.
- **Totals merge; they are not overwritten.** The obvious way to sync statistics
  is "newest wins", and it loses data: points are a sum of what was earned, not a
  high score. Two devices playing offline for a week, one of them wins, the other
  week is gone.

  So `PlayerStats` stores no aggregates. It stores the evidence — which puzzles
  were solved, for how many points, in what time, on which days — as sets and
  per-key dictionaries, and derives everything the player sees from it. Merging
  is union, maximum and minimum: commutative, associative and idempotent, so it
  does not matter which device merges first or how many times. Streaks are runs
  through the set of days, which is why two devices alternating days produce one
  streak rather than two of length one.

  Solving the same puzzle on both devices counts once, because the evidence is
  keyed by puzzle id.

  One case is not exact: points from a stats file written before this existed
  cannot be attributed to any puzzle, so they ride along as a single number and
  merge by maximum rather than sum. It can only affect data that predates the
  model.
- **Publishing has to publish the union.** Reading is not enough and neither is
  writing. The first version pushed this device's totals on finishing a game, and
  overwrote whatever the other device had published since — the integration test
  caught it immediately: two devices, two games, and each ended up with only its
  own. Both directions now happen in one step.
- **A hint has to end in something the player can do.** The board holds digits;
  candidates live in the player's own notes, if they keep any. So a step that
  only rules candidates out — locked candidates, a naked pair, an X-wing —
  changes nothing on the board, and the next hint rebuilds its candidates from
  that same board and finds the very same step. On the tiers *defined* by needing
  those techniques this is not an edge case but where every game ends up: playing
  a hard puzzle on hints alone stalled at 33 empty cells after 25 hints.

  `LogicalSolver.nextHint` now follows the reasoning on from that first step until
  it produces a digit. What gets explained is still the first step, because that
  is the one worth seeing; the card adds a line saying what it lets you place, so
  the button never writes a digit the explanation never mentioned. Every tier can
  now be finished on hints alone, and there is a test per tier that does exactly
  that.
- **The generator version exists for exactly this.** `SavedGame` stores only the
  puzzle *id*; the grid is regenerated from it. Changing what a seed produces
  would hand a player in mid-game a different puzzle with their entries scattered
  over it. So `PuzzleID.currentVersion` went to 2 and version 1 keeps its old
  symmetry rule for good. A test asserts a stored v1 id still names its own grid,
  and that v2 makes something different of the same seed — otherwise the test
  would be checking nothing.
- **The cost of extra platforms is disk, not code.** Each runtime plus its
  simulator data runs to several gigabytes. Nothing in the app had to change for
  visionOS; the machine had to.

## Known, deliberate, not done yet

- **Generation is a retry loop, not a search.** Roughly one attempt in five is
  characteristic of its tier for `hard`, one in four for `expert`. A local search
  over the given set — restore a cell, remove a different one, keep it if the
  rating improved — would converge instead of resampling, and would matter if the
  tiers ever get narrower. Today the p95 budgets are met, so it is not worth the
  complexity.
- **The technique finders allocate freely** (`filter`, `map`, dictionaries per
  call). Fine at current speeds; the obvious first place to look if generation
  ever needs to be faster.
