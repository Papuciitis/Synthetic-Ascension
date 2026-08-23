extends Node2D
class_name VFX_SunderTear

## Ground tear thrown by the Momentum Manifestations (Sunder Wake, Impact
## Scripture). Fully procedural and self-contained: the rule that spawns it only
## ever tells it a radius, an intensity and a tint, so one script covers both
## the offensive and the defensive read.

@export var radius: float = 160.0
@export var intensity: float = 1.0
@export var tint: Color = Color(1.0, 0.55, 0.20, 1.0)
@export var duration: float = 0.34
@export var spokes: int = 9

var _t: float = 0.0
var _seed: float = 0.0


func setup(r: float, power: float, colour: Color) -> void:
	radius = maxf(8.0, r)
	intensity = clampf(power, 0.0, 1.0)
	tint = colour


func _ready() -> void:
	top_level = true
	z_as_relative = false
	# Deliberately below the aura/shard band (4070+): this is a crack in the
	# floor, and it should not paint over the things standing on it.
	z_index = 3980

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# One seed per tear, so two waves in the same second do not land as the
	# same stamp rotated zero degrees.
	_seed = randf() * TAU

	set_process(true)
	queue_redraw()


func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var x: float = clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var fade: float = (1.0 - x) * (1.0 - x)
	# sqrt() front-loads the expansion so the tear snaps open and then settles,
	# instead of drifting outward at a constant, weightless speed.
	var r: float = lerpf(radius * 0.30, radius, sqrt(x))
	var a: float = (0.35 + 0.65 * intensity) * fade
	var weight: float = 0.55 + 0.45 * intensity

	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(tint.r, tint.g, tint.b, 0.42 * a), 11.0 * weight, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(1.0, 0.94, 0.86, 0.85 * a), 2.2, true)

	var crack := Color(tint.r, tint.g, tint.b, 0.60 * a)
	var n: int = maxi(5, int(round(float(spokes) * (0.6 + 0.4 * intensity))))
	for i in range(n):
		var ang: float = _seed + TAU * float(i) / float(n)
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x)
		var wobble: float = sin(_seed + float(i) * 2.1)
		var inner := dir * (r * 0.16)
		var outer := dir * (r * (0.92 + 0.14 * sin(_seed * 3.0 + float(i))))
		# Kink the crack off-axis so it reads as torn ground rather than a
		# clean radial starburst.
		var kink := (inner + outer) * 0.5 + side * (r * 0.10 * wobble)
		draw_line(inner, kink, crack, 4.2 * weight, true)
		draw_line(kink, outer, crack, 2.8 * weight, true)
