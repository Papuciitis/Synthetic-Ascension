# Trailer ground attribution — 4 November 2026

Baseline inspected: `d7cfb52f` (`codex/linux-world-production`). This is a
read-only source investigation supporting the user's priority of a first
trailer. It records a bounded next trial, not a product fix or visual acceptance.
No new Godot run or game capture was made for this audit.

## Separate shape owners

| Visible support | Source at baseline | Meaning |
| --- | --- | --- |
| Residual urban yard field | [ChunkManager.gd](../../core/systems/world/ChunkManager.gd), lines 762–780 and 900–909 | The entire chunk receives its terrain base; `urban` becomes semantic index `6`. |
| District edge | Same file, lines 828–867 | Hashed ragged margins replace base cells beside different terrain before stamps. They do not reshape an interior yard. |
| Central residential courtyard | [SiteParcelsImpl.gd](../../core/systems/world/proc/SiteParcelsImpl.gd), lines 1055–1064 | A randomized 9–13-cell axis-aligned rectangle is stamped with index `8` at alpha `0.88`. |
| Courtyard access | Same file, lines 1066–1092 | Reciprocal three-cell passages receive index `4`; keepouts and clear-cell metadata protect actual access. |
| Doorway approach | Same file, lines 1844–1869 | City kits already stamp the actual doorway core rather than the former five-cell-wide rectangular surround. |
| Formal plaza/objective/arena court | [ChunkGenDistrict.gd](../../core/systems/world/proc/chunkgen/ChunkGenDistrict.gd), lines 244–305 | Separate role/archetype selection uses polygon or rectangular support, indices `7`/`9`, and explicit clearance. |

`district_fill` selects the courtyard branch in `ChunkGenDistrict.gd`, lines
37–71. Its building bands, prop exclusions and spawn sockets use the same
courtyard geometry in `SiteParcelsImpl.gd`, lines 1089–1144. Changing that
rectangle is therefore not merely a material adjustment.

The name `_stamp_floor_rect_cells_patchy` does not mean irregular support:
[ChunkGenStamp.gd](../../core/systems/world/proc/chunkgen/ChunkGenStamp.gd),
lines 54–57, forwards the complete rectangle. Through
[GroundSplatRenderer.gd](../../core/systems/world/ground/GroundSplatRenderer.gd),
lines 203–244, stamps are applied in z order and alpha at least `0.5` replaces
cell ownership. Reducing alpha below that threshold switches to a stain.

## Road/yard role trap

[DistrictGroundPolicy.gd](../../core/systems/world/ground/DistrictGroundPolicy.gd),
lines 37–74, maps index `6` to `ROLE_YARD`, index `4` to `ROLE_LANE`, and
indices `7`, `8`, `9` to `ROLE_ROAD`. A yard-only change cannot reshape the
explicit index-8 courtyard. A global road-role change also affects routes,
plazas and objective/arena courts; index `8` is not exclusively residential.

Existing yard patches in
[ground_splat.gdshader](../../core/systems/world/ground/ground_splat.gdshader),
lines 288–307, use noise plus occlusion. More grading or noise cannot supply
an outline derived from actual household use.

## Safest first trailer trial

Select one ordinary index-6 household yard with a clearly exposed unused
corner. Trial a separate deterministic presentation mask that lets an existing
district-appropriate soil/growth source break up that corner while retaining
the actual footprint, doorway, footway and useful walking support. Gate its
rendering to `ROLE_YARD`; keep the index-8 courtyard and formal courts as
unchanged controls. This is a proposed first trial, not an implemented design.

Do not repurpose the existing light-map channels: red owns brightness, green
stains, blue household care and alpha occlusion. Do not change floor stamps,
terrain IDs or coverage slots to disguise the rectangle.

Care already follows real footprint, garden contact and door records:
[CityGroundCare.gd](../../core/systems/world/ground/CityGroundCare.gd), lines
12–52 and 171–182. `GroundSplatRenderer.gd`, lines 364–388, writes its weights
only to blue. The trial must retain those exact care bytes.

## Regression and native acceptance

The focused regression must require a changed support silhouette at the
selected unused corner and continuous real door/walking support. Require exact
equality of coverage maps, slots, existing light/care bytes, recorded floors,
blockers, building/door identities, terrain/navigation records and RNG state.
Check idempotent repaint, streamed rebuild, reset and wrapped-map reuse.

Existing anchors: `CityDoorApproachGroundTest.gd` lines 26–110 covers rectangular
and recessed homes in four directions; `CityFootwayGeometryTest.gd` lines 35–49
checks silhouette change and retained door width; `WorldGroundSplatTest.gd`
lines 132–199 checks semantic/care preservation and reset; and
`CityGroundCareNaturalTest.gd` lines 53–103 supplies physical snapshots and
independent RNG/rebuild checks. These are relevant tests to run, not new results.

Acceptance needs matched actual-Game before/after originals at 1280×720 and
960×540, with exact source/camera/settings receipts, normal output plus a mask
inspection view, unchanged care/material/door controls, streamed reload and
actual doorway/passage traversal. Retain an index-8 courtyard and formal court
as unchanged controls. Still images alone do not close motion readability,
combat quality, performance or whole-city/trailer readiness.
