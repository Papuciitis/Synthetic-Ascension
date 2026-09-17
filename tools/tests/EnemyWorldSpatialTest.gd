extends Node

const SpatialGrid = preload("res://core/systems/enemy_world/EnemySpatialGrid.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")

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


func _occurrences(values: Array[int], target: int) -> int:
	var count := 0
	for value in values:
		if value == target:
			count += 1
	return count


func _run() -> void:
	_test_raw_grid()
	_test_world_queries()
	print("EnemyWorldSpatialTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_raw_grid() -> void:
	var grid := SpatialGrid.new(64.0)
	grid.insert(3, Vector2(10.0, 10.0))
	grid.insert(8, Vector2(70.0, 10.0))
	grid.insert(13, Vector2(4000.0, 0.0))

	var candidates: Array[int] = []
	grid.gather_candidate_slots(Vector2.ZERO, 100.0, candidates)
	_check(candidates.has(3) and candidates.has(8), "nearby cells are gathered")
	_check(not candidates.has(13), "distant cells are excluded")

	grid.move(8, Vector2(4100.0, 0.0))
	grid.gather_candidate_slots(Vector2.ZERO, 100.0, candidates)
	_check(candidates.size() == 1 and candidates[0] == 3, "moving a slot removes its old bucket entry")

	grid.remove(3)
	_check(not grid.has_slot(3), "removed slot leaves the grid")
	grid.remove(3)
	_check(not grid.has_slot(3), "repeated removal is idempotent")

	grid.gather_candidate_slots(Vector2.ZERO, 50000.0, candidates)
	_check(candidates.has(8) and candidates.has(13), "huge radius scans occupied buckets")

	grid.insert(20, Vector2(130.0, 10.0))
	grid.insert(21, Vector2(131.0, 11.0))
	grid.insert(22, Vector2(132.0, 12.0))
	grid.remove(21)
	grid.gather_candidate_slots(Vector2(131.0, 11.0), 20.0, candidates)
	_check(_occurrences(candidates, 20) == 1, "swap removal preserves the earlier cell member")
	_check(_occurrences(candidates, 22) == 1, "swap removal preserves the moved cell member")
	_check(not candidates.has(21), "swap removal removes only the requested slot")
	_check(grid.max_cell_occupancy() == 2, "cell occupancy reflects swap removal")
	_check(grid.active_cell_count() == 3, "active cell count ignores emptied buckets")

	grid.clear()
	_check(grid.active_cell_count() == 0, "clear removes every occupied cell")
	_check(not grid.has_slot(8) and not grid.has_slot(13), "clear removes slot membership")


func _test_world_queries() -> void:
	var world := WorldScript.new()
	add_child(world)
	var first: int = world.create_enemy(
		SpawnState.new(&"first", "res://first.tscn", Vector2(10.0, 0.0), 10.0, 10.0, 8.0, 0),
	)
	var second: int = world.create_enemy(
		SpawnState.new(&"second", "res://second.tscn", Vector2(70.0, 0.0), 10.0, 10.0, 8.0, 0),
	)
	var distant: int = world.create_enemy(
		SpawnState.new(&"distant", "res://distant.tscn", Vector2(1000.0, 0.0), 10.0, 10.0, 8.0, 0),
	)

	var found: Array[int] = []
	world.gather_in_radius(Vector2.ZERO, 50.0, found)
	_check(found.size() == 1 and found[0] == first, "world radius query filters grid candidates exactly")
	_check(world.nearest_enemy(Vector2.ZERO, 100.0) == first, "world nearest query returns the closest handle")
	_check(world.nearest_enemy(Vector2.ZERO, 100.0, first) == second, "world nearest query honors exclusion")

	world.set_position(second, Vector2(20.0, 0.0))
	_check(world.nearest_enemy(Vector2.ZERO, 100.0, first) == second, "world query follows moved records")
	world.set_position(first, Vector2(2000.0, 0.0))
	world.gather_in_radius(Vector2.ZERO, 100.0, found)
	_check(found.size() == 1 and found[0] == second, "old cells do not retain moved world records")

	world.remove_enemy(second, &"query_test")
	_check(world.nearest_enemy(Vector2.ZERO, 100.0) == 0, "removed record disappears from spatial queries")
	world.gather_in_radius(Vector2.ZERO, 50000.0, found)
	_check(found.has(first) and found.has(distant), "huge world query returns all in-range live handles")
	_check(not found.has(second), "huge world query excludes stale handles")
	world.clear_world()
	world.queue_free()
