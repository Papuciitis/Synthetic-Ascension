# Authoritative Enemy Lifecycle and Combat Implementation Plan

> **Execution note:** Implement this plan test-first in the existing `feat/authoritative-enemy-world` worktree. Keep every enemy materialized during this phase; proxy leasing starts only after this boundary passes.

**Goal:** Make `EnemyWorld` the single source of truth for enemy health, damage, and exact-once death while preserving current gameplay rewards, drops, boss identity events, pooling, DoTs, and projectile batching.

**Architecture:** `EnemyCombatService` resolves stable handles and is the only code allowed to mutate authoritative enemy health or transition a live record to `DYING`. Materialized `EnemyActor` nodes mirror the record and act as presentation/effect adapters. A value-style death context feeds generic systems without requiring an enemy Node; the existing Node death event remains available for identity-sensitive boss and scripted encounters.

**Tech stack:** Godot 4.7, typed GDScript, autoload services, scene-based headless tests.

---

## Task 1: Add atomic health and death primitives to EnemyWorld

**Files:**
- Modify: `core/systems/enemy_world/EnemyWorld.gd`
- Modify: `core/systems/enemy_world/EnemyWorldTypes.gd`
- Modify: `tools/tests/EnemyWorldStorageTest.gd`

1. Add failing tests for maximum-health reconfiguration, healing clamps, first-writer-wins death transition, repeated death rejection, and stale-handle rejection.
2. Run `EnemyWorldStorageTest.tscn` and confirm the new assertions fail for missing behavior.
3. Add `set_max_health`, `heal`, `is_dying`, and `try_begin_death` without exposing slot indices.
4. Prevent any generic representation sync from moving a `DYING` record back to `MATERIALIZED`.
5. Run the storage, spatial, and binding suites and commit the green slice.

## Task 2: Introduce handle-based combat and immutable death context

**Files:**
- Create: `core/systems/enemy_world/EnemyCombatService.gd`
- Create: `core/systems/enemy_world/EnemyDeathContext.gd`
- Create: `tools/tests/EnemyCombatServiceTest.gd`
- Create: `tools/tests/EnemyCombatServiceTest.tscn`
- Modify: `project.godot`

1. Write failing service tests covering normal damage, boss multipliers, batched hit caps, invalid and stale handles, damage after death, exact-once death callbacks, and a data-only enemy with no actor.
2. Add an injectable world dependency for isolated tests and use the `EnemyWorld` autoload in production.
3. Resolve damage modifiers from cold record state first and the currently bound actor as the compatibility adapter.
4. Mutate health in `EnemyWorld`, mirror the result to the bound actor through explicit callbacks, and create one `EnemyDeathContext` when `try_begin_death` succeeds.
5. Register `EnemyCombat` after `EnemyWorld`, run the new suite, and commit the green slice.

## Task 3: Convert EnemyActor from health owner to world adapter

**Files:**
- Modify: `core/actors/enemy/enemy.gd`
- Modify: `core/actors/enemy/modules/EnemyLifecycle.gd`
- Modify: `core/actors/enemy/modules/EnemyBomber.gd`
- Modify: `core/actors/enemy/modules/EnemyInit.gd`
- Modify: `autoload/EnemyIndex.gd`
- Modify: `core/systems/enemy_world/EnemyWorld.gd`
- Create: `tools/tests/EnemyCombatLifecycleTest.gd`
- Create: `tools/tests/EnemyCombatLifecycleTest.tscn`

1. Write a failing real-actor integration test proving direct damage, batched damage, DoT damage, healing, lethal damage, repeated lethal calls, and pooled reuse all agree with the world record.
2. Route `take_damage` and `apply_hit_ledger` through `EnemyCombat` using the actor's stable handle.
3. Split lifecycle behavior into non-authoritative hit feedback and exact-once death resolution. Keep knockback, burn creation, hurt SFX, splitter inheritance, rewards, drops, bomber explosion, and despawn behavior unchanged.
4. Replace reverse health mirroring: position/velocity still flow actor-to-world, but health/death flow world-to-actor after adoption.
5. Add explicit actor methods for full heal, partial heal, and maximum-health reconfiguration so later code cannot silently write only the mirror.
6. Ensure unregister/pool recycle invalidates the old handle and pool obtain adopts a fresh generation.
7. Run combat, lifecycle stress, pool, DoT, index, and binding suites and commit the green slice.

## Task 4: Publish a future-proof generic death event

**Files:**
- Modify: `autoload/RunEvents.gd`
- Modify: `autoload/ThreatDirector.gd`
- Modify: `autoload/SfxManager.gd`
- Modify: `core/systems/world/SegmentProcBuilder.gd`
- Modify: `core/systems/world/Level1Builder.gd`
- Modify: `core/actors/enemy/modules/EnemyLifecycle.gd`
- Modify: `scenes/world/events/BossArena.gd`
- Modify: `scenes/world/events/MiniBossArena.gd`
- Create: `tools/tests/EnemyDeathEventTest.gd`
- Create: `tools/tests/EnemyDeathEventTest.tscn`

1. Write failing tests proving one generic death event per handle, correct position/spec/elite/source snapshot, and no duplicate generic reward/progression response.
2. Add a typed `enemy_defeated(context)` event emitted by the combat service on the successful atomic death transition.
3. Move generic kill-rate, resonance, progression, and SFX consumers to the context event.
4. Retain `enemy_killed(player, enemy, position)` only as the materialized compatibility/identity event used by boss and scripted encounter ownership.
5. Verify that ordinary materialized deaths currently produce both events but each consumer listens to exactly one path.
6. Run the event, boss, audit-closure, lifecycle, and save-integrity suites and commit the green slice.

## Task 5: Remove remaining direct enemy-health writes

**Files:**
- Modify: `core/actors/enemy/enemy.gd`
- Modify: `scenes/world/events/BossArena.gd`
- Modify: `scenes/world/events/MiniBossArena.gd`
- Modify: relevant combat callers found by the final audit
- Modify: `tools/tests/PerformanceRootCauseFixTest.gd`

1. Add an architecture assertion that production enemy code no longer subtracts from `EnemyActor.hp` or restores it directly after registration.
2. Route boss arena scaling, elite promotion, boss leash healing, bomber self-detonation, projectiles, melee, magic, and DoTs through the handle service or the actor facade.
3. Re-run the health-write and death-event searches; document intentional initialization-only assignments.
4. Run the parser warning gate and all 32+ scene suites in separate engine processes.
5. Run the 600-record benchmark and recorder microbenchmark, compare with the foundation baseline, and commit the phase boundary.

## Phase exit criteria

- One authoritative health value per live enemy record.
- One successful live-to-dying transition per stable handle.
- Repeated, late, and stale hits are harmless.
- Current materialized gameplay behavior remains intact, including splitter, bomber, drop, follower, boss, and pooling behavior.
- Generic death consumers no longer require a Node, enabling data-only kills in the next phase.
- Parser gate and full scene suite are clean before any Node dematerialization is introduced.
