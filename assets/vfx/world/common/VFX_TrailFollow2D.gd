extends Node2D
class_name VFX_TrailFollow2D

@export var max_points: int = 10
@export var point_spacing: float = 16.0
@export var width: float = 4.5
@export var alpha: float = 0.28
@export var fade_time: float = 0.14
@export var z: int = 205

@export var color_core: Color = Color(0.92, 0.98, 1.0, 1.0)
@export var color_glow: Color = Color(0.25, 0.65, 1.0, 1.0)
@export var glow_mul: float = 0.55   # 0 = no glow, 1 = full glow

var follow: Node2D = null
var _pts: PackedVector2Array = PackedVector2Array()
var _fading: bool = false
var _t: float = 0.0

func _ready() -> void:
	z_index = z
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and pm.has_method("get_additive_material"):
		material = pm.call("get_additive_material")
	else:
		material = CanvasItemMaterial.new()
		(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)
	queue_redraw()

func stop_and_fade() -> void:
	_fading = true
	follow = null

func _process(dt: float) -> void:
	var dirty := false

	if follow != null and is_instance_valid(follow):
		var gp := follow.global_position
		if _pts.is_empty():
			_pts.append(gp)
			dirty = true
		else:
			if _pts[_pts.size() - 1].distance_to(gp) >= point_spacing:
				_pts.append(gp)
				dirty = true
				if _pts.size() > max_points:
					_pts.remove_at(0)
	else:
		if not _fading:
			dirty = true
		_fading = true

	if _fading:
		_t += dt
		dirty = true
		if _t >= fade_time:
			queue_free()
			return

	if dirty:
		queue_redraw()

func _draw() -> void:
	if _pts.size() < 2:
		return

	var fade := 1.0
	if _fading:
		fade = 1.0 - clampf(_t / maxf(fade_time, 0.001), 0.0, 1.0)
		fade = fade * fade

	var n := _pts.size()
	for i in range(n - 1):
		var t := float(i) / float(max(1, n - 1))
		var a := (1.0 - t) * alpha * fade
		var w := lerpf(width, width * 0.25, t)

		var p0 := to_local(_pts[i])
		var p1 := to_local(_pts[i + 1])

		if glow_mul > 0.0:
			draw_line(p0, p1, Color(color_glow.r, color_glow.g, color_glow.b, a * 0.55 * glow_mul), w * 1.6, true)

		draw_line(p0, p1, Color(color_core.r, color_core.g, color_core.b, a), w, true)
