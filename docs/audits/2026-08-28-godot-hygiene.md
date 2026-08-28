# Godot API hygiene audit — deprecated APIs, deferred calls, ownership, signals, threads, physics callbacks, tick-rate assumptions

**Date:** 2026-08-28 · **Tree:** `enemy-world-work` @ `c131cd2` · **Engine:** Godot 4.7.1 · **Kind:** read-only (nothing modified).

## Baseline

- Godot 4-native codebase: zero hits for `instance()`, `Pool*Array`, `yield`, `OS.get_ticks_*`, `Engine.editor_hint`, `rect_*`/`margin_*`, `Tween.interpolate_property`, `KinematicBody`, `move_and_slide(args)`, `change_scene(`, string-style `connect("sig", self, ...)`. `TextServer.*` uses are current constants. `randomize()` calls are all on per-instance `RandomNumberGenerator`s.
- `project.godot`: `physics/common/max_physics_steps_per_frame=4`; `physics_ticks_per_second` default 60; `run_on_separate_thread` unset; physics interpolation off.
- Several instances of these classes are already fixed (`game.gd:152` deferred-argument capture comment; `enemy.gd:650-663` request-tracked `set_deferred`; `@static_unload` + `release_static_caches()`; `Global.hard_exit_on_quit`). The remaining gaps are mostly in the same families.

## 1. Deprecated / future-breakage APIs — none found

- LOW / 90% — `core/actors/enemy/EnemySpec.gd:1`, `core/systems/spawner/EnemySpawnEntry.gd:1`, `EnemySpawnTable.gd:1`, `core/systems/world/proc/SegmentThemeData.gd:1` — `@tool extends Resource` with no side effects; `tools/batch_icon_cutter.gd` lives only in `tools/BatchIconCutter.tscn`. No action.
- LOW / 60% — `data/manifestations/ManifestationCatalog.gd:46-47`, `ManifestationPairCatalog.gd:19-20` — `static var _defs: Dictionary` holding defs that `preload` GDScripts, **without `@static_unload`**, unlike the other five static caches. Same exit-order class as backlog D1; currently masked by `OS.kill` in `global.gd:1224`. Fix: `@static_unload` + a `release_static_caches()` call from `global.gd:_exit_tree`. Risk: negligible.

## 2. Suspicious deferred calls — mostly clean

`call_deferred` with Node args is guarded (`DebugEnemySpawnFilter.gd:76-86`); `ChunkManager.commit_pending_nav_revision` (line 1418) is idempotent; deferred `add_child` then deferred `make_elite` (`spawner.gd:435/457`, `EnemySplitter.gd:71/77`) preserves FIFO order; tooltip controllers guard `is_inside_tree()/is_node_ready()`.

- LOW / 60% — `core/actors/enemy/modules/EnemyShooter.gd:404,411` — `current_scene.call_deferred("add_child", proj)` followed by synchronous `current_scene.add_child(mf)`: the projectile is invisible for one frame while the muzzle flash is not; `current_scene` captured at schedule time. Fix: make both synchronous (caller is the scheduler's `_physics_process`, not a physics callback) or both deferred.
- LOW / 50% — `scenes/world/combat/MeleeSlash.gd:81,93` — `call_deferred("_scan_initial_overlaps")` then `await physics_frame` then `get_overlapping_areas()`; works because `physics_frame` fires before the step; fragile if the slash is ever spawned from `_process`. Fix: await twice or use `direct_space_state.intersect_shape`.
- LOW / 50% — `ui/components/BagUI.gd:387` — `merge_vfx.call_deferred("play_merge", _grid_slots[from], _grid_slots[to], ...)` captures slot Controls at schedule time; a same-frame grid rebuild would hand the VFX freed nodes. Fix: pass indices and resolve inside `play_merge`.

## 3. Unsafe node ownership

- **MED / 70%** — `autoload/PoolManager.gd:146-165` + `core/actors/enemy/enemy.gd:736-748,1103-1120` — recycled enemies are reparented under the PoolManager autoload but **never leave the `"enemies"` group** (`add_to_group(&"enemies")` at `enemy.gd:820` is re-applied on obtain; nothing removes it on recycle). Consequences:
  - `core/systems/world/Level1Builder.gd:1441-1443` — `for enemy in get_nodes_in_group(&"enemies"): enemy.queue_free()` frees the **entire pool** (and lease-quiesced actors still bound to EnemyWorld handles) on opening-phase restore. PoolManager tolerates freed entries (obtain 50-56), but the warm pool is destroyed exactly when a segment restarts.
  - `core/actors/enemy/modules/EnemyHerald.gd:76-82` buffs parked corpses (no `dead`/`__in_pool` filter); `EnemySeparationSystem.gd:36-39` and `EnemyTactical.gd:138-140` filter `dead` only, so lease-quiesced nodes (`dead == false`, invisible, parked at the demotion position) count as neighbours.
  - Fix: `remove_from_group(&"enemies")` in `_on_pool_recycle()` and `_quiesce_representation_lease()` (obtain already re-adds). Risk: code relying on the group to find pooled nodes — none found; EnemyIndex is the canonical path.
- **MED / 60%** — `autoload/PoolManager.gd:74-79` — `target_parent = cs if cs != null else self`: when `current_scene` is null (scene-transition frame) a *live* projectile is parented under the autoload (`PROCESS_MODE_ALWAYS`, line 29): keeps flying while paused, survives the scene change, renders in the root canvas. Fix: return `null` (callers already null-check) or defer the obtain. Risk: a dropped shot during a transition frame.
- LOW / 70% — pooled physics nodes stay in the tree and the physics space; shape disabling is `set_deferred` (`enemy.gd:663,674,678`) so no ghost collision was found; it is the mechanism behind finding 6.1. Structural fix: park pooled nodes out of the tree. Risk: scripts that use `is_inside_tree()` as liveness (`EnemyLeech.gd:47`).
- Clean: no `reparent()`/`owner` misuse; no preload cycles (246 script/scene preload edges, zero 2- or 3-cycles); `static var`s hold only Strings/Resources/scalars; all RefCounted enemy modules validate `_enemy/_owner` except `EnemyBomber`/`EnemyOrbit`/`EnemySplitter` (only invoked from the owning enemy's own tick → LOW).

## 4. Signals never disconnected — clean overall

Every `RunEvents.*`/`Global.*` connect from a per-run node either has an `_exit_tree` disconnect (all `effects/**`, curses, StaminaCore, ManifestationRunner, builders, player) or lives on a node freed with the scene. Pooled scripts guard with `is_connected` (`EnemyInit.gd:140-143`, `EnemyProjectile.gd:70-73`, `projectile.gd:16-17`). No connects to `SettingsManager.settings_changed` or SceneTree signals; no lambda connected to an autoload signal.

- LOW / 55% — `effects/gravemarch/scenes/GravemarchMassArrest.gd:171-176` — up to four `create_timer(...).timeout.connect(func(): ...)` lambdas reading `self`; if the set effect is freed before they fire, "lambda self freed" errors in debug builds. Fix: `timeout.connect(_aftershock.bind(r), CONNECT_ONE_SHOT)`.
- LOW / 60% — `await get_tree().create_timer(...)` inside nodes that can be freed mid-wait: `player.gd:992`, `spawner.gd:757,765`, `IndoorVolume.gd:162`, `BagUI.gd:389`. Fix: `if not is_inside_tree(): return` after each await.

## 5. Threading

- **MED / 70%** — `autoload/PerformanceFlightRecorder.gd:537` `_latest_incident.clear()` in `clear_session()` vs `performance/PerformanceIncidentWriteQueue.gd:15-23,78-84`: `enqueue()` hands the incident Dictionary to the worker **by reference** (deliberately, to avoid a third copy) and `_run_job` serialises it on the thread; `clear_session()` (reachable from `PerformanceOverlay.gd:430`) mutates that Dictionary while the writer may still read it — Dictionaries are not thread-safe. Fix: `_latest_incident = {}` (rebind) or `flush_reports()` first. Risk: none.
- LOW / 65% — `core/systems/world/FlowFieldNav.gd:170-174` — `_exit_tree` cancels and joins but leaves `_building/_use_snapshot/_cancel_requested/_build_task_id` stale; a re-entered node's `_process` (163-167) would fall into `_step_build()` and publish a cancelled build from a stale snapshot. Fix: reset those in `_exit_tree`.
- LOW / 50% — `FlowFieldNav.gd:153,344` — `_cancel_requested` is a plain bool polled by the worker without atomics; benign in practice (one extra BFS loop at worst).
- Verified sound: the worker touches only its own buffers and immutable snapshots; `_ensure_buffers` refuses to resize under a running task (192-194); publish swaps after join; `PerformanceIncidentWriter` uses only thread-safe APIs; both quit paths join via `flush_reports()`.

## 6. Physics-callback misuse

- **HIGH / 75%** — `core/combat/projectile/projectile.gd:55-72` → `autoload/PoolManager.gd:109-165`: `_on_area_entered` → `_despawn()` → `pm.call("recycle", self)` **synchronously inside the projectile's own `area_entered` emission**. `recycle` then sets `monitoring`/`monitorable` (blocked: "Function blocked during in/out signal") and `remove_child(node)` → Area2D EXIT_TREE → `_clear_monitoring()` (also blocked while locked). Every time: three engine errors, the projectile's overlap map keeps the enemy entry (the reused projectile gets no `area_entered` for that hitbox until the hitbox leaves the tree), and with two or more pending events in one flush (a bullet overlapping two hitboxes in a horde) the server-side monitored map is cleared under an in-progress iteration — the historical UAF crash. Only the pooled path is affected: `projectile.tscn` obtained via PoolManager from `spells/logic/Weapon.gd:39`, `MagicMissileSpell.gd:33`, `MagicMissileEffect.gd:92`. `RangedBullet` and `EnemyProjectile` are instantiated fresh and `queue_free()`d. The enemy-death chain (`MeleeSlash._on_area_entered` → … → `despawn` → `recycle(enemy)`) reparents a CharacterBody2D during the flush, which the engine tolerates but drops that hitbox's pending events. Fix (one line in `PoolManager.recycle`): `if node is CollisionObject2D and PhysicsServer2D.is_flushing_queries(): node.set_physics_process(false); call_deferred("recycle", node, context); return`, plus a `_hit` guard in `projectile.gd` like `RangedBullet.gd:150,168`. Risk: recycle lands one frame later; without the guard a projectile could apply damage twice. *(Note: the cleanup audit marks `projectile.gd`/`Weapon.gd` as a legacy chain with no runtime entry from the player path — the exposure is through MagicMissile, which pools `projectile.tscn`.)*
- **MED / 80%** — `effects/augments/logic/PoisonSpiderling.gd:14,29,32 → 113,124` — `_process(dt)` drives `_chase_and_bite()`/`_orbit_player()`, both calling `move_and_slide()` on a CharacterBody2D from the render loop. Moves in render time against a physics-time world; with the 4-step cap, spiderlings outrun everything on a slow machine; jitter if physics interpolation is ever enabled. Fix: `_physics_process` for movement (bite timer/redraw can stay). Risk: bite cadence becomes tick-based.
- Clean: `direct_space_state` users run from `_physics_process` (except `VisionRig._process`, harmless while physics is single-threaded); every `monitoring`/`monitorable`/`disabled` write reachable from a signal uses `set_deferred`; `player.gd:345` writes `collision_mask` only from `_physics_process`/dash start.

## 7. Tick-rate assumptions

- **MED / 75%** — `core/combat/projectile/EnemyProjectile.gd:102-112` — `_process(delta)`: `global_position = old_pos + velocity * delta`; enemy node projectiles integrate in render time while enemies, the player and player projectiles integrate in physics time (`ProjectileSimulationManager.gd:58-84` documents and clamps this). When physics dilates on a weak machine, enemy bullets get relatively faster. Fix: `_physics_process`, or scale `delta` by the manager's physics-time ratio. Risk: hit timing shifts by up to one tick.
- LOW / 90% — `EnemySniper.gd:20,43`, `EnemyTactical.gd:25,43` — `_dt = 1.0 / 60.0` pre-first-tick. Fix: `1.0 / float(Engine.physics_ticks_per_second)`.
- LOW / 80% — `autoload/HitFeel.gd:75` `punch_decay * 60.0 * real_delta` (frame-rate-normalised constant); `PerformanceFlightRecorder.gd:441` "below 60" metric (telemetry only). Fix: name the constants.
- Clean: the scheduler scales `step_delta` by group count; `enemy.gd:263` derives `_simulation_motion_scale` from `get_physics_process_delta_time()`; `EnemyProxySimulation` uses configurable `update_hz`; spawner `/ 60.0` are minutes.

## Top 10 most likely to bite on the next Godot minor or a different machine

1. `projectile.gd:55-72` + `PoolManager.gd:146-165` — pooled Area2D recycled inside its own `area_entered`; errors today, latent crash in dense hordes.
2. `PerformanceFlightRecorder.gd:537` `_latest_incident.clear()` — mutates a Dictionary the writer thread serialises by reference.
3. `EnemyProjectile.gd:102-112` — render-time projectile motion vs physics-time world.
4. `PoisonSpiderling.gd:113,124` — `move_and_slide()` from `_process`.
5. `enemy.gd` recycle paths + `Level1Builder.gd:1441` — pooled nodes stay in `"enemies"`; opening-restore frees the pool; herald/separation see parked ghosts.
6. `PoolManager.gd:74-79` — fallback parent is the `PROCESS_MODE_ALWAYS` autoload.
7. `FlowFieldNav.gd:170-174` — stale post-`_exit_tree` state; unsynchronised cancel flag.
8. Timer lambdas / awaits after free (`GravemarchMassArrest.gd:171`, `player.gd:992`, `spawner.gd:757/765`, `IndoorVolume.gd:162`, `BagUI.gd:389`).
9. `ManifestationCatalog.gd:46` / `ManifestationPairCatalog.gd:19` — static caches without `@static_unload`.
10. `EnemySniper.gd:20,43` / `EnemyTactical.gd:25,43` / `HitFeel.gd:75` — hard-coded 60s.
