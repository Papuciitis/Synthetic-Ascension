# Segment visual-style inventory

2026-10-19. Source inventory requested before expanding the city art beyond its current coverage. This document records existing names, generation fields, authored spaces and visual gaps. It is not approval to apply the Segment 2 renderer to every segment.

The human clarified that S8 was an arbitrary spot check. The requested review and subsequent visual development cover all segments and their distinct identities; S8 is an example of the wider coverage gap, not the sole target.

## Scope and sources

Area 1 is **The City**: an institutional escape opening into increasingly peripheral city districts. Segment 10 is departure from Area 1 rather than the end of the game ([world structure](../gamegoal.md#5-world-structure)). Current exact theme labels and selection rules come from [SegmentThemePicker](../../core/systems/world/proc/SegmentThemePicker.gd:10). The [historical progression list](../history/PROCEDURAL_GENERATION_0.25.0.md:35) broadly agrees, using some shorter names.

There are **14 named procedural themes across S2–S10**, plus authored S1. S4, S6, S7, S8 and S9 each use a seeded two-theme choice. The selected theme is stable for the segment/attempt seed. S2, S3, S5 and S10 have fixed themes.

The descriptions below summarize implemented terrain/tint/layout fields and documented intent. A theme name does not prove its defining architecture or props are implemented.

## Complete numbered catalogue

| Segment | Exact current name | Existing identity and visible generation cues | Source |
| --- | --- | --- | --- |
| 1 | **The Institution** | Authored escape through admissions, laboratories, archive/research wings, containment courtyard, service district and the outer gate. Brighter admission stone, darker research stone, paved courtyard, dirt service routes. | [S1 design](2026-09-19-segment-1-design-pass.md:13), [authored builder](../../core/systems/world/Level1Builder.gd:96) |
| 2 | **Service Courtyards** | Open, explorable service courts. Grass-based ground with a warm neutral tint. Current civic/domestic city art is implemented here. | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:50) |
| 3 | **Checkpoint Lanes** | Tense security streets. Dirt with grassy exploration, cooler ground tint, denser fallback building mix and checkpoint barricade eligibility. | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:88) |
| 4A | **Collapsed Ward** | Warmer scrub/grass district, greater ruin weighting and overgrowth/decal budgets. | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:126) |
| 4B | **Civilian Cut-through** | Grass/meadow, warm pale tint and denser urban fill. The inhabited alternative to the collapsed ward. | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:164) |
| 5 | **Inner District Gate** | Dense gate district, dirt/grass, subdued cool tint and larger courts. Mandatory miniboss court before the gate. | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:201) |
| 6A | **Industrial Cut-through** | Dirt-based main and exploration terrain, muted warm tint, stronger building weighting. | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:239) |
| 6B | **Ruined Service District** | Scrub/dirt, warmer tint, more ruins and growth than the working industrial alternative. Historical shorthand: “Ruined Services.” | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:275) |
| 7A | **Underpass Veins** | Dirt/moss, cool blue-gray tint, narrow main lanes and dense urban fill. | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:295) |
| 7B | **Canal Service Routes** | Moss/mud, cool blue-green tint and wetter ground identity. Historical shorthand: “Canal Services.” | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:331) |
| 8A | **Rail Yard Expanse** | Dirt/grass, dry warm tint, more open urban envelope and sparse vegetation. | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:351) |
| 8B | **Military Staging Ground** | Dirt/grass, cooler gray-green tint, more building-weighted generation, very sparse vegetation and checkpoint barricade eligibility. | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:389) |
| 9A | **Outer Wall Approaches** | Grass/scrub, muted neutral tint, sparser urban envelope and checkpoint eligibility. | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:408) |
| 9B | **Siege Service District** | Dirt/grass, warm tint, denser building mix than the outer-wall alternative and checkpoint eligibility. Historical shorthand: “Siege Services.” | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:444) |
| 10 | **Gate District** | Dense city departure district, dirt/grass, cool pale tint, broad gate plazas and the mandatory boss court. | [theme](../../core/systems/world/proc/SegmentThemePicker.gd:461) |
| 11+ | **Beyond the Wall** in narrative; **Service Courtyards** in world-generation fallback | Play continues. A distinct beyond-wall environment family is not authored; the picker falls back to the S2 theme. This is a current coverage gap, not an additional completed biome. | [fallback](../../core/systems/world/proc/SegmentThemePicker.gd:34), [continuation](../../autoload/global.gd:41), [narrative](../../core/systems/narrative/StoryDirector.gd:397) |

“A/B” marks alternatives at the same segment number, not extra sequential segments. Default empty/building/ruin weights describe fallback generation, not overall percentages of a complete district.

## Additional spaces that need their own treatment

| Space | Existing identity | Relationship to the catalogue |
| --- | --- | --- |
| Between-segment **HubWorld** | Sheltered market courtyard; warm paving and lamps, red/slate roofs, stone/plaster, dusk tint, autumn planting, stalls, obelisk/dais and Quiet Alcove. Merchant, Ascension, Gear & Stash, Papers and Next Segment stations. | Separate authored hub family, not an S2–S10 theme. [HubWorld](../../scenes/hub/HubWorld.gd:3) |
| S5 miniboss court | Dedicated clear pre-gate encounter court. | A special space within Inner District Gate, not another district theme. [BossArenaSpace](../../core/systems/world/proc/BossArenaSpace.gd:7) |
| S10 boss court | Dedicated final city-gate encounter court at the exit. | A special space within Gate District, not another district theme. [DistrictPlan](../../core/systems/world/proc/DistrictPlan.gd:300) |
| DonJon compounds and compact halls | Stone enclosures, slate wings, optional outdoor court, gatehouse, cells/storage/service cues and roof cutaways. | Cross-cutting building family on eligible sites; ordinary houses do not automatically become DonJons. [accepted first pass](../art/reviews/2026-10-19-donjon-architecture-designer-review.md) |
| Opening illustrations | Historical/admission/synthesis/records story presentation. | Painted presentation images, distinct from walkable map architecture. |
| PeeP continuation | Dark warm-brown conversation presentation with uneven gold margin. | Separate terminal-attempt UI, not a numbered world biome. |
| DevSegment | Debug outdoor/corner-room setup. | Test content, not an additional campaign style. |

The four shared pressure phases—Recon, Disturbance, Ascension and Collapse—and relay/vigil/breach-seal objective choices are gameplay states. They do not add new district styles.

## What already differentiates themes

Current theme data drives terrain selection, gentle ground/floor tint, urban-fill probabilities, fallback building/ruin mix, lane/plaza dimensions, vegetation/decal budgets and DonJon tendency. Road materials also vary by semantic route role. Selected checkpoint themes add roadside barricades.

The `district_family` identifier is stored in [SegmentThemeData](../../core/systems/world/proc/SegmentThemeData.gd:8), but the audited generator/rendering path does not consume it as a dedicated architecture-family selector. Shared landmark/vegetation art is reused across themes.

No theme-specific world-generation implementation for rail tracks/trains, water canals, tunnel ceilings, military tents or foundry structures was found in this inventory. Those names establish district identities to develop; they are not evidence that these physical features are already present.

## Why the visual upgrade is missing across most segments

[CityBlockKit.enabled_for](../../scenes/world/buildings/CityBlockKit.gd:31) explicitly enables the refined ordinary-building family only for S2. Both streetfront parcels and courtyard-fill buildings use this policy. Ordinary buildings in S3 and later therefore retain the legacy roofs, wall presentation and interior floor; the S8 screenshot illustrates that wider gap. S1 has its separate authored building path.

The new DonJon paths are separate: eligible large default-chunk sites and chance-selected compact dungeon regions can receive the dungeon family. Eligible street/district chunks normally roll a 95% parcel-placement attempt; required reward buildings use 100%. Successful parcel placement bypasses compact DonJon generation. A successful dungeon capture does not demonstrate ordinary-house art coverage in every segment.

The coverage gap is confirmed. The exact theme/seed/coordinate of a house cannot be inferred from screenshot appearance alone.

## Existing common art direction and boundaries

The accepted city direction combines Greek/Roman/Mediterranean masonry, medieval European city forms and restrained early industrial, sci-fi, steampunk and authoritarian monumental cues. The current human brief also requires believable depth/shadows, restrained lights, readable combat ground, quieter broad planes and natural uneven streets. The [accepted city concept](../art/concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png) and the [DonJon handoff](../art/concepts/2026-10-19-donjon-directions/DESIGN_HANDOFF.md) establish useful common language.

Per-theme identity still needs its own architectural/prop/light treatment. The inventory does not authorize flattening distinct dirt, moss, canal, rail, military or gate districts into the same S2 courtyard scene, nor replacing their protected ground/roads with the S2 prototype's composed paving.

The vision describes an institutional/security opening, escalating specialist containment and anomalies, and later reality instability. It does not assign those phases to exact segment numbers. Later Areas remain flexible until Area 1 works ([vision](../SYNTHETIC_ASCENSION_VISION.md), [world structure](../gamegoal.md#5-world-structure)).

## Historical authority

The full name sequence is a repository record, corroborated by current code. The recovered direct user requirement specifically establishes an open/explorable S2 followed by a tense S3 ([exact source](../history/chat_archive/sources/699b92a5-20b8-838e-aac5-943bb51dc741/page-001.json:132)). Earlier assistant labels such as “Courtyard Junction” and “Tight Streets / Hunt Net” are proposals, not extra canonical themes.

The archive is incomplete; its [coverage register](../history/chat_archive/coverage.json) records the gaps. This inventory does not reconstruct missing original art briefs from assistant recaps.

## Work state

Broader ordinary-building rollout is on hold at the human's request to review this full list first. The 29 supplied Godot compiler warnings are a separate cleanup task. Diagnostic coverage tests created before the hold contain provisional expectations and are not an approved segment-style policy.
