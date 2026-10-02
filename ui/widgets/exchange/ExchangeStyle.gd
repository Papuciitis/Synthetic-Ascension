extends RefCounted
## The Exchange's share of the front-end register (docs/design/
## 2026-10-02-front-end-arcane-register.md): the palette, and the styleboxes
## the screen sets on its own panels, buttons and slots. The theme has no
## types for a shop, so they are built here once and shared; nothing in this
## file writes to ArcaneMenuTheme or to the shared slot widgets' own styles.

const ARCANE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const HUD_THEME := preload("res://ui/theme/SyntheticHudTheme.tres")

const PARCHMENT := Color(0.91, 0.86, 0.77)
const BODY := Color(0.82, 0.77, 0.68)
const MUTED := Color(0.58, 0.53, 0.46)
const GOLD := Color(0.86, 0.64, 0.36)
const GOLD_DIM := Color(0.62, 0.47, 0.30)
const GOLD_BRIGHT := Color(0.99, 0.84, 0.58)
const INK := Color(0.13, 0.08, 0.045)
const PANEL := Color(0.032, 0.028, 0.025)
const EMBER := Color(1.0, 0.62, 0.30)
const ARCANE := Color(0.42, 0.62, 1.0)
const DANGER := Color(0.86, 0.32, 0.24)

enum Slot { EMPTY, FILLED, HOVER, PAN_EMPTY, LOCKED }
enum Btn { NAV, NAV_PRIMARY, SMALL, PRIMARY, TAB }

static var _cache: Dictionary = {}


static func font(type_name: StringName) -> Font:
	return ARCANE_THEME.get_font(&"font", type_name)


## A front-end panel: near-black warm ground, a 1 px gold-dim rule, square
## corners, a long soft shadow. `rite` is the Balance: warmer ground and a
## brighter rule. `alpha` lets the embedded panel let a little hub through.
static func panel(rite: bool = false, alpha: float = 0.9) -> StyleBoxFlat:
	var key := "panel_%s_%.2f" % [rite, alpha]
	if _cache.has(key):
		return _cache[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.036, 0.029, alpha + 0.03) if rite else Color(PANEL, alpha)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.74, 0.56, 0.33, 0.85) if rite else Color(0.52, 0.39, 0.24, 0.8)
	sb.set_corner_radius_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 22 if rite else 16
	sb.shadow_offset = Vector2(0, 8)
	sb.set_content_margin_all(0.0)
	_cache[key] = sb
	return sb


static func slot(state: int) -> StyleBoxFlat:
	var key := "slot_%d" % state
	if _cache.has(key):
		return _cache[key]
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(1)
	sb.set_border_width_all(1)
	match state:
		Slot.EMPTY:
			sb.bg_color = Color(0.018, 0.016, 0.014, 0.72)
			sb.border_color = Color(GOLD_DIM, 0.22)
		Slot.PAN_EMPTY:
			sb.bg_color = Color(0.014, 0.012, 0.011, 0.5)
			sb.border_color = Color(GOLD_DIM, 0.14)
		Slot.FILLED:
			sb.bg_color = Color(0.07, 0.056, 0.043, 0.96)
			sb.border_color = Color(GOLD_DIM, 0.62)
			sb.shadow_color = Color(0, 0, 0, 0.35)
			sb.shadow_size = 4
			sb.shadow_offset = Vector2(0, 2)
		Slot.LOCKED:
			# A held stack: the amber rule BagSlot used to draw, now on the socket.
			sb.bg_color = Color(0.07, 0.056, 0.043, 0.96)
			sb.set_border_width_all(2)
			sb.border_color = Color(1.0, 0.72, 0.22, 0.85)
		Slot.HOVER:
			sb.bg_color = Color(0.13, 0.086, 0.05, 0.98)
			sb.border_color = GOLD_BRIGHT
			sb.shadow_color = Color(1.0, 0.66, 0.3, 0.22)
			sb.shadow_size = 9
	_cache[key] = sb
	return sb


## Button looks the theme does not have: the ledger's passage rows, the
## gold-stroked primary action, small tool buttons and filter tabs.
static func button_styles(kind: int) -> Dictionary:
	var key := "btn_%d" % kind
	if _cache.has(key):
		return _cache[key]
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	var pressed := StyleBoxFlat.new()
	var disabled := StyleBoxFlat.new()
	var focus := StyleBoxFlat.new()
	for sb: StyleBoxFlat in [normal, hover, pressed, disabled, focus]:
		sb.set_corner_radius_all(1)
	focus.draw_center = false
	focus.set_border_width_all(1)
	focus.border_color = Color(GOLD_BRIGHT, 0.9)
	focus.set_expand_margin_all(2.0)
	match kind:
		Btn.NAV, Btn.NAV_PRIMARY:
			var primary := kind == Btn.NAV_PRIMARY
			for sb: StyleBoxFlat in [normal, hover, pressed, disabled]:
				sb.content_margin_left = 34.0
				sb.content_margin_right = 12.0
				sb.content_margin_top = 9.0
				sb.content_margin_bottom = 9.0
				sb.border_width_bottom = 1
			normal.bg_color = Color(0.09, 0.062, 0.036, 0.75) if primary else Color(0, 0, 0, 0)
			normal.border_color = Color(GOLD, 0.55) if primary else Color(GOLD_DIM, 0.22)
			if primary:
				normal.set_border_width_all(1)
			hover.bg_color = Color(0.16, 0.105, 0.055, 0.92)
			hover.border_color = Color(GOLD_BRIGHT, 0.85)
			hover.border_width_left = 2
			if primary:
				hover.set_border_width_all(1)
				hover.border_width_left = 2
			hover.shadow_color = Color(1.0, 0.62, 0.3, 0.12)
			hover.shadow_size = 8
			pressed.bg_color = Color(0.79, 0.54, 0.27, 1.0)
			pressed.border_color = Color(0.98, 0.8, 0.5, 1.0)
			pressed.set_border_width_all(1)
			disabled.bg_color = Color(0, 0, 0, 0)
			disabled.border_color = Color(0.3, 0.26, 0.21, 0.3)
		Btn.PRIMARY:
			for sb: StyleBoxFlat in [normal, hover, pressed, disabled]:
				sb.content_margin_left = 22.0
				sb.content_margin_right = 22.0
				sb.content_margin_top = 11.0
				sb.content_margin_bottom = 11.0
				sb.set_border_width_all(1)
			normal.bg_color = Color(0.2, 0.13, 0.062, 0.95)
			normal.border_color = Color(GOLD, 0.95)
			normal.shadow_color = Color(1.0, 0.62, 0.3, 0.14)
			normal.shadow_size = 10
			hover.bg_color = Color(0.32, 0.21, 0.1, 1.0)
			hover.border_color = GOLD_BRIGHT
			hover.shadow_color = Color(1.0, 0.66, 0.32, 0.3)
			hover.shadow_size = 14
			pressed.bg_color = Color(0.79, 0.54, 0.27, 1.0)
			pressed.border_color = Color(0.98, 0.8, 0.5, 1.0)
			disabled.bg_color = Color(0.035, 0.031, 0.028, 0.7)
			disabled.border_color = Color(0.36, 0.3, 0.23, 0.55)
		Btn.SMALL:
			for sb: StyleBoxFlat in [normal, hover, pressed, disabled]:
				sb.content_margin_left = 12.0
				sb.content_margin_right = 12.0
				sb.content_margin_top = 6.0
				sb.content_margin_bottom = 6.0
				sb.set_border_width_all(1)
			normal.bg_color = Color(0.045, 0.037, 0.031, 0.8)
			normal.border_color = Color(0.5, 0.38, 0.24, 0.6)
			hover.bg_color = Color(0.12, 0.08, 0.047, 0.92)
			hover.border_color = Color(0.86, 0.6, 0.3, 1.0)
			pressed.bg_color = Color(0.62, 0.42, 0.21, 1.0)
			pressed.border_color = Color(0.98, 0.8, 0.5, 1.0)
			disabled.bg_color = Color(0.03, 0.027, 0.024, 0.5)
			disabled.border_color = Color(0.3, 0.26, 0.21, 0.4)
		Btn.TAB:
			# A filter tab: caption only, a gold underline when chosen.
			for sb: StyleBoxFlat in [normal, hover, pressed, disabled]:
				sb.content_margin_left = 10.0
				sb.content_margin_right = 10.0
				sb.content_margin_top = 5.0
				sb.content_margin_bottom = 7.0
			normal.bg_color = Color(0, 0, 0, 0)
			normal.border_width_bottom = 1
			normal.border_color = Color(GOLD_DIM, 0.2)
			hover.bg_color = Color(0.12, 0.08, 0.047, 0.55)
			hover.border_width_bottom = 1
			hover.border_color = Color(GOLD, 0.7)
			pressed.bg_color = Color(0.11, 0.075, 0.042, 0.7)
			pressed.border_width_bottom = 2
			pressed.border_color = GOLD_BRIGHT
			disabled.bg_color = Color(0, 0, 0, 0)
	var out := {"normal": normal, "hover": hover, "pressed": pressed, "hover_pressed": pressed, "disabled": disabled, "focus": focus}
	_cache[key] = out
	return out


## Sets one of the looks above on a button the screen owns, with the
## Cinzel caption and colours that go with it. Called once per button.
static func style_button(button: Button, kind: int, font_size: int = 15) -> void:
	if button == null:
		return
	var styles := button_styles(kind)
	for state: String in styles.keys():
		button.add_theme_stylebox_override(state, styles[state])
	button.add_theme_font_override(&"font", font(&"ArcaneHeading"))
	button.add_theme_font_size_override(&"font_size", font_size)
	var cream := PARCHMENT if kind != Btn.NAV else BODY
	button.add_theme_color_override(&"font_color", GOLD_BRIGHT if kind == Btn.PRIMARY else cream)
	button.add_theme_color_override(&"font_hover_color", GOLD_BRIGHT)
	button.add_theme_color_override(&"font_focus_color", GOLD_BRIGHT)
	button.add_theme_color_override(&"font_pressed_color", INK)
	button.add_theme_color_override(&"font_hover_pressed_color", INK)
	button.add_theme_color_override(&"font_disabled_color", Color(0.42, 0.39, 0.35))
	if kind == Btn.TAB:
		button.add_theme_color_override(&"font_color", MUTED)
		button.add_theme_color_override(&"font_pressed_color", GOLD_BRIGHT)
		button.add_theme_color_override(&"font_hover_pressed_color", GOLD_BRIGHT)
	if kind == Btn.NAV or kind == Btn.NAV_PRIMARY:
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not button.has_meta(&"exchange_nav_mark"):
			button.set_meta(&"exchange_nav_mark", true)
			button.draw.connect(func() -> void: _draw_nav_mark(button))


## The passage row's diamond: an outline at rest, filled gold under the
## cursor or on the primary row, dim when the passage is closed.
static func _draw_nav_mark(button: Button) -> void:
	var c := Vector2(17.0, button.size.y * 0.5)
	var hot := button.is_hovered() or button.has_focus()
	var col := GOLD_BRIGHT if hot else GOLD
	if button.disabled:
		col = Color(0.36, 0.32, 0.27)
	var r := 5.0 if hot else 4.0
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if button.button_pressed or (hot and not button.disabled):
		button.draw_colored_polygon(pts, col)
	else:
		var loop := pts.duplicate()
		loop.append(pts[0])
		button.draw_polyline(loop, col, 1.2, true)
		var i := r * 0.38
		button.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -i), c + Vector2(i, 0), c + Vector2(0, i), c + Vector2(-i, 0)]), Color(col, 0.8))


static func diamond(center: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])


## 6000 -> "6,000". Negative values keep their sign.
static func grouped(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if negative else "") + digits + out
