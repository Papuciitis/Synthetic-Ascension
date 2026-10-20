# Linux S2 packet — lead art review

20 October 2026. Received Linux branch at
`1fa7a55202bf2276ccbde99450256fe8ef20c375`, implementation `5f851103`, evidence
`1e90f92a`. **Keep the source fit and capture work. The street and ordinary
houses are not visually complete. Proceed with L2 on these same samples.**

The branch is published and was fetched successfully. The authentication failure
recorded at the end of LINUX_STATUS is historical; Linux should acknowledge the
successful publication in its next update. The human can relay Git operations
manually when necessary. No cross-PC live-chat delivery is assumed.

## What was actually reviewed

The lead personally compared [concept 08](../../concepts/2026-10-18-city-directions/08-mediterranean-medieval-industrial-city.png)
with all four [whole-home exterior plates](../../reference/2026-10-20-linux-s2-street/README.md),
the genuine bed/tree cutaways, all three occupied fight stills, and 12 sampled
video frames from each of the three walkthroughs. The [motion samples](motion-review/review-samples.json)
identify the exact video hashes, timestamps and inspection sheets. This is
sampled sequence review, not continuous playback or human comfort certification.

An independent art reviewer checked the concept and the same principal stills.
An independent code reviewer inspected the Linux changes, actual check logs and
native result records, and matched eight scoped Git blobs to the native source
record. The lead verified all **120 published artifact hashes and lengths** from
a Git archive, and all six selected garden/ground/household source PNG hashes.
These are checks of the published packet; no Windows Godot was launched.

The [Linux packet](../../reference/2026-10-20-linux-s2-street/README.md) remains
the detailed source of commands, run conditions and results. Useful technical
work was done: a monitored Linux lane, actual roof/volume identity lookup,
whole-house still framing, real entry/exit and qualified streamed reload/fight
evidence. This removes the missing-fit evidence problem; it does not remove the
remaining art problems.

## Keep / rework decisions

| Area | Decision and evidence | Required consequence |
| --- | --- | --- |
| Herb bed | **KEEP at the tested scale/contact in this fixture.** It reads as a low planting bed beside the wall, preserves its narrow source aspect, leaves the entry clear and remains outside the roof cutaway. | Retain the existing source and anchor. Establish a cared plot around it through L2; do not enlarge the prop to substitute for ground care. |
| Small fruit tree | **KEEP at the tested scale/contact in this fixture.** The compact crown fits the corner without an obvious floating root, roof clip or blocked door in the dedicated stills. | Retain v2 at 135 world px visible width and the measured root anchor. Its bright crown still needs a coherent tended ground pocket. Do not regenerate it. |
| Organic footprints and nearby workshop | **KEEP.** The L-shaped home, differing entrance directions, actual lane connections and fitted neighbor are useful steps. | Preserve these sites, their asymmetry and combat space. Do not restart the whole exterior or impose uniform square blocks. |
| Household care versus wilderness | **REWORK — next packet.** A tidy prop sits against substantially the same rough green ground everywhere. The tree reads as a bright shrub attached to an isolated building, not a small inhabited garden. | L2 must make local care legible in the ground itself while leaving the outer landscape rough and some homes untended. |
| Domestic exterior finish | **REWORK.** The bed home's long tan band looks smeared/stretchy above repeated shutter bays; its large dark rectangular entry reads as an unfinished opening. Raising a wall has not by itself created inhabited medieval massing. | During L3, retain the footprint but correct the material scale/UV and selected structural divisions, doorway reveal/jamb/lintel/threshold contact. Keep the physical opening clear. Do not add ornament everywhere or stretch a painted window bay to fill height. |
| Ordinary house interiors | **REWORK — high for domestic identity.** Both are genuine entered homes, but still empty paved enclosures with pale wall grids. | L3 must show sleeping, cooking and one restrained work/storage corner, plus stronger domestic stone/mortar and lower-face shadow. Apply it to actual perimeter faces as well as partitions. |
| Actor/world depth | **REWORK — blocks occupied-street visual acceptance.** In the bed fight, a fully coloured enemy and projectile visibly draw across the neighboring slate roof. In the tree fight, actors/tells cross upper civic faces and roof edges. They appear to stand on architecture. | Keep this as a named required visibility follow-up, V1. Inspect the existing staged-visibility work before duplicating it. Correct depth/occlusion and retain intentional accessibility cues; do not simply hide all enemies/tells behind buildings. |

Direct evidence:
[bed small](../../reference/2026-10-20-linux-s2-street/bed-small/exterior.png),
[tree small](../../reference/2026-10-20-linux-s2-street/tree-small/exterior.png),
[bed cutaway](../../reference/2026-10-20-linux-s2-street/bed-walk-normal/interior.png),
[tree cutaway](../../reference/2026-10-20-linux-s2-street/tree-walk-small/interior.png),
[bed fight](../../reference/2026-10-20-linux-s2-street/bed-walk-normal/fight.png),
[tree fight](../../reference/2026-10-20-linux-s2-street/tree-walk-small/fight.png).

The concept is still substantially ahead in connected roof masses, inhabited
frontage, purposeful services and open daylight. These scenes read as houses in
large green gaps, with broad paving around them. L2 is a bounded way to improve
the place; it is not a promise that changing grass alone finishes the street.
Preserve useful imperfections while making care, occupation and material
relationships intentional.

## Next Linux packet: L2

Use the [ground direction](../../2026-10-20-ground-material-direction.md).
The existing assets are sufficient for the next trial:

| Source | Immediate use |
| --- | --- |
| [cared_lawn.png](../../../../assets/world/ground/city_care/v1/cared_lawn.png) | Short irregular cared ground local to an eligible occupied row_house. Preserve alpha-independent terrain ownership, route clearance and wild growth beyond the cared pocket. |
| [damp_moss_soil.png](../../../../assets/world/ground/city_care/v1/damp_moss_soil.png) | Low subdued moss/soil in the natural S7 canal-services setting, replacing the blue large-leaf presentation. Preserve cool damp character and mud/paving relationships. |
| Existing rough grass, localized overgrowth, dirt and wet mud | Keep the wilderness and neglected range. Establish worn access and wet/dry distinctions through use and material structure, not global recolour. `ground_dirt_path_01.png` is paving. |

Implementation boundaries remain the handoff's: actual domestic-use eligibility,
bounded irregular local masks, deterministic stream reset/reload, no new terrain
IDs just for pixels, no ninth GroundSplat alias, no paving/threshold overwrite,
and a validated rebuilt baked ground array when its sources change.

Return a small paired review, under the monitored Linux lane:

1. Same two real homes: seed16102026/chunk(0,3)/ID944996572 and
   seed17/chunk(-3,5)/ID2128236757. Show 960×540 with natural props and an actor,
   including ground beyond the cared pocket. Retain a matching 1280 context
   where a small view hides the transition.
2. At least one actual nearby untended/wild comparison so maintained versus
   wilderness is visible without relying on which prop was spawned.
3. Natural S7 seed4/canal_services: subdued green moss, wet soil and paving in
   one view, with actor/tell readability. Confirm actual rendered cache inputs.
4. A short occupied comparison for the changed ground, plus relevant terrain/
   cache/reload checks and exact source commit. Preserve old before evidence;
   do not rerun all prior footage merely for packaging.

Reject a result that globally replaces wilderness with lawn, adds rectangular
green islands, merely hue-shifts the same tall leaves, sharpens noisy detail, or
claims tests close the art findings. If the selected material fails at native
scale, request one precise asset correction with the failing crop, footprint,
scale and placement context.

## Following packet: L3 and the visibility gate

[timber_cot.png](../../../../assets/world/domestic_interiors/v1/timber_cot.png)
and [cooking_hearth.png](../../../../assets/world/domestic_interiors/v1/cooking_hearth.png)
are already supplied with [anchors and footprint estimates](../../../../assets/world/domestic_interiors/v1/manifest.json).
Reuse suitable existing table/storage props. Show a plausible bed, a cold cooking
place, and one work/storage grouping around a clear movement center; do not
scatter generic clutter or obstruct real entry/combat. The [domestic brief](../../2026-10-20-medieval-gardens-and-domestic-interiors.md)
governs the masonry and the true-home baseline. Existing original wall textures
are available; a new furniture or wall pack is not justified before the trial.

Carry V1 roof/entity compositing as an explicit blocking finding until corrected
and re-reviewed in motion. L2/L3 may proceed in bounded steps, but their success
must not silently close V1 or the full street milestone. No new district
families, S4A, balance changes or world-generation expansion are requested.

## Evidence limits and integration decision

The Linux changes are accepted into integration as **qualified work in progress**:
capture tooling/test improvements and a reviewable baseline, with no product
generation/art/gameplay-rule change. Seven native records report completed/exit0;
the three full previews report physical entry/exit, five perimeter targets,
garden/architecture reload equality and 12 simulation seconds of controlled
exterior combat each. The stated focused Linux checks passed. Original raw import
logs retain their whitespace; do not rewrite evidence to silence cosmetic diff
warnings.

The preserved existing Linux checkout is not a fresh clone. Twenty untracked
import sidecars are disclosed and hashed. Source scope does not include every
generated `.godot` cache or all character/UI pixels. Earlier stills used dirty
tracked source whose recorded content matches the later commit. Scripted controls,
god mode, disabled ambient spawner, controlled enemies and frozen streaming after
the explicit reload remain qualifications. The north-entry moving camera crops
the lower home; the dedicated stills supply whole-home fit. The Linux strict
warning snapshot was not repeated. Sampled video, capture overhead and recorded
frame timing do not establish human comfort, ordinary horde balance or a
performance improvement.

Linux should fetch/merge the integration branch, read this review, acknowledge its
received hash in LINUX_STATUS, correct the obsolete publication-blocked state,
and start L2. ART_STATUS remains Windows-owned. The user may perform any required
push/pull manually; report the exact branch/hash if a relay is needed.
