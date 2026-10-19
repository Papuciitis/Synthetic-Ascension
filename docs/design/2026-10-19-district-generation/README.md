# Distinct district generation — design handoff

2026-10-19. **All fourteen themes mapped; bounded S3 guard-loggia prototype implemented and verified.** Other bespoke district families and connected infrastructure remain proposed.

The goal is a recognisable journey through all fourteen procedural Area 1 themes, supported by different architectural silhouettes, purposeful prop groups and the infrastructure their identities require. Keep the current north-up top-down game, natural uneven streets, temperate daylight, quiet combat ground and convincing attached shadows. The common language is Greek/Roman/Mediterranean masonry, medieval European forms and restrained early industrial and authoritarian science-fiction additions.

Read in order:

1. [Complete district matrix](01-district-matrix.md): fourteen procedural themes, authored S1/hub, and what each needs beyond the common base.
2. [Generation contracts and extension seams](02-generation-contracts.md): traced current APIs, proposed data flow, determinism, placement and streaming requirements.
3. [Phased delivery and first playable extension](03-phased-delivery.md): staged deliverables and a bounded S3 recommendation.
4. [S3 implementation plan](04-s3-guard-loggia-implementation-plan.md) and [asset brief](05-s3-asset-brief.md): four concrete tasks, two original facade masters, exact source snapshot and required review evidence; executed after the explicit base-owner lane release; final evidence is linked below.

## Authority and ownership

- Current user brief, [vision](../../SYNTHETIC_ASCENSION_VISION.md), [roadmap](../../SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md) and [theme inventory](../2026-10-19-segment-visual-style-inventory.md) govern this proposal. Existing narrative corroboration comes from [StoryLines.DISTRICTS](../../../data/narrative/StoryLines.gd:32); it is current authored content, not a recovered direct-user art brief.
- The inspected visual anchor is [accepted city concept 08](../../art/concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png). It supports the material/depth language; its painted image is not a replacement camera specification or a ready-made collision layout.
- New building names, material choices, prop groups, interfaces and delivery order here are **design recommendations**, unless explicitly identified as existing. No new lore, rewards, enemy rules or interaction mechanics are authorised by these recommendations.
- The coordinating designer's [completed 18-plate handoff](../../art/concepts/2026-10-19-segment-directions/README.md), common brief and manifest have been read and reconciled below. This chat has visually inspected [S3 plate 03](../../art/concepts/2026-10-19-segment-directions/03-s3-checkpoint-lanes.png); other individual plates remain unreviewed here. Root reports personally reviewing all eighteen and selecting S3 guard-loggia/watch-bay direction for the already requested playable prototype. This selects the architectural direction, not every tiny decoration or new canon.
- The common-base owner released the sole production/engine/Git lane at `a798043d529acda31994a1b3bdbb526ba7fde41b`; the coordinating designer explicitly transferred it to this district chat. Scoped local commits are authorised, with no new push. The S3 implementation uses that handed-off base, preserving unrelated owners' files.
- Source observations are a dated snapshot of an actively shared checkout. At the initial trace `CityBlockKit.enabled_for()` selected S2 only; the post-checkpoint read now shows `segment >= 2`. This is base-owner WIP source coverage, not full native rollout or visual acceptance. Recheck the final handoff before choosing interfaces.
- The DonJon chat owns the separate [DonJon integration notes](donjon-theme-integration-notes.md) companion in this folder. Those notes have been read for shared identity/roof boundaries; they are not edited by this chat. Ordinary-family profiles do not automatically apply to DonJon compounds.

## Recommended approach

Use **family data over the shared building renderer**, plus separately planned infrastructure where required. This keeps doors, parcel generation, security, rewards and roof ownership in their current systems while allowing distinct facades, roofs, landmarks and dressing.

Following coordinating-design review, the S3 pilot now requires one **distinct guard-office/guard-loggia architectural family**: deep stone arch bays, a compact watch-bay roof silhouette and a purposeful security frontage fitted to existing parcels. Recolouring the base and adding signs/lamps is insufficient. Recognisable form must survive a review with those small props hidden.

Two alternatives were considered. Copying a generator/kit per district would make early art iteration direct but duplicate the most fragile door, roof and physics contracts. Rebuilding the entire city topology before adding identity would support ambitious canals and rail, but delay useful playable results and expose every segment to a large change. The proposed sequence delivers S3 identity first, then tackles connected infrastructure in separate bounded stages.

## Implemented S3 and review boundary

S3 civic parcels now resolve the selected `checkpoint_lanes` family into fitted guard-loggia arches and a compact supported watch roof. Family routing, physical/RNG equality, all-direction geometry, native entries/reload/security/combat and the final parse/strict-warning checks are recorded in the [implementation audit](../../audits/2026-10-19-s3-guard-loggia.md) and [evidence index](../../art/reference/2026-10-19-s3-guard-loggia-v1/README.md).

The prototype establishes one building family, not the complete concept scene. Connected checkpoint topology, other district families, S1/Hub and legacy roofless structures remain separate scopes. Sampled native inspection does not claim final coordinating-designer or human aesthetic acceptance. The DonJon companion retains its separate owner.

## Checkpoint provenance

The checkpoint coordinator reported verified push of `d0f99e0614959bceb86514b0347f3e96f496fbea` to `origin/enemy-world-work`, then released the brief workspace freeze. That WIP backup includes the initial four-file packet and the separate DonJon notes. The strengthened S3 scope, plate-03 inspection record and source-status corrections written after release are **later documentation changes**, not content claimed to be in that checkpoint. The later explicit handoff transferred the production/engine/Git lane to this district chat. This prototype has not been pushed.

Root subsequently reported the final concept completion README/manifests committed as `ef4f4376`. The new concrete implementation plan, asset brief and planning source snapshot are later work; they do not claim to be included in either recorded backup.
