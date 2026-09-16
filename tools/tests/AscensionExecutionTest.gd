extends Node

# Execution on a Melee native, with the review's definition: an execution is
# a normal killed by an execution-enabled hit, by damage or by the line.
# Finish turns the line into a finishing blow, Bloodletting raises it, Mark
# pays out on the next hit, Spillover sends the overkill seed to a neighbour,
# Corpse Bomb and Cleave fire from executions and kills, Gavel strikes the
# aim point after its wind-up and Public Execution shares the overkill,
# twelve deaths from one root release Red Mist, DECIMATION sweeps the screen,
# and Elite Sentence uses half the line.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionExecutionTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _engine: ExecutionEngine
var _kills: Array[Dictionary] = []


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn_enemy(hp: float, at: Vector2, flags: int = 0) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_execution", "res://asc_execution.tscn", at, hp, 10.0, 8.0, 0, flags))


func _slash_tags(volley: int) -> PackedStringArray:
	var tags := AscensionTags.native("melee", "slash")
	tags = AscensionTags.with_flag(tags, "core_strike")
	tags = AscensionTags.with_flag(tags, "execute_enabled")
	tags.append("cast:native:%d" % volley)
	return tags


func _settle() -> void:
	# Generated impacts and slashes burst one physics frame after spawning.
	for _i in range(3):
		await get_tree().physics_frame


func _run() -> void:
	Global.selected_style_id = "melee"
	Global.attempt_ascension = AscensionLedger.fresh_state("melee")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("EX01", 0)
	for id in ["EX02", "EX03", "EX04", "EX05", "EX06", "EX09", "EX10", "EXQ", "EXQ3", "EXF2", "EXC", "EXV", "EXS1", "EXS1", "EXS1", "EXS1"]:
		ledger.record_purchase(id, 100)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_runner.kill_resolved.connect(func(hit: Dictionary, _context: RefCounted) -> void: _kills.append(hit))
	_engine = _runner.engine_for("EX01") as ExecutionEngine
	_check(_engine != null and _runner.q_id == "EXQ" and _runner.v_id == "EXV", "the Execution engine loads with Gavel on Q and DECIMATION on V")
	if _engine == null:
		_finish()
		return
	var D := _runner.native_damage()
	_check(is_equal_approx(D, 15.0), "a Melee native's D is 15 (%s)" % str(D))
	_check(is_equal_approx(_runner.get_power_multiplier(), 1.02), "four ranks of Slash Damage give +2% (%s)" % str(_runner.get_power_multiplier()))
	_check(is_equal_approx(_engine.line(), 0.10), "the execute line starts at 10%")

	# --- a hit that leaves a normal in the band finishes it
	var origin := _player.global_position
	var victim := _spawn_enemy(100.0, origin + Vector2(60, 0))
	var neighbour := _spawn_enemy(100.0, origin + Vector2(150, 0))
	_runner.damage_enemy(victim, 91.0, _slash_tags(1))
	_check(not _runner.enemy_alive(victim), "a Melee Core hit leaving 9% finishes the normal")
	_check(int(_engine.counters["line_finishes"]) == 1 and int(_engine.counters["executions"]) == 1, "the finish counts as an execution")
	_check(_kills.size() == 1 and AscensionTags.has_flag(_kills[0]["tags"], "execute"), "the killing record is flagged execute")
	_check(is_equal_approx(_engine.line(), 0.12), "Bloodletting raises the line by two points")
	_check(int(_engine.counters["corpse_bombs"]) == 1 and int(_engine.counters["cleaves"]) == 1, "the execution bursts a Corpse Bomb and throws a Cleave")
	_check(int(_engine.counters["spillovers"]) == 1, "Spillover finds the neighbour within 2R")
	for _i in range(40):
		_engine.tick(1.0 / 60.0)
	var expected_bolt := 0.5 * D + 0.25 * D  # seed plus Blood's first fresh victim
	_check(int(_engine.counters["bolt_hits"]) == 1 and is_equal_approx(_runner.enemy_hp(neighbour), 100.0 - expected_bolt), "the bolt lands the 0.5D seed plus Blood's bonus (%s)" % str(_runner.enemy_hp(neighbour)))
	await _settle()

	# --- an ordinary kill is not an execution
	var whole := _spawn_enemy(10.0, origin + Vector2(-60, 0))
	var executions_before := int(_engine.counters["executions"])
	var tags_plain := AscensionTags.native("melee", "slash")
	tags_plain = AscensionTags.with_flag(tags_plain, "core_strike")
	_runner.damage_enemy(whole, 50.0, tags_plain)
	_check(int(_engine.counters["executions"]) == executions_before, "a kill by a hit that is not execution-enabled is not an execution")
	_check(int(_engine.counters["cleaves"]) == 2, "but it still cleaves, because Cleave keys on kills")
	await _settle()

	# --- Mark pays out on the next Core hit
	var marked := _spawn_enemy(100.0, origin + Vector2(0, 80))
	_runner.damage_enemy(marked, 10.0, _slash_tags(2))
	_check(_runner.has_status(marked, "mark") and int(_engine.counters["marks"]) >= 1, "a Core hit marks its victim")
	_runner.damage_enemy(marked, 10.0, _slash_tags(3))
	_check(int(_engine.counters["mark_consumed"]) == 1 and is_equal_approx(_runner.enemy_hp(marked), 100.0 - 20.0 - 0.5 * D), "the next hit consumes the Mark for +0.5D (%s)" % str(_runner.enemy_hp(marked)))
	EnemyWorld.remove_enemy(marked, &"test")

	# --- Elite Sentence
	var elite := _spawn_enemy(100.0, origin + Vector2(0, -80), EnemyWorldTypes.Flags.ELITE)
	_runner.damage_enemy(elite, 88.0, _slash_tags(4))
	_check(_runner.enemy_alive(elite), "an elite at 12% survives: half the line is 6%")
	# The second Core hit consumes the Mark for +0.5D inside the hit itself,
	# so a 0.5 raw hit lands 8 and leaves the elite at 4%.
	_runner.damage_enemy(elite, 0.5, _slash_tags(5))
	_check(not _runner.enemy_alive(elite) and int(_engine.counters["elite_sentences"]) == 1, "an elite at 4% is sentenced")
	await _settle()

	# --- Gavel with Public Execution
	var target_point := origin + Vector2(200, 0)
	_runner.aim_override = target_point
	var anvil := _spawn_enemy(300.0, target_point)
	var fodder := _spawn_enemy(5.0, target_point + Vector2(20, 0))
	var verdict := _runner.activate_q()
	_check(bool(verdict["ok"]) and is_equal_approx(float(verdict["cooldown"]), 7.0), "Gavel activates on a 7 s cooldown")
	_engine.tick(0.4)
	_check(int(_engine.counters["gavels"]) == 1, "the strike lands after the wind-up")
	await _settle()
	_check(not _runner.enemy_alive(fodder), "Gavel kills the fodder in its area")
	_check(int(_engine.counters["gavel_executions"]) == 1, "a Gavel kill of a normal is an execution")
	_check(int(_engine.counters["public_executions"]) == 1, "Public Execution shares the overkill")
	_check(_runner.enemy_hp(anvil) < 300.0 - 3.0 * D - 30.0, "the survivor takes 3D plus the shared overkill (%s)" % str(_runner.enemy_hp(anvil)))
	EnemyWorld.remove_enemy(anvil, &"test")
	await _settle()

	# --- Red Mist: twelve deaths from one root
	var cluster: Array[int] = []
	for i in range(12):
		cluster.append(_spawn_enemy(1.0, target_point + Vector2(float(i % 4) * 12.0 - 18.0, float(i / 4) * 12.0 - 12.0)))
	var witness := _spawn_enemy(200.0, origin + Vector2(-300, 100))
	_runner.q_cooldown_left = 0.0
	verdict = _runner.activate_q()
	_engine.tick(0.4)
	await _settle()
	var dead := 0
	for handle in cluster:
		if not _runner.enemy_alive(handle):
			dead += 1
	_check(dead == 12, "the second Gavel kills the cluster (%d)" % dead)
	_check(int(_engine.counters["red_mists"]) == 1, "twelve deaths from one root release Red Mist")
	_check(_runner.enemy_hp(witness) <= 200.0 - 5.0 * D, "the sweep hits a normal across the screen for 5D (%s)" % str(_runner.enemy_hp(witness)))
	await _settle()

	# --- DECIMATION
	var weak := _spawn_enemy(30.0, origin + Vector2(100, 100))
	var strong := _spawn_enemy(100.0, origin + Vector2(-100, -100))
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	verdict = _runner.activate_v()
	_check(bool(verdict["ok"]), "a full charge starts DECIMATION")
	_engine.tick(0.45)
	_check(int(_engine.counters["decimations"]) == 1 and not _runner.enemy_alive(weak), "after the tell every visible normal takes 3D")
	_check(is_equal_approx(_runner.enemy_hp(strong), 100.0 - 3.0 * D), "a healthy normal is left at 55 (%s)" % str(_runner.enemy_hp(strong)))
	_check(_kills.size() > 0 and AscensionTags.has_flag(_kills[_kills.size() - 1]["tags"], "v"), "DECIMATION kills are V-rooted")
	await _settle()

	for handle in [neighbour, witness, strong]:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")
	Global.attempt_ascension = {}
	_player.queue_free()
	_finish()


func _finish() -> void:
	print("AscensionExecutionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
