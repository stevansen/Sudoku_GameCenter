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
