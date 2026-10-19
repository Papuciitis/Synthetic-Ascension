# District production handoff

19 October 2026. Coordination snapshot checked against production revision `6d1a0cd7`, the live family selector, and completed base/S3 records. This document updates ownership and delivery expectations; it does not implement another family or approve every detail in a concept.

## Actual coverage

- Fourteen procedural theme definitions across S2–S10 are implemented. They vary terrain/tint, density, lane/court sizes, decoration budgets, ruin/DonJon tendencies and selected checkpoint eligibility. Paired themes are seeded alternatives, not additional sequential segments.
- The shared civic/domestic urban-parcel kit is enabled in S2+, including the S11+ fallback. This is common architectural quality, not fourteen distinct building families. S2's composed prototype paving remains separately bounded.
- **S3 civic parcels alone have a bespoke guard-loggia profile and original open/closed arch assets.** Noncivic S3 houses and every other procedural family retain the common profile. Gate piers, gantries and new checkpoint topology are not part of that prototype.
- Authored S1 and Hub have their own existing architecture. DonJon compounds/halls have a separate implemented enclosure/roof/court family and modular assets; they are cross-cutting buildings, not an extra district.
- Legacy roofless default exploration rooms remain outside the ordinary-parcel upgrade. A blank enclosure in a screenshot must be identified by its actual role/indoor/reward data before deciding it is a ruin, a house or an unfinished service hall.
- All 18 concept PNGs exist: 15 segment plates plus Hub, DonJon and exploratory Beyond the Wall. They are visual targets, not eighteen implemented environments.

Current code: [theme selection](../../core/systems/world/proc/SegmentThemePicker.gd:10), [S2+ common-kit policy and noncivic fallback](../../scenes/world/buildings/CityBlockKit.gd:33), [only bespoke profile](../../scenes/world/buildings/DistrictVisualProfiles.gd:5). Completed records: [base](../audits/2026-10-19-city-foundation-rollout.md), [S3](../audits/2026-10-19-s3-guard-loggia.md), [DonJon review](reviews/2026-10-19-donjon-architecture-designer-review.md).

## Complete district identity map

Ground pairs below are **current main/exploration terrain**. Architecture, utility groupings, planting treatment and material accents are **proposed production directions**, except the common kit and bounded S3 family already described. They are not claims that rails, canals, foundries or wall assemblies exist.

| Segment / theme | Current bespoke coverage | Architecture and useful infrastructure target | Current ground; proposed planting and material treatment |
| --- | --- | --- | --- |
| **S2 Service Courtyards** | Original common civic/domestic base | Inhabited arcades, attached homes, workshops, service pump/awning and connected courts. | Grass / grass. Cultivated court trees, ivy and contained planting; cool limestone/plaster, sage shutters, slate/muted clay. |
| **S3 Checkpoint Lanes** | Guard-loggia prototype on civic parcels; other houses common | Deep official arches, closed inspection grilles, supported watch bay, mounted practical lamp/records equipment. Gate piers/gantry later. | Dirt / grass. Restrained maintained planting; cool stone, dark slate, aged iron, modest subdued cloth. |
| **S4A Collapsed Ward** | Common base; existing generic ruin generation | Coherent failed domestic/service hall bays, exposed wall ends, partial roof and clear passages. Inert drain/repair remnants establish former use. | Scrub / grass. Growth collects against abandoned masonry and rubble footprints; worn cool stone, faded clay, restrained old iron. |
| **S4B Civilian Cut-through** | Common base | Inhabited terraces, small shops, washhouse/fountain court, covered passage and domestic awnings. | Grass / meadow. Doorstep pots and cultivated pocket planting; pale plaster, muted shutters and clay/slate. |
| **S5 Inner District Gate** | Common base plus existing gate/miniboss placement | Compact heavy gatehouses, inspection offices, squared piers and practical winch service. Preserve the 20-cell clear court. | Dirt / grass. Sparse court-edge planting; cool masonry/slate, dull bronze/iron and restrained official cloth. |
| **S6A Industrial Cut-through** | Common base | Stone/brick workshops, loading shed, wider vented roofs, a few proper chimneys, supported hoist and organised pipe/boiler services. | Dirt / dirt. Sparse wall-edge growth; cool stone, subdued brick, soot slate, aged copper/iron. |
| **S6B Ruined Service District** | Common base; existing generic ruin generation | Abandoned depot/workshop sharing S6A construction, failed roof bays, dead pipe/tank base and damaged loading assembly. | Scrub / dirt. Stronger growth at disused edges; faded stone/brick, rusted iron and subdued moss. |
| **S7A Underpass Veins** | Common base | Retaining/service rooms, thick arch abutments and a bounded viaduct/underpass feature. Actual spanning sections require actor-aware overhead treatment. | Dirt / moss. Damp low bands and limited growth at supports; blue-gray stone/slate with small warm practical lamps. |
| **S7B Canal Service Routes** | Common base; no dedicated water-channel layout | Lockhouse, pump workshop and warehouse around one continuous channel, quays and explicit crossings. Water needs declared physical boundaries. | Moss / mud. Controlled bank/reed groups; cool water-stained stone, slate, green-gray water and restrained copper. |
| **S8A Rail Yard Expanse** | Common base; no dedicated rail/wagon layout | Freight depot, engine/service shed, bounded curved track strip, stationary wagon and clear loading/crossing ground. | Dirt / grass. Sparse scrub at yard edges; neutral stone, muted brick/clay, dark iron and subdued gravel. |
| **S8B Military Staging Ground** | Common base and existing checkpoint eligibility | Reused barracks/supply hall, quartermaster store, restrained service shelters and clear muster court. Tents need their own physical/roof adapter. | Dirt / grass. Very sparse maintained growth; cool stone/slate, gray-green canvas and aged iron. |
| **S9A Outer Wall Approaches** | Common base and existing checkpoint eligibility | Sparse watch/service lodges beside a finite thick wall frontage with real traversable breaks; not a new closed world boundary. | Grass / scrub. Sparse wall-foot growth; large cool stone courses, slate and dull iron. |
| **S9B Siege Service District** | Common base and existing checkpoint eligibility | Denser repair/store halls, timber lifting frame, supply cart and wall-side logistics court. | Dirt / grass. Growth confined to neglected edges; stone/faded plaster, muted clay, old iron/timber. |
| **S10 Gate District** | Common base plus existing boss/departure placement | Largest gatehouse and service/record wings, deep departure arch and supported lifting machinery. Preserve the 28-cell boss court. | Dirt / grass. Sparse flanking planting; cool pale stone, charcoal slate, weathered copper/iron and minimal functional indicators. |

**Outside the fourteen:** S1 is The Institution, an authored admissions/lab/archive/containment/service progression. The between-segment Hub is a sheltered market court with its own station art and dusk treatment. S11+ continues under the narrative label **Beyond the Wall**, while world generation falls back to **Service Courtyards**; the exploratory plate does not resolve that gap. The [full matrix](../design/2026-10-19-district-generation/01-district-matrix.md) contains the longer proposals and placement contracts.

## Authority: selected versus exploratory

The human selected the bright temperate Greek/Roman/Mediterranean + medieval European city language with restrained early industrial/cyberpunk/authoritarian science-fiction additions. They requested believable depth/shadows/practical lights, organic uneven streets and quieter surfaces; they rejected excessive darkness, desert drift and over-lined imagery. They requested the full concept set, broader base coverage and new district types/generation. The recovered direct pacing decision is open/explorable S2 followed by tense S3; exact theme names come from current code, not a reconstructed complete human art specification.

The coordinating designer selected S3 guard-loggia/watch-bay vocabulary for the first implemented prototype. That is not final human aesthetic approval. Individual per-theme palettes, pumps, sheds, aqueducts, track alignments, towers and prop arrangements in the 18 plates remain design proposals until translated and reviewed at the actual game camera. Existing narrative may support some useful objects, but does not establish their final geometry, mechanics or visual treatment.

The human's latest correction, relayed by **Refine game vibe concept**, rejects its four objective-derived magic-heavy environment studies. Brass calibration circles, ritual courts, glowing cracks and machinery hidden in statues from those studies remain exploratory/unapproved. Preserve grounded frontage, purposeful edge dressing, material joins, readable floors and differentiated silhouettes without importing those motifs as district canon. Gameplay spells/objectives do not determine the whole district's architecture.

## One production owner

**Production district generation, modular assets and integration:** existing chat **“District generation and distinctive…”**, `01a153ea-44b7-7570-9fe3-e67a5c73ce71`. It owns the next bounded implementation packet, including asset briefs/generation/provenance, fitting, integration, tests, native evidence and its scoped Git work. Its original S3 packet is finished; it is currently coordinating the next packet rather than running an all-district rollout.

**Art direction and actual-game visual review:** this designer chat, `01a14f56-352f-79b2-b401-d8c10d6ba199`. Select architectural targets, review native pixels, resolve visual findings and give explicit prototype/final acceptance status. No competing product implementation.

**Completed common-base owner:** **“Generate the prototype building families…”**, `01a15298-1259-7381-89bb-bce38d810d95`. That bounded work is complete and its lane was released. Keep it available as a read-only specialist unless a distinct non-overlapping task is assigned.

**DonJon specialist:** `01a14fff-3528-77c1-867f-59c8167188eb`, for read-only enclosure/roof/streaming review unless separately assigned implementation. **Refine game vibe concept**, `01a154dc-2a54-70c3-81ca-1b43d3e32a4f`, supplies actual-game observations and grounded brief corrections; it should not start a parallel district generator or independent modular asset pack.

Keep one shared-checkout production/engine/Git lane. Helpers may audit a named concern read-only. A new owner or helper must have a concrete file/scope boundary and completion handoff; creating another chat or concept set does not advance the production queue by itself.

## Evidence-backed coordination gaps

1. **Coverage expectation outran delivery.** The 18 images and fourteen-theme matrix were completed, but only the shared base and one S3 bespoke prototype were implemented. Canals, rails, underpasses, military camps and wall/gate assemblies are not secretly present elsewhere.
2. **The review loop remained open.** S3 was kept as a first prototype with three specific visual revisions deferred. No subsequent implementation packet was activated after that bounded task finished. A design sequence is not an automatically executing backlog.
3. **Stale summaries contradict current work.** The old inventory's “district_family is unconsumed” paragraph is superseded by live S3 routing. Its S2-only diagnosis is explicitly historical, not a current product bug. The concept README still describes the base chat holding the lane and S3 as a future first target. Some matrix/proposed-interface wording also predates the completed pilot. The district README/audit already record S3 implementation; the entire packet must not be rerun as though nothing exists.
4. **New environment studies drifted from the brief.** The relayed human correction establishes this for the four magic-heavy studies. It does not prove a renderer/tool failure.
5. **Acceptance boundaries matter.** Existing final records label concept art, controlled paired captures, native gameplay samples, tests and aesthetic review separately. No evidence was found that the 18 paintings were knowingly labelled native production screenshots. Tests do not resolve S3's flat panels, watch silhouette, side-entry readability or the inherited dark/noisy environment. The weak neighbour-roof test was caught and strengthened before final handoff; the cost probe's asymmetry and alternate-scale limits remain disclosed.

## Next bounded production packet: S3 visual refinement

Close the existing review before opening another whole family. Reuse the implemented footprint fitting, original arches and existing 64 px presentation contract.

- Finish plain end/infill and watch-front surfaces with restrained material variation, a coherent plinth/base and corner/side depth. Do not force an extra arch into a span that cannot fit safely.
- Make the watch body, side plane and eave shadow distinguishable from the main roof within the supported envelope. It should read as architecture rather than a capped vent; more tiny ornament or a hue change alone is insufficient.
- Give the real north/east/west thresholds a clear surround or grounded approach cue. Keep openings, passability and the closed inspection grilles unchanged; do not paint a false entrance elsewhere.

Asset packet: reuse current open/closed arch masters; add or derive only the missing quiet wall-return/plinth treatment, watch front/side/window recess treatment and directional threshold modules. Record support/extent/shadow/cutaway anchors and exact provenance. A wholly new illustration is unnecessary. Foliage masking active floor/distinctive bays and overall world lighting/ground readability remain separate issues; retain them in natural review frames rather than hiding them in all proof.

Completion evidence: same-building common/guard comparisons at normal and small sizes; an unobstructed whole-building view after temporary HUD text clears; actual side-entry/irregular exterior and entered cutaway; restored roof and an occupied readability sample. Compare physical/door/reward/RNG data and run affected-path/roof/parse/strict checks as appropriate. Record current source hashes and state exactly what was visually inspected. Return this packet to the designer and explicitly close or continue each of the three review actions.

## Following packet: one S4A collapsed service-hall family

After the S3 refinement review closes, implement one coherent ruined municipal/service-hall family on **actual eligible Collapsed Ward ruin sites**, with one bounded plan and a safe no-fit fallback. This follows the blank-enclosure/isolated-ruin concern without spreading new magic motifs or rewriting every legacy room.

Useful former purpose should be readable from a loading/entry opening, structural bay rhythm, surviving wall/roof fragment and connected foundation approach. Asset packet: masonry ends/piers, one broken arch/header, exposed rafters with a partial roof, and a quiet foundation/plinth-to-ground transition; reuse existing grouped rubble and temperate vegetation at edges. Keep the traversable centre and existing route/loot approaches clear. New indoor tags or roof coverage must follow real enclosed/covered geometry. Do not silently classify every old roofless exploration box as this ruin family.

Capture the actual segment/theme, seed, chunk, building/site ID and role before designing around a screenshot. Demonstrate two fitted site sizes/orientations, one no-fit case, natural street/foundation joins and native traversal/cutaway/streaming as applicable. S4B inhabited domestic grouping follows separately, then S6 working/abandoned service families. Rail, canal and underpass topology keep their own connected-feature plans and crossing/occlusion tests.

## Current accepted and deferred state

Accepted as bounded implemented foundations: common urban-parcel coverage and the first DonJon enclosure family. S3 is retained as a first architectural prototype, with final visual acceptance pending the three revisions above. The remaining district-specific architectures and connected infrastructure are proposed. S1/Hub visual upgrades, legacy roofless structures, foliage/readability improvements, the wider daylight/ground mismatch, the existing warmup timing concern and other disclosed S3 limits remain separate work.

This handoff is documentation only. It creates no new product branch, assets, engine run or competing implementation lane. The production owner should integrate its current status into the earlier summary documents while beginning the selected bounded packet.
