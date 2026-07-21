extends RefCounted
class_name EnemyLeech

var _enemy: Enemy = null
var _touching_player_hurtbox: int = 0
var _loop_running: bool = false

func setup(enemy: Enemy) -> void:
	_enemy = enemy
	_touching_player_hurtbox = 0
	_loop_running = false

func on_hitbox_area_entered(a: Area2D) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if _enemy.spec == null:
		return
	if _enemy.spec.ai != EnemySpec.AI.LEECH:
		return
	if a != null and a.is_in_group("player_hurtbox"):
		_touching_player_hurtbox += 1
		_start_loop()

func on_hitbox_area_exited(a: Area2D) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if _enemy.spec == null:
		return
	if _enemy.spec.ai != EnemySpec.AI.LEECH:
		return
	if a != null and a.is_in_group("player_hurtbox"):
		_touching_player_hurtbox = maxi(_touching_player_hurtbox - 1, 0)

func _start_loop() -> void:
	if _loop_running:
		return
	_loop_running = true

	while _touching_player_hurtbox > 0 and not _enemy.dead:
		if _enemy.spec == null:
			break

		if _enemy.spec.leech_amount > 0:
			Global.transaction_followers(-_enemy.spec.leech_amount, &"enemy_drain", {"enemy_id": String(_enemy.spec.id)}, true, true)

		await _enemy.get_tree().create_timer(maxf(_enemy.spec.leech_every, 0.05)).timeout

	_loop_running = false
