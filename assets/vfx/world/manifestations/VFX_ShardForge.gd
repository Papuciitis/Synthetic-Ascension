extends Node2D
class_name VFX_ShardForge

## Fragments converging into the shard orbit: one mote when a Lucky Crit forges
## a shard, a handful when an elite shatters. The flight is drawn in local space
## so the whole effect is one node with no children and no assets.

@export var duration: float = 0.34
@export var tint: Color = Color(0.72, 0.95, 1.0)

var _target: Vector2 = Vector2.ZERO
var _frags: Array[Dictionary] = []
var _t: float = 0.0


## Safe either side of add_child(); `to` is resolved to a local offset here so
## the effect keeps flying even though the player moves out from under it.
func setup(from: Vector2, to: Vector2, count: int, colour: Color) -> void:
	global_position = from
	_target = to - from
	tint = colour
	_build(count)


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4072
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if _frags.is_empty():
		_build(1)
	set_process(true)
	queue_redraw()


func _build(count: int) -> void:
	_frags.clear()
	for _i in range(maxi(1, count)):
		_frags.append({
			"bow": randf_range(-0.5, 0.5),
			"spin": randf_range(-11.0, 11.0),
			"lag": randf_range(0.0, 0.20),
			"size": randf_range(0.75, 1.30),
		})


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var flash := 1.0 - p
	flash *= flash
	draw_circle(Vector2.ZERO, lerpf(28.0, 5.0, p), Color(tint.r, tint.g, tint.b, 0.38 * flash))

	var side := Vector2(-_target.y, _target.x) * 0.32
	for frag in _frags:
		var lag := float(frag.get("lag", 0.0))
		var k := clampf((p - lag) / maxf(1.0 - lag, 0.001), 0.0, 1.0)
		var eased := k * k * (3.0 - 2.0 * k)
		var pos := _target * eased + side * float(frag.get("bow", 0.0)) * sin(eased * PI)
		var fade := 1.0 - eased
		var size := float(frag.get("size", 1.0)) * (0.55 + 0.45 * fade)
		draw_circle(pos, 7.0 * size, Color(tint.r, tint.g, tint.b, 0.30 * fade))
		var angle := float(frag.get("spin", 0.0)) * _t
		var facing := Vector2(cos(angle), sin(angle))
		var flank := Vector2(-facing.y, facing.x)
		draw_colored_polygon(PackedVector2Array([
			pos + facing * 6.5 * size,
			pos + flank * 3.0 * size,
			pos - facing * 6.5 * size,
			pos - flank * 3.0 * size,
		]), Color(1.0, 1.0, 1.0, 0.90 * fade))
