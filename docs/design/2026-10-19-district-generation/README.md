# Distinct district generation — design handoff

2026-10-19. **Proposed architecture and production sequence; no product implementation in this packet.**

The goal is a recognisable journey through all fourteen procedural Area 1 themes, supported by different architectural silhouettes, purposeful prop groups and the infrastructure their identities require. Keep the current north-up top-down game, natural uneven streets, temperate daylight, quiet combat ground and convincing attached shadows. The common language is Greek/Roman/Mediterranean masonry, medieval European forms and restrained early industrial and authoritarian science-fiction additions.

Read in order:

1. [Complete district matrix](01-district-matrix.md): fourteen procedural themes, authored S1/hub, and what each needs beyond the common base.
2. [Generation contracts and extension seams](02-generation-contracts.md): traced current APIs, proposed data flow, determinism, placement and streaming requirements.
3. [Phased delivery and first playable extension](03-phased-delivery.md): staged deliverables and a bounded S3 recommendation.

## Authority and ownership

- Current user brief, [vision](../../SYNTHETIC_ASCENSION_VISION.md), [roadmap](../../SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md) and [theme inventory](../2026-10-19-segment-visual-style-inventory.md) govern this proposal. Existing narrative corroboration comes from [StoryLines.DISTRICTS](../../../data/narrative/StoryLines.gd:32); it is current authored content, not a recovered direct-user art brief.
- The inspected visual anchor is [accepted city concept 08](../../art/concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png). It supports the material/depth language; its painted image is not a replacement camera specification or a ready-made collision layout.
- New building names, material choices, prop groups, interfaces and delivery order here are **design recommendations**, unless explicitly identified as existing. No new lore, rewards, enemy rules or interaction mechanics are authorised by these recommendations.
- The coordinating designer owns the incoming full segment concept set. Its [common brief](../../art/concepts/2026-10-19-segment-directions/COMMON_BRIEF.md) and [18-job manifest](../../art/concepts/2026-10-19-segment-directions/image-jobs.json) have now been read and reconciled below. Individual new plates have not been inspected by this chat; their availability and visual acceptance are separate. Reconcile each matrix row with its delivered image before producing final assets.
- The existing chat **“Generate the prototype building families…”** (`01a15298-1259-7381-89bb-bce38d810d95`) holds the sole production/engine/Git lane for the common S2+ base pass. This chat writes only this dedicated documentation folder until an explicit lane handoff. No Godot launch, Git mutation, production edit, warning cleanup or concept-folder edit was performed for this packet.
- Source observations are a dated snapshot of an actively shared checkout. In particular, the inspected `CityBlockKit.enabled_for()` still selected S2 only. A provisional coverage test already describes broader expectations; its presence is not proof that the rollout has shipped or passed.
- The DonJon chat owns a separate `donjon-theme-integration-notes.md` companion in this folder. Do not overwrite it or infer that ordinary-family profiles already apply to DonJon compounds.

## Recommended approach

Use **family data over the shared building renderer**, plus separately planned infrastructure where required. This keeps doors, parcel generation, security, rewards and roof ownership in their current systems while allowing distinct facades, roofs, landmarks and dressing.

Two alternatives were considered. Copying a generator/kit per district would make early art iteration direct but duplicate the most fragile door, roof and physics contracts. Rebuilding the entire city topology before adding identity would support ambitious canals and rail, but delay useful playable results and expose every segment to a large change. The proposed sequence delivers S3 identity first, then tackles connected infrastructure in separate bounded stages.

## Review boundary

This packet is ready for coordinating-design review. It reserves S3 as the recommended first implementation scope; it does not start that scope. Product implementation requires the base-owner handoff and the concrete concept/art brief. No commit or push has been made by this chat.
