# Change Manifest — 0.25.3 Urban Blocks

## Secondary objective lifecycle

- Added stable deterministic IDs to generated secondary objectives.
- Added `RunEvents.secondary_objective_completed(objective_id)`.
- Secondary HUD now appears only while the player is near an unfinished opportunity.
- Leaving the objective pocket clears the secondary HUD.
- Returning to an unfinished pocket restores it.
- Completed opportunities remain hidden for the rest of the segment.
- Searchable-building objectives complete when their activated interior encounter is cleared.
- Dangerous-alley objectives complete when the objective cache pickup is successfully collected.

## Service Courtyards district pass

- Added a one-chunk procedural urban envelope around the generated street graph.
- Kept pedestrian/courtyard access separate from road connectors, preventing fake road branches.
- Added reciprocal cross-chunk courtyard passages and validation for sealed blocks.
- Replaced sparse independent parcel rolls with frontage-density filling.
- Added row-house, shop, workshop and passage-building templates.
- Added enterable courtyard blocks in non-road district chunks.
- Added courtyard combat sockets and light prop dressing.
- Added deterministic roof variation by building type.
- Preserved exact L-turn, T-junction and dead-end street rendering from 0.25.2.

## Main modified files

- `autoload/RunEvents.gd`
- `core/systems/world/ChunkManager.gd`
- `core/systems/world/SegmentProcBuilder.gd`
- `core/systems/world/proc/ChunkGenImpl.gd`
- `core/systems/world/proc/DistrictPlan.gd`
- `core/systems/world/proc/SiteManager.gd`
- `core/systems/world/proc/SiteParcelsImpl.gd`
- `core/systems/world/proc/chunkgen/ChunkGenDistrict.gd`
- `scenes/world/buildings/RoofOverlay.gd`
- `scenes/world/pickups/ExplorationLootSpawner.gd`
- `scenes/world/pickups/ItemPickup.gd`
- `scenes/world/volumes/IndoorVolume.gd`

## Scope and known limitations

- The new block grammar is applied to the **Service Courtyards** theme first. Other district families continue to use their existing generation until they receive their own architecture grammar.
- Buildings remain grid-aligned and mostly rectangular. The patch improves density, frontage, courtyards and traversal; it does not yet add a full exterior façade sprite set.
- Courtyard blocks are generated independently from deterministic shared access masks rather than as one monolithic multi-chunk scene.
- Static project, duplicate-class, delimiter and resource-path checks passed. A Godot runtime executable was not available in the patching environment, so in-engine smoke testing is still required.
