# Playtest performance feedback — 2026-10-18

The report review confirmed unnecessary visual initialization at both boss
entrances. The fix constructs each boss's final form once, preserving the
existing art, collision footprint, health, damage, rewards and attack clocks.
It reduces measured entrance work; it does not establish a general FPS gain
or resolve every reported stall.

## Capture provenance and interpretation

The source is the user's 126 incident JSONs in
`performance_results/2026-10-18/`, named from 14:24:32 through 14:52:03.
Their recorded build is game `0.0.0.25.5`, Godot `4.7.1-stable (official)`,
branch `feat/authoritative-enemy-world`, commit `c9d5a31772f3`, world seed
`1794675549650`. This is original report metadata, not a clean-tree claim
about the later fixes.

Rolling windows overlap. Deduplicating samples by `t_usec` leaves **66,568
samples**; deduplicating events by `(t_usec, category, name)` leaves **14,585
events**. The recovered combat subset, defined by cached enemy count above
zero and no scene-change mark, has 39,818 samples: wall p50 **16.967 ms**,
p95 **28.571 ms**, p99 **41.421 ms**, maximum **168.161 ms**. These are
incident-window statistics, not an unbiased full-session benchmark.

`wall_ms` measures actual sample spacing; `frame_ms` is the capped engine
delta. `process_ms` and `physics_ms` are windowed monitors. Nested enemy,
scheduler, chunk and flow snapshots can be 0.5 seconds old. The scheduler's
per-frame physics interval spans other scene callbacks and deferred work;
an `enemy_step` tag therefore does not prove enemy self time.

## Confirmed entrance cause and fix

Incident 106, `2026-10-18_14-45-47_segment-10_incident-106.json`, contains the
worst recovered combat frame at `t_usec=1351646642`: **168.161 ms wall** and
**155.083 ms physics interval**. `boss_started` occurred 148.406 ms before
that sample, and the Arcanist spawn event 106.153 ms before it. Its cached
snapshot has 39 enemies / 30 projectiles; Barrage fragment work is only
27 microseconds. The nested scheduler's 8.46 ms value is cached, not this
frame's physics measurement.

`BossArena._spawn` previously added the actor to the tree before setting its
visual tier. `EnemyInit._apply_visuals` loaded the S5 form and created
`BossActing`; arena rules immediately replaced them with S10. MiniBossArena
also repeated its existing S5 setup. The new regression directly observed
two form/acting constructions for every role/tier, rather than inferring
the cause solely from the capture tag.

Both arenas now set `boss_visual_tier` before tree entry. Their rule methods
skip duplicate appearance work while retaining reconfiguration for an
already-ready actor from another tier. The authoritative world radius is
correct at registration and matches the physical body.

The one recovered S5 entrance spans 83.732 ms wall / 59.121 ms physics.
One recovered entrance per tier cannot establish role or general boss balance.

## Bounded before-and-after verification

Native Windows Godot 4.7.1, `--headless --audio-driver Dummy`, fresh engine
process per run, isolated process-local APPDATA/LOCALAPPDATA. The test calls
the actual arena `_spawn`, including autoload signal listeners, without
Game/HUD. Order is S10 Arcanist, S10 Bulldozer, S5 Arcanist, S5 Bulldozer.
OS file cache was not cleared.

| Entrance | Before: three-run median | After: one observed run |
| --- | ---: | ---: |
| S10 Arcanist | 222.297 ms | 70.408 ms |
| S10 Bulldozer | 108.011 ms | 20.016 ms |
| S5 Arcanist | 65.659 ms | 27.136 ms |
| S5 Bulldozer | 46.454 ms | 20.207 ms |

Every baseline constructs two forms and fails the four intended assertions
(12 passed / 4 failed, native exit 1). The corrected run constructs one final
form in each case (16/16, native exit 0). BossProportionTest passes **72/72**
and ArenaRewardSettlementTest **83/83**, both native exit 0. All three passing
suite executions have empty stderr. Cold texture/portrait work remains; these timings
measure the bounded spawn path rather than rendered frame rate.

Changed source identities, with full SHA-256 values in the evidence manifest:

| Source | SHA-256 prefix |
| --- | --- |
| `scenes/world/events/BossArena.gd` | `457269e3f1467726` |
| `scenes/world/events/MiniBossArena.gd` | `2376a697f6bbd339` |
| `tools/tests/BossSpawnPresentationTest.gd` | `8f756bfd30f647f9` |
| `tools/tests/BossSpawnPresentationTest.tscn` | `d0670d5355e7564a` |

## Remaining findings and retained evidence

The largest capture gap is scene-marked at **8.754 s**, followed by a
scene-building interval of **1.583 s**; these belong to the separate
front-end/loading investigation. No-enemy hub intervals include **715.864 ms
wall / 286.247 ms physics**, **187.279 ms wall / 178.972 ms deferred**, and
another frame's **358.03 ms render/present**. Some large gaps overlap
Ascension purchases. These coarse measurements cannot distinguish script,
resource/driver work and operating-system wait without a focused reproduction.
No enemy-budget, difficulty or simulation-clock tuning was made from them.

Persistent evidence is in
[`evidence/2026-10-18-performance-feedback/`](evidence/2026-10-18-performance-feedback/):
`capture-excerpts.json` preserves the relevant raw samples and in-frame events;
`deduplicated-captures.json` records statistics and the 40 largest intervals;
`boss-spawn-comparison.json` preserves every timing observation. The original
126 report hashes, source/context hashes and copied-evidence hashes are in
`provenance.json`. `verification.json` records the native exit results, and
the expected-red, clean-green and compatibility logs are retained. The two
small analysis scripts reproduce the extraction and comparison; raw rolling
incidents are not duplicated into this evidence directory.
