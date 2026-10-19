# DonJon architecture — designer review

2026-10-19. Coordinating designer's actual-image review for the human-approved DonJon implementation. After checkpoint `3aa358c5`, the human explicitly authorized applicable commits across the chats, including the designer's own work. Commits are sequenced through the shared checkout. No new push request accompanies that authorization.

**Final art verdict: PASS as a bounded first implemented DonJon prototype.** The reviewed large compounds and compact halls now communicate enclosed dungeon architecture. This is a first usable architectural family, with further roof, courtyard and interior composition work still visible.

## Governing direction

The approved [exterior and interior concepts](../concepts/2026-10-19-donjon-directions/DESIGN_HANDOFF.md) establish a fortified institution with pale masonry, slate wings, a substantial entrance, purposeful open court and readable enclosed halls, cells/storage and a restrained mechanical service area. Temperate daylight, broad depth/shadows, quiet combat floors and calm material groups govern. Current site geometry, real entrances, protected access, identities and roof/indoor ownership remain authoritative.

The implementation may deliberately change dungeon architecture and room topology. Ordinary-house envelope and fallback repairs, intact-wall flags, authoritative multi-chunk masks and existing reward rules must remain sound.

## Early native pass — REWORK

Personally inspected actual Game images from [early 2x1 evidence](../reference/2026-10-19-dungeon-architecture-v1/early-2x1/manifest.json):

- [Small overview](../reference/2026-10-19-dungeon-architecture-v1/early-2x1/facility-2x1-overview-960x540.png).
- [Normal outside](../reference/2026-10-19-dungeon-architecture-v1/early-2x1/facility-2x1-outside-1280x720.png).
- [Small entered cutaway](../reference/2026-10-19-dungeon-architecture-v1/early-2x1/facility-2x1-inside-960x540.png).
- [Small seam view](../reference/2026-10-19-dungeon-architecture-v1/early-2x1/facility-2x1-x-seam-960x540.png).

The enclosing U-shaped compound, three roof zones and open court provide a useful structural foundation. The new gate arch has material character, and the low iron grille can identify fixed cell boundaries.

The shown presentation is not accepted as finished dungeon art. Long uninterrupted roof bands dominate the scene. Broad green-gray gradient wall panels obscure masonry and resemble smooth shelves. The isolated arch has insufficient surrounding gatehouse mass. The enormous paved court and sparse tiny props provide little functional hierarchy.

Required corrections communicated to the coding owner:

1. Break long wings into a few unequal architectural volumes or height changes, with real gatehouse returns and structural accents. Use a restrained clay service portion. Keep roofs tied to actual occupied geometry.
2. Make pale masonry the dominant wall material, with visible top thickness, selective piers and coherent eave/contact shadows. Limit gradients to shading.
3. Establish a hall, cell/storage group and service chamber with coherent wall-bound dressing. Give the court one substantial anchored planted group and clear circulation. Compact Donjons need an enclosed hall family, rather than a miniature open U-shaped court.

An independent art reviewer personally inspected the overview, normal outside and small inside images and reached the same REWORK verdict.

## Revised native v2 — REWORK

Personally inspected [small overview](../reference/2026-10-19-dungeon-architecture-v1/early-2x1-v2/facility-2x1-overview-960x540.png), [small inside](../reference/2026-10-19-dungeon-architecture-v1/early-2x1-v2/facility-2x1-inside-960x540.png) and [normal outside](../reference/2026-10-19-dungeon-architecture-v1/early-2x1-v2/facility-2x1-outside-1280x720.png).

Visible improvements include explicit piers, regular stone courses, clay service color and one anchored court tree. The wall face still reads too smooth and green; the new material/shader suppresses the expected limestone character. The two small roof accents do not yet establish a gatehouse. The gallery arch is partly concealed by the long roof in the normal outside view and insufficiently integrated with adjacent wall thickness in the cutaway.

The owner identified that the roof lift shortened the cap rather than visibly raising its projection. Required next correction: true raised roof/gatehouse depth, fascia and coherent returns, replace the flattened face with the dedicated limestone module, and inspect the west hall and compact Donjon views as well as the entrance sample. Full native verification remains on hold until the focused art pass is acceptable.

## Revised native v3 — north-entry art PASS, technical repairs pending

Root and the independent art reviewer personally inspected [small overview](../reference/2026-10-19-dungeon-architecture-v1/early-2x1-v3/facility-2x1-overview-960x540.png), [small entered cutaway](../reference/2026-10-19-dungeon-architecture-v1/early-2x1-v3/facility-2x1-inside-960x540.png), [small west hall](../reference/2026-10-19-dungeon-architecture-v1/early-2x1-v3/facility-2x1-west-hall-960x540.png) and [normal outside](../reference/2026-10-19-dungeon-architecture-v1/early-2x1-v3/facility-2x1-outside-1280x720.png).

The dedicated limestone source restores masonry character. The actually raised gatehouse, connected returns and roof notch establish a coherent entrance. The west hall now shows a sequence of spaces, warm lamps and service equipment. This north-entry sample passes as a bounded first implemented prototype. Long roof bands and sparse courtyard composition remain further visual refinement, rather than grounds to reject this first pass.

This art verdict does not clear all entrance orientations or the two Important raised-roof source regressions below. The west-hall staged pose is visual evidence, not a claim of physically traversing the complete sequence.

Root and the independent art reviewer also personally inspected the same-code compact S3 [overview](../reference/2026-10-19-dungeon-architecture-v1/district/donjon-overview-960x540.png) and [interior detail](../reference/2026-10-19-dungeon-architecture-v1/district/donjon-interior-detail-960x540.png). They show actual enclosed buildings and a central hall replacing the former open regions. The architecture passes as a first prototype. One focused correction is required: give the actual indoor footprint a continuous quiet floor instead of the outdoor-looking cobbles and mossy edge blending. Its revised native still is pending.

## Native-camera paintover and original modules

[Native-camera paintover 03](../concepts/2026-10-19-donjon-directions/03-native-view-dungeon-paintover.png) makes massing/material corrections concrete. It was generated from the actual overview and approved exterior, then personally inspected. It invents facade openings and proportions; it is design reference only, neither exact topology nor runtime evidence. Its [manifest](../concepts/2026-10-19-donjon-directions/03-native-view-paintover-manifest.json) retains the exact prompt, references, original path and SHA256.

Three original transparent PNG modules are saved under `assets/world/city_block/`: open gate arch, fixed iron grille and a limestone wall bay added after v2 showed a concrete material gap. Their [handoff](../../../assets/world/city_block/DONJON_ASSET_HANDOFF.md) records anchors, aperture, scale and camera limits; the [source manifest](../../../assets/world/city_block/donjon_assets_manifest.json) retains exact built-in generation prompts and source hashes. All three original copies and manifest hashes were independently verified. No raster postprocessing was used. Concepts, sources and handoffs are saved in commit `c396041d`.

Conditional module acceptance requires a matching camera-facing elevation, actual clear passage, correct blocked grille geometry and actor visibility. Do not rotate complete front art into other elevations or stretch it to arbitrary openings. Native composites, not transparent-source previews, decide whether the part is useful.

## Independent source review

A fresh focused reviewer inspected the current uncommitted dungeon production/test changes against checkpoint `3aa358c5`, including the new untracked files. No Critical or Important source defect was found in that snapshot. Both prior WIP issues—reward/RNG bookkeeping when no enclosure fits and 8/9-cell compact roof degeneration—were resolved by source inspection.

The reviewer ran no engine or tests while the coding chat held engine ownership. The source verdict does not independently confirm reported execution counts. In particular, asserting the existing 32-triangle cap does not prove complete silhouette coverage when saturated, and the first chance-selected reward audit exercised one actual selected location with two regions.

The subsequent focused V3 roof-delta review found two Important regressions: raised masonry rectangles/gable triangles did not subtract doorway holes, and the inherited roof projection omitted most lower return pixels from actor-silhouette coverage. A concrete east-entry fixture could cover 52 × 114 pixels of its real doorway. Both findings were sent for correction with doorway, lower-return and direction-specific regressions required.

The same independent reviewer then inspected the repair and issued bounded technical PASS: world-aligned holes apply to every retained face piece; explicit full-form occlusion uses actual clipped geometry after the real front-edge gate; chunk clipping, parent fading and initial occupancy remain coherent. The new contract test covers three sizes and four directions, isolates each roof and checks front/behind actor positions. The reviewer ran no engine. Neighbor unloading, negative coordinates and complete simultaneous cap/wing coverage at triangle-budget saturation remain limits of that focused test, rather than further defects found.

Root read back the expanded natural-selection audit: 156 eligible production chunks, six naturally selected chunks across five attempt seeds, seven original regions, seven fitted enclosures, zero outdoor fallbacks, zero reported failures, and identical original/current reward-ID arrays in all six records. The selected seed list is 2026, 29, 73, 4099 and 7919. This does not demonstrate an integrated no-fit occurrence; its fallback contract is supported by source inspection and fitting tests. Final native evidence remains pending.

## Final native acceptance

The production source remained unchanged through the final captures and the successful capture-only route correction.

| Evidence | Reviewed result |
| --- | --- |
| [Two-chunk runtime manifest](../reference/2026-10-19-dungeon-architecture-v1/final-runtime/manifest.json) | 18 normal/small stills and 32 controlled combat frames. Recorded physical traversal covers 79 cells through the three west rooms, then a true unload/rebuild while inside; geometry matches and nine roof pieces remain cut away. |
| [Compact S3 final manifest](../reference/2026-10-19-dungeon-architecture-v1/final-district/manifest.json) | 10 normal/small stills. The quiet floor resolves the outdoor cobble/moss appearance. Recorded physical entry/hall/exit covers 22 cells and includes an indoor rebuild with equal geometry. |
| [Three-size final v2 manifest](../reference/2026-10-19-dungeon-architecture-v1/final-facilities-v2/manifest.json) | 38 normal/small stills of actual 2×2 west-entry, 2×1 north-entry and 1×2 east-entry sites, including full portrait framing. Recorded complete wall/mask/intact-flag correspondence, four seam rays, physical entry/exit and restored roofs pass. |

Root freshly verified all 25 source/asset hashes in each of the three manifests: 75 matches, zero mismatches. All 66 declared still files exist, and all three manifests record zero failures and zero save writes. The compact and three-size wrapper reports record native exit0, no timeout, empty diagnostics and no before/after source drift.

Root also verified all 172 entries in the [complete image inventory](../reference/2026-10-19-dungeon-architecture-v1/image-sha256.json), including retained diagnostics and fight frames: zero missing files or hash mismatches. All 11 saved [execution records](../reference/2026-10-19-dungeon-architecture-v1/verification/tests/) were read and record exit0, no timeout and empty diagnostics. They include 33,001 layout checks, 96 raised-roof contract checks, 762 production checks, retained house/site/roof checks, 3,840 generated chunks with 2,538 doors and 1,728 rewards, and 546 script parses. These are inspected owner execution records; root did not run a second competing engine.

The expanded [natural-selection audit](../reference/2026-10-19-dungeon-architecture-v1/verification/selected-ca-audit-v2.json) now records its explicit 16-seed list and corrected methodology label.

Root personally inspected the final [physical west hall](../reference/2026-10-19-dungeon-architecture-v1/final-runtime/runtime-physical-west-hall-960x540.png), [reloaded hall](../reference/2026-10-19-dungeon-architecture-v1/final-runtime/runtime-reloaded-inside-960x540.png), [normal fight frame](../reference/2026-10-19-dungeon-architecture-v1/final-runtime/fight-frames/frame-0004.png), [small fight frame](../reference/2026-10-19-dungeon-architecture-v1/final-runtime/fight-frames/frame-0020.png), [quiet compact hall](../reference/2026-10-19-dungeon-architecture-v1/final-district/donjon-physical-hall-960x540.png), [compact overview](../reference/2026-10-19-dungeon-architecture-v1/final-district/donjon-overview-960x540.png), [square overview](../reference/2026-10-19-dungeon-architecture-v1/final-facilities-v2/facility-2x2-overview-960x540.png), [portrait overview](../reference/2026-10-19-dungeon-architecture-v1/final-facilities-v2/facility-1x2-overview-960x540.png), [normal west entrance](../reference/2026-10-19-dungeon-architecture-v1/final-facilities-v2/facility-2x2-outside-1280x720.png) and [small east-entry interior](../reference/2026-10-19-dungeon-architecture-v1/final-facilities-v2/facility-1x2-inside-960x540.png).

The independent art reviewer agreed that the shown compact floor and large-family geometry pass as first prototypes. Their final size sweep used the preceding same-production-source diagnostic stills for art only; root separately inspected the successful v2 views.

The earlier `final-facilities` run is retained as a failed diagnostic: a fixed 240-tick movement bound expired during the long portrait court walk and subsequent straight targets compounded the route failure. It is not accepted traversal proof. The v2 capture uses actual blocker-grid paths and per-cell physical input, completing without a product-code change.

The two populated fights use 20 controlled enemies each, scripted input, god mode, Reduced Motion and Combat Flashes Off. They record 39 fires, 37 hits and 17 deaths in total. Existing facilities have no local security encounter; this pass adds no guards or reward rebalance. The CA volumes retain disabled exploration loot and their separate original reward owner.

## Remaining limits and review status

The reviewed first architecture implementation, compact floor correction and final three-size samples pass. Raised-roof source repairs pass focused review. The implementation, tests, reproducible capture tools, audit and versioned evidence are saved in `df8ea5e353717594428f97e100ee4276dd1c46f6`; root independently verified its 228-file scope and empty staging index.

Applicable work across the chats is saved separately: house evidence `a551b60f`, original art/concepts `c396041d`, historical house/facility designer review `8733ebca`, and dungeon implementation `df8ea5e3`. This final review records the combined acceptance and evidence boundaries. No new push was requested.

Long roof bands, broad bare courts and sparse room dressing remain visible art refinement. The preexisting macro-planning boundary case—an anchor spanning both default and planned-role chunks—has separate incomplete-slice risk; the actual large-site samples here deliberately validate complete all-default footprints. This pass does not certify universal macro-edge site coverage or rewrite anchor/reward distribution. The [implementation audit](../../audits/2026-10-19-dungeon-architecture.md) records the current-chunk gate at `ChunkGenImpl.gd:266`, forwarding at `SiteManager.gd:19` and anchor scan at `SiteOverlayImpl.gd:62`. This is partial site omission risk, not permission for geometry to overdraw protected streets.

The generic duplicate IndoorVolume issue remains deferred. Safe no-fit CA regions retain an honest outdoor ruin/cache rather than false indoor tags. Complete triangle coverage at saturation, human continuous-play comfort, packed-export validation and performance certification are not established by this bounded review. PNG samples and recorded scripted checks do not imply exhaustive whole-city aesthetic approval.
