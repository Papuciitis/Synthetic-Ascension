# 0.21 Tutorial Pacing + Combat Architecture Patch Manifest

# 0.23.1 Godot 4.7 Opening Startup Hotfix

Applies directly over 0.23.0. It adds an explicit `int` type at the saved-phase read and makes the opening-world startup draw safe before node configuration. See `HOTFIX_MANIFEST_0.23.1.md` and `TESTING_CHECKLIST_0.23.1.md`.

# 0.23.0 Playable Historical Opening

Built from the uploaded cumulative 0.22.6 project. This release removes the accidentally nested duplicate source tree that caused `FenceBlock` to hide a global script class, then adds the full/short/skip playable Segment 1 opening, Bren dialogue, manual officer confrontation, first-Follower commitment, save migration, replay/developer controls and focused documentation.

The changed/new-only list, assumptions, tutorial conversion list, save fields and runtime boundary are in `CHANGE_MANIFEST_0.23.0.md`. Installation is direct-overlay per `INSTALL_PATCH_0.23.0.txt`; runtime coverage is in `TESTING_CHECKLIST_0.23.0.md`.

## Baseline

Built from the attached complete `syntethic-ascension0.0.0.20-segment1-rebuild-full(2).zip`.

Verified baseline SHA-256:

`59fd8d10a3ce83910cc8284af362041279cd9a9b2d2f178a12d24667a188bfa8`

The 0.20 five-stage Segment 1 route, mortal name, assistant event, Resonance milestones, completion report, save protection and later-segment developer launches were preserved.

## Changed files

- `autoload/RunEvents.gd`
- `autoload/SaveData.gd`
- `autoload/global.gd`
- `core/actors/enemy/enemy.gd`
- `core/actors/enemy/modules/EnemyHerald.gd`
- `core/actors/enemy/modules/EnemyLeech.gd`
- `core/actors/enemy/modules/EnemyLifecycle.gd`
- `core/actors/enemy/modules/EnemyShooter.gd`
- `core/actors/player/player.gd`
- `core/systems/items/ItemEffectRunner.gd`
- `core/systems/spawner/spawner.gd`
- `core/systems/world/ExitRite.gd`
- `core/systems/world/Level1Builder.gd`
- `data/items/Inventory.gd`
- `effects/items/logic/FirestoneEffect.gd`
- `project.godot`
- `scenes/game.gd`
- `scenes/world/events/BossArena.gd`
- `scenes/world/events/MiniBossArena.gd`
- `ui/components/InventoryBar.gd`
- `ui/components/InventoryBar.tscn`
- `ui/components/InventorySlotView.gd`
- `ui/screens/HubShop.gd`
- `ui/screens/MainMenu.gd`
- `ui/screens/MainMenu.tscn`
- `ui/screens/hud.gd`
- `PROJECT_STRUCTURE.md`
- `SEGMENT1_REBUILD.md`
- `RECOVERY_AUDIT.md`

## Added files

- `core/combat/hits/HitLedger.gd`
- `core/combat/hits/HitProfileAdapter.gd`
- `core/combat/projectile/ProjectileSimulationManager.gd`
- `core/systems/spawner/Segment1SpawnProfile.gd`
- `data/enemies/EnemyDossierCatalog.gd`
- `ui/components/InventorySlotView.tscn`
- `ui/controllers/FollowerFeedbackUI.gd`
- `ui/controllers/TutorialModalController.gd`
- `ui/screens/TutorialCardOverlay.gd`
- `ui/screens/TutorialCardOverlay.tscn`
- `PROJECTILE_HIT_ARCHITECTURE.md`

## Functional changes

- Segment 1 pressure is milestone-driven with staged rosters/caps and no synthesis/security burst spikes.
- Contact damage deduplicates Area/body overlap and uses one tick loop with capped swarm scaling.
- First-encounter dossiers pause safely, queue, and persist once per profile.
- Equipped slots are generated from central slot definitions.
- Ordinary ranged and generic enemy bullets use dense simulation, swept collision and MultiMesh rendering.
- Same-frame compatible hits use `HitLedger` aggregation.
- Follower changes use reasoned, clamped transactions with contextual feedback.
- The assistant remains the first Segment 1 follower; reconstruction now has an explicit presentation.

## Assumptions

- Existing placeholder/enemy textures are acceptable dossier images until final portraits exist.
- Segment 1 stage values are initial tuning values and require a first-play runtime pass.
- Contact swarm scaling of `1.0 + 0.35 × extra unique enemies`, capped at `2.25`, is a readable starting point.
- The generic `EnemyProjectile.tscn` used by normal `EnemyShooter` is safe to migrate; boss-owned uses remain node-based.
- Firestone is the only current item effect that directly mutates ordinary ranged bullets; it received an explicit managed-profile hook.
- Existing dynamic Bag/Stash/Hub slot builders were retained; the confirmed fixed `InventoryBar.tscn` was rebuilt.
- The requested full Respite redesign, Area 2 and later story chapters remain out of scope.
- “Intro” in this patch means the existing opening card plus paced synthesis/containment/follower/enemy teaching. It does not add a new cinematic sequence beyond the supplied scope.

## Static verification and limitation

- ZIP baseline SHA and CRC: verified before editing.
- 234 GDScript files parse with `gdtoolkit 4.5.0`.
- 937 project files pass the independent path/UID/resource audit with zero fatal or suspicious findings.
- No loose `.tmp` scene files are present.

Godot 4.6 was unavailable. Import, runtime, collision feel, UI layout at target resolutions, save migration in-engine and performance counters are not runtime-verified. No performance improvement is claimed from static inspection alone.

# 0.22 Projectile Collision + Set Readability Patch Manifest

## Baseline

Built from the uploaded `syntethic-ascension0.0.0.21b(1).zip` (SHA-256 `66062fd0a52cc0048b344e816c66eb8c3b2fd372483d0b47881ec35b5811446e`).

## Functional manifest

- Intended-shape projectile world collision with grid DDA broad phase and swept rect/circle narrow phase.
- Shared blocker descriptors for walls, transparent windows, fences, half cover and conservative unknown cells.
- Consistent world collision for managed bullets and all four current node projectile scripts.
- Central, inspectable Conduit/Gravemarch/Lattice identity and 2/4/6-tier explanations.
- Tooltip pips, active/next/later hierarchy, best-with guidance, glossary and actual-slot replacement consequences.
- Set emblems across equipped/bag/stash/Hub slot controls.
- Player-driven breakpoint gain/loss presentation without save-load spam.
- Authoritative active readiness plus Conduit prime, Gravemarch bank and Lattice mark combat feedback.
- Developer-only set/collision/stress controls.

## 0.22 changed files

- `PATCH_MANIFEST.md`
- `PROJECTILE_HIT_ARCHITECTURE.md`
- `PROJECT_STRUCTURE.md`
- `RECOVERY_AUDIT.md`
- `autoload/global.gd`
- `core/combat/projectile/EnemyProjectile.gd`
- `core/combat/projectile/ProjectileSimulationManager.gd`
- `core/systems/inventory/InventoryRouter.gd`
- `core/systems/world/ChunkManager.gd`
- `data/items/Inventory.gd`
- `data/sets/SetData.gd`
- `data/sets/SetTier.gd`
- `data/sets/conduit/Conduit.tres`
- `data/sets/gravemarch/Gravemarch.tres`
- `data/sets/lattice/Lattice.tres`
- `effects/augments/logic/MagicMissileProjectile.gd`
- `effects/augments/logic/ReflectedProjectile.gd`
- `effects/conduit/scenes/ConduitOverclockAndFeedback.gd`
- `effects/conduit/scenes/ConduitOverclockAndFeedback.tscn`
- `effects/gravemarch/scenes/GravemarchMassArrest.gd`
- `effects/lattice/scenes/LatticeAfterstrike.tscn`
- `effects/lattice/scenes/LatticeEchoBuffer.gd`
- `effects/lattice/scenes/LatticeEchoBuffer.tscn`
- `project.godot`
- `scenes/world/combat/RangedBullet.gd`
- `scenes/world/cover/CoverHalf.gd`
- `scenes/world/cover/CoverHalfLab.gd`
- `scenes/world/cover/CoverWall.gd`
- `scenes/world/fence/FenceBlock.gd`
- `ui/components/InventorySlotView.gd`
- `ui/screens/HUD.tscn`
- `ui/screens/HubShop.gd`
- `ui/screens/HubShop.tscn`
- `ui/screens/InventoryStash.gd`
- `ui/screens/InventoryStash.tscn`
- `ui/screens/MainMenu.gd`
- `ui/screens/MainMenu.tscn`
- `ui/widgets/ActiveAbilityHUD.gd`
- `ui/widgets/ActiveAbilityHUD.tscn`
- `ui/widgets/HubItemSlot.gd`
- `ui/widgets/ItemTooltip.gd`

## 0.22 added files

- `DEVELOPMENT_LOG.md`
- `TESTING_CHECKLIST_0.22.md`
- `autoload/DevSetCollisionTools.gd`
- `core/systems/world/WorldBlockerGeometry.gd`
- `effects/lattice/scenes/LatticeMarkVfx.gd`
- `ui/controllers/SetBreakpointNotifier.gd`
- `ui/widgets/SetEmblem.gd`

## Assumptions and decisions

- Window wall art remains player/LoS geometry but intentionally permits projectiles, matching its existing “shoot-through” contract.
- A registered blocker cell contains one authoritative blocker owner. Unknown/manual blocked cells remain full-cell fallbacks.
- Half cover uses its existing 16 px fallback circle as the intentional collision shape; alpha-generated polygons are disabled by default.
- Homing magic missiles and reflected projectiles now stop on authored world blockers. Their target/damage behavior is otherwise unchanged.
- No new save field was necessary. Central resource defaults cover old saves, and presentation state is transient.
- Stale effect text corrected: Conduit 6-piece active naming, Lattice 4-piece Afterstrike wording, Lattice 6-piece mark/Index wording.

## Explicitly excluded

No cinematic intro, lore expansion, proc redesign, Area 2, Respite overhaul or broad Hub redesign is included.

## Verification boundary

The archive and references receive static validation during packaging. Godot was unavailable, so parser/import/runtime collision/UI/save/performance claims are deliberately withheld. See `TESTING_CHECKLIST_0.22.md`.

# 0.22.1 Restoration Patch

## Baseline

Apply only to the extracted `syntethic-ascension0.0.0.22-projectile-set-readability-full.zip` project. The baseline archive SHA-256 is `85905ecc14622a5d144e4c3ddeb5cd4dfa54169f4aaf16f929ec4941817389e6`.

## Changed files

- `DEVELOPMENT_LOG.md`
- `PATCH_MANIFEST.md`
- `autoload/SaveManager.gd`
- `assets/textures/items/conduit/*.png` (6 restored icons)
- `assets/textures/items/gravemarch/*.png` (6 restored icons)
- `assets/textures/items/lattice/*.png` (6 restored icons)
- `assets/textures/items/offhand/*.png` (2 restored icons)
- `assets/textures/items/rings/*.png` (2 restored icons)
- `core/actors/enemy/enemy.gd`
- `core/actors/enemy/modules/EnemyDrops.gd`
- `core/actors/enemy/modules/EnemyLifecycle.gd`
- `ui/components/SaveCard.gd`
- `ui/components/SaveCard.tscn`
- `ui/controllers/HudTutorialTipController.gd`
- `ui/screens/HubShop.gd`
- `ui/screens/HubShop.tscn`
- `ui/screens/SaveSelect.gd`

## Added files

- `TESTING_CHECKLIST_0.22.1.md`
- `assets/textures/items/pickups/health_pickup.png`
- `scenes/world/pickups/HealthPickup.gd`
- `scenes/world/pickups/HealthPickup.tscn`
- `ui/data/respite_flavor_lines.txt`
- `ui/widgets/RotatingFlavorLabel.gd`
- `ui/widgets/RotatingFlavorLabel.tscn`
- `ui/widgets/TradeConfirmPopup.gd`
- `ui/widgets/TradeConfirmPopup.tscn`

## Tunable health-drop defaults

- Chance per ordinary enemy death: `0.03`
- Restored health: `0.20 × max_hp`
- Floor lifetime: `20.0` seconds

All three values are exported on `Enemy` and can be overridden per enemy scene.

# 0.22.2 Godot 4.7 Class/Shadow Fix Patch

## Baseline

Apply only after the 0.22.1 restoration patch. The 0.22.1 patch archive SHA-256 is `b7a76925e7962a74a43bbf50cb50ac10f240f21ae9af9b91a19d456ba93e33bf`.

## Changed files

- `DEVELOPMENT_LOG.md`
- `PATCH_MANIFEST.md`
- `assets/vfx/world/enemies/VFX_BomberHazardRing.gd`
- `core/actors/enemy/brains/EnemyHordeNav.gd`
- `core/actors/enemy/brains/EnemyNavigator.gd`
- `core/actors/enemy/brains/EnemySenses.gd`
- `core/actors/enemy/brains/EnemySeparationSystem.gd`
- `core/actors/enemy/enemy.gd`
- `core/actors/enemy/modules/EnemyBomber.gd`
- `core/actors/enemy/modules/EnemyCharge.gd`
- `core/actors/enemy/modules/EnemyDrops.gd`
- `core/actors/enemy/modules/EnemyHerald.gd`
- `core/actors/enemy/modules/EnemyInit.gd`
- `core/actors/enemy/modules/EnemyLeech.gd`
- `core/actors/enemy/modules/EnemyLifecycle.gd`
- `core/actors/enemy/modules/EnemyOrbit.gd`
- `core/actors/enemy/modules/EnemyShooter.gd`
- `core/actors/enemy/modules/EnemySniper.gd`
- `core/actors/enemy/modules/EnemySplitter.gd`
- `core/actors/enemy/modules/EnemySummoner.gd`
- `core/actors/enemy/modules/EnemyTactical.gd`
- `effects/conduit/scenes/ConduitOverclockAndFeedback.gd`
- `effects/gravemarch/scenes/GravemarchMassArrest.gd`
- `effects/lattice/scenes/LatticeEchoBuffer.gd`
- `scenes/world/bosses/BossArcanistBrain.gd`
- `scenes/world/bosses/BossBulldozerBrain.gd`
- `scenes/world/events/BossArena.gd`
- `scenes/world/events/MiniBossArena.gd`
- `ui/controllers/HudBossController.gd`
- `ui/widgets/ActiveAbilityHUD.gd`

## Added files

- `INSTALL_PATCH_0.22.2.txt`
- `TESTING_CHECKLIST_0.22.2.md`

The previous 0.22.1 manifest line naming the health-drop exports on `Enemy` describes that release's original class name. In 0.22.2 those same exports are on `EnemyActor`.

# 0.22.3 Cumulative Godot 4.7 Class Fix Patch

## Baseline and supersession

Apply to the 0.22.1 project. This cumulative patch supersedes 0.22.2 and safely replaces the same files if 0.22.2 was partially or fully installed.

It contains every 0.22.2 file plus these 0.22.3 additions:

- Removes unused global class registration from `ConduitOverclockAndFeedback.gd`.
- Removes unused global class registration from `GravemarchMassArrest.gd`.
- Removes unused global class registration from `LatticeEchoBuffer.gd`.
- Adds `INSTALL_PATCH_0.22.3.txt` and `TESTING_CHECKLIST_0.22.3.md`.

Scene filenames, PackedScene resource paths and scene node names are intentionally unchanged.

# 0.22.4 Full-Archive Overlay Repair

## Baseline and cause

The uploaded 0.22 full archive contained the 0.22.1–0.22.3 cumulative repair payload under a nested `syntethic-ascension/` directory. Godot scanned both the unrepaired root scripts and the nested repaired scripts, producing mixed `Enemy`/`EnemyActor` global-class signatures and retaining the three local `ready` warnings in the outer tree.

## Packaging repair

- Applied the nested cumulative repair payload to the directory containing `project.godot`.
- Distributed one project source tree only; the nested payload and empty nested project directory are absent.
- Excluded the generated `.godot` cache so the receiving editor rebuilds its script-class cache.
- Retained all 0.22 projectile-collision and equipment-set-readability files.
- Retained every path supplied by the four audited 0.21 archives, using later versions where the 0.22/0.22.1–0.22.3 work intentionally supersedes older bytes.

## Verified compatibility state

- `core/actors/enemy/enemy.gd` registers `EnemyActor`.
- Enemy modules, brains, boss scripts, arenas, VFX, and HUD consumers consistently reference `EnemyActor`.
- Conduit, Gravemarch, Lattice, and `ActiveAbilityHUD` use `is_ready` locals while continuing to return/read the dictionary key `"ready"`.
- The three PackedScene-instantiated set effect scripts have no unnecessary global `class_name` declarations.

## Added file

- `TESTING_CHECKLIST_0.22.4.md`

## Verification boundary

Static checks passed. Godot 4.7 was unavailable; engine import and runtime results are not claimed.

# 0.22.5 UI Fit + Backpack Set Emblem Patch

## Baseline

Apply to `syntethic-ascension-0.0.0.22.4-repaired-full` by copying the patch's `syntethic-ascension/` contents into the directory containing `project.godot` and replacing matching files.

## Changed files

- `DEVELOPMENT_LOG.md`
- `PATCH_MANIFEST.md`
- `ui/bag/BagSlot.gd`
- `ui/components/SaveCard.gd`
- `ui/components/SaveCard.tscn`
- `ui/overlays/GateOverlay.tscn`
- `ui/screens/InventoryStash.gd`

## Added files

- `INSTALL_PATCH_0.22.5.txt`
- `TESTING_CHECKLIST_0.22.5.md`

## Behaviour

- Selected save details and the save footer occupy separate vertical regions.
- The objective panel clears the collapsed backpack.
- Inventory/Stash tooltips are measured at their normal 460 px width, placed on the opposite side of the cursor when necessary, and clamped to an 8 px viewport margin without reducing text size.
- Shared `BagSlot` instances now render the same central set emblem data used by equipped and Hub inventory slots.

## Verification boundary

Static checks passed. Godot 4.7 runtime verification remains required.

# 0.22.6 Cumulative UI + Physics-Flush Hotfix

## Baseline and supersession

Apply directly to `syntethic-ascension-0.0.0.22.4-repaired-full` by copying the patch's `syntethic-ascension/` contents into the directory containing `project.godot` and replacing matching files.

This cumulative patch contains all 0.22.5 code changes. Do not install 0.22.5 first. It is also safe to apply if 0.22.5 was already copied.

## Changed files

- `DEVELOPMENT_LOG.md`
- `PATCH_MANIFEST.md`
- `core/systems/world/Level1Builder.gd`
- `scenes/world/cover/CoverWall.gd`
- `scenes/world/fence/FenceBlock.gd`
- `ui/bag/BagSlot.gd`
- `ui/components/SaveCard.gd`
- `ui/components/SaveCard.tscn`
- `ui/overlays/GateOverlay.tscn`
- `ui/screens/InventoryStash.gd`
- `ui/widgets/TradeConfirmPopup.gd`
- `ui/widgets/TradeConfirmPopup.tscn`

## Added files

- `INSTALL_PATCH_0.22.6.txt`
- `TESTING_CHECKLIST_0.22.6.md`

## Runtime behavior

- Segment 1 barrier removal no longer rebuilds live physics shapes from inside the milestone overlap callback.
- Repeated barrier requests are coalesced, unchanged connection masks are skipped, and dynamic wall/fence collision enabled states are deferred.
- The themed trade confirmation popup can focus Confirm without emitting `Control can't grab focus` warnings.
- All save-card, objective-panel, Inventory/Stash tooltip, and backpack set-emblem work from 0.22.5 is included.

## Verification boundary

Static checks passed. Godot 4.7 runtime verification remains required.

# 0.22.6a Direct-Overlay Packaging Repair

## Purpose

This archive contains the same cumulative code as 0.22.6 but places the payload directly at the ZIP root. It prevents the patch wrapper directory from becoming a second Godot-scanned source tree when the archive is extracted into the project directory.

## Installation invariant

After cleanup and extraction, the project directory containing `project.godot` must contain `core/`, `scenes/`, and `ui/` directly. It must not contain a child patch directory named `syntethic-ascension/`.

Godot must find exactly one declaration of each global class carried by the patch, including `FenceBlock`, `Level1Builder`, `BagSlot`, `InventoryStash`, and `TradeConfirmPopup`.

## Payload

- All 0.22.5 UI changes.
- All 0.22.6 physics-flush and trade-focus changes.
- Updated `DEVELOPMENT_LOG.md` and `PATCH_MANIFEST.md`.
- `INSTALL_PATCH_0.22.6A.txt` and `TESTING_CHECKLIST_0.22.6.md`.

## Verification boundary

Static and archive checks passed. Godot 4.7 runtime verification remains required.

# 0.23.2 Opening Camera, Calibration and Objective Hotfix

## Baseline

Apply this direct-overlay hotfix over 0.23.0 or 0.23.1. It includes the 0.23.1 parser/draw corrections and the 0.23.2 runtime corrections.

## Changed files

- `core/systems/world/Level1Builder.gd`
- `core/systems/world/opening/OpeningActor.gd`
- `core/systems/world/opening/OpeningSequenceController.gd`
- `core/systems/world/opening/OpeningSequenceWorld.gd`
- `DEVELOPMENT_LOG.md`
- `PATCH_MANIFEST.md`

## Added files

- `HOTFIX_MANIFEST_0.23.2.md`
- `INSTALL_PATCH_0.23.2.txt`
- `TESTING_CHECKLIST_0.23.2.md`

## Runtime behavior

- Cinematic Camera2D offsets are bounded and cleared before player-controlled movement or aiming.
- Scripted opening targets use the ordinary `EnemyIndex` projectile path; calibration also has an aimed `weapon_fired` completion guard.
- Segment 1 objectives remain hidden until the playable opening finishes.

## Verification boundary

Static syntax, signal wiring, resource-path, duplicate-class and archive checks pass. Godot 4.7.1 runtime verification remains required.

# 0.23.3 New-Attempt Inventory Initialization Hotfix

## Baseline

Apply this direct-overlay hotfix over 0.23.2.

## Changed files

- `autoload/global.gd`
- `scenes/game.gd`
- `DEVELOPMENT_LOG.md`
- `PATCH_MANIFEST.md`

## Added files

- `HOTFIX_MANIFEST_0.23.3.md`
- `INSTALL_PATCH_0.23.3.txt`
- `TESTING_CHECKLIST_0.23.3.md`

## Runtime behavior

- New attempts initialize `run_inventory` and `run_bag` through the established run-system reset.
- Existing active attempts with either missing container are repaired before game systems bind to them.
- Pickup logic otherwise remains unchanged.

## Verification boundary

All 247 GDScript files pass the independent syntax grammar. Godot 4.7.1 runtime pickup verification remains required.

# 0.24.2 Cethiel Ground Integration and Loader Repair

Cumulative full-build correction over the uploaded 0.24.1 ground rework. It replaces the failed gray material set, removes direct global `WorldArt.GROUND_TEX` access, removes generated `.godot` cache content, preserves both earlier texture generations, and records the selected Cethiel CC0 source files. See `GROUND_TEXTURE_PATCH.md`, `INSTALL_PATCH_0.24.2.txt`, `TESTING_CHECKLIST_0.24.2.md` and the 0.24.2 development-log entry.


# 0.25.0 Open District Web Procedural Foundation

## Baseline

Cumulative full-build and direct-overlay patch over `syntethic-ascension-0.0.0.24.2-cethiel-ground-full`.

## Changed code

- `core/systems/world/proc/SegmentThemeData.gd`
- `core/systems/world/proc/SegmentThemePicker.gd`
- `core/systems/world/proc/DistrictPlan.gd`
- `core/systems/world/ChunkManager.gd`
- `core/systems/world/WorldArt.gd`
- `core/systems/world/SegmentProcBuilder.gd`
- `core/systems/world/proc/ChunkGenImpl.gd`
- `core/systems/world/proc/chunkgen/ChunkGenDistrict.gd`
- `core/systems/world/proc/chunkgen/ChunkGenStamp.gd`
- `core/systems/world/proc/SiteOverlayImpl.gd`
- `core/systems/world/proc/SiteParcelsImpl.gd`
- `scenes/world/pickups/ExplorationLootSpawner.gd`

## Changed assets

- `assets/world/ground/ground_grass_01.png`
- `assets/world/ground/_legacy_dense_foliage_0242/ground_grass_01.png`
- `assets/world/ground/_source_cethiel_cc0_selected/ground_grass_patchy_025_source.png`
- `assets/world/ground/_source_cethiel_cc0_selected/ground_grass_patchy_025_source_nrm.png`

## Documentation

- `DEVELOPMENT_LOG.md`
- `PATCH_MANIFEST.md`
- `PROCEDURAL_GENERATION_0.25.0.md`
- `INSTALL_PATCH_0.25.0.txt`
- `TESTING_CHECKLIST_0.25.0.md`
- `STATIC_VALIDATION_0.25.0.json`

## Runtime behavior

- Main and secondary routes remain readable, but neither acts as a hard boundary.
- Planned service lanes and exploration branches extend beyond the route spine, reconnect where possible and reward true endpoints.
- Leaving the authored web continues into ordinary streamed procedural chunks.
- Natural outdoor chunks render grass/dirt/mud instead of the former giant stone block.
- Segment progression uses named district identities instead of a single generic city blend.
- Segment 5's mandatory miniboss occupies a pre-gate arena rather than sharing the Exit Rite chunk.
- Procedural loot spawners are fully configured before entering the scene tree, preventing `_ready()` from seeing a zero loot ID.
- Exploration-loot placement markers are disabled by default.

## Verification boundary

Static validation is included with the package. Godot 4.7.1 runtime verification remains required.
