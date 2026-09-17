# Change Manifest — 0.25.1

Baseline: `0.25.0-procedural-foundation`

## Import and procedural generation

- `core/systems/world/WorldArt.gd` — lazy ground-texture loader.
- `core/systems/world/proc/chunkgen/ChunkGenDistrict.gd` — guaranteed optional-interior parcel request and active loot configuration.
- `core/systems/world/proc/SiteParcelsImpl.gd` — forced valid parcel fallback and configured active indoor loot.
- `core/systems/world/proc/SiteOverlayImpl.gd` — full-site classification and one deterministic active reward.
- `scenes/world/volumes/IndoorVolume.gd` — item-database wait, retry, valid placement and claim-after-success behavior.
- `scenes/world/pickups/ExplorationLootSpawner.gd` — walkable fallback without blocked-source placement.

## Combat, caps and cleanup

- `autoload/EnemyIndex.gd` — bounded summon/split/boss-add budgets and ambient-only counts.
- `core/systems/spawner/spawner.gd`, `core/systems/spawner/spawner.tscn` — pending reservations, exact capacity accounting and quiet defaults.
- `core/actors/enemy/modules/EnemyBomber.gd`, `EnemyLifecycle.gd` — ordinary death bookkeeping before detonation.
- `core/actors/enemy/modules/EnemyDrops.gd` — independently rolled multi-instance drops.
- `core/actors/enemy/modules/EnemySummoner.gd` — valid-position and special-budget enforcement.
- `scenes/world/bosses/BossBulldozerBrain.gd` — boss-add budget enforcement.
- `scenes/world/events/BossArena.gd`, `MiniBossArena.gd` — validate-before-commit retry behavior.
- `scenes/world/pickups/ItemPickup.gd`, `core/systems/inventory/WorldDropSpawner.gd` — ordinary-drop lifetime with persistent exploration/player drops.
- Six existing enemy scene overrides — drop diagnostics disabled.

## Splitter

- `assets/textures/Enemy_SplitterSlime.png` — supplied visual.
- `core/actors/enemy/EnemySpec_SplitterSlime.tres` — stats and stage tuning.
- `scenes/world/enemies/EnemySplitter.tscn` — ambient enemy scene.
- `core/actors/enemy/EnemySpec.gd`, `enemy.gd`, `modules/EnemyInit.gd`, `modules/EnemySplitter.gd` — generation and elite scaling.
- `data/enemies/spawn/SpawnTable_Default.tres` — rare late-roster entry.
- `data/enemies/EnemyDossierCatalog.gd` — first-encounter teaching entry.

## Documentation

- `DEVELOPMENT_LOG.md` — append-only 0.25.1 record.
- `INSTALL_PATCH_0.25.1.txt` — direct-overlay instructions.
- `TESTING_CHECKLIST_0.25.1.md` — Godot 4.7.1 runtime verification.
- `CHANGE_MANIFEST_0.25.1.md` — this file.
