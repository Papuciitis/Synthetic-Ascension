extends Node2D
class_name WardstoneAttuneBurst

@export var duration: float = 0.62
@export var line_width: float = 10.0
@export var dash_count: int = 12
@export var dash_gap: float = 0.26
@export var z: int = 210

var _radius: float = 76.0
var _t: float = 0.0

func setup(pos: Vector2, radius: float) -> void:
	global_position = pos
	_radius = maxf(radius, 1.0)

func _ready() -> void:
	z_index = z
	material = null  # pixel-art kit (Batch B): the sprite blends normally
	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return
	queue_redraw()

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _draw() -> void:
	var p: float = clampf(_t / duration, 0.0, 1.0)
	var k: float = 1.0 - p
	k = k * k

	var r0: float = _radius * 0.35
	var r: float = lerpf(r0, _radius * 1.25, _ease_out(p))
	var w: float = lerpf(line_width, line_width * 0.35, p)

	# Pixel-art kit (Batch B, 2026-09-27): a soft disc sprite replaces the flash circle, one dashed-ring sprite (spun as the dashes were) replaces the twelve dash arcs, one ring sprite replaces the inner arc, and one spokes sprite (its own centre dot) replaces the nine spoke lines and the centre kick circle.
	var flash := clampf(1.0 - (p / 0.32), 0.0, 1.0)
	if flash > 0.0:
		VfxKit.draw_disc(self, Vector2.ZERO, r * 0.52, Color(0.55, 0.88, 1.0, 0.22 * flash * k))

	var base_col := Color(0.92, 0.98, 1.0, 0.85 * k)
	VfxKit.draw_ring_dashed(self, Vector2.ZERO, r, base_col, p * 0.35, w)

	var r2 := r * 0.72
	VfxKit.draw_ring(self, Vector2.ZERO, r2, Color(0.55, 0.85, 1.0, 0.22 * k), maxf(2.0, w * 0.25))

	var spoke_len := r * 0.44
	var spoke_col := Color(0.75, 0.93, 1.0, 0.55 * k)
	VfxKit.draw_spokes(self, Vector2.ZERO, r * 0.15 + spoke_len, spoke_col, p * 0.65)
