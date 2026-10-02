extends RefCounted
## Shared presentation for the HUD's overlays, tooltips, notices and story
## cards in the front end's register (docs/design/2026-10-02-front-end-arcane-
## register.md): the palette, the square gold-ruled boxes these surfaces set on
## their own panels (built here once and shared, so neither theme is touched),
## the fonts, a real-time clock and the entrance motions.
##
## Preload by path; no class_name. Every motion honours Reduced Motion and
## runs on real time: hit-stop, the opening's slowed beat and the augment pick
## all change Engine.time_scale under these surfaces, and several of them are
## shown while the tree is paused.

const ARCANE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const HUD_THEME := preload("res://ui/theme/SyntheticHudTheme.tres")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")
const GARAMOND := preload("res://assets/fonts/eb_garamond/EBGaramond-Variable.ttf")
const CINZEL := preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")

const PARCHMENT := Color(0.91, 0.86, 0.77)
const BODY := Color(0.82, 0.77, 0.68)
const MUTED := Color(0.62, 0.56, 0.47)
const GOLD := Color(0.86, 0.64, 0.36)
const GOLD_DIM := Color(0.62, 0.47, 0.30)
const GOLD_BRIGHT := Color(0.99, 0.84, 0.58)
const INK := Color(0.13, 0.08, 0.045)
const PANEL := Color(0.032, 0.028, 0.025)
const EMBER := Color(1.0, 0.62, 0.30)
const ARCANE := Color(0.42, 0.62, 1.0)
const DANGER := Color(0.86, 0.32, 0.24)
## Blessings, gains and completed steps: a muted verdigris that sits beside
## the gold without reading as a status light.
const SAGE := Color(0.64, 0.79, 0.56)
## Curses and losses in prose: the danger red, lifted for small text.
const CURSE := Color(0.9, 0.47, 0.38)
## The synthetic voice of the opening only, and only on its rule and caption.
const TEAL := Color(0.42, 0.76, 0.78)
## Text sitting straight on the world needs a dark rim to survive bright tiles.
const RIM := Color(0.02, 0.015, 0.01, 0.92)

static var _boxes: Dictionary = {}
static var _fonts: Dictionary = {}
static var _clock_frame: int = -10
static var _clock_usec: int = 0
static var _clock_step: float = 0.0


static func reduced() -> bool:
	return ArcaneMotion.reduced()


## The real seconds behind a scaled frame delta. A card's clock (typewriter,
## hold, fade) must not stretch under hit-stop or stop with the augment pick's
## time_scale of 0. At a time scale of 1 the frame's own delta is returned
## (so a suite can drive a clock by hand); otherwise the wall-clock time of
## the frame, measured once per frame and shared. Dividing by time_scale is
## not enough: hit-stop changes it in the middle of a frame, after the delta
## was scaled, and a card would leap or stall at every hit.
static func real_delta(delta: float) -> float:
	if is_equal_approx(Engine.time_scale, 1.0):
		return delta
	var frame := Engine.get_process_frames()
	if frame != _clock_frame:
		var now := Time.get_ticks_usec()
		if frame == _clock_frame + 1:
			_clock_step = clampf(float(now - _clock_usec) / 1000000.0, 0.0, 0.1)
		else:
			# The first frame after a gap has no previous mark; one frame stands in.
			_clock_step = clampf(1.0 / maxf(1.0, Engine.get_frames_per_second()), 0.0, 0.1)
		_clock_frame = frame
		_clock_usec = now
	return _clock_step


# ------------------------------------------------------------------ fonts

## The register's faces, read from the front-end theme so a change there
## reaches every overlay: `title` (Cinzel Decorative), `heading` (Cinzel 600),
## `caption` (Cinzel 500), `body` (EB Garamond), `italic`, and `semi`
## (Garamond 600, for prose that has to hold up over the world).
static func font(kind: StringName) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var out: Font = null
	match kind:
		&"title":
			out = ARCANE_THEME.get_font(&"font", &"ArcaneTitle")
		&"heading":
			out = ARCANE_THEME.get_font(&"font", &"ArcaneHeading")
		&"caption":
			out = ARCANE_THEME.get_font(&"font", &"ArcaneCaption")
		&"body":
			out = ARCANE_THEME.get_font(&"font", &"ArcaneBody")
		&"italic":
			out = ARCANE_THEME.get_font(&"font", &"ArcaneItalic")
		&"semi":
			out = _variation(GARAMOND, 600, 0)
		&"figure":
			out = _variation(CINZEL, 700, 1)
	if out == null:
		out = ThemeDB.fallback_font
	_fonts[kind] = out
	return out


static func _variation(base: Font, weight: int, glyph_spacing: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	variation.spacing_glyph = glyph_spacing
	return variation


## Sets a label's face, size and colour once (never per frame). `rim` gives
## text drawn straight over the world a dark outline of that width.
static func style_label(label: Label, kind: StringName, font_size: int, colour: Color, rim: int = 0) -> void:
	if label == null:
		return
	label.add_theme_font_override(&"font", font(kind))
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", colour)
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	if rim > 0:
		label.add_theme_color_override(&"font_outline_color", RIM)
		label.add_theme_constant_override(&"outline_size", rim)


# ------------------------------------------------------------------ boxes

## A square box: fill, a rule, optional content margins and shadow. A 1 px
## edge can fall between pixel centres at a non-native window scale (0.93 at
## 1784 x 1004) and vanish, so a 1 px request becomes 2 px at ~60 % alpha,
## the same weight that always lands on a pixel (ChamberKit does the same).
static func box(bg: Color, border: Color, border_width: int = 1, margin: float = 0.0, shadow: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if border_width == 1:
		border_width = 2
		border = Color(border, border.a * 0.6)
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = false
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.4)
	return sb


## Shared (cached) boxes by name, so every tooltip, card and notice shares a
## handful of StyleBox objects instead of building its own.
static func shared(key: StringName) -> StyleBox:
	if _boxes.has(key):
		return _boxes[key]
	var sb: StyleBox
	match key:
		&"tip":
			sb = box(Color(0.028, 0.024, 0.021, 0.97), Color(GOLD_DIM, 0.95), 1, 0.0, 14)
		&"tip_well":
			sb = box(Color(0.012, 0.011, 0.01, 1.0), Color(0.42, 0.32, 0.2, 0.9))
		&"notice":
			sb = box(Color(PANEL, 0.93), Color(GOLD_DIM, 0.95), 1, 0.0, 16)
		&"card":
			# The ornament (ArcaneFrame) draws the rules; this is the ground.
			var card := box(Color(0.03, 0.026, 0.023, 0.97), Color(0, 0, 0, 0), 0, 0.0, 28)
			card.shadow_color = Color(0, 0, 0, 0.62)
			sb = card
		&"seal":
			sb = box(Color(0.075, 0.052, 0.032, 0.9), Color(GOLD, 0.9))
		&"seal_loss":
			sb = box(Color(0.07, 0.035, 0.028, 0.9), Color(0.72, 0.36, 0.26, 0.9))
		&"plate":
			# A slim plate under text that sits on the world (evac, prompts).
			var plate := box(Color(0.022, 0.019, 0.016, 0.82), Color(GOLD_DIM, 0.8), 1, 0.0, 10)
			plate.content_margin_left = 22.0
			plate.content_margin_right = 22.0
			plate.content_margin_top = 6.0
			plate.content_margin_bottom = 7.0
			sb = plate
		&"plate_alarm":
			var alarm := box(Color(0.05, 0.022, 0.016, 0.86), Color(0.78, 0.38, 0.24, 0.9), 1, 0.0, 12)
			alarm.content_margin_left = 26.0
			alarm.content_margin_right = 26.0
			alarm.content_margin_top = 6.0
			alarm.content_margin_bottom = 7.0
			sb = alarm
		&"empty":
			sb = StyleBoxEmpty.new()
		_:
			sb = StyleBoxEmpty.new()
	_boxes[key] = sb
	return sb


## A rule colour for an item's rarity, muted enough to sit beside the gold.
static func rarity_colour(rarity: int) -> Color:
	if rarity <= -1:
		return DANGER
	match rarity:
		0:
			return Color(0.42, 0.32, 0.2, 0.9)
		1:
			return Color(0.5, 0.74, 0.46)
		2:
			return ARCANE
		3:
			return Color(0.7, 0.5, 0.95)
	return EMBER


## The icon well, its rule in the rarity's colour; one box per rarity, shared.
static func well(rarity: int) -> StyleBox:
	var key := StringName("well_%d" % clampi(rarity, -1, 4))
	if _boxes.has(key):
		return _boxes[key]
	var sb := box(Color(0.012, 0.011, 0.01, 1.0), Color(rarity_colour(rarity), 0.85))
	_boxes[key] = sb
	return sb


# ------------------------------------------------------------------ motion

## A tween that runs on real time and through a paused tree.
static func tween(node: Node) -> Tween:
	var tw := node.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tw


## A surface arrives: it fades up and settles from `rise` px below its place
## (above, for a negative rise). It waits out the frame it is built in first,
## whose long delta would otherwise finish the motion before it is seen.
## `target` must be free of container layout, or the next sort undoes the
## motion; its resting place is remembered, so an arrival that interrupts
## another never drifts. Reduced Motion keeps only the fade.
static func arrive(target: Control, rise: float = 12.0, duration: float = 0.34, delay: float = 0.0) -> void:
	var home: Vector2 = target.get_meta(&"overlay_home", target.position)
	target.set_meta(&"overlay_home", home)
	if target.has_meta(&"overlay_arrival"):
		var previous := target.get_meta(&"overlay_arrival") as Tween
		if previous != null and previous.is_valid():
			previous.kill()
	var ticket := int(target.get_meta(&"overlay_ticket", 0)) + 1
	target.set_meta(&"overlay_ticket", ticket)
	var still := reduced()
	target.modulate.a = 0.0
	target.position = home if still else home + Vector2(0.0, rise)
	if not await settle(target):
		return
	if int(target.get_meta(&"overlay_ticket", 0)) != ticket:
		return
	var tw := tween(target).set_parallel(true)
	target.set_meta(&"overlay_arrival", tw)
	if still:
		tw.tween_property(target, "modulate:a", 1.0, minf(duration, 0.2)).set_delay(delay)
		return
	tw.tween_property(target, "modulate:a", 1.0, duration * 0.7).set_delay(delay)
	tw.tween_property(target, "position", home, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)


## A veil or plate fades up from nothing, after the frame it is shown in.
static func fade_in(item: CanvasItem, duration: float = 0.24, to: float = 1.0) -> void:
	var ticket := int(item.get_meta(&"overlay_fade", 0)) + 1
	item.set_meta(&"overlay_fade", ticket)
	item.modulate.a = 0.0
	if not await settle(item):
		return
	if int(item.get_meta(&"overlay_fade", 0)) != ticket:
		return
	tween(item).tween_property(item, "modulate:a", to, duration)


## Waits out the frame a surface is built in (and the next), whose long delta
## would otherwise finish an opening tween before it is ever seen.
static func settle(node: Node, frames: int = 1) -> bool:
	for _i in range(frames):
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			return false
		await node.get_tree().process_frame
	return node != null and is_instance_valid(node) and node.is_inside_tree()


static func diamond(center: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])


## Small filled diamonds on a rect's four corners: the register's mark for a
## gold-ruled box, drawn by the box's own _draw (only on resize).
static func draw_corner_marks(item: CanvasItem, rect: Rect2, colour: Color, r: float = 3.5) -> void:
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var pts := diamond(corner, r)
		item.draw_colored_polygon(pts, Color(0.04, 0.034, 0.03, 1.0))
		var loop := pts.duplicate()
		loop.append(pts[0])
		item.draw_polyline(loop, colour, 1.2, true)
		item.draw_colored_polygon(diamond(corner, r * 0.42), colour)


# ------------------------------------------------------------------ choices

## A spoken choice as a ledger row: Garamond text after a diamond, a faint
## rule beneath, warm ground and a gold edge under the cursor or focus, the
## gold stroke when pressed. Set once per button; the row shares its boxes.
static func style_choice(button: Button, font_size: int = 19) -> void:
	if button == null:
		return
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		button.add_theme_stylebox_override(state, _choice_box(state))
	button.add_theme_font_override(&"font", font(&"semi"))
	button.add_theme_font_size_override(&"font_size", font_size)
	button.add_theme_color_override(&"font_color", BODY)
	button.add_theme_color_override(&"font_hover_color", GOLD_BRIGHT)
	button.add_theme_color_override(&"font_focus_color", GOLD_BRIGHT)
	button.add_theme_color_override(&"font_pressed_color", INK)
	button.add_theme_color_override(&"font_hover_pressed_color", INK)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not button.has_meta(&"overlay_choice_mark"):
		button.set_meta(&"overlay_choice_mark", true)
		button.draw.connect(func() -> void: _draw_choice_mark(button))
		# The mark fills on focus as well as hover; focus has no redraw of its own.
		button.focus_entered.connect(button.queue_redraw)
		button.focus_exited.connect(button.queue_redraw)


static func _choice_box(state: StringName) -> StyleBox:
	var key := StringName("choice_%s" % state)
	if _boxes.has(key):
		return _boxes[key]
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.content_margin_left = 40.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 8.0
	match state:
		&"normal", &"disabled":
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_width_bottom = 1
			sb.border_color = Color(GOLD_DIM, 0.28)
		&"hover":
			sb.bg_color = Color(0.13, 0.086, 0.048, 0.88)
			sb.border_width_left = 2
			sb.border_width_bottom = 1
			sb.border_color = Color(GOLD, 0.85)
		&"pressed", &"hover_pressed":
			sb.bg_color = Color(0.79, 0.54, 0.27, 1.0)
			sb.border_width_bottom = 1
			sb.border_color = GOLD_BRIGHT
		&"focus":
			sb.draw_center = false
			sb.border_width_left = 2
			sb.border_color = Color(GOLD_BRIGHT, 0.9)
	_boxes[key] = sb
	return sb


static func _draw_choice_mark(button: Button) -> void:
	var c := Vector2(20.0, button.size.y * 0.5)
	var hot := button.is_hovered() or button.has_focus()
	var col := INK if button.button_pressed else (GOLD_BRIGHT if hot else GOLD)
	var r := 5.0 if hot else 4.0
	var pts := diamond(c, r)
	if hot:
		button.draw_colored_polygon(pts, col)
		return
	var loop := pts.duplicate()
	loop.append(pts[0])
	button.draw_polyline(loop, col, 1.2, true)
	button.draw_colored_polygon(diamond(c, r * 0.38), Color(col, 0.8))
