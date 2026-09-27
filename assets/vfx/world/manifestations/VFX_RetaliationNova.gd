extends Node2D
class_name VFX_RetaliationNova

## The answer to an evade: a hard white core that throws a gold shock ring out
## to exactly the radius the nova damaged, so the player can read its reach.

@export var duration: float = 0.30
@export var radius: float = 150.0
@export var color_core: Color = Color(1.00, 0.95, 0.78, 1.0)
@export var color_glow: Color = Color(1.00, 0.62, 0.22, 0.85)

var _spokes: Array[float] = []
var _t: float = 0.0


func setup(origin: Vector2, nova_radius: float) -> void:
	global_position = origin
	radius = nova_radius
	_build()


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4074
	material = null  # pixel-art kit (Batch B): the sprite blends normally
	if _spokes.is_empty():
		_build()
	set_process(true)
	queue_redraw()


func _build() -> void:
	_spokes.clear()
	var offset := randf() * TAU
	for i in range(9):
		_spokes.append(offset + TAU * float(i) / 9.0 + randf_range(-0.10, 0.10))


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var fade := 1.0 - p
	fade *= fade
	var eased := 1.0 - pow(1.0 - p, 3.0)
	var r := lerpf(radius * 0.22, radius, eased)

	# Pixel-art kit (Batch B, 2026-09-27): the disc sprite replaces the glow
	# fill, one ring sprite in the core colour replaces the glow+core arc pair,
	# the fourteen-spoke sprite replaces the nine glow+core spoke line pairs
	# (spun by the random offset _build rolled), and a small disc replaces the
	# white centre flash.
	VfxKit.draw_disc(self, Vector2.ZERO, r, Color(color_glow.r, color_glow.g, color_glow.b, 0.14 * fade))
	VfxKit.draw_ring(self, Vector2.ZERO, r, Color(color_core.r, color_core.g, color_core.b, 0.95 * fade), 3.0)

	var spin: float = _spokes[0] if not _spokes.is_empty() else 0.0
	VfxKit.draw_spokes(self, Vector2.ZERO, r * 1.12, Color(color_core.r, color_core.g, color_core.b, 0.75 * fade), spin)

	VfxKit.draw_disc(self, Vector2.ZERO, lerpf(34.0, 6.0, p), Color(1.0, 1.0, 1.0, 0.70 * fade))
