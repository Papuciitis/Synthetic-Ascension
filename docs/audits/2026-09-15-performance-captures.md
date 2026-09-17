# September 15 Performance Capture Review

## Scope and Conclusion

Reviewed the 60 new JSON incidents from 08:30:19 through 08:40:18 on September 15, segments 2 and 3. Current checkout: `28cc9a1`. The user reports that remaining lag is mostly during combat.

The strongest combat lead is Barrage fragment target acquisition. It bypasses the new slash/impact attack budget, and an isolated probe reproduced expensive updates. This establishes a real scaling problem, not its exact contribution to every saved gameplay frame. Streaming stalls and misleading recorder timing are separate confirmed problems.

No gameplay code was changed for this review. Diagnostic scripts and logs live in the isolated temporary test project. The captures have `git_commit` and `git_branch` set to `unknown`, so their timestamps suggest, but do not prove, the precise build used.

## Live Capture Evidence

Overlapping incident windows were deduplicated by `t_usec`. Frame spacing below is the difference between adjacent timestamps within the same recorded window, not the recorder's `frame_ms`. These are incident-window statistics, not an unbiased full-session FPS average. Enemy counts are cached approximately every 0.5 seconds; the recorder does not identify paused/menu frames.

| Recorded population | Unique samples | Median spacing | p95 spacing |
| --- | ---: | ---: | ---: |
| Segment 2, 90-127 materialized enemies | 1,282 | 25.25 ms | 49.87 ms |
| Segment 3, 90-108 materialized enemies | 694 | 30.22 ms | 51.07 ms |

The segment 3 population band represents roughly 180-193 logical enemies, including data-only enemies. Those also participate in combat queries.

Two individual captures illustrate the problem:

- `performance_results/2026-09-15/2026-09-15_08-35-25_segment-02_incident-033.json`: median timestamp spacing 29.03 ms, p95 73.37 ms.
- `performance_results/2026-09-15/2026-09-15_08-40-18_segment-03_incident-060.json`: median timestamp spacing 22.73 ms, p95 49.27 ms.

The event stream switches to the Barrage route at `t_usec=167510055` and subsequently records BRC catastrophes and BRV revelations. The earlier 60-body Execution chain benchmark does not cover this workload. Existing Barrage tests check a wounded pair and individual mechanics, not dense-crowd timing.

## 1. Barrage Retargeting Bypasses the Attack Budget

Relevant code:

- `core/systems/ascension/engines/BarrageEngine.gd:468`: every fragment independently acquires a lowest-health target when spawned.
- `core/systems/ascension/engines/BarrageEngine.gd:489`: every active fragment is processed in one call. Fragments with dead/invalid targets repeat their radius and lowest-health search; pending fragments are admitted together.
- `core/systems/ascension/AscensionRunner.gd:358`: target selection gathers an array of nearby enemies and then checks their health individually.
- `core/systems/enemy_world/EnemyWorld.gd:613`: each radius query constructs candidate storage and handles, followed by another dying-target filtering pass in `EnemyCombatService.gd:318`.
- `core/systems/ascension/AscensionRunner.gd:1024`: all engine ticks run before `flush_attacks(ATTACK_BUDGET_PER_FRAME)`. The 12-attack budget applies to queued slash/impact attacks, not this fragment work.

Fragments selecting the same weakest enemy can all need a new search after that enemy dies. This multiplies candidate enumeration and health lookups during the chain itself.

### Isolated Reproduction

Godot 4.7.1, headless, current code copied into a separate project/save directory. Only `_tick_fragments` was timed. These dense synthetic cases omit rendering and materialized-enemy simulation; they are not a replay of the player's spatial distribution.

Two runs of a 180-body wounded crowd killed all 180 enemies and peaked at 343-347 live fragments. Fragment-update maxima were 40.84 ms and 38.12 ms. A 60-body version peaked at 4.85-5.76 ms; a deliberately excessive 360-body version exceeded 220 ms.

Controlled comparison against the same 180 high-health enemies, resetting fragment positions/lifetimes outside the timed section:

| Fragments | Target condition | Median fragment update | p95 |
| --- | --- | ---: | ---: |
| 120 | Retain valid target | 0.84 ms | 1.62 ms |
| 120 | Force reacquisition each update | 51.25 ms | 76.73 ms |
| 360 | Retain valid target | 1.32 ms | 2.11 ms |
| 360 | Force reacquisition each update | 149.44 ms | 161.54 ms |

The forced-reacquisition case is intentionally adversarial. It isolates acquisition cost; it does not mean every live frame performs that many searches. Both diagnostic runs exited successfully without reported runtime errors.

Reproduction files on this machine:

```text
C:/Users/NAURIS~1/AppData/Local/Temp/sa-ascension-fix-20260914-231340/tools/tests/BarrageCostProbe.gd
C:/Users/NAURIS~1/AppData/Local/Temp/sa-ascension-fix-20260914-231340/tools/tests/BarrageCostProbe.tscn
C:/Users/NAURIS~1/AppData/Local/Temp/sa-ascension-fix-20260914-231340/BarrageCostProbe.log
C:/Users/NAURIS~1/AppData/Local/Temp/sa-ascension-fix-20260914-231340/BarrageCostProbe-controlled.log
```

First optimization target: preserve the lowest-health/radius/exclusion rules while reducing repeated candidate-array construction and per-handle lookups. A data-side lowest-health query can inspect existing slot data directly. Test tie ordering, dying enemies, handle reuse, exclusions and reentrant kill callbacks before adopting shared scratch storage or caching. A bounded reacquisition scheduler is a separate gameplay-sensitive option, not something to slip in without checking behavior.

## 2. Current Recorder Cannot Attribute Combat Cost Reliably

`autoload/PerformanceFlightRecorder.gd:82` stores `_process(delta) * 1000` as real frame duration. Godot can cap and smooth gameplay delta, so it is not a wall-clock frame timer. Timestamp gaps in the captures expose the mismatch:

- Incident 002 has adjacent gaps of 5,303 ms and 1,405 ms during the first transition; corresponding recorded deltas are 18.06 ms and 76.80 ms.
- Incident 034 has transition gaps of 2,172 ms and 858 ms; recorded deltas are 61.81 ms and 71.81 ms.

The comments at `PerformanceFlightRecorder.gd:79` and `:213` also call `TIME_PROCESS` the previous frame's process step. In Godot 4.7, the engine publishes process/physics maxima approximately once per second. Process timing includes rendering synchronization/drawing, not just GDScript. Therefore `dominant_thread = process` does not establish that scripts caused the stall or rule out rendering. See [Godot's main loop](https://github.com/godotengine/godot/blob/4.7-stable/main/main.cpp#L4698-L4757) and [Node delta documentation](https://docs.godotengine.org/en/4.7/classes/class_node.html#class-node-private-method-process).

Additional missing context:

- The recorded `projectiles` count comes only from `ProjectileSimulationManager`; Barrage fragments are absent.
- No Barrage tick/acquisition time, retarget count, pending-fragment count, runner queue cost or rendering CPU/GPU timings are captured.
- Projectile timing already exists in `ProjectileSimulationManager.get_debug_counters()` but is not copied into the flight recorder.
- Chunk subphase timings already exist in `ChunkManager.get_chunk_stream_debug_stats()` but are not included in the incidents.
- `BuildInfo.gd` reads `.git/HEAD` directly. This linked worktree has a `.git` file, explaining its missing commit identity.

Recorder self-measurement was usually small, with occasional overhead approaching 9 ms. That is worth tracking but does not explain all sustained combat slowdown. Flow-worker correlation likewise does not prove or disprove CPU contention.

## 3. Streaming Still Produces Independent Hitches

Of 136 distinct recorded chunk creations, 117 exceeded 2 ms and 20 exceeded 16.7 ms, including initial loading. Examples after the initial transition:

| Capture | Chunk | Measured chunk creation | Enclosing timestamp gap | Cached enemies |
| --- | --- | ---: | ---: | ---: |
| Incident 008 | `(1, 2)` | 76.61 ms | 89.80 ms | 3 |
| Incident 007 | `(-3, 2)` | 33.80 ms | 56.69 ms | 1 |
| Incident 052 | `(-7, -4)` | 29.91 ms | 47.80 ms | 7 |

`ChunkManager.gd:337` builds a complete chunk synchronously; the 2 ms budget check at `:340` only stops subsequent chunks. It cannot interrupt one expensive activation. The existing audit uses a warmed seed/site and does not establish the cost of all first-use procedural chunks.

The loading card changes transition presentation, not load/teardown duration, and does not cover later streamed chunks. These are real secondary issues, but not a sufficient explanation for the user's mostly-in-combat lag.

## Next Verification

1. Add accurate timestamp spacing and direct combat subsystem timings to captures, including fragments, searches and queue backlog. Label the engine's windowed monitor values honestly.
2. Optimize and regression-test Barrage target acquisition, then repeat the dense-chain and retained/reacquired-target comparisons.
3. Run a rendered, stationary Barrage playtest with the same route and seed. Measure complete-frame p95/p99 and CPU/GPU costs; do not substitute the headless result for this test.
4. Profile individual chunk subphases and stage the expensive phase, then test cold chunks as well as warmed chunks.

No claim is made here that all remaining lag is explained or fixed.
