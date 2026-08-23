extends Node2D
class_name VFX_GospelPulse

## One verse of the Overtime Gospel: a ring that pushes outward and a second,
## faster ring closing inward - the reward arriving and the hunt answering.

@export var duration: float = 0.7
@export var tick: int = 1

const PREACH: Color = Color(1.0, 0.72, 0.32, 1.0)
const HUNT: Color = Color(1.0, 0.24, 0.20, 1.0)

var _t: float = 0.0


func setup(tick_index: int) -> void:
	tick = maxi(1, tick_index)


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 3995
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
	var reach: float = 96.0 + 14.0 * float(mini(tick, 10))

	var out_r: float = lerpf(24.0, reach, sqrt(p))
	draw_arc(Vector2.ZERO, out_r, 0.0, TAU, 64, Color(PREACH.r, PREACH.g, PREACH.b, 0.55 * fade), 3.5, true)

	# The answering ring starts wide and closes in: it always arrives second and
	# it always gets closer than the last one did.
	var in_p: float = clampf((p - 0.15) / 0.85, 0.0, 1.0)
	if in_p > 0.0:
		var in_r: float = lerpf(reach * 1.35, 30.0, in_p * in_p)
		draw_arc(Vector2.ZERO, in_r, 0.0, TAU, 64, Color(HUNT.r, HUNT.g, HUNT.b, 0.5 * (1.0 - in_p)), 2.5, true)
