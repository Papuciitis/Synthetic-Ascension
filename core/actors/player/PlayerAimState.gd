extends RefCounted
class_name PlayerAimState

var _controller_active := false
var _direction := Vector2.RIGHT


func note_mouse_motion() -> void:
	_controller_active = false


func update_stick(vector: Vector2, deadzone: float) -> bool:
	if vector.length() < clampf(deadzone, 0.0, 0.99):
		return false
	_direction = vector.normalized()
	_controller_active = true
	return true


func resolve_target(origin: Vector2, mouse_target: Vector2, controller_distance: float) -> Vector2:
	if not _controller_active:
		return mouse_target
	return origin + _direction * controller_distance


func using_controller() -> bool:
	return _controller_active


func direction() -> Vector2:
	return _direction
