extends StaticBody2D
class_name FenceBlock

# Connection bitmask: N=1, E=2, S=4, W=8
var _connections_mask: int = 0
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

const N := 1
const E := 2
const S := 4
const W := 8

const TEX_H := preload("res://assets/world/fences/fence_wood_h.png")
const TEX_V := preload("res://assets/world/fences/fence_wood_v.png")
const TEX_NE := preload("res://assets/world/fences/fence_wood_corner_ne.png")
const TEX_NW := preload("res://assets/world/fences/fence_wood_corner_nw.png")
const TEX_SE := preload("res://assets/world/fences/fence_wood_corner_se.png")
const TEX_SW := preload("res://assets/world/fences/fence_wood_corner_sw.png")
const TEX_POST := preload("res://assets/world/fences/fence_post_01.png")

func _ready() -> void:
	add_to_group(&"fences")
	_apply()
	_register_projectile_geometry()

func _exit_tree() -> void:
	_unregister_projectile_geometry()

func _apply() -> void:
	_apply_collisions()
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return

	var tex := _pick_tex(connections_mask)
	spr.texture = tex

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
		sh.modulate = Color(0, 0, 0, 0.28)


func get_visual_texture() -> Texture2D:
	return _pick_tex(connections_mask)

func _apply_collisions() -> void:
	# Thin fence intent: match the visible line segments (N/E/S/W half-legs).
	# If we don't have a supported segment mask (ends / weird), fall back to a post.
	var is_segment: bool = (
		connections_mask == (N | S)
		or connections_mask == (E | W)
		or connections_mask == (N | E)
		or connections_mask == (N | W)
		or connections_mask == (S | E)
		or connections_mask == (S | W)
	)

	var want_n: bool = is_segment and ((connections_mask & N) != 0)
	var want_e: bool = is_segment and ((connections_mask & E) != 0)
	var want_s: bool = is_segment and ((connections_mask & S) != 0)
	var want_w: bool = is_segment and ((connections_mask & W) != 0)
	var want_post: bool = not is_segment

	_apply_rect("CollisionN", Vector2(0.0, -16.0), Vector2(WorldBlockerGeometry.FENCE_THICKNESS, WorldBlockerGeometry.FENCE_HALF_LENGTH), want_n)
	_apply_rect("CollisionE", Vector2(16.0, 0.0), Vector2(WorldBlockerGeometry.FENCE_HALF_LENGTH, WorldBlockerGeometry.FENCE_THICKNESS), want_e)
	_apply_rect("CollisionS", Vector2(0.0, 16.0), Vector2(WorldBlockerGeometry.FENCE_THICKNESS, WorldBlockerGeometry.FENCE_HALF_LENGTH), want_s)
	_apply_rect("CollisionW", Vector2(-16.0, 0.0), Vector2(WorldBlockerGeometry.FENCE_HALF_LENGTH, WorldBlockerGeometry.FENCE_THICKNESS), want_w)
	_apply_rect("CollisionPost", Vector2.ZERO, Vector2(WorldBlockerGeometry.FENCE_POST_SIZE, WorldBlockerGeometry.FENCE_POST_SIZE), want_post)

func _apply_rect(col_node: String, center: Vector2, size: Vector2, enabled: bool) -> void:
	var collision: CollisionShape2D = get_node_or_null(col_node) as CollisionShape2D
	if collision == null:
		return
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision.shape = rectangle
	rectangle.size = size
	collision.position = center
	collision.set_deferred("disabled", not enabled)

func _register_projectile_geometry() -> void:
	var manager: Node = get_tree().get_first_node_in_group(&"chunk_manager")
	if manager != null and manager.has_method("register_projectile_blocker_world"):
		manager.call("register_projectile_blocker_world", global_position, WorldBlockerGeometry.pack(WorldBlockerGeometry.Kind.FENCE, connections_mask), get_instance_id())

func _unregister_projectile_geometry() -> void:
	if not is_inside_tree():
		return
	var manager: Node = get_tree().get_first_node_in_group(&"chunk_manager")
	if manager != null and manager.has_method("unregister_projectile_blocker_world"):
		manager.call("unregister_projectile_blocker_world", global_position, get_instance_id())

func _pick_tex(mask: int) -> Texture2D:
	# Straight
	if mask == (N | S):
		return TEX_V
	if mask == (E | W):
		return TEX_H

	# Corners
	if mask == (N | E):
		return TEX_NE
	if mask == (N | W):
		return TEX_NW
	if mask == (S | E):
		return TEX_SE
	if mask == (S | W):
		return TEX_SW

	# Everything else (ends / isolated) -> post
	return TEX_POST
