extends RefCounted
## Shared presentation for the in-run chambers (the augment library, the
## Ascension Doctrine, Gear & Stash, Game Over) in the front end's register
## (docs/design/2026-10-02-front-end-arcane-register.md): the palette, square
## gold-ruled boxes built in code so the shared theme stays untouched, the
## soft light and veil textures, slow falling embers, and the open motions.
##
## Preload by path; no class_name. Every motion here honours Reduced Motion
## and runs on real time (tweens ignore the time scale and keep running while
## the tree is paused, since these screens are shown over a stopped world).

const THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")
const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")

const PARCHMENT := Color(0.91, 0.86, 0.77)
const BODY := Color(0.82, 0.77, 0.68)
const MUTED := Color(0.62, 0.56, 0.47)
const GOLD := Color(0.86, 0.64, 0.36)
const GOLD_DIM := Color(0.62, 0.47, 0.30)
const GOLD_BRIGHT := Color(0.99, 0.84, 0.58)
const INK := Color(0.13, 0.08, 0.045)
const PANEL := Color(0.032, 0.028, 0.025, 0.94)
const WELL := Color(0.02, 0.018, 0.016, 0.92)
const EMBER := Color(1.0, 0.62, 0.30)
const ARCANE := Color(0.42, 0.62, 1.0)
const DANGER := Color(0.86, 0.32, 0.24)
const VEIL := Color(0.008, 0.006, 0.005, 0.8)

static var _vignette: GradientTexture2D = null
static var _glow: GradientTexture2D = null
static var _shade: GradientTexture2D = null
static var _boxes: Dictionary = {}


static func reduced() -> bool:
	return ArcaneMotion.reduced()


## A square box: fill, a 1 px rule, optional content margins and shadow.
static func box(bg: Color, border: Color, border_width: int = 1, margin: float = 0.0, shadow: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	# A 1 px square edge can fall between pixel centres at a non-native window
	# scale (0.93 at 1784 x 1004) and vanish; 2 px at ~60 % alpha reads the
	# same weight and always lands on a pixel.
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
		sb.shadow_offset = Vector2(0, shadow * 0.45)
	return sb


## Shared (cached) boxes by name, so a grid of slots shares a handful of
## StyleBox objects instead of building one per slot.
static func shared(name: StringName) -> StyleBox:
	if _boxes.has(name):
		return _boxes[name]
	var sb: StyleBox
	match name:
		&"panel":
			sb = box(PANEL, Color(0.5, 0.38, 0.24, 0.85), 1, 0.0, 22)
		&"well":
			sb = box(Color(0.018, 0.016, 0.014, 0.6), Color(0.36, 0.28, 0.18, 0.45))
		&"slot":
			sb = box(Color(0.026, 0.022, 0.019, 0.96), Color(0.3, 0.235, 0.155, 0.95))
		&"slot_hover":
			var h := box(Color(0.07, 0.05, 0.032, 0.98), GOLD)
			h.shadow_color = Color(1.0, 0.62, 0.3, 0.16)
			h.shadow_size = 7
			sb = h
		&"slot_pressed":
			sb = box(Color(0.1, 0.07, 0.04, 1.0), GOLD_BRIGHT)
		&"slot_lock":
			var l := box(Color(0, 0, 0, 0), Color(GOLD_BRIGHT, 0.95), 2)
			l.draw_center = false
			sb = l
		&"empty":
			sb = StyleBoxEmpty.new()
		&"row":
			sb = box(Color(0.036, 0.031, 0.027, 0.86), Color(0.3, 0.235, 0.155, 0.75), 1, 0.0)
		&"row_hover":
			var r := box(Color(0.075, 0.054, 0.034, 0.95), Color(GOLD, 0.9), 1, 0.0)
			r.border_width_left = 3
			r.border_color = GOLD
			sb = r
		&"row_bound":
			var b := box(Color(0.05, 0.039, 0.028, 0.92), Color(GOLD_DIM, 0.95), 1, 0.0)
			b.border_width_left = 3
			sb = b
		&"art":
			sb = box(Color(0.012, 0.011, 0.01, 1.0), Color(0.42, 0.32, 0.2, 0.9))
		&"keycap":
			var k := box(Color(0.06, 0.045, 0.03, 0.95), Color(GOLD_DIM, 0.95))
			k.content_margin_left = 8.0
			k.content_margin_right = 8.0
			k.content_margin_top = 1.0
			k.content_margin_bottom = 1.0
			sb = k
		&"toggle":
			var t := box(Color(0.04, 0.034, 0.03, 0.85), Color(0.42, 0.33, 0.22, 0.85))
			t.content_margin_left = 10.0
			t.content_margin_right = 10.0
			t.content_margin_top = 3.0
			t.content_margin_bottom = 3.0
			sb = t
		&"toggle_hover":
			var th := box(Color(0.1, 0.07, 0.042, 0.92), GOLD)
			th.content_margin_left = 10.0
			th.content_margin_right = 10.0
			th.content_margin_top = 3.0
			th.content_margin_bottom = 3.0
			sb = th
		&"toggle_on":
			var to := box(Color(0.79, 0.54, 0.27, 1.0), GOLD_BRIGHT)
			to.content_margin_left = 10.0
			to.content_margin_right = 10.0
			to.content_margin_top = 3.0
			to.content_margin_bottom = 3.0
			sb = to
		&"primary":
			var p := box(Color(0.13, 0.085, 0.045, 0.96), GOLD, 1, 0.0)
			p.content_margin_left = 26.0
			p.content_margin_right = 26.0
			p.content_margin_top = 9.0
			p.content_margin_bottom = 9.0
			p.shadow_color = Color(1.0, 0.6, 0.25, 0.14)
			p.shadow_size = 10
			sb = p
		&"primary_hover":
			var ph := box(Color(0.2, 0.13, 0.065, 0.98), GOLD_BRIGHT, 1, 0.0)
			ph.content_margin_left = 26.0
			ph.content_margin_right = 26.0
			ph.content_margin_top = 9.0
			ph.content_margin_bottom = 9.0
			ph.shadow_color = Color(1.0, 0.62, 0.28, 0.26)
			ph.shadow_size = 14
			sb = ph
		_:
			sb = StyleBoxEmpty.new()
	_boxes[name] = sb
	return sb


## Darkens toward the edges; stretched over the whole screen.
static func vignette() -> GradientTexture2D:
	if _vignette == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.22), Color(0, 0, 0, 0.72)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.08, 0.5)
		t.width = 256
		t.height = 256
		_vignette = t
	return _vignette


## A soft round pool of light (white; tint it with modulate).
static func glow() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow = t
	return _glow


## Vertical shade: clear at the top, dark at the bottom (art windows).
static func shade() -> GradientTexture2D:
	if _shade == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.85)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_to = Vector2(0, 1)
		t.width = 4
		t.height = 64
		_shade = t
	return _shade


## A full-screen vignette (darker edges) to sit over a chamber's veil.
static func vignette_rect() -> TextureRect:
	var vig := TextureRect.new()
	vig.name = "ChamberVignette"
	vig.texture = vignette()
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return vig


## A warm pool of candle light at `centre` with `extent` (half size). The
## tint and strength live in self_modulate, so fades on `modulate` compose.
static func light_pool(centre: Vector2, extent: Vector2, colour: Color, alpha: float) -> TextureRect:
	var pool := TextureRect.new()
	pool.name = "ChamberLight"
	pool.texture = glow()
	pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pool.stretch_mode = TextureRect.STRETCH_SCALE
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool.material = ArcaneParticles.additive()
	pool.self_modulate = Color(colour, alpha)
	pool.position = centre - extent
	pool.size = extent * 2.0
	return pool


## Embers and ash drifting down through the whole screen, slowly. Fewer and
## calmer under Reduced Motion.
static func ember_fall(width: float, height: float) -> CPUParticles2D:
	var still := reduced()
	var p := CPUParticles2D.new()
	p.name = "EmberFall"
	p.texture = ArcaneParticles.soft_dot()
	p.material = ArcaneParticles.additive()
	p.amount = 14 if still else 44
	p.lifetime = 16.0
	p.preprocess = 16.0
	p.local_coords = false
	p.randomness = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width * 0.55, 8.0)
	p.position = Vector2(width * 0.5, -24.0)
	p.direction = Vector2(0.15, 1.0)
	p.spread = 18.0
	p.gravity = Vector2(1.5, 5.0 if still else 7.0)
	p.initial_velocity_min = 10.0 if still else 16.0
	p.initial_velocity_max = 22.0 if still else 38.0
	p.tangential_accel_min = 0.0 if still else -6.0
	p.tangential_accel_max = 0.0 if still else 6.0
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.24
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.06, 0.4, 0.78, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 0.72, 0.42, 0.0),
		Color(1.0, 0.7, 0.38, 1.0),
		Color(1.0, 0.5, 0.18, 0.75),
		Color(0.62, 0.44, 0.34, 0.32),
		Color(0.4, 0.34, 0.3, 0.0),
	])
	p.color_ramp = ramp
	p.emitting = true
	if height > 0.0:
		# Long enough to cross the screen at the slowest fall.
		p.lifetime = clampf(height / 30.0, 9.0, 18.0)
		p.preprocess = p.lifetime
	return p


## A tween that runs on real time and through a paused tree.
static func tween(node: Node) -> Tween:
	var tw := node.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tw


## Waits out the frame a screen is built in (and the next), whose long
## delta would otherwise finish an opening tween before it is ever seen.
static func settle(node: Node, frames: int = 2) -> bool:
	for i in range(frames):
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			return false
		await node.get_tree().process_frame
	return node != null and is_instance_valid(node) and node.is_inside_tree()


## The chamber opening: the veil fades up, the chamber rises a little and
## settles. `root` must be a free (not container-placed) full-screen Control,
## such as the CenterContainer holding the panel, so a layout pass can never
## undo the motion. Reduced Motion keeps the fade and drops the movement.
static func open_panel(root: Control, backdrop: Array = [], rise: float = 18.0) -> void:
	var still := reduced()
	for b in backdrop:
		if b is CanvasItem:
			(b as CanvasItem).modulate.a = 0.0
	root.modulate.a = 0.0
	if not still:
		var screen := root.get_viewport_rect().size if root.is_inside_tree() else Vector2(1920, 1080)
		root.pivot_offset = screen * 0.5
		root.scale = Vector2.ONE * 0.985
		root.position.y = rise
	if not await settle(root):
		return
	var tw := tween(root).set_parallel(true)
	for b in backdrop:
		if b is CanvasItem and is_instance_valid(b):
			tw.tween_property(b, "modulate:a", 1.0, 0.22)
	if still:
		tw.tween_property(root, "modulate:a", 1.0, 0.16)
		return
	tw.tween_property(root, "modulate:a", 1.0, 0.26).set_delay(0.03)
	tw.tween_property(root, "position:y", 0.0, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.03)
	tw.tween_property(root, "scale", Vector2.ONE, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.03)


## Controls appear one after another: a fade, and a settle from `from_scale`
## about their centre (containers own position, so the motion is a scale).
## Only `cap` are staggered; the rest arrive with the last of them. Nothing
## under Reduced Motion: they are simply there.
static func stagger_in(owner: Node, controls: Array, start: float = 0.12, step: float = 0.03, cap: int = 14, from_scale: float = 0.94) -> void:
	if reduced() or controls.is_empty():
		return
	var list: Array[Control] = []
	for c in controls:
		if c is Control and is_instance_valid(c):
			list.append(c as Control)
			(c as Control).modulate.a = 0.0
	if not await settle(owner):
		return
	var tw := tween(owner).set_parallel(true)
	var i := 0
	for control in list:
		if not is_instance_valid(control):
			continue
		var delay := start + step * float(mini(i, cap))
		tw.tween_property(control, "modulate:a", 1.0, 0.24).set_delay(delay)
		if from_scale != 1.0:
			control.pivot_offset = control.size * 0.5
			control.scale = Vector2.ONE * from_scale
			tw.tween_property(control, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		i += 1


## Item rarity in the chamber palette: muted enough to sit beside the gold.
static func rarity_colour(r: int) -> Color:
	if r <= -1:
		return DANGER
	match r:
		0:
			return Color(0, 0, 0, 0)
		1:
			return Color(0.5, 0.74, 0.46)
		2:
			return ARCANE
		3:
			return Color(0.7, 0.5, 0.95)
	return EMBER


static func roman(n: int) -> String:
	var table := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return table[n] if n >= 0 and n < table.size() else str(n)


## Applies a Label look in code: a theme type variation plus optional size
## and colour, set once.
static func label(l: Label, variation: StringName, font_size: int = 0, colour: Color = Color(0, 0, 0, 0)) -> void:
	if l == null:
		return
	l.theme_type_variation = variation
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	if colour.a > 0.0:
		l.add_theme_color_override("font_color", colour)
