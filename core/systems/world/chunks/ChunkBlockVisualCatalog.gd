extends RefCounted
class_name ChunkBlockVisualCatalog

const N := WorldBlockerGeometry.N
const E := WorldBlockerGeometry.E
const S := WorldBlockerGeometry.S
const W := WorldBlockerGeometry.W

const TEX_STRAIGHT_V := preload("res://assets/world/walls/wall_stone_straight_v.png")
const TEX_STRAIGHT_H := preload("res://assets/world/walls/wall_stone_straight_h.png")
const TEX_CORNER_NE := preload("res://assets/world/walls/wall_stone_corner_ne.png")
const TEX_CORNER_NW := preload("res://assets/world/walls/wall_stone_corner_nw.png")
const TEX_CORNER_SE := preload("res://assets/world/walls/wall_stone_corner_se.png")
const TEX_CORNER_SW := preload("res://assets/world/walls/wall_stone_corner_sw.png")
const TEX_END_N := preload("res://assets/world/walls/wall_stone_end_n.png")
const TEX_END_E := preload("res://assets/world/walls/wall_stone_end_e.png")
const TEX_END_S := preload("res://assets/world/walls/wall_stone_end_s.png")
const TEX_END_W := preload("res://assets/world/walls/wall_stone_end_w.png")
const TEX_T_N := preload("res://assets/world/walls/wall_stone_t_n.png")
const TEX_T_E := preload("res://assets/world/walls/wall_stone_t_e.png")
const TEX_T_S := preload("res://assets/world/walls/wall_stone_t_s.png")
const TEX_T_W := preload("res://assets/world/walls/wall_stone_t_w.png")
const TEX_CROSS := preload("res://assets/world/walls/wall_stone_cross.png")
const TEX_WIN_V := preload("res://assets/world/walls/wall_stone_window_v.png")
const TEX_WIN_H := preload("res://assets/world/walls/wall_stone_window_h.png")
## Shallow depth (Phase 3): the vertical stone face drawn under a cap
## wherever no wall continues south. Authored by
## tools/design/build_world_textures.py in the caps' palette. Superseded by
## the three-quarter kit below, which bakes the face into each piece.
const TEX_FACE := preload("res://assets/world/walls/wall_stone_face.png")

## Three-quarter wall kit (2026-09-27): one piece per connection mask with the
## lit top lifted KIT_HEIGHT px and the dark face baked under every exposed
## south edge; tools/design/build_wall_kit.py. A piece covers the cell plus
## KIT_HEIGHT above it, so it draws KIT_OFFSET above the cell centre.
static var three_quarter_walls := true
const KIT_HEIGHT := 28.0
const KIT_OFFSET := Vector2(0.0, -KIT_HEIGHT * 0.5)
const KIT_TEXTURES: Array[Texture2D] = [
	preload("res://assets/world/walls/kit/wall34_00.png"),
	preload("res://assets/world/walls/kit/wall34_01.png"),
	preload("res://assets/world/walls/kit/wall34_02.png"),
	preload("res://assets/world/walls/kit/wall34_03.png"),
	preload("res://assets/world/walls/kit/wall34_04.png"),
	preload("res://assets/world/walls/kit/wall34_05.png"),
	preload("res://assets/world/walls/kit/wall34_06.png"),
	preload("res://assets/world/walls/kit/wall34_07.png"),
	preload("res://assets/world/walls/kit/wall34_08.png"),
	preload("res://assets/world/walls/kit/wall34_09.png"),
	preload("res://assets/world/walls/kit/wall34_10.png"),
	preload("res://assets/world/walls/kit/wall34_11.png"),
	preload("res://assets/world/walls/kit/wall34_12.png"),
	preload("res://assets/world/walls/kit/wall34_13.png"),
	preload("res://assets/world/walls/kit/wall34_14.png"),
	preload("res://assets/world/walls/kit/wall34_15.png"),
]
const KIT_WIN_H := preload("res://assets/world/walls/kit/wall34_window_h.png")
const KIT_WIN_V := preload("res://assets/world/walls/kit/wall34_window_v.png")
## Corner fills for solid blocks: [neighbour bits, diagonal, texture], by
## quadrant. A fill covers the open corner between two arms when the diagonal
## cell is wall too.
const KIT_FILLS: Array = [
	[N | E, Vector2i(1, -1), preload("res://assets/world/walls/kit/wall34_fill_ne.png")],
	[S | E, Vector2i(1, 1), preload("res://assets/world/walls/kit/wall34_fill_se.png")],
	[S | W, Vector2i(-1, 1), preload("res://assets/world/walls/kit/wall34_fill_sw.png")],
	[N | W, Vector2i(-1, -1), preload("res://assets/world/walls/kit/wall34_fill_nw.png")],
]
## Walls draw under actors (the player is z 0 and precedes the world in the
## tree): a tall piece drawn over them hid heads standing in FRONT of a wall,
## which reads worse than a head overlapping one they stand behind.
const WALL_Z := -3
const FILL_Z := -2


## World offset of a quadrant fill's centre from its cell centre.
static func fill_offset(diagonal: Vector2i) -> Vector2:
	return Vector2(diagonal) * 24.0 + KIT_OFFSET + Vector2(0.0, -KIT_HEIGHT * 0.5)

const HALF_TEXTURES: Array[Texture2D] = [
	preload("res://assets/world/props/prop_crate_01.png"),
	preload("res://assets/world/props/prop_crate_rot_01.png"),
	preload("res://assets/world/props/prop_rubble_big_01.png"),
	preload("res://assets/world/props/prop_rubble_small_01.png"),
	preload("res://assets/world/props/prop_table_long_01.png"),
	preload("res://assets/world/props/prop_table_small_01.png"),
	preload("res://assets/world/props/prop_broken_pillar_01.png"),
	preload("res://assets/world/props/prop_statue_01.png"),
]


static func wall_texture(kind: int, mask: int) -> Texture2D:
	if kind == WorldBlockerGeometry.Kind.WINDOW:
		var window := window_texture(mask)
		if window != null:
			return window
	if three_quarter_walls:
		return KIT_TEXTURES[mask & 15]
	return _full_wall_texture(mask)


static func window_texture(mask: int) -> Texture2D:
	if mask == (N | S):
		return KIT_WIN_V if three_quarter_walls else TEX_WIN_V
	if mask == (E | W):
		return KIT_WIN_H if three_quarter_walls else TEX_WIN_H
	return null


## Where a wall-like piece draws relative to its cell centre.
static func wall_offset() -> Vector2:
	return KIT_OFFSET if three_quarter_walls else Vector2.ZERO


## Scale that fits `texture` to one cell's width (the old art is 1024 px, the
## kit 256 px).
static func cell_scale(texture: Texture2D, cell_size: float = 64.0) -> Vector2:
	var width := float(texture.get_width()) if texture != null else 1024.0
	return Vector2.ONE * (cell_size / maxf(1.0, width))


static func half_variant(world_position: Vector2) -> int:
	var rng := RandomNumberGenerator.new()
	var sx := int(floor(world_position.x))
	var sy := int(floor(world_position.y))
	rng.seed = int((sx * 73856093) ^ (sy * 19349663) ^ 0x9E3779B9)
	var texture_index := rng.randi_range(0, HALF_TEXTURES.size() - 1)
	var quarter_turn := rng.randi_range(0, 3)
	return texture_index | (quarter_turn << 3)


static func half_texture(variant: int) -> Texture2D:
	return HALF_TEXTURES[clampi(variant & 7, 0, HALF_TEXTURES.size() - 1)]


static func half_rotation(variant: int) -> float:
	return float((variant >> 3) & 3) * PI * 0.5


static func texture_count() -> int:
	if three_quarter_walls:
		return KIT_TEXTURES.size() + 2 + HALF_TEXTURES.size()
	return 18 + HALF_TEXTURES.size()


## The south face for a wall-like cell, or null where one is not drawn: a
## wall connecting south shows no face, and fences/half cover have none.
static func face_texture(kind: int, mask: int) -> Texture2D:
	if three_quarter_walls:
		return null
	if kind == WorldBlockerGeometry.Kind.FENCE or kind == WorldBlockerGeometry.Kind.HALF_COVER:
		return null
	if (mask & S) != 0:
		return null
	return TEX_FACE


static func _full_wall_texture(mask: int) -> Texture2D:
	match mask:
		0, (N | S):
			return TEX_STRAIGHT_V
		(E | W):
			return TEX_STRAIGHT_H
		(N | E):
			return TEX_CORNER_NE
		(N | W):
			return TEX_CORNER_NW
		(S | E):
			return TEX_CORNER_SE
		(S | W):
			return TEX_CORNER_SW
		N:
			return TEX_END_N
		E:
			return TEX_END_E
		S:
			return TEX_END_S
		W:
			return TEX_END_W
		(N | E | W):
			return TEX_T_N
		(S | E | W):
			return TEX_T_S
		(N | S | E):
			return TEX_T_E
		(N | S | W):
			return TEX_T_W
		(N | E | S | W):
			return TEX_CROSS
	if (mask & N) != 0 and (mask & S) != 0 and (mask & (E | W)) == 0:
		return TEX_STRAIGHT_V
	if (mask & E) != 0 and (mask & W) != 0 and (mask & (N | S)) == 0:
		return TEX_STRAIGHT_H
	return TEX_CROSS
