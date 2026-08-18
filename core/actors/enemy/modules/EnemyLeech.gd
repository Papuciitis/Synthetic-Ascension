extends RefCounted
class_name EnemyLeech

var _enemy: EnemyActor = null
var _touching_player_hurtbox: int = 0
var _loop_running: bool = false
# SceneTreeTimers ignore process_mode, so a drain loop awaiting one survives
# pool recycle. The generation counter invalidates coroutines from a previous
# life so a reused enemy can never run two drain loops at once.
var _loop_generation: int = 0

func setup(enemy: EnemyActor) -> void:
	_enemy = enemy
	_touching_player_hurtbox = 0
	_loop_running = false
	_loop_generation += 1

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
	var generation := _loop_generation

	while (
		is_instance_valid(_enemy)
		and _enemy.is_inside_tree()
		and _touching_player_hurtbox > 0
		and not _enemy.dead
	):
		if _enemy.spec == null:
			break

		if _enemy.spec.leech_amount > 0:
			Global.transaction_followers(-_enemy.spec.leech_amount, &"enemy_drain", {"enemy_id": String(_enemy.spec.id)}, true, true)

		await _enemy.get_tree().create_timer(maxf(_enemy.spec.leech_every, 0.05)).timeout
		if generation != _loop_generation:
			return

	if generation == _loop_generation:
		_loop_running = false
