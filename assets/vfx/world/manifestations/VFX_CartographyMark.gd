extends Node2D
class_name VFX_CartographyMark

## Heretical Cartography claiming new ground: survey ticks snap outward and a
## bracket closes around the player. Rings equal the stack you just reached.

@export var duration: float = 0.55
@export var stacks: int = 1
@export var max_stacks: int = 5

const CHART: Color = Color(0.55, 0.95, 0.80, 1.0)

var _t: float = 0.0


func setup(current: int, cap: int) -> void:
	max_stacks = maxi(1, cap)
	stacks = clampi(current, 1, max_stacks)


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 3996
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
	var fade: float = 1.0 - p * p

	for i in range(stacks):
		var r: float = lerpf(14.0, 40.0 + 9.0 * float(i), sqrt(p))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 44, Color(CHART.r, CHART.g, CHART.b, 0.45 * fade / float(i + 1)), 1.8, true)

	# Corner brackets: the "you are here" of a map you are not supposed to have.
	var reach: float = lerpf(56.0, 34.0, p)
	var arm: float = 11.0
	var signs: Array[float] = [-1.0, 1.0]
	for qx: float in signs:
		for qy: float in signs:
			var corner: Vector2 = Vector2(qx * reach, qy * reach)
			draw_line(corner, corner - Vector2(qx * arm, 0.0), Color(CHART.r, CHART.g, CHART.b, 0.85 * fade), 2.0, true)
			draw_line(corner, corner - Vector2(0.0, qy * arm), Color(CHART.r, CHART.g, CHART.b, 0.85 * fade), 2.0, true)
