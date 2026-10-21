# Linux city concept-fidelity pass, phase 1 — 21 October 2026

This is evidence for the Windows lead's review, not self-acceptance.

It covers the Linux production lane, which Claude took over from Codex at the user's request. The integration branch is `claude/calib`, fast-forwarded into `codex/linux-world-production`. The before captures come from Codex's last continuation, `2d749ba0`. The after captures come from this tip. Both use seed 16102026 and the same survey points.

## Why

Codex's continuation reworked two S2 fixture homes behind S2-only gates. S3 to S10 kept:

- a stretched painted front;
- a flat pale wall kit;
- a lawn-and-road layout.

The user asked for the whole procedural city to move toward plate 08 and the segment plates. Their open complaints were:

- flat placeholder facades with a garage-like doorway;
- square paving aprons;
- placeholder pale masonry;
- a flower bed dropped on the pavement;
- superflat lighting;
- identical themes;
- isolated roof-heavy houses among lawns.

Later in the day they added two more: weathering and atmosphere, and a different mood per theme through shader effects.

## What changed (every segment)

| Area | Change |
| --- | --- |
| Facades | `CityFacadeComposer`: every non-civic, non-guard frontage is a continuous family wall field. Modules are composited over it, and doorways are fitted exactly to the physical gap. Coverage-only faces keep actor cover. |
| Roofs | Seeded compositions: workshop halls, rear wings, attached gables, dormers, chimneys and lanterns. Slate or clay comes from the family. |
| Street continuity | Attached infill rows along frontage bands, through-street seams and framed landmark squares. This is a separately salted post-pass, so lots, rewards and parcel RNG are unchanged. WorldCover now indexes occluders, so a frame only pays for the view. |
| Depth and light | One sun model: soft building casts from the drawn wall, wall-base contact shade, and one ground-shade layer. Theme light is expressed through shade, cast length and softness. |
| Ground | `DistrictGroundPolicy`: built districts stand on continuous paving with wild margins. Role values (mid, weight, tint) are calibrated against paired in-game captures, so flags and setts read as stone at gameplay zoom. The lit luminance spread rose from 0.035-0.055 to 0.055-0.075. The palette stays cool-neutral and never beige. Wild shrubs stay off built paving. |
| Dressing | Every frontage gets street life and household gardens. The flat kitchen bed takes the building's shade. |
| Plazas | Plaza rings draw as low planter walls and stone parapets. Squares get beds, a centrepiece and street furniture. |

Two integration fixes were found by the merged suite:

- The street package's interior shortcut disagreed with the dressing package's every-segment furnishing (`2c016df2`).
- Dressing's kitchen bed drew above the building's cast (`609b525f`).

## Evidence

For each theme, the start and route1 points are shown, BEFORE on the left and AFTER on the right.

- Overview zoom: [1](overview-1.jpg) [2](overview-2.jpg) [3](overview-3.jpg) [4](overview-4.jpg)
- Gameplay zoom: [1](play-1.jpg) [2](play-2.jpg) [3](play-3.jpg) [4](play-4.jpg)

## Checks

The 74 suites are listed in [checks/](checks/). Every suite passes on its latest run:

- the 60 headless suites, including the new CityFrontageDressingTest, CityStreetContinuityTest, DistrictGroundPolicyTest, PlazaPresentationTest and SunShadowLayerTest;
- 13 native render suites;
- ScriptParseAuditTest: 564 scripts.

Reruns are recorded in `r*.log` and `n2/n3.log`. Three suites had first been refused because a transient foreign Godot process was running. Two suites were updated deliberately to the flat-bed rule; their commit messages explain why. The remaining runtime diagnostics are the existing fixture warnings and leaks at exit.

## Limits and open items

- **Themes still look too alike at gameplay zoom.** The carriageway is grey setts in most families, and S7 to S9 lost the old warm-beige and green fields. That drift was against the brief, but nothing distinct has replaced it yet. Two packages are written and parked, untested: `claude/wp-mood-wip` (per-theme grade, air, particles) and `claude/wp-weathering-wip` (walls, roofs, ground, smoke).
- **Open spaces are still broad and empty.** District_fill chunks read as large paved fields.
- **Ground GPU cost.** The policy shader fails SIMD16 register allocation on the UHD 620, costing about +3-4 ms per frame at 1080p. A register-pressure rewrite is parked on `claude/wp-ground-wip`. The ground review's remaining majors are also open there: care lozenges on paving, door aprons, index-3 overload, occlusion seams, yard patches, the S2 double road.
- **Dressing review majors not yet fixed:** slate-roofed S2 interior masonry, and the loss of the planted corner planter (`claude/wp-dressing-wip`).
- **Street review majors partly open:** long walls without passages, passages narrowed by later rings, courtyard door flips, the streaming hitch (`claude/wp-street-wip`).
- **District walls and gates (S5, S9, S10) are not merged** (`claude/wp-districts`). The review found a blocker, an invisible siege crane obstacle, and majors: sealed courtyard doors, a first-touch texture hitch, and emptier feature chunks.
- **Not started:** building families (ruins and brick; staged), lived-in interiors (WIP) and chunk-build performance.
- **Host incident.** From 13:10 the host was unstable: overheating under parallel load, then system-wide crashes. Work paused, and the PC was restarted at about 14:35. `git fsck` is clean, and every check above was re-run after the restart.
