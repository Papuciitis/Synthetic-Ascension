extends Control
## The Exchanger in his window: a pointed-arch slice of the workshop painting
## (the Archives' card_portrait shader, drifting very slowly), lamplight pooled
## behind him, the hub's own Exchanger sprite standing on the sill, a few
## embers lifting off the lamp. Built in code; no new art.
##
## Under reduced motion the painting holds still, the lamp does not flicker
## and the embers thin out.

const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")
const PORTRAIT_SHADER := preload("res://ui/shaders/card_portrait.gdshader")
const PLATE := preload("res://assets/ui/menu/threshold_backdrop.jpg")
const FIGURE := preload("res://assets/textures/hub/hub_npc_exchanger.png")

## The threshold painting's lamplit shelves and astrolabe, in plate UV.
const REGION := Vector4(1500.0 / 2048.0, 250.0 / 1152.0, 440.0 / 2048.0, 575.0 / 1152.0)
const ARCH := 54.0
const FIGURE_SCALE := 2.0

var _mat: ShaderMaterial
var _vista: TextureRect
var _glow: TextureRect
var _figure: TextureRect
var _shadow: TextureRect
var _frame: Control
var _embers: CPUParticles2D
var _flicker: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(150, 198)
	var still := ArcaneMotion.reduced()

	_vista = TextureRect.new()
	_vista.texture = PLATE
	_vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = PORTRAIT_SHADER
	_mat.set_shader_parameter("region", REGION)
	_mat.set_shader_parameter("pan_seed", 2.3)
	_mat.set_shader_parameter("lit", 0.55)
	_mat.set_shader_parameter("tint", Color(1.0, 0.93, 0.86))
	_mat.set_shader_parameter("drift_amount", 0.0 if still else 0.6)
	_vista.material = _mat
	add_child(_vista)

	_glow = TextureRect.new()
	_glow.texture = _radial(Color(1.0, 0.68, 0.34, 0.5), Color(1.0, 0.5, 0.2, 0.0))
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.material = ArcaneParticles.additive()
	add_child(_glow)

	_shadow = TextureRect.new()
	_shadow.texture = _radial(Color(0, 0, 0, 0.75), Color(0, 0, 0, 0))
	_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow)

	_figure = TextureRect.new()
	_figure.texture = FIGURE
	_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_figure)

	_embers = ArcaneParticles.embers(3 if still else 7, 0.55)
	_embers.local_coords = true
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(40, 4)
	add_child(_embers)

	_frame = ArcaneFrameScript.new()
	_frame.set("inset", 0.0)
	_frame.set("crown", false)
	_frame.set("outer_rule", false)
	_frame.set("corners", false)
	_frame.set("arch_height", ARCH)
	_frame.set("colour", Color(0.78, 0.58, 0.34, 0.95))
	add_child(_frame)

	resized.connect(_layout)
	_layout()
	if not still:
		_start_flicker()


func _layout() -> void:
	var s := size
	for c: Control in [_vista, _frame]:
		c.position = Vector2.ZERO
		c.size = s
	if _mat != null and s.y > 0.0:
		_mat.set_shader_parameter("arch", ARCH / s.y)
	var fig := FIGURE.get_size() * FIGURE_SCALE
	var feet := s.y - 10.0
	_figure.size = fig
	_figure.position = Vector2(round((s.x - fig.x) * 0.5), round(feet - fig.y))
	_shadow.size = Vector2(fig.x * 1.3, 16)
	_shadow.position = Vector2((s.x - _shadow.size.x) * 0.5, feet - 9.0)
	_glow.size = Vector2(s.x * 1.1, s.x * 1.1)
	_glow.position = Vector2((s.x - _glow.size.x) * 0.5, s.y * 0.38 - _glow.size.y * 0.5 + 20.0)
	_embers.position = Vector2(s.x * 0.5, s.y - 14.0)


## Lamplight that breathes: a slow, uneven loop on the glow's strength.
func _start_flicker() -> void:
	_flicker = create_tween().set_loops().set_ignore_time_scale(true)
	_flicker.tween_property(_glow, "modulate:a", 0.78, 1.3).set_trans(Tween.TRANS_SINE)
	_flicker.tween_property(_glow, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	_flicker.tween_property(_glow, "modulate:a", 0.86, 0.6).set_trans(Tween.TRANS_SINE)
	_flicker.tween_property(_glow, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)


## Warms the window for a moment (a trade has been sealed).
func brighten() -> void:
	if _mat == null:
		return
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("lit", v), 1.0, 0.55, 0.9 if not ArcaneMotion.reduced() else 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _radial(inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
