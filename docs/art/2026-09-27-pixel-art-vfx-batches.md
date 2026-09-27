# Pixel-art VFX conversion — batch plan and prompts (2026-09-27)

Goal: every runtime effect reads in the same chunky pixel-art style as the
user's Batch 1 attack VFX (needle, tracer, dart, grenade, mine, rings, spin
glow, impact burst, judgment mark). Decisions taken 2026-09-27:

- Scope: everything, in ordered batches of about ten sprites, one batch at a time.
- Format: one sprite per image on a real transparent background (as Batch 1).
- Prompts: written here from the Batch 1 look; the user generates.
- Bullets: separate player and enemy sprites with colour baked in; the
  runtime team tint is dropped for those two bodies.

## Style block (paste at the top of every prompt)

> Pixel-art game sprite for a top-down 2D action roguelite, matching an
> existing set. Chunky pixel art on a coarse grid: about 64 art pixels across
> for a small effect, about 96 for a large one, rendered large so every art
> pixel is a clean hard square. No anti-aliasing, no smooth gradients, no
> blur, no glow bloom; shading is stepped in 3 to 4 flat tones. Palette:
> white-hot core #FFF8E7, pale gold #F5C56B, deep gold #D89E44, ember orange
> #FF9640, with a near-black outline #120C14 ONLY on solid metal or stone
> bodies; energy, glows and sparks have no outline. Accent with a few tiny
> plus-shaped sparkle motes. Fully transparent background (real alpha, not
> black, not a checkerboard), the sprite centred with a small margin, nothing
> else in the frame: no text, no watermark, no ground shadow, no border.

Aspect: square (1024x1024 or 1254x1254) unless a prompt says "wide"; wide
means about 3:1 landscape (Batch 1 bullets came as 2172x724).

## Processing (Claude, after each batch lands in the repo root)

1. Trim to the alpha bounding box, Lanczos downscale to the target size
   below, verify alpha (no baked background), zero alpha on every edge.
2. Drop in at the target path; the open editor reimports on focus.
3. Apply the code change listed for the sprite, run the projectile battery
   and parse audit, record provenance in `asset-manifest.md`.

## Batch A — bullets, beams, bursts (10 sprites) — LANDED 2026-09-27

As processed: bullets are 72x16 (the quad's 4.5:1 aspect), motes 64x64
and the sigil 96x96 rather than 32/64, because the ~90-art-pixel grid
the generator draws needs the extra texels to keep thin points; the
burst scenes scale them back to the old 18 to 36 px on screen.

| # | File (target size) | Replaces | Code change |
|---|---|---|---|
| A1 | `vfx/ranged/bullet_player.png` (64x16, wide) | bullet_shared for Team.PLAYER | pool family by team, no tint |
| A2 | `vfx/ranged/bullet_enemy.png` (64x16, wide) | bullet_shared for Team.ENEMY | same |
| A3 | `vfx/ranged/beam_core.png` (64x32, wide) | procedural gradient bar | none (stretched along beams) |
| A4 | `vfx/ranged/beam_cap.png` (96x96) | procedural starburst | none |
| A5 | `vfx/motes/mote_hit_spark.png` (32x32) | kenney spark_06 in Burst_HitSpark | texture + scale_amount x16 |
| A6 | `vfx/motes/mote_ember.png` (32x32) | kenney circle_05 in Burst_Death | same |
| A7 | `vfx/motes/mote_star.png` (32x32) | kenney star_07 in Burst_EliteDeath | same |
| A8 | `vfx/motes/mote_sparkle.png` (32x32) | kenney star_04 in Burst_Pickup | same |
| A9 | `vfx/motes/mote_dust.png` (32x32) | kenney smoke_04 in Burst_Dash | same |
| A10 | `vfx/motes/sigil_cast.png` (64x64) | kenney magic_03 in Burst_Cast | texture + scale_amount x8 |

Motes A5 to A9 are drawn many at once and coloured by the scene's colour
ramp, so they must be WHITE and pale grey only, with no outline. The ramp
does the colouring (death goes white to orange to dark red, pickup white to
cyan, dash blue-white).

### Prompts

**A1 bullet_player** (wide)
> [style block] The player's ordinary shot: a compact horizontal energy bolt
> pointing RIGHT. Rounded white-hot head on the right, pale gold body, a
> tail that thins toward the left and ends in three stepped fading blocks
> of deep gold, two tiny plus-shaped sparkle motes trailing behind. Warm
> white and gold only, no outline. About 60 art pixels long and 14 tall.

**A2 bullet_enemy** (wide)
> [style block] A hostile enemy shot: a compact horizontal bolt pointing
> RIGHT, clearly different from a gold player bolt. Blunt crimson-red head
> with a small pale-pink hot spot, dark maroon body, a tail of stepped dark
> red and near-black soot flecks trailing left. Colours: hot spot #FFD6D6,
> red #E23A2E, maroon #7A1A1A, soot #2A1216. No outline. About 56 art pixels
> long and 14 tall.

**A3 beam_core** (wide)
> [style block] A straight horizontal energy beam SEGMENT that fills the
> full width of the image edge to edge, so it can be stretched and tiled
> along a beam of any length: a white-hot centre line, a pale gold band
> either side, then a thin deep gold edge, all with hard stepped edges. It
> must be seamless left to right, with NO end caps, no flare, no sparks,
> identical at the left edge and the right edge. Transparent above and
> below the beam. The beam occupies the middle half of the image height.

**A4 beam_cap**
> [style block] A radial needle-burst end cap for an energy beam: twelve
> thin needles radiating from a white-hot centre, alternating long and
> short, pale gold fading to deep gold at the tips, with three or four
> tiny muted violet #9B7FB8 accent ticks between needles. Perfectly
> centred, symmetrical, no outline, no ring.

**A5 mote_hit_spark**
> [style block] One single sharp spark shard: an elongated four-sided
> diamond, longer than wide, tilted 45 degrees, white-hot core and a
> single pale grey edge step. White and pale grey only, no colour, no
> outline. Fills about 60 percent of the frame.

**A6 mote_ember**
> [style block] One single rounded ember chunk: a slightly irregular blob
> with a bright white centre and two stepped pale grey rings, like a
> glowing coal seen from above. White and pale grey only, no colour, no
> outline. Fills about 55 percent of the frame.

**A7 mote_star**
> [style block] One single four-pointed star spark with long vertical
> points and shorter horizontal points, a white-hot centre and pale grey
> point tips. White and pale grey only, no colour, no outline. Fills about
> 80 percent of the frame.

**A8 mote_sparkle**
> [style block] One single small four-point sparkle with a dot centre and
> stubby equal points, plus one tiny separate plus-shaped mote at the
> upper right. White and pale grey only, no colour, no outline. The main
> sparkle fills about half the frame.

**A9 mote_dust**
> [style block] One single soft dust puff: a lumpy cloud made of three
> overlapping rounded blobs, white core stepping to two pale grey tones at
> the edges. White and pale grey only, no colour, no outline. Fills about
> 70 percent of the frame.

**A10 sigil_cast**
> [style block] A thin circular casting sigil: a single ring with four
> short outward points at top, bottom, left and right, and four tiny dots
> at the diagonals, white core with one pale gold step on the outer edge.
> Centred, symmetrical, no outline, transparent inside the ring. Fills
> about 85 percent of the frame.

## How the rest of the game draws today (sweep of 2026-09-27)

About ninety scripts draw with primitives (`draw_arc`, `draw_line`,
`draw_circle`, polygons, Line2D). Nearly every one paints a wide faint
"glow" stroke under a thin bright "core" stroke and tints by a constant:
augment blue/cyan, enemy magenta/orange, manifestation noun colours
(momentum, cadence, shard, ward, fortune), set colours. The shapes repeat:
ring, dashed ring, soft disc, spoke burst, crescent band, three-ray fan,
jagged bolt, straight streak, chevron, diamond shard, hexagon, corner
bracket, "+" cross, small glyphs. So the conversion is a shared KIT of
white or near-white sprites that the code draws with `draw_texture_rect`
and the existing colour constant as modulate, one draw per shape instead
of the glow+core pair, MIX blending (ADD only for white-hot sparks).

**Stays code-drawn (no sprite, not in any batch):** the huge zone rings
that scale to gameplay radii (Wardstone zones r 220, Exit Rite r 168,
Ritual Interference r 420, the four objectives r 62 to 203, Cursed Vault,
Level 1 milestone), the gauges and progress arcs around the player in the
manifestation logic scripts, text labels, the dash/charge trail ribbon,
the sniper aim beam (it will use beam_core tinted red), and debug chunk
outlines. Those can get a restyle pass with the kit's ring and glyph
sprites after the batches land, if they still look out of place.

## Batch B — the combat kit (10 sprites) — LANDED 2026-09-27

Everything the player sees in an ordinary fight. White unless noted.

| # | File (target size) | Used by |
|---|---|---|
| B1 | `vfx/kit/crescent.png` (128x128) | MeleeSlash (145 deg, steel + teal), Conduit CleaveArc (150 deg), Reflect parry flash (210 deg, drawn twice offset) |
| B2 | `vfx/kit/ring.png` (128x128) | Shockwave, Tesla pulse, Gate unlock, Providence burst, Retaliation nova, Shard launch, Reflect pop, Hex Blink, Regeneration Ring, Bazinga, Seven-Mile, Dignity, Wardstone idle, Vampiric elite mark, Front-shield fallback |
| B3 | `vfx/kit/ring_large.png` (256x256) | the same effects when the radius passes 128 px (Herald 220, Shockwave 220, Sigil burst 190, Tesla 180, Nova 150) |
| B4 | `vfx/kit/ring_dashed.png` (128x128) | MagicImpact, PulseRing, Herald pulse, Bomber hazard ring, Wardstone attune |
| B5 | `vfx/kit/disc.png` (64x64) | the soft fill under MagicImpact, PulseRing, Spider mist, Reflect window, Stamina Core, Oakheart, Sigil glow |
| B6 | `vfx/kit/spokes.png` (96x96) | SpokesBurst hit spark, Reflect pop spokes, Hex Blink spokes, Providence and Nova spokes, Wardstone attune |
| B7 | `vfx/kit/fan.png` (64x64) | Enemy muzzle flash (3 variants by tint), Charger wind-up (scaled 1.6x) |
| B8 | `vfx/kit/claw.png` (128x128) | Spirit Slash (cyan; crit tinted orange at 1.15x) |
| B9 | `vfx/kit/bolt.png` (128x32, wide) | Tesla arc, Conduit ArcLine, Lattice Echo chain, Perfect-parry bolts, Sniper fire flash |
| B10 | `vfx/kit/streak.png` (64x16, wide) | Speed Ring streak, Fast elite streaks, dash trail segments, RangedBullet tail, Spiderling tail |

Code per effect: replace the glow+core primitive pairs with one
`draw_texture_rect` of the kit sprite (rotated for directional ones),
modulate = the script's existing core colour, keep the timing and fade.

### Prompts

**B1 crescent**
> [style block] A single curved slash crescent: a crescent band sweeping
> 150 degrees, open to the left, its convex edge on the right, thick in
> the middle and tapering to points at both ends. A bright white inner
> band with one pale grey step toward the concave edge and a thin lighter
> rim on the convex edge; four tiny spark ticks flying off the convex
> edge. White and pale grey only, no outline. Centred, filling about 90
> percent of the frame.

**B2 ring**
> [style block] A single plain circular ring, perfectly round and centred,
> band about 4 art pixels thick, white with one pale grey step on the
> outer edge, transparent inside and outside. No dashes, no ornaments, no
> outline. Fills about 92 percent of the frame.

**B3 ring_large**
> [style block] The same plain circular ring as a large version: about
> 96 art pixels across, band about 5 art pixels thick, white with one pale
> grey step on the outer edge, transparent inside and outside. No dashes,
> no outline. Fills about 94 percent of the frame.

**B4 ring_dashed**
> [style block] A single circular ring broken into ten equal dashes with
> even gaps, band about 4 art pixels thick, white with one pale grey step
> on the outer edge, transparent inside and outside. Perfectly centred and
> symmetrical, no outline. Fills about 92 percent of the frame.

**B5 disc**
> [style block] A single soft filled disc: a bright white centre stepping
> through two pale grey rings to a translucent outer edge, like a glow
> seen from above but built from hard pixel steps. White and pale grey
> only, no outline. Fills about 85 percent of the frame.

**B6 spokes**
> [style block] A single radial hit spark: fourteen thin spokes radiating
> from a small white centre dot, alternating long and short, tips
> tapering to single pixels, with a tiny ring around the centre. White
> with pale grey tips, no outline. Centred, symmetrical, fills about 90
> percent of the frame.

**B7 fan**
> [style block] A muzzle flash fan pointing RIGHT from the left-centre of
> the frame: three straight rays in a narrow 30 degree fan, the middle ray
> longest, each ray a white core with a pale grey edge, and a small bright
> dot at the origin. White and pale grey only, no outline. The origin
> sits at the left edge, the rays reach the right edge.

**B8 claw**
> [style block] A spirit claw slash pointing RIGHT from the left-centre of
> the frame: five jagged claw strokes fanned over 60 degrees, each stroke
> a slightly kinked line with a bright white core and a pale grey edge,
> plus two shorter straight strokes crossing in an X near the origin.
> Cool white and pale grey only, no outline. Origin at the left edge.

**B9 bolt** (wide, 4:1)
> [style block] A horizontal lightning bolt segment running the full width
> of the image edge to edge: a jagged zigzag line with about eight kinks,
> a white core and a pale grey edge, with one small side branch. It must
> start exactly at the left edge and end exactly at the right edge at the
> same vertical position, so it can be stretched between two points.
> White and pale grey only, no outline.

**B10 streak** (wide, 4:1)
> [style block] A single horizontal speed streak: a straight line thick
> and bright at the right end, thinning to a single pixel and fading in
> three steps toward the left. White and pale grey only, no outline.
> Fills the full width of the image.

## Batch C — telegraphs and auras (10 sprites) — LANDED 2026-09-27

As processed: the crack is a 128x48 strip stretched between two points
(like the bolt) rather than a 64x64 tile; the cone and shield arc keep
their apex / centre of curvature on the left edge; everything else is
centred at the table sizes. Helpers: VfxKit.draw_cone / draw_hexagon /
draw_plates / draw_crack / draw_chevron / draw_shield_arc / draw_ring_wavy
/ draw_ring_hex_wavy / draw_fangs / draw_splash.

| # | File (target size) | Used by |
|---|---|---|
| C1 | `vfx/kit/cone.png` (128x128) | Arcanist cone telegraph (filled wedge + outer arc) |
| C2 | `vfx/kit/hexagon.png` (128x128) | Shielded elite aura, Reliquary Guard hexagon, Red Line guard heptagon (accept hexagon), Officer actor |
| C3 | `vfx/kit/plates.png` (64x64) | Armoured elite: six arc plates around the body |
| C4 | `vfx/kit/crack.png` (64x64) | Splitting elite zig-zag crack, Sunder Tear cracks |
| C5 | `vfx/kit/chevron.png` (32x32) | Fast elite chevrons, Momentum and Red Line back chevrons, Anchor Rite chevrons, Loom arrowhead, Plot Armor "V" |
| C6 | `vfx/kit/shield_arc.png` (64x64) | Enemy front shield (double arc, directional) |
| C7 | `vfx/kit/ring_wavy.png` (128x128) | Reflect Shield window, Stamina Core aura, Oakheart Shield aura |
| C8 | `vfx/kit/ring_hex_wavy.png` (128x128) | Hex mark aura on the player |
| C9 | `vfx/kit/fangs.png` (32x32) | Spider bite (directional) |
| C10 | `vfx/kit/splash.png` (64x64) | Spider explode droplets, Perfect-parry burst accents |

### Prompts (C)

Lesson from A and B: the generator follows "white and pale grey only" and
"origin at the left edge" reliably, and it adds tasteful stray motes on
its own, so the prompts stay short. Directional sprites point RIGHT.

**C1 cone**
> [style block] A filled cone wedge pointing RIGHT from the left-centre
> of the frame: a 36 degree wedge whose apex sits at the left edge and
> whose curved outer edge reaches the right edge, filled with a
> translucent pale grey stepping to a brighter band along the curved
> edge, with a thin white arc on that outer edge. White and pale grey
> only, no outline. The apex touches the left edge.

**C2 hexagon**
> [style block] A single regular hexagon outline with a flat top and
> bottom, band about 4 art pixels thick, white with one pale grey step on
> the outer edge, a faint translucent pale grey fill inside, and a tiny
> white dot at each of the six corners. Centred, symmetrical, no
> outline. Fills about 92 percent of the frame.

**C3 plates**
> [style block] Six separate curved armour plates arranged in a ring
> around an empty centre, each plate a short thick arc segment with a
> bevelled lighter top edge and a pale grey underside, evenly spaced with
> clear gaps between them. White and pale grey only, no outline. The ring
> of plates fills about 90 percent of the frame, the centre is empty.

**C4 crack**
> [style block] A single jagged crack running from the left edge to the
> right edge of the frame: a zig-zag fissure line with six sharp kinks,
> thin at both ends and thickest in the middle, bright white core with a
> pale grey edge and two tiny splinter lines branching off. White and
> pale grey only, no outline. Ends touch the left and right edges at the
> vertical centre.

**C5 chevron**
> [style block] A single bold chevron arrowhead pointing RIGHT, like a
> ">" made of two thick strokes meeting in a sharp point, white with one
> pale grey step on the trailing edges. White and pale grey only, no
> outline. Fills about 85 percent of the frame, point at the right.

**C6 shield_arc**
> [style block] A double shield arc facing RIGHT: two concentric curved
> arcs on the right side of the frame spanning about 160 degrees, the
> outer one thicker and brighter white, the inner one thinner and pale
> grey, both with squared-off ends, plus three tiny white sparkle ticks
> just outside the outer arc. White and pale grey only, no outline. The
> arcs' centre of curvature sits at the left-centre of the frame.

**C7 ring_wavy**
> [style block] A single closed ring whose band ripples gently like a
> heat shimmer, about twelve soft waves around the circle, band about 4
> art pixels thick, white with one pale grey step on the outer edge,
> transparent inside and outside. Centred, no outline. Fills about 92
> percent of the frame.

**C8 ring_hex_wavy**
> [style block] A single closed hexagon-shaped ring with rippled, slightly
> wavy sides and softly rounded corners, band about 4 art pixels thick,
> white with one pale grey step on the outer edge, transparent inside and
> outside, with six tiny white dots orbiting just outside the corners.
> Centred, flat top and bottom, no outline. Fills about 92 percent of the
> frame.

**C9 fangs**
> [style block] A spider bite mark pointing RIGHT: two short curved fangs
> like a pair of parentheses tips converging toward the right, each with
> a bright white tip and pale grey base, and six tiny splash dots
> scattered around them. White and pale grey only, no outline. Fills
> about 70 percent of the frame.

**C10 splash**
> [style block] A radial droplet splash: ten teardrop droplets flying
> outward from an empty centre, points inward, varying lengths, white
> with pale grey tails, plus a few tiny dots between them. White and pale
> grey only, no outline. Centred, fills about 90 percent of the frame,
> centre empty.

## Batch D — bodies and glyphs (11 sprites) — LANDED 2026-09-27 (all 11)

As processed: all eleven arrived (D11 `lattice_mirror` came separately). Sizes were raised for crispness: missile and
shard 48x24, spiderling / bracket / plus / flame / coin / lattice_mark
48x48, triangle and clock 96x96. The spiderling was rotated 45 degrees
at processing so its head points along +X. The clock's hand is baked
pointing up; the Debt Collector's sweeping hand is drawn on top with the
streak sprite.

| # | File (target size) | Used by |
|---|---|---|
| D1 | `vfx/kit/missile.png` (32x16, wide) | Magic Missile body (replaces the polygon triangle; trail uses B10) |
| D2 | `vfx/kit/spiderling.png` (32x32, drawn at 16 px) | Spiderling body (replaces the drawn circles and legs; keep the wiggle by frame swap later) |
| D3 | `vfx/kit/shard.png` (32x16, wide) | Every manifestation diamond shard: Pair Shatter, Slipstream mote, Shard Forge, Shard Launch, shard projectile, Splinter, Exit Rite seals |
| D4 | `vfx/kit/bracket.png` (32x32) | Cartography corner brackets (drawn four times rotated), Death Rattle brackets |
| D5 | `vfx/kit/triangle.png` (64x64) | Predestination sigil (two counter-rotating), Sigil burst |
| D6 | `vfx/kit/plus.png` (32x32) | Regeneration heal "+", Lattice mirrored cross |
| D7 | `vfx/kit/flame.png` (32x32) | Firestone orbiting ember, Tithe embers (with A6) |
| D8 | `vfx/kit/coin.png` (32x32) | Pilgrim's Toll coin glyph |
| D9 | `vfx/kit/clock.png` (64x64) | Debt Collector ring with eight ticks and hand |
| D10 | `vfx/kit/lattice_mark.png` (32x32) | Lattice echo mark (ring + three ticks) |
| D11 | `vfx/kit/lattice_mirror.png` (32x32) | Lattice mirrored mark (diamond + cross) |

### Prompts (D)

**D1 missile** (wide, 2:1)
> [style block] A magic missile body pointing RIGHT: a slim elongated
> arrowhead bolt with a bright white tip, a pale grey shaft, and two
> small swept-back fins at the left end. White and pale grey only, no
> outline. Fills the width of the frame, tip touching the right edge.

**D2 spiderling**
> [style block] A tiny top-down spiderling seen from above, facing RIGHT:
> a rounded abdomen at the left, a smaller thorax, a small head with two
> bright eye dots at the right, and four legs per side spread outward.
> Solid body, so it gets the near-black outline. Body colours: poison
> green #2AB84A with a darker green #0C3A16 underside and a pale green
> #8CFF9C highlight. Fills about 80 percent of the frame.

**D3 shard** (wide, 2:1)
> [style block] A single elongated crystal shard pointing RIGHT: a
> stretched four-sided diamond twice as long as it is wide, bright white
> core with two pale grey facets, a single brighter pixel highlight near
> the tip. White and pale grey only, no outline. Fills the width of the
> frame.

**D4 bracket**
> [style block] A single corner bracket like the top-left corner of a
> targeting frame: two thick strokes meeting at a right angle in the
> upper-left of the frame, each stroke about half the frame long, white
> with one pale grey step on the inner edge. White and pale grey only, no
> outline. The corner sits in the upper-left, strokes run right and down.

**D5 triangle**
> [style block] A single equilateral triangle outline pointing UP, band
> about 4 art pixels thick, white with one pale grey step on the outer
> edge, a tiny white dot at each corner, transparent inside. Centred,
> symmetrical, no outline. Fills about 90 percent of the frame.

**D6 plus**
> [style block] A single bold plus sign: two thick strokes crossing at
> the centre with slightly flared ends, white with one pale grey step on
> the lower-right edges, and a tiny sparkle at the upper-right. White and
> pale grey only, no outline. Fills about 80 percent of the frame.

**D7 flame**
> [style block] A single small flame licking UP: a teardrop tongue of
> fire with a white-hot core, pale gold #F5C56B middle and ember orange
> #FF9640 outer edge, two tiny orange spark dots above it. No outline.
> Fills about 80 percent of the frame.

**D8 coin**
> [style block] A single round coin seen face-on: a pale gold #F5C56B
> disc with a deep gold #D89E44 rim, a white-hot crescent highlight at
> the upper-left, and a simple embossed cross glyph in the centre. Solid
> object, so it gets the near-black outline. Fills about 85 percent of
> the frame.

**D9 clock**
> [style block] A single thin clock face ring with eight short tick marks
> on the inside of the rim at the hour positions, one longer clock hand
> from the centre pointing UP, and a centre dot. Band about 3 art pixels
> thick, white with one pale grey step on the outer edge, transparent
> inside. Centred, no outline. Fills about 92 percent of the frame.

**D10 lattice_mark**
> [style block] A small targeting mark: a thin circular ring with three
> short tick marks radiating outward at the top, lower-left and
> lower-right (120 degrees apart), white with one pale grey step,
> transparent inside. Centred, no outline. Fills about 85 percent of the
> frame.

**D11 lattice_mirror**
> [style block] A small mirrored mark: a thin diamond outline (a square
> rotated 45 degrees) with a small plus sign centred inside it, white with
> one pale grey step, transparent elsewhere. Centred, no outline. Fills
> about 85 percent of the frame.

## Batch E — decide later

Opening-sequence actor shapes (pentagon, calibration cross), the aim
reticle, and a restyle of the zone rings and player gauges with the kit.
Only if they still look out of place once A to D are in.

C and D prompts were written after B landed (2026-09-27); E is written
only if it is ever needed.

## Hand-back

Put each batch in `incoming/batch-<letter>/` at the repo root, one PNG
per sprite named as in the table (for example `incoming/batch-a/
bullet_player.png`). Keep the originals there; the processed files go to
their target paths and the folder is recorded as provenance.
