# Non-block city pass (2026-09-27)

Source: the user's notes in `docs/design/2026-09-27-hub-world-gen-notes.md` (a design
conversation about why the districts read as "blocks on blocks") and the
generated reference image of a stone plaza with ruined walls and grass
bleeding over paving. The diagnosis there matches the code: every road,
plaza, lot and floor stamp was a `Rect2i` on the 64 px grid, and the
visible world traced the generator exactly.

The rule adopted: **geometry defines navigation; art hides the geometry.**
Gameplay stays on `Vector2i` cells (keepout, walkability, wall spawning,
collision, flow field). Only the shapes fed into that grid changed.

## What changed

- `core/systems/world/proc/chunkgen/ChunkShapeGen.gd` (new, pure static):
  cell masks (`rect_cells`, `add/subtract_rect`, `grow`, `bounds_of`),
  `rasterize_polygon` / `rasterize_polyline` by cell centre,
  `boundary_from_fill` / `outline_of_fill`, `largest_inscribed_rect`,
  `cells_to_rects` (row-run packing so masks still ride the batched floor
  stamp path), `build_road_path` (one sideways bend, endpoints fixed),
  `generate_building_footprint` (corner notch 75%, side indent 35%,
  connected, half the area kept), `plaza_polygon` (worn octagon,
  chamfered slab, lopsided blob).
- Generic buildings (`ChunkGenStructures._spawn_building`): the footprint
  is a notched mass; walls are its boundary, the floor its inside; the door
  is a run of boundary cells on the rolled side that faces open ground; the
  apron and the Donjon micro-carve fit the largest open rectangle.
- District roads (`ChunkGenDistrict._generate_district`): the straight
  lane rects remain the street CONTRACT (keepout, parcel bands, Donjon
  regions, spawn sockets) but the visible road is a polyline from each
  connector socket to a jittered hub, rasterised at half the lane width;
  its row-run rects are keepout too. The sidewalk is the wider band around
  it; the crossing gets a stone hub pad; edge mud chips sit on the road's
  outline.
- Plazas: polygon families by role (gate / arena / checkpoint = chamfered
  slab, landmark / entry = worn octagon, others = blob), stamped as masks;
  the curb lip follows the outline; islands must sit inside the paving; the
  perimeter ring walks the outline as a 4-connected path in long broken
  segments (with the L-step cells diagonal edges need), thick for arenas
  and gates, with the old breach rule.
- Knobs on ChunkManager: `organic_shapes_enabled` (default on; off is the
  old rectangle generator, bit-for-bit) and `organic_road_bend_cells`
  (2.5). Mirrored on ChunkGenImpl.

## Verification

- `tools/tests/WorldShapeGenTest` (22 checks) pins the module.
- `tools/dev/DistrictShapeProbe.tscn` renders a hand-authored 5x3 district
  to a PNG cell map: `--out=<dir> --organic=1|0 --seed=<n>`. Compare the
  two modes for the same seed; the organic map must keep every seam
  connection at the lane centres.
- The existing world suites (footprint, seed sweep, tile integration,
  block integration / data / physics / renderer, staged blockers, flow
  field, objectives, invariants, streaming performance audit) stay green.

- Hub courtyard (`scenes/hub/HubWorld.gd`): `COURTYARD_POLYGON` (a wide
  middle band narrowing toward both gates) plus the two bays, rasterised
  with the same module; walls are the outline, so every floor cell is
  walkable; the loop is an inset of the outline. `courtyard_cells()` and
  `courtyard_walls()` are static so the probe and tests share them.
  `tools/dev/HubShapeProbe.tscn -- --out=<dir>` renders it.

## Still open (later passes, in the notes' order)

- Setbacks / negative space as explicit lots (alley, courtyard, shrine
  nook) instead of leftovers; staggered façades along parcels.
- Visual edge tiles that lie about the grid (grass over stone, chipped
  corners), wall caps / faces / shadows, and the modular wall kit. These
  are art passes; the geometry now gives them irregular ingredients.
