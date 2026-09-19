extends Node

# Roster audit E2: the ambient roster unlocks by the Threat Director's
# segment phase and by segment-scaled start times, not by seconds alone.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/SpawnUnlockTest.tscn

const TABLE := preload("res://data/enemies/spawn/SpawnTable_Default.tres")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _entry(name_part: String) -> EnemySpawnEntry:
	for entry in TABLE.entries:
		if entry != null and entry.enemy_scene != null and entry.enemy_scene.resource_path.contains(name_part):
			return entry
	return null


func _picks(t: float, phase: StringName, scale: float, rolls: int = 400) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var seen: Dictionary = {}
	for i in rolls:
		var picked := TABLE.pick(t, rng, phase, scale)
		if picked != null:
			var key := picked.enemy_scene.resource_path.get_file()
			seen[key] = int(seen.get(key, 0)) + 1
	return seen


func _run() -> void:
	_check(is_equal_approx(EnemySpawnTable.unlock_time_scale(1), 1.0) and is_equal_approx(EnemySpawnTable.unlock_time_scale(5), 0.68) and is_equal_approx(EnemySpawnTable.unlock_time_scale(12), 0.35), "start times shrink 8% per segment to a 35% floor")
	_check(EnemySpawnTable.phase_allows(&"", &"recon") and EnemySpawnTable.phase_allows(&"disturbance", &"ascension") and not EnemySpawnTable.phase_allows(&"collapse", &"disturbance"), "an entry's phase gate reads the phase order")
	var brute := _entry("EnemyBrute")
	_check(brute != null and brute.min_phase == &"disturbance" and brute.max_alive == 6, "the Brute is on the ambient table from disturbance, six alive at most")
	_check(_entry("EnemySummoner").min_phase == &"collapse" and _entry("EnemySniper").min_phase == &"ascension" and _entry("EnemyOrbiter").min_phase == &"disturbance" and _entry("EnemyGrunt").min_phase == &"", "specialists are phase-gated: disturbance, ascension, collapse; fodder is not")
	var recon_late := _picks(600.0, &"recon", 1.0)
	_check(recon_late.size() == 2 and recon_late.has("EnemyGrunt.tscn") and recon_late.has("EnemyRunner.tscn"), "ten minutes into recon only Grunts and Runners spawn (%s)" % str(recon_late.keys()))
	var disturbance := _picks(600.0, &"disturbance", 1.0)
	_check(disturbance.has("EnemyCharger.tscn") and disturbance.has("EnemyBrute.tscn") and not disturbance.has("EnemySummoner.tscn"), "disturbance opens Orbiter, Spitter, Charger and Brute but not the collapse specialists")
	var collapse := _picks(600.0, &"collapse", 1.0)
	_check(collapse.has("EnemySummoner.tscn") and collapse.has("EnemyHerald.tscn") and collapse.has("EnemySplitter.tscn"), "collapse opens the whole roster")
	var early_seg1 := _picks(100.0, &"collapse", EnemySpawnTable.unlock_time_scale(1))
	var early_seg9 := _picks(100.0, &"collapse", EnemySpawnTable.unlock_time_scale(9))
	_check(not early_seg1.has("EnemySummoner.tscn") and early_seg9.has("EnemySummoner.tscn"), "at 100 s the Summoner (180 s) is out at segment 1 and in at segment 9 (scale 0.36)")
	var grunt := _entry("EnemyGrunt")
	_check(is_equal_approx(grunt.weight, 4.5) and is_equal_approx(grunt.elite_chance, 0.01) and is_equal_approx(_entry("EnemyHerald").elite_chance, 0.07), "weights and elite chances carry the roster audit's numbers")
	print("SpawnUnlockTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
