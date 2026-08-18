extends Node

# Spawn-storm regulation: construction budget with debt carry, and a hard cap
# on concurrent elites so saturated promotion chance cannot grow the elite
# population without bound.

class EliteDummy:
	extends Node2D
	var dead := false
	var is_elite := true

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
	var spawner := EnemySpawner.new()
	spawner.spawning_enabled = false
	add_child(spawner)

	_check(spawner.has_method("_take_spawn_budget"), "spawner exposes a per-tick construction budget")
	_check(spawner.has_method("_elite_cap_reached"), "spawner exposes the concurrent elite cap")
	if not spawner.has_method("_take_spawn_budget") or not spawner.has_method("_elite_cap_reached"):
		spawner.queue_free()
		_finish()
		return

	spawner.set("max_spawn_batch_per_tick", 4)
	spawner.set("batch_cap", 8)
	_check(int(spawner.call("_take_spawn_budget", 8)) == 4, "a saturated batch is clamped to the per-tick budget")
	_check(int(spawner.call("_take_spawn_budget", 0)) == 4, "the clamped overflow carries into the next tick")
	_check(int(spawner.call("_take_spawn_budget", 0)) == 0, "carried debt drains instead of accumulating forever")
	var _drain := int(spawner.call("_take_spawn_budget", 100))
	_check(int(spawner.get("_spawn_debt")) <= 16, "spawn debt is bounded")
	spawner.set("_spawn_debt", 0)

	var index := get_node("/root/EnemyIndex")
	spawner.set("max_concurrent_elites", 2)
	_check(not bool(spawner.call("_elite_cap_reached")), "elite cap is open with no live elites")
	var elites: Array = []
	for i in range(2):
		var elite := EliteDummy.new()
		add_child(elite)
		elite.global_position = Vector2(float(i) * 50.0, 0.0)
		index.call("register", elite)
		elites.append(elite)
	_check(bool(spawner.call("_elite_cap_reached")), "elite cap closes at the configured live count")
	index.call("unregister", elites[0])
	_check(not bool(spawner.call("_elite_cap_reached")), "elite cap reopens when an elite dies")
	spawner.set("max_concurrent_elites", 0)
	_check(not bool(spawner.call("_elite_cap_reached")), "a zero cap disables the limit")

	for elite_variant in elites:
		index.call("unregister", elite_variant)
		(elite_variant as Node).queue_free()
	spawner.queue_free()
	_finish()


func _finish() -> void:
	print("SpawnerRegulationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
