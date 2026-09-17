extends Node

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


func _run() -> void:
	_test_handle_and_spawn_contracts()
	_test_world_storage_contracts()
	print("EnemyWorldStorageTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_handle_and_spawn_contracts() -> void:
	var handle: int = Types.make_handle(17, 9)
	_check(handle != Types.INVALID_HANDLE, "constructed handle is valid")
	_check(Types.slot_from_handle(handle) == 17, "handle preserves slot")
	_check(Types.generation_from_handle(handle) == 9, "handle preserves generation")
	_check(Types.slot_from_handle(Types.INVALID_HANDLE) == -1, "zero handle has no slot")

	var state := SpawnState.new(
		&"grunt",
		"res://scenes/world/enemies/EnemyGrunt.tscn",
		Vector2(12.0, 34.0),
		50.0,
		150.0,
		24.0,
		0,
	)
	_check(state.spec_id == &"grunt", "spawn state preserves spec id")
	_check(state.position == Vector2(12.0, 34.0), "spawn state preserves position")
	_check(
		state.health == 50.0 and state.max_health == 50.0,
		"spawn state starts at max health",
	)


func _test_world_storage_contracts() -> void:
	var world := WorldScript.new()
	add_child(world)

	var first_state := SpawnState.new(
		&"grunt",
		"res://scenes/world/enemies/EnemyGrunt.tscn",
		Vector2(10.0, 20.0),
		50.0,
		150.0,
		24.0,
		0,
		Types.Flags.ELITE,
		{"phase": 2, "nested": {"cooldown": 1.5}},
	)
	first_state.velocity = Vector2(3.0, 4.0)
	var first: int = world.create_enemy(first_state)
	var second: int = world.create_enemy(
		SpawnState.new(&"runner", "res://runner.tscn", Vector2(80.0, 0.0), 30.0, 220.0, 18.0, 1),
	)
	var third: int = world.create_enemy(
		SpawnState.new(&"brute", "res://brute.tscn", Vector2(200.0, 0.0), 120.0, 80.0, 30.0, 2),
	)

	_check(first != 0 and second != 0 and third != 0, "world creates valid handles")
	_check(first != second and second != third and first != third, "live handles are unique")
	_check(world.active_count() == 3, "world counts active records")
	_check(world.get_spec_id(first) == &"grunt", "world preserves spec id")
	_check(world.get_scene_path(first).ends_with("EnemyGrunt.tscn"), "world preserves scene path")
	_check(world.get_position(first) == Vector2(10.0, 20.0), "world preserves position")
	_check(world.get_previous_position(first) == Vector2(10.0, 20.0), "new record initializes previous position")
	_check(world.get_velocity(first) == Vector2(3.0, 4.0), "world preserves velocity")
	_check(world.get_health(first) == 50.0 and world.get_max_health(first) == 50.0, "world preserves health")
	_check(world.get_speed(first) == 150.0, "world preserves speed")
	_check(world.get_collision_radius(first) == 24.0, "world preserves collision radius")
	_check(world.get_ai_kind(first) == 0, "world preserves AI kind")
	_check(Types.has_flag(world.get_flags(first), Types.Flags.ELITE), "world preserves flags")
	_check(world.get_representation(first) == Types.Representation.DATA_ONLY, "records begin data-only")

	_check(world.set_position(first, Vector2(30.0, 40.0)), "valid handle can move")
	_check(world.get_previous_position(first) == Vector2(10.0, 20.0), "movement preserves previous position")
	_check(world.get_position(first) == Vector2(30.0, 40.0), "movement stores current position")
	_check(world.set_velocity(first, Vector2(-2.0, 5.0)), "valid handle can change velocity")
	_check(world.get_velocity(first) == Vector2(-2.0, 5.0), "velocity mutation is stored")
	_check(world.set_health(first, 999.0) and world.get_health(first) == 50.0, "health clamps to maximum")
	_check(world.set_health(first, -10.0) and world.get_health(first) == 0.0, "health clamps to zero")
	_check(world.set_max_health(first, 80.0), "maximum health can be reconfigured")
	_check(world.get_max_health(first) == 80.0 and world.get_health(first) == 0.0, "maximum-health growth preserves current health")
	_check(world.heal(first, 25.0) and world.get_health(first) == 25.0, "healing mutates authoritative health")
	_check(world.heal(first, 999.0) and world.get_health(first) == 80.0, "healing clamps to maximum health")
	_check(world.set_max_health(first, 40.0) and world.get_health(first) == 40.0, "maximum-health shrink clamps current health")
	_check(world.set_max_health(first, 120.0, true), "maximum health can refill atomically")
	_check(world.get_max_health(first) == 120.0 and world.get_health(first) == 120.0, "atomic refill stores matching health values")
	_check(world.set_representation(first, Types.Representation.MATERIALIZED), "representation can change")
	_check(world.get_representation(first) == Types.Representation.MATERIALIZED, "representation mutation is stored")
	_check(not world.try_begin_death(first), "healthy records cannot enter dying state")
	_check(world.set_health(first, 0.0), "lethal health can be stored before death transition")
	_check(world.try_begin_death(first), "first lethal transition succeeds")
	_check(world.is_dying(first), "successful lethal transition marks the record dying")
	_check(not world.try_begin_death(first), "repeated lethal transition is rejected")
	_check(not world.set_representation(first, Types.Representation.MATERIALIZED), "dying record cannot return to materialized")
	_check(world.get_representation(first) == Types.Representation.DYING, "rejected representation change preserves dying state")

	var cold_copy: Dictionary = world.get_cold_state(first)
	cold_copy["phase"] = 99
	(cold_copy["nested"] as Dictionary)["cooldown"] = 99.0
	var stored_cold: Dictionary = world.get_cold_state(first)
	_check(int(stored_cold["phase"]) == 2, "cold-state reads cannot mutate the world")
	_check(float((stored_cold["nested"] as Dictionary)["cooldown"]) == 1.5, "cold-state reads are deeply isolated")
	_check(world.replace_cold_state(first, {"phase": 7}), "cold state can be replaced")
	_check(int(world.get_cold_state(first)["phase"]) == 7, "cold-state replacement is stored")

	var active: Array[int] = []
	world.active_handles(active)
	var unique := {}
	for active_handle in active:
		unique[active_handle] = true
	_check(active.size() == 3 and unique.size() == 3, "active iteration returns every live handle once")

	var stale_slot := Types.slot_from_handle(second)
	var stale_generation := Types.generation_from_handle(second)
	_check(world.remove_enemy(second, &"test_remove"), "first removal succeeds")
	_check(not world.remove_enemy(second, &"test_remove"), "repeated removal is rejected")
	_check(not world.is_valid_handle(second), "removed handle becomes stale immediately")
	_check(world.get_position(second) == Vector2.ZERO, "stale position returns neutral default")
	_check(world.get_health(second) == 0.0, "stale health returns neutral default")
	_check(world.get_spec_id(second) == StringName(), "stale spec returns neutral default")
	_check(world.get_cold_state(second).is_empty(), "stale cold state returns empty data")

	var replacement: int = world.create_enemy(
		SpawnState.new(&"replacement", "res://replacement.tscn", Vector2(500.0, 0.0), 20.0, 90.0, 12.0, 3),
	)
	_check(Types.slot_from_handle(replacement) == stale_slot, "removed storage slot is reused")
	_check(Types.generation_from_handle(replacement) != stale_generation, "slot reuse changes generation")
	_check(not world.set_position(second, Vector2(9999.0, 9999.0)), "stale handle cannot mutate a replacement")
	_check(not world.set_max_health(second, 999.0, true), "stale handle cannot reconfigure replacement health")
	_check(not world.heal(second, 999.0), "stale handle cannot heal a replacement")
	_check(not world.try_begin_death(second), "stale handle cannot begin replacement death")
	_check(world.get_position(replacement) == Vector2(500.0, 0.0), "replacement survives stale mutation attempt")

	world.clear_world()
	_check(world.active_count() == 0, "clear removes every active record")
	_check(not world.is_valid_handle(first) and not world.is_valid_handle(third), "clear invalidates existing handles")
	var after_clear: int = world.create_enemy(
		SpawnState.new(&"after_clear", "res://after_clear.tscn", Vector2.ZERO, 10.0, 10.0, 5.0, 0),
	)
	_check(not world.is_valid_handle(first), "old handle stays stale after post-clear allocation")
	_check(world.is_valid_handle(after_clear), "post-clear allocation receives a valid generation")
	world.clear_world()
	world.queue_free()
