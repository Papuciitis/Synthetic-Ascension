# Hub market square — art request (2026-09-27)

The hub (scenes/hub/HubWorld.gd) was rebuilt toward the hub reference
image: a plus-shaped square, round plaza with the Ascension obelisk at the
centre, houses on all four corners, dusk lighting. Everything below is
currently drawn in code by scenes/hub/HubDecor.gd as a stand-in. These
sprites replace those stand-ins.

Hand-back: drop the PNGs in `incoming/hub/`. Claude trims, downscales to
the target size, places them in `assets/textures/hub/`, wires each one in
and re-renders with tools/dev/HubScreenshotProbe.tscn.

## Style block (paste at the top of every prompt)

> Detailed pixel-art game sprite for a top-down 2D action RPG, matching an
> existing set of props (a merchant stall, street lamp, rune obelisk and
> stone gate arch). Camera is top-down three-quarter view: looking down at
> about 45 degrees, so front walls face the viewer and roofs are seen from
> above. Clean pixel art with a near-black outline (#140E0C) around every
> solid shape, 4 to 5 flat shading tones per material, light from the top
> left. Warm, muted medieval palette: weathered stone greys, oak browns,
> clay-red and slate-blue roof tiles, cream plaster, brass and gold
> accents, warm amber (#FFB347) for lit windows and fire. Paint in
> NEUTRAL evening colours, not night: the game adds its own dusk tint and
> lights, so do not darken the image or paint big glow halos. Fully
> transparent background (real alpha, not white, not a checkerboard), the
> object centred with a small margin, nothing else in the frame: no ground,
> no cast shadow, no text, no watermark, no border.

"Front" in the prompts below means the side facing the viewer (the bottom
of the image).

## Priority 1 — the buildings (biggest visual gain)

On-screen sizes are in game pixels. One floor tile is 64 px and the player
is about 64 px tall, so a door should be about 80 px tall on screen.

| # | File | Aspect | On screen | Replaces |
|---|---|---|---|---|
| B1 | `hub_house_timber.png` | 4:3 landscape | ~480 x 360 | north-west house |
| B2 | `hub_house_stone.png` | 4:3 landscape | ~480 x 360 | north-west shop |
| B3 | `hub_forge.png` | 4:3 landscape | ~460 x 360 | north-east forge |
| B4 | `hub_house_wide.png` | 16:9 landscape | ~700 x 400 | north-east house |
| B5 | `hub_house_side.png` | 3:4 portrait | ~380 x 500 | west and east houses |
| B6 | `hub_roofs_back.png` | 3:1 wide | ~1100 x 360 | the south row |

**B1 — timber house.** A two-storey medieval half-timbered house with the
front facing the viewer. Cream plaster between dark oak beams, a stone
plinth along the bottom, a steep clay-red tiled roof that takes up the
upper half of the image, one cross gable rising from the roof over the
right half with a small round window in it, and a stone chimney. The ground
floor has a heavy arched oak door with iron hinges and two small-paned
windows lit amber from inside, each with a wooden flower box of red and
orange flowers. A lantern hangs on a bracket beside the door.

**B2 — stone shop.** A narrow two-storey grey stone townhouse with the
front facing the viewer, a slate-blue tiled roof with a dormer window, and
a shop front on the ground floor: a wide lit window with goods on the sill,
an oak door and a blank wooden hanging sign on an iron bracket. Moss in the
stone joints near the base, and one wooden shutter hanging open.

**B3 — forge.** A blacksmith's workshop with the front facing the viewer.
The ground floor is a wide open arch with a glowing forge hearth inside
(orange and yellow coals, a hint of bellows), and an anvil and a quench
barrel just inside the arch. A dark slate roof, a big brick chimney with a
little grey smoke, and a hanging iron sign shaped like an anvil. Tools
(tongs, hammers) hang on the wall beside the arch. Sooty stone.

**B4 — wide house.** A long three-bay house with the front facing the
viewer. A clay-red roof with TWO cross gables, cream plaster and timber on
the upper floor, stone on the ground floor. Three lit windows, one door
with a small porch roof, a bench and two barrels against the wall, ivy
climbing one corner.

**B5 — side-on house.** A house turned 90 degrees: the roof ridge runs from
the top of the image to the bottom, so you see both roof slopes from above
(the left slope lighter, the right slope darker), and only the gable end
wall is visible at the bottom, facing the viewer, with one small lit window
and no door. The roof is slate-blue tile. The long side walls are hidden
under the eaves. This one sits along the west and east edges of the square,
so it must look fine repeated and flipped horizontally.

**B6 — roofs from behind.** The south edge of the square: a continuous row
of three or four joined rooftops seen from above, the backs of houses whose
fronts face away from the viewer. Mixed clay-red and slate-blue roofs at
slightly different heights, two chimneys and one small dormer. Along the
TOP edge of the image, the roofs end in a straight eave line with a dark
gutter (this edge meets the square). No doors or windows are visible. It
must tile horizontally: the left and right edges should line up.

## Priority 2 — street dressing

| # | File | Aspect | On screen | Replaces |
|---|---|---|---|---|
| T1 | `hub_tree_autumn_a.png` | 3:4 portrait | ~150 x 190 | corner trees |
| T2 | `hub_tree_autumn_b.png` | 2:3 portrait | ~120 x 180 | smaller trees |
| P1 | `hub_banner.png` | 1:2.5 portrait | ~60 x 150 | plaza banners |
| P2 | `hub_brazier_sheet.png` | 3:1 wide, 3 frames | ~70 x 90 per frame | plaza braziers |
| P3 | `hub_stall_alcove.png` | 4:3 landscape | ~180 x 140 | red awning, Quiet Alcove |
| P4 | `hub_stall_gear.png` | 4:3 landscape | ~180 x 140 | teal awning, Gear & Stash |
| P5 | `hub_stall_green.png` | 4:3 landscape | ~180 x 140 | green filler stall |
| P6 | `hub_barrels.png` | 1:1 | ~70 x 70 | loose barrels |
| P7 | `hub_sacks.png` | 1:1 | ~60 x 50 | clutter by the merchant |

**T1 — autumn tree, round.** A deciduous tree seen from above at three
quarters: a short brown trunk at the bottom centre and a big round crown of
orange-gold and amber leaves, built from clusters, with darker undersides
and a few leaves still olive. A few loose leaves at the trunk base.

**T2 — autumn tree, tall.** Like T1 but taller and narrower, with more
olive and ochre in the leaves than orange, and a slightly bare branch
showing at one side.

**P1 — banner.** A black iron pole with a crossbar and a small brass
finial, carrying a deep navy (#1E2A55) cloth banner with a swallowtail
bottom and a gold embroidered rune shaped like a small branching tree (the
same glyph as the glowing lines on the obelisk). The pole stands on a
small square stone foot.

**P2 — brazier, 3 frames.** Three frames side by side, evenly spaced in
equal cells: a squat carved stone plinth holding an iron fire bowl, with
the flames at three moments of a flicker loop (tall, leaning left, leaning
right). The plinth and bowl must be pixel-identical in all three frames;
only the fire changes. Orange and yellow fire with a white-hot core, and a
couple of ember sparks above it.

**P3 — alcove stall.** A small wooden market stall with a sloped RED and
cream striped cloth awning with a scalloped hem, seen from the front. On
the counter are books, rolled scrolls, a candle and a teapot, and a woven
rug hangs off the front. A cosy reading-corner feel.

**P4 — gear stall.** The same build as P3 with a TEAL (#2A5358) awning.
Swords and a shield hang on the back posts, and a leather pack and a
helmet sit on the counter. A small iron-bound chest stands beside it.

**P5 — green stall.** The same build with a dark GREEN awning, selling
produce: baskets of apples, pumpkins and bread.

**P6 — barrels.** Three oak barrels with iron bands, two standing and one
lying on its side in front.

**P7 — sacks.** Two burlap grain sacks slumped against each other, one tied
and one open showing grain.

## Priority 3 — the plaza and station icons

| # | File | Aspect | On screen | Replaces |
|---|---|---|---|---|
| G1 | `hub_plaza.png` | 1:1 | ~680 x 680 | the drawn plaza and dais |
| I1–I5 | `hub_icon_<name>.png` | 1:1 | ~48 x 48 | station ring centres |

**G1 — plaza.** STRAIGHT top-down, not three quarters (this is floor): a
circular paved plaza. The outer part is concentric rings of warm grey
cobbles in courses, bordered by a raised stone curb. The centre is a
two-step round stone dais, each step with a lit top edge and a shadowed
riser, and a thin gold inlaid ring of rune marks on the top step. The
middle of the dais is plain (the obelisk stands there). A few cracks and
tufts of moss, kept subtle. The area outside the circle is fully
transparent.

**I1–I5 — station icons.** Five small round emblem badges in one set: a
dark bronze disc with a gold rim and a light symbol, readable at 48 px.
- `hub_icon_merchant.png`: a coin pouch.
- `hub_icon_ascension.png`: the branching-tree rune.
- `hub_icon_gear.png`: an iron-bound chest.
- `hub_icon_alcove.png`: an open book.
- `hub_icon_exit.png`: an arch with an arrow pointing up.

## Notes for generating

- One object per image; exactly 3 frames for P2.
- Generate larger than the on-screen size (1024 or more on the long side
  is fine). Claude downscales.
- If a building comes out with ground or a street painted under it,
  re-roll: the square's floor is drawn by the game.
- B1–B4 sit side by side along one street, so keep the roof pitch and the
  eave height about the same across them.
