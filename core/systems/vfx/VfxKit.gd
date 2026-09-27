class_name VfxKit
extends RefCounted
## The pixel-art VFX kit (Batch B, 2026-09-27): white / pale-grey sprites in
## assets/textures/vfx/kit/, drawn TINTED by each effect's own colour through
## draw_texture_rect. One draw per shape replaces the old glow+core primitive
## pairs, with MIX blending (the art carries its own light; additive washed it
## out on pale ground). Every helper falls back to the primitive it replaced
## when its sprite is missing (a headless run without imports, or a removed
## file), so nothing depends on the art being present.
##
## Helpers that rotate (fan, claw, crescent, bolt, streak, and the dashed
## ring / spokes when given a spin) use draw_set_transform and reset it to
## IDENTITY afterwards, so call those with no custom transform pending.
## draw_ring and draw_disc never touch the transform, by construction: the
## item effects that draw in world space under draw_set_transform_matrix
## (Bazinga, Seven-Mile Boots, Dignity) depend on that, so keep it so.
## Content extents below were measured when the batch was processed
## (docs/art/2026-09-27-pixel-art-vfx-batches.md).

const DIR := "res://assets/textures/vfx/kit/"

const RING_HALF := 62.0             # ring.png (128): outer edge radius, texels
const RING_LARGE_HALF := 121.5      # ring_large.png (256)
const RING_LARGE_FROM := 80.0       # world radius above which the large ring is used
const RING_DASHED_HALF := 56.5      # ring_dashed.png (128)
const DISC_HALF := 30.0             # disc.png (64): visible glow radius
const SPOKES_HALF := 44.5           # spokes.png (96): longest spoke
const FAN_LENGTH := 62.0            # fan.png (64): origin at x=0, rays reach x=62
const FAN_SPREAD_DEG := 30.0        # the fan's native spread
const CLAW_LENGTH := 125.0          # claw.png (128): origin at x=1
const CLAW_CENTER_Y := 61.5
const CRESCENT_RIGHT := 115.0       # crescent.png (128): convex edge at x=115
const CRESCENT_CENTER_Y := 63.5     # vertical centre of the crescent content
const CRESCENT_HEIGHT := 117.0      # tip-to-tip height of the crescent content
const BOLT_CONTENT_H := 19.0        # bolt.png (128x32): zig-zag amplitude band
const STREAK_CONTENT_H := 8.0       # streak.png (64x16): bright end at the RIGHT

# ---- Batch C (2026-09-27): telegraphs and auras -------------------------
const CONE_LENGTH := 125.0            # cone.png (128): apex at x=0, curved edge at x=125
const CONE_HALF_DEG := 23.4        # the cone's native half-angle
const CONE_CENTER_Y := 66.5
const HEX_HALF := 56.5               # hexagon.png (128): corner radius (pointy top)
const PLATES_HALF := 27.0            # plates.png (64): outer radius of the plate ring
const CRACK_CONTENT_H := 17.0          # crack.png (128x48): kink band height
const CHEVRON_W := 25.0               # chevron.png (32): tip-to-tail length along +X
const SHIELD_HEIGHT := 55.0           # shield_arc.png (64): tip-to-tip height of the outer arc
const SHIELD_APEX_X := 48.0           # x of the outer arc's apex on the middle row
const SHIELD_CENTER_Y := 35.0
const RING_WAVY_HALF := 60.0          # ring_wavy.png (128)
const RING_HEX_WAVY_HALF := 57.5      # ring_hex_wavy.png (128)
const FANGS_W := 17.0                # fangs.png (32): bite width along +X
const SPLASH_HALF := 29.0             # splash.png (64): droplet reach

# ---- Batch D (2026-09-27): bodies and glyphs ------------------------------
const MISSILE_LENGTH := 40.0          # missile.png (48x24): tip at the RIGHT
const MISSILE_CENTER := Vector2(24.5, 13.0)
const SPIDERLING_W := 35.0           # spiderling.png (48): head along +X
const SPIDERLING_CENTER := Vector2(24.0, 24.0)
const SHARD_LENGTH := 41.0            # shard.png (48x24): tip at the RIGHT
const SHARD_CENTER := Vector2(24.0, 13.0)
const BRACKET_CORNER := Vector2(7.0, 6.0)   # bracket.png (48): corner texel, strokes run +X and +Y
const BRACKET_ARM := 36.0             # arm length in texels
const TRIANGLE_HALF := 34.0          # triangle.png (96): half height (apex up)
const TRIANGLE_CENTER := Vector2(47.5, 51.5)
const PLUS_W := 44.0                 # plus.png (48)
const PLUS_CENTER := Vector2(22.5, 23.0)
const FLAME_H := 32.0                # flame.png (48): licks UP (-Y)
const FLAME_CENTER := Vector2(23.0, 23.5)
const COIN_W := 31.0                 # coin.png (48)
const COIN_CENTER := Vector2(22.0, 23.0)
const CLOCK_HALF := 35.5             # clock.png (96): face radius, hand baked pointing UP
const CLOCK_CENTER := Vector2(46.0, 45.5)
const LATTICE_MARK_HALF := 12.5      # lattice_mark.png (48): tick reach
const LATTICE_MARK_CENTER := Vector2(22.0, 23.0)
const LATTICE_MIRROR_HALF := 22.0    # lattice_mirror.png (48): diamond half-diagonal
const LATTICE_MIRROR_CENTER := Vector2(23.5, 23.5)

static var _cache: Dictionary = {}


static func texture(sprite: String) -> Texture2D:
	if _cache.has(sprite):
		return _cache[sprite]
	var path := DIR + sprite + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[sprite] = tex
	return tex


static func has(sprite: String) -> bool:
	return texture(sprite) != null


## A full ring whose OUTER edge sits at `radius` (world px).
static func draw_ring(ci: CanvasItem, at: Vector2, radius: float, color: Color, fallback_width: float = 3.0) -> void:
	var large := radius > RING_LARGE_FROM
	var tex := texture("ring_large" if large else "ring")
	if tex == null:
		ci.draw_arc(at, radius, 0.0, TAU, 48, color, fallback_width, true)
		return
	_draw_centered(ci, tex, at, radius / (RING_LARGE_HALF if large else RING_HALF), 0.0, color)


## A ring of ten dashes, outer edge at `radius`; `spin` rotates the dashes.
static func draw_ring_dashed(ci: CanvasItem, at: Vector2, radius: float, color: Color, spin: float = 0.0, fallback_width: float = 3.0) -> void:
	var tex := texture("ring_dashed")
	if tex == null:
		var dash := TAU / 10.0
		for i in range(10):
			ci.draw_arc(at, radius, spin + i * dash, spin + (i + 0.62) * dash, 8, color, fallback_width, true)
		return
	_draw_centered(ci, tex, at, radius / RING_DASHED_HALF, spin, color)


## A soft filled disc of the given radius (a glow or a fill under a ring).
static func draw_disc(ci: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	var tex := texture("disc")
	if tex == null:
		ci.draw_circle(at, radius, color)
		return
	_draw_centered(ci, tex, at, radius / DISC_HALF, 0.0, color)


## Fourteen radiating spokes reaching `radius`; `spin` rotates the burst.
static func draw_spokes(ci: CanvasItem, at: Vector2, radius: float, color: Color, spin: float = 0.0) -> void:
	var tex := texture("spokes")
	if tex == null:
		for i in range(14):
			var a := spin + TAU * float(i) / 14.0
			var d := Vector2(cos(a), sin(a))
			ci.draw_line(at + d * radius * 0.12, at + d * radius * (0.7 if i % 2 == 1 else 1.0), color, 3.0, true)
		return
	_draw_centered(ci, tex, at, radius / SPOKES_HALF, spin, color)


## A three-ray flash fan with its ORIGIN at `at`, pointing along `facing`,
## `length` px long; `spread_deg` squeezes or widens the native 30 degrees.
static func draw_fan(ci: CanvasItem, at: Vector2, facing: float, length: float, color: Color, spread_deg: float = FAN_SPREAD_DEG) -> void:
	var tex := texture("fan")
	if tex == null:
		var half := deg_to_rad(spread_deg) * 0.5
		for a in [-half, 0.0, half]:
			ci.draw_line(at, at + Vector2.RIGHT.rotated(facing + a) * length, color, 2.6, true)
		return
	var s := length / FAN_LENGTH
	var sy := s * maxf(0.3, spread_deg / FAN_SPREAD_DEG)
	var size := tex.get_size()
	ci.draw_set_transform(at, facing, Vector2(s, sy))
	ci.draw_texture_rect(tex, Rect2(Vector2(0.0, -size.y * 0.5), size), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The five-stroke spirit claw, origin at `at`, `length` px along `facing`.
static func draw_claw(ci: CanvasItem, at: Vector2, facing: float, length: float, color: Color) -> void:
	var tex := texture("claw")
	if tex == null:
		for i in range(5):
			var a := facing + lerpf(-0.5, 0.5, float(i) / 4.0)
			ci.draw_line(at, at + Vector2.RIGHT.rotated(a) * length, color, 3.0, true)
		return
	var s := length / CLAW_LENGTH
	var size := tex.get_size()
	ci.draw_set_transform(at, facing, Vector2(s, s))
	ci.draw_texture_rect(tex, Rect2(Vector2(-1.0, -CLAW_CENTER_Y), size), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A slash crescent around `at`, convex edge at `radius` along `facing`,
## tips spanning +-`half_angle` (radians) like the hitbox it illustrates.
static func draw_crescent(ci: CanvasItem, at: Vector2, facing: float, radius: float, half_angle: float, color: Color, fallback_width: float = 4.0) -> void:
	var tex := texture("crescent")
	if tex == null:
		ci.draw_arc(at, radius, facing - half_angle, facing + half_angle, 24, color, fallback_width, true)
		return
	# Tip-to-tip height matches the arc's chord; the convex edge lands on the radius.
	var s := maxf(2.0 * radius * sin(clampf(half_angle, 0.2, PI * 0.5)), radius * 0.6) / CRESCENT_HEIGHT
	var size := tex.get_size()
	ci.draw_set_transform(at, facing, Vector2(s, s))
	ci.draw_texture_rect(tex, Rect2(Vector2(radius / s - CRESCENT_RIGHT, -CRESCENT_CENTER_Y), size), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A lightning bolt stretched from `from` to `to`; `width` is the old glow
## width and sets the zig-zag band height. `flip` mirrors it for flicker.
static func draw_bolt(ci: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color, flip: bool = false) -> void:
	var tex := texture("bolt")
	var delta := to - from
	var dist := delta.length()
	if tex == null or dist < 0.5:
		ci.draw_line(from, to, color, maxf(2.0, width * 0.3), true)
		return
	var size := tex.get_size()
	var sx := dist / size.x
	var sy := maxf(width * 2.4, 8.0) / BOLT_CONTENT_H * (-1.0 if flip else 1.0)
	ci.draw_set_transform(from, delta.angle(), Vector2(sx, sy))
	ci.draw_texture_rect(tex, Rect2(Vector2(0.0, -size.y * 0.5), size), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A speed streak from the faint tail `from` to the bright head `to`.
static func draw_streak(ci: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var tex := texture("streak")
	var delta := to - from
	var dist := delta.length()
	if tex == null or dist < 0.5:
		ci.draw_line(from, to, color, maxf(1.5, width), true)
		return
	var size := tex.get_size()
	ci.draw_set_transform(from, delta.angle(), Vector2(dist / size.x, maxf(width, 1.5) / STREAK_CONTENT_H))
	ci.draw_texture_rect(tex, Rect2(Vector2(0.0, -size.y * 0.5), size), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_centered(ci: CanvasItem, tex: Texture2D, at: Vector2, scale: float, spin: float, color: Color) -> void:
	var size := tex.get_size() * scale
	if is_zero_approx(spin):
		ci.draw_texture_rect(tex, Rect2(at - size * 0.5, size), false, color)
		return
	ci.draw_set_transform(at, spin, Vector2.ONE)
	ci.draw_texture_rect(tex, Rect2(-size * 0.5, size), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---- Batch C helpers ------------------------------------------------------

## A filled telegraph cone with its APEX at `at`, `length` px along `facing`,
## squeezed or widened to `half_angle_deg` from the sprite's native spread.
static func draw_cone(ci: CanvasItem, at: Vector2, facing: float, length: float, color: Color, half_angle_deg: float = CONE_HALF_DEG) -> void:
	var tex := texture("cone")
	if tex == null:
		var half := deg_to_rad(half_angle_deg)
		var pts := PackedVector2Array([at])
		for i in range(9):
			pts.append(at + Vector2.RIGHT.rotated(facing - half + 2.0 * half * float(i) / 8.0) * length)
		ci.draw_colored_polygon(pts, color)
		return
	var s := length / CONE_LENGTH
	var sy := s * tan(deg_to_rad(clampf(half_angle_deg, 3.0, 80.0))) / tan(deg_to_rad(CONE_HALF_DEG))
	var size := tex.get_size()
	ci.draw_set_transform(at, facing, Vector2(s, sy))
	ci.draw_texture_rect(tex, Rect2(Vector2(0.0, -CONE_CENTER_Y), size), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A hexagon outline (faint fill baked in) with corner radius `radius`.
static func draw_hexagon(ci: CanvasItem, at: Vector2, radius: float, color: Color, spin: float = 0.0, fallback_width: float = 3.0) -> void:
	var tex := texture("hexagon")
	if tex == null:
		var pts := PackedVector2Array()
		for i in range(7):
			pts.append(at + Vector2.RIGHT.rotated(spin - PI * 0.5 + TAU * float(i % 6) / 6.0) * radius)
		ci.draw_polyline(pts, color, fallback_width, true)
		return
	_draw_centered(ci, tex, at, radius / HEX_HALF, spin, color)


## Six armour plates around `at`, outer edge at `radius`.
static func draw_plates(ci: CanvasItem, at: Vector2, radius: float, color: Color, spin: float = 0.0, fallback_width: float = 3.0) -> void:
	var tex := texture("plates")
	if tex == null:
		for i in range(6):
			var a := spin + TAU * float(i) / 6.0
			ci.draw_arc(at, radius, a + 0.12, a + TAU / 6.0 - 0.12, 6, color, fallback_width, true)
		return
	_draw_centered(ci, tex, at, radius / PLATES_HALF, spin, color)


## A jagged crack stretched from `from` to `to`; `width` sets the kink band.
static func draw_crack(ci: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color, flip: bool = false) -> void:
	var tex := texture("crack")
	var delta := to - from
	var dist := delta.length()
	if tex == null or dist < 0.5:
		ci.draw_line(from, to, color, maxf(2.0, width * 0.3), true)
		return
	var size := tex.get_size()
	var sy := maxf(width * 1.6, 6.0) / CRACK_CONTENT_H * (-1.0 if flip else 1.0)
	ci.draw_set_transform(from, delta.angle(), Vector2(dist / size.x, sy))
	ci.draw_texture_rect(tex, Rect2(Vector2(0.0, -size.y * 0.5), size), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A chevron arrowhead centred on `at`, `size` px long, pointing along `facing`.
static func draw_chevron(ci: CanvasItem, at: Vector2, facing: float, size: float, color: Color, fallback_width: float = 2.5) -> void:
	var tex := texture("chevron")
	if tex == null:
		var tip := at + Vector2.RIGHT.rotated(facing) * size * 0.5
		var back := -Vector2.RIGHT.rotated(facing) * size
		var side := Vector2.RIGHT.rotated(facing + PI * 0.5) * size * 0.7
		ci.draw_line(tip, tip + back + side, color, fallback_width, true)
		ci.draw_line(tip, tip + back - side, color, fallback_width, true)
		return
	_draw_centered(ci, tex, at, size / CHEVRON_W, facing, color)


## A double shield arc facing `facing` with its outer apex at `radius` from
## `at`, tips spanning +-`half_angle` (radians).
static func draw_shield_arc(ci: CanvasItem, at: Vector2, facing: float, radius: float, half_angle: float, color: Color, fallback_width: float = 3.0) -> void:
	var tex := texture("shield_arc")
	if tex == null:
		ci.draw_arc(at, radius, facing - half_angle, facing + half_angle, 24, color, fallback_width, true)
		ci.draw_arc(at, radius * 0.83, facing - half_angle, facing + half_angle, 24, Color(color.r, color.g, color.b, color.a * 0.7), fallback_width * 0.7, true)
		return
	var s := maxf(2.0 * radius * sin(clampf(half_angle, 0.2, PI * 0.5)), radius * 0.6) / SHIELD_HEIGHT
	var size := tex.get_size()
	ci.draw_set_transform(at, facing, Vector2(s, s))
	ci.draw_texture_rect(tex, Rect2(Vector2(radius / s - SHIELD_APEX_X, -SHIELD_CENTER_Y), size), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A rippling aura ring, outer edge at `radius`.
static func draw_ring_wavy(ci: CanvasItem, at: Vector2, radius: float, color: Color, spin: float = 0.0, fallback_width: float = 3.0) -> void:
	var tex := texture("ring_wavy")
	if tex == null:
		ci.draw_arc(at, radius, 0.0, TAU, 48, color, fallback_width, true)
		return
	_draw_centered(ci, tex, at, radius / RING_WAVY_HALF, spin, color)


## The hex-shaped rippling mark ring, corner radius `radius`.
static func draw_ring_hex_wavy(ci: CanvasItem, at: Vector2, radius: float, color: Color, spin: float = 0.0, fallback_width: float = 3.0) -> void:
	var tex := texture("ring_hex_wavy")
	if tex == null:
		draw_hexagon(ci, at, radius, color, spin, fallback_width)
		return
	_draw_centered(ci, tex, at, radius / RING_HEX_WAVY_HALF, spin, color)


## A spider bite mark centred on `at`, `size` px across, pointing along `facing`.
static func draw_fangs(ci: CanvasItem, at: Vector2, facing: float, size: float, color: Color, fallback_width: float = 2.0) -> void:
	var tex := texture("fangs")
	if tex == null:
		var fwd := Vector2.RIGHT.rotated(facing)
		var side := Vector2.RIGHT.rotated(facing + PI * 0.5)
		ci.draw_line(at - fwd * size * 0.5 + side * size * 0.3, at + fwd * size * 0.5, color, fallback_width, true)
		ci.draw_line(at - fwd * size * 0.5 - side * size * 0.3, at + fwd * size * 0.5, color, fallback_width, true)
		return
	_draw_centered(ci, tex, at, size / FANGS_W, facing, color)


## A radial droplet splash around `at`, droplets reaching `radius`.
static func draw_splash(ci: CanvasItem, at: Vector2, radius: float, color: Color, spin: float = 0.0, fallback_width: float = 2.0) -> void:
	var tex := texture("splash")
	if tex == null:
		for i in range(10):
			var d := Vector2.RIGHT.rotated(spin + TAU * float(i) / 10.0)
			ci.draw_line(at + d * radius * 0.35, at + d * radius, color, fallback_width, true)
		return
	_draw_centered(ci, tex, at, radius / SPLASH_HALF, spin, color)


# ---- Batch D helpers ------------------------------------------------------

## Draws `tex` so that its content centre `center` (texels) lands on `at`,
## scaled by `scale` and rotated by `rot`.
static func _draw_anchored(ci: CanvasItem, tex: Texture2D, at: Vector2, center: Vector2, scale: float, rot: float, color: Color) -> void:
	var size := tex.get_size()
	ci.draw_set_transform(at, rot, Vector2(scale, scale))
	ci.draw_texture_rect(tex, Rect2(-center, size), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A magic missile body centred on `at`, `length` px long, tip along `facing`.
static func draw_missile(ci: CanvasItem, at: Vector2, facing: float, length: float, color: Color) -> void:
	var tex := texture("missile")
	if tex == null:
		var fwd := Vector2.RIGHT.rotated(facing) * length * 0.5
		var side := Vector2.RIGHT.rotated(facing + PI * 0.5) * length * 0.2
		ci.draw_colored_polygon(PackedVector2Array([at + fwd, at - fwd + side, at - fwd - side]), color)
		return
	_draw_anchored(ci, tex, at, MISSILE_CENTER, length / MISSILE_LENGTH, facing, color)


## A top-down spiderling body centred on `at`, `size` px long, head along `facing`.
static func draw_spiderling(ci: CanvasItem, at: Vector2, facing: float, size: float, color: Color) -> void:
	var tex := texture("spiderling")
	if tex == null:
		ci.draw_circle(at, size * 0.28, color)
		ci.draw_circle(at + Vector2.RIGHT.rotated(facing) * size * 0.3, size * 0.16, color)
		return
	_draw_anchored(ci, tex, at, SPIDERLING_CENTER, size / SPIDERLING_W, facing, color)


## A crystal shard centred on `at`, `length` px long, tip along `facing`.
static func draw_shard(ci: CanvasItem, at: Vector2, facing: float, length: float, color: Color) -> void:
	var tex := texture("shard")
	if tex == null:
		var fwd := Vector2.RIGHT.rotated(facing) * length * 0.5
		var side := Vector2.RIGHT.rotated(facing + PI * 0.5) * length * 0.22
		ci.draw_colored_polygon(PackedVector2Array([at + fwd, at + side, at - fwd, at - side]), color)
		return
	_draw_anchored(ci, tex, at, SHARD_CENTER, length / SHARD_LENGTH, facing, color)


## A corner bracket whose CORNER sits at `corner_at`, arms `arm` px long
## running +X and +Y before `rot` (rotate by PI/2 steps for the other corners).
static func draw_bracket(ci: CanvasItem, corner_at: Vector2, rot: float, arm: float, color: Color, fallback_width: float = 2.5) -> void:
	var tex := texture("bracket")
	if tex == null:
		ci.draw_line(corner_at, corner_at + Vector2.RIGHT.rotated(rot) * arm, color, fallback_width, true)
		ci.draw_line(corner_at, corner_at + Vector2.DOWN.rotated(rot) * arm, color, fallback_width, true)
		return
	_draw_anchored(ci, tex, corner_at, BRACKET_CORNER, arm / BRACKET_ARM, rot, color)


## A triangle outline centred on `at`, apex at `radius` (apex up before `spin`).
static func draw_triangle(ci: CanvasItem, at: Vector2, radius: float, color: Color, spin: float = 0.0, fallback_width: float = 3.0) -> void:
	var tex := texture("triangle")
	if tex == null:
		var pts := PackedVector2Array()
		for i in range(4):
			pts.append(at + Vector2.RIGHT.rotated(spin - PI * 0.5 + TAU * float(i % 3) / 3.0) * radius)
		ci.draw_polyline(pts, color, fallback_width, true)
		return
	_draw_anchored(ci, tex, at, TRIANGLE_CENTER, radius / TRIANGLE_HALF, spin, color)


## A bold plus glyph centred on `at`, `size` px across.
static func draw_plus(ci: CanvasItem, at: Vector2, size: float, color: Color, fallback_width: float = 2.6) -> void:
	var tex := texture("plus")
	if tex == null:
		ci.draw_line(at + Vector2(-size * 0.5, 0.0), at + Vector2(size * 0.5, 0.0), color, fallback_width, true)
		ci.draw_line(at + Vector2(0.0, -size * 0.5), at + Vector2(0.0, size * 0.5), color, fallback_width, true)
		return
	_draw_anchored(ci, tex, at, PLUS_CENTER, size / PLUS_W, 0.0, color)


## A small flame centred on `at`, `height` px tall, licking along -Y before `rot`.
static func draw_flame(ci: CanvasItem, at: Vector2, height: float, color: Color, rot: float = 0.0) -> void:
	var tex := texture("flame")
	if tex == null:
		ci.draw_circle(at, height * 0.3, color)
		return
	_draw_anchored(ci, tex, at, FLAME_CENTER, height / FLAME_H, rot, color)


## A coin glyph centred on `at`, `size` px across; `squash_x` (0..1) turns it
## edge-on for a spin.
static func draw_coin(ci: CanvasItem, at: Vector2, size: float, color: Color, squash_x: float = 1.0, fallback_width: float = 2.0) -> void:
	var tex := texture("coin")
	if tex == null:
		ci.draw_arc(at, size * 0.5, 0.0, TAU, 24, color, fallback_width, true)
		return
	var s := size / COIN_W
	var tex_size := tex.get_size()
	ci.draw_set_transform(at, 0.0, Vector2(s * maxf(absf(squash_x), 0.05), s))
	ci.draw_texture_rect(tex, Rect2(-COIN_CENTER, tex_size), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A clock face (eight ticks, hand baked pointing up) centred on `at`, face
## radius `radius`. Draw a sweeping hand on top with draw_streak.
static func draw_clock(ci: CanvasItem, at: Vector2, radius: float, color: Color, fallback_width: float = 2.5) -> void:
	var tex := texture("clock")
	if tex == null:
		ci.draw_arc(at, radius, 0.0, TAU, 32, color, fallback_width, true)
		for i in range(8):
			var d := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
			ci.draw_line(at + d * radius * 0.8, at + d * radius, color, fallback_width * 0.7, true)
		return
	_draw_anchored(ci, tex, at, CLOCK_CENTER, radius / CLOCK_HALF, 0.0, color)


## The lattice echo mark (ring + three ticks), tick reach `radius`.
static func draw_lattice_mark(ci: CanvasItem, at: Vector2, radius: float, color: Color, spin: float = 0.0, fallback_width: float = 2.0) -> void:
	var tex := texture("lattice_mark")
	if tex == null:
		ci.draw_arc(at, radius * 0.7, 0.0, TAU, 24, color, fallback_width, true)
		for i in range(3):
			var d := Vector2.RIGHT.rotated(spin - PI * 0.5 + TAU * float(i) / 3.0)
			ci.draw_line(at + d * radius * 0.7, at + d * radius, color, fallback_width, true)
		return
	_draw_anchored(ci, tex, at, LATTICE_MARK_CENTER, radius / LATTICE_MARK_HALF, spin, color)


## The mirrored lattice mark (diamond outline with a plus inside), diamond
## half-diagonal `radius`.
static func draw_lattice_mirror(ci: CanvasItem, at: Vector2, radius: float, color: Color, spin: float = 0.0, fallback_width: float = 2.0) -> void:
	var tex := texture("lattice_mirror")
	if tex == null:
		var pts := PackedVector2Array()
		for i in range(5):
			pts.append(at + Vector2.RIGHT.rotated(spin - PI * 0.5 + TAU * float(i % 4) / 4.0) * radius)
		ci.draw_polyline(pts, color, fallback_width, true)
		draw_plus(ci, at, radius * 0.6, color, fallback_width)
		return
	_draw_anchored(ci, tex, at, LATTICE_MIRROR_CENTER, radius / LATTICE_MIRROR_HALF, spin, color)
