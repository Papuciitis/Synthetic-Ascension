# Navigation Diagnostics and Spawn Filtering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build readable performance diagnostics, measurable allocation-free BFS rebuilding, batched navigation invalidation, and live per-archetype enemy isolation controls.

**Architecture:** A session-only `DebugEnemySpawnFilter` autoload owns archetype enablement, cap modes, counts, and cleanup. Every spawn path checks it through the canonical spawner boundary or direct child-spawn hook. `FlowFieldNav` retains BFS but exposes rebuild telemetry and uses fixed buffers; `ChunkManager` batches revisions. The performance overlay becomes a movable compact/detail panel and embeds the spawn controls.

**Tech Stack:** Godot 4.7.1, GDScript, scene resources, existing headless Godot test scenes.

## Global Constraints

- Keep equal-cost eight-neighbor BFS and diagonal corner protection.
- Developer controls and cap overrides are session-only.
- Filter changes retire newly disabled live enemies and clear reservations.
- Protected actors require an explicit protected-filter toggle.
- Debug filtering must cover ambient, interior, scripted, summoned, split, and boss-add creation.
- Production spawning remains unchanged while Production cap mode and all archetypes are enabled.
- Do not remove Developer Mode.
- The workspace is not a Git repository; use file/test checkpoints instead of commits.

---

### Task 1: Spawn Filter Model and Canonical Cleanup

**Files:**
- Create: `autoload/DebugEnemySpawnFilter.gd`
- Modify: `project.godot`
- Modify: `autoload/EnemyIndex.gd`
- Modify: `core/systems/spawner/spawner.gd`
- Test: `tools/tests/SpawnFilterTest.gd`
- Create: `tools/tests/SpawnFilterTest.gd` (a `SceneTree` script; run with `-s`, there is no `.tscn`)

**Interfaces:**
- Produces: `is_enemy_enabled(enemy_id: StringName, protected: bool = false) -> bool`
- Produces: `effective_total_cap(production_cap: int) -> int`
- Produces: `effective_type_cap(enemy_id: StringName, production_cap: int) -> int`
- Produces: `set_enemy_enabled(enemy_id: StringName, value: bool) -> void`
- Produces: `isolate_enemy(enemy_id: StringName) -> void`
- Produces: `get_debug_snapshot() -> Dictionary`
- Consumes: `EnemyIndex.retire_enemy(enemy: Node, reason: StringName) -> bool`

- [ ] **Step 1: Write failing spawn-filter tests**

Test Production, Custom, and Unlimited cap resolution; archetype enablement;
Only-this-type behavior; protected actor handling; live-enemy retirement; and
pending-reservation cleanup using real enemy nodes and the spawner.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . -s res://tools/tests/SpawnFilterTest.gd
```

Expected: failure because `/root/DebugEnemySpawnFilter` and its API do not exist.

- [ ] **Step 3: Implement the session-only model**

Use enum `CapMode { PRODUCTION, CUSTOM, UNLIMITED }`, dictionaries keyed by
stable `EnemySpec.id`, zero-as-unlimited custom caps, spawn/live counters, and a
signal carrying the newly disabled IDs.

- [ ] **Step 4: Add canonical filter and cleanup integration**

Before deferred insertion, resolve the instantiated `EnemyActor.spec.id`, reject
disabled spawns, and avoid creating reservations. When filters change, retire
matching indexed enemies with `debug_spawn_filter` and clear matching pending
scene reservations. Preserve protected actors unless protected filtering is on.

- [ ] **Step 5: Run the focused test and verify GREEN**

Expected: all spawn-filter assertions pass with zero failures.

### Task 2: Cover Direct Enemy-Created Spawn Routes

**Files:**
- Modify: `core/actors/enemy/modules/EnemySummoner.gd`
- Modify: `core/actors/enemy/modules/EnemySplitter.gd`
- Modify: any direct scripted enemy creation route identified by project-wide search
- Modify: `tools/tests/SpawnFilterTest.gd`

**Interfaces:**
- Consumes: `DebugEnemySpawnFilter.is_enemy_enabled(...)`
- Produces: no new public API.

- [ ] **Step 1: Add failing tests for summoner and splitter descendants**

Assert disabled child archetypes are not added and do not increment pending or
spawn counts.

- [ ] **Step 2: Verify RED**

Expected: direct child creation bypasses the filter.

- [ ] **Step 3: Route direct spawns through the filter**

Check the child’s stable spec ID before insertion. Keep normal gameplay behavior
unchanged when enabled.

- [ ] **Step 4: Search for bypasses and run GREEN**

Search all `.gd` files for enemy scene instantiation and deferred enemy
`add_child` calls. Verify the focused test passes.

### Task 3: Flow Rebuild Diagnostics and Stationary Evidence

**Files:**
- Modify: `core/systems/world/FlowFieldNav.gd`
- Modify: `tools/tests/PerformanceLifecycleTest.gd`

**Interfaces:**
- Produces: `get_debug_counters() -> Dictionary`
- Produces: rebuild reasons `initial`, `player_moved`, and `nav_revision`
- Produces: counts for requested, started, completed, superseded, cells, CPU time, revisions, movement state, pending, and building.

- [ ] **Step 1: Add failing request-reason tests**

Exercise repeated identical player cells, movement below and above the two-cell
threshold, and navigation revision changes. Assert a stationary unchanged world
does not add a request.

- [ ] **Step 2: Verify RED**

Expected: diagnostics and reason counters are absent.

- [ ] **Step 3: Implement request and build telemetry**

Record every request/start/completion and reason without printing every frame.
Expose the current and latest completed build state through one dictionary.

- [ ] **Step 4: Cancel superseded builds**

When a newer navigation revision is pending, stop the old build and increment
`superseded` before starting the current revision.

- [ ] **Step 5: Run GREEN**

Expected: stationary, movement, revision, and supersession tests pass.

### Task 4: Allocation-Free BFS Neighbor Expansion

**Files:**
- Modify: `core/systems/world/FlowFieldNav.gd`
- Modify: `tools/tests/PerformanceLifecycleTest.gd`
- Create: `tools/tests/FlowFieldBenchmark.gd`

**Interfaces:**
- Preserves: `sample_dir`, `sample_dir_smooth`, and `sample_cost`.
- Produces: benchmark output containing rebuild time and expanded-cell count.

- [ ] **Step 1: Add path-equivalence tests**

Use a deterministic grid fixture to assert reachability, diagonal corner
blocking, and stable directions before refactoring.

- [ ] **Step 2: Run and capture baseline**

Run the focused correctness test and standalone benchmark; preserve the result
in `docs/PERFORMANCE_PATCH_CHANGELOG.md`.

- [ ] **Step 3: Replace per-cell arrays**

Move neighbor directions to a constant and use fixed reusable candidate indices
and penalties. Perform insertion ordering in-place without allocating arrays in
`_expand_neighbors()`.

- [ ] **Step 4: Run equivalence tests and benchmark**

Expected: identical correctness assertions and no slower median rebuild time.

### Task 5: Batch Navigation Revisions

**Files:**
- Modify: `core/systems/world/ChunkManager.gd`
- Modify: `core/systems/world/proc/ChunkGenImpl.gd`
- Modify: callers that mutate manual walkability
- Modify: `tools/tests/PerformanceLifecycleTest.gd`

**Interfaces:**
- Produces: `request_nav_revision(reason: StringName) -> void`
- Produces: one committed revision for all requests received during a frame.
- Produces: `get_nav_debug_counters() -> Dictionary`

- [ ] **Step 1: Add failing revision-coalescing test**

Issue several chunk/manual-block invalidations before the deferred commit and
assert the revision advances once while preserving reason counts.

- [ ] **Step 2: Verify RED**

Expected: revision advances once per current mutation.

- [ ] **Step 3: Implement deferred revision batching**

Replace direct increments with `request_nav_revision()`. Commit once through a
deferred callback and expose requested/committed/reason diagnostics.

- [ ] **Step 4: Run GREEN**

Expected: multiple same-frame invalidations produce one committed revision.

### Task 6: Movable Compact Performance Overlay and Spawn Controls

**Files:**
- Modify: `ui/widgets/PerformanceOverlay.gd`
- Modify: `ui/widgets/PerformanceOverlay.tscn`
- Modify: `autoload/DevSetCollisionTools.gd`
- Modify: `tools/tests/PerformanceLifecycleTest.gd`

**Interfaces:**
- Consumes: flow, chunk, enemy, projectile, spawner, and spawn-filter snapshots.
- Produces: compact/detail toggle, draggable header, structured diagnostic labels, and spawn controls.

- [ ] **Step 1: Add failing layout/format tests**

Assert compact output contains FPS, enemy tiers, projectiles, and latest flow
reason; detailed output contains grouped flow/spawn data; neither emits raw
dictionary text; default panel rectangle avoids left inventory and right tools
at 1920×1080.

- [ ] **Step 2: Verify RED**

Expected: current wide raw-text overlay violates formatting and placement.

- [ ] **Step 3: Build the structured panel**

Add a header with Compact/Details and close actions, grouped labels, scrollable
detailed content, drag handling with viewport clamping, and a default safe-area
position.

- [ ] **Step 4: Add spawn controls**

Generate rows from discovered stable IDs, show live/spawn counts, and add
Enable all, Disable all, Only, protected toggle, cap mode, custom total cap, and
custom per-type cap controls.

- [ ] **Step 5: Run GREEN and inspect at 1920×1080**

Verify automated layout assertions, then run the game and confirm inventory,
objective UI, ability UI, and right-side tools remain usable.

### Task 7: Full Verification and Documentation

**Files:**
- Modify: `docs/PERFORMANCE_PATCH_CHANGELOG.md`

- [ ] **Step 1: Run focused suites**

Run `SpawnFilterTest.gd` (`-s`), `PerformanceLifecycleTest.tscn`, and
`EnemyLifecycleStressTest.tscn`.

- [ ] **Step 2: Run existing regression suites**

Run `AuditClosureTest.tscn` and `SaveIntegrityTest.tscn`.

- [ ] **Step 3: Run Godot project parsing**

Run the editor initialization command and verify there are no parse errors.

- [ ] **Step 4: Perform stationary-player evidence check**

Leave the player stationary with the detailed overlay visible. Record whether
flow rebuilds occur, and if they do, record the displayed navigation revision
reason.

- [ ] **Step 5: Update changelog**

Document changed files, cap semantics, measured BFS results, rebuild evidence,
test totals, and any remaining runtime risks without claiming unrun tests.
