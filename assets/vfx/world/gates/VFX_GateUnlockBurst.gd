extends Node2D
class_name GateUnlockBurst

@export var duration: float = 0.55
@export var radius: float = 120.0
@export var z: int = 220

var _t: float = 0.0

func setup(pos: Vector2) -> void:
	global_position = pos

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

func _draw() -> void:
	var p := clampf(_t / duration, 0.0, 1.0)
	var k := 1.0 - p
	k = k * k
	var r := lerpf(radius * 0.25, radius, 1.0 - pow(1.0 - p, 3.0))

	# Pixel-art kit (Batch B, 2026-09-27): two ring sprites replace the double arc, and a soft disc sprite replaces the early flash circle.
	VfxKit.draw_ring(self, Vector2.ZERO, r, Color(0.65, 0.90, 1.0, 0.55 * k), 6.0)
	VfxKit.draw_ring(self, Vector2.ZERO, r * 0.72, Color(0.98, 0.92, 0.55, 0.25 * k), 4.0)
	var f := clampf(1.0 - (p / 0.25), 0.0, 1.0)
	if f > 0.0:
		VfxKit.draw_disc(self, Vector2.ZERO, r * 0.45, Color(0.75, 0.94, 1.0, 0.18 * f * k))
