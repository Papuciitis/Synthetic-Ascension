extends Node2D
class_name VFX_ParryFlash

@export var duration: float = 0.10
@export var fade_out: float = 0.06

@export var radius: float = 48.0
@export var arc_degrees: float = 210.0
@export var thickness: float = 12.0
@export var rim_width: float = 2.5
@export var spin_speed: float = 16.0

@export var color_core: Color = Color(0.95, 0.98, 1.0, 1.0)
@export var color_glow: Color = Color(0.35, 0.75, 1.0, 0.60)

var _t := 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = 4092
	top_level = true
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return
	rotation += spin_speed * dt
	queue_redraw()

func _draw() -> void:
	var remain := duration - _t
	var fade := 1.0
	if remain < fade_out:
		fade = clampf(remain / maxf(fade_out, 0.001), 0.0, 1.0)
		fade = fade * fade

	var p := clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var k := 1.0 - pow(1.0 - p, 3.0)

	var r_outer := lerpf(radius * 0.85, radius, k)
	var r_inner := maxf(0.0, r_outer - thickness)

	var half := deg_to_rad(arc_degrees) * 0.5
	var a0 := -half
	var a1 := +half

	var seg := 42
	var pts: PackedVector2Array = []
	for i in range(seg + 1):
		var a := lerpf(a0, a1, float(i) / float(seg))
		pts.append(Vector2(cos(a), sin(a)) * r_outer)
	for i in range(seg, -1, -1):
		var a := lerpf(a0, a1, float(i) / float(seg))
		pts.append(Vector2(cos(a), sin(a)) * r_inner)

	draw_colored_polygon(pts, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade))
	draw_arc(Vector2.ZERO, r_outer, a0, a1, seg, Color(color_core.r, color_core.g, color_core.b, color_core.a * fade), rim_width, true)
