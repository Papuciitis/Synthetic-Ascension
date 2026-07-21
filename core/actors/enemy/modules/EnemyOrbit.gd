extends RefCounted
class_name EnemyOrbit

var _owner: Enemy = null
var _angle: float = 0.0

func setup(owner: Enemy) -> void:
	_owner = owner
	_angle = Global._rng.randf() * TAU

func brain(delta: float, spd: float) -> Vector2:
	if _owner == null or _owner.spec == null or _owner.player == null:
		return Vector2.ZERO

	var spec: EnemySpec = _owner.spec
	_angle += spec.orbit_turn_speed * delta

	var target: Vector2 = _owner.player.global_position + Vector2.RIGHT.rotated(_angle) * spec.orbit_radius
	var v: Vector2 = target - _owner.global_position
	if v.length_squared() < 0.001:
		return Vector2.ZERO
	return v.normalized() * spd
