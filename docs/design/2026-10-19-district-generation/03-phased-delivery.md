# Phased delivery and first playable district

2026-10-19. This is a sequencing proposal and reviewable first-slice definition. It is not an executable implementation plan and grants no production lane to this chat.

## Delivery sequence

| Phase | Deliverable and likely integration surface | Dependency / exit evidence |
| --- | --- | --- |
| **0 — Finish the shared base** | Base owner extends common walls/roofs/frontages, quiet surfaces, shadow/cutaway quality and all-direction support through ordinary S2+ paths. Keep each theme's ground and layout. | Sole base-owner lane. Receive final API changes, source revision and verification packet. This phase supplies shared quality, not bespoke district infrastructure. |
| **1 — S3 family pilot** | Family-context forwarding and a visual profile for existing S3 duty-office/ordinary frontage, plus two restrained mounted assemblies. Optional existing-barricade reskin only if its support is exposed safely. | Concrete S3 concept handoff; explicit production/engine/Git lane handoff; physical/interaction equality and natural native captures. The detailed scope below is the recommendation. |
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

An S3 street should read as the same city under institutional control: deeper official stone entries, a restrained slate/iron treatment, mounted licence/records equipment and quieter domestic neighbours. Cooler dirt/grass ground remains visible. The existing checkpoint roadside positions can acquire deliberate inspection-equipment appearance if their geometry supports it; the road core stays open.

### Exact bounded content

- One **duty-office facade/material set**, selected only for existing civic buildings in `checkpoint_lanes`. Preserve the current civic selection rule and the physical workshop/shop/passage/house template.
- One restrained **staff/resident variant** for the remaining existing S3 buildings, built from the common base rather than a new physical template.
- Two mounted assemblies: **registry/order board** and **shielded entry-lamp/equipment housing**. Art derives from the incoming S3 concept. Both need real support spans, all-direction fit rules and roof-linked fading. Where an outline has no safe support, omit the assembly. Select/replace the existing kit's corresponding decorative detail where appropriate; do not double its lantern or interior records board, and preserve live search/security status labels.
- Optional **visual treatment of existing checkpoint half-cover/barricade units** as a separate small follow-on if the shared renderer exposes a safe per-instance material/visual selector. Preserve their blocker kind, mask, position, count and collision. If it requires global cover changes, defer it from the first slice.
- Forward the selected family and resolve a visual profile for ordinary street and fill paths. Keep every other family on the handed-off common base. Do not replace generic landmarks during this slice, avoiding their separate placement/RNG concerns.

There is no new booth footprint, road barrier, detector interaction, patrol rule, reward, enemy population, lore text, gate state, ground shader or lamp-light system in this pilot. Distinction comes from building identity and mounted assemblies; it must be apparent before adding more objects.

The coordinating [S3 written image job](../../art/concepts/2026-10-19-segment-directions/image-jobs.json) also proposes a guard loggia, compact guardhouse, iron gate piers, a dogleg inspection route and an overhead service gantry. Those establish the fuller destination. They require later fitted structures/visibility checks and are deliberately not smuggled into this visual-only first slice. Inspect `03-s3-checkpoint-lanes.png` when delivered before locking the pilot assets; its written overcast-daylight palette is already compatible with this proposal.

### Expected files after lane handoff

Reconcile these candidates with the base owner's final result before writing a task-level implementation plan:

| Candidate path | Intended change |
| --- | --- |
| `core/systems/world/proc/SegmentThemeData.gd` | Copy the already selected `district_family` into manager context. No theme pool/value changes. |
| `core/systems/world/ChunkManager.gd` and `proc/ChunkGenImpl.gd` | Store/mirror family instance context before generation. No scheduler or physical activation changes. |
| `core/systems/world/proc/chunkgen/ChunkGenDistrict.gd` | Forward family into both street/fill parcel configurations. Keep road/clear/plaza/reward logic identical. |
| `core/systems/world/proc/SiteParcelsImpl.gd` | Attach resolved visual profile after each real rect/irregular building is configured. No RNG calls or replacement door calculation. |
| Proposed `scenes/world/buildings/DistrictVisualProfiles.gd` | Pure small catalogue: S3 profile plus explicit common-base fallbacks. |
| `scenes/world/buildings/CityBlockKit.gd`, frontage helper, and/or proposed `DistrictFamilyDressing.gd` | Minimal extension seam for materials/attachments, using existing roof ownership. Avoid unrelated renderer refactoring. |
| Proposed `assets/world/districts/checkpoint_lanes/` | Reviewed originals/derivatives, provenance and anchors; create only after concept handoff. |
| Proposed `tools/tests/DistrictFamilyVisualTest.gd` / `.tscn` | Cross-family routing, S3 on/off invariants, repeated generation, all-direction fit and inherited corrected-door cases. Existing suites remain the regression baseline. |

### Evidence and completion conditions

1. Record the base handoff revision/hash set, final changed-file lane and the selected S3 concept/provenance. Establish the handed-off build as the comparison baseline.
2. Use natural S3 plans to select examples for an ordinary main/secondary street, actual courtyard fill, searchable reward building, any available checkpoint and a plan with no final checkpoint role. Record seed, plan seed, coordinate, connector mask and role. Do not invent coordinates or silently substitute a hand-built showcase for production proof.
3. Compare family enabled/disabled for each selected example. Physical blockers/masks, floor stamps/alpha, entrances, volumes/IDs, clear/access maps, security and rewards must be identical; subsequent seeded outcomes remain stable. Verify all four entrances, passage rear exit and L/recessed support in focused fixtures.
4. Run the changed-path automated suites in the contracts document only after the engine lane is released. Run script parse audit last. Record real output and limits; no passing claim derives from this plan.
5. Capture native exterior/entered/exit/restored-roof stills at 1280×720 and 960×540, then moving combat with ordinary collision/security active. Include actor occlusion near new mounted/tall forms, unload/reload and reduced-effects settings. Keep fixtures/god mode labelled and save-write checks explicit.
6. Compare chunk-build/streaming costs with the baseline and obtain coordinating-design review of distinct S3 identity and combat readability. If distinction is weak, revise mass/material/entry treatment before increasing clutter. Human continuous-play assessment remains distinct from scripted acceptance.

## Current handoff status

Only the four files in this dedicated design folder were created for this task. Production tracing and the accepted image were inspected read-only. Godot was not launched, no tests were run, no Git operation was performed, and no message was sent to another chat. Next dependent action is to reconcile the incoming concepts and final common-base interface, then prepare the bounded S3 implementation plan under the explicitly transferred lane.

Documentation validation checked all four authored files: 27 local Markdown links resolved, all 14 source theme IDs matched 14 matrix rows, all 18 concept-manifest outputs had explicit translation entries, and no unfinished-marker tokens were found. This validates the packet's coverage and references; it is not gameplay or visual acceptance evidence.
