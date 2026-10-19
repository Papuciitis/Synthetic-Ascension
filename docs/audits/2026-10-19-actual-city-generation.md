# Actual procedural city inspection — 19 October 2026

The user requested inspection of actual generated areas, correction of breakage,
and an honest comparison with concept 08. This pass uses the real Game, plan,
theme, chunk streaming and parcel generator, rather than only forcing the new
kit into synthetic road fixtures. It preserves the existing organic road layout.

## Findings and corrections

The complete painted family was enabled only for S2's
`secondary_reward_building` role. Other production roles still used oversized,
high-contrast flagstone and roof textures. S2's shared ground now uses the
original worn-sett and limestone assets with smaller, quieter material units,
and restrained grass/soil contrast. Original material IDs, organic ownership
maps, light/stain data and world coordinates remain intact. The presentation
switch resets outside S2. Existing non-kit S2 roofs receive lower texture
contrast without changing their silhouettes or cutaways.

Access corridors and road arms previously met with different material responses
and a seam shadow, producing overlapping rounded paving patches. S2's road
layers now share one sett response and omit artificial hard-ground seam shade;
vegetation edges retain their lip/contact treatment. Actual dirt layers remain.

The composed kit's exterior strips extended beyond their owning chunk, despite
only subtracting local parcel interiors. A regression check reproduced 154
out-of-bounds surfaces. Composed geometry now stays within its chunk and fades
over the final 96 world pixels into the shared organic ground. It cannot paint
over uninspected neighboring interiors.

Actual attempt seed 211 exposed a separate placement failure at chunk `(0,3)`:
the required searchable-building role, north connector and courtyard access mask
14 produced no objective interior. Access corridors crossed the full-depth
frontage bands, so regular placement and its existing full-depth fallback both
failed. The corrected test uses the actual mixed `plan.seed`, theme and urban
access, rather than substituting the attempt seed for the chunk seed.

Only when a required parcel produced no buildings, placement now searches for
a smaller 7×8 (or rotated 8×7) workshop inside the same original frontage band.
The standard chunk/keepout checks and actual building/door creation path remain
authoritative. This adds no RNG draws during the search, changes no existing
successful parcel and retains all protected road/courtyard access. The objective
still uses its original rules and reward identity.

## Native evidence

All under [actual generation reference](../art/reference/2026-10-19-city-generation/):

- `before/`: actual seed 16102026, five production roles, 10 normal/small images.
- `after/`: first material pass, 12 images including the old boundary.
- `seed-211/`: second seed revealing the empty required-building area.
- `final/`: final continuous-road response and corrected boundary, seed 16102026,
  12 actual Game stills at 1280×720 and 960×540.
- `final-211-joined/`: final treatment and repaired generated building, seed 211,
  14 stills including an actual required-building close view and boundary pair.

Both final static runs exit zero with no diagnostics, failures or save writes.
They are controlled/frozen outside states, not motion, collision or performance
certification. Their manifests retain exact camera, role and coordinate data.
Scratch capture source and process/test logs are retained under
`.superpowers/sdd/2026-10-18-city-block/`.

The art chat inspected final seed 16102026's service junction, district fill and
kit boundary at both sizes and kept the bounded material/junction/overdraw fixes.
It specifically distinguishes this from a stylistically seamless whole city:
approved kit roofs/frontages still visibly differ from legacy neighbors.
It also inspected the repaired seed-211 closeup at both sizes, clearing building
presence only. Its [focused review and inspected-image register](../art/reviews/2026-10-19-production-city-generation-designer-review.md)
keep collision, live combat and motion acceptance separate from that verdict.

## Regression checks

The new actual-plan test checks one objective interior, a reachable real doorway
and untouched protected road/courtyard cells in each of four S2 plans (attempt
seeds 17, 211, 2026 and 16102026). All four pass after reproducing the seed-211
missing-building failure. The parametric kit sweep now passes 4,580 checks across
20 layouts, including the new chunk ownership constraint. Kit checks pass 1,118.

The broader production route suite passes 3,840 chunks, 2,538 doors and 1,728
reward placements, with zero failures. This sweep varies connectors/roles but
does not substitute for the separate actual-plan urban-access check above.
All 542 gameplay scripts parse. The existing ground-streaming test fixture was
made explicit about disabling content generation without furnished cover scenes;
the new material-switch fixture supplies its dummy player. This removes setup
diagnostics instead of counting their prior zero-exit logs as clean evidence.
Both corrected fixtures pass cleanly: ground ownership/streaming 21 checks,
and the S2 switch test verifies original texture bindings, unchanged road/
frontage/grass ownership and deactivation when a renderer is reused outside S2.

The first seed-211 moving run (`moving-211/`) is retained as failed evidence:
154 frames, one scripted route failure, zero save writes. It physically entered
the room, then attempted to reach its centre before fighting the five live
security guards. The captured interior shows the crowd on that route; real
entry/cutaway, later security clearance, exit restoration and streamed reload
succeeded. The preview now tests entry one cell past the actual threshold before
fighting, instead of requiring an unobstructed path through live guards. No enemy
collision, encounter count or building collision was disabled to pass this check.

The fresh corrected native run in `moving-211-verified/` exits zero with no
diagnostics, failures or save writes. It records 145 frames, 61 fires, 60 hits and
29 deaths across traversal, interior clearance and the controlled outside fight.
Five perimeter waypoints, physical doorway entry, roof alpha 0, security
clearance, physical exit/roof alpha 1 and deterministic streamed unload/reload
pass. Outside combat runs 12 simulation seconds. All 39 recorded current source/
asset hashes match. Raw frames and measured frame timings remain available;
this pass does not claim video playback or human continuous-play approval.

[Machine-readable checks](../art/reference/2026-10-19-city-generation/checks.json)
record the clean test/native results, source hashes and live gates. Timings are
observations from a capped Intel UHD Compatibility capture with readback, not a
benchmark or performance improvement claim. The newly replaced ground surfaces
require an additional texture sample; no packed export was tested.

## Concept comparison

**Closer materials; overall procedural streetscape still requires work.**
The actual generator does not optimize a scene against the concept image.
Semantic road/building rules produce the layout; the new shared presentation
carries the accepted palette and scale farther through that layout. It does
not yet reproduce the concept's connected inhabited frontage, broad architectural
depth, planted courtyard groups or occasional imposing civic mass.

Large grassy gaps, isolated shrub dots, legacy thick roof outlines and sparse
shallow fronts remain visible in the actual production samples. Detailed
non-south and irregular frontages remain incomplete. Extending a supported
frontage/roof family onto a real neighboring cluster, with grounded planting
and useful service infrastructure, is the next substantial art task. A palette
change alone does not complete that coverage. No new art was generated in this
pass, and no whole-city topology rewrite or balance/save retuning was performed.
