extends "res://tools/tests/S10MainBossEscapeTest.gd"
## Continue after an S10 boss kill, in the actual Game: the real kill pays
## once and records the clear, the attempt's save carries it, and the segment
## rebuilt from that save keeps its boss defeated and its Resonance earned,
## raises no second boss in the court and pays nothing twice.
## <godot> --headless --path . res://tools/tests/S10BossContinueTest.tscn

var _victories: Array[int] = []


func _execute() -> void:
	_immortal = false
	_ambient = false
	Global.followers_transaction.connect(_on_followers)
	await _continue_case("tank", 16102026)
	await _continue_case("mage", 16102027)
	Global.followers_transaction.disconnect(_on_followers)
	_execution_completed = _failures == 0


func _on_followers(_old_value: int, change: int, _new_value: int, reason: StringName, _context: Dictionary, _feedback: bool, _aggregate: bool) -> void:
	if reason == &"boss_victory":
		_victories.append(change)


func _continue_case(role_value: String, seed_value: int) -> void:
	if not await _setup_world(role_value, seed_value):
		return
	if not await _spawn_boss():
		return
	var builder := get_tree().get_first_node_in_group(&"segment_proc_builder") as SegmentProcBuilder
	_victories.clear()
	var handle := EnemyWorld.handle_for_actor(_boss)
	EnemyWorld.set_health(handle, 1.0)
	EnemyCombat.apply_damage(handle, 50.0, 1, _player)
	await _frames(4)
	_check(Global.is_arena_cleared(&"boss"), "%s seed%d: the real kill records the S10 clear" % [role_value, seed_value])
	_check(_victories.size() == 1 and builder != null and builder.is_boss_defeated(), "%s: the kill pays the boss reward once and opens the boss gate condition" % role_value)
	var save := SaveData.new()
	Global.write_save(save)
	var paid := Global.followers
	await _shutdown_world()

	# Continue: a fresh process loads the attempt from its save and the Game
	# rebuilds the same seeded S10 district.
	Global.start_new_attempt()
	Global.apply_save(save)
	_victories.clear()
	_check(Global.attempt_segment == Global.FINAL_SEGMENT and Global.is_arena_cleared(&"boss") and Global.followers == paid, "%s: the save restores the segment, the clear and the paid wallet" % role_value)
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	for frame in range(360):
		await get_tree().process_frame
		if frame >= 12 and _chunks.debug_chunk_queue().is_empty() and _chunks.pending_blocker_stage_count() == 0:
			break
	_dismiss_tutorials()
	var rebuilt := get_tree().get_first_node_in_group(&"segment_proc_builder") as SegmentProcBuilder
	_check(rebuilt != null and rebuilt.is_boss_defeated(), "%s: the rebuilt segment keeps its boss defeated" % role_value)
	_check(rebuilt != null and float(rebuilt.get("resonance")) >= 0.999, "%s: and its Resonance earned" % role_value)
	# find_children's type filter only knows engine classes: test the script class.
	var arenas := _game.find_children("*", "", true, false).filter(func(node: Node) -> bool: return node is BossArena and not node.is_queued_for_deletion())
	_check(arenas.is_empty(), "%s: the cleared court leaves instead of waiting to fight" % role_value)
	# Stand in the court, where the trigger and its proximity backup look.
	_player.global_position = _origin
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	for _step in range(45):
		await get_tree().physics_frame
	var bosses := get_tree().get_nodes_in_group(&"boss").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
	_check(bosses.is_empty(), "%s: no second boss rises in the court" % role_value)
	_check(_victories.is_empty(), "%s: nothing is paid twice" % role_value)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
