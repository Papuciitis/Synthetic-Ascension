# District-fill court support and care-bed corners

Continuation at the human's request ("check what has been done and what's not
and continue"; then "finish up and commit"). Governing direction:
`2026-10-22-city-continuation.md`, the 2026-10-21 lead review's
ground-hierarchy REWORK ("usable courts", "asymmetric courts around clear
combat routes"), `docs/art/2026-10-20-ground-material-direction.md` and the
LINUX_STATUS next priority: actual-use yard/courtyard support shapes.
Base: production `d7cfb52f`.

- [x] Attribute the broad rectangles in the accepted S9/S7 views with a
  headless map of the real district plans (`tools/dev/CityGroundRoleMapProbe`).
  S9 plan 1445060584: 40 of 91 chunks are district fill, each with a centred
  9-13 cell court stamped as kerbed court setts (index 8, road role); 56 of
  126 care pockets are perfect rectangles. Both reviewed views are district
  fill chunks.
- [x] Capture matched S9/S7 baselines through the accepted
  GroundPavingPreview harness before any runtime change.
- [x] Record each fill court's existing court and passage rects as
  presentation metadata (no RNG, stamp or semantic change); plan per-cell use
  support (`CityCourtSupport`) from passage mouths and doorways into a working
  middle, meandering on a hashed field with a full landing at every entrance;
  carry it in a support map; make every fill court flush (no kerb ring).
- [x] First pass released unused cells in every family and reshaped beds.
  Independent review: S9 accepted; S7 (coarse flags, straight diagonal wipe)
  and the round, wall-shy beds rejected. Narrowed: release per family
  (`DistrictGroundPolicy.court_release`), enabled only for Outer Wall; a moss
  patch release retraced the rectangle and was dropped; beds keep their shape
  and only gain an inner-corner fillet.
- [x] Headless and native checks with RED controls, owner suites, matched
  after captures, GPU cost A/B, theme sheet, re-review, commits, normal
  merge, status.

Next: enable release per family from `tools/dev/CourtReleaseThemeSheet` with
native review; snap release edges to whole stones (needs a per-stone map of
the sett art); wall-aware bed contact and planting. Formal plazas,
objective/arena courts, broad building-lot rectangles, oversized flags and
tiny covered equipment stay open. Static captures are not combat or
performance acceptance.
