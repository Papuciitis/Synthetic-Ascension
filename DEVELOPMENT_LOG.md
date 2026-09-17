# Synthetic Ascension — Development Log

> **Frozen.** The last entry is 0.25.4 (dated 2026-07-23) and the file was last
> touched 2026-07-30; nothing after 0.25.4 — not 0.25.5 nor any of the
> August 2026 enemy-world work — was logged here. Later history lives in git and
> the roadmap §27 status log (`docs/SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md`).

## Append-only rule

This file is an append-only chronology. Never rewrite, reorder, compress or silently correct an earlier release entry. Add corrections and later findings in a new dated entry so recovery work remains auditable.

## 0.22 — Projectile Collision + Equipment Set Readability

Date: 2026-07-21

Baseline: uploaded `syntethic-ascension0.0.0.21b(1).zip`, SHA-256 `66062fd0a52cc0048b344e816c66eb8c3b2fd372483d0b47881ec35b5811446e`.

### Implemented

- Replaced occupied-cell sampling for managed bullets with grid DDA broad phase and swept intentional-shape narrow phase.
- Added one packed blocker descriptor model for solid fallback cells, thin connected walls, projectile-transparent windows, thin fences and circular half cover.
- Registered handcrafted and procedural blocker nodes with the projectile geometry source and applied the same authored wall/fence/cover dimensions to player physics shapes.
- Routed ordinary managed player/enemy bullets and the four node-owned projectile scripts through the same world-hit query.
- Expanded central set resources with identity, playstyle, best-with guidance, shape/accent language, named tiers, mechanical/plain explanations, active requirements and glossary definitions.
- Rebuilt item tooltip set sections around current count, six pips, active/next/later tiers and an actual fixed-slot replacement simulation with gained/lost breakpoints.
- Added procedural set emblems to equipped, bag, stash and Hub item slots.
- Added player-action-only set breakpoint activation/loss notices; inventory population and save loading update the baseline silently.
- Made active-ability HUD readiness authoritative. Gravemarch no longer reports READY without sufficient bank and failed inputs now explain the missing condition.
- Added Conduit primed/overclock state, Gravemarch bank/requirement/pull state, and Lattice mark count/lifetime/Index state to the combat HUD.
- Added distinct normal and mirrored Lattice mark shapes, visible expiry arcs and faint incomplete-pattern connections.
- Added a developer-only in-run panel for 2/4/6-piece and explicit item-ID grants, switching/clearing, notification forcing, prime/bank/mark state, deterministic slow/high-speed collision fixtures and projectile stress toggling.

### Corrected stale descriptions

- Conduit 6-piece no longer calls Overclock the active ability; the active is Circuit Feedback and Overclock is kill-triggered.
- Lattice 4-piece now describes a periodic delayed area strike instead of “the next hit echoes.”
- Lattice 6-piece now describes three living marks and Index Commit instead of storing excess damage.

### Deliberate boundaries

- No cinematic intro, lore expansion, new area, proc redesign, Respite overhaul or Hub redesign was added.
- No save fields were required; older profiles use the same inventory resources and safely receive presentation defaults from central set data.
- This entry records implementation and static review only. Godot runtime, collision feel and profiler results remain unverified until the first engine playtest.

### Runtime status

- All project GDScript files passed an external syntax parse and literal resource references resolved before packaging.
- Godot 4.6 was unavailable, so import, typed compilation, runtime physics, UI layout, save behaviour and profiler performance were not executed or certified.

## 0.22.1 — Restored 0.21 UI, Item and Stability Patches

Date: 2026-07-21

Baseline: `syntethic-ascension0.0.0.22-projectile-set-readability-full.zip`, SHA-256 `85905ecc14622a5d144e4c3ddeb5cd4dfa54169f4aaf16f929ec4941817389e6`.

### Restored and improved

- Restored the previously selected 48×48 icon cuts for all 18 Conduit/Gravemarch/Lattice items, both offhands and both rings.
- Restored the rare enemy health pickup at a tunable 3% base chance, 20% maximum-health recovery and 20-second lifetime. A full-health player leaves it on the floor.
- Rebuilt save cards around the mortal/character name. Slot number, race, style and route are secondary; selected/hovered cards reveal Area/Segment, state, Followers, equipped count, backpack use, runs and best Followers.
- Changed save-card Rename to edit the mortal name while synchronising the legacy profile-name field.
- Restored the Respite identity in the between-segment Hub, including a compact segment report and rotating atmosphere text.
- Removed duplicated trade controls from the left sidebar and consolidated offer tools inside the Trade panel.
- Replaced the native gray `ConfirmationDialog` with a full themed confirmation overlay showing offered value, secured value, net Follower commitment and before/after Followers.
- Prevented Inventory reorganisation while a live trade cart reserves source slots.
- Corrected save-directory creation by globalising `user://saves/` before calling the absolute-path API.
- Made the HUD tutorial queue abort safely when its scene tree disappears during Segment completion or another scene change.

### Runtime boundary

- All 242 project GDScript files passed an external syntax parse and changed-scene resource paths resolved.
- Godot was unavailable in the working environment. Import, typed compilation, save writes, UI layout and gameplay remain pending the runtime checklist.

## 0.22.2 — Godot 4.7 Global-Class and Signal-Shadow Compatibility

Date: 2026-07-21

Baseline: installed 0.22.1 restoration patch, patch SHA-256 `b7a76925e7962a74a43bbf50cb50ac10f240f21ae9af9b91a19d456ba93e33bf`.

### Corrected

- Renamed the globally registered `Enemy` script class to `EnemyActor` and updated every typed annotation, cast and type check that consumes it. Scene paths, node names and gameplay behaviour are unchanged.
- Removed the collision with Godot's reported duplicate/orphan `Enemy` global class name without requiring the player to edit project cache files first.
- Renamed local `ready` variables to `is_ready` in the Conduit, Gravemarch and Lattice active-state providers and in `ActiveAbilityHUD`, avoiding the inherited `Node.ready` signal name.

### Runtime boundary

- All 242 project GDScript files passed an external syntax parse.
- No duplicate project `class_name` declarations, exact `Enemy` global references or local `ready` declarations remained in the static scans.
- Godot was unavailable in the working environment. Godot 4.7 import, typed global-class registration and gameplay remain pending the runtime checklist.

## 0.22.3 — Cumulative Set-Effect Class Recovery

Date: 2026-07-21

Baseline: 0.22.1 project. This patch deliberately includes all 0.22.2 changes again because runtime evidence showed the earlier overlay did not replace at least one target script.

### Corrected

- Removed unused global `class_name` registration from the Conduit, Gravemarch and Lattice runtime set-effect scripts. They are instantiated through their PackedScenes and have no typed consumers, so global registration was unnecessary.
- Re-included the `EnemyActor` compatibility rename and all four `ready` to `is_ready` corrections from 0.22.2.
- Added installation instructions that require copying the contents into the directory containing `project.godot`, confirming file replacement, and rebuilding the generated `.godot` cache.

### Runtime boundary

- All 242 project GDScript files passed an external syntax parse after the cumulative overlay.
- The three set-effect global names no longer occur as `class_name` declarations, and no local `ready` declarations remain.
- Godot runtime validation remains required on the playtest PC.

## 0.22.4 — Full-Archive Overlay Repair

Date: 2026-07-21

Baseline: uploaded `syntethic-ascension-0.0.0.22.zip` plus the supplied 0.21 tutorial, Godot 4.7 type, UI runtime, and item-icon/health-pickup archives.

### Corrected

- Found that the full 0.22 archive contained the cumulative 0.22.1–0.22.3 repair files inside a nested `syntethic-ascension/` folder instead of overlaid at the directory containing `project.godot`.
- Overlaid the cumulative repair files onto the real project root and removed the nested patch tree from the repaired full build.
- Removed the generated `.godot` cache from the distributed archive so Godot rebuilds its global script-class registry from the corrected single source tree.
- Restored one consistent enemy type contract: `enemy.gd` registers `EnemyActor`, and all typed enemy setup consumers accept `EnemyActor`.
- Preserved the `ready` to `is_ready` compatibility corrections in Conduit, Gravemarch, Lattice, and `ActiveAbilityHUD`.
- Preserved the restored item icons, health pickup, save-card/Respite work, themed trade confirmation, UI runtime fixes, and the newer 0.22 projectile/set-readability systems.

### Patch audit

- Every file path from the 0.21 tutorial-architecture full archive is present. Files that differ are later revisions rather than missing paths.
- Every file path from the 0.21 item-icon/health-pickup, UI-runtime, and Godot-4.7-type patch archives is present. Byte differences were reviewed as later collision, lifecycle, Respite, class-name, or signal-shadow fixes.
- No nested `project.godot`, duplicate project source tree, exact `class_name Enemy`, local `var ready`, or duplicate global `class_name` declaration remains in the repaired distribution tree.

### Runtime boundary

- Static source/resource audits were run after rebuilding the full archive.
- Godot is unavailable in the repair environment, so Godot 4.7 import, typed compilation, gameplay, UI layout, save behaviour, collision feel, and performance remain pending the runtime checklist.

## 0.22.5 — UI Fit and Backpack Set Marks

Date: 2026-07-21

Baseline: repaired full build `syntethic-ascension-0.0.0.22.4-repaired-full.zip`.

### Corrected

- Increased and rebalanced save-card layout space so the selected save details no longer intersect the character footer and action buttons.
- Changed the save-card footer into an attached lower section instead of a second rounded panel floating over the detail area.
- Moved the in-run objective panel below the collapsed backpack with a deliberate visual gap.
- Added viewport-aware positioning to the Inventory/Stash item tooltip. Long tooltips retain their text size and move above or beside the cursor when the lower or right screen edge would clip them.
- Added equipment-set emblems to shared `BagSlot` controls, covering the HUD backpack and Hub backpack/trade grids in addition to the existing equipped and Inventory/Stash slot presentation.

### Runtime boundary

- Changed scripts and scenes passed static source, resource-path, UID, and patch-archive checks.
- Godot 4.7 runtime layout and interaction verification remains required on the playtest PC.

## 0.22.6 — Deferred Barrier Collision and Trade Focus Hotfix

Date: 2026-07-21

Baseline: repaired full build `syntethic-ascension-0.0.0.22.4-repaired-full.zip`. This release is cumulative and includes the complete 0.22.5 UI patch.

### Corrected

- Deferred the Segment 1 wall/fence connection refresh triggered by milestone `Area2D.body_entered` signals until PhysicsServer2D has finished flushing queries.
- Coalesced repeated barrier refresh requests and stopped reapplying every unchanged wall and fence twice. Only nodes whose connection mask actually changed are refreshed.
- Changed dynamic wall and fence `CollisionShape2D`/`CollisionPolygon2D` enabled-state writes to `set_deferred()`, protecting future callers that may also run inside physics callbacks.
- Added an unchanged-mask guard to `FenceBlock`, matching the existing wall guard and avoiding redundant visual, collision, and projectile-geometry rebuilds.
- Restored keyboard focus eligibility on the trade popup's Cancel and Confirm buttons and deferred Confirm focus until the popup is visible.
- Re-included the 0.22.5 save-card layout, objective placement, viewport-clamped Inventory/Stash tooltip, and shared backpack set-emblem changes.

### Runtime boundary

- Static source, scene, resource-path, global-class, and patch-archive checks were run after the cumulative overlay was assembled.
- Godot 4.7 is unavailable in the packaging environment. Barrier collision behavior, debugger silence, trade keyboard focus, and the cumulative UI changes require the supplied runtime checklist on the playtest PC.

## 0.22.6a — Direct-Overlay Packaging Repair

Date: 2026-07-22

Baseline: repaired full build `syntethic-ascension-0.0.0.22.4-repaired-full.zip`, with or without a correctly installed 0.22.5/0.22.6 patch.

### Corrected

- Repackaged the unchanged 0.22.6 cumulative payload directly at the archive root. Extracting it into the directory containing `project.godot` now overlays `core/`, `scenes/`, `ui/`, and the documentation without creating a second `syntethic-ascension/` source tree.
- Added recovery instructions for moving an accidentally nested patch folder outside the project and rebuilding the generated `.godot` script-class cache.
- Documented the expected post-install invariant: exactly one `FenceBlock.gd`, `Level1Builder.gd`, `BagSlot.gd`, `InventoryStash.gd`, and `TradeConfirmPopup.gd` must remain under the project root.

### Code status

- Gameplay and UI code are identical to 0.22.6 except for this append-only log and manifest update.
- The direct-overlay archive passed duplicate-global-class, resource-path, payload-path, and compressed-data checks.

## 0.23.0 — Playable Historical Opening

Date: 2026-07-22

Baseline: uploaded cumulative `syntethic-ascension-0.0.0.22.6.zip`.

### Added

- Replaced the fresh Segment 1 title-card entry with a playable top-down opening in the existing laboratory: restrained historical framing, apparatus camera focus, Bren dialogue, three player-activated synthesis nodes, selected-style calibration, one controlled construct, a manual officer confrontation, death emphasis, records-conduit separation and first-Follower commitment.
- Introduced Bren by name and professional role, Lattice Specialist. Bren remains dialogue-only; no escort or mismatched placeholder character sprite was added.
- Added visually distinct historical, character-dialogue, institutional, synthetic, compact-prompt and human Follower presentation styles.
- Added full (first profile completion), short (later new attempts), skip, replay-next-run and developer-reset behavior. Base exposes a normal replay checkbox after the full sequence has been seen.
- Added attempt phase/resume state, response disposition history, officer/Bren completion flags, Follower-explanation state and legacy save migration.
- Extended the hidden developer panel with all modes, phase jumps, all four response dispositions, officer/death/Bren starts and direct Segment 2/5/10 launches.

### Changed

- Bren now becomes the first actual Follower; a fresh attempt begins at zero and reaches one only at the commitment beat.
- Synthesis success, containment, arrest, lethal escalation and separation are converted from generic tutorial treatment into dialogue/announcement/world presentation. Compact controls, enemy dossiers, Wardstone discovery and first-death reconstruction teaching remain.
- Scripted opening actors cannot drop loot or grant ordinary combat Followers. The officer ignores passive damage until the player deliberately presses Attack during the confrontation.
- Ambient spawning is forced off throughout the opening and resumes at the existing Archive profile with 4.5 seconds of grace.
- Removed the uploaded nested patch source tree and generated cache from the distributable build, leaving one `FenceBlock` global class.

### Known placeholders

- Bren has no portrait or world sprite.
- Apparatus, calibration, construct and officer presentation use lightweight geometric drawing.
- Existing licensed project sounds stand in for dedicated apparatus, alarm and muffled-after-death assets.

### Runtime boundary

- Static source, global-class, resource-path, scene and archive checks are performed during packaging.
- No Godot 4.6 or 4.7 executable is installed in this environment. Typed script loading, save migration, imported assets, cinematic/short-mode pacing, camera feel, UI fit, input, physics, audio, spawner timing and gameplay transitions are not runtime-verified. `TESTING_CHECKLIST_0.23.0.md` is mandatory before release certification.

## 0.23.1 — Godot 4.7 Opening Startup Hotfix

Date: 2026-07-22

Runtime report: Godot 4.7.1 rejected inferred typing for `resume_phase` because its source was an autoload property, then the opening-world scene drew before its interaction-node array was configured.

### Corrected

- Declared `resume_phase: int` and explicitly converted the saved autoload value.
- Initialized the world stage count to zero and bounded drawing by `_nodes.size()` so pre-configuration draws are safe.
- Scanned the new opening scripts for equivalent autoload-inference declarations; no second occurrence remains.

### Validation boundary

- All 247 GDScript files pass the independent syntax grammar after the edit.
- Godot is still unavailable in the packaging environment. The reporter's Godot 4.7.1 runtime must confirm script loading and opening startup with `TESTING_CHECKLIST_0.23.1.md`.

## 0.23.2 — Opening Camera, Calibration and Objective Hotfix

Date: 2026-07-22

Runtime report: cinematic camera offset remained attached while the player was released, the calibration actor was absent from the managed-projectile spatial index, and Segment 1 published the escape objective before the opening sequence finished.

### Corrected

- Limited locked-shot camera framing to a restrained 144 px offset and now restores the player's original Camera2D position before movement or attack control is released. Mouse/world aim no longer inherits a moving child-camera offset.
- Registered every scripted opening actor with `EnemyIndex`, updates moving actors' spatial cells, and unregisters actors on death or tree exit. Managed ranged attacks can now acquire the calibration target, construct and officer through the normal projectile path.
- Added an opening-owned calibration fallback tied to `RunEvents.weapon_fired`. A correctly aimed selected-style attack completes the calibration even if a later physics contact is lost, preventing an indefinite `await target.defeated` softlock.
- Suppressed Segment 1 objective publication from the first Level1Builder objective update until `finish_opening_sequence()`. The escape objective now appears only after the opening has completed and control has been returned.

### Validation boundary

- All 247 GDScript files pass the independent syntax grammar after the edit.
- Static signal, spatial-index, camera-release and objective-suppression checks pass.
- Godot is unavailable in the packaging environment. Camera feel, selected-style calibration and objective timing require the supplied Godot 4.7.1 runtime checklist.

## 0.23.3 — New-Attempt Inventory Initialization Hotfix

Date: 2026-07-22

Runtime report: the playable opening completed correctly, but world pickups repeatedly warned `run_inventory is null` and could not be collected.

### Corrected

- Restored the original `start_new_attempt()` world-seed assignment and `reset_run_systems()` call that were accidentally omitted by the opening rewrite. Fresh attempts now construct equipped inventory, backpack, luck, tutorial and exploration state before the game scene binds them.
- Added a non-destructive game-entry repair for 0.23.0-0.23.2 attempt snapshots. If an active attempt contains a null equipped inventory or bag, only the missing container is created before HUD, stats, autosave and pickup bindings run.
- Left `ItemPickup`'s null guard intact. Missing run state remains diagnosable instead of being silently created at the moment an item touches the player.

### Validation boundary

- All 247 GDScript files pass the independent syntax grammar after the edit.
- Static ordering confirms inventory repair runs before save/HUD bindings and fresh-attempt reset runs before the attempt is persisted.
- Godot 4.7.1 runtime pickup verification remains required.

## 0.24.2 — Cethiel Ground Integration and WorldArt Loader Repair

Date: 2026-07-22

Baseline: uploaded `syntethic-ascension-0.0.0.24.1-ground-rework-full.zip` and five supplied Cethiel tileable ground packs.

### Runtime report

- Godot 4.7.1 rejected `WorldArt.GROUND_TEX` as an unresolved external class member from `ChunkManager.gd`.
- The replacement city substrate rendered as a large flat gray field and did not read as authored ground.

### Corrected

- Removed the generated-cache-sensitive global `WorldArt` member contract. `ChunkManager` and the procedural floor stamper now explicitly preload `WorldArt.gd` and access textures through typed static getter functions.
- Removed the distributed `.godot` directory so Godot rebuilds imports and script metadata from the corrected source tree.
- Replaced the active gray procedural materials with processed CC0 Cethiel textures: mossed city blocks, rectangular street paving, irregular cobble, square interior/gate tiles, packed dirt, rutted mud and restrained grass.
- Increased the material repeat span from 512 to 1024 world pixels, matching the processed 1024×1024 assets and preventing the paving pattern from becoming a dense micro-grid.
- Disabled per-chunk brightness drift entirely so continuous surfaces do not reveal 2048-pixel chunk rectangles.
- Preserved the original 0.23 noisy textures, the rejected gray 0.24.1 set, and untouched selected Cethiel diffuse/normal sources in clearly named asset subfolders.
- Updated `GROUND_TEXTURE_PATCH.md` with the active texture mapping, provenance and loader architecture.
- Added direct-overlay installation instructions and a focused Godot 4.7.1 import/Segment 2 runtime checklist.

### Runtime boundary

- Archive, resource-path, image-dimension and static source checks are performed during packaging.
- No Godot executable is installed in the packaging environment. Godot 4.7.1 import, typed compilation and an actual Segment 2 visual check remain required on the playtest PC.


## 0.25.0 — Open District Web Procedural Foundation

Date: 2026-07-22

Baseline: uploaded `syntethic-ascension-0.0.0.24.2-cethiel-ground-full.zip`.

### Design target

- Preserve a readable escape direction without reducing each segment to a corridor.
- Keep the streamed world open beyond the authored route graph: the player can leave the main and secondary routes, cross unplanned chunks, discover ordinary ruins/buildings and return from another direction.
- Make side travel intentional through longer branches, reconnecting lanes, optional interiors, landmarks and guaranteed rewards at true exploration endpoints.

### Procedural generation changes

- Replaced the old Explore/Escape blend with progression-aware Area 1 district themes: Service Courtyards, Checkpoint Lanes, Collapsed/Civilian wards, Inner District Gate, Industrial/Ruined Services, Underpass/Canal routes, Rail/Military districts, Outer Wall approaches and the fixed Gate District capstone.
- Expanded `DistrictPlan` into a macro route contract containing a main route, secondary paths, an exploration web, short reconnects, landmark positions, reward endpoints and semantic chunk roles.
- Added semantic roles for entry courts, main streets, secondary routes, service lanes, optional interiors, exploration rewards, landmark plazas, checkpoints, Wardstone courts, exit approaches, gates and boss arenas.
- Kept the planned web deliberately finite while leaving ChunkManager streaming infinite. Chunks outside the authored plan use ordinary procedural generation rather than collision walls, void tiles or invisible boundaries.
- Added deterministic terrain metadata per planned chunk and a natural fallback terrain for unplanned exploration chunks.
- Added progression-aware landmarks and checkpoint barricade language without sealing the road core.
- Optional-interior endpoints now strongly request streetfront parcel generation and guaranteed parcel loot.
- True exploration endpoints now create deterministic guaranteed loot spawners.
- Corrected procedural loot initialization order across Donjon interiors, streetfront parcels and large sites: IDs, rarity, count and local position are now configured before the spawner enters the scene tree, so `_ready()` cannot discard an unconfigured spawner.
- Disabled the exploration-loot debug marker by default; the cyan placement ring can still be re-enabled explicitly during generator debugging.
- Segment 5 now places its required miniboss in the pre-gate route chunk, leaving a short final approach before the Exit Rite.

### Ground correction

- Replaced the dense oversized foliage/cobblestone-looking outdoor base with a darker patchy Cethiel CC0 grass-and-soil material.
- Planned roads, sidewalks, plazas and interiors remain separate structural overlays; open land beneath and beyond them is grass, dirt or mud according to district theme.
- Unplanned streamed chunks use natural fallback terrain with restrained deterministic dirt variation instead of the city-base stone slab.
- Preserved the previous active grass under `assets/world/ground/_legacy_dense_foliage_0242/` and preserved the untouched selected Cethiel diffuse/normal source maps.

### Current boundary

- This is the procedural foundation, not the final authored-module library. Roles now alter route width, floor language, plaza use, checkpoint cover, parcel preference, rewards and landmarks, but later work should add more unique architecture for warehouses, clinics, archives, residences, rail platforms and collapsed crossings.
- Static source, resource-path, archive and texture checks are performed during packaging.
- A Godot 4.7.1 executable could not be run in the packaging environment. Typed compilation, actual map readability, streaming transitions, combat clearance, site placement and visual scale require the supplied runtime checklist.

## 0.25.1 — Procedural Foundation Reliability and Splitter Patch

Date: 2026-07-22

Baseline: uploaded `syntethic-ascension-0.0.0.25.0-procedural-foundation-full.zip` plus the supplied audit and Splitter image.

### Import and procedural rewards

- Replaced direct ground-texture preloads in `WorldArt.gd` with cached, lazy resource loading and a source-image fallback. The seven 1024×1024 active ground textures remain unchanged.
- Optional-interior route endpoints now force at least one valid streetfront parcel instead of depending on two 55% side rolls. Their active `IndoorVolume` receives a 100% loot chance.
- Active parcel and multi-chunk site loot now receives count, rarity, scatter and deterministic IDs before entering the scene tree.
- `IndoorVolume` waits briefly for the item database, retries failed placement, classifies large sites from the complete site footprint, and claims a reward only after at least one pickup is placed.
- Exploration reward fallback searches for a real walkable cell and never places or claims an item at the blocked source point.

### Combat and population reliability

- Bomber proximity detonation now enters the ordinary death lifecycle before exploding, restoring the kill event, Follower transaction, health roll and item roll.
- Instance-based boss and miniboss drops honor `drop_amount_min`–`drop_amount_max` and create independently rolled `ItemInstance` pickups.
- Ambient multi-spawns reserve their deferred instances synchronously and clamp every batch against global and per-archetype remaining capacity.
- Summons, Splitter children and boss adds use a separate bounded special-population budget. They no longer consume ambient pressure, and ambient culling does not delete them as cap overflow.
- Boss and miniboss arenas mark themselves spawned only after validating an `EnemyActor`; invalid scene assignments leave the trigger available for retry.
- Ordinary combat drops expire after 120 seconds. Exploration rewards and player-dropped equipment remain persistent.
- Spawn/drop diagnostics are disabled by default in the spawner and enemy scene overrides.

### Splitter enemy

- Added the supplied green Splitter image, a dedicated `EnemySpec`, scene, dossier entry and late ambient-roster entry.
- A normal Splitter begins at 2× body scale with high health and low speed, divides into two normal-size bodies, then each divides into four half-size fast fragments.
- The extremely rare elite begins at 4× ordinary-enemy scale and follows 2/4/8 child-count stages while retaining elite state.
- Child placement requires walkable, unblocked space and consumes the bounded split population budget.

### Validation boundary

- Independent grammar parsing reports zero syntax errors in the 244 scripts the parser can represent; three unchanged oversized scripts exceed that parser library's input-size limit.
- Literal resource paths, active PNG dimensions, duplicate global classes, direct-overlay structure and ZIP integrity are checked during packaging.
- Godot is not installed in the packaging environment. Godot 4.7.1 typed compilation, import timing, deterministic map generation and combat behavior still require `TESTING_CHECKLIST_0.25.1.md`.

## 0.25.2 — Urban Objective Vertical Slice

Date: 2026-07-22

Baseline: uploaded `syntethic-ascension-0.0.0.25.1-procedural-reliability-full(2).zip`, the supplied procedural-city reference image and five tileable Cethiel texture packs.

### Segment direction and pacing

- Added a deterministic mission layer to procedural Segments 2–10: one mandatory primary relay objective, a hidden generated exit and zero-to-three optional secondary opportunities. Segment 2 always demonstrates both secondary templates.
- Added the Recon, Disturbance, Ascension and Collapse pressure phases to the existing `ThreatDirector`. Objective activation and completion change spawn cadence/elite pressure without replacing the existing resonance, carry, heat or overtime curves.
- Kept passive resonance but reduced it from `0.0040` to `0.0015` per second. Kills, elites and item pickups contribute more, and primary completion immediately grants 18% resonance.
- Increased route-distance targets and added deterministic retry validation for start, primary, exit, secondary reachability and reciprocal connector data.
- The primary objective is the initial HUD/navigation target. Completing it reveals the Exit Rite and transfers navigation guidance to the gate. Full resonance alone cannot bypass the primary objective.

### Objective vertical slice

- Added **Silence the District Relay**, a plaza landmark containing three short attunement nodes. The player must move between nodes while ambient/objective socket pressure rises; it is not one long stationary capture circle.
- Added the dangerous-alley cache template. Its final route uses 2-cell passages and always carries deterministic high-rarity exploration loot.
- Added the searchable reward-building template. Entering starts a local encounter; the reward is released only after its spawned enemies leave the encounter lifecycle.
- Interior encounter enemies are created only on activation and are tagged outside the ambient enemy budget. Ordinary ambient spawning now rejects all active `IndoorVolume` rectangles.

### Streets, buildings and spawns

- Replaced axis-wide road stamping with exact connector arms. Corners, dead ends, T-junctions and crossroads now render only the directions present in the route graph.
- Added semantic road widths: 6–8-cell main roads, 5-cell secondary streets, 3-cell service/building routes and 2-cell dangerous passages.
- Extended streetfront parcel generation to corners, junctions and dead ends. Parcel bands use the real rendered arm span, and every generated door faces an actual street or courtyard edge.
- Removed the independent random corner-building pass that produced structures unrelated to roads. Connected Donjon rooms and parcels are registered as interiors, while ordinary ambient enemies use street, door, alley and objective spawn sockets.
- Added 1024×1024 civic brick, mossy brick and rounded cobble materials from the supplied tileable packs. Main streets, old secondary lanes and the relay landmark use them semantically rather than as whole-chunk random replacements.

### Validation boundary

- All modified scripts report zero diagnostics in a Godot 4.x-aware headless static analyzer. The project has no duplicate `class_name` declarations, the new resource paths resolve and the three integrated PNGs are valid 1024×1024 images.
- `tools/ProcPlanSmokeTest.gd` is included for deterministic multi-seed validation from a Godot command line.
- Godot 4.7.1 is unavailable in the packaging environment. Import, typed engine compilation, runtime navigation, streamed geometry, encounter feel and final visual scale remain pending the included first-play checklist.

## 0.25.3 — Urban Blocks and Secondary Lifecycle

- Fixed secondary objectives remaining on the HUD after leaving or completing their area.
- Added deterministic secondary IDs and real completion notifications from building encounters and alley-cache pickups.
- Added a Service Courtyards urban envelope around the street graph.
- Added separately planned reciprocal pedestrian access so courtyards connect without becoming fake roads.
- Rebuilt street parcels as dense frontage rows with row-house, shop, workshop and passage templates.
- Added enterable courtyard blocks, local spawn sockets, roof variants and semantic floor use.
- Added validation for inaccessible or non-reciprocal urban blocks.

## 0.25.4 — Exchange and Cleanup QoL

Date: 2026-07-23

Baseline: uploaded `syntethic-ascension-0.0.0.25.3.zip` and the supplied HUB/BG3 trade-screen comparison images.

### HUB exchange

- Rebuilt the HUB trader presentation around a compact five-column exchange layout with a warm ink/bronze backdrop and restrained ornamental geometry.
- Added a dedicated viability status, disabled impossible/empty exchanges, revalidated on confirmation and accounted for bag slots freed by the offer.
- Added an Affordable stock filter based on current Followers plus offered value.

### Population reliability

- Lowered the ambient culling threshold, increased culling frequency/batch size and added proactive far-enemy retirement.
- Added stale cleanup for distant, stationary, non-elite ambient enemies.
- Added EnemyIndex maintenance rebuilding for invalid or duplicate registry entries while preserving protected special populations.

### Sustain and objective feedback

- Extended capped lifesteal to melee, ranged and magic, weighted toward melee while retaining melee passive regeneration.
- Replaced post-relay gate prose with a live requirement checklist and LOCKED/LOCATED/READY state.
- Added secondary-completion pulse, type-specific text and delayed clearing.

### Validation boundary

- Static modified-source, resource, scene hierarchy, HUB node-path and duplicate global-class checks passed.
- The Godot 4.7.1 executable archive could not be executed in the packaging runtime; engine import, typed compilation and runtime behavior remain covered by `TESTING_CHECKLIST_0.25.4.md`.
