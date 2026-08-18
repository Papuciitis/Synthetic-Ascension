extends Node

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")

const RECORD_COUNT := 600
const STEP_COUNT := 600
const REPLACEMENTS_PER_CYCLE := 20

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


func _make_state(index: int, generation_wave: int = 0) -> EnemySpawnState:
	var column := index % 30
	var row := floori(float(index) / 30.0)
	var state := SpawnState.new(
		&"benchmark",
		"res://benchmark.tscn",
		Vector2(float(column) * 48.0, float(row) * 48.0),
		50.0,
		120.0,
		16.0,
		0,
	)
	var x_direction := -1.0 if (index + generation_wave) % 2 == 0 else 1.0
	var y_direction := -1.0 if (index + generation_wave) % 3 == 0 else 1.0
	state.velocity = Vector2(x_direction * float(10 + index % 7), y_direction * float(5 + index % 5))
	return state


func _run() -> void:
	var world := WorldScript.new()
	add_child(world)
	var handles: Array[int] = []
	for i in range(RECORD_COUNT):
		handles.append(world.create_enemy(_make_state(i)))

	var stale_handles: Array[int] = []
	var gathered: Array[int] = []
	var started_usec := Time.get_ticks_usec()
	for step in range(STEP_COUNT):
		for handle in handles:
			var position: Vector2 = world.get_position(handle)
			var velocity: Vector2 = world.get_velocity(handle)
			world.set_position(handle, position + velocity * 0.1)
		world.gather_in_radius(Vector2.ZERO, 900.0, gathered)
		if (step + 1) % 60 == 0:
			var wave := floori(float(step + 1) / 60.0)
			for replacement_index in range(REPLACEMENTS_PER_CYCLE):
				var stale: int = handles[replacement_index]
				stale_handles.append(stale)
				world.remove_enemy(stale, &"benchmark_reuse")
				handles[replacement_index] = world.create_enemy(
					_make_state(replacement_index, wave),
				)
	var elapsed_usec := Time.get_ticks_usec() - started_usec

	_check(world.active_count() == RECORD_COUNT, "benchmark retains 600 active records")
	var active: Array[int] = []
	world.active_handles(active)
	var unique := {}
	var all_active_valid := true
	var all_positions_finite := true
	for handle in active:
		unique[handle] = true
		all_active_valid = all_active_valid and world.is_valid_handle(handle)
		var position: Vector2 = world.get_position(handle)
		all_positions_finite = all_positions_finite and is_finite(position.x) and is_finite(position.y)
	_check(active.size() == RECORD_COUNT and unique.size() == RECORD_COUNT, "active iteration returns 600 unique handles")
	_check(all_active_valid, "every active benchmark handle validates")
	_check(all_positions_finite, "every benchmark position remains finite")

	var all_stale_invalid := true
	for stale in stale_handles:
		all_stale_invalid = all_stale_invalid and not world.is_valid_handle(stale)
		all_stale_invalid = all_stale_invalid and not world.set_health(stale, 1.0)
	_check(stale_handles.size() == 200 and all_stale_invalid, "all 200 recycled handles remain stale")

	var counters: Dictionary = world.get_debug_counters()
	_check(int(counters.get("logical", -1)) == RECORD_COUNT, "debug counters report 600 logical records")
	_check(
		int(counters.get("materialized", -1)) + int(counters.get("data_only", -1)) == RECORD_COUNT,
		"representation counters account for every record",
	)
	_check(int(counters.get("capacity", 9999)) <= 620, "slot reuse keeps storage capacity bounded")
	_check(int(counters.get("spatial_cells", 0)) > 0, "benchmark retains a populated spatial grid")

	print(
		"EnemyWorldBenchmark: records=%d steps=%d elapsed_ms=%.3f stale=%d" % [
			RECORD_COUNT,
			STEP_COUNT,
			float(elapsed_usec) / 1000.0,
			stale_handles.size(),
		],
	)
	world.clear_world()
	world.queue_free()
	print("EnemyWorldBenchmark passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
