# Optimization handoff — enemy horde project (2026-08-22)

Read this first. It is the working context for the enemy-count optimization
effort on branch `enemy-world-work` (a sandbox branch; going wild is fine,
`main` is untouched).

## Goal

500–1000+ simultaneous enemies at playable frame times on desktop Linux.
The original game chugged at ~180 ("the 180 barrier" = spawn table
`max_alive_total = 180`). Secondary target: projectile-heavy builds
("minigun") must not tank the frame rate.

## Architecture (as of today)

- **Logical enemy population** lives in EnemyWorld (data records). Only
  ~64–96 enemies near the player are *materialized* as CharacterBody2D
  nodes (EnemyRepresentationPolicy, budget 64, ceiling 96); the rest are
  **data-only proxies**: no node, no physics, simulated by
  EnemyProxySimulation at 10Hz in 6 slices, steered by the flow field,
  hit via EnemyCombat's data-side segment/radius queries.
- **EnemySimulationScheduler** (autoload) tiers materialized nodes:
  FULL 60Hz / MID 20Hz / FAR 8.6Hz, budget + spatial bands with
  hysteresis, rank-incumbency bias, pressure tiers (physics >14ms
  sustained → budgets 24/24; >20ms → 16/16 + harder physics shedding).
  Smart archetypes release body physics beyond a distance that shrinks
  under pressure. Pausable (pause now freezes everything).
- **All enemy sprites render batched**: enemy nodes hide their Sprite2D
  and EnemyProxyRenderer draws everything through per-texture MultiMesh
  batches (proxies by handle, materialized actors by node transform with
  snapshot interpolation). Bullets were already MultiMesh.
- Spawning: PoolManager warm-up is budgeted per frame; dev force-spawn
  drains 12/frame through a queue.

## State: VERIFICATION PENDING

The last four fixes addressed batched-visual bugs found in desktop runs
(headless tests kept passing because they cannot see pixels):

1. 1px sprites → unit quad renders one pixel; scale = pixel size.
2. Upside down → quad UVs are Y-up, canvas is Y-down; Y basis negated.
3. Under the world → z_index 10 backstop (bullets 200, fog 1500) plus
   move-to-front computed at execution time (call_deferred captures args
   at schedule time — trap).
4. **"Mostly invisible" (root cause, high confidence): missing
   `emit_changed()` after multimesh buffer uploads — the canvas item
   keeps a stale culling rect at the world origin, so batches culled as
   the camera roams.** The projectile renderer already carried this
   lesson (ProjectileSlotReuseTest asserts it).

**First task of the next session: have the user roam far from spawn and
confirm enemies stay visible.** If not, debug rendering with
tools/tests/RenderChainProbe.tscn (runs the real game headless and
asserts registration/instances/layering) and remember headless cannot
verify culling — only the user's screen can.

## Measured results so far (benchmark reports in performance_results/benchmarks/)

- Desktop (user's machine): 120 & 250 enemies locked 60fps; 400 → p95
  20.4ms; **550 → p95 31.5ms (goal ≤33 met)**; chaos test 1129 alive →
  p95 42ms.
- Headless CPU: 550 alive → p95 13.8ms; 619 alive earlier at 8.2ms avg.
- Draw calls collapsed from ~2600 (250 enemies, pre-batching) to ~200–700.
- Physics catch-up cap (project.godot, max 4 steps/frame) closed the
  "unaccounted frame time" death spiral (130ms frames with 42ms of
  measured work). Frames now ≈ sum of measured work.

## TODO (in order)

1. Verify enemy visibility everywhere (see above), plus smoothness
   (snapshot interpolation) and the emergency pressure tier under hordes.
2. Complete a desktop benchmark run (battery died mid-run last time);
   reports self-save to performance_results/benchmarks/.
3. Minigun: rerun projectile stress AFTER the catch-up cap; if frames
   are still bad, next suspect is per-hit impact VFX
   (ProjectileSimulationManager spawns a node per impact,
   scene.add_child(impact)). Overdraw was likely NOT the issue (bullets
   are tiny additive quads, draws stayed low).
4. Rapier 2D physics A/B (godot.rapier.rs) — biggest remaining physics
   lever (30ms p95 at ~90 bodies); third-party binary, may change
   move_and_slide feel; needs user's go-ahead.
5. p99 hitch tagging if tails persist after the catch-up cap.
6. Design decisions for the user: (a) proxies near the player deal no
   contact damage until materialized (raise materialized_budget 64→96?);
   (b) summoner summons bypass every population cap and can snowball
   550 → 1129.
7. GDExtension (Rust/C++) for proxy sim + batch fill hot loops — only if
   2000+ becomes a real goal.
8. **`git push --force-with-lease origin enemy-world-work` is STILL
   PENDING** (user must run it in the VS Code terminal — this shell has
   no GitHub credentials; SSH keys on this machine are not registered
   with GitHub). History was rewritten today (Co-Authored-By strippage)
   after an earlier push, hence the force. ~35 commits are local-only.

## Gotchas learned today (do not relearn these)

- Godot binary: `~/Downloads/Godot_v4.7.2-stable_linux.x86_64` (not on
  PATH). Never run it while the user is playtesting.
- Tests: `<binary> --headless --path . res://tools/tests/<Name>.tscn`;
  two summary formats ("N passed, M failed" and "passes=N failures=M");
  some tests are SceneTree scripts run via `--script`. Full-game tests
  must dismiss the run-start augment selection (it pauses the tree;
  headless nobody clicks). See DevForceSpawnTest for the pattern.
- The flight recorder re-arms only after recovered frames: sustained
  slowness records almost nothing. The benchmark writes its own reports.
- Captures live in performance_results/YYYY-MM-DD/ (auto day folders);
  days 19–21 are gitignored locally. Analyzer:
  `python3 tools/perf/analyze_captures.py --group session`.
- 2D MultiMesh: unit quad = 1px; Y-up UVs; needs emit_changed after raw
  buffer writes; no get_global_transform_interpolated for 2D in this
  build; project physics_interpolation is OFF.
- call_deferred evaluates arguments at schedule time.
- No AI attribution in commits (no Co-Authored-By).
- Dev overlay (PerformanceOverlay): god mode, pause-game toggle, force
  spawn +1/+10/+100, population caps (typing a cap auto-switches to
  Custom), batched-sprites toggle, real ENEMIES count (logical + split).
