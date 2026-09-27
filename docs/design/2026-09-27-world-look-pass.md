# World look pass (2026-09-27)

Source: the user's reference render (knights on a weathered flagstone square,
grass and ferns breaking the paving, ruined walls with lit tops and dark
faces, warm top-right light) against an in-game screenshot of segment 2, with
the note that "the 2.5D aspect looks bad, especially on segment 1".
`docs/design/2026-09-27-hub-world-gen-notes.md` is the design conversation behind it.

Follows the non-block city pass (2026-09-27-non-block-city.md): that pass
fixed the SHAPES fed into the grid; this one fixes how the grid is DRAWN.
Gameplay (cells, walkability, keepout, collision, flow field) is untouched.

## What was wrong (measured, not guessed)

`tools/dev/WorldLookProbe.tscn` renders the real run at gameplay zoom.

- **Segment 1 walls were a bug, not a style.** Level1Builder converts every
  wall scene's sprites into 64 px TileMap cells. The Phase 3 "DepthFace"
  child (a 1024x352 brick strip) was converted too, squashed to 64x64 and
  painted over the cap in the same cell - so every wall read as stacked brown
  bricks until the first barrier opened and repainted the caps. Segment 1
  also dropped every wall shadow.
- **Ground = stacked translucent rectangles.** Every road, sidewalk, plaza,
  apron and curb was its own Sprite2D at alpha 0.74-0.94 over the grass;
  overlaps composited into grey see-through bands, and every material edge
  was a hard 64 px staircase. Segment 1 stamps were also darkened to
  brightness 0.36-0.68 and drawn with a 1024 px texture repeat.
- **Walls were flat cartoon masks** with a separate flat brick strip hung
  under them. The batched renderer also drew every texture upside down
  (QuadMesh is Y-up), which swaps N and S pieces - legacy corners and ends
  have been mirrored for as long as the batch path existed.
- **No light.** No CanvasModulate, no lights, no vignette outdoors.

## What changed

- **Ground splat** (`core/systems/world/ground/GroundSplatRenderer.gd` +
  `ground_splat.gdshader`, `ChunkManager.ground_splat_enabled`, default on).
  The same data - base material per chunk, recorded floor stamps in z order,
  Segment 1's authored stamps - is painted with native `Image.fill_rect` into
  three wrapped 256x256 maps (two one-hot coverage maps for 8 material slots,
  one light/stain map). One quad per chunk; the shader takes the slot with
  most bilinear coverage at a noise-warped point, overgrowth wins ties and
  casts a lip shadow on paving. Stamps under alpha 0.5 (mud chips) are
  stains. Two materials draw with a sibling layer (`material_layer`): the
  cobble sidewalk bands use the road's own flagstone pattern in a greyer
  grade, the flat stone tiles use the dark regular brick. Per-material tints
  pull the paving to the reference's warm grey-brown.
  Cost on the dev machine (Intel UHD 620, 1080p): ~+1 ms GPU over the sprite
  floors; CPU and streaming unchanged (audit median 0.375 ms, max 3.1 ms).
  A first per-pixel-resolve version cost +10 ms; see the shader header.
- **Three-quarter wall kit** (`tools/design/build_wall_kit.py` ->
  `assets/world/walls/kit/`, `ChunkBlockVisualCatalog.three_quarter_walls`,
  default on). One baked piece per connection mask: lit top lifted 28 px, a
  dark face under each exposed south edge, thin outline, contact shade;
  corner fills make solid blocks one slab. Walls draw at z -3 (under the
  player), shadows fall down-left. Segment 1 walls now batch through a
  ChunkBlockRenderer of their own (`Level1Builder._rebuild_wall_visuals`,
  rebuilt when a barrier opens); the CoverWall bodies keep collision only.
- **Atmosphere** (`core/systems/world/atmosphere/WorldAtmosphere.gd`,
  `ChunkManager.world_atmosphere_enabled`): one camera-following multiply
  quad on the world canvas - warm grade, vignette centred toward the
  top-right light. The HUD is untouched. Not created headless.
- Parcel roofs (`RoofOverlay`) fade to 0.3 instead of 0.62 and lose their
  dark front line: the wall faces are the façade now.
- Segment 1 floors: brightness halved toward 1 under the splat (opaque now),
  open courtyards and the gate plaza take the warm flagstone.

## Verification

- `tools/tests/WorldGroundSplatTest` (21 checks): base/stamp/z order,
  authored stamps surviving later bases, stains, the wrapped window, slot
  borrowing, no ground/floor sprites from a streamed ChunkManager.
- ChunkBuildDataTest covers both catalogs (legacy + kit); WorldFootprintTest
  checks kit walls carry no separate faces.
- Green: ChunkBlock* (4), ChunkStaged, ChunkStreaming*, WorldFootprint,
  WorldShapeGen, WorldTerrain, WorldIdleRedraw, ProcSeedSweep,
  SegmentProcStartup, Invariants, Level1Determinism, SecondaryObjective,
  VerticalSlice, HubWorld, ChunkStreamingPerformanceAudit.
  PrimaryObjectiveTest's "unsealed rite accepts the player" fails as before.
- Look: `<godot> --path . res://tools/dev/WorldLookProbe.tscn -- --out=<dir>
  --segment=1|2 [--seed=n] [--enemies=n] [--splat=0|1] [--stops=n]` (needs a
  display). Prints mean GPU ms per stop.

## Still open

- Art: `docs/art/2026-09-27-world-look-art.md` - wall top/face strips
  (drop-in for the kit), ground dressing (ferns, grass, moss, fallen blocks,
  rubble) and props in the painterly style, optional flagstone/overgrowth
  ground textures.
- A dressing scatter pass once D1-D12 exist: wall feet, paving joints near
  grass, plaza edges.
- Walls under the player means a player standing just north of a wall draws
  over its face; true occlusion needs per-row sorting.
- The legacy (flag-off) batch path still draws its textures upside down.

## Building pass (same day, follow-up)

The user: "the big buildings look not right" and "the roof tiles should go
over the walls, now it looks like a box with tiles in it". Per the design
notes, buildings are large top-down obstacles with roofs that fade on entry.

- RoofOverlay draws a textured roof (user art R1-R3: slate, clay, lead by
  building kind) over the WHOLE footprint, walls included, out to a 6 px
  eave, lifted to wall-top height and drawn above the walls (z -1, below
  actors); only the south façade's face shows under it, with a soft eave
  shadow. roof.gdshader shades a gable (lit north slope, shaded south, ridge
  highlight, dark eaves) on box-shaped roofs; ~35% of slate/clay roofs carry
  a damage hole (R4). Walking in fades the roof as before.
- Interior partitions of parcel buildings are tagged at spawn
  (ChunkManager.spawn_roofed_wall_cells, VARIANT_UNDER_ROOF) and drawn with
  the props at z -6, so nothing inside shows until the roof fades.
- Long straight walls: a buttress every 6 cells (staggered per row) and a
  collapsed half-height section on ~7% of other straight cells
  (ChunkBlockVisualCatalog.wall_texture_at, pieces baked by
  build_wall_kit.py). Visual only.
- Art still requested: docs/art/2026-09-27-building-art.md (chimneys,
  dormers, door arches, shuttered windows, ivy, wall lanterns, banners,
  interior floors) on top of the world-look request (W1/W2, D1-D12, P1-P8).
