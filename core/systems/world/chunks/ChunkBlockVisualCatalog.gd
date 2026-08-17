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
	return _full_wall_texture(mask)


static func window_texture(mask: int) -> Texture2D:
	if mask == (N | S):
		return TEX_WIN_V
	if mask == (E | W):
		return TEX_WIN_H
	return null


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
	return 17 + HALF_TEXTURES.size()


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
