extends Node

# The 2026-09-15 audit's workload: a 180-body wounded crowd under
# Fragmentation, Pinball and Hot Rounds, where every fragment reacquires the
# lowest-health target after each death. Times the engine's fragment update
# per frame and the whole headless frame, then repeats the audit's controlled
# comparison (120 and 360 fragments, target retained vs. forced
# reacquisition). Prints numbers for the changelog and pins the bounds.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionBarrageDenseBenchmark.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const BODIES := 180

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


func _spawn(hp: float, at: Vector2) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_dense", "res://asc_dense.tscn", at, hp, 10.0, 8.0, 0, 0))


func _pct(values: Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	return float(sorted_values[clampi(int(ceil(fraction * sorted_values.size())) - 1, 0, sorted_values.size() - 1)])


func _run() -> void:
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("BR01", 0)
	for id in ["BR02", "BR04", "BR05", "BR09", "BR10"]:
		ledger.record_purchase(id, 100)
	var player: Node2D = PLAYER_SCENE.instantiate()
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var runner := player.get_node("AscensionRunner") as AscensionRunner
	runner.refresh()
	# Seeded: the chain's rolls decide how much of the crowd dies, so the
	# kill floor below is a fixed outcome rather than a coin flip.
	runner._rng = RandomNumberGenerator.new()
	runner._rng.seed = 20260916
	var engine := runner.engine_for("BR01") as BarrageEngine
	engine.heat = 60.0
	var origin := player.global_position
	var bodies: Array[int] = []
	for i in range(BODIES):
		var at := origin + Vector2(140 + float(i % 15) * 20.0, float(i / 15) * 20.0 - 110.0)
		bodies.append(_spawn(6.0, at))
	var seed_tags := AscensionTags.native("ranged", "bullet")
	seed_tags = AscensionTags.with_flag(seed_tags, "core_strike")
	seed_tags.append("volley:1")
	runner.damage_enemy(bodies[0], 100.0, seed_tags)
	var fragment_usec: Array = []
	var frame_ms: Array = []
	var peak_live := 0
	var frames := 0
	var last := Time.get_ticks_usec()
	while frames < 400:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - last) / 1000.0)
		last = now
		var cost := engine.frame_cost()
		fragment_usec.append(int(cost["fragment_usec"]))
		peak_live = maxi(peak_live, int(cost["fragments_live"]))
		frames += 1
		if frames > 30 and engine.fragments.is_empty() and runner.pending_attacks().is_empty():
			break
	var dead := 0
	for handle in bodies:
		if not runner.enemy_alive(handle):
			dead += 1
	print("dense chain: %d of %d dead in %d frames, peak live fragments %d, fragment update p50 %.2f ms p95 %.2f ms max %.2f ms, headless frame p95 %.2f ms max %.2f ms" % [dead, BODIES, frames, peak_live, _pct(fragment_usec, 0.5) / 1000.0, _pct(fragment_usec, 0.95) / 1000.0, _pct(fragment_usec, 1.0) / 1000.0, _pct(frame_ms, 0.95), _pct(frame_ms, 1.0)])
	# Frame timing still steers the fragments, so the kill count spreads
	# (127-180 of 180 observed); the floor only proves the chain happened.
	_check(dead >= BODIES * 0.6, "the chain kills most of the crowd (%d of %d)" % [dead, BODIES])
	_check(peak_live >= 100, "the crowd produced a real fragment storm (%d live at peak)" % peak_live)
	# The single worst frame is noise (8.8-16.7 ms across identical runs);
	# p99 is the stable guard. The max is still printed above.
	_check(_pct(fragment_usec, 0.99) < 15000.0, "fragment update p99 stayed under 15 ms headless (p99 %.2f ms, max %.2f ms)" % [_pct(fragment_usec, 0.99) / 1000.0, _pct(fragment_usec, 1.0) / 1000.0])
	_check(_pct(frame_ms, 0.95) < 33.0, "headless frame p95 stayed under 33 ms (%.2f ms)" % _pct(frame_ms, 0.95))
	for handle in bodies:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"bench")

	# --- controlled comparison: retained target vs. forced reacquisition
	var crowd: Array[int] = []
	for i in range(180):
		crowd.append(_spawn(1000.0, origin + Vector2(140 + float(i % 15) * 20.0, float(i / 15) * 20.0 - 110.0)))
	for count in [120, 360]:
		for forced in [false, true]:
			var samples: Array = []
			for trial in range(12):
				engine.fragments.clear()
				engine._pending_fragments.clear()
				for i in range(count):
					var target: int = crowd[i % crowd.size()]
					engine.fragments.append({"burning": false, "cast": "", "pos": origin + Vector2(100, float(i)), "vel": Vector2.RIGHT * 520.0, "target": 0 if forced else target, "damage": 1.0, "life": 2.0, "pp": 0.4, "bounces": 0, "root": "BR05", "gen": 1, "last": 0, "suppression": false})
				engine._tick_fragments(1.0 / 60.0)
				samples.append(int(engine.frame_cost()["fragment_usec"]))
			print("fragments %d %s: fragment update median %.2f ms p95 %.2f ms (retargets %d, deferred %d)" % [count, "forced reacquisition" if forced else "target retained", _pct(samples, 0.5) / 1000.0, _pct(samples, 0.95) / 1000.0, int(engine.frame_cost()["retargets"]), int(engine.frame_cost()["retargets_deferred"])])
			if forced:
				_check(_pct(samples, 0.95) < 15000.0, "%d fragments forced to reacquire stay under 15 ms per update (p95 %.2f ms)" % [count, _pct(samples, 0.95) / 1000.0])
	for handle in crowd:
		EnemyWorld.remove_enemy(handle, &"bench")
	engine.fragments.clear()
	Global.attempt_ascension = {}
	player.queue_free()
	print("AscensionBarrageDenseBenchmark: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
