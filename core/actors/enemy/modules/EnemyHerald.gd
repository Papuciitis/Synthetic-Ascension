extends RefCounted
class_name EnemyHerald

var _enemy: Enemy = null
var _pulse_cd: float = 0.0

func setup(enemy: Enemy) -> void:
	_enemy = enemy
	if _enemy != null and _enemy.spec != null:
		var every: float = maxf(_enemy.spec.herald_pulse_every, 0.2)
		_pulse_cd = Global._rng.randf_range(0.2, every)
	else:
		_pulse_cd = 0.0

func tick(delta: float) -> void:
	_pulse_cd = maxf(_pulse_cd - delta, 0.0)

func brain(to_player: Vector2, dist: float) -> Vector2:
	if _enemy == null or not is_instance_valid(_enemy):
		return Vector2.ZERO
	if _enemy.spec == null:
		return to_player * _enemy._spd()

	# identity pulse
	if _pulse_cd <= 0.0:
		_do_pulse()
		_pulse_cd = maxf(_enemy.spec.herald_pulse_every, 0.2)

	# movement: kite (calmer)
	var spd: float = _enemy._spd()

	var desired: Vector2 = Vector2.ZERO
	var min_d: float = _enemy.spec.preferred_range - _enemy.spec.range_tolerance
	var max_d: float = _enemy.spec.preferred_range + _enemy.spec.range_tolerance

	if dist < min_d:
		desired = -to_player * spd
	elif dist > max_d:
		desired = to_player * spd * 0.45

	var strafe: Vector2 = Vector2(-to_player.y, to_player.x)
	desired += strafe * (spd * (_enemy.spec.strafe_strength + 0.25))

	# optional plink-shot (uses the SAME shooter module as spitter)
	var has_los: bool = false
	if _enemy.has_method("has_los_cached"):
		has_los = _enemy.has_los_cached()
	else:
		has_los = _enemy.has_los_to_player()
	if has_los:
		_enemy._shooter.shoot_if_ready(to_player)

	return desired

func _do_pulse() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if _enemy.spec == null:
		return

	var r: float = maxf(_enemy.spec.herald_pulse_radius, 0.0)
	if r <= 1.0:
		return

	# Buff nearby enemies (use EnemyIndex spatial hash if available)
	var ei := _enemy.get_node_or_null("/root/EnemyIndex")
	if ei != null and is_instance_valid(ei) and ei.has_method("gather_in_radius"):
		var gathered: Array = []
		ei.call("gather_in_radius", _enemy.global_position, r, gathered)
		for n in gathered:
			var e: Enemy = n as Enemy
			if e == null or e == _enemy:
				continue
			e.apply_speed_buff(_enemy.spec.herald_ally_speed_mult, _enemy.spec.herald_ally_speed_duration)
	else:
		var nodes: Array = _enemy.get_tree().get_nodes_in_group("enemies")
		for n in nodes:
			var e: Enemy = n as Enemy
			if e == null or e == _enemy:
				continue
			if e.global_position.distance_to(_enemy.global_position) <= r:
				e.apply_speed_buff(_enemy.spec.herald_ally_speed_mult, _enemy.spec.herald_ally_speed_duration)

	# Drain followers if player is inside radius
	if _enemy.spec.herald_player_drain_followers and _enemy.spec.herald_player_drain_amount > 0:
		if _enemy.player != null and is_instance_valid(_enemy.player):
			if _enemy.player.global_position.distance_to(_enemy.global_position) <= r:
				Global.transaction_followers(-_enemy.spec.herald_player_drain_amount, &"enemy_drain", {"enemy_id": String(_enemy.spec.id)}, true, true)

	# VFX pulse ring
	var v: VFX_HeraldPulseRing = VFX_HeraldPulseRing.new()
	_enemy.get_tree().current_scene.add_child(v)
	v.setup(_enemy.global_position, r)
