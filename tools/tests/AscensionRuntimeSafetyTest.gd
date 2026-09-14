extends Node

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const ENEMY_SCENE = preload("res://scenes/world/enemies/EnemySniper.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

class ErrorCapture:
	extends Logger
	var errors := PackedStringArray()
	var mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		errors.append(rationale if not rationale.is_empty() else code)
		mutex.unlock()

	func take_errors() -> PackedStringArray:
		mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		mutex.unlock()
		return out

var _passes := 0
var _failures := 0
var _errors := ErrorCapture.new()
var _player: Node2D
var _runner: AscensionRunner
var _engine: DistortionEngine
var _collision_calls := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		print("FAIL: ", message)


func _check_errors(label: String) -> void:
	var errors := _errors.take_errors()
	_check(errors.is_empty(), "%s reports no runtime errors: %s" % [label, errors])


func _spawn_enemy(hp: float, at: Vector2) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_safety", "res://asc_safety.tscn", at, hp, 10.0, 8.0, 0, 0))


func _reset_debt(ids: Array = []) -> void:
	Global.attempt_ascension = AscensionLedger.fresh_state("magic")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("DT06", 0)
	for id in ids:
		ledger.record_purchase(String(id), 100)
	_runner.refresh()
	_engine = _runner.engine_for("DT06") as DistortionEngine
	_engine.debts.clear()
	_engine.counters["matured"] = 0


func _collision_area(at: Vector2) -> Area2D:
	var area := Area2D.new()
	area.position = at
	area.collision_layer = 1 << 19
	area.collision_mask = 1 << 19
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	area.add_child(shape)
	return area


func _on_collision(_area: Area2D) -> void:
	_collision_calls += 1
	var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "EX06", "cleave", 1, 0.5)
	_player.spawn_generated_slash(Vector2(1400, 1400), Vector2.RIGHT, 10.0, tags, 120.0, 80.0)
	_player.spawn_generated_impact(Vector2(1800, 1400), 13.0, tags, 50.0)


func _run() -> void:
	OS.add_logger(_errors)
	Global.selected_style_id = "magic"
	Global.attempt_ascension = AscensionLedger.fresh_state("magic")
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.set_process(false)

	# A real physics signal must be able to create damaging chain attacks.
	var slash_target := _spawn_enemy(100.0, Vector2(1430, 1400))
	var impact_target := _spawn_enemy(100.0, Vector2(1800, 1400))
	var trigger := _collision_area(Vector2(600, 600))
	trigger.area_entered.connect(_on_collision, CONNECT_ONE_SHOT)
	add_child(trigger)
	var contact := _collision_area(Vector2(600, 600))
	add_child(contact)
	for _i in range(6):
		await get_tree().physics_frame
	_check(_collision_calls == 1, "generated attacks were triggered by a real Area2D collision")
	_check(is_equal_approx(_runner.enemy_hp(slash_target), 90.0), "the generated slash still hits for 10 damage")
	_check(is_equal_approx(_runner.enemy_hp(impact_target), 87.0), "the generated impact still hits for 13 damage")
	_check_errors("collision-generated attacks")
	trigger.queue_free()
	contact.queue_free()
	EnemyWorld.remove_enemy(slash_target, &"test")
	EnemyWorld.remove_enemy(impact_target, &"test")

	# Encounter rollback can run before the spawner's deferred insertion.
	var population_before := EnemyIndex.alive_count()
	var cancelled := ENEMY_SCENE.instantiate()
	cancelled.set_meta("special_spawn_kind", &"beat")
	get_tree().current_scene.call_deferred("add_child", cancelled)
	cancelled.call("despawn", &"beat_aborted")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_instance_valid(cancelled), "an enemy cancelled before insertion is freed")
	_check(EnemyIndex.alive_count() == population_before, "cancelled encounter members leave no population behind")
	_check_errors("encounter rollback before insertion")

	# A synchronous kill chain can remove a later key from the tick snapshot.
	_reset_debt()
	var first := _spawn_enemy(5.0, Vector2(2000, 1000))
	var second := _spawn_enemy(5.0, Vector2(2300, 1000))
	var survivor := _spawn_enemy(100.0, Vector2(2600, 1000))
	for handle in [first, second, survivor]:
		_engine.deposit(handle, 10.0, "test", true)
	var chain := func(hit: Dictionary, _context: RefCounted) -> void:
		if int(hit["handle"]) == first:
			_runner.damage_enemy(second, 10.0, AscensionTags.native("magic", "impact"))
	_runner.kill_resolved.connect(chain)
	_engine._tick_debts(0.0)
	_runner.kill_resolved.disconnect(chain)
	_check(not _runner.enemy_alive(first) and not _runner.enemy_alive(second), "Debt can trigger a kill that removes another debtor")
	_check(is_equal_approx(_runner.enemy_hp(survivor), 90.0), "Debt processing continues after a later debtor is removed")
	_check_errors("Debt keys removed by a kill chain")
	EnemyWorld.remove_enemy(survivor, &"test")

	# Only still-unpaid buckets can pass on when a maturity kills its target.
	_reset_debt(["DT09"])
	var payer := _spawn_enemy(5.0, Vector2(3000, 1000))
	var heir := _spawn_enemy(100.0, Vector2(3050, 1000))
	_engine.deposit(payer, 10.0, "first", true)
	_engine.deposit(payer, 20.0, "second", true)
	_engine._tick_debts(0.0)
	_check(int(_engine.counters["matured"]) == 1, "a killed debtor cannot mature its remaining detached buckets")
	_check(is_equal_approx(_engine.unpaid_debt(heir), 15.0), "Back Pay transfers only 75 percent of the unpaid 20")
	_engine._tick_debts(0.0)
	_check(is_equal_approx(_runner.enemy_hp(heir), 85.0), "the heir pays the transferred Debt once")
	_check_errors("lethal Debt payment")
	EnemyWorld.remove_enemy(heir, &"test")

	# A hit callback may collect a ledger and create a replacement for the same enemy.
	_reset_debt()
	var replaced := _spawn_enemy(100.0, Vector2(3500, 1000))
	_engine.deposit(replaced, 10.0, "old", true)
	var replace := func(hit: Dictionary) -> void:
		if int(hit["handle"]) == replaced:
			_engine.collect_debt(replaced)
			_engine.deposit(replaced, 7.0, "replacement", true)
	_runner.hit_resolved.connect(replace, CONNECT_ONE_SHOT)
	_engine._tick_debts(0.0)
	_check(is_equal_approx(_engine.unpaid_debt(replaced), 7.0), "cleanup cannot erase a replacement Debt ledger")
	_engine._tick_debts(0.0)
	_check(is_equal_approx(_runner.enemy_hp(replaced), 83.0), "replacement Debt pays on the next tick")
	_check_errors("Debt replaced during a damage callback")
	EnemyWorld.remove_enemy(replaced, &"test")

	Global.attempt_ascension = {}
	_player.queue_free()
	await get_tree().process_frame
	_check_errors("test cleanup")
	OS.remove_logger(_errors)
	print("AscensionRuntimeSafetyTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
