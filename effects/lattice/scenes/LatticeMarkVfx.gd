extends Node2D
class_name LatticeMarkVfx

var _mirrored: bool = false
var _life: float = 1.0
var _maximum: float = 1.0

func setup(world_position: Vector2, mirrored: bool, lifetime: float) -> void:
	global_position = world_position
	_mirrored = mirrored
	_life = maxf(0.05, lifetime)
	_maximum = _life
	queue_redraw()

func _process(delta: float) -> void:
	_life = maxf(0.0, _life - delta)
	queue_redraw()
	if _life <= 0.0:
		queue_free()

func _draw() -> void:
	var alpha: float = clampf(_life / _maximum, 0.0, 1.0)
	var color := Color(0.86, 0.50, 1.0, 0.85 * alpha) if _mirrored else Color(0.50, 0.92, 1.0, 0.85 * alpha)
	if _mirrored:
		# Pixel-art kit (Batch D, 2026-09-27): the mirrored diamond + cross is
		# one lattice_mirror sprite (diamond half-diagonal 15 px).
		VfxKit.draw_lattice_mirror(self, Vector2.ZERO, 15.0, color, 0.0, 2.2)
	else:
		# Pixel-art kit (Batch D, 2026-09-27): one lattice-mark sprite (ring and
		# three ticks, tick reach 17 px) replaces the r 14 arc and the three
		# tick lines.
		VfxKit.draw_lattice_mark(self, Vector2.ZERO, 17.0, color, 0.0, 2.0)
	var remaining_angle: float = TAU * alpha
	draw_arc(Vector2.ZERO, 19.0, -PI * 0.5, -PI * 0.5 + remaining_angle, 24, Color(color.r, color.g, color.b, 0.45 * alpha), 1.0, true)
