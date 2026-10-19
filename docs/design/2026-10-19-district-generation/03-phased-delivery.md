# Phased delivery and first playable district

2026-10-19. This is a sequencing proposal and reviewable first-slice definition. It is not an executable implementation plan and grants no production lane to this chat.

## Delivery sequence

| Phase | Deliverable and likely integration surface | Dependency / exit evidence |
| --- | --- | --- |
| **0 — Finish the shared base** | Base owner extends common walls/roofs/frontages, quiet surfaces, shadow/cutaway quality and all-direction support through ordinary S2+ paths. Keep each theme's ground and layout. | Sole base-owner lane. Receive final API changes, source revision and verification packet. This phase supplies shared quality, not bespoke district infrastructure. |
| **1 — S3 family pilot** | Family-context forwarding and one distinct guard-office/guard-loggia architectural family: deep stone arches/returns and a compact supported watch-bay roof composition on existing civic parcels. Small mounted equipment supports the family. | S3 plate 03 has been inspected as target direction; explicit production/engine/Git lane handoff remains required. Prove physical/interaction equality, new silhouette and native combat readability. |
| **2 — Domestic, ruin and work families** | S2 completion, S4 civilian/collapsed treatments and S6 working/ruined-service pairs. Start with actual existing templates, then introduce one fitted ruin or workshop-hall footprint per separately reviewed scope. | Prove silhouette differences at the camera before broad prop expansion. Preserve intact-building/ruin distinction and required searchable-building placement. |
| **3 — Bounded connected infrastructure** | Separate small plans for S7 canal, S7 underpass and S8 rail strips, using explicit feature records and crossings. Implement one feature kind at a time. | Physical/visual boundary agreement, neighbour-independent slices, stream-order tests, route/loot/door reachability, overhead actor visibility. Each must produce a usable district without requiring the other two. |
| **4 — Garrison and wall logistics** | S8 military store/tent family, S9 wall approach and siege-service compounds. Add tent physical/indoor semantics separately from military facade dressing. | Tent entry/roof proof; finite wall frontage preserving the open map; safe logistics courts. Do not use tents as skins on opaque house geometry. |
| **5 — Inner and final gate assemblies** | S5 and S10 receive related but distinctly scaled gatehouse families and machinery around the real gate/court axes. | Keep 20/28-cell courts, retreat connectors, live boss tells, gate state and departure behaviour. Native moving combat is mandatory. |
| **6 — Authored reconciliation and city journey review** | Separate S1 and hub visual passes; complete native contact sheet of fourteen procedural identities and authored spaces. Check transitions and remaining fallback paths. | Coordinating-design review, human continuous play, full-city pacing/readability and measured streaming costs. S11+ remains a named separate coverage gap. |

Concept development can cover all fourteen immediately. Product sequence is based on risk and shared dependencies; S5/S10 facade-only work could move earlier if the designer prioritises it, while their large gate assemblies keep their own spatial checks. Nothing in this order assigns new anomaly mechanics to particular segments.

## First playable recommendation: S3 Checkpoint Lanes

### Why S3

It follows the explicitly recorded open S2 / tense S3 contrast, has one deterministic theme and already has checkpoint/security language. Existing narrative supports licence checking; it does not require invented factions or a new mechanic. S3 also exercises the base beyond its original S2 coverage without first introducing water, trains, ceiling occlusion or a new macro-layout generator.

The actual generator skips street parcels in checkpoint plazas. Therefore the pilot makes **street/fill office buildings and checkpoint dressing** coherent, rather than putting an unreserved guardhouse in the centre of the checkpoint.

### Player-visible result

An S3 street should read as the same city under institutional control through a **new guard-loggia architectural type**: substantial deep stone arch bays and returns, a compact official roof/watch mass and a disciplined closed inspection frontage around the real entrance. Ordinary neighbours preserve the common city language. Cooler dirt/grass ground remains visible. This family must be recognisable at the game camera even with signs, lamps, cloth and small equipment hidden; a recoloured S2 arcade is insufficient.

### Exact bounded content

- One **guard-office/guard-loggia architectural family**, selected only for existing civic buildings in `checkpoint_lanes`. Preserve the current civic selection rule and physical workshop/shop/passage/house template. Replace the selected base facade/roof composition with the family forms; this is architectural geometry, not a texture swap or another overlaid house.
- Three required form components: **deep stone arch-bay frontage with substantial returns**, **compact slate official roof with a supported watch-bay mass**, and **purposeful closed inspection bays around the actual passable entry**. Choose bay count and support from the real span; non-entry arches use visibly closed/grilled surfaces rather than false open doors. The watch mass adds no playable upper storey or destination.
- All four entrance directions retain their exact real openings and receive fitted entry treatment; the visible south wall remains substantial when the door is on another side. Passage buildings keep both real exits. Irregular/narrow parcels get a recognisable reduced family of exposed-edge arch segments and a coherent low roof; omit only unsupported watch modules, never bridge a notch with a bounding-box facade.
- The remaining S3 ordinary houses use the handed-off base, with an optional restrained staff/resident material variant. Do not turn every house into a checkpoint or create a second bespoke residential family in this pilot.
- Two mounted assemblies: **registry/order board** and **shielded entry-lamp/equipment housing**. Art derives from the incoming S3 concept. Both need real support spans, all-direction fit rules and roof-linked fading. Where an outline has no safe support, omit the assembly. Select/replace the existing kit's corresponding decorative detail where appropriate; do not double its lantern or interior records board, and preserve live search/security status labels.
- Optional **visual treatment of existing checkpoint half-cover/barricade units** as a separate small follow-on if the shared renderer exposes a safe per-instance material/visual selector. Preserve their blocker kind, mask, position, count and collision. If it requires global cover changes, defer it from the first slice.
- Forward the selected family and resolve a visual profile for ordinary street and fill paths. Keep every other family on the handed-off common base. Do not replace generic landmarks during this slice, avoiding their separate placement/RNG concerns.

The scope reuses physical parcels but requires a new rendered building type. Gate piers, an overhead service gantry, a dogleg inspection route and a new booth footprint belong to the next separately fitted checkpoint phase. Existing interactions, enemy populations, rewards and gate state remain the comparison baseline.

The coordinating [S3 plate 03](../../art/concepts/2026-10-19-segment-directions/03-s3-checkpoint-lanes.png) has been visually inspected. Its loggia and watch/official building mass support this strengthened pilot; its larger gate/road composition establishes a later destination. This is concrete visual reference, not in-engine proof or approval of every tiny decoration. Retain its broad stone/roof hierarchy while reducing repeated tile outlines and keeping real doors/actors readable.

### Expected files after lane handoff

Reconcile these candidates with the base owner's final result before writing a task-level implementation plan:

| Candidate path | Intended change |
| --- | --- |
| `core/systems/world/proc/SegmentThemeData.gd` | Copy the already selected `district_family` into manager context. No theme pool/value changes. |
| `core/systems/world/ChunkManager.gd` and `proc/ChunkGenImpl.gd` | Store/mirror family instance context before generation. No scheduler or physical activation changes. |
| `core/systems/world/proc/chunkgen/ChunkGenDistrict.gd` | Forward family into both street/fill parcel configurations. Keep road/clear/plaza/reward logic identical. |
| `core/systems/world/proc/SiteParcelsImpl.gd` | Attach resolved visual profile after each real rect/irregular building is configured. No RNG calls or replacement door calculation. |
| Proposed `scenes/world/buildings/DistrictVisualProfiles.gd` | Pure small catalogue: S3 profile plus explicit common-base fallbacks. |
| `scenes/world/buildings/CityBlockKit.gd`, `CityBlockFrontages.gd`, `RoofOverlay.gd` / roof forms, and proposed `CheckpointOfficeForms.gd` | Focused family-form seam for deep arch bays and supported roof/watch mass, using existing roof/frontage ownership and complete actor occlusion. Replace selected base forms rather than duplicating them; avoid unrelated renderer refactoring. |
| Proposed `scenes/world/buildings/DistrictFamilyDressing.gd` if needed | Small mounted security assemblies only; architectural form selection belongs to the roof/frontage path. |
| Proposed `assets/world/districts/checkpoint_lanes/` | Reviewed originals/derivatives, provenance and anchors; create only after concept handoff. |
| Proposed `tools/tests/DistrictFamilyVisualTest.gd` / `.tscn` | Cross-family routing, S3 on/off invariants, repeated generation, all-direction fit and inherited corrected-door cases. Existing suites remain the regression baseline. |

### Evidence and completion conditions

1. Record the base handoff revision/hash set, final changed-file lane and the selected S3 concept/provenance. Establish the handed-off build as the comparison baseline.
2. Use natural S3 plans to select examples for an ordinary main/secondary street, actual courtyard fill, searchable reward building, any available checkpoint and a plan with no final checkpoint role. Record seed, plan seed, coordinate, connector mask and role. Do not invent coordinates or silently substitute a hand-built showcase for production proof.
3. Compare family enabled/disabled for each selected example. Physical blockers/masks, floor stamps/alpha, entrances, volumes/IDs, clear/access maps, security and rewards must be identical; subsequent seeded outcomes remain stable. Verify all four entrances, passage rear exit and L/recessed support in focused fixtures. Verify arch supports and roof/watch footprint against real geometry; an unsupported optional module is omitted deterministically.
4. Run the changed-path automated suites in the contracts document only after the engine lane is released. Run script parse audit last. Record real output and limits; no passing claim derives from this plan.
5. Capture native exterior/entered/exit/restored-roof stills at 1280×720 and 960×540, then moving combat with ordinary collision/security active. Include actor occlusion behind the **full new roof/watch/facade mass**, unload/reload and reduced-effects settings. The tall form must fit the actor shader's real coverage capacity. Keep fixtures/god mode labelled and save-write checks explicit.
6. Compare chunk-build/streaming costs with the baseline and obtain coordinating-design review of distinct S3 identity and combat readability. Include matching-camera base/pilot images with decorative boards, lamps, cloth and equipment hidden: deep bay depth and roof/watch hierarchy must still distinguish the family at 960×540. If not, revise massing before adding clutter. Human continuous-play assessment remains distinct from scripted acceptance.

## Current implementation status

The common-base handoff is `a798043d529acda31994a1b3bdbb526ba7fde41b`. The coordinating designer released the sole production/engine/Git lane to this chat and selected the S3 guard-loggia/watch-bay prototype. Tasks 1–3 implement selected-family routing, pure supported geometry and original arch/watch rendering; Task 4 supplies natural parcel comparisons and native evidence. No new push is authorised or performed.

The final 22 Godot scene/script suites, including the 548-script parse audit, and isolated strict reported-warning check pass. Nine current native captures have 459 matching runtime source/asset hashes and zero failures, diagnostics or save writes. See the [bounded implementation audit](../../audits/2026-10-19-s3-guard-loggia.md). Final coordinating-designer/human aesthetic acceptance is not asserted. Other bespoke families, connected infrastructure, S1/Hub, legacy roofless structures and the separately owned DonJon companion remain outside this completed prototype.
