extends RefCounted
class_name EnemyCharge

var _enemy: Enemy = null

var _cd: float = 0.0
var _windup_left: float = 0.0
var _time_left: float = 0.0
var _dir: Vector2 = Vector2.ZERO
var _override_vel: Vector2 = Vector2.ZERO

func setup(enemy: Enemy) -> void:
	_enemy = enemy
	_cd = 0.0
	_windup_left = 0.0
	_time_left = 0.0
	_dir = Vector2.ZERO
	_override_vel = Vector2.ZERO

func tick(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)

func step_override(delta: float) -> bool:
	# returns true if charge logic is currently overriding movement
	if _enemy == null or not is_instance_valid(_enemy):
		_override_vel = Vector2.ZERO
		return false

	if _windup_left > 0.0:
		_windup_left = maxf(_windup_left - delta, 0.0)
		_override_vel = Vector2.ZERO
		return true

	if _time_left > 0.0:
		_time_left = maxf(_time_left - delta, 0.0)
		var spd: float = (_enemy.spec.charge_speed if _enemy.spec != null else 520.0)
		_override_vel = _dir * spd
		return true

	_override_vel = Vector2.ZERO
	return false

func override_velocity() -> Vector2:
	return _override_vel

func brain(to_player: Vector2, dist: float) -> Vector2:
	if _enemy == null or not is_instance_valid(_enemy):
		return Vector2.ZERO
	if _enemy.spec == null:
		return to_player * _enemy._spd()

	# If we're already charging/winding up, Enemy.gd will handle override movement
	if _windup_left > 0.0 or _time_left > 0.0:
		return Vector2.ZERO

	if _cd <= 0.0 and dist <= _enemy.spec.charge_trigger_range:
		_dir = (to_player.normalized() if to_player != Vector2.ZERO else Vector2.RIGHT)
		_windup_left = maxf(_enemy.spec.charge_windup, 0.0)
		_time_left = maxf(_enemy.spec.charge_duration, 0.01)
		_cd = maxf(_enemy.spec.charge_cooldown, 0.1)

		# Windup VFX (child so it follows)
		var v: VFX_ChargeWindup = VFX_ChargeWindup.new()
		_enemy.add_child(v)
		v.setup(_dir, _windup_left)

		return Vector2.ZERO

	return to_player * _enemy._spd()
