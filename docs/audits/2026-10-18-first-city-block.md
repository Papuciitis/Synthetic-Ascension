# First playable city block — 18 October 2026

Latest streetscape follow-up: see the [street/ground audit](2026-10-18-city-ground.md)
for the procedural road/material, depth, planted-corner and original-asset pass
continued into 19 October. The earlier block/chimney evidence below is retained.

The four art-chat refinements and the user's chimney correction are
implemented and visually cleared in the shown native states. Procedural generator
coverage and a final post-chimney small Game run pass; see the refinement section
below. This remains a limited reusable family rather than finished all-city art.

Status: **revision 02 clears the designer's architectural shape gate**;
its three fresh moving runs pass. User-requested cursor/roof-occlusion follow-up
also passes final native verification. The four-run evidence below describes the reviewed first iteration,
not fresh acceptance evidence for subsequent source changes. See the
[designer review](../art/reviews/2026-10-18-city-block-designer-review.md).
No commit or push was requested or performed. The whole-city rollout remains
outside this milestone. Existing unrelated working-tree changes were preserved.

## Next refinement — art-chat guidance, 18 October 2026

After the user requested further upgrades, the designer prioritized four bounded
relationships: domestic eave, entrance/street contact, municipal service run and
one sign of civic interior use. The next-pass recommendation in the designer
review gives locations and stop conditions against study 08. This builds on the
prior GO; it does not replace the accepted direction.

The implementation reduces the dwelling's blank fascia from 35 to 12 world
pixels, extending its front roof plane to retain the original lower edge and
align with the service-wing eave. A dull trim and narrow underside replace the
bright slab. Local soft foundation contact and flush worn entrance aprons follow
the actual doors, with a shorter domestic threshold. The existing civic pipe
becomes one coarse aged-copper/patina run with two supports, plant coupling and
a localized damp/mineral patch beside the drain. The civic room receives one
muted two-panel wall cupboard/records group in its blocked north wall band.
It is omitted whenever a north entrance could conflict. No floor furniture,
interaction, collision or gameplay-rule change is introduced.

[upgrade-review-02](../art/reference/2026-10-18-city-block/upgrade-review-02/)
contains eight clean native staged images: exterior, cutaway and matched
behind-building control/shadow views at both window sizes. Packet 01 is the
earlier eave-only iteration. Fresh checks pass 1,092 city-kit assertions, 11
roof-mask checks and all 542 gameplay scripts; code review reports no remaining
concrete blocker after the north-door guard. The designer kept the eave, contact
and service changes, then requested opaque ledger faces. Actual wall corner
fills had been overdrawing the board at the same layer: the corrected board now
shares the roof's layer but precedes its polygon, above wall fills and hidden
by the opaque roof. Two muted paper faces with broad record bands read correctly
in [upgrade-review-03](../art/reference/2026-10-18-city-block/upgrade-review-03/).
The designer cleared that remaining correction. The pre-chimney moving small run
under `upgrade-moving/small-final` passes 151 frames, zero failures/save writes,
clean native exit and physical entry/clearance/exit, streamed reload and combat.

### Procedural requirement and chimney follow-up

The user clarified that the kit must support procedural generation, and separately
reported the pale-box chimneys in the art chat. The implementation follows those
inputs: a weathered civic masonry stack with projecting coping and broad flue;
a smaller domestic rendered base/clay pot; lead flashing and short shared-light
shadow for both. Placement takes the actual supporting roof polygon and role,
selects a deterministic span clear of the ridge/eave, and skips an unsafe span.
All pieces remain beneath the host RoofPoly's fade ownership. Native
[chimney-review-01](../art/reference/2026-10-18-city-block/chimney-review-01/)
and one generated placement/cutaway sample were personally reviewed and cleared
by the designer. This supersedes the user's rejected plain-box treatment.

The real `decorate_district_parcels` generator is exercised over four seeds and
five road-arm arrangements: horizontal, vertical, cross, L and T. The 20 distinct
layouts contain 76 generated parcels, including 75 styled rectangular kit
instances across 22 sizes; all four entrance directions occur. All 2,685 checks
pass for styled/original geometry, real doors and identities, deterministic
regeneration and open road connectors. These are generator assertions, not a
claim of physical traversal through every seed. Native
[procedural-review-02](../art/reference/2026-10-18-city-block/procedural-review-02/)
contains five generated-layout inspection views using production parcel and
blocker rendering; they are not full-Game footage. Curb openings now require the
actual road arm to reach that edge, preserving L/T boundary joins.

Final focused checks pass 1,112 city-kit assertions (including opaque board draw
ownership, real doorway/north-entrance safety, functional flues, on-plane flashing
and unsafe chimney omission), the 2,685 generator checks, 11 roof-mask checks and
all 542 gameplay scripts. The native five-layout capture and eight original-block
chimney/cutaway/shadow captures exit cleanly with zero save writes/diagnostics.
Code review reports no remaining concrete blocker. Final post-chimney moving
small verification passes under `chimney-moving/small-final`: 154 frames,
61 fires, 62 hits and 29 deaths (whole-run counters), native exit 0, zero
diagnostics/capture failures/save writes, physical indoor security clearance and
roof restoration, streamed regeneration and a twelve-second outside fight.
Source hashes include all production changes in this follow-up. Earlier capture
packets remain historical; they must not be relabelled as current-source proof.

This is a reusable prototype family, not finished all-city art coverage. Detailed
painted frontages remain south-facing; other entrance orientations preserve the
existing walls and actual doors, and irregular footprints retain existing art.
The style is still enabled only for the bounded S2 searchable-building block.
Those art-coverage and rollout steps remain explicit future work. No seed layout,
collision, combat, objective or save rule was retuned by this refinement.

## What changed

Segment 2's existing searchable-building block receives a small Mediterranean /
medieval / municipal-industrial kit: a three-bay limestone civic arcade,
shuttered plaster frontage, calmer slate and terracotta roofs, pressure plant,
coarse utilities, flush curb/drains and restrained planting. Broad limestone
frontage paving is clipped against all actual parcel footprints. The existing
blended ground remains underneath. Revision 02 gives interiors a separate muted
stone floor surface, while exterior paving excludes every occupied footprint.

The kit uses the actual carver's footprints and two-cell entrances. The arcade
opening follows the same doorway-center formula as `IndoorVolume`. Walls keep
their existing batched geometry and collision descriptors; a visual variant
selects a shared quieter limestone shader. Roofs retain production entry/exit
signals and fading; the raised frontage and plant cut away with them. The
shortened roof updates its eave shadow and gable bounds together.

There are six new original PNG components, generated with built-in ImageGen.
[Asset inventory and source originals](../../assets/world/city_block/README.md)
and [exact prompts](../../assets/world/city_block/PROMPTS.md) are retained.
The kit does not require a renderer conversion or per-brick/per-tile objects.
The separately completed objective-family art/state work was not edited.
Combat values, balance, reward rules and save rules were not retuned.

## Native review media

### Revision 02 — designer-directed correction

The art chat rejected the first iteration's flat roof rectangles, compressed
frontage, isolated paving carpets and competitive interior joints. The bounded
follow-up raises the civic/domestic fronts, adds connected pitched roof volumes
and solid chimneys under the existing fading roof, quiets roof texture contrast,
and joins paving into one block treatment clipped around every real footprint.
A grouped planted pocket and coarse service outlet/drain give the alley a use.
The indoor floor has a separate subdued surface above legacy floor stamps in
both ground-rendering paths; walls keep their existing collision and batching.

The designer personally inspected both exterior and interior sizes in
[block-review-02](../art/reference/2026-10-18-city-block/block-review-02/)
and cleared the **architectural shape gate**. The earlier forms-review-01
required a further pitched cross-wing end; that finding is resolved in this
packet. Heavy house fascia remains non-blocking polish. The designer's exact
verdict and viewing limits are in the labelled review addenda.

Frozen captures are composition evidence only. New moving runs live under
`revision-02/`; the original four-run packet below remains historical.
The three matched-source revision-02 runs contain 467 frames and six cleanly
decoded videos, with native exit 0 and no capture failures, diagnostics or save
writes. All physically enter/clear/exit the interior, traverse the perimeter,
reload the block and run twelve simulation seconds of outside combat. Outdoor
population decreases by 25/26/24 and sampled projectile peaks are 6/8/5 in
normal/small/reduced respectively. Those runs precede the later player-mask
follow-up; their recorded hashes describe their capture-time source versions.
The initial `revision-02/normal` candidate also passes but predates the floor
layer fix and is excluded from the matching final trio. See
[revision-02 summary](../art/reference/2026-10-18-city-block/revision-02/review-summary.json).

### User follow-up — smaller cursor and roof concealment

Default hardware cursors are 35% smaller: pointer/click textures are 26×31 and
aim is 26×26, with hotspots scaled by the same factor. Accessibility UI-scale
enlargement remains. The exact registered textures are rendered at native 1:1
size in `cursor-review-02/`, at both window sizes and UI scales 1.0/1.5. The
first scale-1.5 proof sheet accidentally included canvas magnification; the
corrected packet fixes the preview, without another production cursor change.
Hardware cursor overlays themselves do not appear in viewport screenshots.

The player now becomes a subdued cool translucent silhouette only where real
opaque roof pixels cover its body/head. Uncovered art retains its normal colour.
The existing indoor cutaway still owns roof fading. Front/behind classification
uses each filled vertical span of the actual rectilinear footprint, including
L recesses and U courtyards, then clips the projected roof planes. The initial
whole-building depth test failed those cases; targeted tests reproduce and
resolve both. This changes no collision, movement, stats or enemy presentation.
The GPU mask is bounded to 32 nearby triangles; native captures are observations,
not a benchmark for per-frame clipping cost or every possible overlap.

The designer cleared the first staged slate-roof before/after treatment and
smaller default cursor art. Corrected cursor/roof packets retain the front and
indoor controls. The prematurely stopped first `occlusion-moving/normal-final`
run is incomplete evidence and must not be used as acceptance proof; the final
follow-up run uses `normal-corrected`. Final results are recorded separately.

The corrected final native moving run passes with 151 frames, 83 fires, 66 hits
and 31 deaths (whole-run counters), zero capture failures/save writes/diagnostics
and native exit 0. Physical interior entry reaches alpha 0 with five security;
exit restores alpha 1; streamed geometry/identity matches and unload leaves zero
visual instances. It includes the same twelve-second populated outside fight.
Source hashes now also include the player mask/controller, cursor manager and
roof scene. The final parse audit passes all 542 gameplay scripts; roof-mask
tests pass 11, character-animation integration 163, and actor-depth/shadow 38.
The animation suite's deliberate invalid-race fallback emits its expected warning.
The existing city-kit checks pass 1,083. Code review reports no remaining concrete
blocker. Recorded median process time is 16.67 ms, p95 18.33 ms with capture
readback/capped presentation: no performance improvement is claimed.
See [final moving summary](../art/reference/2026-10-18-city-block/occlusion-moving/review-summary.json)
and [designer review](../art/reviews/2026-10-18-city-block-designer-review.md).

### Original first-iteration packet

All media below is captured from the actual `scenes/game.tscn`, Segment 2,
seed `16102026`, north-up camera, zoom 1, logical viewport 1920×1080. The
preview camera follows the player with a stable world-space review offset;
the normal gameplay camera is unchanged.

| Review | Traversal, entry, combat and exit | Short outside fight |
| --- | --- | --- |
| 1280×720 normal | [Walkthrough](../art/reference/2026-10-18-city-block/normal-final/walkthrough.mp4) | [Fight](../art/reference/2026-10-18-city-block/normal-final/fight.mp4) |
| 960×540 normal | [Walkthrough](../art/reference/2026-10-18-city-block/small/walkthrough.mp4) | [Fight](../art/reference/2026-10-18-city-block/small/fight.mp4) |
| 960×540 Reduced Motion / Flashes Off | [Walkthrough](../art/reference/2026-10-18-city-block/reduced/walkthrough.mp4) | [Fight](../art/reference/2026-10-18-city-block/reduced/fight.mp4) |
| 1280×720 original art control | [Before walkthrough](../art/reference/2026-10-18-city-block/before/walkthrough.mp4) | [Before fight](../art/reference/2026-10-18-city-block/before/fight.mp4) |

Normal [exterior](../art/reference/2026-10-18-city-block/normal-final/exterior.png),
[interior](../art/reference/2026-10-18-city-block/normal-final/interior.png) and
[restored roof](../art/reference/2026-10-18-city-block/normal-final/restored-exterior.png)
stills supplement the moving evidence. The original-art control disables only
the kit in that isolated process; it uses the same current scene, seed, scale
and traversal procedure. It is not an assertion of identical AI/loot outcomes.

The four final runs contain 682 native frames. Every run records native exit 0,
zero diagnostics, zero capture failures and zero profile-save writes. All eight
video files decode cleanly with their measured VFR timestamps. Videos are silent
H.264 exports with no resize, repaint, interpolation or speed adjustment.
Viewport readback samples the walkthrough sparsely and the fights at roughly
8 fps; these are review recordings, not 60 fps animation captures.

The native player follows real input and `CharacterBody2D` collision along the
west, north, east/service alley and south approach. Exterior waypoint snapping
is recorded and bounded to one cell; the side/alley goals resolve 10–11 pixels
from their requested positions. Real `Area2D` entry starts five production
security enemies and fades the roof to alpha 0. Native ordinary attacks clear
that colliding squad before exit; the real exit restores alpha 1. No body/door
collision or enemy-AI bypass is used for the recorded traversal.

The outside fight starts with 26 controlled ordinary enemies and retains real
AI, attacks, projectiles, tells, hits and deaths. Player god mode and scripted
controller movement/aim are explicit fixture conditions. Ambient spawning is
disabled; native pickups/progression remain live. This is not a human playtest,
balance result or proof of all-build readability.

| Review | Whole-walkthrough fires / hits / deaths | Outside population decrease | Outside projectile peak |
| --- | --- | --- | --- |
| Normal | 61 / 60 / 30 | 25 | 8 |
| Small | 63 / 61 / 28 | 22 | 6 |
| Reduced | 61 / 62 / 28 | 22 | 6 |
| Original control | 108 / 61 / 29 | 23 | 7 |

Fires/hits/deaths include interior clearance and the outside fight. The harness
does not isolate those event totals by phase. The packaging check separately
requires projectiles and a population decrease in the outside phase's own frame
samples; that footage also visibly establishes player attacks and hit feedback.
Differences in clearance time or outcomes are not attributed to the art.

## Seeded reload and regression checks

Every final native run uses the production streaming teardown/rebuild path,
verifies that unloaded wall instances reach zero, then compares the target
chunk's blocker kinds, masks, city material variants, floor stamps, building IDs
and visual roles before and after reload. All match. This verifies regeneration
of this block; it does not add new save/persistence behavior.

The focused suite first failed because civic/residential presentations were
absent. Its final 1,056 checks pass, including unchanged blocker occupancy and
IDs, exact doorway-center alignment, interior/neighbor paving exclusion,
updated roof bounds/eaves and frontage cutaway. The final asset import also
completes with native exit 0 and no logged diagnostics.

| Check | Result |
| --- | --- |
| CityBlockKitTest, including after asset import | 1,056 passed, 0 failed |
| ChunkBlockRendererTest | 11 passed, 0 failed |
| ChunkBlockIntegrationTest | 64 passed, 0 failed |
| ScriptParseAuditTest | 540 gameplay scripts passed, 0 failed |

The existing integration fixture logs its existing “Player not found” warning;
it is not represented as a diagnostic-free native capture. Scoped independent
review found and led to fixes for interior paving overdraw, non-south curb
placement, stale roof framing and per-fill shader allocation. No remaining
definite production blocker was reported; the aggregate-counter limitation
above remains explicit.

## Performance observation and limits

These capped Intel UHD / OpenGL Compatibility previews reported process-frame
medians near 16.67 ms. Normal's reported p95 was 16.73 ms; the small, reduced and
original-art controls reported 16.67 ms. Each outside fight advances twelve
simulation seconds; the exported sampled spans are approximately 11.8–12.0 wall
seconds. Capture readback, a 60 fps cap and different live combat outcomes make
this a bounded observation, not a benchmark or evidence of an improvement.
The previously reported full-game loading stalls remain unresolved by this pass.

Full painted fronts currently support south-facing entrances. Other orientations
retain honest existing walls/doors and receive only the shared material/roof
treatment. The current example deliberately preserves the generated parcel
geometry; it does not yet reproduce all the concept's varied towers, compound
roof silhouettes, arcaded courts or larger tree canopy. Human assessment of the
direction, repetition, line hierarchy and busy-fight comfort remains necessary
before expanding the kit throughout the city.

## Reproduce and play

From the project root in PowerShell, with no human playtest/other engine run
active:

```powershell
./tools/capture/run_city_block_preview.ps1 -Playable
```

This opens an isolated manual S2 example with normal movement, camera and damage,
the real local encounter, ambient spawning disabled and profile writes disabled.
Close its window normally. The launcher leaves other Godot processes untouched
and refuses to start alongside another game/import run.

For another automatic capture, use a new evidence folder:

```powershell
./tools/capture/run_city_block_preview.ps1 -Review normal -OutputDirectory "$PWD/.superpowers/city-block-new-review"
```

Use `small`, `reduced` or `before` for the other conditions. The launcher refuses
to overwrite a nonempty evidence folder. `-Engine` can specify another local
Godot 4.7.x executable. `tools/capture/package_city_block_review.py` validates
the four saved runs and packages their media using the existing measured-time
encoder.

## Evidence register

[review-summary.json](../art/reference/2026-10-18-city-block/review-summary.json)
contains the four-run results and limits. Each run retains `capture-info.json`,
`run-results.json` with exact source/asset hashes, full-frame PNGs locally and
encoding sidecars with media/image hashes. All four source records describe the
captured first-iteration source version. Current follow-up edits require new
evidence. Raw frame directories are ignored by Git and runtime
imports. `.gdignore` keeps review media out of game imports.

Intermediate failures/iterations are retained under
`.superpowers/sdd/2026-10-18-city-block/`: the initial missing presentation,
incomplete-asset/test-fixture errors, camera-offset correction and an obstructed
no-attack security exit. Only the four explicitly linked final runs establish
the native acceptance claims above. No earlier frozen concept capture is
presented as moving-fight evidence.
