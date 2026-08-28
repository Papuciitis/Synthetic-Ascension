# Performance hygiene audit — per-frame callbacks that could sleep

**Date:** 2026-08-28 · **Tree:** `enemy-world-work` @ `c131cd2` · **Kind:** read-only audit (nothing modified).
**Scope:** every `_process` / `_physics_process` / per-frame `queue_redraw` / `_input` / Timer loop under `autoload/`, `core/`, `scenes/`, `ui/`, `effects/`, and the `assets/vfx/` scripts they instantiate. This is *not* an optimisation pass: it lists idle work and the condition under which each callback could sleep. Nothing here proposes algorithmic changes.

Counting assumptions for "500 enemies": `EnemyRepresentationManager` materialises a bounded set of `enemy.gd` actors (near tier, physics on) and keeps the rest as data proxies drawn by `EnemyProxyRoot`; the proxy path is one `_process`/`_physics_process` pair regardless of count. DoTs on actors are ticked from the enemy step (`register_dot`), not per node. So the enemy count mostly does not multiply GDScript callback count; it multiplies work inside a handful of managers that are simulation, not idle cost, and those are excluded from the idle ranking.

Class key: **SLEEPS** = `set_process(false)` when idle or only alive while needed; **CHEAP-IDLE** = early-out within a few ops; **ALWAYS-ON** = real work every frame with nothing changing.

---

## 1. Inventory

### Autoloads (run during menus / pause too)

| path:line | node | lifetime | class | idle cost | sleep condition | risk |
|---|---|---|---|---|---|---|
| `autoload/HitFeel.gd:69` | HitFeel | autoload, ALWAYS | CHEAP-IDLE | 2 compares | could `set_process(false)` until a stop/punch starts | LOW |
| `autoload/PerformanceFlightRecorder.gd:69` | PFR | autoload, ALWAYS | ALWAYS-ON (light) | `_poll_completed_reports()` runs before the `enabled` check: allocates an `Array[Dictionary]` via `_take_completed()` every frame even when the recorder is off (line 481; `performance/PerformanceIncidentWriteQueue.gd:30`). When enabled: 8 `Performance.get_monitor` calls + dict alloc + `sample.duplicate()` per frame | poll only while a write job is in flight (`_thread != null`) or an incident is pending; otherwise `set_process(enabled)` | LOW |
| `autoload/ThreatDirector.gd:195` | ThreatDirector | autoload, pausable | CHEAP-IDLE (5 Hz) | 1 float add + compare; every 0.2 s: `get_nodes_in_group("exit_rite_channeling")` (allocates an Array), `_update_dominance/_update_evac/_recompute` (~80 float ops) — runs identically in MainMenu/Hub where there is no run | tick only while a run scene is active; replace the group poll with group join/leave events | LOW |
| `autoload/EnemySimulationScheduler.gd:161,165` | scheduler | autoload, PAUSABLE | ALWAYS-ON (sim) | `_physics_process`: `_update_pressure_state`, `refresh_assignments()` every 0.2 s (calls `EnemyIndex.get_all()` + `compute_assignment`, allocates groups) even with 0 enemies; mid/far group step. This is the sim driver, not idle waste at 500 | skip `refresh_assignments` and group runs when `EnemyIndex` is empty; sleep in menus | LOW |
| `core/systems/enemy_world/EnemyStatusService.gd:52` | EnemyStatus | autoload | CHEAP-IDLE | loop over active statuses only; empty list = 2 compares | – | – |
| `core/combat/projectile/ProjectileSimulationManager.gd:83,88` | ProjectileManager | autoload | ALWAYS-ON (light) | with 0 projectiles: `_sync_scene_refs` (2 tree lookups), `_pending_ledgers.clear()`, `_flush_hit_ledgers`, `_update_renderer` — which still calls `RenderingServer.multimesh_set_buffer` with the full `capacity*12` float buffer and `emit_changed()` every frame even when `_active_count == 0` (lines 456-458), `_update_debug_overlay`. Runs in menus too | early-out in `_update_renderer` when `_active_count == 0` and the previous count was 0; sleep the whole `_process` while empty and no stress test, wake on `spawn()` | LOW |
| `core/combat/BattleTextRenderer.gd:176` | BattleText | autoload | SLEEPS | `set_process(false)` at count 0 (line 205) | – | – |
| `ui/controllers/FollowerFeedbackUI.gd:25` | autoload, ALWAYS | CHEAP-IDLE | 2 compares | could sleep until `_show()` | LOW |
| `autoload/DevSetCollisionTools.gd:23` | autoload | SLEEPS | `set_process(false)` in `_ready`; `_process` body is `pass` (dead) | – | – |
| `autoload/EnemyIndex.gd:74` | autoload | (no callback) | `set_physics_process(true)` with no `_physics_process` defined — harmless dead toggle | – | – |
| `scripts/boot.gd:10` | boot scene root | boot only | dead | `_process: pass` — one empty script call per frame while the boot scene lives | delete or `set_process(false)` | LOW |

### Player / camera / aim / dash

| path:line | node | lifetime | class | idle cost | sleep condition | risk |
|---|---|---|---|---|---|---|
| `core/actors/player/player.gd:198` | player `_process` | per-run | CHEAP-IDLE (necessary input poll) | ~6 timers, `_ensure_inventory_binding` (1 compare), 3 `Input.is_action_just_pressed`, `_tick_dash` | – (input must be polled) | – |
| `core/actors/player/player.gd:248` | player `_physics_process` | per-run | ALWAYS-ON (necessary) — but `get_effective_move_speed()` does 3 `get_node_or_null` string-path lookups per physics tick (lines 388-396); `SettingsManager.get_value` dictionary lookup per tick | cache the three runner refs in `_ready`; cache deadzone on settings change | LOW |
| `core/actors/player/PlayerAimReticle.gd:15` (via `set_aim`) | aim reticle | per-run, 1 | ALWAYS-ON when controller aiming | `queue_redraw()` every physics tick although `_draw` is static geometry (5 draw calls); moving a Node2D does not need a repaint | drop the `queue_redraw()` in `set_aim`; redraw only on `visible` flip. Mouse users: already hidden | LOW |
| `core/actors/player/PlayerDashState.gd:83` | dash state | per-run | CHEAP-IDLE | epsilon-gated signal (`REPORT_EPSILON`) | – | – |
| `assets/vfx/world/common/VFX_TrailFollow2D.gd:35` | dash trail | per-dash, freed after fade | SLEEPS (lifetime-bounded) | dirty-flag gated redraw | – | – |
| Camera | `Camera2D` in `player.tscn` | – | engine-side | no script; `HitFeel._apply_punch` only while `_punch_offset != 0` | – | – |

### Enemies / enemy modules / proxies

| path:line | node | lifetime | class | idle cost | sleep condition | risk |
|---|---|---|---|---|---|---|
| `core/actors/enemy/enemy.gd:249` | enemy actor | pooled actor, near tier only | SLEEPS | `set_physics_process(_lod_tier == 0)`; pooled nodes `PROCESS_MODE_DISABLED` (`PoolManager.gd:149`); mid/far ticked by scheduler groups | – | – |
| `core/actors/enemy/enemy.gd:825,1047` | enemy actor | – | dead toggle | `set_process(true)` with no `_process` in enemy.gd — harmless | – | – |
| `core/actors/enemy/modules/BurnDot.gd:29`, `BleedDot.gd:30` | DoT | per-status | SLEEPS | `set_process(false)` when the parent registers via `register_dot` | – | – |
| `core/actors/enemy/modules/EnemySummoned.gd:11` | summoned minion tag | per summoned actor (few) | CHEAP-IDLE | `instance_from_id` + timer per frame | – | – |
| `core/actors/enemy/modules/{Shooter,Charge,Summoner,Sniper,Herald,Tactical}.gd` | – | – | SLEEPS | ticked from `_tick_active_modules` by AI kind only (enemy.gd:400-410) | – | – |
| `core/actors/enemy/brains/EnemySeparationSystem.gd:16` | – | per-run | SLEEPS | `set_physics_process(false)` | – | – |
| `core/systems/enemy_world/EnemyProxyRoot.gd:54,74` | proxy root | per-run, 1 | ALWAYS-ON (rendering, necessary) | `renderer.publish()` rebuilds `groups`/`actor_groups`/`seen` Dictionaries and per-batch buffers every frame; half-rate for proxies above `HALF_RATE_PROXY_THRESHOLD` | at 0 enemies it still allocates 3 dicts/frame — could early-out when `_handles` and `_actors` are empty | LOW |
| `core/systems/enemy_world/EnemyRepresentationManager.gd:47` | – | per-run | CHEAP-IDLE (5 Hz) | timer early-out | – | – |
| `core/combat/projectile/EnemyProjectile.gd:102` | enemy bullet node | per-bullet (transient) | lifetime-bounded | raycast per frame; no per-frame redraw | – | – |
| `core/combat/projectile/projectile.gd:38`, `scenes/world/combat/RangedBullet.gd:77` | legacy bullets | transient | lifetime-bounded | – | – | – |

### World: rites, wardstones, vaults, objectives, arenas, sigils, streaming

| path:line | node | lifetime | class | idle cost | sleep condition | risk |
|---|---|---|---|---|---|---|
| `core/systems/world/ExitRite.gd:220` | ExitRite | per-segment, 1 | **ALWAYS-ON while locked** | `_share_location_with_hud()` + sigil rotate/breathe + **`queue_redraw()` every frame while `locked`** (line 232): `_draw` = 96-seg arc + 3 seal polygons (2 PackedVector2Array allocs each) + `safeguard_pip_positions()` alloc + pip circles/arcs. Locked is the state for most of a segment | locked: redraw only on `set_locked()`/seal/safeguard change (nothing in `_draw` depends on time while locked). Sleeps at completion already (line 282) | LOW |
| `core/systems/world/Wardstone.gd:72` | Wardstone | per-segment, 1-2 | **ALWAYS-ON while inactive** | **`queue_redraw()` every frame in the `not _player_inside` branch** (line 95) — `_draw` = distance check + up to 96-seg + 64-seg arcs; `_set_idle_intensity` write per frame | redraw only on `_player_inside` flip / capture progress / `_active` change; the "ring shows when near" needs a coarse distance hysteresis (~4 Hz) | LOW |
| `assets/vfx/world/wardstones/VFX_WardstoneIdleAura.gd:36` | `$IdleAura` child of each Wardstone | per-wardstone, permanent | **ALWAYS-ON** | `queue_redraw()` unconditionally; `_draw` = 96-seg + 64-seg antialiased arcs + 10 sparks × 2 circles, regardless of distance/visibility | throttle to the 30 Hz pulse bucket; skip when off-screen | LOW |
| `core/systems/world/CursedVault.gd:39` | CursedVault | per-segment, 0-1 | **ALWAYS-ON** | distance calc + **`queue_redraw()` every frame** (line 57) even far away with `_progress == 0`; after `_opened` it still runs the distance/`is_dead` reads forever | redraw only when `_progress` changed or `_opened` flips; `set_process(false)` after `_open()` | LOW |
| `core/systems/world/objectives/PrimaryObjective.gd:97` | primary objective | per-segment, 1 | **ALWAYS-ON** | pre-activation: distance check + **`queue_redraw()` every frame** (line 122) wherever the player is; `tick_finished` also redraws every frame forever after completion (line 168). Subclass `_draw`s: BreachSeal ~10 arcs/circles per breach + `draw_string` with `%`-format; DistrictRelay 3 draws per component + `draw_string`; WardVigil 6 spokes + 4 arcs + `draw_string` | pre-activation: redraw at pulse rate only within camera range; finished: 30 Hz or freeze the idle visual | LOW |
| `core/systems/world/objectives/WagerShrineObjective.gd:59` | secondary | per-segment, 0-1 | ALWAYS-ON after finish | `queue_redraw()` every frame once `_finished` (line 62) — a static "spent" ring | one redraw on finish then `set_process(false)` | LOW |
| `scenes/world/events/BossArena.gd:78`, `MiniBossArena.gd:73` | arenas | per-segment, 1 each | CHEAP-IDLE | player group lookup + `distance_to` per frame until spawned | Area2D `body_entered` already exists — poll at 4 Hz instead | LOW |
| `scenes/world/waypoints/WaypointSigil.gd:40` | waypoint sigil | Segment 1: 9 | **ALWAYS-ON** | sigil rotate + **`queue_redraw()` every frame**; `_draw` = 7 sparks × 2 circles = 14 draw calls; no distance/visibility cull | 30 Hz pulse bucket + skip when off-screen | LOW |
| `core/systems/world/Level1MilestoneArea.gd:45` | – | Segment 1 | event-driven | redraws only on configure/complete/enter | – | – |
| `core/systems/world/ChunkManager.gd:209` | ChunkManager | per-run, 1 | CHEAP-IDLE | camera-movement gated replan; `process_chunk_generation_queue()` per frame = ticks read + empty-queue check | – | – |
| `core/systems/world/FlowFieldNav.gd:130` | FlowFieldNav | per-run, 1 | CHEAP-IDLE | `_acquire_refs`, `_ensure_buffers`, cell conversion, `get_nav_revision` per frame; rebuild throttled | – | – |
| `core/systems/world/Level1Builder.gd:1615` | Level1 | Segment 1 | CHEAP-IDLE (throttled) | 0.15 s: `_push_resonance_ui` **emits `resonance_changed` unconditionally** (line 1701) → HUD handler every 150 ms even when unchanged | emit only on value change | LOW |
| `core/systems/world/SegmentProcBuilder.gd:155` | Segment 2+ | per-segment | CHEAP-IDLE-ish | **`_check_secondary_objective_discovery()` every frame**; every 0.25 s `_push_objective_ui` **emits `objective_changed` with freshly formatted strings unconditionally** (lines 563-566); after `resonance >= 1` it emits every frame (line 161) | throttle discovery to 4 Hz; emit UI only when the text changes | LOW |
| `core/systems/spawner/spawner.gd:133` + Timer | Spawner | per-run | CHEAP-IDLE | 7 timer decrements + 2 empty-queue checks | – | – |
| `core/systems/encounters/EncounterDirector.gd:77` | – | per-run | CHEAP-IDLE | `_cooldowns.keys()` alloc per physics tick (usually empty), `_check_escalation`, timer | – | – |
| `scenes/world/volumes/IndoorVolume.gd` | – | per-building | SLEEPS | no per-frame callback | – | – |
| `scenes/world/pickups/ExplorationLootSpawner.gd:77` | – | transient | SLEEPS | one-shot timer chain until DB ready, then frees | – | – |
| `core/systems/world/rite/RitePulseVFX.gd:16`, `OpeningSequenceWorld.gd:25`, `OpeningActor.gd:47` | – | transient / opening only | lifetime-bounded | – | – | – |

### Backgrounds / vision

| path:line | node | lifetime | class | idle cost | sleep condition | risk |
|---|---|---|---|---|---|---|
| `core/systems/backgrounds/AtmosFireflies.gd:43` | fireflies | per-run, 1 | ALWAYS-ON (by design, ambient) | 28 flies: RNG jitter + dict mutate per fly + `queue_redraw()`; `_draw` = 56 `draw_circle` per frame | 30 Hz would be visually identical | LOW |
| `core/systems/backgrounds/FloorFollow.gd:28` | floor | per-run, 1 | CHEAP-IDLE | `_cache_tex_size` + position/region write per frame | skip when player position unchanged | LOW |
| `core/systems/vision/VisionOverlay.gd:28` | overlay | per-run, 1 | ALWAYS-ON (light) | **4 `set_shader_parameter` calls per frame with constant values** (`_update_uniforms`, lines 45-48) | call `_update_uniforms` from setters / `_ready` only | LOW |
| `core/systems/vision/VisionRig.gd:113` | rig | per-run, 1 | CHEAP-IDLE | lightweight mode: `_is_point_in_any_indoor` loop over indoor rects per frame + vignette write while indoors | – | – |
| `core/systems/vision/FogOfWar.gd:38` | fog | per-run | SLEEPS | redraw only on `vision_revision` change | – | – |

### Pickups

| path:line | node | lifetime | class | idle cost | sleep condition | risk |
|---|---|---|---|---|---|---|
| `scenes/world/pickups/ItemPickup.gd:70` | item pickup | per pickup (tens) | CHEAP-IDLE | 0.25 s idle poll beyond 330 px; distance calc only inside | – (already the house pattern) | – |
| `scenes/world/pickups/HealthPickup.gd:43` | health pickup | per pickup | ALWAYS-ON (light) | bob/pulse writes to 2 nodes every frame + the same idle poll | – (transient) | – |
| `scenes/world/pickups/PickupVfx.gd:100` | pickup rings | per pickup | SLEEPS | `set_process(want)` only for locked/exploration rings | – | – |

### HUD / UI

| path:line | node | lifetime | class | idle cost | sleep condition | risk |
|---|---|---|---|---|---|---|
| `ui/screens/hud.gd:151` | HUD | per-run, ALWAYS | CHEAP-IDLE | `_refresh_run_sheet` at 10 Hz → early-outs on `not visible`; `_claim_pause_if_free` 2 compares | – | – |
| `ui/widgets/RunSheetHUD.gd:84` | run sheet | visible only while the bag is open (paused) | ALWAYS-ON while visible (10 Hz) | `_refresh_profile` formats 12 label strings; `_refresh_sets` builds counts dict + signature string; `_refresh_manifestations` builds a nested Dictionary and `var_to_str`s it — allocation-heavy signature; `_refresh_observations` joins a PackedStringArray | signature-gated rebuilds already exist; the signatures are the cost — refresh on `Inventory.changed` / `manifestations_changed` / `hp_changed` instead of polling | MED (paused-UI correctness) |
| `ui/controllers/HudTooltipController.gd:69` | item tooltip driver | per-run | **ALWAYS-ON while hovering** | every frame: `gui_get_hovered_control()` + up to 3 parent walks + `_is_bag_open`. **While hovering an item, `_show_tooltip(inst)` → `ItemTooltip.show_item()` rebuilds the whole tooltip every frame** (formats, `get_effects_short`, comparison rows, `"\n".join`, `body_label.text =`, `reset_size()`), then `_position_tooltip_beside` does `reset_size()` + `get_combined_minimum_size()` again → full Control relayout every frame. No hover-instance cache (unlike `InventoryStash.gd:76-85`, `HubShop.gd:1473-1476`, `AugmentTooltipController.gd:92`) | cache the last shown `ItemInstance` id; re-call `show_item` only when it changes or `Inventory.changed` fires; reposition only on hovered-control change | LOW |
| `ui/controllers/AugmentTooltipController.gd:41` | augment tooltip | per-run | CHEAP-IDLE | `a == _current_augment` early-out (good) | – | – |
| `ui/widgets/AugmentActiveBadge.gd:82` | cooldown badge | 3 instances | **ALWAYS-ON** | per badge per frame: validity checks; every 0.15 s `_rescan_and_rebind` (child scan); `_is_slot_empty()` = 2 `get_node_or_null` path lookups + `strip_edges()`; **`_apply_ready_blend()` writes `StyleBoxFlat.border_color` every frame** — the setter calls `emit_changed()` unconditionally → the Panel is redrawn every frame for all 3 badges even when idle | `set_process` only while a cooldown runs or the blend is mid-transition; rebind on `effect_added/removed` signals; skip `_apply_ready_blend` when unchanged | LOW |
| `ui/widgets/ActiveAbilityHUD.gd:55` | set-ability HUD | 1 | **ALWAYS-ON** | bound: `effect.get_active_state()` (Dictionary alloc) + 2 bar writes + 2 label sets per frame; unbound: player group lookup + iterates children of 2 runners with `has_signal` per frame | poll at 10 Hz or on `active_cd_changed`; rescan on `child_entered_tree` | LOW |
| `ui/controllers/HudGateOverlayController.gd:100` | gate arrow | 1, ALWAYS | ALWAYS-ON (light) | `_resolve_nodes()`, camera lookup, rect math, `get_first_node_in_group("player")`, `"%dm"` string + label position every frame, `lerp_angle`, modulate — even when the arrow ends up hidden | hidden: sleep until `objective_target_pos`/`exit_gate_pos` changes (both are plain `Global` writes — a setter/signal would be needed) | MED |
| `ui/controllers/HudEvacOverlayController.gd:61` | evac overlay | 1, ALWAYS | ALWAYS-ON (light) | `get_first_node_in_group("exit_rite")` every frame; 3 `_td.get()` + `has_method` ×2 | rebind on `exit_rite` group join; update from the director's 5 Hz tick via signal | LOW |
| `ui/controllers/HudGateChecklistController.gd:54` | checklist | 1 | ALWAYS-ON (light) | `InputMap.action_get_events()` (Array alloc) + `OS.get_keycode_string` (String alloc) every frame, compared to `_last_prompt` | cache the prompt; recompute on binding change | LOW |
| `ui/controllers/HudThreatController.gd:162` | threat | 1 | CHEAP-IDLE | `_td.get("threat")` + compare | – | – |
| `ui/controllers/HudManifestationController.gd:248` | nouns row | 1 | SLEEPS | `set_process(any or active_count>0)` (line 229); 10 Hz values | – | – |
| `ui/controllers/HudBossController.gd:34` | boss bar | 1 | SLEEPS | on only between spawn and clear | – | – |
| `ui/controllers/ManifestationPairNotifier.gd:51`, `SetBreakpointNotifier.gd:20`, `TutorialModalController.gd:27` | – | 1 each | CHEAP-IDLE | 1-2 compares | – | – |
| `ui/widgets/PerformanceOverlay.gd:83,93` | dev overlay | 1 | CHEAP-IDLE | `visible` early-out | – | – |
| `ui/overlays/FirstEncounterOverlay.gd:63` | – | transient | lifetime-bounded | – | – | – |
| `ui/screens/InventoryStash.gd:100`, `HubShop.gd:205`, `RotatingFlavorLabel.gd:20` | hub screens | hub only | CHEAP-IDLE | hover-id cached (good) | – | – |
| `ui/screens/TutorialCardOverlay.gd:25`, `OpeningPresentation.gd:31`, `DisplayConfirmationOverlay.gd:16` | – | state-gated | CHEAP-IDLE | early-out on flag | – | – |
| `_gui_input`/`_unhandled_input` in `BagSlot`, `InventorySlotView`, `HubItemSlot`, `AugmentEquipSlot`, `AugmentLibraryEntry`, `TradeConfirmPopup`, `GameOverUI`, `MajorChoice`, `SettingsScreen`, `InputCaptureOverlay`, `hud.gd:303/314` | – | – | event | all early-out on state flags | – | – |

### Player-attached effect runners, items, augments, sets

| path:line | node | lifetime | class | idle cost | sleep condition | risk |
|---|---|---|---|---|---|---|
| `core/systems/items/ItemEffectRunner.gd:26`, `core/systems/manifestations/ManifestationRunner.gd:64` | runners | per-run, 1 each | CHEAP-IDLE | 1 compare (`Global.run_inventory` poll) | no "run_inventory changed" signal exists to replace the poll | – |
| `core/systems/manifestations/ManifestationState.gd:943` | shared state | per-run, 1 | CHEAP-IDLE | movement track, 3 dict lookups, decay loop over `CHANNELS`; shard redraw change-gated | – | – |
| `effects/items/logic/FirestoneEffect.gd:68` | item | 0-1 | **ALWAYS-ON** | `queue_redraw()` every frame; `_draw` = 4 circles + polygon (PackedVector2Array alloc) | 30 Hz pulse bucket like `ManifestationEffect.pulse_redraw` | LOW |
| `effects/items/logic/OakheartShieldEffect.gd:71` | item | 0-1 | **ALWAYS-ON** | `queue_redraw()` every frame; `_draw` allocates `PackedVector2Array(seg+1)` and issues **≥48 `draw_line` calls** per frame | 30 Hz + reuse point buffer (as `VFX_HexMarkAura` does) + `draw_polyline` | LOW |
| `effects/items/logic/RegenerationRingEffect.gd:53` | item | 0-1 | ALWAYS-ON (light) | `queue_redraw()` every frame; circle + 48-seg arc | 30 Hz | LOW |
| `effects/items/logic/SpeedRingEffect.gd:49`, `curses/SlowHeartCurse.gd:80` | items | 0-1 | CHEAP-IDLE | early-out | – | – |
| `effects/augments/logic/{HexBlinkMark,ReflectShield,SpiderlingSummon,SpiritSlash,StaminaCore}Effect.gd` `_process` | augments | ≤3 | CHEAP-IDLE (necessary input poll) | `InputMap.has_action(String(...))` (StringName→String alloc) + blocked check + `is_action_just_pressed`; `_report_cd` epsilon-gated (good) | cache the `has_action` result | LOW |
| `effects/augments/logic/MagicMissileEffect.gd:32` | augment | 0-1 | **ALWAYS-ON when no enemies in range** | once `_cd` hits 0 with no target, `EnemyCombat.nearest_enemy(pos, seek_radius)` runs **every frame** until an enemy appears (lines 57-63) | retry the scan at ~10 Hz after a miss | LOW |
| `effects/augments/logic/TeslaAuraEffect.gd:31` | augment | 0-1 | CHEAP-IDLE | tick-interval gated | – | – |
| `effects/augments/logic/PoisonSpiderling.gd:68` | spiderling | per spiderling | lifetime-bounded, throttled | target refresh 10 Hz, redraw 15 Hz (good) | – | – |
| `assets/vfx/world/augments/VFX_SpiderlingVisual.gd:21` | spiderling body | per spiderling | ALWAYS-ON while alive | `queue_redraw()` every frame: ≈25 draw calls per spiderling — undoes the parent's 15 Hz throttle | share the parent's `_redraw_t` | LOW |
| `effects/augments/logic/ReflectedProjectile.gd:53` | reflected bolt | transient | lifetime-bounded, 30 Hz redraw (good) | – | – | – |
| `effects/conduit/scenes/ConduitOverclockAndFeedback.gd:92`, `gravemarch/GravemarchMassArrest.gd:77`, `lattice/LatticeEchoBuffer.gd:63` | set actives | ≤1 | CHEAP-IDLE (input poll) | LatticeEchoBuffer rebuilds `_preview_line.points` every frame while ≥2 marks exist | preview line: rebuild on mark add/expire only | LOW |
| `ConduitArcBolts.gd:26`, `GravemarchSunderstep.gd:26`, `LatticeAfterstrike.gd:27`, `ImpactScripture.gd:39`, `BadFortuneEngine.gd:73`, `TitheRhythm.gd:129`, `SpellBase.gd:16`, `Weapon.gd:19`, `SpellCaster.gd:24` | cooldown tickers | 1 each | CHEAP-IDLE | 1 `maxf` per frame | could sleep at cd 0 and wake on use | LOW |

### Manifestation overlays (`effects/manifestations/**`)

`pulse_redraw()` is a 30 Hz wall-clock bucket (`ManifestationEffect.gd:143`). Every overlay also writes `global_position = player_position()` per frame (transform write, no redraw).

| path:line | overlay | class | idle cost | sleep condition | risk |
|---|---|---|---|---|---|
| `AnchorRite.gd:70` | SLEEPS-ish | `_build()` per frame; redraw only on change / 30 Hz when full | – | – |
| `PilgrimsMomentum.gd:53`, `ScarTissue.gd:94`, `RedLine.gd:122`, `ReliquaryGuard.gd:145`, `Loom.gd:81`, `MarchingOrder.gd:70`, `PilgrimsToll.gd:76`, `DeathRattle.gd:127`, `BrokenProvidence.gd:91`, `FeverLitany.gd:69`, `HereticalCartography.gd:153`, `DebtCollector.gd:162`, `OvertimeGospel.gd:142` | CHEAP-IDLE | change-gated or "one last wipe" pattern | – | – |
| `MartyrCircuit.gd:42`, `StoredViolence.gd:42`, `ThirdLitany.gd:47`, `TitheFurnace.gd:151` | ALWAYS-ON at 30 Hz (by design — a steady-state read) | 2-12 arcs/circles each at 30 Hz | `MartyrCircuit` healthy-state ring could be change-gated; `StoredViolence` at `_charge <= 0.02` returns in `_draw` but still pays the 30 Hz canvas rebuild | LOW |
| `SlipstreamFoundry.gd:78`, `VectorHalo.gd:166` | CHEAP-IDLE | no drawing; mote tick over ≤`MAX_TRAIL` | – | – |
| `ManifestationShardProjectile.gd:49`, `VFX_PairSlipstreamMote.gd:52`, `VFX_SigilMark.gd:52` | transient | lifetime-bounded, per-frame redraw while alive | – | – |

### Transient VFX (`assets/vfx/world/**`, bosses, combat)

All 27 one-shot scripts (`VFX_*Burst`, `VFX_PulseRing`, `MeleeSlash`, `MagicImpact`, `RitePulseVFX`, `LatticeMarkVfx`, `BossBeamSweep`, …) follow `_t += dt; if _t >= duration: queue_free(); queue_redraw()` — lifetime-bounded, fine. Handled well already: `VFX_BomberHazardRing.gd:43` (distance cull + `REDRAW_INTERVAL`), `VFX_TeslaArc2D.gd:62` (`redraw_hz`), `VFX_HexMarkAura.gd:44` / `VFX_StaminaCoreAura.gd:53` (reused point buffer). `VFX_HexMarkAura` is per marked enemy and redraws every frame at ~30 draw calls while the mark lives; `VFX_ReflectShieldWindow.gd:84` allocates a `PackedVector2Array` per frame (short window). Boss brains are 1-2 instances and timer-gated.

---

## 2. Ten highest idle-cost items (order of magnitude, 500 enemies, nothing changing)

Cost basis: one antialiased `draw_arc(96)` ≈ 96 vertices tessellated on the CPU + one canvas command; a GDScript `_process` call floor ≈ 2-5 µs; a full Control text rebuild + relayout ≈ 100-500 µs; canvas item rebuild ≈ 10-30 µs before draw commands.

| # | item | count | per-frame idle cost (est.) | why it is idle |
|---|---|---|---|---|
| 1 | `HudTooltipController.gd:69` → `ItemTooltip.show_item` + `reset_size()` ×2 per frame | 1, every frame while the cursor is over an inventory slot (bag open = paused; also live when hovering the HUD inventory bar mid-fight) | **0.3-1 ms** | the item under the cursor has not changed |
| 2 | `ExitRite.gd:220` locked-state `queue_redraw()` | 1 | **~60-100 µs** | the locked visual has no time dependence |
| 3 | `PrimaryObjective.gd:97` pre-activation / post-finish `queue_redraw()` | 1 | **~60-150 µs** | player thousands of px away; only `pulse_time` moves |
| 4 | `VFX_WardstoneIdleAura.gd:36` + `Wardstone.gd:72` inactive branch | 1-2 wardstones, 2 canvas items each | **~100-160 µs** | off-screen most of the segment |
| 5 | `AugmentActiveBadge.gd:82` (`StyleBoxFlat.border_color` write → `emit_changed` → Panel redraw; path lookups; 0.15 s rescan) | 3 | **~50-90 µs** plus 3 Control redraws | no cooldown running, blend settled |
| 6 | `WaypointSigil.gd:40` | 9 (Segment 1) | **~100-130 µs** | never culled by distance |
| 7 | `ProjectileSimulationManager.gd:88` with 0 projectiles | 1 (also in menus) | **~20-60 µs** (`multimesh_set_buffer` uploads `capacity*12` floats — e.g. 24 KB — plus `emit_changed`) | `_active_count == 0` |
| 8 | `ActiveAbilityHUD.gd:55` | 1 | **~15-30 µs** | ability state unchanged |
| 9 | `OakheartShieldEffect.gd:71` / `FirestoneEffect.gd:68` / `RegenerationRingEffect.gd:53` | 0-1 each | **~30-50 µs** Oakheart, ~10 µs others | the 60 Hz vs 30 Hz gap |
| 10 | `HudGateOverlayController.gd:100` + `HudEvacOverlayController.gd:61` + `HudGateChecklistController.gd:54` | 1 each, ALWAYS | **~10-25 µs combined** | target/rite/bindings unchanged |

Below the cut: `CursedVault.gd:39` (~10 µs, 0-1), `MagicMissileEffect.gd:32` idle `nearest_enemy` query each frame while nothing is in range (~5-20 µs), `VisionOverlay.gd:28` (~5 µs), `PerformanceFlightRecorder.gd:69` array alloc when disabled (~2 µs), `ThreatDirector` 5 Hz group alloc in menus (<1 µs amortised). `EnemyProxyRoot.publish` and `EnemySimulationScheduler` dominate the frame at 500 enemies but are simulation/rendering work, deliberately not ranked.

**Total recoverable idle cost** during a normal locked-gate segment with a wardstone, a primary objective and 9 sigils: roughly **0.4-0.7 ms/frame**, rising to **1-1.5 ms** while hovering an item with the bag open. Every top-10 item is LOW risk except the run sheet (MED, paused-UI correctness) and the gate arrow (MED, needs a `Global` setter/signal that does not exist yet).

---

## 3. House patterns already in the codebase (copy these)

- **`core/combat/BattleTextRenderer.gd:176-211`**, **`core/combat/projectile/ImpactBurstRenderer.gd:89-113`** — `set_process(false)` at count 0, `set_process(true)` on first push; swap-remove with pre-allocated buffers. The canonical "sleep when empty, wake on push".
- **`ui/controllers/HudManifestationController.gd:229`** — `set_process(any or active_count > 0)` recomputed from the signal that changes the state, plus the `tree_exiting` wake-up so a sleeping controller cannot hold a freed reference. The right pattern for every polling HUD controller.
- **`ui/controllers/HudBossController.gd:32/52/74`** — on only between `boss_spawned` and `boss_cleared`.
- **`scenes/world/pickups/ItemPickup.gd:70-98`** — 0.25 s idle poll beyond 3× magnet radius; **`PickupVfx.gd:52`** `set_process(want)` from state setters.
- **`core/actors/enemy/modules/BurnDot.gd:21-28`** — a child that hands its tick to the parent's scheduled step and sleeps itself.
- **`core/actors/enemy/enemy.gd:481-486`** + **`autoload/PoolManager.gd:137-153`** — physics on only for LOD tier 0; pooled nodes `PROCESS_MODE_DISABLED`.
- **`core/systems/manifestations/ManifestationEffect.gd:143`** `pulse_redraw()` (shared 30 Hz bucket) with the "one last wipe" idiom in **`PilgrimsMomentum.gd:53-71`**, **`RedLine.gd:133-136`**, **`ScarTissue.gd:94-104`**, **`BrokenProvidence.gd:91-101`**, **`HereticalCartography.gd:167-171`**. Exactly what `ExitRite`, `Wardstone`, `CursedVault`, `PrimaryObjective`, the item rings and the sigils should adopt.
- **`assets/vfx/world/enemies/VFX_BomberHazardRing.gd:43-61`** — distance cull to `visible=false` plus `REDRAW_INTERVAL`; the model for `VFX_WardstoneIdleAura` and `WaypointSigil`.
- **`assets/vfx/world/augments/VFX_HexMarkAura.gd:89-95`** / **`VFX_StaminaCoreAura.gd:99-121`** — reused `_pts` buffer instead of a per-frame `PackedVector2Array`.
- **`effects/augments/logic/PoisonSpiderling.gd:76-79, 90-94`** — separate throttles for target refresh (10 Hz) and redraw (15 Hz); **`ReflectedProjectile.gd:80-83`** 30 Hz redraw for a moving bolt.
- **`ui/screens/InventoryStash.gd:76-85`**, **`ui/screens/HubShop.gd:1473-1476`**, **`ui/controllers/AugmentTooltipController.gd:92-94`** — hover instance-id cache; the direct fix for `HudTooltipController`.
- **`core/systems/world/ChunkManager.gd:218-229`** — replan gated on a quarter-chunk of camera movement, rationale in the comment.
- **`effects/augments/logic/HexBlinkMarkEffect.gd:210-214`**, **`core/actors/player/PlayerDashState.gd:90-93`** — epsilon-gated signal emission.
- **`ui/widgets/RunSheetHUD.gd:145-151, 290-293`** — signature-gated page rebuilds (only the signature computation is still per tick).
