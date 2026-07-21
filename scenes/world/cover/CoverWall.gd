extends StaticBody2D
# Connection bitmask: N=1, E=2, S=4, W=8

var _connections_mask: int = 0
var _is_window: bool = false
var _use_alpha_collision: bool = true

@export var connections_mask: int:
	set(value):
		if value == _connections_mask:
			return
		_connections_mask = value
		if is_inside_tree():
			_apply()
	get:
		return _connections_mask

@export var is_window: bool:
	set(value):
		if value == _is_window:
			return
		_is_window = value
		if is_inside_tree():
			_refresh_groups()
			_apply()
	get:
		return _is_window

@export var use_alpha_collision: bool:
	set(value):
		if value == _use_alpha_collision:
			return
		_use_alpha_collision = value
		if is_inside_tree():
			_apply()
	get:
		return _use_alpha_collision

static var _alpha_cache: Dictionary = {} # texture path -> Array[PackedVector2Array]

const N := 1
const E := 2
const S := 4
const W := 8

# Full walls
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

# Window walls (shoot-through). Use only on straight segments.
const TEX_WIN_V := preload("res://assets/world/walls/wall_stone_window_v.png")
const TEX_WIN_H := preload("res://assets/world/walls/wall_stone_window_h.png")

# Collision intent: wall art is authored as a thin "band" centered in the 64x64 tile.
# Use 4 half-segment colliders (N/E/S/W) so corners/T pieces don't over-block.
const COLL_WALL_THICKNESS: float = 24.0
const _HALF_LEN: float = 32.0

func _ready() -> void:
	_refresh_groups()
	_apply()

func _refresh_groups() -> void:
	# Keep group membership consistent even if is_window is set after _ready().
	add_to_group(&"cover_wall")
	if is_window:
		add_to_group(&"cover_window")
		remove_from_group(&"cover_full")
	else:
		add_to_group(&"cover_full")
		remove_from_group(&"cover_window")

func _apply() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return

	# Choose texture
	var tex: Texture2D
	if is_window:
		tex = _pick_window_texture(connections_mask)
		if tex == null:
			tex = _pick_full_texture(connections_mask)
	else:
		tex = _pick_full_texture(connections_mask)

	spr.texture = tex
	if use_alpha_collision:
		_apply_alpha_collision(spr, tex)
	else:
		_apply_collisions()


	# Quick win readability: cheap drop-shadow sprite (optional)
	var sh := get_node_or_null("Shadow") as Sprite2D
	if sh != null:
		sh.texture = tex
		sh.texture_filter = spr.texture_filter
		sh.texture_repeat = spr.texture_repeat
		sh.scale = spr.scale
		sh.flip_h = spr.flip_h
		sh.flip_v = spr.flip_v
		sh.rotation = spr.rotation
		sh.position = spr.position + Vector2(2, 3)
		sh.z_index = spr.z_index - 1
		sh.modulate = Color(0, 0, 0, 0.35)

func _apply_collisions() -> void:
	var want_n: bool = (connections_mask & N) != 0
	var want_e: bool = (connections_mask & E) != 0
	var want_s: bool = (connections_mask & S) != 0
	var want_w: bool = (connections_mask & W) != 0
	var want_post: bool = (connections_mask == 0)

	_apply_half_rect("CollisionN", Vector2(0, -16), Vector2(COLL_WALL_THICKNESS, _HALF_LEN), want_n)
	_apply_half_rect("CollisionS", Vector2(0, 16),  Vector2(COLL_WALL_THICKNESS, _HALF_LEN), want_s)
	_apply_half_rect("CollisionE", Vector2(16, 0),  Vector2(_HALF_LEN, COLL_WALL_THICKNESS), want_e)
	_apply_half_rect("CollisionW", Vector2(-16, 0), Vector2(_HALF_LEN, COLL_WALL_THICKNESS), want_w)

	var col_p: CollisionShape2D = get_node_or_null("CollisionPost") as CollisionShape2D
	if col_p != null:
		var rp := col_p.shape as RectangleShape2D
		if rp == null:
			rp = RectangleShape2D.new()
			col_p.shape = rp
		rp.size = Vector2(COLL_WALL_THICKNESS, COLL_WALL_THICKNESS)
		col_p.disabled = not want_post

	# Vision-only blockers for windows (LoS leak through the center gap).
	_apply_window_vision_blockers(connections_mask)



func _apply_alpha_collision(spr: Sprite2D, tex: Texture2D) -> void:
	# Builds collision polygons that match the texture's opaque pixels (no "whole tile" collision).
	# Cached per texture path to keep it cheap.
	if tex == null:
		_apply_collisions()
		return

	var key := tex.resource_path
	var polys: Array = []
	if _alpha_cache.has(key):
		polys = _alpha_cache[key]
	else:
		var img := tex.get_image()
		if img == null:
			_apply_collisions()
			return
		var bm := BitMap.new()
		bm.create_from_image_alpha(img)
		# Higher epsilon => fewer points (cheaper). 6-10 is a good sweet spot for 1024px art.
		polys = bm.opaque_to_polygons(Rect2i(0, 0, img.get_width(), img.get_height()), 8.0)
		_alpha_cache[key] = polys

	# If extraction failed, fall back.
	if polys.is_empty():
		_apply_collisions()
		return

	# Disable legacy rectangle colliders.
	for n in ["CollisionN", "CollisionE", "CollisionS", "CollisionW", "CollisionPost"]:
		var cs := get_node_or_null(n) as CollisionShape2D
		if cs != null:
			cs.disabled = true

	# Create / update CollisionPolygon2D nodes (cap count to avoid pathological cases).
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var half := Vector2(w * 0.5, h * 0.5)

	var max_polys := mini(4, polys.size())
	for i in range(max_polys):
		var col_name := "AlphaCol%d" % i
		var cp := get_node_or_null(col_name) as CollisionPolygon2D
		if cp == null:
			cp = CollisionPolygon2D.new()
			cp.name = col_name
			add_child(cp)

		var src: PackedVector2Array = polys[i]
		var dst := PackedVector2Array()
		dst.resize(src.size())
		for j in range(src.size()):
			var p := src[j] - half
			# Match Sprite2D's scale (textures are authored at 1024px, sprite is scaled down to 64px).
			p *= spr.scale
			dst[j] = p

		cp.polygon = dst
		cp.position = spr.position
		cp.rotation = spr.rotation
		cp.disabled = false

	# Disable any extra AlphaCol nodes from previous textures
	var k := max_polys
	while true:
		var extra := get_node_or_null("AlphaCol%d" % k) as CollisionPolygon2D
		if extra == null:
			break
		extra.disabled = true
		k += 1

	# Keep window vision blockers in sync (best-effort; node may not exist).
	_apply_window_vision_blockers(connections_mask)

func _apply_window_vision_blockers(mask: int) -> void:
	var vb := get_node_or_null("VisionBlocker") as StaticBody2D
	if vb == null:
		return

	# Default: nothing blocks (we'll enable the right pair for window straights).
	_set_cs_disabled("VisionBlocker/VB_V_Top", true)
	_set_cs_disabled("VisionBlocker/VB_V_Bot", true)
	_set_cs_disabled("VisionBlocker/VB_H_Left", true)
	_set_cs_disabled("VisionBlocker/VB_H_Right", true)

	if not is_window:
		return

	var is_vert: bool = (mask == (N | S))
	var is_horiz: bool = (mask == (E | W))
	if is_vert:
		_set_cs_disabled("VisionBlocker/VB_V_Top", false)
		_set_cs_disabled("VisionBlocker/VB_V_Bot", false)
	elif is_horiz:
		_set_cs_disabled("VisionBlocker/VB_H_Left", false)
		_set_cs_disabled("VisionBlocker/VB_H_Right", false)


func _set_cs_disabled(path: String, disabled: bool) -> void:
	var cs := get_node_or_null(path) as CollisionShape2D
	if cs != null:
		cs.disabled = disabled

func _apply_half_rect(node_name: String, pos: Vector2, size: Vector2, enabled: bool) -> void:
	var col: CollisionShape2D = get_node_or_null(node_name) as CollisionShape2D
	if col == null:
		return
	col.position = pos

	# Robust: scenes may have no shape (or a corrupted cached one). Ensure it's a RectangleShape2D we own.
	var r := col.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		col.shape = r
	r.size = size
	col.disabled = not enabled


func _pick_window_texture(mask: int) -> Texture2D:
	# Only place window art on straight segments.
	if mask == (N | S):
		return TEX_WIN_V
	if mask == (E | W):
		return TEX_WIN_H
	return null

func _pick_full_texture(mask: int) -> Texture2D:
	# Defensive default (handcrafted / unknown)
	if mask == 0:
		return TEX_STRAIGHT_V

	match mask:
		(N | S):
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
			return TEX_T_N   # missing S
		(S | E | W):
			return TEX_T_S   # missing N
		(N | S | E):
			return TEX_T_E   # missing W
		(N | S | W):
			return TEX_T_W   # missing E

		(N | E | S | W):
			return TEX_CROSS

	# Fallbacks: prefer straight if it looks like one, else cross.
	if (mask & N) != 0 and (mask & S) != 0 and (mask & (E | W)) == 0:
		return TEX_STRAIGHT_V
	if (mask & E) != 0 and (mask & W) != 0 and (mask & (N | S)) == 0:
		return TEX_STRAIGHT_H

	return TEX_CROSS
