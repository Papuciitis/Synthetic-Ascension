# Cleanup audit — consolidated report (2026-08-28)

Branch `enemy-world-work` at `62bbfd3`. **Nothing was modified or deleted**;
this is a ranked catalogue with exact paths, evidence and a recommended action
per finding. "Usage cannot be proven" is always marked REVIEW, never REMOVE.

Sub-reports this document ranks (each carries the full evidence):

| Dimension | Report |
|---|---|
| A. Dead scripts, orphan scenes/resources/assets | `2026-08-28-dead-code-orphans.md` |
| B. Stale docs, comments, version strings | `2026-08-28-stale-docs.md`, `2026-08-28-stale-docs-july-plans.md` |
| C. Duplicate helpers/systems, legacy code paths, dead functions | §C below (token scan + `rg -w`) |
| D. Tests for nonexistent systems, debug-only code, temp files | `2026-08-28-stale-tests.md` + §D below |
| E. Repository size, generated files, `.gitignore` | §E below |
| Cross-cutting constraints | `2026-08-28-save-compatibility.md` (what must never be renamed), `2026-08-28-naming-consistency.md`, `2026-08-28-godot-hygiene.md`, `2026-08-28-logging.md` |

Severity: **HIGH** = ships in the build, costs real bytes/time, or can bite at
runtime; **MED** = maintenance drag or misleading; **LOW** = tidy-up.
Confidence is the reviewer's, after spot-checking the tooling with `rg -w`.
Every REMOVE candidate in §A, §C7 (first paragraph) and §D1.1–D1.3 was
independently re-grepped (all `.gd/.tscn/.tres/.cfg/.ps1` outside `.git`,
`.godot`, `performance_results`, `docs`): each resolves only to its own file
(and, for `selection_card.gd`, two comments in `ui/screens/base.gd:190,197`).

---

## Headline numbers

- 2,413 tracked files, 594.0 MB. **79.3 % of tracked bytes is `performance_results/`** (642 files, 470.8 MB), of which 449.2 MB is JSON no tool reads.
- 1,006 candidate resource/script files graphed from real roots: **~26.4 MiB provably unreferenced** and shipped by `export_filter="all_resources"`; a further 15.8 MB of source PNGs under REVIEW.
- 489 `.gd` scripts: 11 dead scripts, ~9 dead functions with zero callers whose bodies were read, ~60 more zero-caller functions under REVIEW, 56 test-only seams.
- 108 test scripts audited (111 entry points): **0 tests target a nonexistent system**; 3 are REMOVE (assertion-free or superseded benchmarks); 13 are display-only or never-failing probes/benchmarks and 5 are grab-bags or brittle source-grep pins (all REVIEW); 9 silent-skip guard sites.
- Root: 24 loose files from the 0.21–0.25 patch era (manifests, patches, a recovery zip, a stray plan copy); no README.
- Zero `TODO`/`FIXME`/`XXX` markers in the code base.

---

## A. Dead / unused GDScript, orphan scenes, resources and assets

Full evidence in `2026-08-28-dead-code-orphans.md`. Method: `res://` and
`uid://` reference graph over every `.tscn/.tres/.gd`, `project.godot`,
`export_presets.cfg`, the benchmark runner, `.uid`/`.import` sidecars,
`class_name` word usage, `global.gd` path constants, the eight
directory-scan roots and the SFX manifest; transitive reachability from the
main scene, 20 autoloads, dir-scanned data and the runner.

| # | Sev | Conf | Path | Evidence | Action | Risk |
|---|---|---|---|---|---|---|
| A1 | HIGH | 98% | `scenes/boot.tscn`, `scripts/boot.gd` | empty Godot template; no referrer; main scene is `MainMenu.tscn` | REMOVE | none (`scripts/` becomes empty; `project.godot` folder colour dangles) |
| A2 | HIGH | 98% | `scenes/_dev/sprite_2d.tscn`, `assets/textures/new_gradient_texture_2d.tres` | editor scratch; referenced only by each other | REMOVE | none |
| A3 | HIGH | 97% | `ui/components/InventorySlot.tscn` | superseded by `InventorySlotView.tscn` (the one `InventoryBar.tscn` instantiates) | REMOVE | none |
| A4 | HIGH | 95% | `ui/components/SelectionCard.tscn`, `ui/components/selection_card.gd` | header claims RaceCard/PlaystyleCard use it; both attach their own scripts; contains 12 dead stat-alias probes | REMOVE | none |
| A5 | HIGH | 97% | `ui/controllers/HudInventoryController.gd` | `class_name` never mentioned anywhere; `HUD.tscn` wires 13 other controllers | REMOVE | none |
| A6 | HIGH | 95% | `core/actors/enemy/modules/EnemyOrbit.gd` | orbit is inline in `enemy.gd:854`; only mention is `PATCH_MANIFEST.md:258` | REMOVE | none |
| A7 | HIGH | 96% | `core/systems/vision/VisionOverlay.gd`, `vision_overlay.gdshader`, `fog_of_war.gdshader` | `VisionRig.tscn` uses `VisionRig.gd`/`FogOfWar.gd`/`vignette.gdshader`; no other referrer | REMOVE | none |
| A8 | HIGH | 97% | `core/systems/world/SegmentPlan.gd` | `class_name` appears only in its own file; role taken by `proc/DistrictPlan.gd` | REMOVE | none |
| A9 | HIGH | 97% | `scenes/world/cover/CoverWindow.gd` | `CoverWindow.tscn` attaches `CoverWall.gd` with `is_window = true` | REMOVE | none |
| A10 | HIGH | 95% | `assets/vfx/world/augments/VFX_SpiritSlashImpact.tscn/.gd` | `SpiritSlashEffect.tscn` uses `VFX_SpiritSlash.tscn`; class never instantiated | REMOVE | none |
| A11 | MED | 94–96% | `assets/textures/Player_Placeholder.png` (51 KB), `backgrounds/fog_noise_01.png` (149 KB), `covers/game_cover_full.png` (1.8 MB), `covers/game_cover_half.png` (2.6 MB), `covers/window_placeholder_placeholder.png` (1.1 MB), `assets/world/decals/decal_cracks_01.png` (1.7 MB), `decal_stain_01.png` (359 KB) | no referrer; no string-built texture paths anywhere | REMOVE (relocate the two `game_cover_*` if they are store art) | none; 7.7 MB leaves the `.pck` |
| A12 | HIGH | 97% | `assets/world/ground/_legacy_023_noisy/` (14.8 MB), `_legacy_failed_gray_0241/` (3.7 MB), `_legacy_dense_foliage_0242/` (1.4 MB) | every ground load is a literal path into `assets/world/ground/<file>`; mentioned only in prose | REMOVE + UPDATE DOC (`GROUND_TEXTURE_PATCH.md` "Preserved material") | low; in git history |
| A13 | MED | 97% unused | `assets/world/ground/_source_cethiel_cc0_selected/` (15.8 MB, 16 PNG + README) | README says "preserved for future material/shader work" | REVIEW → move out of `res://` or `.gdignore`; keep the README/provenance | none if kept outside `res://` |
| A14 | LOW | 100% | `tools/BatchIconCutter.tscn`, `tools/batch_icon_cutter.gd`, `tools/ProcPlanSmokeTest.gd` | dev tools; `exclude_filter` covers only `tools/tests/*,tools/perf/*` so **they ship** | REVIEW → move under `tools/perf/` or extend the filter | none |
| A15 | LOW | n/a | `data/weapons/StarterMagic.tres` | bare `Resource` with no script/properties, dir-scanned into `weapon_db["magic"]` | REVIEW | none |
| A16 | LOW | — | 26 test entry points not in any recorded sweep (list in the sub-report) | all targets exist; simply never run lately | REVIEW → run once, add to the sweep or delete | none |

Doc citations of files that do not exist (UPDATE DOC): `docs/superpowers/plans/2026-08-26-exit-rite-safeguards.md:390` (`InputBindingServiceTest.tscn`), `2026-07-29-navigation-diagnostics-spawn-filter.md:32,54` (`SpawnFilterTest.tscn`), `2026-07-28-enemy-lifecycle-performance.md:342` (`ProjectileRenderBenchmark.tscn`); `project.godot [file_customization]` colours `res://_archive/`, which does not exist.

Proven KEEP despite looking orphaned: 18 manifest-loaded SFX, 78 directory-scanned `.tres`, `item_test.tres` (guarded by `AuditClosureTest`), all 111 test entry points.

---

## B. Stale documentation, comments, version strings

Full evidence in `2026-08-28-stale-docs.md` (root and `docs/`) and
`2026-08-28-stale-docs-july-plans.md` (plans). The short list:

| # | Sev | Conf | Path | Evidence | Action |
|---|---|---|---|---|---|
| B1 | MED | 95% | Root `*.md` (16 files) | 0.21–0.23 patch-era history (`CHANGE_MANIFEST_0.25.*`, `PATCH_MANIFEST.md`, `RECOVERY_AUDIT.md`, `SEGMENT1_REBUILD.md`, `PROCEDURAL_GENERATION_0.25.*`, …); **no README**; `PROJECT_STRUCTURE.md` predates EnemyWorld/Manifestations | REVIEW → move under `docs/history/`; write a README that points at the roadmap |
| B2 | MED | 95% | `2026-08-19-enemy-world-foundation.md` (repo root) | stray copy of a plan that lives in `docs/superpowers/plans/` | REMOVE (root copy) |
| B3 | MED | 90% | `docs/OPTIMIZATION_HANDOFF.md` | still quotes representation budgets 24/24 (now 64/96) and a Linux environment; §117-118 asks for raw JSON captures to be shared cross-machine (see E1) | UPDATE DOC |
| B4 | MED | 90% | `docs/gamegoal.md` | tags shipped systems (Manifestations, Doctrine, Exit Rite) as DESIGNED; uses "gate" for the Exit Rite | UPDATE DOC |
| B5 | LOW | 100% | `bugfix-0.25.6-to-0.25.6a.patch`, `bugfix-0.25.6a-to-0.25.6b.patch`, `enemy-performance-0.25.5-to-0.25.6.patch`, `PATCH_MANIFEST.sha256`, `STATIC_VALIDATION_0.25.{0,4,5}.json`, `RECOVERY_EDITOR_TMP_ARTIFACTS.zip` | applied long ago; excluded from export; the zip is editor `*.tmp` recovery from 2026-07-21 | REMOVE the zip; move the rest under `docs/history/` or remove |
| B6 | LOW | 100% | `project.godot` `config/version="0.0.0.25.5"` vs patch files/manifests naming 0.25.6, 0.25.6a, 0.25.6b | the only machine-read version is `project.godot` (BuildInfo); the 0.25.6 line exists only in patch names | UPDATE DOC or bump once the numbering is decided |
| B7 | LOW | 100% | `docs/design/MANIFESTATIONS.md:157-173` | "Family" column lists pre-noun tags (stability, rhythm, charge, …) — runtime nouns are `ward, momentum, fortune, cadence, shard` | UPDATE DOC |
| B8 | LOW | 100% | `docs/PERFORMANCE_PATCH_CHANGELOG.md:142` | says `PerformanceLifecycleTest.tscn` "could not complete in a second headless process" — it passes today | UPDATE DOC |
| B9 | LOW | 100% | Stale code comments: `core/actors/enemy/enemy.gd:390-392` ("Spatial buckets remain exact for the projectile manager" — the manager uses EnemyWorld); `tools/tests/EnemyIndexTest.gd:133-134` (names `rebuild_legacy_shadow`, zero callers); `tools/tests/MinigunStressBenchmark.gd:6-7` (per-hit VFX hypothesis, resolved); `ui/components/selection_card.gd` header (see A4) | UPDATE DOC (comments) |
| B10 | info | 100% | `TODO`/`FIXME`/`XXX`/`HACK` markers | **0** in `.gd/.tscn/.tres/.md` | — |

---

## C. Duplicated systems, legacy paths, dead functions

Method: ripgrep over `*.gd/*.tscn/*.tres/project.godot` (excluding `.godot`,
`.git`, `performance_results`) plus a whole-word token scan counting every
occurrence of each `func` name across those file types (so `"name"`,
`&"name"`, `call("name")` and `.tscn` signal bindings count as references);
15 scan hits spot-checked with `rg -w`.

### C1. Enemy population: EnemyIndex vs EnemyWorld vs EnemyCombat

| # | Sev | Conf | Path | Evidence | References | Action | Risk |
|---|---|---|---|---|---|---|---|
| C1.1 | MED | 95% | `autoload/EnemyIndex.gd:800-846` `nearest_enemy`, `:848-884` `first_in_radius`, `:886-921` `gather_in_radius` | Duplicates of `EnemyWorld.gd:633-668` and the `EnemyCombatService.gd:226-254` wrappers. Every gameplay caller (15 files: ManifestationState, Wardstone, MagicMissileEffect, PoisonSpiderling, SpiritSlash, TeslaAura, ReflectShield, ConduitArcBolts, ConduitOverclock, GravemarchMassArrest, GravemarchSunderstep, LatticeAfterstrike, LatticeEchoBuffer, ShardProjectile, MagicImpact, MagicMissileSpell) uses `EnemyCombat.*`. EnemyIndex's versions filter on `e.dead` and return `Node2D`; EnemyCombat's filter `is_dying` and return handles (cover data-only proxies). | Only `tools/tests/EnemyIndexTest.gd:61,69,76` | **REMOVE** the three functions + the assertions at `EnemyIndexTest.gd:58-80`; survivor = `EnemyCombatService` wrappers | None at runtime; one test trimmed |
| C1.2 | HIGH (design) | 90% | `autoload/EnemyIndex.gd` bucket grid: `:6,18-19,113-116,164-168,461-476,560-573,923-983 sample_sep, :985-1031 count_allies, :1033-1058` | A second spatial index that sees only materialized nodes. Consumers: `core/actors/enemy/brains/EnemySeparationSystem.gd:57,105` ← `EnemyHordeNav.gd:87→389-400` (every enemy tick, 60 ms throttle) and `EnemyTactical.gd:90→119-133`. `EnemyWorld`/`EnemySpatialGrid` have no neighbour-sampling equivalent (`rg -i 'separation|sample_sep|count_allies' core/systems/enemy_world/` → nothing). | live | **KEEP now; REVIEW** → migrate `sample_sep`/`count_allies` onto `EnemySpatialGrid.gather_candidate_slots` (`:60`), then delete the EnemyIndex grid (write-only afterwards except `get_debug_counters:511`) | Removing now breaks horde separation and tactical ally counts |
| C1.3 | LOW | 90% | `core/actors/enemy/brains/EnemySeparationSystem.gd:5,8-9,26-47,59-95,107-133` fallback bucket implementation | Runs only when `/root/EnemyIndex` is missing (`:56,:104`); EnemyIndex is a registered autoload. `:22-23` also overwrites `EnemyIndex.cell_size` with this node's export at first lookup without re-bucketing. | unreachable | **REMOVE** the fallback branches (keep the delegation) | None unless the autoload is disabled |
| C1.4 | LOW | 100% | `core/actors/enemy/enemy.gd:390-392` comment "Spatial buckets remain exact for the projectile manager" | `ProjectileSimulationManager.gd:206,256,259,266,284,329` use `EnemyCombat`/`EnemyWorld` only | — | **UPDATE DOC** (comment) | None |
| C1.5 | LOW | 95% | `EnemyCombatService.gd:141-150 apply_damage_to_actor`; `EnemyWorld.gd:613-631 rebuild_legacy_shadow` | Zero callers (token scan + `rg -w`); only the plan doc `2026-08-19-enemy-world-foundation.md:673-717` mentions `rebuild_legacy_shadow`, and `EnemyIndex.prune_invalid:516-590` does its own rebuild | plan doc only | **REMOVE** both; update the plan if kept as history | None |

### C2. Projectiles: packed-array manager vs node scenes

| # | Sev | Conf | Path | Evidence | References | Action | Risk |
|---|---|---|---|---|---|---|---|
| C2.1 | MED | 95% | `core/combat/projectile/projectile.gd:1-72` + `projectile.tscn`, `spells/logic/Weapon.gd:1-60` (`try_attack:23`), `data/WeaponData.gd:7 projectile_scene`, `data/weapons/StarterRanged.tres:4,9` | `projectile.tscn` referenced only by `StarterRanged.tres:4` and `tools/tests/EnemyHandleTargetingTest.gd:5,69` (as a generic Area2D fixture). `Weapon.try_attack` has zero callers; `Weapon` is never instantiated. `Global.weapon_db` is read only at `global.gd:399` to set the string `selected_weapon_id`, whose consumers (`base.gd:169`, `MainMenu.gd:188,243`) only write it back. Player firing goes `player.gd:813-825` → `ProjectileManager.spawn_player`. | test fixture only | **REMOVE** `Weapon.gd`, `projectile.gd/.tscn`; **REVIEW** `WeaponData.projectile_scene` (drop the field; keep `.tres` if `weapon_db` keys matter). Replace the test fixture with an inline Area2D. | Low; one test fixture |
| C2.2 | MED | 90% | `core/actors/player/player.gd:827-850` RangedBullet fallback; `scenes/world/combat/RangedBullet.gd`; hooks `ItemEffectRunner.gd:86-91`, `ManifestationRunner.gd:690-695`, `FirestoneEffect.gd:104-116`, `AnchorRite.gd:157-177` | `ProjectileManager` is an autoload so `player.gd:815` is never null in-game; `apply_to_ranged_bullet` is called only from that fallback. The managed path uses `apply_to_managed_hit_profile` → `apply_to_hit_profile`. `RangedBullet` still instantiated by `autoload/DevSetCollisionTools.gd:15,138` and 3 tests. Dead in file: `RangedBullet.gd:71-72 _exit_tree: pass`, `:74-75 _stop_trail` (zero callers). | DevSetCollisionTools + tests | **REVIEW** — delete the fallback + the 4 `apply_to_ranged_bullet` hooks and port DevSetCollisionTools to `spawn_player`, or document that every new effect must implement both hooks. **REMOVE** `_stop_trail`/empty `_exit_tree` regardless. | DevSetCollisionTools and 3 tests depend on the node scene |
| C2.3 | MED | 95% | `core/actors/enemy/modules/EnemyShooter.gd:373-400` (routes to the manager only when `spec.projectile_scene.resource_path == "res://core/combat/projectile/EnemyProjectile.tscn"`), `scenes/world/bosses/BossArcanistBrain.gd:37,155`, `BossPylon.gd:9,90`, `core/combat/projectile/EnemyProjectile.gd:102-146` | `EnemySpec_Herald.tres:5`, `EnemySpec_Spitter.tres:5` point at `EnemyProjectile.tscn` so ordinary enemies use the manager; only bosses use nodes. `consume_enemy_projectiles_in_radius:461` sees manager projectiles only. | bosses | **REVIEW** → port both boss brains to `ProjectileManager.spawn_enemy`, then **REMOVE** `EnemyProjectile.gd/.tscn`, `global.gd:1245` release call and the string compare | Boss projectile visuals (`set_style` colours) need manager equivalents; reflect/absorb cannot consume boss projectiles today |

### C3. Enemy LOD / scheduler

| # | Sev | Conf | Path | Evidence | Action |
|---|---|---|---|---|---|
| C3.1 | — | 100% | `should_run_reduced_step` family | Already removed; `PerformanceRootCauseFixTest.gd:50` asserts its absence; tier functions in `enemy.gd:413-580` all have live callers | **KEEP** |
| C3.2 | LOW | 95% | `enemy.gd:494-495 run_full_simulation_next_frame`, `:579-580 _set_hitbox_active` | Zero refs (the only other mention of `_set_hitbox_active` is the stray root patch file `enemy-performance-0.25.5-to-0.25.6.patch`) | **REMOVE** |
| C3.3 | LOW | 95% | `enemy.gd:498 is_body_physics_enabled`, `:504 hitbox_roles` | Test-only (4 and 6 refs) | **KEEP** as test seams (mark as such) |
| C3.4 | LOW–MED | 95% | `autoload/EnemySimulationScheduler.gd:409-412 _is_over_budget_pressure`, `:419-420 is_physics_pressure_active`, `:547-548 _measured_pressure_level` | Zero refs | **REMOVE** |
| C3.5 | LOW–MED | 95% | `EnemySimulationScheduler.gd:427-430 physics_release_distance_scale` + exports `pressure_release_distance_scale:55`, `emergency_release_distance_scale:61` | Only `EnemySimulationSchedulerTest.gd:705`; the exports have no other readers (tunables that do nothing in-game) | **REVIEW → REMOVE** function + both exports + the one assertion |
| C3.6 | MED | 95% | Two definitions of "physics pressure": `is_under_physics_pressure:403-406` (`physics_pressure_ms` = 8 ms, used by `FlowFieldNav.gd:687-688`) vs `_pressure_level_for:551-556` (`budget_pressure_ms` 14 / `emergency_pressure_ms` 20, drives tiers and `EnemyProxyRoot.gd:61-62`) | Two systems disagree about one fact | **REVIEW** (see future-bug #3) |

### C4. Pickups and loot

| # | Sev | Conf | Path | Evidence | Action | Risk |
|---|---|---|---|---|---|---|
| C4.1 | MED | 100% | `scenes/world/pickups/ItemPickup.gd:26-33,70-96` and `HealthPickup.gd:13-18,57-84` | Identical magnet constants and pull/`lerpf(60, MAX, pull*pull)`/`move_toward` math; only the retry cooldown (1.5 vs 1.0 s), ItemPickup's `persistent_world_drop` skip and HealthPickup's HP gate differ. In-file duplicates: `ItemPickup._get_screen_pos_of_pickup:130-133` ≡ `_world_to_screen:334-336`; `_is_player:121-127` ≡ HealthPickup `_player_from:97-105`. | — | **REVIEW** → extract a `PickupMagnet` helper (survivor: ItemPickup's superset version); collapse the screen-pos duplicate | Low; keep both cooldowns and the HP gate |
| C4.2 | MED | 100% | Loot recipe at five sites: `EnemyDrops.gd:179-246`, `ExplorationLootSpawner.gd:89-137`, `IndoorVolume.gd:313-350` (near-verbatim copy of the spawner), `CursedVault.gd:91-122`, `HubShop.gd:1422-1429`, `WorldDropSpawner.gd:35-55` | Generation is centralized (`ItemGenerator.create_instance`, `build_item_drop_context`); the pickup wiring is duplicated. Divergences: CursedVault adds immediately while the others `call_deferred("add_child")`; CursedVault retries 8× for `equip_slot >= 0` while the others do not filter; ExplorationLootSpawner adds `rarity_bonus_per_segment`; CursedVault hard-codes `pickup_delay = 0.4`. | — | **REVIEW** → one `ItemPickup.spawn_from_instance(host, inst, pos, opts)`; IndoorVolume delegates to the spawner. Survivor: EnemyDrops' `_new_pickup`/`_defer_pickup` split | Low; preserve deferred add and the `is_exploration_loot`/`secondary_objective_id` flags |

### C5. Spawner entry points

| # | Sev | Conf | Path | Evidence | Action | Risk |
|---|---|---|---|---|---|---|
| C5.1 | MED | 95% | `spawner.gd:261-298 debug_force_spawn`, `:654-690 spawn_burst`, `:749-767 queue_authored_wave`, `:718-737 spawn_beat_member` all funnel into `_spawn_one:312-373` → `_pick_enabled_entry:893-916` → `_spawn_instance_node:378-467` (fine). `spawn_local_encounter:592-613` bypasses it: uses `spawn_table.pick` (`EnemySpawnTable.gd:8-27`, the same weighted roll minus the debug filter), skips per-type caps and pending reservations, and `_pick_local_encounter_pos:615-626` never calls `_is_spawn_position_valid:565-591` (no wardstone-field, authored-bounds or indoor-exclusion checks). `_spawn_instance_node:391-397` re-checks the debug filter, so filtered picks cost an instantiate + free. | IndoorVolume (2 calls) | **REVIEW** → route `spawn_local_encounter` through `_pick_enabled_entry` + a position validator; delete `EnemySpawnTable.pick` if unused afterwards (only caller is `spawner.gd:600`). **KEEP** the three pacing wrappers. | Interior encounters may spawn fewer enemies once caps/filters apply (arguably intended) |

### C6. Helper duplication (repo-wide)

| # | Sev | Conf | Finding | Action |
|---|---|---|---|---|
| C6.1 | LOW | 100% | Test harness `_check/_passes/_failures/_finish` in 90 of 111 `tools/tests/*.gd` | **KEEP** (convention); optional shared base |
| C6.2 | LOW | 100% | `get_first_node_in_group("player")` — 55 occurrences in 40 non-test files; no central accessor (`Global` has no player var) | **REVIEW** → optional `Global.player` cache set by the player |
| C6.3 | LOW | 100% | Percentile/summary helpers ×3: `EnemyPressureBenchmark.gd:256-274`, `EnemyHordeBenchmark.gd:49-54`, `MinigunStressBenchmark.gd:298-303` (byte-identical `_pct`) | **REVIEW** → one `tools/tests/BenchStats.gd` |
| C6.4 | LOW | 100% | `static func release_static_caches` in `WorldArt.gd:111`, `EnemyProjectile.gd:22`, `AugmentActiveBadge.gd:51`, invoked from `global.gd:1244-1246`; no other RID-backed statics exist | **KEEP** (complete pattern); the EnemyProjectile entry goes with C2.3 |
| C6.5 | LOW | 100% | Three value-level duplicate colour constants (RunSheetHUD `ACCENT` ≡ InventoryBar `BORDER_HOVER_STRONG`; RunSheetHUD `BURDEN` ≡ CursedVault `COLOUR`; InventoryBar `BORDER` ≡ InventorySlotView `CORNER_BASE`) | **REVIEW** only if a palette file is introduced |

### C7. Zero-caller functions repo-wide (token scan; `_initialize` SceneTree virtuals excluded)

Safe to **REMOVE** (body read): `EnemySimulationScheduler.gd:409 _is_over_budget_pressure`, `:419 is_physics_pressure_active`, `:547 _measured_pressure_level`; `enemy.gd:494 run_full_simulation_next_frame`, `:579 _set_hitbox_active`; `EnemyCombatService.gd:141 apply_damage_to_actor`; `EnemyWorld.gd:613 rebuild_legacy_shadow`; `RangedBullet.gd:74 _stop_trail`; `spells/logic/Weapon.gd:23 try_attack` (with C2.1).

**REVIEW** (zero refs, body not read in depth): `global.gd:338 add_followers`, `:404 set_run_selection`, `:450 reset_run_augments`, `:984 get_mutation`, `:1013 add_doctrine_rule`, `:1280 has_visited_building`; `SaveManager.gd:41 has_save` (documented in the save-integrity plan; read by `SaveSelect`/`SaveCard` via `_sm.has_save` — verify before touching); `EnemySniper.gd:685 is_winding_up`; `player.gd:410 clear_cinematic_input`; `AugmentRunner.gd:115 get_children_effects`; `EncounterDirector.gd:168 active_beats`, `:172 last_beat_id`; `InventoryRouter.gd:42 _bag_set_origin`, `:48 _bag_clear_origin`; `BurdenSnapshot.gd:66 severity_at`, `:71 active_at`; `LuckResolver.gd:55 augment_quality_bonus`; `ManifestationState.gd:319 claim_batch`, `:417 source_count`, `:465 break_stability`, `:675 is_marked`, `:727 shard_positions`, `:817 nearest_enemy_direction`; `VisionRig.gd:199 get_indoor_rects_world`; `ChunkManager.gd:477-516` (ten `set_/clear_chunk_*` funcs), `:526 reset_world`, `:1275 register_manual_block_world`; `SegmentProcBuilder.gd:461 is_boss_defeated`; `WorldArt.gd:76 ground_base_texture_index`; `RectFacilityCarver.gd:349 _rand_floor_cell`; `StatDelta.gd:27 equals`; `BagInventory.gd:61 set_pending_ui_origin_world`, `:159 add_pickup`, `:439 find_best_slot_for_equip_slot`; `Inventory.gd:87 is_full`; `ItemInstance.gd:231 from_data` (static; `docs/current_game_data.md` still cites it); `SetRunner.gd:159 get_active_effect_keys`; `SetEffectBase.gd:40/43 get_tooltip_short/long`; `PoisonSpiderling.gd:178 _spawn_bite_vfx`; `ConduitOverclockAndFeedback.gd:237 debug_set_overclock`; `GravemarchMassArrest.gd:254 debug_set_bank`; `VFX_TeslaArc2D.gd:43 setup_nodes`; UI: `BagSlot.gd:373 play_merge_flash`, `BagUI.gd:231 set_open`, `:394 _set_inv_origin_from_bag_slot`, `FirstEncounterOverlay.gd:76 is_freeze_active`, `MajorChoice.gd:84 focus_choice`, `Segment1NarrativeOverlay.gd:16 present_opening`, `AugmentActiveBadge.gd:197 _try_set_cd_int_property`; tests `UiConsistencyVisualProbe.gd:125,145`.

Non-test functions referenced only from `tools/tests` (56; **KEEP** as test seams unless noted): `EnemyIndex.gd:848 first_in_radius` (REMOVE per C1.1), `EnemySimulationScheduler.gd:427 physics_release_distance_scale` (REMOVE per C3.5), `EnemyWorld.gd:669 clear_world` (9 refs), `EnemyWorld.gd:222 get_facing`, `HitFeel.gd:160/164`, `PoolManager.gd:226 pool_size_for_scene`, `EnemyDrops.gd:126 finalize_rarity`, `Inventory.gd:188-212` (four polarity readers), `BurdenResolver.gd:130/142 doctrine_tuning/set_doctrine_tuning`, `CursedVault.gd:64 is_opened`, `PrimaryObjective.gd:87 is_activated`, `RunSheetHUD.gd:75/79`, ~15 `debug_*` accessors on EnemyProxyRenderer / PerformanceFlightRecorder / ChunkManager / FlowFieldNav.

---

## D. Tests for nonexistent systems, debug-only code, temporary files

### D1. Tests (per-test verdicts in `2026-08-28-stale-tests.md`)

Every `res://` path, method, property, signal and constant referenced by the
108 audited tests resolves against HEAD — **no test targets a removed
system**. What is stale is the *shape* of some tests:

| # | Sev | Conf | Path | Evidence | Action |
|---|---|---|---|---|---|
| D1.1 | MED | 75% | `tools/tests/EnemySimulationBenchmark.gd/.tscn` | writes dead properties `_far_step_left`/`_far_delta_accum` (silent `.set()` no-ops); no assertions; compares a "population LOD layer" its own comment says is gone; not in the runner | REMOVE |
| D1.2 | MED | 85% | `tools/tests/FlowFieldAllocationBenchmark.gd` | benchmarks a local re-implementation, touches nothing in `FlowFieldNav`; the buffer-shape invariant is pinned by `FlowFieldUnitTest:108-111` | REMOVE |
| D1.3 | LOW | 70% | `tools/tests/ChunkScaleBenchmark.gd/.tscn` | no assertions, always quit(0); same seed/config as `ChunkStreamingPerformanceAudit`, which already emits timing | REMOVE or register in the runner |
| D1.4 | LOW | 70% | `tools/tests/PerformanceFlightRecorderBenchmark.gd/.tscn` | sole assertion duplicates `PerformanceFlightRecorderTest:122`; timing printed, never recorded | REVIEW |
| D1.5 | MED | 75% | Display-only "probes" that hang or pass vacuously headless: `DevConsoleShotProbe` (hangs to its 110 s watchdog), `ObjectiveShotProbe` (zero assertions), `ManifestationHoverProbe`, `ManifestationPlaytestProbe` (quit 0 when no player), `Level1DeterminismProbe` (never compares), `RenderChainProbe` (3 assertions buried in diagnostics), `RoamVisibilityProbe`, `Segment1StoryProbe` (prints FAIL, quits 0), `UiConsistencyVisualProbe` (zero assertions, two dead capture helpers), `EnemyProxyRendererVisualTest` (self-skips with exit 0) | REVIEW → keep as documented windowed tools outside any automated sweep; extract the headless-able assertions (`_verify_pair_shortcut`, `_probe_overheal_is_never_damage`, `_probe_styles_are_all_real`, the Segment 1 exploration-cache check) into real tests |
| D1.5b | LOW | 70% | `tools/tests/ProjectileRenderBenchmark.gd` (pure engine MultiMesh micro-benchmark, zero project code, always exit 0), `tools/tests/StyleDpsBenchmark.gd/.tscn` (balance measurement, zero assertions) | REVIEW → move to `tools/perf/` or remove from the test set |
| D1.6 | LOW | 80% | Grab-bags: `AuditClosureTest` (16 invariants named after the closed July audit), `PerformanceLifecycleTest` (four systems; overlay block byte-identical to `PerformanceOverlayUnitTest:29-42`) | REVIEW → split/rename |
| D1.6b | LOW | 80% | Source-text pins: `StyleParityTest:40-92` and `FirstEncounterPresentationTest:45-52` grep production source with `FileAccess.get_file_as_string` — a comment satisfies them; `RunSheetArchiveTest:204-207` asserts four strings are absent that occur in 0 production files | REVIEW → behavioural checks |
| D1.7 | LOW | 85% | Silent skips: `InterfaceThemeConsistencyTest:90,98` (no assertion before `if != null`), `DevForceSpawnTest:117`, `ManifestationSystemTest:811` (ThreatDirector block inside `_test_dash_hook`), `EnemyPoolTest:126-128`, `RunSheetArchiveTest:102`, `Segment1ProgressionTest:79`, `SpawnFilterTest:74,96`, `StyleParityTest:98` | REVIEW → hard asserts |
| D1.11 | LOW | 95% | `tools/tests/ScriptParseAuditTest.gd` scans `core/ ui/ autoload/ scenes/ effects/ data/` only — `res://assets` (79 VFX `.gd`), `res://spells`, `res://scripts` are never parse-checked | REVIEW → add the three roots (the dead scripts in §A all parse today, so this changes nothing until one rots) |
| D1.8 | LOW | 85% | `tools/tests/AutosaveDebounceTest.gd` writes a real `user://saves/slot_97.tres` (+`.bak`) via `save_current_profile()` and never deletes it; `DevForceSpawnTest` / probes call `start_new_attempt` on the live profile | REVIEW → use a `.test-user-*` dir or delete on `_finish` |
| D1.9 | LOW | 85% | `EnemyHordeBenchmark` gate is windowed-only; `docs/superpowers/plans/2026-08-25-sustained-combat-pressure.md:404` shows it run `--headless`, which silently skips the gate | UPDATE DOC |
| D1.10 | LOW | 100% | `tools/tests/BuildIdentityTest.gd:53,88` uses noun ids `&"Momentum"/&"Shard"/&"Ward"` that never occur at runtime (`&"momentum"` …) | REVIEW (test data only) |

### D2. Debug-only code that ships

`export_presets.cfg:9-11`: `export_filter="all_resources"`, `exclude_filter`
covers `.godot/*, .test-user-*/*, docs/*, performance_results/*, tools/tests/*,
tools/perf/*, RECOVERY_*, *.patch, PATCH_MANIFEST*, STATIC_VALIDATION_*,
CHANGE_MANIFEST_*, DEVELOPMENT_LOG.md`. Everything else that Godot recognises
as a resource is packed. Autoloads cannot be excluded by filter.

| # | Sev | Conf | Path | Evidence | Action | Risk |
|---|---|---|---|---|---|---|
| D2.1 | MED | 100% | Autoloads `DebugEnemySpawnFilter` (`autoload/DebugEnemySpawnFilter.gd`) and `DevSetCollisionTools` (`autoload/DevSetCollisionTools.gd`) — `project.godot [autoload]` | Registered singletons; ship and run in release. `DevSetCollisionTools` is gated by `Global.debug_set_collision_tools = false` at runtime but the node still exists; `DebugEnemySpawnFilter` defaults to PRODUCTION cap mode | REVIEW → gate their `_ready` on `OS.is_debug_build()` or `Global.debug_dev_mode` so release instances are inert | low; tests reach them via `/root/…` |
| D2.2 | MED | 100% | `autoload/global.gd:99-118,1170-1176,1216` debug flags | `debug_enemy_visual_batching = true`, `debug_encounter_beats = true`, `debug_cursed_vault = true` are **production features named `debug_`** and default on; `hard_exit_on_quit = true` is a shipped crash mitigation (`request_quit()` → `OS.kill`) | UPDATE DOC / REVIEW → rename the three feature flags (`feature_` or `enable_`); leave the real `debug_*` (dev mode, god mode, stress test) at `false` | none |
| D2.3 | HIGH | high (logging audit) | `effects/augments/logic/MagicMissileEffect.gd:30,37,42,62,74` (`debug_prints` **defaults true**), `effects/augments/logic/StaminaCoreEffect.gd:37-116` (no flag at all) | 1–3 `print` lines per second in a release build while these augments are held; genuine failures (`player is NULL`, `aura instantiate failed`) hidden as prints | REVIEW → flip the default / add the flag; one-shot `push_warning` for the failure cases (`2026-08-28-logging.md` §1a) | none |
| D2.4 | LOW | 100% | `OS.is_debug_build()` gates: `ui/widgets/PerformanceOverlay.gd:95`, `ui/screens/MainMenu.gd:54` (dev checkbox), `core/actors/player/player.gd:193,224,242`, `ui/augments/AugmentSelect.gd:88,171` | Correctly gated; **but** `DeveloperConsoleTest:67` will fail on a release template because of the overlay gate | KEEP; UPDATE DOC in the test header |
| D2.5 | LOW | 100% | `data/items/defs/item_test.tres`, `assets/textures/item_test.png` | dir-scanned into the item db in release; `runtime_enabled = false` keeps it out of rolls; `AuditClosureTest:45-52` guards it | KEEP (or move under a `.gdignore`d dev folder and adjust the test) | none |
| D2.6 | LOW | 100% | `tools/BatchIconCutter.tscn`, `tools/batch_icon_cutter.gd` (`@tool`), `tools/ProcPlanSmokeTest.gd` | outside the excluded `tools/tests/*,tools/perf/*` → packed | REVIEW → move or extend the filter (see A14) | none |
| D2.7 | LOW | 95% | `ui/widgets/PerformanceOverlay.gd` dev console (`Tests` tab, `grant_pair`, `dev_grant` follower transactions, `_set_total_cap`) | Whole console ships (gated at `:95`); ~1,000 lines of dev UI in the release `.pck` | KEEP (gate is correct); note for size only | none |

### D3. Temporary benchmark / recovery / editor files

| # | Sev | Conf | Path | Evidence | Action |
|---|---|---|---|---|---|
| D3.1 | LOW | 100% | 14 untracked files in `performance_results/benchmarks/` (`horde_*.txt`, `minigun_*.txt`, `enemy-pressure.json`, `enemy-pressure-baseline.json`) | produced by this week's benchmark runs; `enemy-pressure*.json` is regenerated by `EnemyPressureBenchmark` | REVIEW → commit the `.txt` captures that back the commit messages; ignore `enemy-pressure.json` (regenerated), keep `enemy-pressure-baseline.json` tracked (it is the gate's reference) |
| D3.2 | LOW | 100% | `RECOVERY_EDITOR_TMP_ARTIFACTS.zip` (root, 18.5 KB) | editor `*.tmp` recovery files from 2026-07-21, documented by `RECOVERY_AUDIT.md` | REMOVE |
| D3.3 | LOW | 100% | `user://saves/slot_97.tres`, `slot_97.bak.tres` (outside the repo) | left by `AutosaveDebounceTest` on every run | REVIEW (D1.8) |
| D3.4 | info | 100% | Tracked `.log/.tmp/.bak/.orig/.rej/~` files, anything under `.godot/` | **0** | — |
| D3.5 | LOW | 100% | `performance_results/.gitignore` | ignores day folders `2026-08-19/20/21` that no longer exist | REMOVE (stale) once E1/E2 is decided |

---

## E. Repository size and generated files

Baseline @ `c131cd2`: working tree excl. `.git`/`.godot` **566.6 MiB**; `.git` 132.5 MiB (packs 109.7 + 27.1 + 0.27 MB); `.godot` (ignored) 76.9 MB; **2,413 tracked files, 594.0 MB** — `performance_results` 470.8 MB (642 files, **79.3%**), `assets` 118.4 MB (471), everything else ≈ 4.8 MB. By extension: json 449.25 MB (312), png 104.26 MB (148), csv 21.54 MB (309), mp3 11.40 MB (2), gd 3.33 MB (489).

| # | Sev | Conf | Path / pattern | Evidence | Action | Risk |
|---|---|---|---|---|---|---|
| E1 | **HIGH** | 95% | `performance_results/2026-08-{22,23,24}/*.json` (309 files, **449.2 MB = 75.6% of tracked bytes**) | Written by `PerformanceIncidentWriter.gd:17-24` into `res://performance_results` on editor runs (`PerformanceFlightRecorder.gd:26-33`). Nothing reads the JSON: `tools/perf/analyze_captures.py:9,57` globs only `*_segment-NN_*.csv`. One day (08-22) added 309.8 MB. | **GITIGNORE** `/performance_results/20*/*.json` + `git rm --cached` the 309 files (or E2) | Low: export already excludes `performance_results/*` (`export_presets.cfg:11`); only the intent at `PerformanceFlightRecorder.gd:26` / `docs/OPTIMIZATION_HANDOFF.md:117-118` (cross-machine raw sharing) needs a one-line policy update |
| E2 | HIGH | 85% | `performance_results/20*/` day folders (618 files, 470.8 MB) | The existing per-day retirement policy already ignores 2026-08-19/20/21 (`performance_results/.gitignore`) — folders that **no longer exist**, so that file is stale. CSVs (21.5 MB) are the analyzer's real input. | **REVIEW**: ignore whole day folders (`/performance_results/20*/`) or keep CSVs and ignore JSON (E1); then `git rm -r --cached performance_results/2026-08-2[234]`, delete the stale `performance_results/.gitignore`, keep `performance_results/.gdignore` | Same as E1; local copies stay on disk |
| E3 | LOW | 90% | `performance_results/benchmarks/` (22 tracked `*.txt`, 25 KB; 14 untracked `*.txt`/`*.json`, 29 KB) | Written by the three benchmarks; `docs/2026-08-27-improvement-backlog.md` proposes CI artifacts instead | **KEEP** tracked; decide on the 14 untracked (D3.1) | None |
| E4 | MED | 90% | `assets/world/ground/_legacy_*` (28 files, 19.9 MB) and `_source_cethiel_cc0_selected/` (33 files, 15.8 MB) = **35.7 MB of tracked art** | Referenced only by prose (`DEVELOPMENT_LOG.md`, `GROUND_TEXTURE_PATCH.md`, `PATCH_MANIFEST.md`); zero `.tscn/.tres/.gd` references; not `.gdignore`d and not in the export exclude filter → imported and shipped in the `.pck` | **REVIEW → REMOVE** from the tree (or at least `.gdignore`) — A12/A13 | Low; recoverable from history; confirm the CC0 source folder is not needed for attribution |
| E5 | LOW | 80% | `assets/textures/Augment_Placeholder_*.png` (8 files, 22.8 MB, 1365×2048 each) | Used as augment icons by 13 `data/augments/*.tres` | **KEEP** (art pass, not cleanup): ≤512 px would cut ~90% | None |
| E6 | LOW | 85% | `assets/textures/covers/game_cover_half.png` (2.6 MB) | No references outside its own `.import` | **REVIEW** (marketing asset; `.gdignore` or move out of `res://`) — A11 | None |
| E7 | LOW | 90% | Root artifacts: `RECOVERY_EDITOR_TMP_ARTIFACTS.zip` (18.5 KB), `*.patch` (3, 39.8 KB), `PATCH_MANIFEST.md/.sha256`, `STATIC_VALIDATION_*.json` (3), `CHANGE_MANIFEST_*.md` (5) | Added once in `d77f1f3`/`af1fc46`; excluded from export | **REVIEW**: `git rm` the zip; move the patch/manifest set under `docs/history/` if kept | None; ~90 KB |
| E8 | info | 100% | Tracked `.log/.tmp/.bak/.exe/.pck/.orig/.rej/~/.translation`, files under `build/ export/ android/ .godot/` | **0** | KEEP | — |
| E9 | info | 100% | Tracked text files > 200 KB | 309 — all the E1 JSON captures | see E1 | — |

**Git history:** 4,286 blobs, raw 836.6 MB, packed 137.2 MB. The 25 largest blobs are all still tracked (nothing large "deleted but haunting"). `performance_results` across history: 1,562 blobs, raw 700 MB, **packed only 25.2 MB** (JSON gzips ~55:1); 920 of those blobs are already-deleted 08-19/20/21 captures (packed 11.2 MB). `assets`: 481 blobs, **108.9 MB packed (79% of the pack)**, essentially zero churn — legitimately needed. **A history rewrite is not worth it** (≈ −25 MB at best). **Do not use Git LFS for captures** (LFS stores raw bytes → ~28× inflation vs the current pack). `git gc --prune` reclaims ~1 MB.

**`.gitignore` review.** Current root: `.godot/`, `/android/`, `/.worktrees/`, `/build/`, `build_info.json`; plus the stale `performance_results/.gitignore`. Proposed additions (each proven against `git ls-files`): `/performance_results/20*/*.json` (conservative; 309 tracked files need `git rm --cached`) **or** `/performance_results/20*/` (preferred if cross-machine CSV sharing is not needed; 618 files); `/.test-user-*/` (0 tracked; created by the save-integrity test recipe); optional `*.log`, `*.tmp` (0 tracked). Not recommended: LFS; ignoring `*.uid`/`*.import` (Godot 4 wants them versioned, and they are clean).

**Godot-specific:** 491 `.uid` tracked for 489 `.gd` + 5 shaders; **3 `.gd` files have no `.uid` in git or on disk** — `core/systems/world/CursedVault.gd`, `tools/tests/CursedVaultTest.gd`, `tools/tests/ThreatDirectorPressureTest.gd` (Godot generates them on the next editor scan — commit them then). Orphan `.uid`: 0. `.import`: 174 tracked, every one with a source; every importable asset has one. Nothing tracked under `.godot/`; `performance_results/.gdignore` present (keep). No duplicate blobs > 50 KB.

---

## The ten safest cleanup wins

Each is provably unreferenced, excluded from the save format, and reversible
from git history. Suggested order; every step is one commit and one headless
sweep (`ScriptParseAuditTest` + the affected suite).

| # | What | Bytes / lines | Why it is safe |
|---|---|---|---|
| 1 | `.gitignore` `/performance_results/20*/*.json` + `git rm --cached` the 309 JSON captures (E1) | −449 MB tracked | nothing reads them; export already excludes them; local copies stay |
| 2 | Delete `scenes/boot.tscn`, `scripts/boot.gd`, `scenes/_dev/sprite_2d.tscn`, `assets/textures/new_gradient_texture_2d.tres` (A1, A2) | 4 files | editor template/scratch; zero referrers |
| 3 | Delete `ui/components/InventorySlot.tscn`, `SelectionCard.tscn`, `selection_card.gd`, `ui/controllers/HudInventoryController.gd` (A3–A5) | 4 files, ~10 KB | superseded UI; class names never mentioned |
| 4 | Delete `core/actors/enemy/modules/EnemyOrbit.gd`, `core/systems/world/SegmentPlan.gd`, `scenes/world/cover/CoverWindow.gd`, `VisionOverlay.gd` + two shaders, `VFX_SpiritSlashImpact.*` (A6–A10) | 9 files | `class_name` or path appears nowhere else |
| 5 | Delete the three `_legacy_*` ground folders (A12) and update `GROUND_TEXTURE_PATCH.md` | −19.9 MB, leaves the `.pck` | literal-path loads only; prose references only |
| 6 | Delete the 7 loose textures (A11) | −7.7 MB | no referrer, no string-built paths |
| 7 | Remove the nine zero-caller functions whose bodies were read (C7 first paragraph) + `EnemyIndex.nearest_enemy/first_in_radius/gather_in_radius` and their 3 test assertions (C1.1) | ~120 lines | token scan + `rg -w`; the survivors are the EnemyCombat wrappers every caller already uses |
| 8 | Remove `EnemySimulationBenchmark`, `FlowFieldAllocationBenchmark`, `ChunkScaleBenchmark` (D1.1–D1.3) | 6 files | assertion-free or targeting dead properties; not in the runner |
| 9 | Remove `RECOVERY_EDITOR_TMP_ARTIFACTS.zip`, the three `.patch` files, `PATCH_MANIFEST.sha256`, `STATIC_VALIDATION_*.json`; move `CHANGE_MANIFEST_*`, `PATCH_MANIFEST.md`, the 0.25.x root docs and the stray `2026-08-19-enemy-world-foundation.md` under `docs/history/` (B1, B2, B5, E7) | 24 root files | applied/obsolete; excluded from export; history keeps them |
| 10 | Delete the stale `performance_results/.gitignore`; fix the three doc citations of nonexistent `.tscn` test files and the `res://_archive/` folder colour (A16 docs, D3.5) | 5 edits | pure hygiene |

---

## The ten highest-risk legacy areas

Ranked by how likely they are to produce a real bug or a wasted week, not by
size. These are REVIEW items — none should be removed without the work
described.

| # | Area | Why it is risky | What "done" looks like |
|---|---|---|---|
| 1 | **Save format keyed by `res://` paths with no `uid`** (`SaveManager.gd:24-28`; save-compatibility §3) | Renaming or deleting any item `.tres` under `data/items/defs/` or any of `SaveData.gd`, `StashInventory.gd`, `ItemInstance.gd`, `Inventory.gd`, `BagInventory.gd`, `StatDelta.gd` bricks every save that references it — and `SaveSelect` then offers to overwrite the slot. This is the one constraint every cleanup above must respect (none of the REMOVE items is on that list). | `save_version` field; refuse-to-overwrite guard in `SaveSelect`; `.bak` rotation skipped when the primary is unloadable |
| 2 | **Two enemy spatial indexes** — `EnemyIndex` bucket grid (materialised nodes only) vs `EnemyWorld`/`EnemySpatialGrid` (all handles) (C1.2) | Separation and tactical ally counts see only nodes; every gameplay query sees handles. As proxies grow, the two disagree more; "why did the horde stop separating" bugs land here | `sample_sep`/`count_allies` on `EnemySpatialGrid`; EnemyIndex grid deleted |
| 3 | **Two definitions of "physics pressure"** — `is_under_physics_pressure` (8 ms, FlowFieldNav) vs `_pressure_level_for` (14/20 ms, tiers + proxies) (C3.6) | Load-shedding systems trigger at different loads; the benchmark gates one, play hits the other | one threshold table, one accessor |
| 4 | **Boss projectiles as nodes, everything else packed** (C2.3) | Reflect/absorb (`consume_enemy_projectiles_in_radius`) cannot see boss shots; boss visuals depend on `EnemyProjectile.set_style`, which no manager path has | port both boss brains to `ProjectileManager.spawn_enemy`; delete the node path |
| 5 | **RangedBullet fallback + dual effect hooks** (C2.2) | Every new item/manifestation effect must implement `apply_to_ranged_bullet` *and* `apply_to_hit_profile`; the first is dead in play but exercised by `DevSetCollisionTools` and three tests, so it silently rots | port DevSetCollisionTools to `spawn_player`; delete the four hooks |
| 6 | **Pooled `Area2D` recycled inside its own `area_entered`** (godot-hygiene HIGH) | Engine errors today; a latent crash when two pending events target the same pooled body | defer the recycle by one frame |
| 7 | **`spawn_local_encounter` bypasses caps, filters and position validation** (C5.1) | Interior encounters can spawn into wardstone fields / authored bounds and ignore the debug filter — the only spawner path that does | route through `_pick_enabled_entry` + `_is_spawn_position_valid` |
| 8 | **Five loot-drop recipes** (C4.2) | CursedVault adds immediately, others deferred; only CursedVault filters `equip_slot`; the next loot bug will be fixed in one copy | `ItemPickup.spawn_from_instance` |
| 9 | **Typed sub-resource save properties** (`meta_stash`, `attempt_inventory`, `attempt_bag`, `attempt_vendor_bag`, `attempt_mod_stat_delta`) (save-compatibility §4.4) | Changing any of those classes silently nulls the data and the next autosave persists the loss | freeze the five types; migrate under `save_version` |
| 10 | **Display-only probes in `tools/tests/`** (D1.5) | `DevConsoleShotProbe` hangs a headless sweep for 110 s; four probes exit 0 without asserting; a green sweep does not mean what it looks like | move probes out of the sweep; extract their headless-able checks |

---

## Estimated repository size savings

| Scenario | Tracked bytes | Fresh clone | History |
|---|---|---|---|
| A. Ignore + untrack the JSON captures (E1) | **−449.2 MB → ~144.7 MB** | 566.6 → ~120 MiB | 0 (no rewrite) |
| B. Ignore + untrack whole day folders (E2) | **−470.8 MB → ~123.2 MB** | ~117.6 MiB | 0 |
| C. Remove legacy/source ground textures (A12, A13 / E4) | −35.7 MB | same | 0 |
| D. Remove the loose textures (A11) | −7.7 MB | same | 0 |
| E. `git gc --prune=now` | — | — | ≈ −1.2 MB |
| F. History rewrite dropping `performance_results` (not recommended) | — | — | ≈ −25 MB (137 → ~112 MB); needs `git filter-repo` + force-push + re-clone |

Bottom line: ~79 % of tracked bytes are generated captures nothing reads (JSON) or that the existing policy already retires per day; one `.gitignore` line plus `git rm --cached` recovers ~450–471 MB with zero history rewrite. A further ~43 MB of shipped-but-unreferenced art can go from the tree and the `.pck`. The pack itself is dominated by real art and is not a rewrite candidate.

---

## Where old code could cause future bugs

1. **`EnemySeparationSystem.gd:22-23`** overwrites `EnemyIndex.cell_size` with its own export on first lookup without re-bucketing — a silent grid corruption if the two exports ever differ.
2. **`EnemyShooter.gd:373-400`** decides "packed vs node" by comparing `spec.projectile_scene.resource_path` to a literal string; renaming `EnemyProjectile.tscn` silently moves every Herald/Spitter back to node projectiles.
3. **`FlowFieldNav.gd:687-688`** throttles on `is_under_physics_pressure` (8 ms) while everything else uses the 14/20 ms tiers — a scheduler tuning change will not reach the flow field.
4. **`SegmentProcBuilder.gd:80,84`** `queue_free()`s itself on a failed precondition with only a log line (logging audit HIGH) — a future world-gen change produces a segment with no objectives and no exit rite, and nothing in-game says why.
5. **`scenes/game.gd:409,414`** returns with the tree already paused when the death UI is missing — soft-lock path.
6. **`ItemInstance.has_manifestation()`** stays true for a removed manifestation id; `CursedVault.guarantee_manifestation` and `ManifestBadge` are satisfied by a dead id.
7. **`SaveManager.save_slot:103-113`** rotates an unloadable primary into `.bak`, destroying the last good generation — combined with `SaveSelect`'s "EMPTY SLOT / Click to create", one content rename can cost a player both copies.
8. **`global.gd` defaults omitted from saves** — changing any `@export` default on `SaveData` (as `attempt_followers` 1→0 did) silently rewrites every old save.
9. **`spawner.gd:391-397`** re-checks the debug spawn filter *after* instantiating; a filtered pick costs an instantiate + free on every attempt.
10. **Feature flags named `debug_*` that default `true`** (`debug_enemy_visual_batching`, `debug_encounter_beats`, `debug_cursed_vault`): a well-meant "turn all debug flags off for release" sweep would remove three shipped features.
11. **`performance_results/.gitignore`** lists day folders that no longer exist — the next capture day is tracked by default (that is how 449 MB got in).
12. **Dead alias probes** (`selection_card.gd:80-86`, `AugmentActiveBadge.gd:368-371`, `base.gd:220`) hide missing-field errors as silent fallbacks; the same pattern anywhere new will hide the next typo.
13. **`AutosaveDebounceTest` / `DevForceSpawnTest` write the live profile directory** — a test run on a developer's machine can overwrite `slot_97` and, through `start_new_attempt`, touch real profile state.

---

## Status 2026-08-29 — the ten safest wins were executed

One commit per win, `ScriptParseAuditTest` plus the directly affected suites
run green after every deletion batch, every REMOVE candidate re-grepped
(bare identifier and `"name"` string forms) immediately before removal.

| Win | Commit | Note |
|---|---|---|
| 1 JSON captures untracked (+ stale `performance_results/.gitignore`) | `13bebb4` | 309 files, −449 MB tracked; files stay on disk |
| 2 boot template + `_dev` scratch scene | `7a432cb` | |
| 3 InventorySlot / SelectionCard / HudInventoryController | `ae86c60` | two `base.gd` comments reworded |
| 4 EnemyOrbit, SegmentPlan, CoverWindow.gd, VisionOverlay + 2 shaders, SpiritSlashImpact | `0428e8d` | class cache refreshed with `--import` |
| 5 three `_legacy_*` ground folders | `9a0376c` | `GROUND_TEXTURE_PATCH.md` "Preserved material" updated |
| 6 loose textures | `e7d4de0` | **cover art moved, not deleted:** the three `covers/` files now live in `marketing/` under a `.gdignore` |
| 7 zero-caller functions + `EnemyIndex.nearest_enemy/first_in_radius` | `7bfc6cb` | see the two corrections below |
| 8 the three assertion-free benchmarks | `af4e23e` | + two generated `.uid` sidecars |
| 9 root artifacts deleted / moved to `docs/history/` | `2244764` | no markdown links pointed at the old paths |
| 10 doc citations + dangling folder colours | `2f40501` | |

**Corrections to this audit found while executing it**

- **C1.1 is partly wrong.** `EnemyIndex.gather_in_radius` has a live caller
  the token scan missed: `core/actors/enemy/modules/EnemyHerald.gd:66-69`
  resolves `/root/EnemyIndex` with `get_node_or_null` and calls it through
  `has_method`/`call`. It was kept; only `nearest_enemy` and
  `first_in_radius` were removed (their sole callers were EnemyIndexTest).
- **C7 `Weapon.try_attack`** was not removed: it is the whole of `Weapon.gd`
  and belongs with C2.1, which is not one of the ten wins.
- **D3.5** (stale `performance_results/.gitignore`) was folded into win 1.

**Bugfixes taken from the "highest-risk" list, as permitted** (each with a
red→green regression test): `e549847` pooled projectile despawn deferred out
of its own `area_entered` + hit guard (`PooledProjectileRecycleTest`);
`3619ddd` `end_run()` never leaves the tree paused when the game-over UI is
missing (`GameOverFallbackTest`). Note for the godot-hygiene audit: the
suggested `PhysicsServer2D.is_flushing_queries()` guard does not exist in
Godot 4.7.1, and the pooled `projectile.tscn` is obtained only by the dead
`Weapon.gd` — MagicMissile pools `MagicMissileProjectile.tscn` (a Node2D) —
so that finding was latent rather than live. The fix stands for the next
pooled Area2D.

**Regression sweep after the series:** 85 suites on `2dca035` (the 82 from the pre-series baseline plus PooledProjectileRecycleTest, GameOverFallbackTest, SaveSelectUnreadableSlotTest): **0 failures**; the only script-error lines are the corrupt save fixtures that SaveIntegrityTest and SaveSelectUnreadableSlotTest parse on purpose. Four suites exited non-zero — DevConsoleShotProbe, ManifestationHoverProbe, ObjectiveShotProbe, UiConsistencyVisualProbe — all display-only probes hitting their own watchdogs because this runner no longer quits them by frame count; that is the vacuous-pass behaviour the stale-tests audit documents, not a regression.
