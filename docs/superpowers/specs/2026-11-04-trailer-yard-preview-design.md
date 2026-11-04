# Trailer yard preview design

The user's overnight authorization is to continue useful work for up to eight
hours or available tokens, commit as work progresses, and prioritize appearance
for the first trailer. Routine choices below are the implementer's, not a new
user-approved aesthetic. Baseline: `d7cfb52f`.

## Intended result

Trial a small irregular patch of existing damp ground at one unused household
yard corner. Preserve the threshold and practical approaches. The current
yard-wide noise/grade cannot express use derived from actual building geometry.
See [the source attribution](../../audits/2026-11-04-trailer-ground-attribution.md).

## Approaches

- Another global material grade is cheap but cannot change an outline.
- Changing terrain/floor stamps would also change ownership, eligibility and
  route contracts; it is inappropriate for this presentation correction.
- A separate presentation mask can use footprint/door geometry without changing
  those contracts. This is the selected bounded trial.

## Bounds and implementation choices

Add a pure GDScript helper returning chunk-local byte weights. It selects at
most one convex, exposed corner per actual household footprint, away from real
door approaches and the declared planted contact. An elliptical, softly
irregular patch outside that corner must meet the footprint's surroundings,
rather than create a uniform ring or full property rectangle. Seed variation
uses integer hashes, never either gameplay RNG. Invalid geometry yields zeros.

The renderer clips weights to semantic urban index 6 and existing zero-care
cells. Footways, lanes, aprons, indoor floors, explicit index-8 courtyards and
formal courts are unaffected. Coverage maps, slots and all light-map channels
remain byte-identical. A separate single-channel wrapped texture carries the
trial and resets with its chunk. Repainting max-composites deterministically.

The wrapped mask has a small data owner, `CityYardSupportMap.gd`, independent
of Game, texture loaders and the renderer. It accepts one already-composited
row-major proposed field plus semantic IDs and care bytes. Replacing a chunk
clears stale bytes before clipping to index 6 / zero care; the caller combines
all household proposals by maximum before replacement. This split lets the
state/reset contract be tested with actual Godot byte arrays and Images without
loading the city. It does not replace the renderer or native acceptance tests.

Use only S7's already available subdued damp-moss material for this first trial.
Do not change scale, grade, actors, pickups or the accepted fractional care
blend at the same time. The new path defaults off, enabled only by
`SA_YARD_SUPPORT_PREVIEW=1` plus an explicit
`SA_YARD_SUPPORT_TARGET=chunk_x,chunk_y,visual_seed`. Native acceptance is required
before considering a production default. Authored S1/Hub retain their existing
presentation.

Keep the production ground shader unchanged. A small preview factory builds a
separate Shader resource from uniquely validated hooks in its original code,
only when requested in S7. Unsupported source disables the preview. Switching
back restores the original resource and all shared parameters. This keeps the
normal GPU program unchanged despite the base shader's documented register
budget. It trades source-hook maintenance in the opt-in prototype for a smaller
normal-mode risk; a general templating framework is not needed.

## Verification and acceptance

Pure-data tests cover useful/nonrectangular support, concave/degenerate
footprints, all four door directions, exclusions, negative chunk coordinates,
determinism, bounded dimensions and untouched inputs/RNG. Renderer tests cover
coverage/light/care/slot equality, idempotence, reset, wrap and policy-off cases.

A minimal isolated data-only Godot project may run under a separate bounded
memory profile because it loads no Game/autoloads/assets. Full project/native
runs retain the existing capture memory gates and one-engine exclusion.

Keeping the visual trial requires matched actual-Game S7 before/after images at
1280x720 and 960x540, a mask inspection view, a real doorway/passage traversal
and streamed reload. Explicit courtyard/road and cared-core controls must stay
unchanged. Pixel evidence, not the helper tests, decides whether it looks good.
No new visual acceptance or trailer readiness is claimed by this design.
