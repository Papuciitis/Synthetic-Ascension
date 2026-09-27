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
	material = null  # pixel-art kit (Batch D): the sprite blends normally
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

	# Pixel-art kit (Batch D, 2026-09-27): one ring sprite per stack replaces each expanding arc.
	for i in range(stacks):
		var r: float = lerpf(14.0, 40.0 + 9.0 * float(i), sqrt(p))
		VfxKit.draw_ring(self, Vector2.ZERO, r, Color(CHART.r, CHART.g, CHART.b, 0.45 * fade / float(i + 1)), 1.8)

	# Corner brackets: the "you are here" of a map you are not supposed to have.
	# Pixel-art kit (Batch D, 2026-09-27): one bracket sprite per corner replaces
	# each pair of "L" lines; rot steps of PI/2 walk the arms round the four
	# corners of the closing square, always pointing back at the centre.
	var reach: float = lerpf(56.0, 34.0, p)
	var arm: float = 11.0
	var bracket := Color(CHART.r, CHART.g, CHART.b, 0.85 * fade)
	VfxKit.draw_bracket(self, Vector2(-reach, -reach), 0.0, arm, bracket, 2.0)
	VfxKit.draw_bracket(self, Vector2(reach, -reach), PI * 0.5, arm, bracket, 2.0)
	VfxKit.draw_bracket(self, Vector2(reach, reach), PI, arm, bracket, 2.0)
	VfxKit.draw_bracket(self, Vector2(-reach, reach), PI * 1.5, arm, bracket, 2.0)
