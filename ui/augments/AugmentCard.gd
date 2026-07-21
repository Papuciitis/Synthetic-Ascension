extends Button

signal picked(augment: AugmentData, card_node: Control)
signal hovered(augment: AugmentData, card_node: Control)
signal unhovered(card_node: Control)

@export var base_bg := Color(0.18, 0.18, 0.18)
@export var base_border := Color(0.10, 0.10, 0.10)
@export var hover_border := Color(1.0, 0.55, 0.20)
@export var pressed_border := Color(1.0, 0.35, 0.00)
@export var corner_radius := 14
@export var border_width := 2

var data: AugmentData = null
var _hovered: bool = false
var _style: StyleBoxFlat
var _tw: Tween = null

var icon_rect: TextureRect = null
var name_label: Label = null
var desc_label: Label = null
var _nodes_cached: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_NONE
	flat = false

	_cache_nodes()
	_build_style()
	_update_style()
	call_deferred("_init_pivot")

	# If set_data() was called before _ready(), apply now.
	_apply_data()

	mouse_entered.connect(func():
		_hovered = true
		_update_style()
		_hover_fx(true)
		if data != null:
			hovered.emit(data, self)
	)

	mouse_exited.connect(func():
		_hovered = false
		_update_style()
		_hover_fx(false)
		unhovered.emit(self)
	)

	pressed.connect(func():
		if data != null:
			picked.emit(data, self)
	)

	button_down.connect(func():
		if _tw != null:
			_tw.kill()
		var s0 := scale
		_tw = create_tween()
		_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "scale", s0 * 0.98, 0.04)
		_tw.tween_property(self, "scale", s0, 0.08)
	)


func _cache_nodes() -> void:
	if _nodes_cached:
		return
	_nodes_cached = true

	# Prefer explicit paths (stable), fall back to find_child for resilience.
	icon_rect = get_node_or_null("Margin/VBox/IconFrame/Icon") as TextureRect
	if icon_rect == null:
		icon_rect = find_child("Icon", true, false) as TextureRect

	name_label = get_node_or_null("Margin/VBox/Name") as Label
	if name_label == null:
		name_label = find_child("Name", true, false) as Label

	desc_label = get_node_or_null("Margin/VBox/DescPanel/DescMargin/Desc") as Label
	if desc_label == null:
		desc_label = find_child("Desc", true, false) as Label

	# Keep the card text readable (short flavor on the card; full numbers on hover tooltip)
	if desc_label != null:
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.clip_text = true
		desc_label.max_lines_visible = 3
		desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		# Force readability regardless of theme overrides elsewhere.
		desc_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.86))
		desc_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
		desc_label.add_theme_constant_override("outline_size", 5)
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if name_label != null:
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.90))
		name_label.add_theme_constant_override("outline_size", 6)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _init_pivot() -> void:
	pivot_offset = size * 0.5


func set_data(a: AugmentData) -> void:
	data = a
	# AugmentSelect may call set_data() right after add_child(), before this node is ready.
	if is_node_ready():
		_apply_data()
	else:
		call_deferred("_apply_data")


func _apply_data() -> void:
	_cache_nodes()
	if data == null:
		return

	if name_label != null:
		name_label.text = data.display_name
	if desc_label != null:
		# Keep the card short and readable; full details live in the hover tooltip.
		# Prefer an explicit short blurb if provided by the resource.
		var blurb: String = ""
		# Direct property access is more reliable than Object.get() for script resources.
		blurb = String(data.card_blurb)
		blurb = blurb.strip_edges()
		if blurb == "":
			blurb = _card_flavor(data.description)
		desc_label.text = blurb
		desc_label.visible = true
	if icon_rect != null:
		icon_rect.texture = data.icon


func _card_flavor(s: String, max_chars: int = 95) -> String:
	var t := s.strip_edges()
	if t == "":
		return ""

	# Flatten newlines so wrapping behaves predictably.
	t = t.replace("\n", " ").replace("\r", " ")
	while t.find("  ") != -1:
		t = t.replace("  ", " ")

	if t.length() <= max_chars:
		return t

	var cut := t.substr(0, max_chars)
	var last_space := cut.rfind(" ")
	if last_space >= int(max_chars * 0.6):
		cut = cut.substr(0, last_space)
	return cut + "…"


func _build_style() -> void:
	_style = StyleBoxFlat.new()
	_style.corner_radius_top_left = corner_radius
	_style.corner_radius_top_right = corner_radius
	_style.corner_radius_bottom_left = corner_radius
	_style.corner_radius_bottom_right = corner_radius
	_style.set_border_width_all(border_width)
	_style.bg_color = base_bg
	_style.border_color = base_border
	_style.shadow_size = 10
	_style.shadow_offset = Vector2(0, 6)
	_style.shadow_color = Color(0, 0, 0, 0.35)

	add_theme_stylebox_override("normal", _style)
	add_theme_stylebox_override("hover", _style)
	add_theme_stylebox_override("pressed", _style)
	add_theme_stylebox_override("focus", _style)


func _update_style() -> void:
	if _style == null:
		return

	if icon_rect != null:
		icon_rect.modulate = (Color(1, 1, 1, 1) if _hovered else Color(1, 1, 1, 0.88))

	var border := base_border
	if button_pressed:
		border = pressed_border
	elif _hovered:
		border = hover_border

	_style.border_color = border
	_style.bg_color = base_bg.lightened(0.04) if _hovered else base_bg


func _hover_fx(on: bool) -> void:
	if _tw != null:
		_tw.kill()
		_tw = null

	_tw = create_tween()
	_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var target_scale := Vector2(1.03, 1.03) if on else Vector2(1.0, 1.0)
	_tw.tween_property(self, "scale", target_scale, 0.10)

	if icon_rect != null:
		var target_mod := Color(1.10, 1.10, 1.10, 1.0) if on else Color(1, 1, 1, 1)
		_tw.parallel().tween_property(icon_rect, "modulate", target_mod, 0.10)
