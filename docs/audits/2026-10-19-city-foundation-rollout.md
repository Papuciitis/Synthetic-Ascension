# Common procedural building foundation

2026-10-19. Bounded ordinary-urban-parcel foundation verified across the current theme catalogue. Work in progress through the completed S3/S7 captures was backed up in checkpoint `d0f99e0614959bceb86514b0347f3e96f496fbea` on `origin/enemy-world-work`; the completed S11 capture and final verification below are subsequent evidence.

## Authorized design

The human requested base-building implementation across all other segments while district concepts and dedicated generation designs proceed separately. This supersedes the inventory hold. S8 was an example, not an upper bound. Apply the accepted civic/domestic architecture to ordinary urban parcels from S2 onward, including the current S11+ theme fallback. Keep the original-material preview switch.

The building policy and ground-composition policy remain separate. Only the accepted S2 secondary reward block receives composed paving. Other parcels retain shared terrain and semantic route materials. The pass changes no theme definitions, district plans, density, vegetation, checkpoint eligibility, geometry, doors, collision, rewards, security, deterministic IDs or RNG operations. Dedicated rail, canal, military and industrial generation belongs to the subsequent district work.

## Implementation and coverage

`CityBlockKit.enabled_for` now accepts procedural segments >=2. Both courtyard fill and streetfront parcels consume it. Later secondary reward parcels use shared ground, retaining their district's original surface ownership. The playable native preview accepts an explicit segment and records the selected theme, so captures need not silently run S2.

The production-parcel regression first failed 39 checks, then passed 150. It generates both district-fill and required-reward chunks for all 14 actual theme IDs and the S11 fallback: 121 styled buildings in 30 chunks in 15 natural plans. The paired original/styled snapshots compare blocker kinds, connection masks, every non-material variant, floor stamps/alpha, clear cells, roof outlines/door records, indoor bounds, building/reward IDs and security/reward configuration. Later samples contain no composed paving. Source/seed/coordinate details are retained in the [evidence packet](../art/reference/2026-10-19-city-foundation/production-parcel-samples.json).

These are focused parcel fixtures. They disable ground rendering, decoration and sites and set placement chance/sidewalk width explicitly; they do not prove exhaustive terrain, vegetation or checkpoint rendering. Native actual-Game samples supplement them. Shared policy predicates do not imply that every chunk contains a house.

## Native actual-Game review

| Segment/theme | Attempt seed | Window | Recorded frames | Local security |
| --- | --- | --- | --- | --- |
| S3 Checkpoint Lanes | 1 | 1280×720 | 142 | 6 |
| S7 Canal Service Routes | 4 | 960×540, Reduced Motion, Combat Flashes Off | 151 | 7 |
| S11 Service Courtyards fallback | 3 | 1280×720 | 144 | 8 |

All three completed runs pass physical perimeter/door travel, real entry-triggered security clearance, cutaway alpha 0 on entry and 1 on exit, full streamed unload/reload with identical data and restored building identities, and populated exterior combat. Total: 437 recorded frames, 195 weapon fires, 195 hits, 90 deaths, zero failures, diagnostics or save writes. These are separate current-code samples, not S8-only or S2 relabels; each report records the actual selected theme and segment. Native inspection shows the common broad slate/clay roof and upright wall treatment alongside the existing dirt, blue-green moss/mud and grassy fallback terrain. Existing noisy ground art remains a future district refinement.

The first S11 attempt reached all four stills with no diagnostics but hit the old harness's 240-second process limit while serializing its PNG sequence. It has no final success report and is retained as incomplete. A fresh run with a 600-second output allowance completed normally; no product scheduling, gameplay timeout, capture source or performance threshold changed. Its 144 frames and source contract are independently reported. Representative frames are retained for S3/S11 with full sequences preserved locally; the checkpoint already includes the full S7 sequence. See [native summary](../art/reference/2026-10-19-city-foundation/native-summary.json).

## Final checks

All twelve behavior suites pass, followed by the final 546-script parse audit. Every completed run has zero diagnostics. The packet contains each [suite report](../art/reference/2026-10-19-city-foundation/tests/).

| Check | Result |
| --- | --- |
| All-theme parcel coverage | 150 passed; 30 chunks, 121 buildings, 14 themes plus S11 fallback |
| CityBlockKit | 1,298 passed |
| CityBlockProcedural | 5,430 passed; 20 layouts, 76 parcels |
| CityPlannedBuilding | 20 chunks, 60 buildings, both families and four door directions; zero failures |
| CityGenerationMaterial | Zero failures |
| PlayerRoofOcclusion | 11 passed |
| ProcChunkReachability | 3,840 chunks, 2,538 doors, 1,728 rewards; zero failures |
| WorldGroundSplat | 21 passed |
| HubWorld | 54 passed |
| Segment1TileIntegration / Segment1Progression | 8 / 42 passed |
| DungeonRoofContract | 99 passed |
| ScriptParseAudit, run last | 546 passed |

The [strict compiler audit](../art/reference/2026-10-19-city-foundation/warning-final/audit.json) reloads all 14 previously reported scripts with real autoloads and strict startup warning severities: zero diagnostics, zero failed scripts, engine exit 0. Working `project.godot` remains unchanged. All 1,536 runtime source/resource files match the isolated snapshot and the tested candidate; all 11 key source/test/tool/settings hashes still match after captures and checks. Generated `.uid`/`.import` sidecars are excluded. This verifies the reported categories, not the complete human editor warning panel.

Independent read-only code and evidence reviews found no actionable issue. The coordinating designer inspected S3/S7 exteriors and confirmed bounded common-foundation coverage with district ground retained; this is not acceptance of whole-concept fidelity. The busy S7 ground and dedicated per-district architecture remain subsequent work. No additional product code changed after the checkpoint, and no new push was performed for this verification packet.

## Authored Institution and Hub

S1's `Level1Builder` builds explicit admissions/lab/archive/containment/service architecture. Its `_rebuild_wall_visuals` uses shared `ChunkBlockRenderer` batches with authored wall/half-cover data; the warehouse/kiosk service-footprint helper `_footprint_perimeter` already derives walls from real footprint cells and declared door cells. Common masonry shading, broad material planes and coherent wall depth can safely be evaluated through those batches, with explicit laboratory/service distinctions. Ordinary civic-house roofs, plants and entrances cannot simply be attached to these connected authored spaces. This pass retains their geometry, material selection and progression. S1 integration/progression checks are part of verification.

`HubWorld` uses authored `BUILDING_ART` sprites and roof-back strips when the complete asset set is available, with a separate `HubDecor` fallback. Invisible feet-space blockers follow the courtyard/station plan. Its existing warm stone/plaster, slate/clay roofs and lights already belong to the common material language. Future improvements should refine that authored art's roof planes/contact shadows and its fallback's matching depth, preserving station sightlines, arrival/departure and the Quiet Alcove. A generic `CityBlockKit` overlay would duplicate facades and cannot improve baked roof lighting coherently. Hub progression/feet-space checks are verified separately; no ordinary-house replacement is made here.

The default exploration generator also contains older roofless room/ruin structures, separate from both urban parcel entry points. This pass does not describe those as newly roofed civic/domestic houses. Their existing floor/volume/door contract needs a separate explicit architectural decision before adding opaque roofs; the generic duplicate IndoorVolume issue remains deferred.

## Limits

Native fixtures use scripted input and god mode, isolated profiles, real production collisions/entry/security, and controlled outside crowds. They are sampled visual/traversal evidence, not human continuous-play or performance acceptance. The previously unresolved resource-warmup guard remains unresolved (465 ms and 279.9 ms against 250 ms, with a 212.775 ms control); no threshold or scheduling change is included.
