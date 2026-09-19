extends Line2D
class_name VFX_ArcLine

@export var lifetime := 0.08
@export var segments := 6
@export var jitter := 12.0

func setup(from: Vector2, to: Vector2) -> void:
	clear_points()

	var dir := to - from
	var dist: float = dir.length()
	if dist < 0.001:
		add_point(from)
		add_point(to)
		return

	var n := Vector2(-dir.y, dir.x).normalized()

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := from.lerp(to, t)

		var w := 1.0 - absf(t * 2.0 - 1.0)
		var off := n * randf_range(-jitter, jitter) * w
		add_point(p + off)

var _tween: Tween = null

func _ready() -> void:
	z_index = 100
	width = 4.0
	_start_fade()

## Pooled reuse (PooledVfx): opaque again, a new fade.
func _on_pool_obtain() -> void:
	clear_points()
	_start_fade()

func _on_pool_recycle() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func _start_fade() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, lifetime)
	_tween.tween_callback(func() -> void: PooledVfx.release(self))
