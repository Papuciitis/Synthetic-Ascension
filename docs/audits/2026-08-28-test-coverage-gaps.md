# Audit — test coverage gaps (2026-08-28)

Branch `enemy-world-work`; read-only, nothing created or modified in the
repository. Which production scripts and behaviours have **no** automated
test, ranked by how bad an undetected regression there would be.

## Method and evidence

- **Production inventory**: `find autoload core ui scenes scripts effects spells data -name '*.gd'` (addons/.godot excluded) → **329 scripts**. `assets/vfx/**/*.gd` (47 pure-VFX scripts) catalogued separately in Appendix B.
- **Autoloads**: `[autoload]` block of `project.godot` (21 entries; `uid://` targets resolved through the `.gd.uid` files — e.g. `Global` → `autoload/global.gd`, `InvRouter` → `core/systems/inventory/InventoryRouter.gd`, `PoolManager` → `autoload/PoolManager.gd`).
- **Test inventory**: `tools/tests/*.gd` → 111 scripts (88 with a `.tscn`; 23 are `extends SceneTree` scripts with no scene). Plus `tools/ProcPlanSmokeTest.gd` outside the folder. Breakdown: 10 benchmarks, 10 probes, 2 audits (`ScriptParseAuditTest`, `ChunkStreamingPerformanceAudit`), 89 asserting tests.
- **Coverage evidence**, all grep-based, no guessing:
  - class_name: `grep -owE '\b(<all 247 class_names>)\b' tools/tests/*.gd`
  - autoload name: `grep -owE '\b(Global|SaveManager|SettingsManager|RunEvents|ThreatDirector|InvRouter|EnemyIndex|EnemyWorld|EnemyCombat|EnemyStatus|EnemySimulationScheduler|HitFeel|DebugEnemySpawnFilter|PerformanceFlightRecorder|PoolManager|AudioManager|SfxManager|ProjectileManager|BattleText|FollowerFeedbackUI|DevSetCollisionTools)\b' tools/tests/*.gd`
  - resource path: `grep -oE 'res://(autoload|core|ui|scenes|scripts|effects|spells|data)/[^"]+\.(gd|tscn)' tools/tests/*.gd tools/tests/*.tscn`
  - scene closure: every `.tscn` a test references, expanded through `ext_resource path="...tscn"` to the scripts attached (`ext_resource path="...gd"`); e.g. `ui/screens/HUD.tscn` (instantiated by DevSegmentTest, Segment1ProgressionTest, Segment1TileIntegrationTest, WorldTileIntegrationTest, InterfaceThemeConsistencyTest) pulls in `hud.gd` and 12 `Hud*Controller` scripts.
  - basename word-match for the ~50 scripts with no `class_name` (weak; only used where nothing else matched).
- **Not counted as coverage**: `tools/tests/ScriptParseAuditTest.gd` `load()`s every `.gd` under core/ui/autoload/scenes/effects/data and asserts `can_instantiate()` — a parse check only (and it skips `spells/`, `scripts/` and `assets/`). Also not counted: `PerformanceRootCauseFixTest.gd` lines 115–160, which read 22 scripts with `FileAccess.get_file_as_string()` and string-search them (BossArena, MiniBossArena, EnemyLifecycle, the four set-effect scripts, etc.). Scripts whose only "reference" is one of these are treated as uncovered below and marked *source-scan only*.

## Summary counts

| | Count |
|---|---|
| Production scripts (autoload/core/ui/scenes/scripts/effects/spells/data) | **329** |
| Covered (direct reference, or instantiated through a scene a test loads, or constructed by production code a test verifiably drives) | **211** |
| — of which reached *only* through a parent-scene instantiation with none of their methods called | ~44 |
| — of which reached only transitively (constructed by production code under test) | 11 (see notes in tables) |
| **Uncovered** | **118** |
| — HIGH risk | **51** |
| — MEDIUM risk | **38** |
| — LOW risk (incl. 6 probable orphans) | **29** |
| `assets/vfx` scripts (Appendix B) | 47 (13 reached via scene closure, 34 never loaded; all pure visuals) |

Raw reference-only classification was 190 covered / 139 uncovered; 29 scripts were moved to covered on verified transitive evidence (18 manifestation logic scripts constructed by `ManifestationSystemTest` line 106 `def.logic.new()`; 6 MCE/MajorChoiceEffect scripts applied via `effect.apply(Global)` in `AscensionDoctrineGameplayTest` line 45; `EnemyDeathContext` fields asserted in `EnemyDeathEventTest` lines 61–66; `EnemyProxyRoot` looked up by group in `EnemyProxyRolloutTest` line 100; `DisplaySettingsAdapter` preloaded by `SettingsRuntimeApplier` whose `apply_all/begin_display_preview/revert_display_preview` are called by `SettingsRuntimeTest`; `DoctrineRewardService` via `Global.grant_doctrine_secondary_rewards`; `BindingRow` via `SettingsScreen.gd` line 6/261 under `SettingsScreenTest`), and 8 were moved to uncovered because their only reference is a source-text scan or a filename string.

---

## Uncovered scripts — HIGH risk (51)

Confidence key: **proven none** = no class_name/autoload/path/scene/basename hit in tools/tests; **transitive-construct** = no test references it, but production code that a test drives constructs it (behaviour never asserted); **source-scan only** = referenced only by `FileAccess.get_file_as_string` string checks.

| Path | Lines | Autoload / class_name | Why it matters | Minimal test would assert | Evidence / confidence |
|---|---|---|---|---|---|
| core/systems/inventory/InventoryRouter.gd | 265 | autoload `InvRouter` / `InventoryRouter` | Single choke point for equip↔bag↔stash moves and world drops (`eject_equipped_to_bag`, `equip_from_bag`, `move_between`, `drop_from`); used by BagUI, InventoryBar, HubShop, hud.gd, InventoryStash, WorldDropSpawner. A regression silently loses or duplicates items. | `equip_from_bag` moves the instance out of the bag slot and into the equip slot exactly once, `move_between` refuses invalid slots, `drop_from` emits `dropped_to_world`. | `grep -lw InvRouter tools/tests` → none; `grep -l InventoryRouter tools/tests` → none. **proven none** |
| ui/screens/InventoryStash.gd | 558 | `InventoryStash` | Stash↔bag transfer screen; stash contents are copied into `SaveData.meta_stash` (SaveIntegrityTest covers the copy, not the screen that fills it). | Instantiating the scene with a seeded bag/stash and invoking a transfer updates both inventories and leaves counts consistent. | `grep -l InventoryStash tools/tests` → none; `InventoryStash.tscn` not in any test scene closure. **proven none** |
| core/combat/projectile/EnemyProjectile.gd | 166 | `EnemyProjectile` | Enemy ranged damage to the player (`p.call("take_damage", damage, self)` line 145); spawned by EnemyShooter, BossArcanistBrain, BossPylon, Spitter/Herald specs. | A projectile overlapping a `player_hurtbox` calls `take_damage` with its configured damage exactly once and then frees. | `grep -l EnemyProjectile tools/tests` → none. **proven none** |
| core/combat/hazards/DamageCircle.gd | 61 | `DamageCircle` | Area damage hazard used by BossMine and BossBulldozerBrain. | Player inside `radius` takes `damage` once within `lifetime`; outside takes none. | `grep -l DamageCircle tools/tests` → none. **proven none** |
| effects/items/logic/FirestoneEffect.gd | 180 | `FirestoneEffect` | Item effect scene instantiated by `ItemEffectRunner.refresh_effects` when the item is equipped; damage/burn payout. | Equipping the item through `ItemEffectRunner.refresh_effects` instantiates the effect and it applies its modifier to a hit profile. | `grep -l Firestone tools/tests` → none; no test calls `refresh_effects` (`grep -n refresh_effects tools/tests/*.gd` → none). **proven none** |
| effects/items/logic/OakheartShieldEffect.gd | 143 | `OakheartShieldEffect` | Damage-taken reduction item effect. | `get_damage_taken_multiplier` on the runner reflects the effect after equip. | as above. **proven none** |
| effects/items/logic/RegenerationRingEffect.gd | 101 | `RegenerationRingEffect` | Regen item effect; `ring_regeneration.tres` is loaded by AuditClosureTest but the effect scene is never instantiated. | Player HP rises by the configured rate over N ticks after equip. | `grep -n ring_regeneration tools/tests` → only AuditClosureTest lines 220/389 (loads ItemData). **proven none** |
| effects/items/logic/SpeedRingEffect.gd | 97 | `SpeedRingEffect` | Move-speed item effect (`ring_crusher.tres`). | `get_move_speed_multiplier` > 1 after equip, back to 1 after unequip. | same. **proven none** |
| effects/items/logic/curses/SlowHeartCurse.gd | 105 | — | Curse: healing rate cap ("negative_effect_scenes"). BurdenSystemTest line 119 checks that negative items declare scenes, never instantiates them. | Healing above the cap is clamped; below the cap unchanged. | `grep -l SlowHeart tools/tests` → none. **proven none** |
| effects/items/logic/curses/SourProvidenceCurse.gd | 62 | — | Curse affecting luck/providence. | Luck modifier applied while equipped and removed on unequip. | none. **proven none** |
| effects/items/logic/curses/TitheBonesCurse.gd | 88 | — | Curse that taxes on hit (uses BattleText). | Tithe deducted on the configured trigger. | none. **proven none** |
| core/systems/manifestations/ManifestationPairEffect.gd | 59 | `ManifestationPairEffect` | Base class of all 10 pair rules. | A pair effect receives `setup` with both member ids and its hooks fire. | `grep -l ManifestationPairEffect tools/tests` → none; tests only call `ManifestationPairCatalog.all_ids/active_for_counts`, never `.logic.new()` for pairs. **proven none (headless)** — `grant_pair` is only exercised by display probes DevConsoleShotProbe/ManifestationHoverProbe. |
| effects/manifestations/pairs/BadFortuneEngine.gd | 171 | — | Pair rule (misfortune→damage). | Construct via `ManifestationPairCatalog.get_def(id).logic.new()`, call the hit hook, assert the modifier. | as above. **proven none (headless)** |
| effects/manifestations/pairs/DeathRattle.gd | 255 | — | Pair rule on death. | same pattern. | **proven none (headless)** |
| effects/manifestations/pairs/DebtCollector.gd | 276 | — | Pair rule. | same. | **proven none (headless)** |
| effects/manifestations/pairs/Loom.gd | 187 | — | Pair rule. | same. | **proven none (headless)** (word "Loom" appears in BuildIdentityTest/ManifestationPlaytestProbe only as a pair id string) |
| effects/manifestations/pairs/MarchingOrder.gd | 180 | — | Pair rule. | same. | **proven none (headless)** |
| effects/manifestations/pairs/PilgrimsToll.gd | 227 | — | Pair rule. | same. | **proven none (headless)** |
| effects/manifestations/pairs/RedLine.gd | 256 | — | Pair rule. | same. | **proven none (headless)** |
| effects/manifestations/pairs/ReliquaryGuard.gd | 194 | — | Pair rule. | same. | **proven none (headless)** |
| effects/manifestations/pairs/SlipstreamFoundry.gd | 191 | — | Pair rule. | same. | **proven none (headless)** |
| effects/manifestations/pairs/TitheRhythm.gd | 192 | — | Pair rule. | same. | **proven none (headless)** |
| effects/manifestations/ManifestationShardProjectile.gd | 108 | `ManifestationShardProjectile` | Damage projectile launched by shard manifestations (3 production users). | Spawned shard hits an EnemyWorld handle and applies damage through EnemyCombat. | `grep -l ManifestationShardProjectile tools/tests` → none. **proven none** |
| effects/conduit/scenes/ConduitOverclockAndFeedback.gd | 445 | — | Conduit set tier effect (damage/feedback). | Activating the set tier through SetRunner instantiates it and its hit hook modifies damage. | only `PerformanceRootCauseFixTest.gd:149` string scan. **source-scan only** |
| effects/gravemarch/scenes/GravemarchMassArrest.gd | 362 | — | Gravemarch set effect (stun/arrest). | same pattern. | **source-scan only** |
| effects/gravemarch/scenes/GravemarchSunderstep.gd | 82 | `GravemarchSunderstep` | Gravemarch set effect. | same. | class hit only in PerformanceRootCauseFixTest (string list). **source-scan only** |
| effects/lattice/scenes/LatticeAfterstrike.gd | 93 | `LatticeAfterstrike` | Lattice set effect (echo damage). | same. | **source-scan only** |
| effects/augments/logic/HexBlinkMarkEffect.gd | 270 | `HexBlinkMarkEffect` | Player active augment: blink + mark damage. | `AugmentRunner` equip instantiates it; triggering the active applies the mark and respects cooldown (`active_cd_changed`). | `grep -l HexBlink tools/tests` → none. **proven none** |
| effects/augments/logic/StaminaCoreEffect.gd | 213 | `StaminaCoreEffect` | Player active augment altering stamina/dash. | Cooldown and stat delta applied on activation. | none. **proven none** |
| core/systems/major_choice/effects/MCE_AddMutation.gd | 39 | `MCE_AddMutation` | Major-choice effect (weapon mutation) used by `major_magic_trisigil`, `major_melee_dual_slash`, `major_ranged_shotgun`. | `apply(Global)` adds the mutation id; applying twice is idempotent. | doctrine tests only apply `doctrine_*`/`method_*` ids (`grep -ohE 'doctrine_[a-z_]+' tools/tests/AscensionDoctrine*.gd`); `major_*` never applied. **transitive-none** |
| core/systems/major_choice/effects/MCE_AddBackpackSlots.gd | 23 | `MCE_AddBackpackSlots` | Grows bag slot count (`major_satchel`). | Bag slot count increases by the configured amount and persists into the run. | same. **transitive-none** |
| core/systems/major_choice/effects/MCE_GrantItemRoll.gd | 36 | `MCE_GrantItemRoll` | Grants an item roll (`major_relic_crusher_ring`). | An item instance lands in the bag with the expected rarity floor. | same. **transitive-none** |
| core/systems/world/opening/OpeningSequenceController.gd | 438 | `OpeningSequenceController` | Drives the new-run opening (phases, `sequence_finished`); a stall blocks starting a run. | Advancing phases headless ends in `sequence_finished` and hands control to the game. | `grep -l OpeningSequenceController tools/tests` → none (only `OpeningActor.tscn` is instantiated, by EnemyLegacyCombatCompatibilityTest). **proven none** |
| core/systems/world/opening/OpeningSequenceWorld.gd | 69 | `OpeningSequenceWorld` | Stage activation for the opening. | `stage_activated` fires in order. | none. **proven none** |
| ui/screens/base.gd | 394 | — (attached to ui/screens/base.tscn, `Global.PATH_BASE`) | Run-setup screen: race/style pick → `Global.start_new_attempt()` → `Global.goto_game()` (lines 385–387). The only UI path that starts a run. | Selecting a race and style and pressing StartRun records a new attempt and requests the game scene. | basename "base" hits are unrelated words; `base.tscn` in no test closure. **proven none** |
| core/actors/enemy/modules/EnemyShooter.gd | 432 | `EnemyShooter` | Ranged enemy attack module (spawns EnemyProjectile). | With a SHOOTER spec and a player in range, a projectile is spawned after the peek/windup timers. | class not in any test; constructed as member `_shooter` in enemy.gd:157 for every enemy.tscn test. **transitive-construct** |
| core/actors/enemy/modules/EnemyCharge.gd | 69 | `EnemyCharge` | Charge attack windup/impact. | Windup elapses then a charge impulse and hit occur once per cooldown. | **transitive-construct** |
| core/actors/enemy/modules/EnemyLeech.gd | 66 | `EnemyLeech` | Contact-damage leech loop on player hurtbox. | Overlapping the hurtbox ticks damage at the configured rate and stops on exit. | **transitive-construct** |
| core/actors/enemy/modules/EnemySplitter.gd | 112 | `EnemySplitter` | Spawns child enemies on death (spawning/pooling). | Death of a SPLITTER produces N children via the spawner and respects caps. | **transitive-construct** |
| core/actors/enemy/modules/EnemySummoner.gd | 136 | `EnemySummoner` | Summons minions on cooldown (spawning). | Summon count never exceeds the hard cap and minions are registered in EnemyIndex/EnemyWorld. | **transitive-construct** |
| core/actors/enemy/modules/EnemyInit.gd | 155 | `EnemyInit` | Applies spec stats / threat scaling on spawn (stat math). | Configured HP/damage match spec × ThreatDirector multipliers. | **transitive-construct** |
| core/actors/enemy/modules/EnemyLifecycle.gd | 119 | `EnemyLifecycle` | Death → drops → pool return path. | Killing an enemy returns it to PoolManager and unregisters it once. | only `PerformanceRootCauseFixTest.gd:115` string scan (+ member construction). **source-scan only** |
| scenes/world/events/BossArena.gd | 266 | `BossArena` | Boss encounter: arena gating, boss scaling, wave spawning. | Entering the arena spawns the boss with scaled stats and unlocks on kill. | only `PerformanceRootCauseFixTest.gd:117` string scan. **source-scan only** |
| scenes/world/events/MiniBossArena.gd | 252 | `MiniBossArena` | Mini-boss encounter scaling/spawn. | same pattern. | `PerformanceRootCauseFixTest.gd:118` only. **source-scan only** |
| scenes/world/bosses/BossArcanistBrain.gd | 243 | — | Boss AI (fan shot → EnemyProjectile). | Fan attack fires the configured projectile count after telegraph. | `grep -l BossArcanist tools/tests` → none. **proven none** |
| scenes/world/bosses/BossBulldozerBrain.gd | 226 | — | Boss AI (slam → DamageCircle). | Slam spawns a DamageCircle after windup. | none. **proven none** |
| scenes/world/bosses/BossBeamSweep.gd | 99 | `BossBeamSweep` | Beam damage sweep. | Player in the beam during sweep takes damage; not during telegraph. | none. **proven none** |
| scenes/world/bosses/BossMine.gd | 53 | `BossMine` | Delayed area damage. | After `fuse`, a DamageCircle of `radius`/`damage` is spawned. | none. **proven none** |
| core/systems/world/objectives/BreachSealObjective.gd | 183 | `BreachSealObjective` | Primary objective (gates the Exit Rite). | `PrimaryObjectiveCatalog.create_for` with a breach seed yields it; visiting three breaches finishes it. | class only in ObjectiveShotProbe (display probe). **proven none (headless)** |
| core/systems/world/objectives/WardVigilObjective.gd | 175 | `WardVigilObjective` | Primary objective (hold the circle). | Standing in the circle for hold time finishes; leaving pauses. | none. **proven none** |
| core/systems/world/objectives/DistrictRelayObjective.gd | 105 | `DistrictRelayObjective` | Primary objective; `PrimaryObjectiveTest.gd:76` only asserts `pick_id(2, …) == &"district_relay"`, never creates it. | `create_for(2, seed)` returns a DistrictRelayObjective and three site visits finish it. | class not referenced. **proven none** |

## Uncovered scripts — MEDIUM risk (38)

| Path | Lines | Autoload / class_name | Why it matters | Minimal test would assert | Evidence / confidence |
|---|---|---|---|---|---|
| autoload/AudioManager.gd | 161 | `AudioManager` | Music crossfade between menu/game contexts. | Switching context swaps the stream and the fade completes. | `grep -lw AudioManager tools/tests` → none. **proven none** |
| autoload/SfxManager.gd | 329 | `SfxManager` | ID-based SFX playback from `sfx_manifest.txt`; 11 production callers. | Manifest parses, every referenced id resolves to a loadable stream, unknown ids don't crash. | none. **proven none** |
| core/combat/BattleTextRenderer.gd | 262 | autoload `BattleText` | Batched floating damage text; called from 10 scripts on every hit. | `push`-style call enqueues an entry and it expires after lifetime. | `grep -lw BattleText tools/tests` → none. **proven none** |
| core/actors/enemy/brains/EnemyHordeNav.gd | 413 | `EnemyHordeNav` | Horde navigation over the flow field. | Direction sampled from FlowFieldNav moves toward lower cost. | **transitive-construct** (enemy.gd:167) |
| core/actors/enemy/brains/EnemyNavigator.gd | 312 | `EnemyNavigator` | SEEK/WALL point-to-point navigator. | Blocked corridor switches to WALL mode and re-seeks when clear. | **transitive-construct** |
| core/actors/enemy/brains/EnemySenses.gd | 179 | `EnemySenses` | Line-of-sight raycasts to the player. | LOS false through a blocker, true in the open. | **transitive-construct** |
| core/actors/enemy/modules/EnemyTactical.gd | 313 | `EnemyTactical` | "Commit if allies nearby" behaviour. | Commit flag flips when `count_allies` crosses the threshold. | **transitive-construct** |
| core/actors/enemy/modules/EnemyHerald.gd | 93 | `EnemyHerald` | Pulse buff to nearby enemies. | Pulse applies to allies in radius on cooldown. | **transitive-construct** |
| core/actors/enemy/modules/EnemySummoned.gd | 28 | `EnemySummoned` | Summoned-minion controller (`EnemySummoner.gd:85`). | Minion despawns when its summoner dies or lifetime expires. | **proven none** (constructed only by EnemySummoner) |
| effects/augments/logic/SpiderlingSummonEffect.gd | 278 | `SpiderlingSummonEffect` | Active augment that spawns PoisonSpiderling (spiderling itself is covered by EnemyHandleTargetingTest). | Activation spawns the configured count and respects cooldown. | none. **proven none** |
| effects/SetEffectBase.gd | 45 | `SetEffectBase` | Base for set effects (tooltips, effect_id). | Subclass exposes id/tooltip after setup. | **transitive** (ConduitArcBolts/LatticeEchoBuffer tests construct subclasses) |
| core/systems/spawner/EnemySpawnEntry.gd | 29 | `EnemySpawnEntry` | Spawn table weights. | Weighted pick distribution matches weights. | `SpawnTable_Default.tres` loaded by SpawnFilterTest:90 (resource load only). **transitive-load** |
| core/systems/spawner/EnemySpawnTable.gd | 30 | `EnemySpawnTable` | Spawn table container. | same. | same |
| core/systems/vision/SeenGrid.gd | 52 | `SeenGrid` | Persistent "seen" memory for fog. | Marking a cell seen persists across chunk boundaries. | used only by VisionRig (scene-only). **transitive-construct** |
| core/systems/world/WorldArt.gd | 147 | — | Centralised texture access for chunk generation. | Every referenced texture path loads. | preloaded by ChunkManager (covered). **transitive** |
| core/systems/world/Level1MilestoneArea.gd | 51 | `Level1MilestoneArea` | Emits `reached(milestone_id)` for segment-1 progression. | Player entering the area emits once. | built by Level1Builder in game.tscn tests; Segment1ProgressionTest asserts `Global.record_segment1_milestone` indirectly. **transitive-construct** |
| core/systems/world/proc/ChunkGenImpl.gd | 381 | `ChunkGenImpl` | Chunk content generator driven by `ChunkManager.process_chunk_generation_queue` (called in chunk tests). | Same seed + coords → identical ChunkBuildData. | **transitive** |
| core/systems/world/proc/chunkgen/ChunkGenDistrict.gd | 651 | — | District chunk layout (loot spawners, indoor volumes). | Determinism and connector mask consistency. | **transitive** |
| core/systems/world/proc/chunkgen/ChunkGenStamp.gd | 326 | — | Floor/wall stamps. | Stamp writes stay inside chunk bounds. | **transitive** |
| core/systems/world/proc/chunkgen/ChunkGenStructures.gd | 286 | — | Structure placement. | Structures never overlap connectors. | **transitive** |
| core/systems/world/proc/chunkgen/ChunkGenWalls.gd | 137 | — | Wall carving. | Perimeter wall kinds match neighbour masks. | **transitive** |
| core/systems/world/proc/chunkgen/ChunkGenArchetypes.gd | 125 | — | Archetype tables. | Every archetype id resolves. | **transitive** |
| core/systems/world/proc/chunkgen/ChunkGenDeco.gd | 7 | — | Decoration stub. | (trivial) | **transitive** |
| core/systems/world/proc/SiteManager.gd | 51 | `SiteManager` | Facade over site overlay/parcels. | Site lookup deterministic per seed. | **transitive** |
| core/systems/world/proc/SiteOverlayImpl.gd | 394 | `SiteOverlayImpl` | Multi-chunk site overlay. | Overlay for (seed, coords) stable and readable. | **transitive** |
| core/systems/world/proc/SiteParcelsImpl.gd | 522 | `SiteParcelsImpl` | Parcels → IndoorVolume/RoofOverlay instantiation. | Parcels produce non-overlapping volumes. | **transitive** |
| core/systems/world/proc/DonjonCarver.gd | 417 | `DonjonCarver` | Interior carver. | Carve result rooms are connected. | **transitive** |
| core/systems/world/proc/RectFacilityCarver.gd | 361 | `RectFacilityCarver` | Room-first facility carver. | Every room reachable from a corridor. | **transitive** |
| core/systems/world/proc/SegmentThemeData.gd | 157 | `SegmentThemeData` | Theme data for segments. | Picker output references only existing theme ids. | SegmentThemePicker is referenced by `tools/ProcPlanSmokeTest.gd` (outside tools/tests) only. **transitive** |
| scenes/world/volumes/IndoorVolume.gd | 399 | `IndoorVolume` | Indoor visibility volumes carrying secondary-objective ids. | Entering the volume toggles roof/indoor state. | Segment1ProgressionTest:108 counts live instances with ids (asserted transitively). **transitive-construct** |
| scenes/world/pickups/HealthPickup.gd | 137 | `HealthPickup` | Heal pickup dropped by EnemyDrops. | Overlap heals the player by the configured amount and frees. | only a filename string compare in MinigunStressBenchmark:180. **proven none** |
| ui/screens/AugmentLibrary.gd | 336 | `AugmentLibraryScreen` | Permanent-augment library/equip screen (meta progression). | Equipping from the library updates `Global.set_permanent_augment`. | none; `AugmentLibrary.tscn` not in any closure. **proven none** |
| ui/widgets/AugmentLibraryEntry.gd | 114 | `AugmentLibraryEntry` | Library row. | Displays level/name for an AugmentData. | **proven none** |
| ui/widgets/AugmentEquipSlot.gd | 96 | `AugmentEquipSlot` | Equip slot for augments. | Drop accepts only augments. | **proven none** |
| ui/widgets/HubItemSlot.gd | 204 | `HubItemSlot` | Shop/stash drag-drop slot (EQUIPPED/BAG/STASH kinds). | Drag between kinds routes via InvRouter with the right indices. | **proven none** |
| ui/components/PlaystyleCard.gd | 68 | — | Style pick card on the run-setup screen. | Pressing selects the style. | **proven none** |
| ui/components/RaceCard.gd | 81 | — | Race pick card. | Pressing selects the race. | **proven none** |
| ui/components/selection_card.gd | 168 | — | Listed here for completeness; it is **dead** (`2026-08-28-dead-code-orphans.md` A4) — no test needed, remove instead. | — | **proven none / orphan** |

## Uncovered scripts — LOW risk (29)

| Path | Lines | class_name | Why it matters | Minimal test | Evidence / confidence |
|---|---|---|---|---|---|
| core/combat/projectile/ImpactBurstRenderer.gd | 152 | `ImpactBurstRenderer` | Batched impact visuals (used by ProjectileSimulationManager). | Burst count bounded. | **proven none** (needs renderer for pixels) |
| core/actors/player/PlayerAimReticle.gd | 27 | `PlayerAimReticle` | Reticle visual. | — | **proven none** |
| core/actors/enemy/modules/EnemyOrbit.gd | 22 | `EnemyOrbit` | Dead (dead-code audit A6; not constructed in `enemy.gd:149-167` where every other module is). | — | **orphan** |
| ui/controllers/HudInventoryController.gd | 223 | `HudInventoryController` | Orphan (dead-code audit A5). | — | **orphan** |
| core/systems/vision/VisionOverlay.gd | 48 | — | Orphan (A7). | — | **orphan** |
| core/systems/world/SegmentPlan.gd | 136 | `SegmentPlan` | Orphan (A8). | — | **orphan** |
| scenes/world/cover/CoverWindow.gd | 19 | — | Orphan (A9; `CoverWindow.tscn` attaches `CoverWall.gd`). | — | **orphan** |
| scripts/boot.gd | 11 | — | Empty template; orphan (A1). | — | **orphan** |
| scenes/world/buildings/RoofOverlay.gd | 126 | `RoofOverlay` | Roof fade visual. | — | **transitive** (SiteParcelsImpl) |
| effects/lattice/scenes/LatticeMarkVfx.gd | 34 | `LatticeMarkVfx` | VFX. | — | **proven none** |
| ui/widgets/SellMarkOverlay.gd | 44 | `SellMarkOverlay` | Shop sell marker. | — | **proven none** |
| ui/widgets/SetEmblem.gd | 44 | `SetEmblem` | Set icon widget. | — | **proven none** |
| ui/components/ManifestBadge.gd | 63 | `ManifestBadge` | Badge widget. | — | **proven none** |
| ui/screens/Segment1NarrativeOverlay.gd | 40 | `Segment1NarrativeOverlay` | Narrative overlay. | — | **proven none** |
| core/systems/augments/AugmentData.gd | 46 | `AugmentData` | Resource definition. | — | **transitive-load** (`Global.init_permanent_augments`) |
| core/systems/items/ItemDropContext.gd | 14 | `ItemDropContext` | Data holder. | — | **transitive** |
| spells/SpellBase.gd | 38 | `SpellBase` | Spell base (SpellCaster is in player.tscn). | — | **proven none** |
| spells/SpellData.gd | 10 | `SpellData` | Data. | — | **proven none** |
| spells/logic/Weapon.gd | 72 | `Weapon` | Dead (cleanup audit C2.1). | — | **proven none / orphan** |
| data/RaceData.gd | 23 | `RaceData` | Resource. | — | **proven none** |
| data/WeaponData.gd | 10 | `WeaponData` | Resource. | — | **proven none** |
| data/styles/StyleData.gd | 21 | `StyleData` | Resource. | — | **proven none** |
| data/sets/SetData.gd | 45 | `SetData` | Resource (set tiers). | — | **transitive** (SetRunner scene-only) |
| data/sets/SetTier.gd | 16 | `SetTier` | Resource. | — | **transitive** |
| data/enemies/EnemyDossierCatalog.gd | 37 | `EnemyDossierCatalog` | Static catalog. | — | **proven none** |
| data/manifestations/ManifestationDef.gd | 63 | `ManifestationDef` | Def resource. | — | **transitive** (catalog tests) |
| data/manifestations/ManifestationPairDef.gd | 51 | `ManifestationPairDef` | Def resource. | — | **transitive** |
| data/narrative/OpeningSequenceData.gd | 99 | `OpeningSequenceData` | Text data. | — | **proven none** |
| data/narrative/Segment1Text.gd | 59 | `Segment1Text` | Text data. | — | **proven none** |

---

## Covered scripts with thin coverage (15 rows)

"Touched" = public (non-underscore) methods whose name appears in a referencing test; static-only helpers are described qualitatively.

| Path | Lines | Referencing tests | What is thin |
|---|---|---|---|
| autoload/global.gd | 2103 | 41 tests | 37 of 94 public functions ever called; run lifecycle (`start_new_attempt`, `record_new_attempt`, `goto_game`) touched but 57 functions untested. |
| core/actors/player/player.gd | 1324 | player.tscn in 5 tests; path in 2 | Only `heal` and `wardstone_full_restore` called; `take_damage`, death, respawn, movement never asserted (aim/dash have their own unit tests). |
| core/systems/spawner/spawner.gd | 1147 | SpawnerRegulationTest, EnemyLifecycleStressTest, SpawnFilterTest, PerformanceLifecycleTest | 2 of 13 methods (`is_enemy_cull_eligible`, `get_cull_counters`); rest driven via `set()`/scene. |
| core/systems/world/Level1Builder.gd | 1841 | game.tscn in 4 tests, Level1DeterminismProbe, ChunkTileRendererTest (path) | 0 of 8 methods called directly. |
| autoload/SettingsManager.gd | 143 | HitFeelTest, SettingsScreenTest, TutorialTypewriterTest | Only `get_value`, `set_value`, `input_entries`; `reset_section`, `snapshot`, display-preview trio, `bind_input`, `clear_input_slot`, `reset_controls` untested at the facade (SettingsStore/InputBindingService are tested underneath). |
| autoload/SaveManager.gd | 155 | SaveIntegrityTest, AutosaveDebounceTest | `save_slot`/`load_slot`/`delete_slot`/`ensure_dir` round-tripped on disk; `has_save`, `create_slot`, `set_current`, `save_current` untested. |
| data/sets/SetRunner.gd | 195 | player.tscn only | 0 of 5 methods; set tier activation never asserted. |
| core/systems/augments/AugmentRunner.gd | 125 | player.tscn only | 0 of 3 methods; augment equip never asserted. |
| core/systems/items/ItemEffectRunner.gd | 208 | BurdenSystemTest, StyleParityTest | 4 of 10; `refresh_effects` (the path that instantiates item effect scenes) never called → 7 effect scripts uncovered. |
| effects/manifestations/logic/*.gd (18) | 3,146 | ManifestationSystemTest, StyleParityTest | Each constructed via `def.logic.new()` and freed (line 106) and `describe()`d; only VectorHalo has behavioural asserts (line 885), AnchorRite only `has_method` checks. |
| ui/screens/HubShop.gd | 1669 | DeveloperConsoleTest, ExchangeIdentityTest, UiConsistencyVisualProbe (scene) | No shop method invoked; buy/sell only via `Global.compute_buy_value/compute_sell_value` in AuditClosureTest. |
| ui/screens/hud.gd + HudGateOverlayController (264), HudManifestationController (410), HudThreatController (236), HudBossController, HudTutorialTipController, AugmentTooltipController, SetBreakpointNotifier, HudBagController | 2,326 | HUD.tscn in 5 SceneTree tests | Instantiated only; no controller method called. |
| autoload/DevSetCollisionTools.gd | 483 | DeveloperConsoleTest (+2 display probes) | Headless test only asserts `has_method` for six actions (lines 112–117). |
| core/actors/enemy/modules/EnemySniper.gd (700), EnemyBomber.gd (58) | 758 | EnemyPressureBenchmark only | Benchmark sets `spec.ai`; no behaviour assertions. |
| core/systems/world/opening/OpeningActor.gd | 176 | EnemyLegacyCombatCompatibilityTest | Instantiated for world registration; 0 of 7 methods. |

---

## Top 15 gaps to close first

1. **InventoryRouter (`InvRouter`)** — every equip/bag/stash/drop move in the game goes through it (7 production callers), zero tests; item loss/duplication would be invisible to the suite.
2. **Item effect scenes + `ItemEffectRunner.refresh_effects`** — Firestone, Oakheart, Regeneration, Speed and the three curses are the runtime half of the burden system; tests stop at ItemData/BurdenResolver math and never instantiate an effect.
3. **Manifestation pair logic** (10 scripts + `ManifestationPairEffect`, ~2,100 lines of stat/damage rules) — never constructed in a headless test; only display probes call `grant_pair`.
4. **Enemy→player damage path** — `EnemyProjectile`, `DamageCircle`, `BossBeamSweep`, `BossMine`: no test ever drives `player.take_damage` from a projectile or hazard.
5. **Set effects + SetRunner** — ConduitOverclockAndFeedback, GravemarchMassArrest, GravemarchSunderstep, LatticeAfterstrike are only string-scanned; SetRunner tier activation (0 methods called) is core build identity.
6. **Primary objectives** — BreachSeal, WardVigil, DistrictRelay gate the Exit Rite; only `PrimaryObjectiveCatalog.pick_id` is asserted.
7. **Enemy attack/spawn modules + EnemyLifecycle** — Shooter, Charge, Leech, Splitter, Summoner/Summoned, Init are constructed by every enemy test but never asserted; EnemyLifecycle (death → pool return) is only source-scanned.
8. **Boss encounters** — BossArena/MiniBossArena scaling (source-scan only) and the Arcanist/Bulldozer brains.
9. **Run start path** — `ui/screens/base.gd` → `Global.start_new_attempt()`/`goto_game()` and `OpeningSequenceController`; no headless test starts a run through the UI.
10. **Meta-persistence screens** — `InventoryStash` (0 tests) and `HubShop` (scene-only) write the stash and vendor state that SaveIntegrityTest then only copies.
11. **Player active augments** — HexBlinkMarkEffect, StaminaCoreEffect, SpiderlingSummonEffect plus `AugmentRunner` (0 methods called).
12. **Major-choice effects never applied** — MCE_AddMutation, MCE_AddBackpackSlots, MCE_GrantItemRoll (tests only apply `doctrine_*`/`method_*` ids).
13. **player.gd** — 1,324 lines with two methods exercised; damage intake, death and respawn unasserted.
14. **SettingsManager facade** — 3 of 13 methods; reset/snapshot/bind/clear/reset_controls untested at the layer the UI calls.
15. **Procedural generation chain** — ChunkGenImpl, chunkgen/*, Site*, carvers (≈4,000 lines) run only as a side effect of ChunkManager tests; no determinism or shape assertions beyond DistrictPlan (AuditClosureTest) and `tools/ProcPlanSmokeTest.gd`.

Honourable mentions: AudioManager/SfxManager (manifest parse never checked), BattleText (called on every hit, untested), HealthPickup.

---

## Notes on what cannot be tested headless (structural gaps)

- **Display-bound tests already in the folder** (screenshot via `get_viewport().get_texture().get_image().save_png`): DevConsoleShotProbe, ManagementPauseProbe, ManifestationHoverProbe, ManifestationPlaytestProbe, ObjectiveShotProbe, RoamVisibilityProbe, Segment1StoryProbe, UiConsistencyVisualProbe, EnemyProxyRendererVisualTest, MinigunStressBenchmark. `HudContextPresentationTest` saves a PNG but its asserts run headless; `ProjectileSlotReuseTest` guards pixel checks with `DisplayServer.get_name() != "headless"` (line 107). `EnemyHordeBenchmark` is run windowed by `tools/perf/run_benchmarks.ps1` line 42.
- **23 tests are `extends SceneTree` scripts with no `.tscn`** and must be run with `--headless -s res://tools/tests/X.gd`, not `--quit-after N X.tscn`: AccessibilitySettingsTest, ChunkTileRendererTest, DevSegmentTest, DeveloperConsoleTest, ExchangeIdentityTest, FirstEncounterPresentationTest, FlowFieldAllocationBenchmark, FollowerFeedbackPresentationTest, InputBindingServiceTest, InterfaceThemeConsistencyTest, MainMenuSettingsIntegrationTest, PerformanceOverlayUnitTest, PlayerAimStateTest, PlayerDashStateTest, ProjectileRenderBenchmark, Segment1ProgressionTest, Segment1TileIntegrationTest, SettingsPersistenceTest, SettingsRuntimeTest, SettingsScreenTest, SpawnFilterTest, TutorialTypewriterTest, WorldTileIntegrationTest.
- **Production behaviour that needs a real display/input**: `DisplaySettingsAdapter` window-mode/vsync changes (dummy DisplayServer headless — state can be asserted, effect cannot); `InputCaptureOverlay` and `BindingRow` real key capture (synthetic `InputEvent` works, hardware capture does not); `player.gd` and `HudGateChecklistController` poll `Input.is_action_*` (testable with `Input.action_press`/`parse_input_event`); renderers `ImpactBurstRenderer`, `BattleTextRenderer`, `EnemyProxyRenderer`, `VisionRig`/`FogOfWar` SubViewports — API callable headless but no readable framebuffer (RenderChainProbe / EnemyProxyRendererVisualTest exist for windowed checks); `AudioManager`/`SfxManager` — dummy audio driver: stream/bus state assertable, output not.
- **No CI/suite runner exists**: the only orchestration is `tools/perf/run_benchmarks.ps1` (benchmarks only); no script or `.github` workflow lists the canonical test set.

## Appendix A — orphans confirmed during the audit

All already listed in `2026-08-28-dead-code-orphans.md`: `scripts/boot.gd` + `scenes/boot.tscn`, `ui/controllers/HudInventoryController.gd`, `core/systems/vision/VisionOverlay.gd`, `core/systems/world/SegmentPlan.gd`, `scenes/world/cover/CoverWindow.gd`, `core/actors/enemy/modules/EnemyOrbit.gd` (independently confirmed here: no reference in `core/` or `scenes/` besides itself; not constructed in `enemy.gd` lines 149–167 where every other module is), `ui/components/selection_card.gd`, `spells/logic/Weapon.gd`.

## Appendix B — `assets/vfx` scripts (47, all pure visuals, LOW)

Reached through scene closure (13): AugmentFlyVfx, UiFlyVfx, BagMergeVfx, VFX_ReflectShieldWindow, VFX_SpiderBite, VFX_SpiderExplode, VFX_SpiderlingVisual, reflect/VFX_ParryWindow, reflect/VFX_PerfectBurst, reflect/VFX_ReflectPop, sets/conduit/VFX_PulseRing, sets/conduit/VFX_SpokesBurst, wardstones/VFX_WardstoneIdleAura. Never loaded by any test (34): VFX_HexBlinkBurst, VFX_HexMarkAura, VFX_SpiritSlash, VFX_SpiritSlashImpact, VFX_StaminaCoreAura, VFX_TeslaArc2D, VFX_TeslaPulseRing, common/VFX_TrailFollow2D, enemies/VFX_BomberHazardRing, VFX_ChargeWindup, VFX_EnemyMuzzleFlash, VFX_EnemyShootCone, VFX_HeraldPulseRing, gates/VFX_GateUnlockBurst, items/VFX_FloatingPlus, VFX_SpeedStreak, manifestations/ShardSplinter, VFX_CartographyMark, VFX_GospelPulse, VFX_PairShatter, VFX_PairSlipstreamMote, VFX_ProvidenceBurst, VFX_RetaliationNova, VFX_ShardForge, VFX_ShardLaunch, VFX_SigilMark, VFX_SunderTear, VFX_TitheEmbers, sets/conduit/VFX_ArcLine, VFX_CleaveArc, VFX_ExplosiveT, VFX_ShockRing, VFX_Shockwave, wardstones/VFX_WardstoneAttuneBurst. `ScriptParseAuditTest` does not scan `assets/`, so these are not even parse-checked (stale-tests audit D1.11).

---

## Status 2026-08-30 — no gap closed; seven uncovered rows overtaken by deletions

Verified at `b2b1604` by re-running the audit's greps against the tree and
`git show --stat` on every commit since `cbc86ef` (the audit's own commit;
all code changes below postdate it). Nothing executed.

**Rows overtaken by deletion** (the orphans this audit said to remove
instead of test — all seven files confirmed gone at HEAD):

| Row | Commit |
|---|---|
| MEDIUM `ui/components/selection_card.gd` | `ae86c60` |
| LOW `ui/controllers/HudInventoryController.gd` | `ae86c60` |
| LOW `core/actors/enemy/modules/EnemyOrbit.gd`, `core/systems/vision/VisionOverlay.gd`, `core/systems/world/SegmentPlan.gd`, `scenes/world/cover/CoverWindow.gd` | `0428e8d` |
| LOW `scripts/boot.gd` | `7a432cb` |

`spells/logic/Weapon.gd` (LOW, orphan, cleanup C2.1) was **not** deleted —
still present, row stays. Appendix B: `VFX_SpiritSlashImpact.gd` deleted in
`0428e8d` → 47 vfx scripts become 46, the never-loaded list 34 → 33.
Appendix A: 7 of 8 orphans now gone; Weapon.gd remains.

**Summary counts at HEAD** (re-counted with the audit's `find`): production
scripts 329 → **322**; uncovered 118 → **111** (HIGH 51 unchanged, MEDIUM
38 → 37, LOW 29 → 23); covered 211 unchanged — 211 + 111 = 322 checks out.

**Test inventory shifts** (Method section): `af4e23e` removed
ChunkScaleBenchmark, EnemySimulationBenchmark and FlowFieldAllocationBenchmark;
three regression suites were added (below) → still 111 scripts, but
benchmarks 10 → 7, asserting tests 89 → 92, with-`.tscn` 88 → 89,
SceneTree-only 23 → 22. The 23-name SceneTree list in the Notes section is
stale by one entry: FlowFieldAllocationBenchmark no longer exists.

**New coverage since 08-28 — all of it deepens scripts already counted
covered, so no uncovered row closes**: `e549847`
PooledProjectileRecycleTest (`projectile.gd` pooled recycle), `3619ddd`
GameOverFallbackTest (`game.gd end_run` unpause fallback), `9453f95`
SaveSelectUnreadableSlotTest (SaveSelect/SaveCard), `3897ef6` + `054f635`
two new SaveIntegrityTest cases (broken-primary rotation, save_version
round-trip), `bc13160` ManifestationSystemTest dangling-id, `2dca035`
SettingsPersistenceTest newer-schema, `13c7d0f` BuildIdentityTest
fractional-luck pin. Thin-coverage table effect: the **SaveManager** row
improves — `has_save` is now exercised (SaveSelectUnreadableSlotTest lines
45/78); `create_slot`/`set_current`/`save_current` still have zero callers
in tools/tests (`grep -lw` at HEAD → none). The other 14 rows are
unchanged: `054f635`/`b2b1604` edit inside existing `global.gd` functions
(37/94 stands), and `2dca035` tests SettingsStore beneath the facade, not
the SettingsManager row's methods.

**Top 15: all fifteen re-verified still open.** `grep -lw` at HEAD for
InvRouter/InventoryRouter, `refresh_effects`, ManifestationPairEffect,
EnemyProjectile/DamageCircle/BossBeamSweep/BossMine, SetRunner, the three
objective classes, EnemyShooter/EnemyLifecycle/BossArena,
OpeningSequenceController, InventoryStash, HexBlink/StaminaCore, `MCE_`,
AugmentRunner finds nothing beyond the same PerformanceRootCauseFixTest
source scans the audit already discounted. #11 note: StaminaCoreEffect was
edited by `2aebf62` (release-build logging) — still untested, finding
unaffected.

**Disposition of `7bfc6cb`** (ten zero-caller functions removed): every
touched file (EnemyIndex, EnemySimulationScheduler, enemy.gd,
EnemyCombatService, EnemyWorld, RangedBullet) is a *covered* script — no
row of this audit is retired or altered by it.

## Status 2026-08-31 — top-15 gap #1 closed, and it found a defect

**#1 InventoryRouter — closed** (`356b3ea`). `InventoryRouterTest` drives the
real router through the exact call shapes of its production callers: equip
into an empty slot, equip-swap (including against a full bag), bag↔equip and
stash↔bag both ways, the same-id feed route vs the distinct-item swap route,
drop-to-world through a spawner stub, full-container refusals with rollback,
locked sources and destinations, invalid slots — and the conservation
invariant (instances across equip + bag + stash + world) after every single
operation. 111 checks where the audit found "proven none".

Mutation-checked rather than trusted: neutralising the router's `locked`
guards turns the suite red (8 failures) and removing the eject rollback turns
it red (3), so the two load-bearing invariants are pinned for real.

It also found a live defect, fixed with its own pin (`adb705d`): a refused
eject left the bag's staged VFX origin armed, so the next origin-less bag add
— a vendor buy, a granted reward — flew in from an equip slot nothing had
left. `equip_from_bag` already disarmed on its merge path for exactly that
reason.

The other fourteen top-15 gaps are untouched; HIGH stays 50 of the 51.

## Status 2026-08-31, later — gaps #2, #3, #5, #6 closed; four defects found

`ItemEffectRunnerTest` (229), `ManifestationPairBehaviourTest` (232),
`SetRunnerTest` (218) and `PrimaryObjectiveTest` (228) close the top-15 rows
#2, #3, #5 and #6 — 907 assertions over code that had none. Reviewers were
required to *actually mutate* the production code rather than reason about
vacuity, and found real vacuity in three of the four suites (a rarity curve
recomputed test-side instead of run, an assertion that could not have caught
its own negative, a regression guard never reached, and one tautology); all
were repaired before integration.

**Two defects found and fixed with their pins:**

- `39b9b84` — the whole **Conduit set damaged with no source**. All three
  sites omitted `1, player` that every other set effect passes, and
  `EnemyCombatService` gates `damage_dealt`/`player_hit_landed` on
  `source != null`: neither breakpoint fed the style lifesteal or any
  Manifestation `on_hit` rule. 0.0 of 65.0 damage credited before the fix.
- `db21616` — **Slow Heart re-intercepted its own payout**. `_releasing` was
  written with a comment explaining why, and never read, so 85% of each
  released step went straight back into the bank: 0.89 HP/s returned against
  the 5.95 the curse advertises.

**Two reported, deliberately not acted on — they are design decisions:**

- `BreachSealObjective`: `_activated` latches permanently
  (`PrimaryObjective.gd:120`) and `tick_active` has no distance gate, while
  `_tick_breach_spawn` takes the breach's world position and **ignores it**
  (the parameter is `_world`) — spawning through `spawner.spawn_burst`,
  which spawns around the *player*. One visit to a breach therefore pulls
  waves after the player anywhere in the district until it is sealed. The
  unused parameter suggests spawning *at the breach* was intended and never
  wired; the base class comment shows a previous fix addressed only the
  never-activated case. Changing where enemies spawn is a balance change,
  so it is recorded here rather than made. **Ruled 2026-09-06: enemies
  pour from the breach's fixed location.** Not yet implemented — the ruling
  came with a condition: the culling rules must be rechecked alongside it,
  so a distant open breach neither teleports enemies to the player nor
  stockpiles an off-screen army (a local population cap and a culling policy
  for breach-spawned enemies).
- `DeathRattle.gd:137-140` writes `state.time_since_attack = _gap`
  unconditionally when its hold expires, clobbering a shared-clock reset
  another rule performed while the hold stood — visible only in multi-rule
  loadouts (e.g. alongside Martyr Circuit). Whether the shared clock is
  first-writer-wins or last-writer-wins is a rules question, not a bug with
  an obvious right answer. **Ruled 2026-09-06: the best result wins, on one
  shared clock** — neither first- nor last-writer; effects propose a clock
  state and the most player-favourable valid cadence resolves, so broken
  combinations stay broken (that is the point) without depending on node
  iteration order. Not yet implemented.

Also worth knowing: `BuildInfoTest` fails 2 of 11 inside any linked git
worktree, because `BuildInfo.gd:59` reads `res://.git/HEAD` and a worktree's
`.git` is a file, not a directory. Environmental, not a regression — but it
means every future worktree agent reports two phantom failures.
