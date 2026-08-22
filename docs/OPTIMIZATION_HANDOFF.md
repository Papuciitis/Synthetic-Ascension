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

## State: VISIBILITY VERIFIED (2026-08-22, late session)

The culling fix is confirmed with real rendered pixels: Claude ran the
game windowed on DISPLAY=:0 (Intel UHD 620) via
tools/tests/RoamVisibilityProbe.tscn — spawns a horde, teleports the
player to ±10–20k px from origin, screenshots each stop
(ROAM_SHOT_DIR env), auto-dismisses first-encounter tutorial cards.
Enemies render correctly at every stop; batches follow the camera.
Screenshot verification no longer needs the user: windowed runs +
viewport captures work whenever a display session exists (never run
while the user is playtesting).

Historical context (the four fixes that led here): 1px sprite scale,
Y-basis negation, z_index backstop (EnemyProxyRoot z=10; probe prints
batch-relative z=0 — that's normal), and the emit_changed()-after-
buffer-upload culling fix.

## Measured results so far (benchmark reports in performance_results/benchmarks/)

- Desktop (user's machine): 120 & 250 enemies locked 60fps; 400 → p95
  20.4ms; **550 → p95 31.5ms (goal ≤33 met)**; chaos test 1129 alive →
  p95 42ms.
- Desktop FULL run 2026-08-22 23:23 (battery survived): 120 locked;
  250 → p95 22.2; 400 → p95 25.0; **550 → p95 31.7 (goal still met)**.
- Minigun stress (MinigunStressBenchmark, desktop): pre-fix massacre
  stage (250 enemies + 550-bullet torrent) 66ms avg / 620 draws. After
  batching impact VFX into one MultiMesh: 45–49ms avg / ~280 draws;
  impacts-on now identical to impacts-off (impact cost ≈ 0).
- Headless CPU: 550 alive → p95 13.8ms; 619 alive earlier at 8.2ms avg.
- Draw calls collapsed from ~2600 (250 enemies, pre-batching) to ~200–700.
- Physics catch-up cap (project.godot, max 4 steps/frame) closed the
  "unaccounted frame time" death spiral (130ms frames with 42ms of
  measured work). Frames now ≈ sum of measured work.

## TODO (in order)

DONE today (late session): visibility verified everywhere (roam probe);
full desktop benchmark completed (550 p95 31.7, goal met); minigun
stress harness built + impact VFX batched (impact cost now ~0); the
pending force-push happened (branch is in sync with origin).

1. Minigun remainder: massacre stage is still ~45–49ms avg with impacts
   at zero cost. Measured shares (immortal isolation): death+respawn
   churn ~12ms; per-hit pipeline + torrent churn ~19ms over plain-horde
   baseline; projectile physics sim alone is ~20ms at 550 live bullets
   with ZERO enemies (stage 0) — per-tick GDScript cost of
   _simulate_one (chunk raycast + segment queries), the prime
   GDExtension/optimization candidate. Also ~+60–90 draws in stress
   stages remain unattributed (not impacts, not node counts —
   candidates: SFX-triggered canvas? knockback flashes? dig via census
   + draw stepping).
2. Smoothness (snapshot interpolation) and emergency pressure tier
   still deserve a human-eyes pass during real play.
3. Rapier 2D physics A/B (godot.rapier.rs) — biggest remaining physics
   lever (30ms p95 at ~90 bodies); third-party binary, may change
   move_and_slide feel; needs user's go-ahead.
4. p99 hitch tagging if tails persist after the catch-up cap.
5. Design decisions for the user: (a) proxies near the player deal no
   contact damage until materialized (raise materialized_budget 64→96?);
   (b) summoner summons bypass every population cap and can snowball
   550 → 1129.
6. GDExtension (Rust/C++) for proxy sim + batch fill + projectile sim
   hot loops — projectile sim just earned its place on this list (see
   TODO 1).

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
- Windowed runs on the user's desktop work from this shell: DISPLAY=:0,
  real GPU, viewport screenshots readable by Claude. First-encounter
  tutorial cards (TutorialCardOverlay) dim the screen during probes —
  sweep-dismiss them via node.call("_dismiss") each frame (see
  RoamVisibilityProbe/MinigunStressBenchmark).
- A new `class_name` is NOT resolvable in direct (non-editor) runs until
  the editor rebuilds the global class cache — reference new scripts by
  preload() path instead (bit us with ImpactBurstRenderer).
- Force-spawned hordes trigger first-encounter cards + massive drops;
  census in MinigunStressBenchmark tallies scene-root children by
  script to attribute node churn.
