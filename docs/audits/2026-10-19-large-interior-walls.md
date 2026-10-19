# Large facility and Donjon wall audit — 19 October 2026

The human reported holes in outer walls, disconnected/doubled courses inside
houses, and asked for the huge dungeon/Donjon buildings to be included. The house
worker owns parcel geometry, its carver and common rendering. This chat's focused
production repair owns only `core/systems/world/proc/SiteOverlayImpl.gd`.

## Separate production families

These are physical footprints in the streamed city, not separate indoor scenes.

| Family | Production path and extent | Current presentation/topology |
| --- | --- | --- |
| Multi-chunk room-first facility | SiteOverlayImpl on eligible default, connector-free chunks. Default 20% anchor chance; 1×1, 2×1, 1×2 or 2×2 chunks. With 32 cells/chunk and padding 2: 28×28, 60×28, 28×60 or 60×60 cells (up to 3840×3840 world pixels). | RectFacilityCarver perimeter, rooms and corridors; floor/solid wall geometry sliced per chunk. One indoor volume per slice shares a site reward ID. No RoofOverlay/CityBlockKit in this path. |
| District CA Donjon side region | ChunkGenDistrict when parcels did not place, a single road axis exists and the theme's Donjon roll passes. Side regions below 10×10 are skipped. At normal 32-cell chunks, straight-road regions commonly reach 28×10–19 cells, or the transpose. | Cave/CA + rectangular rooms and corridors; only internal wall/floor boundaries extracted. No outermost region ring, roof or city family. Street/access erasure and subsequent component/spur cleanup can further open the shape. This must be judged as its own family before imposing an intact enclosure. |
| Generic isolated structure | ChunkGenStructures._spawn_building, weighted default content, 10–16×8–14 base cells with optional notches and inner Donjon. | Outer footprint ring is spawned separately from optional interior carving. Two IndoorVolume instances over the same interior are a separately identified reward-ownership issue; untouched in this wall repair. |

The supplied symptom crop was personally inspected. Its seed/family was not
provided; it cannot by itself establish that a pictured house is a CA Donjon or
multi-chunk facility.

## Confirmed multi-chunk wall root cause and repair

The facility code clipped the authoritative site's wall dictionary to each chunk,
then trimmed wall endpoints twice. A continuous wall crossing a chunk boundary
therefore became two artificial endpoints and lost cells on both sides. The same
cleanup eroded real doorway jambs. Next, `_spawn_wall_cells` calculated connection
masks only from those clipped cells, losing cross-boundary half-arms. This affected
both rendered wall pieces and actual player/world collision geometry.

The fix keeps the complete site plan authoritative: no per-slice topology prune;
N/E/S/W connections are resolved against the complete plan before recording each
chunk-local blocker. Windows and original doorway holes remain unchanged. Existing
rooms, corridors, random draws, floor stamps, building IDs and reward logic remain.

Intact facility wall cells also receive the shared
`VARIANT_BUILDING_ENVELOPE` marker introduced by the house repair. It prevents
random ruin holes/raised pier art from reintroducing visual gaps on intact walls.
The CA Donjon/ruin path does not receive that marker globally.

## Reproduction and checks

`tools/tests/SiteWallContinuityTest.gd` runs production overlay decoration on
cached authoritative 2×1, 1×2 and 2×2 site plans, with real ChunkBuildData and
ChunkBlockPhysics rectangle generation. It checks exact cells/connections,
windows, intended door holes, seam-reaching colliders, intact-wall flags, shared
site reward ID and normal/reverse slice regeneration.

- Original topology: 19,225 passed / 588 failed.
- Topology repair: 19,861 passed / 0 failed.
- Added intact-art requirement before marker: 1,686 failures.
- Final focused test: 21,547 passed / 0 failed; clean exit and no diagnostics.

These cached plans isolate slicing defects; they do not replace actual carver,
shared-manager streaming or native rendered evidence. A read-only reviewer found
no concrete regression in the scoped code, with those same verification limits.

## Genuine large-site candidates

The unchanged production plan/anchor rules found the following outside planned
city roles, S2 attempt 16102026, mixed world seed 436524753:

| Root chunk | Size | Site/building ID | Region | Original wall cells |
| --- | --- | --- | --- | --- |
| (-16,-22) | 2×2 | 756382052 | 60×60 cells | 684 |
| (-14,-22) | 2×1 | 158799869 | 60×28 cells | 368 |
| (-24,-16) | 1×2 | 1135889672 | 28×60 cells | 421 |

Exact 64-bit site seed, doorway, dimensions and window counts are retained in
[candidate metadata](../art/reference/2026-10-19-large-site-walls/actual-site-candidates.json).
No forced anchor probability or authored building geometry was used to select
these examples.

## Actual Game verification and remaining art gap

[Corrected native facility evidence](../art/reference/2026-10-19-large-site-walls/native-v2/manifest.json)
contains 26 images at 1280×720 and 960×540. The production shared manager streamed
all three actual sites. Every original wall cell, full-plan connection mask and
intact-art flag matched (684 / 368 / 421 cells); all four live seam collision rays
hit. Physical player entry and exit through each generated doorway passed, with
the matching indoor volume verified. The run exited 0 with zero failures,
diagnostics or save writes. All nine recorded source hashes matched immediately
after capture. These are scripted, isolated runs with god mode, disabled enemy
spawning and overview zooms, not human continuous-play approval.

Native-v1 is retained as diagnostic evidence: its first site was correctly
framed, but relative camera placement became stale after walking. Native-v2 uses
explicit global camera placement. Its 1×2 overview at zoom 0.43 is a centered
crop, not a complete-building view; its native doorway evidence and complete
plan-data checks remain valid. The 2×2 and 2×1 overviews show their entire sites.

The personally inspected facility images show a separate architectural problem:
huge uncovered stone mazes still use legacy wall art. They have no city-family
frontage or roof, and should not be counted as visually matching the two
prototype buildings simply because their seam repair passes.

[Actual Donjon evidence](../art/reference/2026-10-19-large-site-walls/donjon-native-v1/manifest.json)
reproduces S3 attempt 2026, mixed world seed 2057449438, chunk (-3,-3). Two real
regions (15×28 and 10×28 cells) reproduce in Game. After access clearing and
cleanup, the probe records only five occupied blocker cells, including props;
the native view reads as scattered paving islands in grass rather than a
recognizable enclosed dungeon. Four normal/small images, clean exit 0, no
failures, diagnostics or save writes. This capture uses static controlled poses;
it does not establish physical interior traversal. Donjon geometry remains
unchanged pending an explicit ruin/open-yard versus intact-building decision.

Both corrected packets were sent to the art designer for architectural review.
The final gameplay parse audit passed all 543 scripts with a clean exit and no
diagnostics. Only the preexisting editor remained when the engine slot was
returned to the house worker. Its upcoming shared-carver repair may supersede
these source hashes; the native packets describe their recorded snapshot.
The ordinary-house near-perimeter double-wall issue remains with its separate
coding owner. Git publication is on hold pending the combined review.

## Art review verdict

The coordinating art chat and its independent designer inspected six selected
final scenes: 2×2 and 2×1 facility overviews, the 2×1 seam, the 1×2 actual entrance,
and the Donjon overview/detail. They accepted the bounded SiteOverlay continuity
and intact-art repair: the shown boundaries are complete, the sampled wall course
is seamless, and the actual entrance reads clearly.

Large-facility concept fidelity remains a separate rework. The next recommended
design prototype is the actual 2×1 site as a civic/workshop compound: a substantial
entrance, two or three roofed wings, an intentional courtyard and one service bay,
retaining route/room clearances and stable identities. Wall tint changes alone
will not establish that hierarchy. No new large-building art implementation is
requested in this repair review round.

The actual CA Donjon sample is not accepted as a finished enclosed dungeon. Its
enclosed-dungeon versus outdoor-ruin contract remains unresolved; do not silently
enclose it, change its identity or delete its reward volumes as part of this fix.

The house worker's shared RectFacilityCarver repair must compare all three actual
facility plans against the prior exact wall/window sets and connection masks.
Refresh relevant native proof only if those plans change. This chat remains
read-only on production sources while that owner completes the small-room repair.
