# Buildings — art request (2026-09-27)

Follows `docs/art/2026-09-27-world-look-art.md` (same style block, same
hand-back folder `incoming/world/`). That request covers wall material
(W1/W2), ground dressing (D1-D12), props (P1-P8) and ground (G1/G2); this one
is what makes BUILDINGS read as buildings, per the design notes
(`docs/design/2026-09-27-hub-world-gen-notes.md`: "treat buildings like large
top-down obstacles… roof fades when you enter", "break long walls every 5-8
tiles", "doorway recess, pillar, ruined section, vines").

What code already does: every parcel building has a roof over its footprint,
framed by the walls' lit tops, shaded as a gable (lit north slope, shaded
south slope, ridge highlight, dark eaves), fading out when the player walks
in; interior partitions stay hidden under it. Long straight walls get a
buttress every 6 cells and the odd collapsed section (procedural until W1/W2
arrive). The roofs (R1-R4) are the user's art as of 2026-09-27.

Sizes are on-screen game pixels; one cell is 64 px, the player ~64 px tall.
Generate at 1024 px or more on the long side.

## Priority 1 — roofs (R1-R4 DELIVERED 2026-09-27, installed)

Roofs are drawn as seamless textures stretched over any footprint, so they
must tile in BOTH directions. The code shades the slopes; paint them flat.

| # | File | Aspect | What |
|---|---|---|---|
| R1 | `roof_slate.png` | 1:1 | slate roof, seamless |
| R2 | `roof_clay.png` | 1:1 | clay tile roof, seamless |
| R3 | `roof_lead.png` | 1:1 | flat leaded / stone roof for institutional buildings, seamless |
| R4 | `roof_damage_a..c.png` | 1:1 | holes in a roof, sprite (transparent) |

**R1 — slate roof.** Seamless tileable texture: a slate roof seen from
directly above, rows of overlapping dark blue-grey slates running left to
right, each row's lower edge slightly lit, uneven slate widths, a few chipped
or missing slates, patches of green-grey lichen and moss. Evenly lit, fills
the frame edge to edge, no ridge line, no perspective. One slate row is
about 1/16 of the image tall.

**R2 — clay roof.** Same as R1 but weathered terracotta tiles in muted
brick-red and ochre, a few darker replacement tiles, moss in the gaps.

**R3 — lead/stone roof.** Seamless tileable texture: a flat institutional
roof of large grey lead sheets or stone slabs with raised seams in a grid,
streaks of grime and rust-brown staining, a little moss. Dark and cold.

**R4 — roof damage (3 variants).** Transparent sprite: a jagged hole broken
through a roof, seen from above - broken slate/tile edges around a dark
interior with two or three exposed wooden rafters crossing it, debris on the
rafters. About 90 x 70 on screen. The edge must look like it sits ON a roof
(no ground around it).

## Priority 1 — building details (sprites, transparent)

| # | File | On screen | What |
|---|---|---|---|
| B1 | `bld_chimney.png` | ~40 x 64 | stone chimney stack rising from a roof |
| B2 | `bld_dormer.png` | ~56 x 48 | small dormer window with its own little roof |
| B3 | `bld_door_arch.png` | ~72 x 92 | stone door frame / arch for a gap in a wall |
| B4 | `bld_window_shutters.png` | ~64 x 40 | a window in a wall face with wooden shutters |
| B5 | `bld_ivy_a..b.png` | ~64 x 56 | ivy hanging over a wall top and down its face |
| B6 | `bld_wall_lantern.png` | ~24 x 40 | iron lantern on a bracket, unlit and lit frames |
| B7 | `bld_banner_wall.png` | ~32 x 56 | tattered cloth banner hanging on a wall face |

**B1 — chimney.** A square stone chimney stack seen from above at three
quarters: its lit top with a dark sooty opening, one front face in shade,
a little dark staining down the stone. No roof around it, no smoke.

**B2 — dormer.** A small dormer window that sits on a roof slope: a tiny
gable roof of slate over a dark window with a wooden frame, front facing
the viewer.

**B3 — door arch.** The stone frame of a doorway seen from the front at
three quarters: two squared stone jambs and an arched or flat stone lintel
across the top, the lit top surface of the lintel showing, the opening
itself fully transparent (the ground shows through). It is placed over a
2-cell gap in a wall.

**B4 — shuttered window.** The front face of a stone wall section (dark
stone, like W2) with a small window: dark glass or darkness, a stone sill,
two weathered wooden shutters open to the sides.

**B5 — ivy (2 variants).** Dense dark-green ivy spilling over the top of a
wall and hanging down its front face in strands, transparent around it.

**B6 — wall lantern.** A small iron lantern hanging from a bracket, front
view. Two frames side by side in one image: unlit (dark glass) and lit
(warm amber glass, no glow halo - the game adds light).

**B7 — wall banner.** A narrow, tattered deep-red cloth banner with a faded
gold rune, hanging from an iron rod, front view.

## Priority 2 — interiors

What the player sees when a roof fades. Seamless textures, both directions.

| # | File | What |
|---|---|---|
| F1 | `floor_planks.png` | worn wooden floorboards, dark oak, some broken boards |
| F2 | `floor_tiles_worn.png` | old square stone tiles, cracked, grime in the joints |
| F3 | `floor_institution.png` | a cleaner patterned floor (grey and ochre tiles) for the Segment 1 facility |

## Notes for generating

- R1-R3 and F1-F3: re-roll anything with a visible seam, a vignette, a
  lighting gradient or a single dominant feature (a repeated big crack
  tiles badly).
- B-sprites: one object per image, real alpha, no ground, no shadow.
- Keep the palette muted; the game grades the world and shades roofs itself.
