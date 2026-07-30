extends StaticBody2D
class_name CoverHalf

@export var use_alpha_collision: bool = false

static var _alpha_cache: Dictionary = {} # texture path -> Array[PackedVector2Array]

# Deterministic-ish visual variety based on world position
const PROP_TEX: Array[Texture2D] = [
	preload("res://assets/world/props/prop_crate_01.png"),
	preload("res://assets/world/props/prop_crate_rot_01.png"),
	preload("res://assets/world/props/prop_rubble_big_01.png"),
	preload("res://assets/world/props/prop_rubble_small_01.png"),
	preload("res://assets/world/props/prop_table_long_01.png"),
	preload("res://assets/world/props/prop_table_small_01.png"),
	preload("res://assets/world/props/prop_broken_pillar_01.png"),
	preload("res://assets/world/props/prop_statue_01.png"),
]

func _ready() -> void:
	add_to_group(&"cover_half")
	_apply()
	_register_projectile_geometry()

func _exit_tree() -> void:
	_unregister_projectile_geometry()

func _register_projectile_geometry() -> void:
	var manager: Node = get_tree().get_first_node_in_group(&"chunk_manager")
	if manager != null and manager.has_method("register_projectile_blocker_world"):
		manager.call("register_projectile_blocker_world", global_position, WorldBlockerGeometry.pack(WorldBlockerGeometry.Kind.HALF_COVER), get_instance_id())

func _unregister_projectile_geometry() -> void:
	if not is_inside_tree():
		return
	var manager: Node = get_tree().get_first_node_in_group(&"chunk_manager")
	if manager != null and manager.has_method("unregister_projectile_blocker_world"):
		manager.call("unregister_projectile_blocker_world", global_position, get_instance_id())

func _apply() -> void:
	_apply_default_collision()
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return

	var rng := RandomNumberGenerator.new()
	var sx := int(floor(global_position.x))
	var sy := int(floor(global_position.y))
	# 2D hash -> seed
	rng.seed = int((sx * 73856093) ^ (sy * 19349663) ^ 0x9E3779B9)

	var tex := PROP_TEX[rng.randi_range(0, PROP_TEX.size() - 1)]
	spr.texture = tex
	spr.rotation_degrees = float(90 * rng.randi_range(0, 3))
	if use_alpha_collision:
		_apply_alpha_collision(spr, tex)


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

func _apply_default_collision() -> void:
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	var circle: CircleShape2D = collision.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision.shape = circle
	circle.radius = WorldBlockerGeometry.HALF_COVER_RADIUS
	collision.disabled = use_alpha_collision



func _apply_alpha_collision(spr: Sprite2D, tex: Texture2D) -> void:
	if tex == null:
		return

	var key := tex.resource_path
	var polys: Array = []
	if _alpha_cache.has(key):
		polys = _alpha_cache[key]
	else:
		var img := tex.get_image()
		if img == null:
			return
		var bm := BitMap.new()
		bm.create_from_image_alpha(img)
		polys = bm.opaque_to_polygons(Rect2i(0, 0, img.get_width(), img.get_height()), 10.0)
		_alpha_cache[key] = polys

	if polys.is_empty():
		return

	# Disable legacy circle collider (it over-blocks long props like tables).
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null:
		cs.disabled = true

	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var half := Vector2(w * 0.5, h * 0.5)

	var max_polys := mini(3, polys.size())
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
			p *= spr.scale
			# Apply sprite flips directly (so collision matches visuals).
			if spr.flip_h:
				p.x = -p.x
			if spr.flip_v:
				p.y = -p.y
			dst[j] = p

		cp.polygon = dst
		cp.position = spr.position
		cp.rotation = spr.rotation
		cp.disabled = false

	# Disable extras
	var k := max_polys
	while true:
		var extra := get_node_or_null("AlphaCol%d" % k) as CollisionPolygon2D
		if extra == null:
			break
		extra.disabled = true
		k += 1
