# Enemy Simulation Budget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bound expensive enemy physics independently of total horde size so the current game can recover stable frame time and later scale beyond 500 living enemies.

**Architecture:** Add one scheduler autoload that assigns a fixed number of ordinary ambient enemies to full and mid simulation while treating the remainder as cheap far proxies. Reuse `EnemyIndex` as the only registry/spatial hash, split enemy simulation from per-node callbacks, shed flow-build work under physics pressure, and reuse only enemies that pass an explicit pool-reset contract.

**Tech Stack:** Godot 4.7.1, typed GDScript, SceneTree autoloads, existing headless test scenes, `PerformanceFlightRecorder`.

**Spec:** `docs/superpowers/specs/2026-08-18-enemy-simulation-budget-design.md`

## Global Constraints

- The scheduler must assign every valid actor exactly once even with 500+ ordinary enemies.
- Ordinary full and mid budgets default to 32 and 48; protected actors are additional and always full.
- Bosses, minibosses, elites, objectives, tutorials, active authored encounters, never-cull actors, and committed snipers retain full behavior.
- Projectile damage ordering, leech contact behavior, drop probabilities, and spawn balance do not change.
- `EnemyIndex` remains the only enemy registry and spatial hash.
- Existing uncommitted developer-segment and warning-cleanup changes are user work and must not be overwritten or included in feature commits.
- Production population caps remain unchanged until runtime recorder evidence supports raising them.

---

### Task 1: Deterministic scheduler assignment for 500+ enemies

**Files:**
- Create: `autoload/EnemySimulationScheduler.gd`
- Create: `autoload/EnemySimulationScheduler.gd.uid` (Godot-generated if created by the parser)
- Create: `tools/tests/EnemySimulationSchedulerTest.gd`
- Create: `tools/tests/EnemySimulationSchedulerTest.tscn`
- Modify: `project.godot:17-35`

**Interfaces:**
- Produces: `compute_assignment(enemies: Array, player_position: Vector2) -> Dictionary`, mapping instance ID to tier `0`, `1`, or `2`.
- Produces: `refresh_assignments() -> void`, `get_debug_counters() -> Dictionary`, and `is_under_physics_pressure() -> bool`.
- Consumes later: enemies may provide `is_simulation_protected(distance: float)`, `simulation_priority(player_position: Vector2)`, and `set_scheduler_tier(tier: int)`; Task 1 must fall back safely when these methods do not yet exist.

- [ ] **Step 1: Write the failing scheduler tests**

Preload the real scheduler script and create 500 real `Node2D` candidates. The
script deliberately has no `class_name`, because its production singleton uses
the same `EnemySimulationScheduler` name. Hand-check these behaviors:

```gdscript
func _test_500_actor_budget() -> void:
    var scheduler_script := preload("res://autoload/EnemySimulationScheduler.gd")
    var scheduler := scheduler_script.new()
    scheduler.full_budget = 32
    scheduler.mid_budget = 48
    var enemies: Array = []
    for index in range(500):
        var enemy := Node2D.new()
        enemy.position = Vector2(float(index), 0.0)
        add_child(enemy)
        enemies.append(enemy)
    var assignment := scheduler.compute_assignment(enemies, Vector2.ZERO)
    _check(assignment.size() == 500, "500-actor assignment loses no enemies")
    _check(_tier_count(assignment, 0) == 32, "full tier obeys hard budget")
    _check(_tier_count(assignment, 1) == 48, "mid tier obeys hard budget")
    _check(_tier_count(assignment, 2) == 420, "remaining actors become far proxies")
```

Add a protected fixture using metadata/group fallbacks and assert two protected actors are tier 0 while ordinary tier-0 count remains exactly 32. Add a stable-order test where equal-distance actors retain their previous tier ahead of newly promoted actors.

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tools/tests/EnemySimulationSchedulerTest.tscn
```

Expected: parse/load failure because `EnemySimulationScheduler` and its API do not exist.

- [ ] **Step 3: Implement minimal deterministic assignment**

Implement exported `full_budget = 32`, `mid_budget = 48`, `assignment_interval = 0.20`, `mid_group_count = 2`, `far_group_count = 6`, and `physics_pressure_ms = 8.0`. Filter invalid, dead, queued, or non-tree nodes; split protected and ordinary actors; sort ordinary actors by priority, previous-tier stickiness, squared distance, then instance ID; assign exactly the budgeted counts. Never use the current spawner cap in this calculation.

Register the autoload directly after `EnemyIndex`:

```ini
EnemySimulationScheduler="*res://autoload/EnemySimulationScheduler.gd"
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the Task 1 command. Expected: all budget, protection, stability, and 500-actor assertions pass with exit code 0.

- [ ] **Step 5: Commit Task 1 only**

```powershell
git add -- project.godot autoload/EnemySimulationScheduler.gd autoload/EnemySimulationScheduler.gd.uid tools/tests/EnemySimulationSchedulerTest.gd tools/tests/EnemySimulationSchedulerTest.tscn
git commit -m "perf: bound full enemy simulation assignments"
```

---

### Task 2: Tier transitions, reduced tick groups, and physics eviction

**Files:**
- Modify: `core/actors/enemy/enemy.gd:36-535`
- Modify: `core/actors/enemy/enemy.tscn:13-39`
- Modify: `autoload/EnemySimulationScheduler.gd`
- Modify: `autoload/EnemyIndex.gd:125-165`
- Modify: `tools/tests/EnemySimulationSchedulerTest.gd`
- Modify: `tools/tests/PerformanceLifecycleTest.gd:105-145`

**Interfaces:**
- Produces on `EnemyActor`: `set_scheduler_tier(tier: int)`, `run_scheduled_simulation(delta: float)`, `is_simulation_protected(distance: float)`, `simulation_priority(player_position: Vector2)`, `is_body_physics_enabled()`, and `hitbox_roles() -> Dictionary`.
- Consumes from Task 1: scheduler assignments and rotating mid/far groups.
- Preserves: `simulation_tier()` for recorder and existing tests.

- [ ] **Step 1: Add failing transition and scheduling tests**

Instantiate the real enemy scene, await `_ready`, and assert observable state:

```gdscript
enemy.set_scheduler_tier(2)
await get_tree().physics_frame
_check(not enemy.is_physics_processing(), "far actor has no individual physics callback")
_check(not enemy.is_body_physics_enabled(), "far actor leaves body physics")
_check(enemy.hitbox_roles() == {"monitoring": false, "monitorable": false}, "far hitbox leaves broadphase")

enemy.set_scheduler_tier(1)
await get_tree().physics_frame
_check(not enemy.is_physics_processing(), "mid actor is manager scheduled")
_check(enemy.is_body_physics_enabled(), "mid actor retains reduced world collision")
_check(enemy.hitbox_roles().monitorable, "mid actor remains hittable")
```

Add an ordinary chase assertion that `monitoring == false`, a leech assertion that full/mid `monitoring == true`, and a protected-actor assertion. Add scheduler-step counters proving 12 physics frames call a mid actor 6 times and a far actor 2 times while passing accumulated deltas near `2/60` and `6/60` respectively.

- [ ] **Step 2: Run focused tests and verify RED**

Run both scheduler and lifecycle scenes. Expected: missing tier-transition methods or current hitbox/callback behavior fails the new assertions.

- [ ] **Step 3: Extract the enemy simulation step**

Keep `_physics_process(delta)` as a thin full-tier entry point:

```gdscript
func _physics_process(delta: float) -> void:
    if _lod_tier != 0:
        return
    _run_simulation_step(delta, true)

func run_scheduled_simulation(delta: float) -> void:
    if _lod_tier == 0 or dead:
        return
    _run_simulation_step(maxf(delta, 0.000001), _lod_tier == 1)
```

Move the existing gameplay body into `_run_simulation_step`. Remove the old per-enemy interval gate from the hot entry path; preserve compatibility helpers only for older tests/callers.

- [ ] **Step 4: Implement atomic tier state transitions**

Cache the body `CollisionShape2D` and hitbox. `set_scheduler_tier` must clamp to `0..2`, enable the individual callback only for tier 0, defer body-shape disable for tier 2, split hitbox monitoring from monitorability, refresh steering caches, and reset physics interpolation when returning from far proxy state.

`is_simulation_protected` must mirror the existing retirement exceptions and committed-sniper rules. Only leech AI actively monitors its hitbox; ordinary full/mid actors are monitorable but not monitoring.

- [ ] **Step 5: Implement rotating manager ticks**

On each assignment refresh, build two mid arrays and six far arrays using stable instance-ID modulo. Each physics frame processes one group from each tier with `delta * group_count`. Validate the actor and its current tier before calling it. Measure scheduler CPU microseconds and update debug counters without allocating per actor per frame.

- [ ] **Step 6: Keep `EnemyIndex` exact for proxy motion**

Continue calling `EnemyIndex.update_enemy` after every scheduled proxy move. Make `simulation_tier_counts()` ignore invalid, dead, and queued actors so recorder counts do not retain recycled/dead nodes.

- [ ] **Step 7: Run focused tests and verify GREEN**

Expected: budget, protection, callback, hitbox, physics-membership, tick-frequency, accumulated-delta, and lifecycle assertions all pass.

- [ ] **Step 8: Commit Task 2 only**

```powershell
git add -- core/actors/enemy/enemy.gd core/actors/enemy/enemy.tscn autoload/EnemySimulationScheduler.gd autoload/EnemyIndex.gd tools/tests/EnemySimulationSchedulerTest.gd tools/tests/PerformanceLifecycleTest.gd
git commit -m "perf: schedule reduced enemies outside the scene tree"
```

---

### Task 3: Flow-field double buffering and pressure-aware budget

**Files:**
- Modify: `core/systems/world/FlowFieldNav.gd:8-340`
- Modify: `tools/tests/PerformanceRootCauseFixTest.gd:20-40`
- Create: `tools/tests/FlowFieldLoadSheddingTest.gd`
- Create: `tools/tests/FlowFieldLoadSheddingTest.tscn`

**Interfaces:**
- Produces: `current_build_budget_ms() -> float`, `debug_active_generation() -> int`, and completed-field reads that remain stable during a replacement build.
- Consumes: `/root/EnemySimulationScheduler.is_under_physics_pressure()`.

- [ ] **Step 1: Write failing flow tests**

Use a small deterministic fake `ChunkManager` scene dependency with fixed walkability. Complete one field, record `sample_cost` and generation, request another field, advance only one partial build step, and assert the first generation and sample remain active. Force scheduler pressure through a supported test override and assert the chosen build budget changes from `1.50` to `0.50` ms without cancelling `_building`.

- [ ] **Step 2: Run flow tests and verify RED**

Expected: missing active-generation/budget API or sampling changes as soon as the partial build starts.

- [ ] **Step 3: Separate active and build buffers**

Keep active stamp/distance/direction/origin arrays read-only during construction. Build into the inactive buffer and atomically swap buffers plus origin/revision only when the BFS finishes. Walkability and penalty scratch buffers remain build-local and reusable. A cancelled nav-revision build discards only inactive data.

- [ ] **Step 4: Add pressure-aware time budget and revision debounce**

Add exported `pressured_ms_per_frame = 0.50` and `nav_revision_debounce = 0.20`. `current_build_budget_ms()` returns the reduced value only while the scheduler reports pressure. Repeated revisions replace one pending revision/cell and restart at most once after the debounce window.

- [ ] **Step 5: Run flow and existing root-cause tests; verify GREEN**

Expected: completed field remains readable, active build stays active under budget changes, revision requests coalesce, and prior flow behavior passes.

- [ ] **Step 6: Commit Task 3 only**

```powershell
git add -- core/systems/world/FlowFieldNav.gd tools/tests/PerformanceRootCauseFixTest.gd tools/tests/FlowFieldLoadSheddingTest.gd tools/tests/FlowFieldLoadSheddingTest.tscn
git commit -m "perf: preserve flow fields while shedding build load"
```

---

### Task 4: Bounded, fail-closed ambient enemy pooling

**Files:**
- Modify: `autoload/PoolManager.gd`
- Modify: `core/systems/spawner/spawner.gd:250-340,765-790`
- Modify: `autoload/EnemyIndex.gd:70-125`
- Modify: `core/actors/enemy/enemy.gd`
- Modify: `core/actors/enemy/modules/EnemyInit.gd`
- Modify: `core/actors/enemy/modules/EnemyLifecycle.gd:65-140`
- Create: `tools/tests/EnemyPoolTest.gd`
- Create: `tools/tests/EnemyPoolTest.tscn`

**Interfaces:**
- Produces on `PoolManager`: `set_limit_for_scene(scene: PackedScene, limit: int)`, `pool_size_for_scene(scene: PackedScene) -> int`, and `get_debug_counters() -> Dictionary`.
- Produces on `EnemyActor`: `can_pool_as_ambient() -> bool`, `_on_pool_recycle()`, `_on_pool_obtain()`, and `despawn(reason: StringName = &"death")`.
- Consumes: existing `PoolManager.obtain`/`recycle`, with a bounded return contract.

- [ ] **Step 1: Write failing pool lifecycle tests**

Obtain a real ordinary enemy scene, mutate HP, elite flag, velocity, stun, knockback, metadata, tier, hitbox roles, visibility, and add a real `BurnDot`. Recycle and obtain again. Assert the same instance is reused only for an eligible ordinary actor and all mutable state returns to scene/spec defaults before collision becomes active. Assert it is registered exactly once in `EnemyIndex` and assigned by the scheduler.

Set the per-scene limit to 2, recycle 3 eligible instances, await a frame, and assert pool size is 2 while the third instance is freed. Assert elites and `special_spawn_kind` actors are freed rather than pooled.

- [ ] **Step 2: Run the pool test and verify RED**

Expected: enemies lack reset hooks, the generic pool is unbounded, or stale state survives reuse.

- [ ] **Step 3: Bound the existing generic pool**

Add per-key limits and counters. `recycle` calls the node hook, but if the pool already reached its key limit it frees the node after the hook instead of retaining it. Preserve existing projectile behavior by leaving their default limit unbounded unless configured; configure common enemy scene keys to 32 through the spawner.

- [ ] **Step 4: Implement the enemy reset contract**

Extract spawn initialization from `_ready` into an idempotent reset that clears dynamic DOT children, transient metadata, dead/stun/knockback/speed timers, module state, telegraphs, elite state, scale, physics tier, and cached navigation state. Reapply spec and current threat scaling exactly once, restore HP, then register with `EnemyIndex`. Recycling unregisters first and disables all callbacks, collision, hitbox roles, and visibility.

`can_pool_as_ambient` returns true only for non-elite, non-special, non-protected regular spawner actors with a non-empty scene path. Any failed precondition uses `queue_free`.

- [ ] **Step 5: Route spawn, death, and retirement through the contract**

Regular ambient `_spawn_instance_node` uses `PoolManager.obtain`; special/authored paths continue to instantiate. `EnemyLifecycle` calls `despawn(&"death")` after synchronous kill/drop events. `EnemyIndex.retire_enemy` unregisters immediately, records the reason, then asks the actor to despawn; its fallback remains `queue_free` for generic test nodes.

When editing `spawner.gd`, preserve the user's existing `encounter_owner` parameter rename and do not stage unrelated changes.

- [ ] **Step 6: Run pool, scheduler, lifecycle, and projectile tests; verify GREEN**

Expected: reset, capacity, eligibility, registry, hitbox, projectile, death, and retirement behaviors pass.

- [ ] **Step 7: Commit Task 4 paths selectively**

Because `spawner.gd` already contains unrelated user edits, review `git diff`, stage only the pooling hunk for that file with a patch, and never stage the existing parameter-warning hunk. Commit the remaining clean files normally.

```powershell
git commit -m "perf: reuse bounded ambient enemy instances"
```

---

### Task 5: Recorder diagnostics and recurring-log gating

**Files:**
- Modify: `autoload/PerformanceFlightRecorder.gd:185-250`
- Modify: `autoload/global.gd:90-100,298-315`
- Modify: `effects/conduit/scenes/ConduitArcBolts.gd:1-45`
- Modify: `tools/tests/PerformanceFlightRecorderTest.gd`
- Modify: `tools/tests/EnemySimulationSchedulerTest.gd`

**Interfaces:**
- Recorder sample adds `enemy_scheduler` and `enemy_pool` dictionaries to the slow snapshot.
- Global adds `debug_combat_transactions: bool = false` without changing transaction results.
- Conduit proc logging is disabled unless its explicit debug flag is enabled.

- [ ] **Step 1: Write failing diagnostic tests**

Enable the recorder, collect a slow snapshot with the real scheduler and pool autoloads, and assert hand-named keys exist: `full`, `mid`, `far`, `protected`, `physics_enabled`, `mid_steps`, `far_steps`, `assignment_usec`, `reuse_hits`, `releases`, and `inactive`. Exercise a follower transaction with logging disabled and assert the returned follower delta remains correct; do not test console text.

- [ ] **Step 2: Run recorder tests and verify RED**

Expected: missing scheduler/pool snapshot keys.

- [ ] **Step 3: Merge cached diagnostics into recorder samples**

Read scheduler and pool counters only during the existing 0.5-second slow snapshot, not every frame. Duplicate nested dictionaries before storing them so later counter mutation cannot rewrite earlier samples.

- [ ] **Step 4: Gate recurring developer prints**

Wrap `FOLLOWERS TRANSACTION` with `debug_combat_transactions`; default false. Add a local exported debug flag around `ConduitArcBolts` proc printing. Preserve the user's existing unrelated warning fix in `global.gd` and stage only the new hunks.

- [ ] **Step 5: Run recorder and scheduler tests; verify GREEN**

- [ ] **Step 6: Commit Task 5 paths selectively**

```powershell
git commit -m "perf: record enemy budgets without combat log spam"
```

---

### Task 6: Full regression and performance verification

**Files:**
- Modify: `docs/PERFORMANCE_PATCH_CHANGELOG.md`
- Modify only if a verified regression requires it: files from Tasks 1-5 and their tests.

**Interfaces:**
- Produces: a documented repeat-run procedure and exact before/after metrics.

- [ ] **Step 1: Run every focused test fresh**

Run these scenes individually with the Godot 4.7.1 console executable:

```text
EnemySimulationSchedulerTest.tscn
EnemyPoolTest.tscn
FlowFieldLoadSheddingTest.tscn
PerformanceRootCauseFixTest.tscn
PerformanceLifecycleTest.tscn
PerformanceFlightRecorderTest.tscn
PerformanceIncidentWriteQueueTest.tscn
ProjectileSimulationTest.tscn (or the repository's current projectile test scene)
ChunkStreamingPerformanceAudit.tscn
WorldTileIntegrationTest.tscn
```

If a listed projectile scene name differs, locate it with `rg --files tools/tests | rg Projectile` and run the real scene. Any failure returns to the task that owns the behavior; do not stack unrelated fixes.

- [ ] **Step 2: Run the full project parser scan**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit
```

Expected: exit code 0 and no new GDScript errors or warnings from modified files.

- [ ] **Step 3: Run existing enemy/projectile benchmarks**

Locate current benchmark scenes with `rg --files tools/tests | rg 'Benchmark|Stress'`. Record command, actor count, median/p95 frame or step time, and failures. Unit benchmarks establish regression safety but do not substitute for gameplay capture.

- [ ] **Step 4: Audit the diff and user changes**

Run `git status --short`, `git diff --check`, and `git diff HEAD~5 --stat`. Confirm the pre-existing developer-segment files and warning-cleanup hunks are unchanged and uncommitted unless they were already committed independently by the user.

- [ ] **Step 5: Update the changelog and commit verified documentation**

Document implemented budgets, proxy frequencies, pool limits, tests, and the exact runtime test requested from the user. Do not claim gameplay FPS improvement before the user produces a fresh recorder run.

```powershell
git add -- docs/PERFORMANCE_PATCH_CHANGELOG.md
git commit -m "docs: record enemy simulation performance rework"
```

- [ ] **Step 6: Runtime handoff**

Ask the user to run the same horde-survivor route until at least 500 enemies if the temporary cap has intentionally been raised for that test, or to the current cap for the first comparison. On the returned capture compare frame-time bins against enemy tiers, `physics_enabled`, scheduler CPU, flow CPU, pool reuse, projectiles, nodes, and draw calls before choosing the next scale increase.
