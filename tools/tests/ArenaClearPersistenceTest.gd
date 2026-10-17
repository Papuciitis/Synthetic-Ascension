extends Node

# A defeated boss stays defeated on Continue (boss overhaul, "Arena and
# encounter presentation"): an arena records its clear with its payout, the
# attempt's save carries it, and a rebuilt segment restores the earned gate
# state instead of fighting, or paying, again. A live fight still starts.
const BOSS_ARENA := preload("res://scenes/world/events/BossArena.tscn")
const MINIBOSS_ARENA := preload("res://scenes/world/events/MiniBossArena.tscn")
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
var _passes := 0
var _failures := 0
var _world: Node2D
var _builder: FakeBuilder
var _player: Node2D
var _victories: Array[int] = []

## The arenas only talk to the builder through these calls.
class FakeBuilder:
	extends SegmentProcBuilder
	var boss_defeated := 0
	var miniboss_defeated := 0
	var granted: Array[float] = []
	func _ready() -> void:
		add_to_group(&"segment_proc_builder")
	func set_boss_defeated() -> void:
		boss_defeated += 1
	func set_miniboss_defeated() -> void:
		miniboss_defeated += 1
	func grant_resonance(amount: float, _immediate: bool = true) -> void:
		granted.append(amount)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _fixture() -> void:
	_world = Node2D.new()
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	_builder = FakeBuilder.new()
	_world.add_child(_builder)
	_player = Node2D.new()
	_player.add_to_group(&"player")
	_world.add_child(_player)


func _clear() -> void:
	get_tree().current_scene = self
	_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _frames(count: int = 3) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _on_followers(_old_value: int, change: int, _new_value: int, reason: StringName, _context: Dictionary, _feedback: bool, _aggregate: bool) -> void:
	if reason == &"boss_victory" or reason == &"miniboss_victory":
		_victories.append(change)


func _bosses() -> Array:
	return get_tree().get_nodes_in_group(&"boss").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())


func _test_record() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 10
	_check(not Global.is_arena_cleared(&"boss") and not Global.is_arena_cleared(&"miniboss"), "a new attempt has settled no arena")
	Global.note_arena_cleared(&"boss")
	Global.note_arena_cleared(&"boss")
	_check(Global.is_arena_cleared(&"boss") and Global.attempt_cleared_arenas.size() == 1, "a clear is recorded once, for its segment and kind")
	_check(not Global.is_arena_cleared(&"miniboss"), "the same segment's other arena is untouched")
	Global.attempt_segment = 7
	_check(not Global.is_arena_cleared(&"boss"), "another segment's arenas are untouched")
	Global.attempt_segment = 10
	var save := SaveData.new()
	Global.write_save(save)
	_check(save.attempt_cleared_arenas == PackedStringArray(["10:boss"]), "the attempt's save carries the clear")
	Global.start_new_attempt()
	_check(Global.attempt_cleared_arenas.is_empty(), "a new attempt forgets every clear")
	Global.apply_save(save)
	_check(Global.attempt_segment == 10 and Global.is_arena_cleared(&"boss"), "Continue restores the clear from the save")
	var older := SaveData.new()
	Global.write_save(older)
	older.attempt_cleared_arenas = PackedStringArray()
	Global.apply_save(older)
	_check(Global.attempt_cleared_arenas.is_empty(), "a save from before the record loads with nothing settled")
	# The developer console's segment jump (the attempt state it leaves before
	# the Game loads) replays the attempt from that segment: its arenas and
	# every later segment's rise again, earlier ones stay settled.
	_check(SaveManager.current_save == null, "fixture: no profile is open for the jump to save")
	Global.attempt_segment = 3
	Global.note_arena_cleared(&"miniboss")
	Global.attempt_segment = 5
	Global.note_arena_cleared(&"miniboss")
	Global.attempt_segment = 10
	Global.note_arena_cleared(&"boss")
	Global.note_arena_cleared(&"miniboss")
	DevSetCollisionTools.prepare_segment_jump(10)
	_check(Global.attempt_segment == 10 and Global.attempt_cleared_arenas == PackedStringArray(["3:miniboss", "5:miniboss"]), "a developer jump to Segment 10 forgets that segment's clears and keeps the earlier ones")
	Global.note_arena_cleared(&"boss")
	DevSetCollisionTools.prepare_segment_jump(5)
	_check(Global.attempt_segment == 5 and Global.attempt_cleared_arenas == PackedStringArray(["3:miniboss"]), "a jump back to Segment 5 forgets the clears from there on, so Segment 10's boss rises again too")


func _test_cleared_arenas_restore() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 10
	Global.note_arena_cleared(&"boss")
	var followers := Global.followers
	_fixture()
	var arena := BOSS_ARENA.instantiate() as BossArena
	var fills := arena.fill_resonance_on_clear
	_world.add_child(arena)
	_player.global_position = arena.global_position
	await _frames()
	_check(_builder.boss_defeated == 1 and _builder.granted == ([1.0] if fills else []), "a cleared S10 arena restores its defeat and its full Resonance")
	_check(not is_instance_valid(arena) or arena.is_queued_for_deletion(), "and leaves, as it does after the fight")
	_check(_bosses().is_empty() and Global.followers == followers, "with the player in its court, no second boss and no second payout")
	await _clear()

	Global.attempt_segment = 5
	Global.note_arena_cleared(&"miniboss")
	followers = Global.followers
	_fixture()
	var mini := MINIBOSS_ARENA.instantiate() as MiniBossArena
	var bump := mini.grant_resonance_on_clear
	_world.add_child(mini)
	_player.global_position = mini.global_position
	await _frames()
	_check(_builder.miniboss_defeated == 1 and _builder.granted == [bump], "a cleared S5 arena restores its defeat and its Resonance bump")
	_check(not is_instance_valid(mini) or mini.is_queued_for_deletion(), "and leaves")
	_check(get_tree().get_nodes_in_group(&"miniboss").is_empty() and Global.followers == followers, "no second miniboss and no second payout")
	await _clear()


func _test_live_fight_records_its_clear() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 10
	_fixture()
	var arena := BOSS_ARENA.instantiate() as BossArena
	arena.tank_boss_scenes.clear()
	arena.mage_boss_scenes.clear()
	arena.tank_boss_scenes.append(TANK)
	var bonus := arena.bonus_followers_on_clear
	_world.add_child(arena)
	_check(is_instance_valid(arena) and not arena.is_queued_for_deletion(), "an uncleared arena stays to fight")
	arena.call("_spawn")
	var boss := arena.get("_boss") as EnemyActor
	_check(boss != null and _bosses().size() == 1, "and raises its boss")
	if boss == null:
		await _clear()
		return
	boss.set_process(false)
	boss.set_physics_process(false)
	boss.get_node("BossBrain").set_physics_process(false)
	_victories.clear()
	var handle := EnemyWorld.handle_for_actor(boss)
	EnemyWorld.set_health(handle, 1.0)
	EnemyCombat.apply_damage(handle, 50.0, 1, _player)
	await _frames()
	_check(Global.is_arena_cleared(&"boss"), "the real kill records the clear")
	_check(_victories == [bonus] and _builder.boss_defeated == 1, "and pays the boss reward once")
	var paid := Global.followers
	var save := SaveData.new()
	Global.write_save(save)
	await _clear()

	# Continue: a fresh process loads the save and the builder raises the
	# segment's arenas again.
	Global.start_new_attempt()
	Global.apply_save(save)
	_victories.clear()
	_fixture()
	var rebuilt := BOSS_ARENA.instantiate() as BossArena
	_world.add_child(rebuilt)
	_player.global_position = rebuilt.global_position
	await _frames()
	_check(_builder.boss_defeated == 1 and _bosses().is_empty(), "after Continue the court restores the defeat and raises no boss")
	_check(_victories.is_empty() and Global.followers == paid, "and the reward is not paid again")
	await _clear()


func _run() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/arena_clear_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	Global.followers_transaction.connect(_on_followers)
	await _test_record()
	await _test_cleared_arenas_restore()
	await _test_live_fight_records_its_clear()
	Global.start_new_attempt()
	print("ArenaClearPersistenceTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
