extends StaticBody2D
# Connection bitmask: N=1, E=2, S=4, W=8

var _connections_mask: int = 0
var _is_window: bool = false
var _use_alpha_collision: bool = false

@export var connections_mask: int:
	set(value):
		if value == _connections_mask:
			return
		_connections_mask = value
		if is_inside_tree():
			_apply()
			_register_projectile_geometry()
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
			_register_projectile_geometry()
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

func _ready() -> void:
	_refresh_groups()
	_apply()
	_register_projectile_geometry()

func _exit_tree() -> void:
	_unregister_projectile_geometry()

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

	# Choose texture
	var tex: Texture2D
	if is_window:
		tex = _pick_window_texture(connections_mask)
		if tex == null:
			tex = _pick_full_texture(connections_mask)
	else:
		tex = _pick_full_texture(connections_mask)

	if use_alpha_collision and spr != null:
		_apply_alpha_collision(spr, tex)
	else:
		_apply_collisions()

	if spr == null:
		return
	spr.texture = tex

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


func get_visual_texture() -> Texture2D:
	if is_window:
		var window_texture := _pick_window_texture(connections_mask)
		if window_texture != null:
			return window_texture
	return _pick_full_texture(connections_mask)

func _apply_collisions() -> void:
	var want_n: bool = (connections_mask & N) != 0
	var want_e: bool = (connections_mask & E) != 0
	var want_s: bool = (connections_mask & S) != 0
	var want_w: bool = (connections_mask & W) != 0
	var want_post: bool = (connections_mask == 0)

	_apply_half_rect("CollisionN", Vector2(0, -16), Vector2(WorldBlockerGeometry.WALL_THICKNESS, WorldBlockerGeometry.WALL_HALF_LENGTH), want_n)
	_apply_half_rect("CollisionS", Vector2(0, 16),  Vector2(WorldBlockerGeometry.WALL_THICKNESS, WorldBlockerGeometry.WALL_HALF_LENGTH), want_s)
	_apply_half_rect("CollisionE", Vector2(16, 0),  Vector2(WorldBlockerGeometry.WALL_HALF_LENGTH, WorldBlockerGeometry.WALL_THICKNESS), want_e)
	_apply_half_rect("CollisionW", Vector2(-16, 0), Vector2(WorldBlockerGeometry.WALL_HALF_LENGTH, WorldBlockerGeometry.WALL_THICKNESS), want_w)

	var col_p: CollisionShape2D = get_node_or_null("CollisionPost") as CollisionShape2D
	if col_p != null:
		var rp := col_p.shape as RectangleShape2D
		if rp == null:
			rp = RectangleShape2D.new()
			col_p.shape = rp
		rp.size = Vector2(WorldBlockerGeometry.WALL_POST_SIZE, WorldBlockerGeometry.WALL_POST_SIZE)
		col_p.set_deferred("disabled", not want_post)

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
			cs.set_deferred("disabled", true)

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
		cp.set_deferred("disabled", false)

	# Disable any extra AlphaCol nodes from previous textures
	var k := max_polys
	while true:
		var extra := get_node_or_null("AlphaCol%d" % k) as CollisionPolygon2D
		if extra == null:
			break
		extra.set_deferred("disabled", true)
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
		cs.set_deferred("disabled", disabled)

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
	col.set_deferred("disabled", not enabled)

func _register_projectile_geometry() -> void:
	var manager: Node = get_tree().get_first_node_in_group(&"chunk_manager")
	if manager == null or not manager.has_method("register_projectile_blocker_world"):
		return
	var kind: int = WorldBlockerGeometry.Kind.WINDOW if is_window else WorldBlockerGeometry.Kind.WALL
	manager.call("register_projectile_blocker_world", global_position, WorldBlockerGeometry.pack(kind, connections_mask), get_instance_id())

func _unregister_projectile_geometry() -> void:
	if not is_inside_tree():
		return
	var manager: Node = get_tree().get_first_node_in_group(&"chunk_manager")
	if manager != null and manager.has_method("unregister_projectile_blocker_world"):
		manager.call("unregister_projectile_blocker_world", global_position, get_instance_id())


func _pick_window_texture(mask: int) -> Texture2D:
	return ChunkBlockVisualCatalog.window_texture(mask)

func _pick_full_texture(mask: int) -> Texture2D:
	return ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL, mask)
