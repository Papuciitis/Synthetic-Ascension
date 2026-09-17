extends Node2D
class_name VFX_PairShatter

## Reliquary Guard's absorb: a shard on the orbit ring cracks apart and its
## fragments are thrown outward while the ward flares behind them.
##
## The hit that triggered this is reported at the PLAYER's position, not the
## attacker's, so there is no bearing to lean the burst along - it reads as the
## orbit itself giving way, which is what happened.

@export var duration: float = 0.30
@export var radius: float = 46.0
@export var tint: Color = Color(0.72, 0.95, 1.00)

const FRAGMENTS: int = 7

var _shards: Array[Dictionary] = []
var _t: float = 0.0


func setup(origin: Vector2, orbit_radius: float, shard_tint: Color) -> void:
	global_position = origin
	radius = orbit_radius
	tint = shard_tint
	_build()


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4074
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if _shards.is_empty():
		_build()
	set_process(true)
	queue_redraw()


## Built once up front rather than per frame: this can fire four times a second
## under contact damage and the draw loop must not allocate.
func _build() -> void:
	_shards.clear()
	var offset := randf() * TAU
	for i in range(FRAGMENTS):
		_shards.append({
			"angle": offset + TAU * float(i) / float(FRAGMENTS) + randf_range(-0.18, 0.18),
			"reach": randf_range(0.55, 1.20),
			"spin": randf_range(-9.0, 9.0),
		})


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

	# The ward flare: a ring at the orbit that brightens and thins as it takes
	# the hit the player did not.
	draw_arc(Vector2.ZERO, radius * (1.0 + 0.28 * eased), 0.0, TAU, 40,
		Color(tint.r, tint.g, tint.b, 0.32 * fade), 6.0 * fade + 1.0, true)

	for shard in _shards:
		var angle := float(shard.get("angle", 0.0))
		var dir := Vector2(cos(angle), sin(angle))
		var reach: float = radius * (1.0 + 0.85 * float(shard.get("reach", 1.0)) * eased)
		var at := dir * reach
		var facing := dir.rotated(float(shard.get("spin", 0.0)) * eased)
		var side := Vector2(-facing.y, facing.x)
		var scale_out := 1.0 - 0.45 * eased
		draw_colored_polygon(PackedVector2Array([
			at + facing * 6.5 * scale_out,
			at + side * 3.0 * scale_out,
			at - facing * 6.5 * scale_out,
			at - side * 3.0 * scale_out,
		]), Color(1.0, 1.0, 1.0, 0.85 * fade))

	draw_circle(Vector2.ZERO, lerpf(14.0, 3.0, p), Color(tint.r, tint.g, tint.b, 0.45 * fade))
