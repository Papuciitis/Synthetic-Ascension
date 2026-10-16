extends RefCounted
class_name EnemyCharge

const BossWindupSprites = preload("res://scenes/world/bosses/BossWindupSprites.gd")
const BossAttackScope = preload("res://scenes/world/bosses/BossAttackScope.gd")

var _enemy: EnemyActor = null

var _cd: float = 0.0
var _windup_left: float = 0.0
var _time_left: float = 0.0
var _dir: Vector2 = Vector2.ZERO
var _override_vel: Vector2 = Vector2.ZERO
var _committed_speed: float = -1.0
## Lurker state: seconds left dormant after spawning, and how long the
## player has been still (a small velocity counts as still).
var _dormant_left: float = 0.0
var _player_still_for: float = 0.0
const STILL_SPEED := 12.0

func setup(enemy: EnemyActor) -> void:
	_enemy = enemy
	_cd = 0.0
	_windup_left = 0.0
	_time_left = 0.0
	_dir = Vector2.ZERO
	_override_vel = Vector2.ZERO
	_committed_speed = -1.0
	_dormant_left = maxf(enemy.spec.charge_dormant_seconds, 0.0) if enemy != null and enemy.spec != null else 0.0
	_player_still_for = 0.0

func tick(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	_dormant_left = maxf(_dormant_left - delta, 0.0)
	if _enemy != null and is_instance_valid(_enemy) and _enemy.spec != null and _enemy.spec.charge_only_when_player_still:
		var player: Node = _enemy.player
		if player != null and is_instance_valid(player) and "velocity" in player and (player.velocity as Vector2).length() <= STILL_SPEED:
			_player_still_for += delta
		else:
			_player_still_for = 0.0


func player_still_for() -> float:
	return _player_still_for


func is_dormant() -> bool:
	return _dormant_left > 0.0


## The S5 boss controller chooses the action; ordinary Chargers still choose
## through brain(). Movement continues on the actor's existing physics clock.
func begin_committed(direction: Vector2, duration: float, speed: float) -> void:
	_dir = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_windup_left = 0.0
	_time_left = maxf(duration, 0.01)
	_committed_speed = maxf(speed, 0.0)
	_override_vel = Vector2.ZERO


func cancel() -> void:
	_windup_left = 0.0
	_time_left = 0.0
	_committed_speed = -1.0
	_override_vel = Vector2.ZERO

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
		var remaining := _time_left
		_time_left = maxf(_time_left - delta, 0.0)
		var spd: float = _committed_speed if _committed_speed >= 0.0 else (_enemy.spec.charge_speed if _enemy.spec != null else 520.0)
		# The controller previews speed * duration. A coarse final step must
		# spend only its remaining commitment, not an extra whole physics tick.
		if _committed_speed >= 0.0:
			spd *= minf(maxf(delta, 0.0), remaining) / maxf(delta, 0.000001)
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

	# If we're already charging/winding up, EnemyActor.gd will handle override movement
	if _windup_left > 0.0 or _time_left > 0.0:
		return Vector2.ZERO

	var spec: EnemySpec = _enemy.spec
	if bool(_enemy.get_meta(&"boss_controller_owns_charge", false)) and not _enemy.is_in_group(&"boss"):
		return to_player * _enemy._spd()
	if _dormant_left > 0.0:
		return Vector2.ZERO
	if spec.charge_only_when_player_still and _player_still_for < spec.charge_player_still_seconds:
		# Lurk: hold the distance, drift closer when far, back off when near.
		if to_player == Vector2.ZERO:
			return Vector2.ZERO
		var hold := maxf(spec.charge_hold_distance, 40.0)
		if dist > hold * 1.15:
			return to_player.normalized() * _enemy._spd() * 0.8
		if dist < hold * 0.85:
			return -to_player.normalized() * _enemy._spd() * 0.8
		return Vector2.ZERO
	if _cd <= 0.0 and dist <= _enemy.spec.charge_trigger_range:
		_committed_speed = -1.0
		_dir = (to_player.normalized() if to_player != Vector2.ZERO else Vector2.RIGHT)
		_windup_left = maxf(_enemy.spec.charge_windup, 0.0)
		_time_left = maxf(_enemy.spec.charge_duration, 0.01)
		_cd = maxf(_enemy.spec.charge_cooldown, 0.1)

		# Windup VFX (child so it follows)
		if _enemy.get_meta(&"boss_archetype", "") == "tank":
			var cue := BossWindupSprites.new()
			cue.setup(_dir, _windup_left, &"charge", spec.charge_speed * spec.charge_duration)
			BossAttackScope.bind(cue, _enemy)
			_enemy.add_child(cue)
		else:
			var v: VFX_ChargeWindup = VFX_ChargeWindup.new()
			_enemy.add_child(v)
			v.setup(_dir, _windup_left)

		return Vector2.ZERO

	return to_player * _enemy._spd()
