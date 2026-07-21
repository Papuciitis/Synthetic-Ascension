extends Sprite2D
class_name FloorFollow

@export var target_group: StringName = &"player"
@export var region_multiplier: float = 3.0
@export var snap_to_whole_pixels: bool = true

# If movement feels "inverted", flip these.
@export var invert_scroll_x: bool = false
@export var invert_scroll_y: bool = false

var _target: Node2D
var _tex_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	region_enabled = true
	centered = true

	_cache_target()
	_cache_tex_size()
	_refresh_region()

	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.connect(_on_viewport_size_changed)

func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_cache_target()
		if _target == null:
			return

	_cache_tex_size()
	if _tex_size == Vector2.ZERO:
		return

	# Use ONE consistent position (fixes drift/jitter)
	var world_pos: Vector2 = _target.global_position
	if snap_to_whole_pixels:
		world_pos = Vector2(round(world_pos.x), round(world_pos.y))

	# 1) Keep the floor centered on the target (so it never ends)
	global_position = world_pos

	# 2) Scroll the sampled texture region so the pattern moves under you
	var sx: float = (-1.0 if invert_scroll_x else 1.0)
	var sy: float = (-1.0 if invert_scroll_y else 1.0)

	var ox: float = fposmod(world_pos.x * sx, _tex_size.x)
	var oy: float = fposmod(world_pos.y * sy, _tex_size.y)

	region_rect.position = Vector2(ox, oy)

func _cache_target() -> void:
	_target = get_tree().get_first_node_in_group(String(target_group)) as Node2D

func _cache_tex_size() -> void:
	if texture == null:
		_tex_size = Vector2.ZERO
		return
	var s: Vector2 = texture.get_size()
	_tex_size = Vector2(maxf(s.x, 1.0), maxf(s.y, 1.0))

func _refresh_region() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var size: Vector2 = vp.get_visible_rect().size * maxf(region_multiplier, 1.5)
	region_rect.size = size

func _on_viewport_size_changed() -> void:
	_refresh_region()
