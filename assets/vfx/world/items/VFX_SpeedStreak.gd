extends Node2D
class_name VFX_SpeedStreak

@export var lifetime: float = 0.22
@export var speed: float = 120.0
@export var length: float = 26.0
@export var width: float = 3.0
@export var color: Color = Color(0.70, 0.95, 1.0, 1.0)

var dir: Vector2 = Vector2.LEFT
var _t: float = 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = 4070
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	position += dir.normalized() * speed * dt
	if _t >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / maxf(lifetime, 0.001), 0.0, 1.0)
	var a := (1.0 - k)
	a = a * a
	var c := Color(color.r, color.g, color.b, color.a * a)

	var a0 := Vector2.ZERO
	var a1 := -dir.normalized() * length
	draw_line(a0, a1, Color(c.r, c.g, c.b, c.a * 0.35), width * 3.0, true)
	draw_line(a0, a1, c, width, true)
