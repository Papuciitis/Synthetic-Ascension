# S3 guard-loggia — bounded asset brief

19 October 2026. Historical commission brief, now executed: the two original arch masters and measured provenance are in [checkpoint assets](../../../assets/world/districts/checkpoint_lanes/README.md). Read the [executed plan](04-s3-guard-loggia-implementation-plan.md), [selected concept handoff](../../art/concepts/2026-10-19-segment-directions/README.md) and [current production register](06-production-ownership-and-status.md). Original instructions below preserve the commission context; they are not a claim that assets or the lane are still pending.

## Target and reference authority

Primary reference: [S3 plate 03](../../art/concepts/2026-10-19-segment-directions/03-s3-checkpoint-lanes.png), SHA256 `3CC022A165A5D2611D1DEEACDFCECA35F509CF42F16EE82F3CD5640B4822F71B`. Shared material/camera anchor: [accepted city 08](../../art/concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png).

Produce a guard-office/loggia family distinguishable through substantial stone arches, deep returns, ordered inspection bays and a compact watch-bay roof silhouette. Pale cool stone, broad slate and restrained iron/copper support the forms. Reduce repeated mortar/roof marks substantially from the concept; concentrate edges at structural joins. Bright readable daylight remains authoritative.

The selected retry has no overhead gantry. A gantry was present in an earlier version/written job and is not a missing pilot requirement. Gate piers, barricade topology, coats of arms, every banner and full concept landscaping are not required miniature copies. Preserve a true open doorway instead of the image's potentially obstructing hanging cloth.

## Required original modular assets

Commission only two new architectural masters initially. Their broad geometry remains runtime-owned; no complete building image or scene becomes a sprite over the map.

| Runtime target | Required content / alpha | Placement and native scale contract |
| --- | --- | --- |
| `assets/world/districts/checkpoint_lanes/guard_arch_open.png` | Isolated upright south-facing limestone arch surround with thick piers, deep inner reveal and a restrained coping. Transparent outside **and through the opening**; no door leaf, step, floor, hanging flag, freestanding equipment or cast shadow outside the assembly. | Target rendered height 192 px for a rectangular family; true opening remains the existing 128 px two-cell door. Crop/UV anchors are recorded from the returned original rather than assumed. Side/north recesses use geometry, not a rotated south image. Preserve complete inner clearance when fitting. |
| `assets/world/districts/checkpoint_lanes/guard_arch_closed.png` | Matching limestone inspection bay with a visibly closed iron grille or shutter/back wall in the recess. No apparent open doorway. Transparent outside its masonry silhouette; quiet stone faces and broad recess shade. | Native bay width 128–192 px, target 160 px; height follows the 192 px family wall or reduced 112 px irregular wall. Fit complete supported bays between physical entry spans; use plain pier geometry when too narrow rather than stretching grille patterns. |

The source master should have ample resolution for the 192 px rendered height, with no background scene. Use the built-in image tool with transparent background; view reference images before generation and inspect every original. If a generated opening contains backdrop/opaque fill, correct with the image tool. Do not remove backgrounds, composite arches or paint shadows with scripts. Save tool-native original bytes, exact final prompt, source path, SHA256 and any tool-native revision history.

## Geometry and reuse

The watch mass is **rendered architectural geometry**, using the existing slate texture/shader and masonry family surfaces: 128×128 px support with 16 px margin and 96 px additional lift at the 64 px cell scale. Its hipped/compact official roof replaces the corresponding generic civic cap; it is not a tower sprite pasted on an unrelated roof. Resolve support on the actual footprint/roof and omit the optional mass when no safe candidate exists. Use broad planes and a small recessed watch opening, not an accessible upper doorway.

Reuse existing shielded wall lantern, slate texture, neutral stone/material helpers and records-board construction where compatible. There is no need to generate a new lamp merely to make the district look new. A small order panel/equipment housing can be built from existing assets/geometry after the architecture reads correctly. Keep these decorations independently hideable and avoid duplicating the common kit's board, lamp or pressure plant.

## Anchor/provenance record

For each master record actual image size; outer masonry bounds; arch inner-clear polygon; feet/baseline; left/right pier support spans; material/texture orientation; intended display height; UV crop; and revision/hash. Store a matching rendered overlay showing these anchors as **vector debug geometry in the engine**, not a modified claim about original pixels. Assembly support/door tests must use the recorded measurements.

Fixed light is northeast with southwest cast direction `Vector2(-0.72, 0.50)`. Generate local recess/contact shading only; runtime geometry owns the shared exterior cast shadow and roof-linked fading. No live light or new animation is needed.

## Review set and acceptance

Review an exterior, entered cutaway and rear/side entry for a real rectangle; one L/recessed fallback; a passage with both exits; and an unsupported-watch case. Use actual 1280×720 and 960×540 output with a player scale reference, plus moving combat/streaming evidence later. Show matching common-base/guard views with all boards, lamps, cloth and small equipment hidden: the arch depth and roof/watch mass must still distinguish the family. This compares architecture, not colour filters.

Reject facade artwork that covers real opening cells, creates a false walkable arch on blocked floor, introduces noisy equal-weight tile lines, floats beyond its support, or requires opaque overdraw across a footprint notch. A safe reduced form is acceptable on an individual constrained parcel; the representative full family must still deliver the selected guard-loggia silhouette.

## Implemented masters and measured revisions

Both original transparent PNGs are implemented under [checkpoint assets](../../../assets/world/districts/checkpoint_lanes/README.md), with full prompts, returned original paths, immutable hashes and measured anchors. No raster derivative was scripted. Runtime region/UV selection consumes the originals. The open arch's measured masonry returns require an 80 px exclusion beside a 128 px opening; ordinary inter-bay piers remain 24 px. The watch roof uses a 32 px pitched cap above the 96 px upright mass to read at the native camera. These bounded proportion revisions are tested and recorded in the audit. Native small/normal architecture pairs, all four real entrance directions and an irregular parcel are linked in the evidence index; constrained no-watch and passage cases also have focused geometry/render tests.
