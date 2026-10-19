# City streets and ground — 18 October 2026

The user asked for streets, grass and dirt to approach study 08, remain
procedural, and receive screenshot review from the art chat. Their later direct
messages there also request uneven old-city roads, stronger depth/shadows/light,
more ambitious fidelity and replacement of the flat L-shaped service outlet.
The current visual target is a complete streetscape, rather than the earlier
individual KEEP checkpoints. Work continued into 19 October. That chat supplied
five original foliage/frontage/material assets with the user's explicit
authorization; all five are integrated and source bytes/provenance retained.

## Implemented system

The S2 prototype block's existing shared exterior polygons use a new ground
material. It distinguishes quiet smaller cool road stone from lighter limestone
frontages, derives the union and open connectors from actual generated road
arms/chunk dimensions, and adds broad asymmetric visual width changes with a
restrained splayed junction. Broken shallow curbs, localized earth/growth and
broad stone repair groups replace the single surface and continuous green belt.
Texture/profile variation uses continuous world coordinates; generation's RNG,
actual collision and protected road/door routes are unchanged.

Building shadows use the existing shared southwest sunlight direction, with
different civic/domestic heights. All local parcel interiors are subtracted.
Standing-wall shade remains during roof cutaway; the cover-dependent portion
fades. The enlarged planted corner has an alpha-textured foliage shadow, including
explicit atlas-region UV handling through polygon clipping. Foliage shade stays
constant when the building opens.

The civic opening now separates shaded arched recess, jamb and receding floor
planes, with a small shielded entry sconce and local warm response. These shallow
frontage details fade with the roof/front. The service run terminates in a short
mounted shaded elbow directly over a flush iron catch drain in a stone surround;
the long graphic pipe across the pavement is removed. Planting has a contained
stone base and soil response at the actual corner. None adds collision, objective
rules, rewards, balance or save changes.

The original tree uses its measured `(650,1170)` root in the 1254-square image;
the selected ivy trough uses its actual stone foot rather than the dangling ivy.
Their contacts remain on the existing occupied corner band. The trough and one
domestic awning clamp to available generated spans and preserve the real door.
The painted iron lantern replaces the primitive sconce, with its own mounting
and glass/light positions. Both mounted pieces follow the real roof/front fade;
the outdoor tree and its shadow remain. The original worn-sett texture replaces
the generic cobble, using larger world repeat and quiet value compression.
See [asset provenance, exact prompts and anchors](../../assets/world/city_block/STREETSCAPE_ASSET_HANDOFF.md).
Optional assets use resource-aware availability checks as well as a raw-source
fallback, so imported texture remapping is respected. No packed export was built.

## Evidence and review

Review correspondence is in
[the designer review](../art/reviews/2026-10-18-city-block-designer-review.md).
Ground packets 01–06 record surface/profile development; 07 is the first larger
integrated pass and predates the foliage atlas/fade correction. The first moving
run under `ground-moving/small-final` also predates that larger integrated pass:
151 native frames, 61 fires, 62 hits, 29 deaths, real entry/exit and streamed
reload checks pass, with clean native exit, no failures or save writes. Its
source hashes and videos were packaged before subsequent source changes.

The art chat personally inspected the complete final `ground-review-11` small
transition, exterior and cutaway, its normal transition counterpart, and one
current generated L view in `ground-procedural-08`. It cleared the shown combined
streetscape and found no further concrete art correction in those samples.
These are sampled static decisions, not a whole-city or performance signoff.

Focused red/green evidence catches missing road ownership, detached stale
surfaces, interior overlap and the incorrect foliage atlas region. The corrected
procedural sweep passes 4,326 checks across 20 distinct layouts (four seeds ×
horizontal, vertical, cross, L and T streets), 76 parcels, 22 parcel sizes and all
four entrance directions. It includes translated-chunk world alignment, road
clearance, unchanged geometry/identities, deterministic regeneration, sun-shadow
interior exclusion, actual planted contacts and clipped atlas/full-image foliage
UV bounds. The styled subset is 75 rectangular instances across 22 sizes. Kit
checks pass 1,118, including real cover callbacks for mounted art and independent
foliage shade; all 542 gameplay scripts parse.

A square road jump was a real rendered defect, not intended old-city character.
The native technical ownership capture in packet 10 fails the new edge check:
18 pixels between adjacent columns. Replacing floating sine hashing with integer
lattice hashing removes that boundary discontinuity on this Compatibility
renderer. Packet 11 passes with maximum one-pixel adjacent-column change at both
960×540 and 1280×720. The unchanged shared polygon/road data and before/after
ownership pixels are retained; the checker reads existing pixels without editing
images. These checks do not judge general art quality or every camera/seed.

## Scope and limits

This remains a reusable prototype family at the existing S2 example role. The
underlying city topology has not been replaced with an organic road generator:
the unevenness here changes the rendered street surface inside the existing
safe layout. Detailed painted fronts remain south-facing; other orientations and
irregular-footprint art coverage are still incomplete. The calmer growth treatment
is local to this block and immediate margins, rather than a global terrain
replacement. Frozen screenshots, scripted god-mode combat and capped capture
timings do not establish human play comfort or a performance improvement.

The final current-source native run after the resource-availability correction
passes in `ground-moving/small-streetscape-verified`: 150 frames, 61 fires, 61
hits and 28 deaths, physical perimeter traversal, real entry/security/exit,
streamed unload/reload and 12 seconds of populated outside simulation. Native
exit is zero with no diagnostics, failures or save writes. The packager validates
36 current source/asset hashes; walkthrough/fight videos retain measured timing
and both decode without diagnostics. Its earlier interrupted attempt remains
interrupted evidence, not counted as a successful run. The art chat receives
the actual exterior, populated outside frame 83, interior combat frame 56 and
fight-ending still. It cleared these sampled environment states: no new terrain,
foliage or fixture obstruction, with tells/projectiles salient and the interior
floor quiet. The crowded body/effect pileup still makes the player difficult to
isolate in frame 83, an existing crowd/VFX limit rather than a demonstrated new
terrain regression. This is PNG sampling, not MP4 playback, continuous human
play comfort, performance or a full moving Reduced Motion signoff.
