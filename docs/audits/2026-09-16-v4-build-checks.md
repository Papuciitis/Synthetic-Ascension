# V4 build checks, 2026-09-16

The first full pass over the V4 advancement tree's playable builds: every
preset replayed through the real purchase rules, fought in a scripted crowd
on the runner, then the whole game booted with a preset and driven by the
build probe, headless and rendered. Read this with the labels: HEADLESS
numbers have no rendering and bound the simulation only; rendered numbers
come from this laptop's integrated GPU.

## Machine, build, seed, loadout

| | |
|---|---|
| CPU | Intel Core i7-8650U (8 threads), 31 GB |
| GPU (rendered runs) | Mesa Intel UHD Graphics 620 (KBL GT2), OpenGL compatibility renderer, X11 display :0 |
| Godot | 4.7.2-stable (official), headless for the suites and the headless probes |
| Game build | 0.0.0.25.5, branch enemy-world-work, commit 74c1714 (stage 3e) plus the stage 4 test files |
| Seed | probe RNG 20260916 (PROBE_SEED); world seed 0; the preset suite's RNG 20260916 |
| Loadouts | `data/ascension/presets_v4.json` (37 presets); each pure preset equips its Q, V and one keystone; the Ascendant preset equips the Gavel, the Loaded Coin as Reaction Q, DECIMATION and REWRITE |
| Segment (probe) | 5, population 60, six scripted kills per second, Q every 3 s, V when charged, 40 s headless / 30 s rendered |

## 1. Preset suite (headless, `AscensionPresetTest`)

Every preset purchases in order at real prices and equips its loadout; the
six authored hybrids and the Ascendant build cost exactly their authored
Followers. Then each preset is installed on a live runner and fights a
60-body crowd for 240 frames: a native strike every fourth frame, Q every
45 frames, V at frames 60 and 180, a dash every 90 frames, the crowd
refilled every 30 frames. Afterwards the attack queue is drained and the
status registry holds only live enemies. The first measured frame includes
the 60-body spawn, so the max column carries that burst; p95 and p99 are
the judgement.

| Preset | Strikes | Casts | Dead / spawned | Generated attacks | Frame p50 | p95 | p99 | max | Wall p95 | Wall max |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Execution early | 60 | 0 | 6 / 66 | 67 | 6.90 | 6.94 | 10.75 | 82.11 | 8.68 | 10.12 |
| Execution developed | 60 | 3 | 99 / 132 | 651 | 6.91 | 6.94 | 10.33 | 25.16 | 9.29 | 32.83 |
| Execution pure | 57 | 5 | 122 / 125 | 570 | 6.89 | 6.94 | 10.06 | 35.43 | 9.26 | 39.19 |
| Momentum early | 60 | 0 | 6 / 65 | 65 | 6.94 | 6.94 | 7.00 | 7.26 | 8.79 | 11.89 |
| Momentum developed | 60 | 5 | 8 / 68 | 143 | 6.90 | 6.94 | 6.94 | 6.94 | 8.62 | 9.26 |
| Momentum pure | 60 | 6 | 15 / 73 | 225 | 6.90 | 6.90 | 6.90 | 6.90 | 9.03 | 10.29 |
| Bastion early | 60 | 0 | 6 / 65 | 60 | 6.90 | 6.90 | 6.90 | 6.90 | 8.84 | 9.99 |
| Bastion developed | 60 | 5 | 3 / 63 | 60 | 6.90 | 6.94 | 9.63 | 68.67 | 8.89 | 9.83 |
| Bastion pure | 60 | 7 | 47 / 107 | 119 | 6.90 | 6.90 | 6.90 | 6.90 | 9.37 | 12.33 |
| Precision early | 60 | 0 | 12 / 66 | 0 | 6.90 | 6.94 | 16.67 | 71.82 | 8.25 | 64.88 |
| Precision developed | 60 | 5 | 28 / 72 | 68 | 2.43 | 6.94 | 6.94 | 6.94 | 8.59 | 10.00 |
| Precision pure | 60 | 7 | 54 / 84 | 66 | 2.41 | 6.90 | 6.90 | 6.90 | 8.09 | 10.18 |
| Barrage early | 60 | 0 | 20 / 75 | 307 | 6.90 | 6.90 | 6.90 | 6.90 | 8.25 | 10.84 |
| Barrage developed | 60 | 1 | 49 / 92 | 651 | 6.90 | 6.90 | 6.90 | 6.90 | 8.26 | 13.09 |
| Barrage pure | 60 | 3 | 57 / 98 | 787 | 6.90 | 7.58 | 8.33 | 13.28 | 8.64 | 12.70 |
| Ordnance early | 60 | 0 | 21 / 74 | 101 | 6.90 | 6.90 | 6.90 | 6.90 | 8.04 | 9.11 |
| Ordnance developed | 60 | 5 | 33 / 79 | 194 | 6.90 | 7.41 | 7.41 | 10.22 | 7.97 | 21.57 |
| Ordnance pure | 60 | 7 | 12 / 69 | 96 | 6.90 | 6.90 | 6.90 | 6.90 | 7.87 | 9.54 |
| Invocation early | 60 | 0 | 8 / 67 | 60 | 6.90 | 6.90 | 6.90 | 6.90 | 8.90 | 10.96 |
| Invocation developed | 60 | 5 | 31 / 89 | 265 | 6.90 | 7.58 | 8.33 | 17.07 | 8.99 | 28.43 |
| Invocation pure | 60 | 7 | 88 / 117 | 655 | 6.94 | 7.58 | 11.02 | 46.22 | 9.18 | 58.06 |
| Distortion early | 60 | 0 | 9 / 69 | 165 | 6.90 | 6.90 | 6.94 | 6.94 | 8.30 | 8.93 |
| Distortion developed | 60 | 5 | 51 / 104 | 393 | 6.90 | 6.91 | 7.99 | 55.17 | 8.30 | 9.29 |
| Distortion pure | 60 | 7 | 112 / 132 | 854 | 6.90 | 6.90 | 6.90 | 6.90 | 8.55 | 10.91 |
| Dominion early | 60 | 0 | 56 / 113 | 424 | 6.90 | 7.41 | 7.41 | 12.35 | 8.86 | 15.18 |
| Dominion developed | 60 | 5 | 98 / 144 | 674 | 6.94 | 7.41 | 7.41 | 11.21 | 10.34 | 20.15 |
| Dominion pure | 55 | 7 | 134 / 146 | 1644 | 7.14 | 8.33 | 19.99 | 81.11 | 10.82 | 80.08 |
| Hybrid: Running guns | 60 | 6 | 30 / 80 | 451 | 6.90 | 6.90 | 6.90 | 6.90 | 8.72 | 9.39 |
| Hybrid: Corpse artillery | 56 | 5 | 117 / 119 | 579 | 6.94 | 6.94 | 7.27 | 35.34 | 8.88 | 38.69 |
| Hybrid: Death Debt | 55 | 5 | 135 / 135 | 891 | 6.94 | 6.94 | 6.94 | 12.35 | 8.37 | 23.98 |
| Hybrid: Stormwire | 60 | 3 | 134 / 141 | 2808 | 6.90 | 7.14 | 7.41 | 7.41 | 10.23 | 16.02 |
| Hybrid: Spell-loaded rail | 60 | 7 | 42 / 80 | 177 | 2.43 | 6.90 | 6.90 | 6.90 | 8.40 | 13.61 |
| Hybrid: Runes and mines | 60 | 7 | 67 / 91 | 387 | 6.90 | 6.94 | 6.94 | 6.94 | 7.97 | 19.61 |
| Hybrid: Kill Feed, ranged side | 60 | 3 | 53 / 98 | 740 | 6.90 | 6.94 | 6.94 | 6.94 | 8.05 | 10.81 |
| Hybrid: Death Debt, melee side | 54 | 5 | 126 / 134 | 819 | 6.90 | 7.75 | 8.33 | 19.25 | 8.94 | 25.64 |
| Hybrid: Wildfire, ranged side | 60 | 3 | 55 / 98 | 806 | 6.90 | 7.41 | 7.41 | 7.41 | 8.94 | 13.48 |
| Ascendant: Three-Core avalanche | 54 | 5 | 146 / 146 | 1452 | 6.94 | 6.94 | 6.94 | 6.94 | 8.57 | 17.13 |

Whole-system checks on the Execution pure preset, all green: despawning
every enemy mid-cast drains the queue; 300 spawn / mark / kill cycles leave
no status behind; pause blocks input and resume finishes the held queue;
refunding a mutation while the Gavel winds up returns Followers and
rebuilds the engines; save / load restores the owned set and equipment and
the engines rebuild; leaving and re-entering the tree unwires and rewires
the runner; Revelations off refuses V and on casts it.

## 2. Build probe (real game, segment 5)

`tools/tests/AscensionBuildProbe.tscn`: the game boots, the preset loads
through the dev route loader (real purchases, funded), the spawner keeps 60
bodies alive, six scripted native kills per second run the kill families,
Q fires every 3 s and V whenever its meter is full. "Tree usec" is the
runner's own per-frame cost (engine ticks + attack flush + hit handling)
from `get_debug_counters`.

| Preset | Mode | Frames | Frame p50 | p95 | p99 | max | Wall p95 | Wall max | Draw calls p50 | Nodes start -> end | Tree usec p50 / p95 / max | Kills | Casts | Report |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---:|---:|---|
| Ascendant: Three-Core avalanche | headless | 5387 | 6.73 | 12.26 | 16.56 | 68.59 | 12.72 | 63.31 | 0 | 2159 -> 2742 | 1033 / 5134 / 28513 | 209 | 26 | `headless_ascendant_three_core_avalanche.json` |
| Barrage pure | headless | 5698 | 6.94 | 7.14 | 8.33 | 73.99 | 10.46 | 62.72 | 0 | 2114 -> 2737 | 1551 / 2691 / 6897 | 240 | 11 | `headless_barrage_pure.json` |
| Bastion pure | headless | 5745 | 6.90 | 7.14 | 8.33 | 27.03 | 11.81 | 29.23 | 0 | 2247 -> 2522 | 15 / 42 / 27154 | 240 | 14 | `headless_bastion_pure.json` |
| Distortion pure | headless | 5615 | 6.94 | 8.33 | 12.50 | 34.95 | 11.41 | 38.90 | 0 | 2132 -> 2753 | 34 / 3088 / 29980 | 223 | 25 | `headless_distortion_pure.json` |
| Dominion pure | headless | 5692 | 6.94 | 7.41 | 9.75 | 49.71 | 11.68 | 48.56 | 0 | 2103 -> 2618 | 254 / 831 / 75678 | 240 | 17 | `headless_dominion_pure.json` |
| Execution pure | headless | 5534 | 6.94 | 8.56 | 14.37 | 71.91 | 11.97 | 43.16 | 0 | 2186 -> 2797 | 46 / 2927 / 35349 | 222 | 26 | `headless_execution_pure.json` |
| Invocation pure | headless | 5748 | 6.94 | 7.14 | 8.33 | 22.26 | 11.47 | 27.55 | 0 | 2197 -> 2674 | 41 / 125 / 8578 | 240 | 17 | `headless_invocation_pure.json` |
| Momentum pure | headless | 5721 | 6.90 | 6.94 | 8.33 | 81.43 | 10.40 | 86.28 | 0 | 2230 -> 3032 | 20 / 78 / 15050 | 240 | 15 | `headless_momentum_pure.json` |
| Ordnance pure | headless | 5563 | 6.94 | 8.33 | 13.60 | 35.16 | 11.56 | 62.78 | 0 | 2120 -> 2695 | 124 / 4677 / 19135 | 240 | 25 | `headless_ordnance_pure.json` |
| Precision pure | headless | 6461 | 6.90 | 7.14 | 8.33 | 69.28 | 11.64 | 26.05 | 0 | 2233 -> 2554 | 12 / 29 / 9258 | 240 | 14 | `headless_precision_pure.json` |
| Ascendant: Three-Core avalanche | windowed | 1298 | 22.07 | 34.73 | 47.71 | 77.02 | 39.01 | 91.12 | 717 | 2271 -> 2838 | 3768 / 13980 / 72039 | 171 | 18 | `windowed_ascendant_three_core_avalanche.json` |
| Dominion pure | windowed | 1776 | 16.67 | 16.67 | 24.99 | 75.00 | 21.98 | 82.83 | 305 | 2140 -> 2850 | 319 / 3248 / 166845 | 178 | 13 | `windowed_dominion_pure.json` |
| Execution pure | windowed | 1724 | 16.67 | 25.13 | 34.22 | 80.27 | 29.96 | 67.14 | 517 | 2174 -> 2775 | 213 / 7706 / 60576 | 172 | 18 | `windowed_execution_pure.json` |

## 3. What the numbers say

- Every headless build holds a 6.9 ms median (the headless frame pacing on
  this CPU) with p99 at or under 16.6 ms. Rendered on the UHD 620 the median
  is the 16.7 ms vsync frame; Execution pure sits at p95 25 ms, Dominion
  pure at p95 16.7 ms, the Three-Core avalanche at p95 34.7 ms with 717
  draw calls at the median. The avalanche is the heaviest rendered build.
- The single worst frames (22-91 ms) are real and are not the tree's
  steady cost: the tree's own p95 is 0.03-5 ms headless (Ascendant 5.1 ms,
  Ordnance 4.7 ms, Distortion 3.1 ms). The worst frames coincide with the
  spawner refilling up to 60 bodies at once, segment streaming, and a few
  single-frame tree spikes: Dominion pure's worst tree frame is 76 ms
  headless and 167 ms rendered, Execution pure 35 / 61 ms, the avalanche
  29 / 72 ms. Those spikes are the next performance target (see §5); they
  were not smoothed by dropping damage, interactions or population.
- Node counts rise from about 2,100 to 2,600-3,000 over 40 s at population
  60 with the ground-loot cap active; no unbounded build-up.
- Headless and rendered kill counts differ (240 vs 170-178 in 40 vs 30 s)
  only because of the durations.

## 4. Comparison with the 15 September captures

The 14 September lag (chain bursts spawning slash/impact nodes per kill,
physics 337 ms, 12k draw calls) is gone from every build here: generated
attacks are data on the runner's queue, and the heaviest rendered build's
worst frame is 91 ms of wall time with a 717 draw-call median. The dense
Barrage benchmark's fragment update stays at p95 5.0-6.0 ms (changelog).
What this pass cannot claim: a play-feel verdict. The rendered runs are
scripted kills at a fixed cadence on an integrated GPU; a hand playtest at
the checklist's step 3 is still owed.

## 5. Follow-ups this pass found

1. Dominion's single-frame tree spikes (76 ms headless, 167 ms rendered
   worst frame): forced movement of a full Well or a KNEEL slam moves and
   damages every caught body in one tick. Budget the per-tick moves the way
   the attack queue is budgeted, without changing outcomes.
2. Execution pure and the avalanche: the worst frames coincide with a
   DECIMATION or Gavel chain resolving many kills in one flush. The flush
   budget is 12 attacks per frame; kill families that resolve synchronously
   inside on_kill (Spillover bolts, Corpse Bombs queued then flushed) still
   cluster. Spread the on-kill work across frames without reordering it.
3. The spawner's top-up spawns up to 60 bodies in one frame in the probe;
   in play the spawner paces itself, so this is a harness artefact to
   separate from the tree in the next capture.
4. Rendered draw calls (305-717 at the median) put the UHD 620 at or above
   the vsync frame on their own; the tree's drawn payloads are a share of
   that. A rendered capture with the overlay's draw-call breakdown is the
   next step before any art pass.

Raw reports: `docs/audits/2026-09-16-v4-build-checks/*.json`. Godot prints
"Texture with GL ID ... leaked" lines when a rendered run quits; they come
from the engine shutdown, not from this pass, and are unchanged from
earlier windowed runs.
