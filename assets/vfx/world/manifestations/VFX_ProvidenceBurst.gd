extends Node2D
class_name VFX_ProvidenceBurst

## Broken Providence cashing out: a gold shockwave with one spoke per banked
## point of Misfortune, so the size of the jackpot is legible at a glance.

@export var duration: float = 0.42
@export var radius: float = 120.0
@export var spokes: int = 8

const CORE: Color = Color(1.0, 0.95, 0.72, 1.0)
const GLOW: Color = Color(1.0, 0.72, 0.14, 0.85)

var _t: float = 0.0


func setup(r: float, banked: int) -> void:
	radius = r
	spokes = clampi(banked, 1, 25)


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 3998
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
	var p: float = clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var fade: float = (1.0 - p) * (1.0 - p)
	var r: float = lerpf(radius * 0.25, radius, sqrt(p))

	# Pixel-art kit (Batch B, 2026-09-27): the disc sprite replaces the glow
	# fill, one ring sprite in the core colour replaces the glow+core arc pair,
	# and the fourteen-spoke sprite replaces the one-line-per-point spokes; its
	# alpha scales with the banked count so a small payout still reads fainter.
	VfxKit.draw_disc(self, Vector2.ZERO, r * 0.55, Color(GLOW.r, GLOW.g, GLOW.b, 0.22 * fade))
	VfxKit.draw_ring(self, Vector2.ZERO, r, Color(CORE.r, CORE.g, CORE.b, fade), 2.5)

	# Spokes lag the ring slightly so the burst reads as thrown outward.
	var spoke_r: float = r * lerpf(0.35, 1.12, p)
	VfxKit.draw_spokes(self, Vector2.ZERO, spoke_r, Color(CORE.r, CORE.g, CORE.b, 0.9 * fade * minf(1.0, float(spokes) / 14.0)), 0.0)
