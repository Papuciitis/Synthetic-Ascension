# World look — art request (2026-09-27)

Target: the reference render the user supplied on 2026-09-27 (knights on a
weathered flagstone square, grass and ferns breaking the paving, low ruined
walls with lit tops and dark faces, warm light from the top right). Attach
that image to every prompt as the style reference.

What code already does (no art needed): organic paving/grass edges with a
lip shadow (ground splat shader), three-quarter walls with baked faces and
drop shadows (procedural kit from the old brick band), a warm grade and
vignette. What it cannot fake is below: real wall material, and the small
dressing that makes the reference look lived-in.

Hand-back: drop the PNGs in `incoming/world/`, named as in the tables.
Claude trims, resizes, installs, re-bakes the wall kit with
`tools/design/build_wall_kit.py`, and re-renders with
`tools/dev/WorldLookProbe.tscn`.

## Style block (paste at the top of every prompt)

> Painterly pixel-art game asset for a top-down 2D action RPG, matching the
> attached reference image. Camera looks down steeply (about 70 degrees), so
> tops of things are seen from above and only a thin front face shows. Warm
> light from the top right, soft shadows falling to the bottom left. Muted,
> weathered palette: grey-brown and sandy stone, dark olive greens with
> yellow-green highlights, near-black (#141010) for the darkest shadows. Fine
> detail, crisp edges, no blur, no text, no watermark, no border.

For sprites add: "Fully transparent background (real alpha, not white, not a
checkerboard), one object centred with a small margin, no ground under it, no
cast shadow (the game draws shadows)."

For textures add: "Seamless tileable texture: the left edge continues into the
right edge and the top into the bottom with no visible seam. Even lighting
across the whole image, no vignette, no single dominant feature."

Sizes are on-screen game pixels. One floor cell is 64 px; the player is
about 64 px tall. Generate at 1024 px or more on the long side; Claude
downscales.

## Priority 1 — the wall material (replaces the procedural kit sources)

The walls are built from two strips; every connection piece is composed from
them, so these two images restyle every wall in the game.

| # | File | Aspect | Maps to | Notes |
|---|---|---|---|---|
| W1 | `wall_top_strip.png` | 4:1 | the lit top of every wall, 32 px deep | seamless left-right |
| W2 | `wall_face_strip.png` | 8:1 | the front face, 28 px tall | seamless left-right |

**W1 — wall top.** Seamless tileable strip (tile left-right only): the flat
top of an old stone wall seen from directly above, running left to right.
Two rows of weathered sandy-tan stone blocks of uneven length with dark
mortar joints, a few chipped corners, a little moss and grit in the joints.
Evenly lit (the game adds light), fills the whole image edge to edge.

**W2 — wall face.** Seamless tileable strip (tile left-right only): the
vertical front face of the same wall seen straight on, in shade. Two or
three courses of large dark grey-brown stone blocks, a slightly lighter
worn top course, a damp darker band with moss along the bottom edge.
Fills the whole image edge to edge.

## Priority 1 — ground dressing (the reference's richness)

Scattered by code along wall feet, paving joints and grass edges. One object
per image.

| # | File | On screen | What |
|---|---|---|---|
| D1–D3 | `dress_fern_a..c.png` | ~48 x 48 | fern / weed tufts |
| D4–D5 | `dress_grass_a..b.png` | ~40 x 32 | low grass clumps |
| D6 | `dress_moss_patch.png` | ~64 x 48 | flat moss creeping over stone |
| D7–D9 | `dress_block_a..c.png` | ~40 x 40 | fallen stone blocks |
| D10–D11 | `dress_rubble_a..b.png` | ~56 x 40 | rubble piles |
| D12 | `dress_wall_chunk.png` | ~96 x 64 | a broken wall section lying on its side |

**D1–D3 — fern tufts.** A small clump of fern and weed leaves growing out of
a crack, seen from above: bright olive and yellow-green fronds radiating from
a dark centre. Three different shapes (a round clump, a lopsided spray, a
thin two-frond sprout).

**D4–D5 — grass clumps.** A low tuft of wild grass seen from above, dark
green at the base, yellow-green tips. Two shapes.

**D6 — moss patch.** A flat, irregular patch of dark green moss with a soft
ragged edge, meant to lie over paving. Mostly flat colour, fine texture.

**D7–D9 — fallen blocks.** A single squared stone block (like the wall's
stones) lying loose, seen from above with its top lit and one dark side face
showing at the bottom. One whole block, one cracked in two, one tilted with a
chipped corner.

**D10–D11 — rubble piles.** A small heap of broken stone chunks and grit,
grey-brown, a couple of larger pieces on top.

**D12 — wall chunk.** A short piece of collapsed stone wall lying on the
ground: the same sandy block top and dark face as W1/W2, broken ends.

## Priority 2 — props in the new style (replace the cartoon set)

The current crates, tables, rubble, pillar and statue have thick cartoon
outlines and read as stickers on the painted ground. Same style block, three
quarter view, each object alone.

| # | File | On screen | Replaces |
|---|---|---|---|
| P1 | `prop_crate.png` | ~48 x 52 | prop_crate_01 |
| P2 | `prop_crate_broken.png` | ~52 x 48 | prop_crate_rot_01 |
| P3 | `prop_barrels.png` | ~56 x 56 | (new, two iron-banded barrels) |
| P4 | `prop_pillar_broken.png` | ~40 x 72 | prop_broken_pillar_01 |
| P5 | `prop_statue.png` | ~48 x 80 | prop_statue_01 |
| P6 | `prop_table.png` | ~72 x 48 | prop_table_long_01 |
| P7 | `prop_cart.png` | ~88 x 56 | (new, a broken hand cart) |
| P8 | `prop_brazier.png` | ~40 x 48 | (new, cold iron brazier on a stone foot) |

## Priority 3 — ground textures (optional polish)

The current paving (the Cethiel civic brick, graded warm grey-brown in the
shader) and grass are serviceable. If you want the reference's exact ground:

| # | File | Aspect | What |
|---|---|---|---|
| G1 | `ground_flagstone.png` | 1:1 | large irregular rectangular flagstones, warm grey-brown, dark joints with moss and a few weeds; stones about 1/5 of the image wide |
| G2 | `ground_overgrowth.png` | 1:1 | dense low leafy ground cover, dark olive with yellow-green highlights and a few dark earth gaps |

Both seamless in both directions.

## Notes for generating

- Walls: if W1/W2 come out with a perspective slant or a lit edge on one
  side only, re-roll; they must tile left-right.
- Dressing: keep each object small in its frame and fully cut out; soft
  semi-transparent edges are fine (leaves), halos are not.
- Keep the palette muted; the game grades the world warm and darkens the
  screen edges itself.
