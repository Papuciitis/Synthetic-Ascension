# Optimization handoff — enemy horde project (2026-08-22)

> **Superseded (2026-08-30):** direction and priorities now live in
> `docs/SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md` (§24 near-term roadmap,
> §27 status log). The figures below are as of 2026-08-22/23 and several have
> moved since; dated corrections are inline. Still-open backlog items are
> labelled in the "Audited but NOT implemented" list.

> 2026-08-23 note: a full-project design/bug audit and fix session
> happened on top of this (see "Design audit session" at the bottom).

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
  hysteresis, rank-incumbency bias, pressure tiers (2026-08-30: physics >14 ms
  sustained → budgets 12/24; >20 ms → 8/16 + harder physics shedding;
  >40 ms → a severe fast path — `autoload/EnemySimulationScheduler.gd:46-47,59-60,86`).
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

1. Minigun remainder (SOLVED down to 34ms — two root causes found
   2026-08-23): (a) the projectile sim ran in _physics_process while
   being physics-server-free; whenever the physics step exceeded
   16.7ms, catch-up ran it 2–4× per rendered frame. Moved to _process:
   torrent-only 38.6→23.6ms avg, massacre p95 68.7→38.9ms. (b) The
   "unattributed draws" were leftover loot drops from kills
   accumulating across benchmark stages — swept between stages now;
   draws sit at ~200 in every stage. Remaining cost is honest work:
   ~24ms process (GDScript _simulate_one at 550 bullets ≈ the
   GDExtension candidate) + ~15ms physics (bodies) in the massacre.
   Frame time now equals measured work; render thread measured
   directly (viewport_get_measured_render_time_*): cpu ~1.5ms,
   gpu ~5ms — rendering is NOT a bottleneck.
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
  PATH). Never run it while the user is playtesting. (2026-08-30: the
  user's desktop benchmarks run on Windows through
  `tools/perf/run_benchmarks.ps1`, Godot 4.7.1; the Linux 4.7.2 binary
  remains the headless-suite convention.)
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
- No AI attribution in commits (no Co-Authored-By). (The rule stands;
  a batch of Aug 23-27 commits violated it before it was enforced.)
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
  census in MinigunStressBenchmark tallies the FULL tree by script to
  attribute node churn. Enemy dossier cards are now spaced: min 6s of
  unpaused play between them (TutorialModalController), first card
  immediate, scripted non-enemy cards never delayed.
- ~74 enemy.gd nodes exist with ZERO alive — that's the PoolManager
  warm pool, NOT lingering corpses. Don't misread census counts.
- The ~243 ObjectDB instances "leaked at exit" are load-time resource
  cycles (GDScript/PackedScene/CompressedTexture2D preload cycles);
  the count is IDENTICAL for a minimal probe and a 100s spawn-heavy
  run — static, harmless, not worth chasing. Real leak hunts should
  watch OBJECT_NODE_COUNT during play instead (it stays flat).
- Teleporting enemies: write EnemyWorld records (set_position +
  reset_interpolation) AND the actor node; node-only moves leave stale
  records the representation policy acts on.
- TIME_PHYSICS_PROCESS reports ONE step; under catch-up the frame runs
  up to 4. A frame-vs-measured-work gap with normal render times means
  multiple physics steps, not hidden render cost.
- SceneTree `--script` tests: do NOT preload gameplay scripts at parse
  time (they compile before autoloads register and spam compile errors;
  load() inside _run instead). Walkability/spawn probes must first wait
  for chunk streaming (poll is_cell_walkable on the start cell), and
  headless frames run uncapped - N process_frames is NOT N/60 seconds;
  use create_timer for timer-driven systems like spawning.
- is_cell_walkable() requires a streamed chunk record. Anything that
  builds a world must call ChunkManager.start_streaming() or spawning,
  nav snapshots and checkpoint validation all silently die (this is
  exactly how Segment 1 broke after the 08-17 rearchitecture).

## Design audit session (2026-08-23, autonomous)

Eight parallel auditors mapped every subsystem against the design brief
(horde roguelite: ascension, exploration, buildcraft, systemic Luck,
pressure). ~15 commits landed, each independently revertable. Full
suite green before and after (plus new ScriptParseAuditTest covering
all 253 gameplay scripts — 372 non-tools scripts as of 2026-08-30).

Landed (highlights):
- Damage numbers (BattleText autoload, batched single canvas item,
  merge-by-handle, crit gold, player-damage red, accessibility toggle).
- Luck is systemic now: drop chance, lucky crits (1.5x, all styles),
  lucky evasion, extra follower gain, exploration loot chance — plus
  the roll_signed_range fix (high Luck used to make NEG rolls MORE
  severe, and the quality shift was halved).
- Followers: belief feeds Power (+1%/sqrt follower, cap 15%); leech
  drain no longer ticks through pause; vendor warns before trading
  below reconstruction cost; undo goes through the ledger.
- Resonance (proc): ambient only after primary; wardstones +6%,
  secondaries +5%; public bar clamps at 99.8% while the gate is
  actually blocked (kills false GATE READY / overtime / EVAC).
- Three new augments: Lucky Charm (+Luck), Cult of Personality
  (kills recruit), Corruption Engine (equipped NEG severity -> Power,
  first real NEG-exploit payoff).
- Fixes: ThreatDirector reset on same-segment death; augment picker
  duplicate/overwrite; Hex Blink for all styles; Reflect Shield vs
  simulated bullets (new manager consume API); splitter heir cull
  protection; loot magnet + pickup latch fixes; indoor encounter
  culled-abort; miniboss/secondary chunk collision; checkpoint restore
  in proc segments; Exit Rite dead-channel guard; triple-quote .tres
  parse bug (7 of 8 augment descriptions were empty in-game); debug
  hygiene (title typo, dev panels gated to debug builds, log spam).
- UI: vendor status no longer clobbered same-frame (+ EXCHANGE
  COMPLETE), threat tooltip in player language, gate arrow distance
  ("142m"), set rows use display names/max pieces, Ctrl-lock in the
  run bag, descriptions for all 18 set-piece items.

Audited but NOT implemented (backlog, roughly by value):
1. Vendor stock quality: LuckResolver.vendor_stock_bonus is wired
   through threat_level and near-no-op; make it bump the rarity band.
   (Still true 2026-08-30: `HubShop.gd:1428` only bumps threat_level.)
2. Segment 1 never advances ThreatDirector segment_phase (recon damp
   flattens the authored endgame) — mirror milestone->phase at
   COURTYARD/OUTER_APPROACH/EXIT_RITE. Tuning-sensitive.
3. spawn_burst bypasses the per-tick spawn construction budget
   (spawner.gd:668) — route through _force_spawn_queue.
   (Still true 2026-08-30: `spawn_burst` loops `_spawn_one` directly,
   `spawner.gd:654-690`.)
4. Proxy deaths pay followers but never drop items/health (asymmetric
   with node kills) — decide, then implement or document.
5. Continue mid-proc-segment can leave a ghost alley-cache secondary
   (claim_loot fires at spawn, not pickup) and resets resonance.
6. Augment cards don't label upgrades (picking an owned augment now
   levels it up, but the card looks identical).
7. AugmentData.grant_spell_id and EnemySpec.drop_instance_roll are
   dead exported fields; positive_probability clamps unreachable;
   augment_quality_bonus has no consumer (no quality axis on offers).
   (Still true 2026-08-30: grant_spell_id unread, drop_instance_roll
   only assigned, augment_quality_bonus callerless —
   `core/systems/items/LuckResolver.gd:57`.)
8. "Interact" is rebindable in Settings but nothing reads it.
   (Done 2026-08-30: `ExitRite.gd:597` reads `&"interact"`.)
9. Level1 loot rooms have full secondary plumbing but never surface
   as secondaries. Vendor hover "(R5 POS)" shorthand.
10. Heat valley: ascension phase floor 0.48 erases the authored
    70-90% dip (0.35) — pick one owner.
    (Still true 2026-08-30: `ThreatDirector.gd:458` `maxf(heat, 0.48)`
    vs `heat_at_90 = 0.35`.)

## Direction rulings (2026-08-23, designer)

(Executed — 1 done in the story pass below, 2 Run Sheet `34cbdd2`, 3 NEG
slice `c8d5af8`/`7c894f3`; superseded by the direction doc §24/§27. Kept as
history — 2026-08-30.)

Project state: **no longer missing systems — missing authored game.**
Priority order for the next pushes (designer's ordering):

1. **Segment 1 spatial + story pass** — treat as a FULL level redesign,
   not "bigger tutorial map": normal institution → something wrong →
   incident → first confrontation → lethal escalation → hostile
   building → first build choice → transition out → city reveal →
   outer objective/Exit Rite. Build the final **Exit Rite
   LOCKED/LOCATED/READY checklist UI during this pass** (not before —
   the layout may change what the gate requires; not backlog either).
2. **Run Sheet expansion** — during/after the Segment-1 pass, informed
   by its playtests. One screen, three questions: "What am I?",
   "What is my build doing?" (show REASONS: "Corruption Engine — 184%
   from top 2 → +22.1% Power", "Equilibrium — 3 POS / 3 NEG — ACTIVE"),
   "What has this run done?". No tax return, no ten tabs.
3. **NEG vertical slice** — Doctrine of Burden + Inversion Lens +
   3 deep-curse items (with shipped Corruption Engine that tests three
   opposed valuations of the same loot: make it worse / make it safer /
   find the worst thing imaginable). Only after that plays well:
   Equilibrium, Litany, Gambler, Gravemarch.
   **Deep curses are NAMED, recognizable items** — never a global
   widened NEG band; players must learn "oh FUCK, that's the one".
4. **#27 persistent three-slot system: SUPERSEDED BY AUGMENTS** —
   intentionally retired (augment slots + levels + archetypes inherited
   its job). Revisit only if playtests show runs lack player-controlled
   direction.
5. More city/content variety, then the smaller system backlog.
   The milestone after Segment 1: "can I play three runs and get three
   noticeably different stories/build trajectories?"

Also ruled: threat/roster escalation should eventually blend progress
state with wall-clock (baseline pressure from time, roster phases from
objectives/story milestones) — but TEST it inside the new Segment 1,
not against temporary geography. Performance headroom (665 @ p95
29.6ms) is a design unlock for variety/spectacle, not a mandate to
chase 1000.

Fixed on report: ring/offhand effects ignored rarity (only Regen Ring
scaled) — all four accessory effects now scale via the shared
continuous potency curve with rate-stat guardrails.

## Segment 1 story pass session (2026-08-23, autonomous, later same day)

Priority 1 of the rulings executed. Design in
docs/design/SEGMENT1_STORY_PASS.md (with landed-status header); ~12
commits, each independently revertable, suite green throughout, plus a
windowed rendered-pixels probe (tools/tests/Segment1StoryProbe.tscn,
pattern of RoamVisibilityProbe).

Landed:
- Ten-beat arc: NEW admissions wing (normalcy + ward-flicker beats, new
  ADMISSION opening phase, entrance start for full-prologue runs), the
  existing incident/confrontation/escalation beats untouched, escape
  re-armed (below), first build choice moved INTO the level (evidence
  store 3-B beat before the security fight, with the tutorial-modal
  pause contract), city-reveal camera beat past the breach (zoom-out
  over a new backdrop strip), Exit Rite finale with the checklist.
- Exit Rite checklist UI (per ruling, built during the pass):
  structured RunEvents.gate_checklist_changed + HudGateChecklistController
  panel; both builders emit it; proc objective text un-flattened.
- Backlog #2 fixed: spawn stages mirror into ThreatDirector phases
  (single choke point, restore-safe). Segment 1 finally escapes the
  recon damp; plaza now runs collapse. TUNING-SENSITIVE - playtest.
- Backlog #9 fixed: the three service rooms are tracked secondaries
  (guaranteed payout, announce/complete, warehouse local encounter).
- MAJOR pre-existing regression found and fixed: Segment 1 never called
  start_streaming after the 08-17 rearchitecture - zero chunk records,
  so is_cell_walkable() was false everywhere: NO ambient spawns and no
  flow-field walkability in the whole segment. Also fixed the two bugs
  that surfaced behind it: the authored spawn filter was dead code
  (shared variable with the debug autoload), and the facility-wide
  IndoorVolume would have rejected all indoor spawns (new
  ambient_spawn_excluded flag).
- SEGMENT1_LAYOUT_VERSION 3, OPENING_SEQUENCE_VERSION 2 (+ phase-int
  migration; dev phase-jump buttons renumbered).
- New tests: Segment1ProgressionTest (40 checks: phases, filter,
  secondaries, checklist states, wing geometry, start rules).

Needs human eyes (in priority order): opening walk pacing + copy tone,
reveal camera feel, evidence-offer placement under SERVICE pressure,
phase-mirror difficulty lift, checklist panel layout at 1080p.

## Playtest bug-fix session (2026-08-23, after the user's segment 1+2 run)

User verdict on the story pass: likes it ("feels more like tutorial
level"). Perf held: p95 30.6ms / p99 37ms, 0.08% >50ms in their run.
Four reported bugs root-caused (parallel investigation) and fixed, each
its own commit, pinned by tools/tests/PlaytestRegressionTest.tscn:
- Spawn blink at last kill's position: LIFO pool reuse + the f2dfcf5
  idempotency guard left the batch renderer's interpolation snapshot at
  the death transform. reset_actor_snapshot on reuse + record-side
  reset_interpolation after spawn positioning.
- Dossier cards late/mismatched: enemy_archetype_encountered only fired
  in _ready, which warmed nodes run silently - cards appeared when a
  pool ran DRY. Now re-emitted (deferred) on every pool obtain.
- Hub duplicate augments: quick-equip had no already-equipped check
  (drag path swapped). No-op now; set_permanent_augment enforces
  one-slot-per-id; save load heals corrupted arrays.
- Vendor rarity bump on sell: vendor stock is a BagInventory, so the
  buyback set_at ran K6 consolidation and FED the vendor's copy. New
  BagInventory.auto_consolidate flag, false on all vendor paths.
- r0-bag/r1-equipped splits: K6 merging was container-local. Instance
  pickups + deliver_guaranteed_item now feed the equipped copy;
  equipping a duplicate MERGES instead of swapping (both routes), so
  diverged saves can be consolidated by hand. DECISION for designer:
  shop BUYS still go to the bag (merging inside the shop would break
  the trade-undo snapshot contract - ItemInstance.gd:27-29).
Deliberately NOT done: lighting/music/fade systems (do not exist),
wall-clock threat blending (ruled: test inside new Segment 1 first),
segment-1 bosses, heat-valley ownership (#10).
