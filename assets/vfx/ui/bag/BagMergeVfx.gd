extends Control
class_name BagMergeVfx

@export var fly_time: float = 0.18
@export var icon_size: float = 34.0
@export var fade_out: bool = true
@export var only_when_open: bool = true
@export var z_index_icon: int = 50

# obvious feedback
@export var impact_flash: bool = true
@export var flash_time: float = 0.18
@export var flash_size: float = 54.0
@export var debug_vfx: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true
	clip_contents = false
	set_anchors_preset(Control.PRESET_FULL_RECT, true)

	# KEY: draw in SCREEN SPACE so it can fly across the whole screen
	set_as_top_level(true)

	# Keep z sane (you hit CANVAS_ITEM_Z_MAX before)
	z_as_relative = false
	z_index = 2000

	if debug_vfx:
		var pname := "null"
		var p := get_parent()
		if p != null:
			pname = String(p.name)
		print("[BagMergeVfx] READY parent=", pname)

# --------------------------------------------------
# Public API
# --------------------------------------------------

# Merge: from slot -> to slot (fly icon)
func play_merge(from_ctrl: Control, to_ctrl: Control, src: ItemInstance, bag_is_open: bool) -> void:
	if only_when_open and not bag_is_open:
		if debug_vfx: print("[BagMergeVfx] play_merge blocked (only_when_open)")
		return
	if not _basic_valid(src, from_ctrl, to_ctrl):
		return

	await get_tree().process_frame

	var start_g: Vector2 = _center_global(from_ctrl)
	var end_g: Vector2 = _center_global(to_ctrl)

	if debug_vfx:
		print("[BagMergeVfx] play_merge ok start_g=", start_g, " end_g=", end_g)

	_spawn_fly(src, start_g, end_g, false)

# Feed: "absorbed" into a bag slot (ground/inventory -> bag)
# origin is expected to be: { "type": int, "pos": Vector2 }
func play_feed(to_ctrl: Control, src: ItemInstance, bag_is_open: bool, upgraded: bool = false, origin: Variant = null) -> void:
	if only_when_open and not bag_is_open:
		if debug_vfx: print("[BagMergeVfx] play_feed blocked (only_when_open)")
		return
	if not _basic_valid(src, to_ctrl, to_ctrl):
		return

	await get_tree().process_frame

	var end_g: Vector2 = _center_global(to_ctrl)

	var have_origin := false
	var start_g: Vector2 = end_g

	if origin is Dictionary:
		var d: Dictionary = origin
		if d.has("pos") and d["pos"] is Vector2:
			start_g = d["pos"]
			have_origin = true

	if not have_origin:
		# fallback: random little pull near destination
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if dir.length() < 0.001:
			dir = Vector2.RIGHT
		else:
			dir = dir.normalized()
		start_g = end_g + dir * 40.0

	if debug_vfx:
		var otype := -1
		var opos := Vector2.ZERO
		if origin is Dictionary:
			var dd: Dictionary = origin
			otype = int(dd.get("type", -1))
			var pv: Variant = dd.get("pos", Vector2.ZERO)
			if pv is Vector2:
				opos = pv as Vector2
		print("[BagMergeVfx] play_feed ok start_g=", start_g, " end_g=", end_g,
			" upgraded=", upgraded, " origin_type=", otype, " origin_pos=", opos)

	_spawn_fly(src, start_g, end_g, upgraded)

# --------------------------------------------------
# Internals
# --------------------------------------------------

func _basic_valid(src: ItemInstance, a: Control, b: Control) -> bool:
	if src == null or src.data == null or src.data.icon == null:
		if debug_vfx: print("[BagMergeVfx] missing src/data/icon")
		return false
	if a == null or b == null:
		if debug_vfx: print("[BagMergeVfx] missing ctrl")
		return false
	if not is_instance_valid(a) or not is_instance_valid(b):
		if debug_vfx: print("[BagMergeVfx] invalid ctrl")
		return false
	return true

func _center_global(c: Control) -> Vector2:
	var r: Rect2 = c.get_global_rect()
	return r.position + r.size * 0.5

func _spawn_fly(src: ItemInstance, start_g: Vector2, end_g: Vector2, upgraded: bool) -> void:
	var is_pos := (int(src.polarity) == int(ItemInstance.Polarity.POS))
	var tint := (Color(0.85, 1.0, 1.0, 1.0) if is_pos else Color(1.0, 0.75, 0.8, 1.0))
	var flash_col := (Color(0.25, 1.0, 1.0, 0.22) if is_pos else Color(1.0, 0.35, 0.55, 0.22))

	var ghost := TextureRect.new()
	ghost.texture = src.data.icon
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.size = Vector2(icon_size, icon_size)
	ghost.custom_minimum_size = ghost.size
	ghost.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	ghost.z_index = z_index_icon
	ghost.z_as_relative = false
	ghost.modulate = tint
	add_child(ghost)

	var half := ghost.size * 0.5
	ghost.position = start_g - half

	var flash: ColorRect = null
	if impact_flash:
		flash = ColorRect.new()
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.size = Vector2(flash_size, flash_size)
		flash.custom_minimum_size = flash.size
		flash.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		flash.position = end_g - flash.size * 0.5
		flash.z_index = z_index_icon + 1
		flash.z_as_relative = false
		flash.color = flash_col
		add_child(flash)

	var t := create_tween()
	t.set_parallel(true)

	t.tween_property(ghost, "position", end_g - half, fly_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var bump := (1.35 if upgraded else 1.15)
	t.tween_property(ghost, "scale", Vector2(bump, bump), fly_time * 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(ghost, "scale", Vector2(0.95, 0.95), fly_time * 0.45)\
		.set_delay(fly_time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if fade_out:
		var end_col := ghost.modulate
		end_col.a = 0.0
		t.tween_property(ghost, "modulate", end_col, fly_time * 0.45)\
			.set_delay(fly_time * 0.55)

	if flash != null:
		flash.scale = Vector2(0.65, 0.65)
		var fcol1 := flash.color
		fcol1.a = 0.0
		t.tween_property(flash, "scale", Vector2(1.25, 1.25), flash_time * 0.55)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(flash, "color", fcol1, flash_time * 0.45)\
			.set_delay(flash_time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	t.set_parallel(false)
	t.tween_callback(Callable(ghost, "queue_free"))
	if flash != null:
		t.tween_callback(Callable(flash, "queue_free"))
