# Enemy Lifecycle and Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop gradual FPS degradation by retiring irrelevant special enemies, reducing far-enemy physics work, fixing tooltip placement/input, and exposing trustworthy runtime performance evidence.

**Architecture:** Keep `EnemyIndex` as the canonical registry and give `EnemySpawner` an explicit policy for each enemy responsibility instead of exempting every special enemy. Preserve full simulation for engaged actors, especially offscreen snipers, while stagger-throttling eligible distant actors. Add a low-frequency developer diagnostics overlay and benchmark the existing projectile renderer before accepting any bulk-buffer change.

**Tech Stack:** Godot 4.7.1, typed GDScript, existing headless `.tscn` test harnesses, MultiMesh 2D rendering.

## Global Constraints

- Developer Mode remains available.
- Save data is unchanged.
- Enemy combat values, rewards, drop chances, and nearby spawn pressure are unchanged.
- Bosses, minibosses, active objectives, tutorial actors, active scripted encounters, and engaged snipers are never distance-culled.
- Sniper protection is based on combat state and configured engagement range, not screen visibility.
- Ordinary projectiles retain piercing, burn, critical hits, knockback, world collision, and batched damage.
- Exotic mines, beams, telegraphs, and homing attacks remain node-owned.
- No procedural-generation redesign or enemy ECS rewrite is included without measured evidence.
- The workspace has no Git repository, so each task ends with a verified checkpoint instead of a commit.

---

## File map

- `ui/widgets/ItemTooltip.gd`: recursive input transparency and source-rect-aware placement helper.
- `ui/controllers/HudTooltipController.gd`: pass the hovered control rectangle into tooltip placement.
- `ui/screens/HubShop.gd`: use the shared source-rect placement helper.
- `core/actors/enemy/modules/EnemySniper.gd`: expose authoritative engagement/telegraph state.
- `core/actors/enemy/enemy.gd`: expose retirement protection and implement staggered far simulation.
- `autoload/EnemyIndex.gd`: expose population/tier diagnostics and maintain exact retirement accounting.
- `core/systems/spawner/spawner.gd`: replace blanket special exclusion with responsibility-aware culling.
- `scenes/world/volumes/IndoorVolume.gd`: reversible ownership/protection for interior enemies.
- `ui/widgets/PerformanceOverlay.gd`: low-frequency developer diagnostics.
- `ui/widgets/PerformanceOverlay.tscn`: diagnostics presentation.
- `scenes/game.tscn`: attach the developer overlay.
- `core/combat/projectile/ProjectileSimulationManager.gd`: accurate timing and isolated renderer benchmark/change.
- `tools/tests/PerformanceLifecycleTest.gd`: lifecycle, sniper, tooltip, tier, and counter regression tests.
- `tools/tests/PerformanceLifecycleTest.tscn`: headless test entry point.

### Task 1: Tooltip input and RPG-style placement

**Files:**
- Modify: `ui/widgets/ItemTooltip.gd`
- Modify: `ui/controllers/HudTooltipController.gd`
- Modify: `ui/screens/HubShop.gd`
- Test: `tools/tests/PerformanceLifecycleTest.gd`
- Create: `tools/tests/PerformanceLifecycleTest.tscn`

**Interfaces:**
- Produces: `ItemTooltip.make_subtree_mouse_transparent() -> void`
- Produces: `ItemTooltip.place_beside(source_rect: Rect2, viewport_rect: Rect2, gap: float = 12.0) -> Vector2`

- [ ] **Step 1: Write failing tooltip tests**

Create a headless test that instantiates `ItemTooltip.tscn`, calls
`make_subtree_mouse_transparent()`, recursively visits every `Control`, and asserts its
`mouse_filter == Control.MOUSE_FILTER_IGNORE`.

Add placement assertions with a `460x300` tooltip:

```gdscript
var source := Rect2(Vector2(100, 100), Vector2(44, 44))
var viewport := Rect2(Vector2.ZERO, Vector2(1920, 1080))
var placed := tooltip.place_beside(source, viewport, 12.0)
_check(placed.x >= source.end.x + 12.0, "tooltip prefers source right side")
_check(not Rect2(placed, tooltip.size).intersects(source), "tooltip avoids hovered slot")
```

Add a source near the right edge and assert placement flips left and remains vertically
inside the viewport.

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tools/tests/PerformanceLifecycleTest.tscn
```

Expected: failure because the two tooltip methods do not exist.

- [ ] **Step 3: Implement input transparency and placement**

In `_ready()`, recursively set `MOUSE_FILTER_IGNORE` on the tooltip and every descendant
`Control`. Implement `place_beside` so it lays out the tooltip first, prefers
`source_rect.end.x + gap`, flips to `source_rect.position.x - size.x - gap`, clamps Y, and
only overlaps the source if neither side fits.

Update HUD and shop hover handlers to pass the hovered slot's `get_global_rect()` rather than
placing from raw mouse coordinates.

- [ ] **Step 4: Verify GREEN and existing tooltip comparisons**

Run `PerformanceLifecycleTest.tscn` and `AuditClosureTest.tscn`. Expected: all tooltip tests
and the existing scripted-effect comparison pass.

- [ ] **Step 5: Record checkpoint**

Record test totals in `docs/PERFORMANCE_PATCH_CHANGELOG.md` under `Tooltip`.

### Task 2: Explicit enemy retirement policy and sniper protection

**Files:**
- Modify: `core/actors/enemy/modules/EnemySniper.gd`
- Modify: `core/actors/enemy/enemy.gd`
- Modify: `core/systems/spawner/spawner.gd`
- Test: `tools/tests/PerformanceLifecycleTest.gd`

**Interfaces:**
- Produces: `EnemySniper.is_combat_committed() -> bool`
- Produces: `EnemyActor.is_retirement_protected(player_distance: float) -> bool`
- Produces: `EnemySpawner.is_enemy_cull_eligible(enemy: Node2D, player_position: Vector2) -> bool`

- [ ] **Step 1: Write failing policy tests**

Use lightweight enemy fixtures with groups/metadata and assert:

- Ambient enemy: eligible beyond retention distance.
- `special_spawn_kind == &"split"`: eligible.
- `special_spawn_kind == &"interior"` with `interior_active == false`: eligible.
- Interior with `interior_active == true`: protected.
- Boss/miniboss/objective/tutorial: protected.
- Sniper inside engagement range: protected.
- Sniper with a live telegraph, pending shot, aim, or combat relocation: protected.
- Idle sniper beyond `maximum engagement range + safety margin`: eligible.

- [ ] **Step 2: Run the policy tests and verify RED**

Expected: failure because the new policy interfaces do not exist and the current blanket
special-kind rule protects split/interior enemies.

- [ ] **Step 3: Expose sniper combat commitment**

Return true while any sniper windup, telegraph, pending fire, active shot sequence, or
combat relocation state is live. Expose the maximum engagement distance from existing
`EnemySpec`/sniper range values plus a fixed safety margin owned by `EnemyActor`.

- [ ] **Step 4: Replace blanket special exclusion**

Move eligibility into the public policy method. Continue protecting explicit active
encounters, bosses, objectives, tutorial actors, summons during their lifetime, and engaged
snipers. Permit ambient, split, expired interior, and orphaned encounter adds.

- [ ] **Step 5: Verify GREEN**

Run `PerformanceLifecycleTest.tscn`. Expected: every responsibility case passes.

- [ ] **Step 6: Record checkpoint**

Document the exact protection matrix in `docs/PERFORMANCE_PATCH_CHANGELOG.md`.

### Task 3: Reversible interior and encounter ownership

**Files:**
- Modify: `scenes/world/volumes/IndoorVolume.gd`
- Modify: `core/systems/spawner/spawner.gd`
- Modify: `autoload/EnemyIndex.gd`
- Test: `tools/tests/PerformanceLifecycleTest.gd`

**Interfaces:**
- Produces metadata: `interior_owner_id: int`, `interior_active: bool`
- Produces metadata: `encounter_owner_id: int`, `encounter_active: bool`
- Produces: `EnemyIndex.retire_enemy(enemy: Node, reason: StringName) -> bool`

- [ ] **Step 1: Write failing ownership tests**

Assert that an active interior enemy is protected, deactivation makes it eligible, and
`retire_enemy` removes it from `_enemies`, buckets, population counts, and the scene tree
exactly once. Repeat for an orphaned encounter add.

- [ ] **Step 2: Run and verify RED**

Expected: failure because ownership metadata and canonical retirement do not exist.

- [ ] **Step 3: Tag interior ownership**

When an interior wave spawns, tag enemies with the interior instance ID and active state.
When the interior deactivates/exits its encounter lifecycle, set `interior_active` false.
Remove the permanent `never_cull` assignment for ordinary interior enemies.

- [ ] **Step 4: Centralize retirement**

Implement idempotent `EnemyIndex.retire_enemy`, performing unregister/accounting before
`queue_free()`. Update the spawner to call it instead of independently unregistering.

- [ ] **Step 5: Verify GREEN and population integrity**

Run the lifecycle test twice in the same process to ensure counters do not drift after
repeated retire/unregister calls.

- [ ] **Step 6: Record checkpoint**

Document ownership metadata and lifecycle behavior.

### Task 4: Far-enemy staggered simulation

**Files:**
- Modify: `core/actors/enemy/enemy.gd`
- Modify: `autoload/EnemyIndex.gd`
- Test: `tools/tests/PerformanceLifecycleTest.gd`

**Interfaces:**
- Produces: `EnemyActor.simulation_tier() -> int`
- Produces: `EnemyActor.should_run_far_step(delta: float) -> bool`
- Produces: `EnemyIndex.simulation_tier_counts() -> Dictionary`

- [ ] **Step 1: Write failing scheduling tests**

Create several eligible enemies with different instance-derived phases. Assert far enemies
do not all step on the same frame, accumulated delta is preserved, and changing distance to
near or entering sniper commitment forces the next step immediately.

- [ ] **Step 2: Run and verify RED**

Expected: failure because far movement still runs every physics frame.

- [ ] **Step 3: Implement safe far scheduling**

Keep player acquisition, death, stun, telegraph, attack, and protection checks immediate.
For eligible far actors, accumulate delta and execute movement/collision/index update at a
staggered interval in the 0.067–0.10 second range. Do not throttle active ranged attacks,
snipers, elites engaged with the player, bosses, objectives, or scripted actors.

- [ ] **Step 4: Verify GREEN**

Run lifecycle tests and a headless scene with at least 100 fixture enemies. Assert tier
counts remain stable and all actors return to full frequency upon approaching.

- [ ] **Step 5: Record checkpoint**

Document thresholds, interval, exclusions, and measured fixture update count.

### Task 5: Trustworthy developer performance diagnostics

**Files:**
- Modify: `autoload/EnemyIndex.gd`
- Modify: `core/systems/spawner/spawner.gd`
- Modify: `core/systems/world/ChunkManager.gd`
- Modify: `core/combat/projectile/ProjectileSimulationManager.gd`
- Create: `ui/widgets/PerformanceOverlay.gd`
- Create: `ui/widgets/PerformanceOverlay.tscn`
- Modify: `scenes/game.tscn`
- Test: `tools/tests/PerformanceLifecycleTest.gd`

**Interfaces:**
- Produces: `EnemyIndex.get_debug_counters() -> Dictionary`
- Produces: `EnemySpawner.get_cull_counters() -> Dictionary`
- Produces: `ChunkManager.loaded_chunk_count() -> int`
- Produces: `PerformanceOverlay.collect_snapshot() -> Dictionary`

- [ ] **Step 1: Write failing counter tests**

Assert all snapshot keys exist, values are numeric, collection does not mutate enemy/index
state, and projectile `physics_ms` changes with measured workload rather than equalling
`delta * 1000`.

- [ ] **Step 2: Run and verify RED**

Expected: missing interfaces and inaccurate projectile time.

- [ ] **Step 3: Add low-cost counters**

Maintain retirement totals incrementally. Expose index totals/by-kind/tier and loaded chunk
count without scanning. Measure projectile work with `Time.get_ticks_usec()` around the
manager's physics body.

- [ ] **Step 4: Implement overlay**

Refresh at 0.5-second intervals only while visible. Include FPS, frame/process/physics
monitors, draw calls, objects/nodes, collision objects, live/indexed enemies, special kinds,
simulation tiers, retirement reasons, projectiles, actual projectile milliseconds, and
loaded chunks. Add a Developer Mode toggle/key without removing existing tools.

- [ ] **Step 5: Verify GREEN**

Run lifecycle tests and editor initialization. Confirm hidden overlay performs no full
scene-tree scans and visible overlay scans at most twice per second.

- [ ] **Step 6: Record checkpoint**

Add overlay controls and counter definitions to the changelog.

### Task 6: Long-session lifecycle stress verification

**Files:**
- Modify: `tools/tests/PerformanceLifecycleTest.gd`
- Create: `tools/tests/EnemyLifecycleStressTest.gd`
- Create: `tools/tests/EnemyLifecycleStressTest.tscn`

**Interfaces:**
- Consumes all lifecycle and diagnostics interfaces from Tasks 2–5.
- Produces a bounded-count stress report printed by the headless test.

- [ ] **Step 1: Write the stress scenario**

Cycle fixture populations through ambient spawning, split descendants, summons, activated
then expired interiors, simulated player chunk movement, and retirement. Sample valid
scene-tree enemies, indexed counts, bucket counts, special counts, and object counts after
each cycle.

- [ ] **Step 2: Run against the new lifecycle**

Expected invariant after each cleanup boundary:

```text
scene enemies == indexed enemies
ambient <= configured ambient cap
split <= configured split cap
summons expire after lifetime/owner loss
expired interior enemies <= retirement budget backlog
```

- [ ] **Step 3: Fix only lifecycle defects demonstrated by the stress test**

Trace any mismatch to ownership, registration, reservation, or queued-deletion timing.
Do not tune unrelated combat behavior.

- [ ] **Step 4: Run all regression suites**

Run:

```text
PerformanceLifecycleTest.tscn
EnemyLifecycleStressTest.tscn
AuditClosureTest.tscn
SaveIntegrityTest.tscn
```

Expected: zero test failures.

- [ ] **Step 5: Record checkpoint**

Add stress cycle counts and maximum retained populations to the changelog.

### Task 7: Isolated projectile renderer benchmark

**Files:**
- Modify: `core/combat/projectile/ProjectileSimulationManager.gd`
- Create: `tools/tests/ProjectileRenderBenchmark.gd`
- Create: `tools/tests/ProjectileRenderBenchmark.gd` (a `SceneTree` script; run with `-s`, there is no `.tscn`)
- Modify: `docs/PERFORMANCE_PATCH_CHANGELOG.md`

**Interfaces:**
- Produces benchmark results for current per-instance setters and candidate bulk buffer.
- Production renderer changes only if the candidate is compatible and measurably faster.

- [ ] **Step 1: Build the benchmark without changing production rendering**

Measure renderer update time for 100, 500, 1,000, and 4,000 instances across both methods.
The candidate buffer must preserve 2D transform, rotation, per-instance scale, and color.

- [ ] **Step 2: Run the benchmark repeatedly**

Use warm-up iterations and compare median update time. Reject the bulk path if it loses
color/transform fidelity, creates per-frame garbage that offsets its gain, or fails to
improve the high-count median meaningfully.

- [ ] **Step 3: Write a failing renderer-equivalence test only if accepted**

Assert the generated bulk buffer encodes the same positions, rotations, scales, and colors
as the existing path for representative projectiles.

- [ ] **Step 4: Implement the accepted minimal renderer change**

Change only `_update_renderer()`. Do not alter simulation, collision, damage, attack
ownership, or projectile types.

- [ ] **Step 5: Verify**

Run projectile benchmark, lifecycle stress test, audit tests, and Godot editor smoke test.
If the candidate is rejected, retain the current renderer and document the measured result.

- [ ] **Step 6: Final documentation**

Complete `docs/PERFORMANCE_PATCH_CHANGELOG.md` with modified files, measurements, remaining
hotspots, and any runtime tests that still require the user's real gameplay build.
