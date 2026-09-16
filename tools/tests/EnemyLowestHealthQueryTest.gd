extends Node

# EnemyWorld.lowest_health_in_radius reads the slot arrays directly. It must
# agree with the array-building path it replaces: least health wins, ties go
# to the lowest slot, dying and excluded records are skipped, the radius is
# inclusive, and a reused slot with a new generation is a different enemy.
#
# Run: <godot> --headless --path . res://tools/tests/EnemyLowestHealthQueryTest.tscn

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
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


func _spawn(world: Node, hp: float, at: Vector2) -> int:
	return world.create_enemy(SpawnState.new(&"q", "res://q.tscn", at, hp, 10.0, 8.0, 0, 0))


func _reference(world: Node, origin: Vector2, radius: float, excluded: int) -> int:
	# The old path: gather handles, then compare health one by one.
	var out: Array[int] = []
	world.gather_in_radius(origin, radius, out, excluded)
	var best := 0
	var best_hp := INF
	for handle in out:
		if world.is_dying(handle):
			continue
		var hp: float = world.get_health(handle)
		if hp > 0.0 and hp < best_hp:
			best_hp = hp
			best = handle
	return best


func _run() -> void:
	var world := WorldScript.new()
	add_child(world)
	var a := _spawn(world, 30.0, Vector2(10, 0))
	var b := _spawn(world, 12.0, Vector2(40, 0))
	var c := _spawn(world, 12.0, Vector2(-40, 0))
	var far := _spawn(world, 1.0, Vector2(500, 0))
	_check(world.lowest_health_in_radius(Vector2.ZERO, 100.0) == b, "least health wins; ties go to the lowest slot")
	_check(world.lowest_health_in_radius(Vector2.ZERO, 100.0, b) == c, "an excluded handle yields the next candidate")
	_check(world.lowest_health_in_radius(Vector2.ZERO, 600.0) == far, "the radius is inclusive of far cells")
	_check(world.lowest_health_in_radius(Vector2.ZERO, 5.0) == 0, "nothing in range returns INVALID_HANDLE")
	world.set_health(b, 0.0)
	world.try_begin_death(b)
	_check(world.is_dying(b) and world.lowest_health_in_radius(Vector2.ZERO, 100.0) == c, "a dying record is skipped")
	world.set_health(c, 0.0)
	_check(world.lowest_health_in_radius(Vector2.ZERO, 100.0) == a, "zero health is skipped")
	world.remove_enemy(b, &"test")
	var reused := _spawn(world, 5.0, Vector2(40, 0))
	_check(Types.slot_from_handle(reused) == Types.slot_from_handle(b) and reused != b, "the freed slot is reused with a new generation")
	_check(world.lowest_health_in_radius(Vector2.ZERO, 100.0) == reused, "the reused slot's new enemy is found under its new handle")
	_check(world.lowest_health_in_radius(Vector2.ZERO, 100.0, reused) == a, "excluding the new handle works")
	# Randomised agreement with the reference path.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var handles: Array[int] = []
	for i in range(150):
		handles.append(_spawn(world, rng.randf_range(1.0, 100.0), Vector2(rng.randf_range(-400, 400), rng.randf_range(-400, 400))))
	var agree := 0
	for i in range(60):
		var origin := Vector2(rng.randf_range(-400, 400), rng.randf_range(-400, 400))
		var radius := rng.randf_range(20.0, 300.0)
		var excluded: int = handles[rng.randi_range(0, handles.size() - 1)]
		var fast := world.lowest_health_in_radius(origin, radius, excluded)
		var slow := _reference(world, origin, radius, excluded)
		if fast == slow or (fast != 0 and slow != 0 and is_equal_approx(world.get_health(fast), world.get_health(slow))):
			agree += 1
	_check(agree == 60, "the direct query agrees with the gather-then-compare path on 60 random queries (%d)" % agree)
	world.queue_free()
	print("EnemyLowestHealthQueryTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
