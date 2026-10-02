extends Button
## One option on the New Chronicle screen (a race or a playstyle): an emblem
## on the left - a portrait crop or a drawn sigil - then the name, a line of
## flavour and the stat changes it brings. Toggle-mode inside a ButtonGroup;
## the chosen tile carries the gold frame and a crown flare, hover warms it.
##
## Focus follows hover like every front-end entry, so arrows and the mouse
## share one cursor; accept (or a click) chooses.

const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")
const FLARE := preload("res://assets/ui/menu/flare_star.png")

const GOLD := Color(0.86, 0.64, 0.36)
const GOLD_DIM := Color(0.6, 0.46, 0.29)
const UP := Color(0.93, 0.83, 0.6)
const DOWN := Color(0.86, 0.48, 0.4)
const ZERO := Color(0.55, 0.5, 0.44)

## "portrait" draws `portrait`; "magic" / "melee" / "ranged" draw a sigil.
var emblem: String = "portrait"
var portrait: Texture2D = null
var title_text := ""
var flavour := ""
## [label, value, is_percent]
var stats: Array = []

var _frame: Control
var _emblem: Control
var _portrait_rect: TextureRect
var _name: Label
var _flavour: Label
var _stats: RichTextLabel
var _flare: TextureRect
var _hover := 0.0
var _lit := 0.0
var _bg_style: StyleBoxFlat
var _applied_warmth := -1.0
var _focus_mark: Control
var _t := 0.0


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	flat = true
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_build()
	mouse_entered.connect(func() -> void:
		# Never pull focus out of a text field mid-word.
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit and (focus_owner as LineEdit).is_editing():
			return
		if not has_focus():
			grab_focus()
	)
	focus_entered.connect(func() -> void: _focus_mark.queue_redraw())
	focus_exited.connect(func() -> void: _focus_mark.queue_redraw())
	toggled.connect(func(on: bool) -> void:
		if on:
			_flare_crown()
	)
	resized.connect(_layout)
	_layout()


func configure(p_emblem: String, p_title: String, p_flavour: String, p_stats: Array, p_portrait: Texture2D = null) -> void:
	emblem = p_emblem
	title_text = p_title
	flavour = p_flavour
	stats = p_stats
	portrait = p_portrait
	if _name != null:
		_apply()


func _build() -> void:
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.028, 0.024, 0.021, 0.86)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	bg.add_theme_stylebox_override("panel", sb)
	_bg_style = sb
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_emblem = Control.new()
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem.clip_contents = true
	_emblem.draw.connect(_draw_emblem)
	add_child(_emblem)
	_portrait_rect = TextureRect.new()
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem.add_child(_portrait_rect)

	_name = Label.new()
	_name.theme_type_variation = &"ArcaneHeading"
	_name.add_theme_font_size_override("font_size", 22)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)
	_flavour = Label.new()
	_flavour.theme_type_variation = &"ArcaneItalic"
	_flavour.add_theme_font_size_override("font_size", 16)
	_flavour.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavour.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flavour)
	_stats = RichTextLabel.new()
	_stats.bbcode_enabled = true
	_stats.fit_content = true
	_stats.scroll_active = false
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_theme_font_size_override("normal_font_size", 15)
	_stats.add_theme_font_override("normal_font", get_theme_font("font", &"ArcaneCaption"))
	add_child(_stats)

	_frame = ArcaneFrameScript.new() as Control
	_frame.set("inset", 5.0)
	_frame.set("crown", true)
	add_child(_frame)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Focus has its own mark, apart from the chosen tile's warmth: a firm
	# underline under the name.
	_focus_mark = Control.new()
	_focus_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_mark.draw.connect(func() -> void:
		if has_focus():
			_focus_mark.draw_rect(Rect2(Vector2.ZERO, Vector2(_focus_mark.size.x, 2.0)), Color(0.99, 0.84, 0.58))
	)
	add_child(_focus_mark)

	_flare = TextureRect.new()
	_flare.texture = FLARE
	_flare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare.material = ArcaneParticles.additive()
	_flare.size = Vector2(70, 70)
	_flare.pivot_offset = _flare.size * 0.5
	_flare.modulate = Color(1.0, 0.82, 0.55, 0.0)
	add_child(_flare)
	_apply()


func _layout() -> void:
	if _emblem == null:
		return
	var h := size.y
	var side := h - 24.0
	_emblem.position = Vector2(14, 12)
	_emblem.size = Vector2(side * 0.82, side)
	_portrait_rect.position = Vector2(0, 2)
	_portrait_rect.size = Vector2(_emblem.size.x, _emblem.size.y * 1.55)
	var x := _emblem.position.x + _emblem.size.x + 18.0
	var w := maxf(40.0, size.x - x - 16.0)
	_name.position = Vector2(x, 12)
	_name.size = Vector2(w, 30)
	var name_w := minf(w, _name.get_theme_font("font").get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x) if _name.get_theme_font("font") != null else w
	_focus_mark.position = Vector2(x, 41)
	_focus_mark.size = Vector2(name_w, 3)
	_flavour.position = Vector2(x, 44)
	_flavour.size = Vector2(w, 40)
	_stats.position = Vector2(x, h - 52)
	_stats.size = Vector2(w, 44)
	_flare.position = Vector2(size.x * 0.5, 0.5) - _flare.size * 0.5
	_emblem.queue_redraw()


func _apply() -> void:
	_name.text = title_text
	_layout()
	_flavour.text = flavour
	_flavour.visible = flavour != ""
	_portrait_rect.texture = portrait if emblem == "portrait" else null
	var parts: Array[String] = []
	for entry: Array in stats:
		var value: float = entry[1]
		var percent: bool = entry[2]
		var shown := ("%+d%%" % roundi(value)) if percent else ("%+d" % roundi(value))
		var colour := UP if value > 0.0 else (DOWN if value < 0.0 else ZERO)
		parts.append("[color=#%s]%s %s[/color]" % [ZERO.to_html(false), entry[0], ""] + "[color=#%s]%s[/color]" % [colour.to_html(false), shown])
	# Two rows of three, so the six numbers line up instead of wrapping anywhere.
	var rows: Array[String] = []
	for i in range(0, parts.size(), 3):
		rows.append("   ".join(parts.slice(i, i + 3)))
	_stats.text = "\n".join(rows)
	_emblem.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var target_hover := 1.0 if (has_focus() or is_hovered()) and not disabled else 0.0
	_hover = move_toward(_hover, target_hover, delta * 6.0)
	_lit = move_toward(_lit, 1.0 if button_pressed else 0.0, delta * 5.0)
	var warmth := maxf(_lit, _hover * 0.5)
	if absf(warmth - _applied_warmth) > 0.004:
		_applied_warmth = warmth
		_frame.set("glow", warmth)
		_name.add_theme_color_override("font_color", Color(0.86, 0.78, 0.62).lerp(Color(1.0, 0.9, 0.7), warmth))
		# Tint only: the screen's staggered intro owns the alpha.
		var alpha := modulate.a
		modulate = Color(1, 1, 1, 1).lerp(Color(0.78, 0.76, 0.74, 1), (1.0 - warmth) * 0.35)
		modulate.a = alpha
		_emblem.queue_redraw()
		# The chosen tile is lit from within, not only outlined.
		_bg_style.bg_color = Color(0.028, 0.024, 0.021, 0.86).lerp(Color(0.085, 0.058, 0.036, 0.92), _lit)
	if (emblem == "magic" or emblem == "ranged") and not ArcaneMotion.reduced():
		_emblem.queue_redraw()


func _flare_crown() -> void:
	if ArcaneMotion.reduced():
		_flare.scale = Vector2.ONE * 0.8
		_flare.modulate.a = 0.8
		create_tween().tween_property(_flare, "modulate:a", 0.0, 0.5)
		return
	_flare.scale = Vector2.ONE * 0.2
	_flare.rotation = -PI * 0.25
	_flare.modulate.a = 1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_flare, "scale", Vector2.ONE * 1.3, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_flare, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_flare, "modulate:a", 0.0, 0.6)


func _draw_emblem() -> void:
	var r := _emblem.size
	var warmth := maxf(_lit, _hover * 0.5)
	var col := GOLD_DIM.lerp(GOLD, warmth)
	# The window the emblem sits in.
	_emblem.draw_rect(Rect2(Vector2.ZERO, r), Color(0.05, 0.042, 0.036, 1.0))
	if emblem == "portrait":
		# A warm pool behind the bust.
		_emblem.draw_circle(Vector2(r.x * 0.5, r.y * 0.62), r.x * 0.52, Color(1.0, 0.6, 0.28, 0.08 + 0.1 * warmth))
	else:
		StyleSigil.draw(_emblem, emblem, Vector2(r.x * 0.5, r.y * 0.5), minf(r.x, r.y) * 0.36, col, _t if not ArcaneMotion.reduced() else 0.0, warmth)
	_emblem.draw_rect(Rect2(Vector2(0.5, 0.5), r - Vector2.ONE), Color(col, 0.6), false, 1.0, true)


## The three playstyles' marks, drawn so they need no art: Magic a ringed
## star, Melee two crossed blades, Ranged a drawn bow. Shared with the large
## preview on the New Chronicle screen.
class StyleSigil:
	static func draw(ci: CanvasItem, kind: String, c: Vector2, size: float, col: Color, t: float, warmth: float) -> void:
		var faint := Color(col, col.a * 0.45)
		match kind:
			"magic":
				ci.draw_arc(c, size, 0.0, TAU, 64, col, 1.6, true)
				ci.draw_arc(c, size * 0.78, 0.0, TAU, 48, faint, 1.0, true)
				var points := PackedVector2Array()
				for i in range(6):
					var a := -PI * 0.5 + TAU * float(i * 2 % 5) / 5.0 + t * 0.1
					points.append(c + Vector2.from_angle(a) * size * 0.74)
				ci.draw_polyline(points, col, 1.4, true)
				for i in range(8):
					var a := t * -0.2 + TAU * float(i) / 8.0
					ci.draw_circle(c + Vector2.from_angle(a) * size * 1.12, 1.6 + warmth, faint)
			"melee":
				var d := size * 1.05
				ci.draw_polyline(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0), c + Vector2(0, -d)]), faint, 1.0, true)
				for side in [-1.0, 1.0]:
					var tip := c + Vector2(side * size * 0.7, -size * 0.75)
					var hilt := c + Vector2(-side * size * 0.55, size * 0.6)
					ci.draw_line(hilt, tip, col, 2.0, true)
					var along := (tip - hilt).normalized()
					var across := Vector2(-along.y, along.x)
					var guard := hilt + along * size * 0.28
					ci.draw_line(guard - across * size * 0.2, guard + across * size * 0.2, col, 1.6, true)
					ci.draw_line(hilt, hilt - along * size * 0.14, col, 2.4, true)
			"ranged":
				ci.draw_arc(c + Vector2(size * 0.25, 0), size * 0.95, PI * 0.62, PI * 1.38, 40, col, 1.8, true)
				var top := c + Vector2(size * 0.25, 0) + Vector2.from_angle(PI * 0.62) * size * 0.95
				var bottom := c + Vector2(size * 0.25, 0) + Vector2.from_angle(PI * 1.38) * size * 0.95
				var pull := 0.08 * sin(t * 1.4) * size
				var nock := c + Vector2(size * 0.42 + pull, 0)
				ci.draw_polyline(PackedVector2Array([top, nock, bottom]), faint, 1.0, true)
				ci.draw_line(nock, c + Vector2(-size * 1.0, 0), col, 1.6, true)
				var head := c + Vector2(-size * 1.0, 0)
				ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-8, 0), head + Vector2(4, -6), head + Vector2(4, 6)]), col)
				for k in range(2):
					var fx := nock + Vector2(-6.0 - k * 7.0, 0)
					ci.draw_line(fx, fx + Vector2(6, -6), faint, 1.2, true)
					ci.draw_line(fx, fx + Vector2(6, 6), faint, 1.2, true)
			_:
				ci.draw_arc(c, size, 0.0, TAU, 48, col, 1.4, true)
