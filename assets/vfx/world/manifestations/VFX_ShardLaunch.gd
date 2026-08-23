extends Node2D
class_name VFX_ShardLaunch

## The moment a full halo empties itself down the aim line: the orbit snaps
## outward as a ring and the launch cone tears open behind the shards.

@export var duration: float = 0.26
@export var radius: float = 96.0
@export var tint: Color = Color(0.72, 0.95, 1.0)

var _facing: Vector2 = Vector2.RIGHT
var _lines: Array[Dictionary] = []
var _t: float = 0.0


func setup(origin: Vector2, direction: Vector2, count: int, ring_radius: float) -> void:
	global_position = origin
	_facing = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	radius = ring_radius
	_build(count)


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4073
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if _lines.is_empty():
		_build(4)
	set_process(true)
	queue_redraw()


func _build(count: int) -> void:
	_lines.clear()
	var spread := deg_to_rad(34.0)
	var n := maxi(2, count)
	for i in range(n):
		var t: float = float(i) / float(n - 1)
		_lines.append({
			"angle": lerpf(-spread * 0.5, spread * 0.5, t),
			"reach": randf_range(0.78, 1.25),
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

	var ring := lerpf(radius * 0.35, radius, eased)
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.45 * fade), 11.0, true)
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.85 * fade), 2.2, true)

	for line in _lines:
		var dir := _facing.rotated(float(line.get("angle", 0.0)))
		var reach: float = radius * 2.1 * float(line.get("reach", 1.0)) * eased
		var head := dir * reach
		var tail := dir * (reach * 0.35)
		draw_line(tail, head, Color(tint.r, tint.g, tint.b, 0.40 * fade), 8.0, true)
		draw_line(tail, head, Color(1.0, 1.0, 1.0, 0.80 * fade), 2.0, true)

	draw_circle(Vector2.ZERO, lerpf(26.0, 8.0, p), Color(1.0, 1.0, 1.0, 0.55 * fade))
