extends Node2D
class_name VFX_TitheEmbers

## A Follower going into the Tithe Furnace: the coal bed flares white and the
## believer leaves as embers drifting upward.

@export var duration: float = 0.85
@export var ember_count: int = 14

const HOT: Color = Color(1.0, 0.62, 0.18, 1.0)
const ASH: Color = Color(1.0, 0.93, 0.78, 1.0)

var _t: float = 0.0
var _embers: Array[Dictionary] = []


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 3997
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for _i in range(ember_count):
		_embers.append({
			"x": randf_range(-16.0, 16.0),
			"rise": randf_range(46.0, 96.0),
			"drift": randf_range(-22.0, 22.0),
			"size": randf_range(1.6, 3.4),
			"phase": randf() * TAU,
			"delay": randf() * 0.22,
		})
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

	# The flare: a short, bright gulp as the tithe is taken.
	var flare: float = clampf(1.0 - p * 4.0, 0.0, 1.0)
	if flare > 0.0:
		draw_circle(Vector2.ZERO, 30.0 * (0.6 + 0.4 * flare), Color(HOT.r, HOT.g, HOT.b, 0.35 * flare))
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 40, Color(ASH.r, ASH.g, ASH.b, 0.9 * flare), 2.5, true)

	for ember in _embers:
		var local_p: float = clampf((p - float(ember["delay"])) / maxf(0.05, 1.0 - float(ember["delay"])), 0.0, 1.0)
		if local_p <= 0.0:
			continue
		var fade: float = 1.0 - local_p
		var y: float = -float(ember["rise"]) * local_p
		var x: float = float(ember["x"]) + float(ember["drift"]) * local_p + sin(float(ember["phase"]) + local_p * 7.0) * 3.5
		var tint: Color = HOT.lerp(ASH, local_p)
		draw_circle(Vector2(x, y), float(ember["size"]) * (0.5 + 0.5 * fade), Color(tint.r, tint.g, tint.b, fade * 0.9))
