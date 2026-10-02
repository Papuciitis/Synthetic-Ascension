class_name ArcaneMenuItem
extends Button
## A front-end menu entry in the register of the main-menu mock-up: a gold
## diamond, a Cinzel caption and a faint rule; when selected the gold brush
## stroke wipes in behind it, its star flares, a few sparks fly along the paint
## and the caption turns to dark ink.
##
## Selection is focus. Hovering takes focus, so mouse, keyboard and controller
## share one cursor; `selected` fires when this entry gains it. The caption is
## the Button's own `text` (drawn transparent by the ArcaneMenuButton theme
## type) so callers and tests keep reading and writing `text`.

signal selected(item: ArcaneMenuItem)

const HIGHLIGHT := preload("res://assets/ui/menu/menu_highlight.png")
const FLARE := preload("res://assets/ui/menu/flare_star.png")
const NOISE := preload("res://assets/ui/menu/cloud_noise.png")
const HIGHLIGHT_SHADER := preload("res://ui/shaders/menu_highlight.gdshader")
const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

## The star painted into menu_highlight.png, in its pixels, and the
## nine-patch margins that keep the star end and the ragged tip unstretched.
const HIGHLIGHT_STAR := Vector2(63.0, 56.0)
const HIGHLIGHT_PATCH_LEFT := 128
const HIGHLIGHT_PATCH_RIGHT := 72

const CREAM := Color(0.91, 0.86, 0.77)
const INK := Color(0.13, 0.08, 0.045)
const GOLD := Color(0.86, 0.64, 0.36)
const GOLD_DIM := Color(0.62, 0.47, 0.3)
const GOLD_BRIGHT := Color(0.99, 0.84, 0.58)

## The world's answer when this entry is selected (ArcaneBackdrop.MOODS).
@export var mood: StringName = &"calm"
@export var font_size: int = 30
@export var row_height: float = 70.0
## Extra paint past the end of the caption, as in the mock-up.
@export var stroke_tail: float = 150.0
@export var show_rule: bool = true
@export var rule_ornament: bool = false
## Off for tabs: focus only brightens the caption; the paint marks `active`.
@export var stroke_on_focus: bool = true
## Tabs: the active entry keeps its stroke while focus is elsewhere.
@export var active: bool = false:
	set(value):
		if active == value:
			return
		active = value
		if is_node_ready():
			_refresh()

var _highlight_root: Control
var _highlight: NinePatchRect
var _highlight_mat: ShaderMaterial
var _icon: Control
var _label: Label
var _rule: Control
var _mark: Control
var _flare: TextureRect
var _sparks: CPUParticles2D
var _tween: Tween
var _flare_tween: Tween
var _focused := false
var _stroked := false
var _reveal := 0.0
var _ink := 0.0
var _t := 0.0
var _quiet_once := false


func _ready() -> void:
	theme_type_variation = &"ArcaneMenuButton"
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_build()
	_fit()
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	button_down.connect(_on_button_down)
	pressed.connect(_on_pressed)
	resized.connect(_layout)
	_refresh()


## Take focus without the hover sound (initial focus on screen entry).
func select_quietly() -> void:
	_quiet_once = true
	grab_focus()


func is_selected() -> bool:
	return _focused


func set_caption(value: String) -> void:
	text = value
	if _label != null:
		_label.text = value
		_fit()


func _build() -> void:
	# Scaled as a whole so the star end and the ragged tip keep their shape;
	# only the paint between them stretches to fit the caption.
	_highlight_root = Control.new()
	_highlight_root.name = "HighlightRoot"
	_highlight_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_highlight_root)
	_highlight = NinePatchRect.new()
	_highlight.name = "Highlight"
	_highlight.texture = HIGHLIGHT
	_highlight.patch_margin_left = HIGHLIGHT_PATCH_LEFT
	_highlight.patch_margin_right = HIGHLIGHT_PATCH_RIGHT
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_mat = ShaderMaterial.new()
	_highlight_mat.shader = HIGHLIGHT_SHADER
	_highlight_mat.set_shader_parameter("noise_tex", NOISE)
	_highlight_mat.set_shader_parameter("reveal", 0.0)
	_highlight_mat.set_shader_parameter("sheen_phase", fmod(float(get_index()) * 0.37, 1.0))
	_highlight.material = _highlight_mat
	_highlight.visible = false
	_highlight_root.add_child(_highlight)

	_icon = Control.new()
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	add_child(_icon)

	_label = Label.new()
	_label.name = "Caption"
	_label.text = text
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", get_theme_font("font"))
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_label)

	_rule = Control.new()
	_rule.name = "Rule"
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.draw.connect(_draw_rule)
	add_child(_rule)

	# Focus for entries that do not paint on focus (tabs): a firm underline
	# under the caption, ink on the stroke, gold off it.
	_mark = Control.new()
	_mark.name = "FocusMark"
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.draw.connect(_draw_mark)
	add_child(_mark)

	_flare = TextureRect.new()
	_flare.name = "Flare"
	_flare.texture = FLARE
	_flare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare.material = ArcaneParticles.additive()
	_flare.modulate = Color(1.0, 0.85, 0.6, 0.0)
	add_child(_flare)

	_sparks = ArcaneParticles.select_sparks()
	_sparks.name = "Sparks"
	add_child(_sparks)


func _icon_centre() -> Vector2:
	return Vector2(row_height * 0.4, row_height * 0.5)


func _label_x() -> float:
	return row_height * 0.4 + font_size * 1.15


func _fit() -> void:
	if _label == null:
		return
	var font := _label.get_theme_font("font")
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font != null else 200.0
	custom_minimum_size = Vector2(_label_x() + text_width + stroke_tail, row_height)
	_layout()


func _layout() -> void:
	if _highlight == null:
		return
	var h := size.y if size.y > 0.0 else row_height
	var centre := Vector2(row_height * 0.4, h * 0.5)
	var k := (h * 1.12) / float(HIGHLIGHT.get_height())
	var width_px := maxf(float(HIGHLIGHT.get_width()), (size.x - centre.x) / k + HIGHLIGHT_STAR.x)
	_highlight_root.scale = Vector2(k, k)
	_highlight_root.position = centre - HIGHLIGHT_STAR * k
	_highlight.size = Vector2(width_px, HIGHLIGHT.get_height())
	_icon.position = centre - Vector2(16, 16)
	_icon.size = Vector2(32, 32)
	_label.position = Vector2(_label_x(), 0)
	_label.size = Vector2(maxf(0.0, size.x - _label_x()), h)
	_rule.position = Vector2(_label_x(), h - 6)
	var caption_w := 0.0
	var font := _label.get_theme_font("font")
	if font != null:
		caption_w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_mark.position = Vector2(_label_x(), h * 0.5 + font_size * 0.62)
	_mark.size = Vector2(caption_w, 3)
	_rule.size = Vector2(maxf(0.0, size.x - _label_x() - stroke_tail * 0.35), 6)
	var flare_size := Vector2.ONE * h * 1.25
	_flare.size = flare_size
	_flare.pivot_offset = flare_size * 0.5
	_flare.position = centre - flare_size * 0.5
	_sparks.position = centre
	_icon.queue_redraw()
	_rule.queue_redraw()


func _draw_icon() -> void:
	var c := _icon.size * 0.5
	var r := 9.0 if row_height >= 60.0 else 7.0
	var points := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
	var colour := GOLD if (has_focus() or is_hovered()) else GOLD_DIM
	_icon.draw_polyline(points, colour, 1.6, true)
	var inner := r * 0.38
	_icon.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -inner), c + Vector2(inner, 0), c + Vector2(0, inner), c + Vector2(-inner, 0)]), colour)
	# The long diamond points of the mock-up's icon.
	_icon.draw_line(c + Vector2(-r - 5, 0), c + Vector2(-r - 1, 0), Color(colour, 0.6), 1.0, true)
	_icon.draw_line(c + Vector2(r + 1, 0), c + Vector2(r + 5, 0), Color(colour, 0.6), 1.0, true)


func _draw_rule() -> void:
	if not show_rule:
		return
	var w := _rule.size.x
	var y := _rule.size.y * 0.5
	var steps := 24
	for i in range(steps):
		var a := float(i) / steps
		var b := float(i + 1) / steps
		var fade := sin(a * PI) * 0.55 + 0.1
		_rule.draw_line(Vector2(w * a, y), Vector2(w * b, y), Color(GOLD_DIM, 0.42 * fade), 1.0, true)
	if rule_ornament:
		var c := Vector2(w * 0.5, y)
		var r := 3.5
		_rule.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), Color(GOLD_DIM, 0.7))


func _draw_mark() -> void:
	if stroke_on_focus or not _focused:
		return
	var colour := INK if _stroked else GOLD_BRIGHT
	_mark.draw_rect(Rect2(Vector2.ZERO, Vector2(_mark.size.x, 2.0)), colour)


func _process(delta: float) -> void:
	_t += delta
	if _stroked and _flare_tween == null:
		if ArcaneMotion.reduced():
			_flare.modulate.a = 0.55
			_flare.rotation = 0.0
		else:
			_flare.modulate.a = 0.5 + 0.14 * sin(_t * 2.3)
			_flare.rotation = sin(_t * 0.7) * 0.08


func _on_mouse_entered() -> void:
	if disabled or focus_mode == Control.FOCUS_NONE:
		return
	# Never pull focus out of a text field mid-word.
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit and (focus_owner as LineEdit).is_editing():
		return
	if not has_focus():
		grab_focus()


func _on_focus_entered() -> void:
	if _focused:
		return
	_focused = true
	if not _quiet_once and is_inside_tree() and SfxManager != null:
		SfxManager.play_ui(&"ui_hover")
	_quiet_once = false
	_refresh()
	selected.emit(self)


func _on_focus_exited() -> void:
	if not _focused:
		return
	_focused = false
	_refresh()


func _refresh() -> void:
	var want := active or (_focused and stroke_on_focus)
	if want != _stroked:
		_stroked = want
		_animate(want)
	_apply_visuals()
	if _icon != null:
		_icon.queue_redraw()
	if _mark != null:
		_mark.queue_redraw()


func _on_button_down() -> void:
	if _highlight_mat == null:
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _highlight_mat.set_shader_parameter("glow", v), 1.0, 0.0, 0.35)
	if not ArcaneMotion.reduced():
		_burst(1.9)


func _on_pressed() -> void:
	if is_inside_tree() and SfxManager != null:
		SfxManager.play_ui(&"ui_click")


func _animate(on: bool) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	if not on and ArcaneMotion.reduced():
		# Instant, and no Tween: an empty one is an engine error.
		_set_reveal(0.0)
		_set_ink(0.0)
		if _flare_tween != null and _flare_tween.is_running():
			_flare_tween.kill()
		_flare_tween = null
		_flare.modulate.a = 0.0
		_icon.queue_redraw()
		return
	_tween = create_tween().set_parallel(true)
	if on and ArcaneMotion.reduced():
		# Reduced motion: the stroke is simply there, the star rests lit.
		_set_reveal(1.0)
		_set_ink(1.0)
		_flare.scale = Vector2.ONE * 0.85
		_flare.rotation = 0.0
		_tween.tween_property(_flare, "modulate:a", 0.55, 0.12)
	elif on:
		_tween.tween_method(_set_reveal, _reveal, 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_ink, _ink, 1.0, 0.16)
		_burst(1.55)
		_sparks.restart()
		_sparks.emitting = true
	else:
		_tween.tween_method(_set_reveal, _reveal, 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_method(_set_ink, _ink, 0.0, 0.14)
		if _flare_tween != null and _flare_tween.is_running():
			_flare_tween.kill()
		_flare_tween = null
		_tween.tween_property(_flare, "modulate:a", 0.0, 0.15)
	_icon.queue_redraw()


func _burst(peak: float) -> void:
	if _flare_tween != null and _flare_tween.is_running():
		_flare_tween.kill()
	_flare.scale = Vector2.ONE * 0.2
	_flare.rotation = -PI * 0.25
	_flare.modulate.a = 1.0
	_flare_tween = create_tween().set_parallel(true)
	_flare_tween.tween_property(_flare, "scale", Vector2.ONE * peak, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flare_tween.tween_property(_flare, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flare_tween.chain().tween_property(_flare, "scale", Vector2.ONE * 0.85, 0.45).set_trans(Tween.TRANS_SINE)
	_flare_tween.parallel().tween_property(_flare, "modulate:a", 0.55, 0.45)
	_flare_tween.chain().tween_callback(func() -> void: _flare_tween = null)


func _set_reveal(v: float) -> void:
	_reveal = v
	# Hidden at rest: the shader's mask is fully clear at 0, so skip the pass.
	_highlight.visible = v > 0.0
	_highlight_mat.set_shader_parameter("reveal", v)
	_rule.modulate.a = 1.0 - v
	_icon.modulate.a = 1.0 - smoothstep(0.0, 0.35, v)


func _set_ink(v: float) -> void:
	_ink = v
	_apply_visuals()


func _apply_visuals() -> void:
	if _label == null:
		return
	var base := CREAM
	if disabled:
		base = Color(CREAM, 0.38)
	elif _focused and not _stroked:
		base = GOLD_BRIGHT
	_label.add_theme_color_override("font_color", base.lerp(INK, _ink))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65 * (1.0 - _ink)))
	_label.position.x = _label_x() + (0.0 if ArcaneMotion.reduced() else 5.0 * _ink)
