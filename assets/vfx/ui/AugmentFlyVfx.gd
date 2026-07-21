extends Control
class_name AugmentFlyVfx

@export var augments_panel_path: NodePath = NodePath("../TopLeft/Margin/VBox/BodyRow/AugmentsPanel")
@export var slot_icon_path_format: String = "Aug%d/Content/Icon" # % (slot_index+1)

@export var fly_duration: float = 0.42
@export var shrink_duration: float = 0.10
@export var end_scale: float = 0.45

signal fly_finished(slot_index: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	z_index = 2000
	z_as_relative = false

# Call this from AugmentSelect after you decide slot_index
func fly_card_to_slot(source_card: Control, slot_index: int) -> void:
	if source_card == null or not is_instance_valid(source_card):
		return

	var panel: Node = get_node_or_null(augments_panel_path)
	if panel == null:
		push_warning("[AugmentFlyVfx] augments_panel_path not found: %s" % [str(augments_panel_path)])
		return

	var icon_path: String = slot_icon_path_format % (slot_index + 1)
	var target_icon: Control = panel.get_node_or_null(icon_path) as Control
	if target_icon == null:
		push_warning("[AugmentFlyVfx] target icon not found at: %s" % icon_path)
		return

	# Let one frame render before capture (helps viewport capture stability)
	await get_tree().process_frame

	var start_rect: Rect2 = source_card.get_global_rect()
	var tex: Texture2D = _capture_rect_texture(start_rect)

	if tex == null:
		tex = _find_best_icon_texture(source_card)
		if tex == null:
			push_warning("[AugmentFlyVfx] Could not capture card or find icon texture.")
			return
		start_rect = source_card.get_global_rect()

	var fly: TextureRect = TextureRect.new()
	fly.name = "FlyCard"
	fly.texture = tex
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.stretch_mode = TextureRect.STRETCH_SCALE
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.modulate = Color(1, 1, 1, 1)
	add_child(fly)

	fly.top_level = true
	fly.global_position = start_rect.position
	fly.size = start_rect.size

	var target_rect: Rect2 = target_icon.get_global_rect()

	var start_pos: Vector2 = start_rect.position
	var start_size: Vector2 = start_rect.size

	var end_size: Vector2 = start_size * end_scale
	end_size.x = clampf(end_size.x, 24.0, target_rect.size.x * 1.15)
	end_size.y = clampf(end_size.y, 24.0, target_rect.size.y * 1.15)

	var target_center: Vector2 = target_rect.position + target_rect.size * 0.5
	var end_pos: Vector2 = target_center - end_size * 0.5

	# Tiny click shrink on the real card (layout-safe)
	_pulse_shrink(source_card)

	# Animate using real-time ticks (ignores Engine.time_scale)
	await _animate_fly_realtime(fly, start_pos, start_size, end_pos, end_size, fly_duration)

	# Pop the target
	_target_pop(target_icon)

	if is_instance_valid(fly):
		fly.queue_free()

	emit_signal("fly_finished", slot_index)

# ---------------------------------------------------------
# REAL-TIME ANIMATION (ignores time_scale)
# ---------------------------------------------------------

func _animate_fly_realtime(fly: TextureRect, p0: Vector2, s0: Vector2, p1: Vector2, s1: Vector2, dur: float) -> void:
	if fly == null or not is_instance_valid(fly):
		return

	var start_ms: int = Time.get_ticks_msec()
	var dur_ms: float = max(dur, 0.01) * 1000.0
	var timeout_ms: int = int(dur_ms + 500.0) # safety

	while true:
		if fly == null or not is_instance_valid(fly):
			return

		var now_ms: int = Time.get_ticks_msec()
		var elapsed: int = now_ms - start_ms
		if elapsed >= timeout_ms:
			break

		var t: float = clampf(float(elapsed) / dur_ms, 0.0, 1.0)
		var e: float = _ease_out_quad(t)

		fly.global_position = p0.lerp(p1, e)
		fly.size = s0.lerp(s1, e)

		# Fade near the end
		if t >= 0.65:
			var ft: float = clampf((t - 0.65) / 0.35, 0.0, 1.0)
			var a: float = lerpf(1.0, 0.0, ft)
			var m: Color = fly.modulate
			m.a = a
			fly.modulate = m

		if t >= 1.0:
			break

		await get_tree().process_frame

func _ease_out_quad(t: float) -> float:
	var inv: float = 1.0 - t
	return 1.0 - inv * inv

# ---------------------------------------------------------
# Small helper effects
# ---------------------------------------------------------

func _pulse_shrink(card: Control) -> void:
	if card == null or not is_instance_valid(card):
		return

	# This uses tween BUT it's purely cosmetic; if time_scale=0 it won't animate,
	# and that's fine. It will not block anything.
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var s0: Vector2 = card.scale
	tw.tween_property(card, "scale", s0 * 0.96, shrink_duration)
	tw.tween_property(card, "scale", s0, shrink_duration)

func _target_pop(target: Control) -> void:
	if target == null or not is_instance_valid(target):
		return

	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)

	var s0: Vector2 = target.scale
	tw.tween_property(target, "scale", s0 * 1.08, 0.10)
	tw.tween_property(target, "scale", s0, 0.12)

# ---------------------------------------------------------
# Snapshot capture
# ---------------------------------------------------------

func _capture_rect_texture(global_rect: Rect2) -> Texture2D:
	var vp: Viewport = get_viewport()
	var vp_tex: ViewportTexture = vp.get_texture()
	if vp_tex == null:
		return null

	var img: Image = vp_tex.get_image()
	if img == null:
		return null

	var img_w: int = img.get_width()
	var img_h: int = img.get_height()
	if img_w <= 0 or img_h <= 0:
		return null

	var x: int = int(floor(global_rect.position.x))
	var y: int = int(floor(global_rect.position.y))
	var w: int = int(ceil(global_rect.size.x))
	var h: int = int(ceil(global_rect.size.y))

	if w <= 2 or h <= 2:
		return null

	if x < 0:
		w += x
		x = 0
	if y < 0:
		h += y
		y = 0
	if x + w > img_w:
		w = img_w - x
	if y + h > img_h:
		h = img_h - y

	if w <= 2 or h <= 2:
		return null

	var r: Rect2i = Rect2i(Vector2i(x, y), Vector2i(w, h))
	var region: Image = img.get_region(r)
	if region == null:
		return null

	return ImageTexture.create_from_image(region)

func _find_best_icon_texture(root: Control) -> Texture2D:
	var icon: TextureRect = root.find_child("Icon", true, false) as TextureRect
	if icon != null and icon.texture != null:
		return icon.texture

	var kids: Array[Node] = root.get_children()
	for n: Node in kids:
		var tex_rect: TextureRect = n as TextureRect
		if tex_rect != null and tex_rect.texture != null:
			return tex_rect.texture

	return null
