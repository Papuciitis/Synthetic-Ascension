extends Node2D
class_name RitePulseVFX

var _target_radius := 420.0
var _duration := 0.96
var _age := 0.0
var _accent := Color(0.94, 0.68, 0.28, 1.0)


func setup(target_radius: float, final_seal: bool = false) -> void:
	_target_radius = maxf(32.0, target_radius)
	_accent = Color(0.98, 0.91, 0.70, 1.0) if final_seal else Color(0.94, 0.58, 0.18, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / _duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var ring_radius := lerpf(18.0, _target_radius, eased)
	var alpha := pow(1.0 - t, 1.6)
	var colour := Color(_accent.r, _accent.g, _accent.b, alpha)
	# A short translucent front makes the displacement read as an authored
	# repulsion, not enemies coincidentally sliding. It never shakes the camera.
	draw_circle(Vector2.ZERO, ring_radius, Color(colour.r, colour.g, colour.b, alpha * 0.055))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 96, colour, lerpf(8.0, 2.0, t), true)
	draw_arc(Vector2.ZERO, maxf(4.0, ring_radius - 9.0), 0.0, TAU, 96, Color(colour.r, colour.g, colour.b, alpha * 0.38), 1.0, true)
	draw_arc(Vector2.ZERO, maxf(4.0, ring_radius * 0.72), 0.0, TAU, 96, Color(colour.r, colour.g, colour.b, alpha * 0.24), 2.0, true)
	# Fixed ceremonial fragments read as dust/resonant material without relying
	# on a neon particle texture or introducing random capture variance.
	for index in range(16):
		var angle := TAU * float(index) / 16.0 + 0.12 * sin(float(index) * 2.7)
		var offset := Vector2.from_angle(angle) * (ring_radius - 4.0 + float(index % 3) * 5.0)
		draw_circle(offset, lerpf(2.2, 0.6, t), Color(colour.r, colour.g, colour.b, alpha * 0.65))
