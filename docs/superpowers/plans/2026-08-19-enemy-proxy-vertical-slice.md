# Enemy Proxy Vertical Slice Implementation Plan

> **Execution note:** Implement test-first on `feat/authoritative-enemy-world`. Keep runtime rollout disabled until the complete combat phase gate and every vertical-slice test pass.

**Goal:** Run ordinary distant chase enemies as visible, damageable data records while enforcing a default 64 / maximum 96 active EnemyActor budget, without changing bosses, scripted actors, combat balance, rewards, or population accounting.

**Architecture:** Add three focused services around the existing authoritative `EnemyWorld`: a low-frequency `EnemyProxySimulation`, a policy/lease `EnemyRepresentationManager`, and a batched `EnemyProxyRenderer`. The first slice supports only ordinary non-elite CHASE actors. EnemyIndex remains the temporary population-accounting facade, but gains explicit detach/attach/release operations so recycling a representation never changes logical population. Data-only lethal transitions are finalized by a logical death path before rollout can be enabled.

**Tech stack:** Godot 4.7 typed GDScript, packed EnemyWorld arrays, MultiMeshInstance2D, existing PoolManager/EnemyIndex/EnemyActor scenes, headless scene suites, performance recorder counters.

---

## Task 1: Add proxy eligibility and representation policy

**Files:**
- Create: `core/systems/enemy_world/EnemyRepresentationPolicy.gd`
- Create: `tools/tests/EnemyRepresentationPolicyTest.gd`
- Create: `tools/tests/EnemyRepresentationPolicyTest.tscn`

1. Write failing tests for critical flags, elite/smart exclusions, activation/deactivation hysteresis, nearest-first priority, a hard 64 budget, a 96 ceiling, and bounded per-step churn.
2. Implement allocation-conscious scoring over active handles without touching Nodes or the scene tree.
3. Return explicit promote/demote handle lists; policy evaluation itself must never mutate representation.
4. Run world storage/spatial/query suites and commit.

## Task 2: Add data-only chase simulation

**Files:**
- Modify: `core/systems/enemy_world/EnemyWorld.gd`
- Create: `core/systems/enemy_world/EnemyProxySimulation.gd`
- Create: `tools/tests/EnemyProxySimulationTest.gd`
- Create: `tools/tests/EnemyProxySimulationTest.tscn`

1. Write failing deterministic tests for 10 Hz accumulation, movement toward the player, speed, knockback decay, stun pause, finite positions, interpolation endpoints, stale handles, and 600-record bounded cost.
2. Add only the hot packed state required by ordinary chase proxies: facing, activity timer, deterministic phase, and knockback/stun progression.
3. Simulate DATA_ONLY CHASE records in rotating groups; never call physics, scene-tree queries, or per-record callbacks.
4. Keep flow/navigation integration injectable; begin with a deterministic target-direction provider and add the production FlowField adapter after core behavior passes.
5. Run benchmark and storage gates; commit.

## Task 3: Add batched proxy rendering

**Files:**
- Create: `core/systems/enemy_world/EnemyProxyRenderer.gd`
- Create: `tools/tests/EnemyProxyRendererTest.gd`
- Create: `tools/tests/EnemyProxyRendererTest.tscn`

1. Write failing tests for DATA_ONLY-only visibility, interpolation, handle removal, generation reuse, materialization handoff, elite color metadata, and no ghost instances.
2. Create one MultiMesh batch per visual key and bulk-publish transform/color buffers.
3. Use cold-state visual metadata populated at spawn/adoption; missing visuals use an explicit diagnostic proxy, never invisibility.
4. Run a real-renderer scene test in addition to headless state tests; commit.

## Task 4: Make EnemyActor a reversible representation lease

**Files:**
- Modify: `autoload/PoolManager.gd`
- Modify: `autoload/EnemyIndex.gd`
- Modify: `core/actors/enemy/enemy.gd`
- Create: `core/systems/enemy_world/EnemyRepresentationManager.gd`
- Create: `tools/tests/EnemyRepresentationLeaseTest.gd`
- Create: `tools/tests/EnemyRepresentationLeaseTest.tscn`

1. Write failing round-trip tests covering position, velocity, health, stun, knockback, flags, cold state, pool reuse, forced Node deletion, stale generations, and unchanged population counters.
2. Add PoolManager obtain context so a leased actor binds an existing handle without registering a new logical enemy.
3. Add EnemyIndex detach/attach APIs that preserve logical counters and a release API for detached logical records.
4. Add EnemyActor hydrate/commit/quiesce hooks. Every process, collision, monitoring, timer, external VFX, and signal must be disabled before pool handoff.
5. Enforce policy decisions with bounded churn. Critical flags bypass normal churn but never exceed the hard ceiling.
6. Keep the manager disabled by default; commit.

## Task 5: Finalize data-only death and retirement

**Files:**
- Create: `core/systems/enemy_world/EnemyDeathService.gd`
- Modify: `core/systems/enemy_world/EnemyCombatService.gd`
- Modify: `core/systems/enemy_world/EnemyWorld.gd`
- Modify: `autoload/EnemyIndex.gd`
- Modify: `core/actors/enemy/modules/EnemyDrops.gd` only to expose pure-data drop inputs
- Create: `tools/tests/EnemyProxyDeathTest.gd`
- Create: `tools/tests/EnemyProxyDeathTest.tscn`

1. Write failing exact-once tests for data-only XP, drops, population release, special ownership, splitter/summon metadata, stale hits, repeated lethal hits, and non-rewarding retirement.
2. Move ordinary logical death finalization behind one atomic service. Representation cleanup becomes a consequence, never authority.
3. Preserve existing materialized presentation callbacks while preventing duplicate legacy events/rewards.
4. Remove the record only after current combat readers finish; release detached EnemyIndex accounting exactly once.
5. Run lifecycle stress and save/inventory integrity suites; commit.

## Task 6: Spawn logical records and enable the chase slice behind a flag

**Files:**
- Modify: `core/systems/spawner/spawner.gd`
- Modify: `project.godot`
- Modify: `autoload/PerformanceFlightRecorder.gd`
- Create: `tools/tests/EnemyProxySpawnIntegrationTest.gd`
- Create: `tools/tests/EnemyProxySpawnIntegrationTest.tscn`

1. Write failing tests proving spawn creates one logical record, actor acquisition does not change logical population, the 64 budget is hard, special/critical spawns remain materialized, and safety cap supports at least 600.
2. Add a default-off rollout flag and only mark ordinary non-elite CHASE records proxy-eligible.
3. Populate complete hot/cold/visual state at logical spawn. Materialize only when policy requests it.
4. Replace spawner total/per-scene cap reads with authoritative logical counters while retaining special reservation semantics.
5. Add recorder counters for logical/materialized/data-only counts, requests, promotions, demotions, failures, churn, proxy simulation time, and batch upload time.
6. Enable the flag only in the controlled stress scene first; commit.

## Task 7: Vertical-slice gate and measured rollout

1. Run every scene suite in a separate process, editor parse gate, 480 lifecycle stress, 600-record simulation, pool reuse, projectile rendering, and proxy renderer tests.
2. Run comparable real gameplay captures at 180, 300, and 500 logical enemies with materialized budgets 48, 64, and 96.
3. Require no freed-object casts, duplicate deaths, invisible records, unbounded actor counts, or recurring enemy-caused frame spikes.
4. Only after recorder evidence passes, enable the ordinary CHASE proxy flag by default and raise the release safety cap to at least 600.

## Vertical-slice exit criteria

- Every ordinary CHASE enemy remains visible and combat-valid across repeated lease transitions.
- Materialized actors never exceed the configured hard ceiling.
- Critical, objective, tutorial, and never-retire records are never dematerialized.
- Actor pool operations do not create/remove logical enemies or alter population counters.
- Data-only lethal and retirement paths release exactly once with correct reward semantics.
- 500 logical enemies hold the project’s 60 FPS target in a fresh recorder capture; headless benchmarks alone are insufficient.
