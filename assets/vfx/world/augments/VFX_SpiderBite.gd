extends Node2D
class_name VFX_SpiderBite

@export var lifetime: float = 0.16
@export var fade_out: float = 0.06
@export var scale_mul: float = 1.0
@export var z: int = 4090

@export var color_poison: Color = Color(0.35, 1.0, 0.45, 0.85)
@export var color_dark: Color = Color(0.04, 0.16, 0.07, 0.90)
@export var color_glow: Color = Color(0.55, 1.0, 0.65, 0.22)

var _t: float = 0.0
var _rnd: float = 0.0

func setup(world_pos: Vector2, dir: Vector2 = Vector2.RIGHT) -> void:
	global_position = world_pos
	var d: Vector2 = dir.normalized()
	if d.length_squared() < 0.001:
		d = Vector2.RIGHT
	rotation = d.angle()
	_rnd = randf_range(-0.35, 0.35)

func _ready() -> void:
	top_level = true
	z_index = z
	material = null  # pixel-art kit (Batch C): the sprite blends normally
	set_process(true)

func _process(dt: float) -> void:
	_t += dt
	if _t >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var remain: float = lifetime - _t
	var fade: float = 1.0
	if remain < fade_out:
		fade = clampf(remain / maxf(fade_out, 0.001), 0.0, 1.0)
		fade *= fade

	var s: float = scale_mul

	# Pixel-art kit (Batch C, 2026-09-27): a soft disc sprite replaces the glow puff circle.
	VfxKit.draw_disc(self, Vector2.ZERO, 10.0 * s, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade))

	# Pixel-art kit (Batch C, 2026-09-27): one fangs sprite along +X (the node's rotation carries the bite direction, _rnd the wobble) replaces the two fang lines, their white under-strokes and the dark puncture dots.
	VfxKit.draw_fangs(self, Vector2.ZERO, _rnd, 16.0 * s, Color(color_poison.r, color_poison.g, color_poison.b, color_poison.a * fade), 2.4 * s)

	# Pixel-art kit (Batch C, 2026-09-27): one splash sprite, spun by the same wobble, replaces the six scratch "legs".
	VfxKit.draw_splash(self, Vector2.ZERO, 10.0 * s, Color(color_poison.r, color_poison.g, color_poison.b, 0.35 * fade), _rnd * 0.5, 1.3 * s)
