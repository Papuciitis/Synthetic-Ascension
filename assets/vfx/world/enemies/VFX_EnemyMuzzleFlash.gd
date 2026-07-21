extends Node2D
class_name VFX_EnemyMuzzleFlash

@export var duration: float = 0.07
@export var length: float = 26.0
@export var spread_deg: float = 22.0
@export var core_width: float = 2.6
@export var glow_width: float = 10.0

@export var color_core: Color = Color(0.95, 0.98, 1.0, 0.95)
@export var color_glow: Color = Color(0.25, 0.65, 1.0, 0.50)

var _t: float = 0.0

func setup(pos: Vector2, dir: Vector2, style_id: StringName = &"") -> void:
	global_position = pos
	if dir.length_squared() > 0.0001:
		rotation = dir.angle()

	# Style palettes
	match style_id:
		&"enemy_spitter":
			color_core = Color(0.75, 1.00, 0.25, 0.95)  # bile core
			color_glow = Color(0.10, 0.80, 0.25, 0.55)  # toxic glow
			length = 24.0
			spread_deg = 28.0
		&"enemy_herald":
			color_core = Color(1.00, 0.70, 0.35, 0.95)  # ember core
			color_glow = Color(0.75, 0.20, 1.00, 0.60)  # violet glow
			length = 30.0
			spread_deg = 18.0
		_:
			pass

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4090

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var p: float = clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var fade: float = 1.0 - p
	fade = fade * fade

	# “cone” lines
	var half: float = deg_to_rad(spread_deg) * 0.5
	var a0: float = -half
	var a1: float = +half

	# two rays + center ray
	var rays := [a0, 0.0, a1]
	for a in rays:
		var dir := Vector2.RIGHT.rotated(a)
		var end := dir * length

		draw_line(Vector2.ZERO, end, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade), glow_width, true)
		draw_line(Vector2.ZERO, end, Color(color_core.r, color_core.g, color_core.b, color_core.a * fade), core_width, true)

	# tiny pop at origin
	draw_circle(Vector2.ZERO, 2.0, Color(color_core.r, color_core.g, color_core.b, 0.30 * fade))
