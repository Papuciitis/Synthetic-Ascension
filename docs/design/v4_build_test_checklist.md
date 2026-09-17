# V4 advancement tree: build-test checklist

A reproducible pass over the tree's builds. Run it after any change to
`core/systems/ascension/`, the projectile manager, the enemy world services
or the player's damage and dash paths. Never run the engine while a playtest
is in progress on the same machine.

```
G=~/Downloads/Godot_v4.7.2-stable_linux.x86_64
cd ~/Nauris/Synthetic-Ascension
```

## 1. Headless regression (about 12 minutes)

Run after `$G --headless --path . --import` whenever scripts were added.
Each suite prints `N passed, M failed`; `ScriptParseAuditTest` goes last.

```
for t in AscensionLedgerTest AscensionRunnerTest AscensionBarrageTest \
         AscensionExecutionTest AscensionDistortionTest AscensionHybridTest \
         AscensionScreenTest AscensionRuntimeSafetyTest AscensionSharedRulesTest \
         AscensionSliceCompletionTest AscensionMomentumTest AscensionBastionTest \
         AscensionPrecisionTest AscensionOrdnanceTest AscensionInvocationTest \
         AscensionDominionTest AscensionFusionTest AscensionChainBurstBenchmark \
         AscensionBarrageDenseBenchmark EnemyLowestHealthQueryTest \
         FlightRecorderSampleTest EnemyCombatQueryTest BalanceLedgerTest \
         BalanceCaptureWriterTest BalanceRecorderLoadTest GroundLootCapTest \
         LoadingScrimTest ScriptParseAuditTest; do
  printf "%-32s " $t
  $G --headless --path . res://tools/tests/$t.tscn --quit-after 3000 2>&1 | grep -E "passed|failures=|SCRIPT ERROR" | tail -1
done
# The preset suite fights 37 crowds and needs more frames:
$G --headless --path . res://tools/tests/AscensionPresetTest.tscn --quit-after 40000 2>&1 | grep -E "FAIL|passed|HEADLESS"
```

What each group proves:

- Ledger / Runner / Screen: purchase rules at authored prices, equipment,
  refunds, save round-trip, the radial map.
- One suite per discipline plus Fusion: every authored node rule with real
  enemies, real projectiles and the player's damage path.
- SharedRules / SliceCompletion / Hybrid / RuntimeSafety: Gates, Witness,
  Reaction Q, Ascendant, action charge, Encore/Overflow, physics-query
  mutation, detached-enemy cleanup, reentrant callbacks.
- Preset: all 37 presets purchase in order through the real rules, equip,
  build their engines, fight a 60-body crowd with strikes, Q, V and dashes;
  then despawn mid-effect, 300 handle-reuse cycles, pause/resume, a refund
  with live engine state, save/load, a scene transition and the
  Revelations toggle.
- Benchmarks: chain bursts and the dense fragment storm keep their p95 /
  p99 bounds. Their single worst frame is printed but not asserted.

Frame numbers printed by headless runs are process deltas without any
rendering. They bound the simulation cost only.

## 2. Build probe (real game, headless or rendered)

`tools/tests/AscensionBuildProbe.tscn` boots the real game at a segment,
loads a preset through the dev route loader (real purchases, funded), keeps a
crowd alive, strikes and casts on a schedule, and writes a JSON report.

```
OUT=docs/audits/<date>-v4-build-checks
PROBE_PRESET="Execution pure" PROBE_SECONDS=40 PROBE_POP=60 PROBE_OUT="$OUT/headless_execution_pure.json" \
  $G --headless --path . res://tools/tests/AscensionBuildProbe.tscn
# rendered: same command without --headless on a real display
DISPLAY=:0 PROBE_PRESET="Dominion pure" PROBE_SECONDS=30 PROBE_OUT="$OUT/windowed_dominion_pure.json" \
  $G --path . res://tools/tests/AscensionBuildProbe.tscn
```

Environment: `PROBE_PRESET` (any route or preset name from the dev loader),
`PROBE_SEGMENT` (5), `PROBE_SECONDS` (40), `PROBE_POP` (60),
`PROBE_KILLS_PER_SEC` (6), `PROBE_CAST` (1), `PROBE_SEED` (20260916),
`PROBE_OUT`. The report records whether it ran headless, the display server
and renderer, CPU, GPU, Godot version, build info, seed, loadout, frame and
wall percentiles, draw calls, node counts, the runner's subsystem counters
and the events (preset load, Revelations).

Compare runs on the same machine and preset only. A rendered run at 60 Hz
vsync sits at a 16.7 ms median by construction; read p95 / p99 / max and the
draw-call median.

## 3. Rendered playtest pass (by hand)

For each discipline preset (`Execution pure` … `Dominion pure`) and the
three hybrids, from the overlay's Run tab (Load route):

1. Load the preset with Revelations off; fight one segment. Watch: Q feel,
   the resource strip (LINE / HEAT / MOMENTUM / FORCE / AIM / COORD /
   SIGILS / DEBT / WELLS), on-kill chains reading as chains.
2. Revelations on: cast V once at full charge; confirm the state ends and
   the meter refills; at Ascendant hold V for the pair.
3. Elites and the segment boss: the durable rules (Sentence, Beacon,
   Anchor, resisted travel, boss slam) show without a stagger bar.
4. Dense crowd (overlay: Enemy HP x3, population cap 80): frame time stays
   readable; no node build-up in the World tab's Node census.
5. Equipment and Manifestations: swap the Q and a keystone at the Hub, then
   again mid-run (T); confirm the runner refreshes and nothing double-fires.
6. Save at the Hub, quit, continue: the tree, the equipped slots and the
   claims survive.

Record outcomes in `docs/audits/<date>-v4-build-checks.md` with hardware,
build, seed and loadout. Anything that only a rendered session can judge
(read as chains, placeholder feedback legibility, Throw against terrain)
stays "awaiting playtest" in the matrix until this pass is done.

## 4. Where the numbers live

- `docs/audits/2026-09-16-v4-build-checks.md`: the first full pass.
- `docs/PERFORMANCE_PATCH_CHANGELOG.md`: benchmark bounds and why.
- `docs/design/v4_implementation_matrix.md`: implemented / partial / n/a
  per node, regenerated by `python3 tools/design/build_v4_matrix.py`.
