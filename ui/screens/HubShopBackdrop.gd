extends Control
class_name HubShopBackdrop
## What the Exchange stands in front of.
##
## Standalone it is the Archives' workshop painting turned down to lamplight:
## the plate darkened, a vignette, a warm pool behind the Balance and a little
## dust and a few embers in the air. Embedded over the walkable hub it is only
## a veil, so the courtyard stays visible around the panels.
##
## Everything here is drawn once (on resize or a mode change); the motes are
## a handful of CPU particles.

const PLATE := preload("res://assets/ui/menu/vigil_backdrop.jpg")
const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

## Embedded over the hub: a translucent veil instead of the painting.
var embedded: bool = false:
	set(value):
		if embedded == value:
			return
		embedded = value
		_apply_mode()

var _vignette: GradientTexture2D
var _pool: TextureRect
var _dust: CPUParticles2D
var _embers: CPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = _radial([
		[0.0, Color(0, 0, 0, 0.0)],
		[0.55, Color(0, 0, 0, 0.18)],
		[1.0, Color(0, 0, 0, 0.82)],
	])
	_pool = TextureRect.new()
	_pool.texture = _radial([
		[0.0, Color(1.0, 0.6, 0.28, 0.16)],
		[0.5, Color(1.0, 0.5, 0.2, 0.05)],
		[1.0, Color(1.0, 0.45, 0.18, 0.0)],
	])
	_pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pool.material = ArcaneParticles.additive()
	add_child(_pool)
	var still := ArcaneMotion.reduced()
	_dust = ArcaneParticles.dust()
	_dust.amount = 10 if still else 22
	add_child(_dust)
	_embers = ArcaneParticles.embers(4 if still else 9, 0.7)
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(420, 8)
	_embers.gravity = Vector2(3.0, -22.0)
	add_child(_embers)
	resized.connect(_layout)
	_layout()
	_apply_mode()


func _layout() -> void:
	if _pool == null:
		return
	var pool := Vector2(size.x * 0.62, size.y * 0.95)
	_pool.size = pool
	_pool.position = Vector2(size.x * 0.5 - pool.x * 0.5, size.y * 0.58 - pool.y * 0.5)
	_dust.position = size * 0.5
	_dust.emission_rect_extents = size * 0.48
	_embers.position = Vector2(size.x * 0.5, size.y + 6.0)
	queue_redraw()


func _apply_mode() -> void:
	if _pool == null:
		return
	_pool.visible = not embedded
	_embers.visible = not embedded
	_embers.emitting = not embedded
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if embedded:
		# The courtyard stays in view, pushed back and cooled a little.
		draw_rect(rect, Color(0.012, 0.01, 0.009, 0.46))
		draw_texture_rect(_vignette, rect, false, Color(1, 1, 1, 0.75))
		return
	draw_rect(rect, Color(0.012, 0.01, 0.009, 1.0))
	draw_texture_rect(PLATE, rect, false, Color(0.34, 0.3, 0.27, 1.0))
	draw_rect(rect, Color(0.012, 0.009, 0.007, 0.5))
	draw_texture_rect(_vignette, rect, false)


static func _radial(stops: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return s[0]))
	g.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return s[1]))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.08, 0.5)
	t.width = 128
	t.height = 128
	return t
