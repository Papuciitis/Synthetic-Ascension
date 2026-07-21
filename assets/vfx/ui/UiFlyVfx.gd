extends Control
class_name UiFlyVfx

@export var fly_time: float = 0.18
@export var icon_size: float = 34.0
@export var impact_flash: bool = true
@export var flash_time: float = 0.18
@export var flash_size: float = 54.0
@export var fade_out: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	visible = true

	add_to_group("ui_fly_vfx")
	# KEY: draw in SCREEN SPACE so it can fly across the whole screen
	set_as_top_level(true)

	set_anchors_preset(Control.PRESET_FULL_RECT, true)

	z_as_relative = false
	z_index = 4095

func fly_to(target_ctrl: Control, inst: ItemInstance, start_global: Vector2, upgraded: bool = false) -> void:
	if target_ctrl == null or not is_instance_valid(target_ctrl):
		return
	if inst == null or inst.data == null or inst.data.icon == null:
		return

	await get_tree().process_frame

	var end_g := _center_global(target_ctrl)
	var start := _global_to_local_ui(start_global)
	var end := _global_to_local_ui(end_g)

	_spawn_fly(inst, start, end, upgraded)

func _center_global(c: Control) -> Vector2:
	var r: Rect2 = c.get_global_rect()
	return r.position + r.size * 0.5

func _spawn_fly(inst: ItemInstance, start: Vector2, end: Vector2, upgraded: bool) -> void:
	var is_pos := (int(inst.polarity) == int(ItemInstance.Polarity.POS))
	var tint := (Color(0.85, 1.0, 1.0, 1.0) if is_pos else Color(1.0, 0.75, 0.8, 1.0))
	var flash_col := (Color(0.25, 1.0, 1.0, 0.22) if is_pos else Color(1.0, 0.35, 0.55, 0.22))

	var ghost := TextureRect.new()
	ghost.texture = inst.data.icon
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.size = Vector2(icon_size, icon_size)
	ghost.custom_minimum_size = ghost.size
	ghost.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	ghost.z_as_relative = false
	ghost.z_index = 4090
	ghost.modulate = tint
	add_child(ghost)

	var half := ghost.size * 0.5
	ghost.position = start - half

	var flash: ColorRect = null
	if impact_flash:
		flash = ColorRect.new()
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.size = Vector2(flash_size, flash_size)
		flash.custom_minimum_size = flash.size
		flash.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		flash.position = end - flash.size * 0.5
		flash.z_as_relative = false
		flash.z_index = 4091
		flash.color = flash_col
		add_child(flash)

	var t := create_tween()
	t.set_parallel(true)

	t.tween_property(ghost, "position", end - half, fly_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var bump := (1.35 if upgraded else 1.15)
	t.tween_property(ghost, "scale", Vector2(bump, bump), fly_time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(ghost, "scale", Vector2(0.95, 0.95), fly_time * 0.45).set_delay(fly_time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if fade_out:
		var end_col := ghost.modulate
		end_col.a = 0.0
		t.tween_property(ghost, "modulate", end_col, fly_time * 0.45).set_delay(fly_time * 0.55)

	if flash != null:
		flash.scale = Vector2(0.65, 0.65)
		var fcol1 := flash.color
		fcol1.a = 0.0
		t.tween_property(flash, "scale", Vector2(1.25, 1.25), flash_time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(flash, "color", fcol1, flash_time * 0.45).set_delay(flash_time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	t.set_parallel(false)
	t.tween_callback(Callable(ghost, "queue_free"))
	if flash != null:
		t.tween_callback(Callable(flash, "queue_free"))

func _global_to_local_ui(p: Vector2) -> Vector2:
	var inv: Transform2D = get_global_transform_with_canvas().affine_inverse()
	return inv * p
