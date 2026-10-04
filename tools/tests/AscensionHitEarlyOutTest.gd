extends Node

## AscensionRunner counts a survived hit and returns early when nothing reads
## its record (no engine, no hit_resolved listener, no history, no Second
## Skin; FPS audit 2026-10-04). Run the same hits with and without a
## hit_resolved listener (the listener forces the full path): the telemetry
## and the lethal records that travel with each kill must be identical.

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

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


func _script(runner: AscensionRunner, player: Node2D) -> Dictionary:
	var kills: Array = []
	var on_kill := func(hit: Dictionary, _context: RefCounted) -> void:
		var record := hit.duplicate()
		record.erase("handle")
		record.erase("position")
		kills.append(record)
	runner.kill_resolved.connect(on_kill)
	var telemetry_before: Dictionary = runner.telemetry.duplicate()
	var tree_tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "EXQ", "slash", 1, 0.5)
	var odd_tags := AscensionTags.native("ranged", "bullet")
	odd_tags.append("family:tree")
	var tag_sets: Array[PackedStringArray] = [tree_tags, AscensionTags.native("melee", "slash"), odd_tags, PackedStringArray()]
	for round_index in range(6):
		var handle := EnemyWorld.create_enemy(SpawnState.new(&"asc_early", "res://asc_early.tscn", player.global_position + Vector2(200 + round_index * 10, 0), 40.0, 0.0, 8.0, 0, 0))
		for step in range(5):
			var tags := tag_sets[(round_index + step) % tag_sets.size()]
			if step == 3:
				EnemyCombat.apply_status_damage(handle, 3.0, player)
			else:
				runner.damage_enemy(handle, 9.0, tags)
		if EnemyWorld.is_valid_handle(handle):
			runner.damage_enemy(handle, 100.0, tree_tags)
	runner.kill_resolved.disconnect(on_kill)
	var delta := {}
	for key in ["hits", "tree_hits", "kills", "tree_kills", "seed_kills", "chain_kills"]:
		delta[key] = int(runner.telemetry.get(key, 0)) - int(telemetry_before.get(key, 0))
	return {"telemetry": delta, "kills": kills}


func _run() -> void:
	Global.selected_style_id = "melee"
	Global.attempt_ascension = AscensionLedger.fresh_state("melee")
	var player: Node2D = PLAYER_SCENE.instantiate()
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var runner := player.get_node_or_null("AscensionRunner") as AscensionRunner
	_check(runner != null, "the player carries an AscensionRunner")
	if runner == null:
		_finish()
		return
	runner.refresh()
	_check(runner.engines.is_empty() and not runner.hit_resolved.has_connections(), "no engine and no listener: hits take the early return")
	var early := _script(runner, player)
	var listener := func(_hit: Dictionary) -> void: pass
	runner.hit_resolved.connect(listener)
	var full := _script(runner, player)
	runner.hit_resolved.disconnect(listener)
	_check(int(early["telemetry"]["hits"]) > 20, "the script landed hits (%s)" % str(early["telemetry"]))
	_check(early["telemetry"] == full["telemetry"], "telemetry is identical on both paths (%s vs %s)" % [str(early["telemetry"]), str(full["telemetry"])])
	_check((early["kills"] as Array).size() == 6 and early["kills"] == full["kills"], "every kill carries the same lethal record on both paths")
	var started := Time.get_ticks_usec()
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"asc_early", "res://asc_early.tscn", player.global_position + Vector2(300, 0), 1.0e9, 0.0, 8.0, 0, 0))
	var tags := AscensionTags.native("ranged", "bullet")
	var ledger := HitLedger.new()
	ledger.tags = tags
	started = Time.get_ticks_usec()
	for _i in range(2000):
		runner.call("_on_enemy_damaged", handle, 1.0, 1.0, 1.0e9, player, ledger)
	var early_usec := float(Time.get_ticks_usec() - started) / 2000.0
	runner.hit_resolved.connect(listener)
	started = Time.get_ticks_usec()
	for _i in range(2000):
		runner.call("_on_enemy_damaged", handle, 1.0, 1.0, 1.0e9, player, ledger)
	var full_usec := float(Time.get_ticks_usec() - started) / 2000.0
	runner.hit_resolved.disconnect(listener)
	print("AscensionHitEarlyOutTest: survived hit %.2f us (early return) vs %.2f us (full record)" % [early_usec, full_usec])
	_check(early_usec < full_usec, "the early return is cheaper")
	EnemyWorld.remove_enemy(handle, &"test")
	_finish()


func _finish() -> void:
	print("AscensionHitEarlyOutTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
