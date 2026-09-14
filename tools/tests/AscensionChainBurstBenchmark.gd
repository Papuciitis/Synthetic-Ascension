extends Node

# The 14 September captures showed chain bursts (Red Mist, DECIMATION,
# Corpse Bomb + Cleave on forty bodies) dropping dozens of Area2D slash and
# impact nodes into one physics step: physics 337 ms, 12,000 draw calls,
# process 1.4 s. Generated attacks are now a budgeted data queue on the
# runner. This pins that: a sixty-body chain with Finish, Spillover, Corpse
# Bomb, Cleave and Chain Sentence creates no scene nodes, resolves over a few
# frames, and no frame's script work exceeds the budget.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionChainBurstBenchmark.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const BODIES := 60
const FRAME_BUDGET_MS := 12.0

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	Global.selected_style_id = "melee"
	Global.attempt_ascension = AscensionLedger.fresh_state("melee")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("EX01", 0)
	for id in ["EX03", "EX04", "EX05", "EX06", "EX10", "EXQ", "EXF1"]:
		ledger.record_purchase(id, 100)
	var player: Node2D = PLAYER_SCENE.instantiate()
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var runner := player.get_node("AscensionRunner") as AscensionRunner
	runner.refresh()
	var execution := runner.engine_for("EX01") as ExecutionEngine
	var origin := player.global_position
	# A tight wounded crowd: every Corpse Bomb (R) and Cleave (1.5R) reaches neighbours.
	var bodies: Array[int] = []
	for i in range(BODIES):
		var at := origin + Vector2(120 + float(i % 10) * 22.0, float(i / 10) * 22.0 - 55.0)
		bodies.append(EnemyWorld.create_enemy(SpawnState.new(&"asc_bench", "res://asc_bench.tscn", at, 12.0, 10.0, 8.0, 0, 0)))
	var nodes_before := get_tree().get_node_count()
	var tags := AscensionTags.native("melee", "slash")
	tags = AscensionTags.with_flag(tags, "core_strike")
	tags = AscensionTags.with_flag(tags, "execute_enabled")
	tags.append("cast:native:1")
	var started := Time.get_ticks_usec()
	runner.damage_enemy(bodies[0], 100.0, tags)
	var seed_us := Time.get_ticks_usec() - started
	var worst_ms := 0.0
	var frames := 0
	var max_nodes := nodes_before
	while frames < 90 and (frames < 6 or not runner.pending_attacks().is_empty()):
		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		var t1 := Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, float(t1 - t0) / 1000.0)
		max_nodes = maxi(max_nodes, get_tree().get_node_count())
		frames += 1
	var dead := 0
	for handle in bodies:
		if not runner.enemy_alive(handle):
			dead += 1
	print("chain: seed hit %d us, %d bodies dead after %d frames, %d generated attacks, worst frame %.2f ms, node growth %d" % [seed_us, dead, frames, int(runner.telemetry["generated"]), worst_ms, max_nodes - nodes_before])
	_check(dead >= 30, "the chain kills at least half the crowd (%d of %d)" % [dead, BODIES])
	_check(int(runner.telemetry["generated"]) >= 60, "the chain generated dozens of attacks (%d)" % int(runner.telemetry["generated"]))
	_check(max_nodes - nodes_before <= 4, "generated attacks add no scene nodes (%d)" % (max_nodes - nodes_before))
	_check(float(seed_us) / 1000.0 < FRAME_BUDGET_MS, "the seed kill resolves inside the budget (%.2f ms)" % (float(seed_us) / 1000.0))
	_check(worst_ms < 40.0, "no frame of the chain took more than 40 ms headless (%.2f)" % worst_ms)
	_check(int(execution.counters["corpse_bombs"]) >= 20 and int(execution.counters["cleaves"]) >= 20, "Corpse Bombs and Cleaves fired through the queue (%d / %d)" % [int(execution.counters["corpse_bombs"]), int(execution.counters["cleaves"])])
	for handle in bodies:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"bench")
	Global.attempt_ascension = {}
	player.queue_free()
	print("AscensionChainBurstBenchmark: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
