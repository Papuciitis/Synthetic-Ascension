extends Node2D

## World marker for Predestination Sigil's Mark.
##
## Lives in the world scene rather than under the player because it tracks an
## enemy handle, not the caster. Fully procedural - no texture, no scene file.

const FADE_TIME: float = 0.22
const BURST_TIME: float = 0.42

var handle: int = 0
var time_left: float = 0.0
var time_total: float = 1.0
var burst_radius: float = 190.0

var color_core: Color = Color(1.00, 0.84, 0.34, 1.0)
var color_glow: Color = Color(0.74, 0.32, 1.00, 0.70)

var _t: float = 0.0
var _fade: float = 0.0
var _burst: float = 0.0


func setup(enemy_handle: int, duration: float) -> void:
	handle = enemy_handle
	time_left = duration
	time_total = maxf(duration, 0.001)


func _ready() -> void:
	z_as_relative = false
	z_index = 4090
	top_level = true
	material = null  # pixel-art kit (Batch D): the sprite blends normally
	set_process(true)


## Stop tracking and dissolve. Safe to call more than once.
func release() -> void:
	if _fade <= 0.0 and _burst <= 0.0:
		_fade = FADE_TIME


func detonate(at: Vector2, radius: float) -> void:
	global_position = at
	burst_radius = maxf(radius, 8.0)
	_burst = BURST_TIME
	_fade = 0.0


func _process(delta: float) -> void:
	_t += delta

	if _burst > 0.0:
		_burst -= delta
		if _burst <= 0.0:
			queue_free()
			return
		queue_redraw()
		return

	if _fade > 0.0:
		_fade -= delta
		if _fade <= 0.0:
			queue_free()
			return
		queue_redraw()
		return

	time_left -= delta
	if time_left <= 0.0:
		release()
		return

	# The handle is the only link to the enemy, and a recycled or despawned one
	# answers with the origin - that is the world's "not here any more".
	if EnemyCombat != null:
		var here: Vector2 = EnemyCombat.position_for_handle(handle)
		if here == Vector2.ZERO:
			release()
			return
		global_position = here

	queue_redraw()


func _draw() -> void:
	if _burst > 0.0:
		_draw_burst()
		return

	var alpha: float = 1.0 if _fade <= 0.0 else (_fade / FADE_TIME)
	var pulse: float = 0.90 + 0.10 * sin(_t * 5.5)
	var radius: float = 30.0 * pulse

	# Pixel-art kit (Batch D, 2026-09-27): the disc sprite replaces the glow circle and the ring sprite replaces the glow arc.
	VfxKit.draw_disc(self, Vector2.ZERO, radius * 1.25, Color(color_glow.r, color_glow.g, color_glow.b, 0.14 * alpha))
	VfxKit.draw_ring(self, Vector2.ZERO, radius, Color(color_glow.r, color_glow.g, color_glow.b, 0.55 * alpha), 2.4)

	# A slowly counter-rotating triangle over a fixed one: reads as "aimed at",
	# not as generic enemy decoration.
	# Pixel-art kit (Batch D, 2026-09-27): two triangle sprites, spun by the same phases, replace the two polyline triangles.
	VfxKit.draw_triangle(self, Vector2.ZERO, radius * 0.86, Color(color_core.r, color_core.g, color_core.b, 0.85 * alpha), _t * 0.8, 2.0)
	VfxKit.draw_triangle(self, Vector2.ZERO, radius * 0.86, Color(color_core.r, color_core.g, color_core.b, 0.45 * alpha), -_t * 0.55 + PI, 1.4)

	# Countdown ring, so the player can see how long the target is worth chasing.
	var remaining: float = clampf(time_left / time_total, 0.0, 1.0)
	if remaining > 0.0:
		draw_arc(
			Vector2.ZERO,
			radius * 1.32,
			-PI * 0.5,
			-PI * 0.5 + TAU * remaining,
			34,
			Color(1.0, 0.95, 0.80, 0.70 * alpha),
			2.0,
			true
		)

	# Pixel-art kit (Batch D, 2026-09-27): a small disc sprite replaces the centre dot.
	VfxKit.draw_disc(self, Vector2.ZERO, 3.4 * pulse, Color(1.0, 0.96, 0.86, 0.95 * alpha))


func _draw_burst() -> void:
	var t: float = clampf(_burst / BURST_TIME, 0.0, 1.0)
	var grow: float = 1.0 - t
	var radius: float = burst_radius * (0.25 + 0.80 * grow)
	# Pixel-art kit (Batch D, 2026-09-27): disc, ring and triangle sprites replace
	# the glow circle, the growing arc and the polyline triangle; the spokes
	# sprite (spun by the same drift) replaces the nine radial lines.
	VfxKit.draw_disc(self, Vector2.ZERO, radius, Color(color_glow.r, color_glow.g, color_glow.b, 0.22 * t))
	VfxKit.draw_ring(self, Vector2.ZERO, radius, Color(color_core.r, color_core.g, color_core.b, 0.85 * t), 4.0 * t + 1.0)
	VfxKit.draw_triangle(self, Vector2.ZERO, radius * 0.72, Color(1.0, 0.92, 0.70, 0.70 * t), grow * 2.4, 3.0)
	VfxKit.draw_spokes(self, Vector2.ZERO, radius * (1.05 + 0.15 * grow), Color(1.0, 0.80, 0.40, 0.60 * t), grow * 1.2)
