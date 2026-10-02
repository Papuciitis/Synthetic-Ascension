extends RefCounted
## The walkable hub's text in the front end's register (docs/design/
## 2026-10-02-front-end-arcane-register.md): station signs in Cinzel over a
## thin gold rule with a diamond, key-cap interact prompts, EB Garamond
## italic speech in a small dark bubble edged in old gold, and passing
## notices. All of it is drawn straight onto the label layer's canvases
## (HubWorld._label_layer: world-following, above the player and outside the
## dusk CanvasModulate), so nothing here is a Control, a StyleBox or a node
## built per frame. The faces are the ArcaneMenuTheme's own FontVariations.
##
## Every piece of text sits on a soft pool of shade and carries a tight ink
## edge and a drop shadow, so it reads over the painted paving at gameplay
## zoom. Fades always run; under Reduced Motion nothing rises or slides.
##
## Preload by path; no class_name.

const THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

const PARCHMENT := Color(0.91, 0.86, 0.77)
const BODY := Color(0.82, 0.77, 0.68)
const GOLD := Color(0.86, 0.64, 0.36)
const GOLD_DIM := Color(0.62, 0.47, 0.30)
const GOLD_BRIGHT := Color(0.99, 0.84, 0.58)
const EMBER := Color(1.0, 0.62, 0.30)
## The near-black warm brown every halo, edge and shadow is drawn in.
const SHADE := Color(0.025, 0.018, 0.012)
## The speech bubble's ground: the menus' panel colour, a touch warmer.
const BUBBLE := Color(0.045, 0.036, 0.029)

const SIGN_SIZE := 19
const VERB_SIZE := 16
const KEY_SIZE := 15
const SPEECH_SIZE := 18
const SPEAKER_SIZE := 13
const NOTICE_SIZE := 19
## Key cap height, and the gap between the cap and its verb.
const KEY_H := 24.0
const KEY_GAP := 8.0
## A speech line wider than this is broken in two.
const SPEECH_WRAP := 300.0
const BUBBLE_PAD := Vector2(11.0, 6.0)
const BUBBLE_TAIL := 6.0
## Cinzel's cap height and EB Garamond's x-height as a share of the size,
## used to centre a line of text on a point by eye.
const CAP := 0.7
const XH := 0.42

static var _heading: Font = null
static var _caption: Font = null
static var _italic: Font = null
static var _pool: GradientTexture2D = null


static func heading() -> Font:
	if _heading == null:
		_heading = THEME.get_font(&"font", &"ArcaneHeading")
	return _heading


static func caption() -> Font:
	if _caption == null:
		_caption = THEME.get_font(&"font", &"ArcaneCaption")
	return _caption


static func italic() -> Font:
	if _italic == null:
		_italic = THEME.get_font(&"font", &"ArcaneItalic")
	return _italic


static func reduced() -> bool:
	return ArcaneMotion.reduced()


## Seconds of real time since `last_usec` (Time.get_ticks_usec()), capped so a
## hitch, a pause or a stopped time scale never jumps or freezes a fade.
static func since(last_usec: int) -> float:
	if last_usec <= 0:
		return 0.0
	return clampf(float(Time.get_ticks_usec() - last_usec) / 1000000.0, 0.0, 0.1)


## Moves `value` toward `target`, covering the whole 0..1 range in `seconds`.
static func approach(value: float, target: float, dt: float, seconds: float) -> float:
	return move_toward(value, target, dt / maxf(0.001, seconds))


static func ease_out(t: float) -> float:
	var k := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - k * k * k


## The label the interact action's first keyboard key shows (E unless the
## player rebound it). Read on demand when a prompt appears, never per frame.
static func interact_key(fallback: String = "E") -> String:
	if InputMap.has_action(&"interact"):
		for event in InputMap.action_get_events(&"interact"):
			if event is InputEventKey:
				var key_event := event as InputEventKey
				var code := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
				if code != 0:
					return OS.get_keycode_string(code)
	return fallback


## A soft round pool of light (white; tinted by the draw's modulate).
static func pool() -> GradientTexture2D:
	if _pool == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_pool = t
	return _pool


## A smoky pool of shade behind text centred on `centre`, `extent` half-size.
static func draw_shade(canvas: CanvasItem, centre: Vector2, extent: Vector2, strength: float) -> void:
	if strength <= 0.004:
		return
	canvas.draw_texture_rect(pool(), Rect2(centre - extent, extent * 2.0), false, Color(SHADE, strength))


## One run of text from its baseline's left end: a drop shadow, a tight ink
## edge, then the face.
static func draw_line_text(canvas: CanvasItem, font: Font, at: Vector2, line: String, font_size: int, colour: Color, edge: int = 4) -> void:
	var a := colour.a
	if a <= 0.004:
		return
	canvas.draw_string(font, at + Vector2(1.0, 2.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(SHADE, 0.6 * a))
	if edge > 0:
		canvas.draw_string_outline(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, edge, Color(SHADE, 0.88 * a))
	canvas.draw_string(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


static func text_width(font: Font, line: String, font_size: int) -> float:
	return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## A thin gold rule centred on `centre`, fading at both ends, with a diamond
## at its heart. `lit` fills the diamond and warms the line.
static func draw_rule(canvas: CanvasItem, centre: Vector2, half_width: float, colour: Color, lit: float) -> void:
	var a := colour.a
	if a <= 0.004:
		return
	var y := centre.y
	var gap := 7.0
	var clear := Color(colour, 0.0)
	var solid := colour
	for side: float in [-1.0, 1.0]:
		var near := centre.x + side * gap
		var mid := centre.x + side * half_width * 0.55
		var far := centre.x + side * half_width
		var points := PackedVector2Array([Vector2(near, y), Vector2(mid, y), Vector2(far, y)])
		canvas.draw_polyline_colors(points, PackedColorArray([Color(SHADE, 0.5 * a), Color(SHADE, 0.3 * a), Color(SHADE, 0.0)]), 3.0, true)
		canvas.draw_polyline_colors(points, PackedColorArray([solid, Color(solid, a * 0.8), clear]), 1.25, true)
	var r := 4.0
	var diamond := PackedVector2Array([centre + Vector2(0, -r), centre + Vector2(r, 0), centre + Vector2(0, r), centre + Vector2(-r, 0)])
	canvas.draw_colored_polygon(diamond, Color(SHADE, 0.7 * a))
	if lit > 0.004:
		var inner := PackedVector2Array()
		for p in diamond:
			inner.append(centre + (p - centre) * 0.62)
		canvas.draw_colored_polygon(inner, Color(GOLD_BRIGHT, a * lit))
	diamond.append(diamond[0])
	canvas.draw_polyline(diamond, colour, 1.25, true)


## A station's sign, centred on `centre` (the rule's middle): the name in
## Cinzel over the rule. `lit` 0..1 warms it from parchment to bright gold
## as the player steps onto the ring.
static func draw_sign(canvas: CanvasItem, centre: Vector2, title: String, title_width: float, lit: float, alpha: float) -> void:
	if alpha <= 0.004:
		return
	var font := heading()
	var baseline := centre.y - 9.0
	var half := maxf(46.0, title_width * 0.5 + 18.0)
	draw_shade(canvas, Vector2(centre.x, baseline - SIGN_SIZE * CAP * 0.5), Vector2(half + 34.0, SIGN_SIZE * 1.35), (0.42 + 0.12 * lit) * alpha)
	var colour := PARCHMENT.lerp(GOLD_BRIGHT, lit)
	colour.a = (0.8 + 0.2 * lit) * alpha
	draw_line_text(canvas, font, Vector2(centre.x - title_width * 0.5, baseline), title, SIGN_SIZE, colour)
	var rule := GOLD_DIM.lerp(GOLD, lit)
	rule.a = (0.7 + 0.3 * lit) * alpha
	draw_rule(canvas, centre, half, rule, lit)


## The width a prompt takes, for centring and for its pool of shade.
static func prompt_width(key: String, verb: String) -> float:
	return _key_width(key) + (KEY_GAP + text_width(caption(), verb, VERB_SIZE) if not verb.is_empty() else 0.0)


static func _key_width(key: String) -> float:
	var font := heading() if key.length() <= 1 else caption()
	return maxf(KEY_H, text_width(font, key, KEY_SIZE if key.length() <= 1 else 12) + 14.0)


## The interact prompt, centred on `centre`: a square key cap holding the
## bound key, then the verb in Cinzel ("[E] Trade").
static func draw_prompt(canvas: CanvasItem, centre: Vector2, key: String, verb: String, alpha: float) -> void:
	if alpha <= 0.004:
		return
	var total := prompt_width(key, verb)
	var left := roundf(centre.x - total * 0.5)
	var top := roundf(centre.y - KEY_H * 0.5)
	draw_shade(canvas, centre, Vector2(total * 0.5 + 30.0, KEY_H * 1.2), 0.5 * alpha)
	var cap_w := _key_width(key)
	var cap := Rect2(left, top, cap_w, KEY_H)
	canvas.draw_rect(Rect2(cap.position + Vector2(1.0, 2.0), cap.size), Color(SHADE, 0.55 * alpha))
	canvas.draw_rect(cap, Color(0.06, 0.044, 0.03, 0.94 * alpha))
	canvas.draw_rect(cap.grow(-2.5), Color(GOLD_DIM, 0.22 * alpha), false, 1.0)
	canvas.draw_rect(cap, Color(GOLD, 0.95 * alpha), false, 1.5)
	var single := key.length() <= 1
	var key_font := heading() if single else caption()
	var key_size := KEY_SIZE if single else 12
	var kw := text_width(key_font, key, key_size)
	var key_at := Vector2(cap.position.x + (cap_w - kw) * 0.5, centre.y + key_size * CAP * 0.5)
	canvas.draw_string(key_font, key_at, key, HORIZONTAL_ALIGNMENT_LEFT, -1, key_size, Color(GOLD_BRIGHT, alpha))
	if verb.is_empty():
		return
	var verb_at := Vector2(cap.end.x + KEY_GAP, centre.y + VERB_SIZE * CAP * 0.5)
	draw_line_text(canvas, caption(), verb_at, verb, VERB_SIZE, Color(PARCHMENT, alpha))


## A speech bubble's lines and size, worked out once when the line is said
## (the per-frame draw only places it). `speaker` is an optional title shown
## in small Cinzel over the line ("The Exchanger").
static func bubble_layout(line: String, speaker: String = "") -> Dictionary:
	var font := italic()
	var lines := PackedStringArray([line])
	var width := text_width(font, line, SPEECH_SIZE)
	if width > SPEECH_WRAP:
		# Break at the space nearest the middle, so both halves balance.
		var best := -1
		var middle := float(line.length()) * 0.5
		for i in range(line.length()):
			if line[i] == " " and (best < 0 or absf(i - middle) < absf(best - middle)):
				best = i
		if best > 0:
			lines = PackedStringArray([line.substr(0, best), line.substr(best + 1)])
			width = maxf(text_width(font, lines[0], SPEECH_SIZE), text_width(font, lines[1], SPEECH_SIZE))
	var title_w := text_width(caption(), speaker, SPEAKER_SIZE) if not speaker.is_empty() else 0.0
	var line_h := float(SPEECH_SIZE) * 1.08
	var head := float(SPEAKER_SIZE) + 5.0 if not speaker.is_empty() else 0.0
	var box := Vector2(maxf(width, title_w) + BUBBLE_PAD.x * 2.0, head + line_h * lines.size() + BUBBLE_PAD.y * 2.0 - 2.0)
	return {"lines": lines, "speaker": speaker, "size": Vector2(ceilf(box.x), ceilf(box.y)), "line_h": line_h, "head": head}


## Where a bubble sits by default: centred over `tip`, its tail's length above.
static func bubble_rect(tip: Vector2, layout: Dictionary) -> Rect2:
	var box_size: Vector2 = layout["size"]
	return Rect2(Vector2(roundf(tip.x - box_size.x * 0.5), roundf(tip.y) - BUBBLE_TAIL - box_size.y), box_size)


## A small dark bubble edged in old gold above `tip` (the speaker's head),
## its little tail pointing down at them; EB Garamond italic inside.
## `offset` moves the box (to keep clear of a sign); the tail still points
## at the speaker.
static func draw_bubble(canvas: CanvasItem, tip: Vector2, layout: Dictionary, alpha: float, offset: Vector2 = Vector2.ZERO) -> void:
	if alpha <= 0.004:
		return
	var rect := bubble_rect(tip, layout)
	rect.position += offset.round()
	var tail_tip := Vector2(roundf(tip.x), roundf(tip.y))
	var tail_x := clampf(tail_tip.x, rect.position.x + BUBBLE_TAIL + 5.0, rect.end.x - BUBBLE_TAIL - 5.0)
	draw_shade(canvas, rect.get_center(), rect.size * 0.5 + Vector2(26.0, 16.0), 0.3 * alpha)
	canvas.draw_rect(Rect2(rect.position + Vector2(1.0, 3.0), rect.size), Color(SHADE, 0.45 * alpha))
	var tail := PackedVector2Array([
		Vector2(tail_x - BUBBLE_TAIL, rect.end.y - 0.5), Vector2(tail_x + BUBBLE_TAIL, rect.end.y - 0.5), tail_tip,
	])
	canvas.draw_rect(rect, Color(BUBBLE, 0.92 * alpha))
	canvas.draw_colored_polygon(tail, Color(BUBBLE, 0.92 * alpha))
	# Parchment-gold edge: a 1.5 px outer rule, a faint inner one, and the
	# tail's two sides continuing it (the base stays open into the box).
	var edge := Color(GOLD_DIM, 0.85 * alpha)
	var outline := PackedVector2Array([
		Vector2(tail_x - BUBBLE_TAIL, rect.end.y), Vector2(rect.position.x, rect.end.y), rect.position,
		Vector2(rect.end.x, rect.position.y), rect.end, Vector2(tail_x + BUBBLE_TAIL, rect.end.y), tail_tip,
		Vector2(tail_x - BUBBLE_TAIL, rect.end.y),
	])
	canvas.draw_polyline(outline, edge, 1.5, true)
	canvas.draw_rect(rect.grow(-3.0), Color(GOLD_DIM, 0.16 * alpha), false, 1.0)
	var y := rect.position.y + BUBBLE_PAD.y
	var speaker: String = layout["speaker"]
	if not speaker.is_empty():
		var sw := text_width(caption(), speaker, SPEAKER_SIZE)
		canvas.draw_string(caption(), Vector2(rect.get_center().x - sw * 0.5, y + SPEAKER_SIZE * CAP + 1.0), speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, SPEAKER_SIZE, Color(GOLD, 0.9 * alpha))
		y += float(layout["head"])
	var line_h: float = layout["line_h"]
	for line in (layout["lines"] as PackedStringArray):
		var lw := text_width(italic(), line, SPEECH_SIZE)
		y += line_h
		var at := Vector2(rect.get_center().x - lw * 0.5, y - line_h * 0.24)
		canvas.draw_string(italic(), at + Vector2(0.0, 1.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, SPEECH_SIZE, Color(SHADE, 0.7 * alpha))
		canvas.draw_string(italic(), at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, SPEECH_SIZE, Color(PARCHMENT, alpha))


## A passing line in the square ("a quiet corner"), centred on `centre`:
## EB Garamond italic on a pool of shade, no box.
static func draw_notice(canvas: CanvasItem, centre: Vector2, line: String, colour: Color, alpha: float) -> void:
	if alpha <= 0.004:
		return
	var font := italic()
	var w := text_width(font, line, NOTICE_SIZE)
	draw_shade(canvas, centre, Vector2(w * 0.5 + 36.0, NOTICE_SIZE * 1.3), 0.5 * alpha)
	draw_line_text(canvas, font, Vector2(centre.x - w * 0.5, centre.y + NOTICE_SIZE * XH * 0.5), line, NOTICE_SIZE, Color(colour, colour.a * alpha), 3)
