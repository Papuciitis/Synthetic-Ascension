# 0.21 Tutorial Pacing + Combat Architecture Patch Manifest

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
