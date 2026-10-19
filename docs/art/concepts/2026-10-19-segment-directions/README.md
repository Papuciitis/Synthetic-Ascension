# District concepts and implementation handoff

19 October 2026. **18 concept plates: S1, all 14 procedural themes, and three supporting explorations.** Created with the built-in image-generation tool from the accepted city reference. All original PNGs are preserved at their generated 1672×941 resolution. These paintings describe visual destinations; they are not in-engine screenshots or collision blueprints.

Open the [interactive gallery](index.html), or select an individual original below. The gallery has district filters, full-image viewing and previous/next navigation. Its source and JavaScript syntax were checked; browser rendering could not be verified because the desktop browser tool's kernel failed to start.

## Complete set

| Plate | District / space | Architectural direction |
| --- | --- | --- |
| [01](01-s1-the-institution.png) | S1 — The Institution | Admission loggia, research wings, secured service yard and institutional mass. |
| [02](02-s2-service-courtyards.png) | S2 — Service Courtyards | Open inhabited courts, civic arcade, attached homes and bent service passages. |
| [03](03-s3-checkpoint-lanes.png) | S3 — Checkpoint Lanes | Guard loggia, duty offices, gate piers and controlled inspection approaches. |
| [04](04-s4-collapsed-ward.png) | S4A — Collapsed Ward | Believable failed masonry bays and roofless halls beside surviving homes. |
| [05](05-s4-civilian-cut-through.png) | S4B — Civilian Cut-through | Washhouse/fountain court, shuttered homes, shops and small inhabited lanes. |
| [06](06-s5-inner-district-gate.png) | S5 — Inner District Gate | Heavy gatehouses and winch annex around a clear encounter court. |
| [07](07-s6-industrial-cut-through.png) | S6A — Industrial Cut-through | Vented workshop roofs, proper chimneys, loading bays and wall-bound services. |
| [08](08-s6-ruined-service-district.png) | S6B — Ruined Service District | Failed workshop roof, damaged hoist, abandoned plant and surviving service routes. |
| [09](09-s7-underpass-veins.png) | S7A — Underpass Veins | Monumental viaduct arches above connected human-scale service streets. |
| [10](10-s7-canal-service-routes.png) | S7B — Canal Service Routes | Continuous canal, broad crossing, lockhouse and pump workshops. |
| [11](11-s8-rail-yard-expanse.png) | S8A — Rail Yard Expanse | Curved rail strips, depot, engine shed, wagon and open loading ground. |
| [12](12-s8-military-staging-ground.png) | S8B — Military Staging Ground | Reused barracks/supply halls, canvas service shelters and a clear muster court. |
| [13](13-s9-outer-wall-approaches.png) | S9A — Outer Wall Approaches | Thick continuous perimeter wall, guard lodges and exposed approaches. |
| [14](14-s9-siege-service-district.png) | S9B — Siege Service District | Reinforced repair halls, stone logistics and wall-side lifting frames. |
| [15](15-s10-gate-district.png) | S10 — Gate District | Dominant departure gate, institutional machinery and a broad boss plaza. |
| [16](16-hub-market-courtyard.png) | Hub — Market courtyard | Sheltered market frontages, station identities, central dais and quiet planted alcove. |
| [17](17-donjon-enclosed-compound.png) | DonJon — Enclosed compound | Connected roofed wings and cells around an outdoor court with a deliberate gatehouse. |
| [18](18-beyond-the-wall-exploration.png) | Beyond the Wall — **exploration only** | Temperate road, aqueduct and service lodge beyond the perimeter; no new Area is canonised. |

A/B marks alternatives at the same segment, not additional sequential segments. The [source-backed style inventory](../../../design/2026-10-19-segment-visual-style-inventory.md) records what actually exists and the S11+ generation fallback.

## Designer review

All 18 selected images were personally viewed. Keep their differentiated massing, coherent material family, bright temperate light and natural connecting routes. Canal, rail, underpass, military, ruined and gate plates establish distinct large forms rather than only palette changes. S5's compact gate court and S10's larger departure axis should remain recognisable relatives with different encounter scale.

The set still inherits stronger and more uniform roof/paving/mortar line detail than the intended final game materials. Later prompts reduce clutter and improve broad grouping, but the over-lined surface issue is **not fully solved**. Runtime assets should simplify joints and repeated roof marks, group shadows broadly and concentrate strong edges at structural boundaries. Preserve these original concepts rather than filtering them into supposed finished game assets.

Further translation notes: plate 13 interprets its small postern as a substantial gate; avoid making every outer-wall approach another final boss gate. Plate 14's canted layout must be adapted to the fixed north-up camera and real parcel geometry. Plate 15 contains extra tiny parapet guards; they are scale dressing, not an enemy-count or encounter proposal. Several concepts use fuller civic paving than the current theme terrain; the common-building pass must retain the actual dirt/moss/grass and route-material policies. New canals, rail, overhead bridges, gate assemblies and tents require their own physical/streaming contracts.

## Work in parallel

1. **Common base buildings:** the existing building-family chat extends accepted ordinary urban architecture across S2+, including the current S11+ fallback, while preserving theme ground/layout, physical parcels, entrances, rewards and seeded choices. Authored S1 and Hub keep their own architecture. Legacy roofless exploration rooms are a separate unresolved family. Native S3 and S7 samples were visually inspected by root; they show broader kit coverage, not completion of these painted districts.
2. **District architecture and generation:** [dedicated design packet](../../../design/2026-10-19-district-generation/README.md) maps every theme and connected infrastructure. First playable target is S3: a genuinely distinct guard-office/loggia family with deep arch bays and a supported watch-bay roof silhouette, not merely colour and extra signs. It must fit real entrances, all supported orientations and irregular outlines. Canal/rail/underpass structures and gate courts follow as separately bounded generation work.
3. **Asset production and review:** derive modular roof/frontage/structure pieces from the selected direction, with exact supports, anchors, orientation and cutaway rules. Never paste a complete painting over the map. Preserve existing collisions, search/security labels, objective keepouts, reachability and deterministic ownership. Native traversal/combat/streaming evidence remains separate from concept review.

The implementation chats retain their own progress and verification reports. The base owner holds production/engine/Git until explicit handoff. The root designer creates concepts, reviews native results and coordinates the next district slice.

## Prompts, originals and checkpoint

- [Shared brief](COMMON_BRIEF.md) and [all 18 scene jobs](image-jobs.json).
- Exact final prompts, tool mode, original-output paths, SHA256 and per-image QA: [01–06](group-01-06-manifest.json), [07–12](group-07-12-manifest.json), [13–18](group-13-18-manifest.json).
- [Completion verification](verification.json) records file coverage and original-byte correspondence.

Human-requested checkpoint `d0f99e0614959bceb86514b0347f3e96f496fbea` was verified on `origin/enemy-world-work`. It includes the first 15 saved images (01–05, 07–11, 13–17), brief/jobs/gallery and initial district docs. Plates 06, 12 and 18, all three final manifests and this completion record were saved **after** that checkpoint; they must not be described as already included in it.
