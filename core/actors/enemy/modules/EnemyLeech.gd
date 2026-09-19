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

## One bite: the discipline meter for a Siphon (Followers when the build
## carries no meter), Followers for a Leech.
func _drain_once(player: Node) -> void:
	var spec: EnemySpec = _enemy.spec
	if spec.leech_drains_meter and player != null:
		var runner: Node = player.get_node_or_null("AscensionRunner")
		if runner != null and runner.has_method("drain_discipline"):
			var drained := float(runner.call("drain_discipline", spec.leech_meter_amount))
			if drained > 0.0:
				if BattleText != null and BattleText.has_method("popup"):
					BattleText.popup(_enemy.global_position, "SIPHONED %d" % int(round(drained)), Color(0.7, 0.55, 1.0, 0.95), 0.9)
				return
	if spec.leech_amount > 0:
		Global.transaction_followers(-spec.leech_amount, &"enemy_drain", {"enemy_id": String(spec.id)}, true, true)


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

		# No drain from a dead player (the reconstruction modal pauses the
		# tree, but this loop's timer used to keep ticking through it).
		var player := _enemy.get_tree().get_first_node_in_group("player")
		var player_dead: bool = player != null and bool(player.get("is_dead"))
		if not player_dead:
			_drain_once(player)

		await _enemy.get_tree().create_timer(maxf(_enemy.spec.leech_every, 0.05), false).timeout
		if generation != _loop_generation:
			return

	if generation == _loop_generation:
		_loop_running = false
