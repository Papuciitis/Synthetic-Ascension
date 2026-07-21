# Synthetic Ascension — Project Structure (0.21 recovery patch)

This is the ownership map for the recovered Godot 4.6 project. The main rule is that gameplay authority, presentation and authored data should have one clear owner each.

## Top-level ownership

| Path | Responsibility |
|---|---|
| `autoload/` | Persistent profile/attempt state, save orchestration and cross-system event buses |
| `core/actors/` | Player and enemy state/behaviour; actors consume combat results but do not own bullet simulation |
| `core/combat/` | Hit contracts, simple projectile simulation and compatibility projectile scenes |
| `core/systems/` | Spawning, inventory routing, items, world generation and authored Segment 1 progression |
| `data/` | Authored resources and small data catalogs; no live scene state |
| `effects/` | Item/augment gameplay effects and their presentation hooks |
| `scenes/` | Game/world composition, encounters and environment scenes |
| `ui/` | Screens, reusable controls, modal controllers and feedback presentation |
| `assets/` | Raw media and visual-only VFX |
| `spells/` | Spell data, logic and scenes |

## Segment 1

`core/systems/world/Level1Builder.gd` owns the deterministic five-stage route, barriers, milestones, cell-to-world placement, objective state and Resonance awards. Map-cell markers, milestone Areas, Wardstones, barriers and the Exit Rite all derive positions through its shared `_cell_to_world()` conversion. `ChunkManager` owns walkability and registered manual blocker cells.

`core/systems/spawner/Segment1SpawnProfile.gd` is the single tuning point for tutorial pressure. It defines interval, alive cap, batch, roster, grace and Threat participation for before-synthesis, containment, archive, courtyard, service, outer-approach and Exit-Rite stages. `Level1Builder` advances the stage by milestones; elapsed scene time cannot unlock the normal roster during the tutorial.

`EnemySpawner` owns spawn placement/caps and resets its timer after blocking UI. `Level1Builder` owns when an authored wave is requested. `ExitRite` owns its final channel-pressure bursts.

## Tutorial and enemy dossiers

`data/enemies/EnemyDossierCatalog.gd` maps stable `EnemySpec.id` values to first-encounter prose. Enemy scenes do not contain tutorial copy.

`ui/controllers/TutorialModalController.gd` owns the single modal queue. It pauses gameplay, defers enemy cards during bosses/Rite channeling, persists discoveries through `Global`, and resets spawner clocks after dismissal. `ui/screens/TutorialCardOverlay.*` owns presentation only. `RunEvents` carries requests and encounter notifications.

`SaveData.meta_discovered_enemy_ids` is profile-scoped. Missing fields in old saves default to an empty list. Developer controls in Main Menu can force introductions for one test run or reset saved discoveries.

## Equipment and bag grids

`Inventory.SLOT_COUNT` and `Inventory.SLOT_DEFINITIONS` are authoritative for equipped slots. `InventoryBar` instantiates `InventorySlotView.tscn` at runtime using exported column policy; its `.tscn` contains no repeated slot branches. Generated controls retain click, hover, drag/drop payloads, tooltips, rarity styling and fly-in targets. Fly-in effects and overlays use the real Control `get_global_rect()`.

Bag, stash and Hub grids already instantiate reusable slot scenes from their backing inventory sizes. Expanded Satchel remains driven by `BagInventory.get_slot_count()`/`SLOT_COUNT`, not fixed coordinates.

## Projectile and hit architecture

`ProjectileSimulationManager` is an autoload and the authority for ordinary straight player `RangedBullet` shots and ordinary generic enemy `EnemyProjectile` shots emitted by `EnemyShooter`. It stores dense parallel packed arrays, performs swept target/world checks, queries `EnemyIndex`, and draws all simple bullets through one `MultiMeshInstance2D`.

`HitProfileAdapter` is one reusable player-owned compatibility object. Item effects modify it before the manager copies scalar values. Firestone has an explicit `apply_to_hit_profile()` path; melee and magic hooks are unchanged.

`HitLedger` represents compatible resolved hits to one target in one physics frame. `Enemy.apply_hit_ledger()` delegates to `EnemyLifecycle`; legacy `take_damage()` remains supported. See `PROJECTILE_HIT_ARCHITECTURE.md` for exact aggregation semantics and migration boundaries.

Gameplay collision remains CPU-authoritative. The MultiMesh is presentation only. Impact particles/VFX are presentation only and never determine hits.

## Followers

`Global.transaction_followers()` is the authority for follower changes. It clamps at zero, emits old/change/new/reason/context, autosaves, and suppresses pre-assistant combat rewards in Segment 1. Enemy rewards, drains, boss rewards, Hub trades, vendor refresh and reconstruction use reasoned transactions.

`FollowerFeedbackUI` explains gains/commitments across Game and Hub and aggregates small combat gains. The HUD tooltip shows the next reconstruction cost. `TutorialModalController` presents the first-Follower and death/reconstruction explanations.

## Developer verification

Main Menu developer mode exposes enemy-introduction force/reset and projectile stress-test controls. The stress test requests a 100-shot burst, sustained fire toward several hundred active logical projectiles, several colors, and an on-screen counter block. It is instrumentation, not evidence of performance until run in Godot 4.6.

## Reference and recovery rules

- Move/rename imported resources in Godot's FileSystem dock when possible so `.godot_uid` mappings are maintained.
- Use stable IDs for saved knowledge and authored catalogs.
- Prefer exported `PackedScene` dependencies for scene composition. Central systems may preload their deliberately owned compatibility assets.
- Keep unique homing, reflected, mine, beam and boss attacks as nodes until their semantics are intentionally migrated.
- Put pure visual effects in `assets/vfx`; gameplay-bearing effects remain in `effects` or `core`.
- Recovery/editor debris belongs in the quarantine archive, not as loose `.tmp` files in the project tree.

