# Common procedural building foundation

2026-10-19. Verification in progress; native review and final test results follow.

## Authorized design

The human requested base-building implementation across all other segments while district concepts and dedicated generation designs proceed separately. This supersedes the inventory hold. S8 was an example, not an upper bound. Apply the accepted civic/domestic architecture to ordinary urban parcels from S2 onward, including the current S11+ theme fallback. Keep the original-material preview switch.

The building policy and ground-composition policy remain separate. Only the accepted S2 secondary reward block receives composed paving. Other parcels retain shared terrain and semantic route materials. The pass changes no theme definitions, district plans, density, vegetation, checkpoint eligibility, geometry, doors, collision, rewards, security, deterministic IDs or RNG operations. Dedicated rail, canal, military and industrial generation belongs to the subsequent district work.

## Implementation and coverage

`CityBlockKit.enabled_for` now accepts procedural segments >=2. Both courtyard fill and streetfront parcels consume it. Later secondary reward parcels use shared ground, retaining their district's original surface ownership. The playable native preview accepts an explicit segment and records the selected theme, so captures need not silently run S2.

The production-parcel regression first failed 39 checks, then passed 150. It generates both district-fill and required-reward chunks for all 14 actual theme IDs and the S11 fallback: 30 chunks in 15 natural plans. The paired original/styled snapshots compare blocker kinds, connection masks, every non-material variant, floor stamps/alpha, clear cells, roof outlines/door records, indoor bounds, building/reward IDs and security/reward configuration. Later samples contain no composed paving. Source/seed/coordinate details are retained in the evidence packet.

These are focused parcel fixtures. They disable ground rendering, decoration and sites and set placement chance/sidewalk width explicitly; they do not prove exhaustive terrain, vegetation or checkpoint rendering. Native actual-Game samples supplement them. Shared policy predicates do not imply that every chunk contains a house.

## Authored Institution and Hub

S1's `Level1Builder` builds explicit admissions/lab/archive/containment/service architecture. Its `_rebuild_wall_visuals` uses shared `ChunkBlockRenderer` batches with authored wall/half-cover data; `_footprint_perimeter` already derives walls from real footprint cells and declared door cells. Common masonry shading, broad material planes and coherent wall depth can safely be evaluated through those batches, with explicit laboratory/service distinctions. Ordinary civic-house roofs, plants and entrances cannot simply be attached to these connected authored spaces. This pass retains their geometry, material selection and progression. S1 integration/progression checks are part of verification.

`HubWorld` uses authored `BUILDING_ART` sprites and roof-back strips when the complete asset set is available, with a separate `HubDecor` fallback. Invisible feet-space blockers follow the courtyard/station plan. Its existing warm stone/plaster, slate/clay roofs and lights already belong to the common material language. Future improvements should refine that authored art's roof planes/contact shadows and its fallback's matching depth, preserving station sightlines, arrival/departure and the Quiet Alcove. A generic `CityBlockKit` overlay would duplicate facades and cannot improve baked roof lighting coherently. Hub progression/feet-space checks are verified separately; no ordinary-house replacement is made here.

The default exploration generator also contains older roofless room/ruin structures, separate from both urban parcel entry points. This pass does not describe those as newly roofed civic/domestic houses. Their existing floor/volume/door contract needs a separate explicit architectural decision before adding opaque roofs; the generic duplicate IndoorVolume issue remains deferred.

## Limits

Native fixtures use scripted input and god mode, isolated profiles, real production collisions/entry/security, and controlled outside crowds. They are sampled visual/traversal evidence, not human continuous-play or performance acceptance. The previously unresolved resource-warmup guard remains unresolved (465 ms and 279.9 ms against 250 ms, with a 212.775 ms control); no threshold or scheduling change is included.
