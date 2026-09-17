# Enemy World Combat Migration Implementation Plan

> **Execution note:** Implement test-first on `feat/authoritative-enemy-world`. Do not dematerialize any EnemyActor until every phase exit criterion passes.

**Goal:** Make every player attack that can reach an ordinary enemy query and mutate stable EnemyWorld handles, so materialized and future data-only enemies receive identical hits, knockback, burn, bleed, and exact-once death behavior.

**Architecture:** `EnemyCombatService` becomes the single handle-oriented facade for live-target queries and combat commands. Projectile and effect code stores handles instead of enemy Nodes. `EnemyStatusService` owns logical DoT schedules independently of representation. Physics hitboxes remain only as a compatibility path for always-materialized legacy/critical actors, and resolve back to handles whenever one exists.

**Tech stack:** Godot 4.7 typed GDScript, packed EnemyWorld storage, analytic segment/circle/sector tests, existing batched projectile manager and scene-based headless suites.

---

## Task 1: Add live handle queries and authoritative knockback

**Files:**
- Modify: `core/systems/enemy_world/EnemyWorld.gd`
- Modify: `core/systems/enemy_world/EnemyCombatService.gd`
- Modify: `core/actors/enemy/enemy.gd`
- Create: `tools/tests/EnemyCombatQueryTest.gd`
- Create: `tools/tests/EnemyCombatQueryTest.tscn`

1. Write failing tests for nearest/radius filtering of dying records, exact swept-segment collision using each record's collision radius, exclusion handles, sector/wedge inclusion, and stale handles.
2. Add packed knockback velocity storage with get/set/add accessors and generation-safe reset.
3. Add allocation-conscious combat queries: radius, nearest, first swept-segment hit with hit fraction, and sector gather.
4. Add `EnemyCombat.apply_knockback(handle, force)`; data-only targets store force, materialized targets mirror it into the actor, and actor physics commits decay back to the world.
5. Preserve a compatibility fallback for bound non-EnemyActor targets whose lifecycle is still Node-owned.
6. Run storage, spatial, binding, combat-service, and query suites; commit the green slice.

## Task 2: Convert managed projectiles and hit ledgers to handles

**Files:**
- Modify: `core/combat/hits/HitLedger.gd`
- Modify: `core/combat/projectile/ProjectileSimulationManager.gd`
- Modify: `tools/tests/ProjectileSlotReuseTest.gd`
- Create: `tools/tests/ProjectileHandleCombatTest.gd`
- Create: `tools/tests/ProjectileHandleCombatTest.tscn`

1. Write failing tests with one materialized record and one data-only record on projectile paths, including piercing and a stale removed/reused target.
2. Store `target_handle` in each ledger, key pending ledgers by handle, and replace projectile instance-ID exclusion with generation-safe handle exclusion.
3. Use the combat service's swept query and hit fraction, then flush damage/knockback/status payloads by handle without materializing the target.
4. Keep enemy-team projectile-to-player behavior unchanged.
5. Verify batched damage semantics, slot reuse, projectile rendering publication, and stale-source safety; commit the green slice.

## Task 3: Centralize burn and bleed schedules

**Files:**
- Create: `core/systems/enemy_world/EnemyStatusService.gd`
- Modify: `project.godot`
- Modify: `core/actors/enemy/modules/EnemyLifecycle.gd`
- Modify: `effects/augments/logic/SpiritSlashEffect.gd`
- Modify: `tools/tests/DotSchedulingTest.gd`
- Create: `tools/tests/EnemyStatusServiceTest.gd`
- Create: `tools/tests/EnemyStatusServiceTest.tscn`

1. Write failing tests for max-stack refresh semantics, duration refresh, tick intervals, simultaneous burn/bleed, materialized/data-only parity, lethal ticks, pause-safe delta, stale cleanup, and generation reuse.
2. Add one central status schedule keyed by handle and status kind, with weak source references and no per-enemy Nodes or timers.
3. Route projectile burn and Spirit Slash bleed through the status service. Keep `BurnDot` and `BleedDot` only for non-world legacy targets.
4. Remove EnemyActor's active-dot ownership and prove pool reuse cannot retain status from an old handle generation.
5. Run status, DoT, lifecycle, pool, combat, and save suites; commit the green slice.

## Task 4: Migrate radius, sector, and pulse attacks

**Files:**
- Modify: `scenes/world/combat/MeleeSlash.gd`
- Modify: `scenes/world/combat/MagicImpact.gd`
- Modify: `effects/augments/logic/TeslaAuraEffect.gd`
- Modify: `effects/lattice/scenes/LatticeAfterstrike.gd`
- Modify: `effects/lattice/scenes/LatticeEchoBuffer.gd`
- Modify: `effects/gravemarch/scenes/GravemarchSunderstep.gd`
- Modify: `effects/gravemarch/scenes/GravemarchMassArrest.gd`
- Modify: `effects/conduit/scenes/ConduitOverclockAndFeedback.gd`
- Modify: `core/systems/world/Wardstone.gd`
- Create: `tools/tests/EnemyAreaCombatTest.gd`
- Create: `tools/tests/EnemyAreaCombatTest.tscn`

1. Write failing materialized/data-only parity tests for radius damage, melee wedges, target limits/order, knockback, and one-hit deduplication when a materialized hitbox and world query both see the same target.
2. Replace EnemyIndex/group scans with handle queries and issue damage/knockback commands by handle.
3. Preserve physics callbacks only for non-world legacy actors and use a unified hit key so world-backed actors cannot be hit twice.
4. Spawn VFX from the authoritative target position rather than requiring a Node transform.
5. Run area-combat, combat-lifecycle, audit, and set-effect coverage; commit the green slice.

## Task 5: Migrate homing, chaining, and legacy projectile attacks

**Files:**
- Modify: `core/combat/projectile/projectile.gd`
- Modify: `scenes/world/combat/RangedBullet.gd`
- Modify: `effects/augments/logic/MagicMissileEffect.gd`
- Modify: `spells/logic/MagicMissileSpell.gd`
- Modify: `effects/augments/logic/PoisonSpiderling.gd`
- Modify: `effects/augments/logic/ReflectedProjectile.gd`
- Modify: `effects/augments/logic/ReflectShieldEffect.gd`
- Modify: `effects/augments/logic/SpiritSlashEffect.gd`
- Modify: `effects/conduit/scenes/ConduitArcBolts.gd`
- Create: `tools/tests/EnemyTargetHandleTest.gd`
- Create: `tools/tests/EnemyTargetHandleTest.tscn`

1. Write failing tests proving homing targets survive representation changes, disappear safely on stale generation, reacquire correctly, and chaining exclusion uses handles.
2. Store target handles and resolve current positions each step; never retain an enemy Node for logical targeting.
3. Give moving legacy projectiles analytic segment hits so they can collide with data-only targets between frames.
4. Keep authored visuals and impact timing unchanged; use bound actors only for optional presentation.
5. Run targeting, projectile, augment, lifecycle, and stale-object tests; commit the green slice.

## Task 6: Preserve always-materialized legacy/critical targets

**Files:**
- Modify: `autoload/EnemyIndex.gd`
- Modify: `scenes/world/bosses/BossPylon.gd`
- Modify: `core/systems/world/opening/OpeningActor.gd` if required by compatibility tests
- Modify: `core/systems/enemy_world/EnemyCombatService.gd`
- Create: `tools/tests/EnemyLegacyCombatCompatibilityTest.gd`
- Create: `tools/tests/EnemyLegacyCombatCompatibilityTest.tscn`

1. Write failing tests for BossPylon and OpeningActor damage through handle-oriented attacks, exact legacy death events, and clean unregister.
2. Snapshot CRITICAL/OBJECTIVE/TUTORIAL/NEVER_RETIRE flags during adoption.
3. Register eligible critical Node targets with the compatibility index/world and route handle damage to their existing Node-owned lifecycle without double-mutating health.
4. Ensure these flags permanently exclude the records from later proxy eligibility.
5. Run boss, opening, audit-closure, index, and combat suites; commit the green slice.

## Task 7: Combat migration phase gate

**Files:**
- Modify: `tools/tests/PerformanceRootCauseFixTest.gd`
- Modify: `autoload/PerformanceFlightRecorder.gd` only if query/status counters require schema additions

1. Add architecture guards rejecting production player attacks that scan the `enemies` group or call EnemyIndex target queries, except documented compatibility-only code.
2. Audit every `take_damage`, `apply_hit_ledger`, `apply_knockback`, `enemy_hitbox`, EnemyIndex query, and enemy-group scan call site.
3. Run the editor parser gate with zero warning/error lines.
4. Run every scene suite in a separate process, the 600-record benchmark, managed-projectile stress, recorder benchmark, and stale-lifecycle stress.
5. Require a clean worktree and commit the phase boundary before enabling any data-only representation.

## Phase exit criteria

- Every player attack capable of reaching an ordinary enemy targets stable handles.
- Materialized and data-only records receive identical damage, knockback, burn, bleed, and exact-once death transitions.
- Homing and piercing retain no enemy Node identity.
- Stale handles cannot damage slot replacements or carry status across generations.
- Legacy critical actors remain fully functional and explicitly non-proxy.
- No ordinary proxy can be invisible or invulnerable because an attack still depends on an Area2D.
- Parser gate and full scene suite pass before materialization is allowed to remove a Node.
