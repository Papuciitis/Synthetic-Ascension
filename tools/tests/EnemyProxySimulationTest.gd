extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const SimulationScript = preload("res://core/systems/enemy_world/EnemyProxySimulation.gd")

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


func _spawn(
	world: Node,
	id: StringName,
	position: Vector2,
	speed: float = 100.0,
	ai_kind: int = 0,
	flags: int = 0,
	cold_state: Dictionary = {},
) -> int:
	return int(world.call("create_enemy", SpawnState.new(
		id,
		"res://%s.tscn" % String(id),
		position,
		20.0,
		speed,
		6.0,
		ai_kind,
		flags,
		cold_state,
	)))


func _run() -> void:
	var world := WorldScript.new()
	add_child(world)
	var simulation := SimulationScript.new()
	simulation.set("update_hz", 10.0)
	simulation.set("slice_count", 1)
	simulation.call("setup", world)
	add_child(simulation)
	_check(is_equal_approx(float(simulation.call("update_interval")), 0.1), "proxy simulation starts at 10 Hz")
	simulation.call("set_pressure_level", 1)
	_check(is_equal_approx(float(simulation.call("update_interval")), 1.0 / 6.0), "pressure reduces proxy simulation to 6 Hz")
	_check(int(simulation.get("slice_count")) == 8, "pressure spreads proxy work across eight slices")
	simulation.call("set_pressure_level", 2)
	_check(is_equal_approx(float(simulation.call("update_interval")), 1.0 / 3.0), "emergency pressure reduces proxy simulation to 3 Hz")
	_check(int(simulation.get("slice_count")) == 12, "emergency pressure spreads proxy work across twelve slices")
	simulation.call("set_pressure_level", 0)
	_check(is_equal_approx(float(simulation.call("update_interval")), 0.1), "proxy simulation restores 10 Hz after pressure")
	_check(int(simulation.get("slice_count")) == 6, "proxy simulation restores six normal slices")

	var chase := _spawn(world, &"chase", Vector2.ZERO)
	_check(int(simulation.call("advance", 0.1, Vector2(100.0, 0.0))) == 1, "10 Hz step updates one data-only chase record")
	_check(world.get_position(chase).is_equal_approx(Vector2(10.0, 0.0)), "data-only chase moves toward target at authoritative speed")
	_check(world.get_previous_position(chase) == Vector2.ZERO, "proxy movement preserves previous position for interpolation")
	_check(world.get_velocity(chase).is_equal_approx(Vector2(100.0, 0.0)), "proxy movement stores authoritative velocity")
	_check(world.get_facing(chase).is_equal_approx(Vector2.RIGHT), "proxy movement stores stable facing")
	_check(simulation.call("interpolated_position", chase, 0.0) == Vector2.ZERO, "interpolation alpha zero returns previous position")
	_check(simulation.call("interpolated_position", chase, 1.0).is_equal_approx(Vector2(10.0, 0.0)), "interpolation alpha one returns current position")
	# Halfway through the 10 Hz interval the proxy is drawn at (5, 0). Dropping
	# to the 3 Hz emergency rate must not recompute that blend against the
	# longer interval (that snapped every proxy backwards on the frame pressure
	# engaged); the drawn position is continuous across the rate change.
	simulation.set("slice_count", 1)
	simulation.call("advance", 0.05, Vector2(100.0, 0.0))
	var before_rate_change: Vector2 = simulation.call("interpolated_position", chase)
	_check(before_rate_change.is_equal_approx(Vector2(5.0, 0.0)), "mid-interval blend sits halfway (got %s)" % before_rate_change)
	simulation.call("set_pressure_level", 2)
	var after_rate_change: Vector2 = simulation.call("interpolated_position", chase)
	_check(
		after_rate_change.is_equal_approx(before_rate_change),
		"changing the proxy update rate keeps the interpolated position continuous (got %s)" % after_rate_change
	)
	_check(world.get_position(chase).is_equal_approx(Vector2(10.0, 0.0)), "rate change leaves the authoritative position untouched")
	# The proxy's next step lands mid-blend at the new rate: clock 0.15 with
	# 0.05 s banked, the 3 Hz slice fires at 0.44 s, blend 0.78 through the
	# rebased interval. The step must continue from the DRAWN point, not
	# reset the origin to the old authoritative position (a forward snap).
	simulation.set("slice_count", 1)
	simulation.call("advance", 0.29, Vector2(100.0, 0.0))
	var drawn_before_step: Vector2 = before_rate_change.lerp(Vector2(10.0, 0.0), 0.87)
	var drawn_after_step: Vector2 = simulation.call("interpolated_position", chase)
	_check(
		drawn_after_step.distance_to(drawn_before_step) < 0.25,
		"a step that lands mid-blend keeps the drawn position continuous (before %s after %s)" % [drawn_before_step, drawn_after_step]
	)
	_check(
		world.get_position(chase).is_equal_approx(Vector2(10.0 + 100.0 / 3.0, 0.0)),
		"the authoritative step still advances a full 3 Hz interval"
	)
	simulation.call("set_pressure_level", 0)
	# Consume the banked time with single slices so the tests below see the
	# original 6-slice, zero-accumulator cadence.
	simulation.set("slice_count", 1)
	simulation.call("advance", 0.1 - fmod(float(simulation.get("_slice_accumulator")), 0.1), Vector2(100.0, 0.0))
	simulation.set("slice_count", 6)

	var controlled := _spawn(world, &"controlled", Vector2.ZERO, 100.0, 0, 0, {"knockback_decay": 0.0})
	world.set_stun_time(controlled, 0.2)
	world.set_knockback_velocity(controlled, Vector2(50.0, 0.0))
	simulation.call("advance", 0.1, Vector2(100.0, 0.0))
	_check(world.get_position(controlled).is_equal_approx(Vector2(5.0, 0.0)), "stunned proxy moves only from authoritative knockback")
	_check(is_equal_approx(world.get_stun_time(controlled), 0.1), "proxy simulation advances stun time centrally")

	var materialized := _spawn(world, &"materialized", Vector2.ZERO)
	world.set_representation(materialized, Types.Representation.MATERIALIZED)
	var smart := _spawn(world, &"smart", Vector2.ZERO, 100.0, 2)
	var protected := _spawn(world, &"protected", Vector2.ZERO, 100.0, 0, Types.Flags.CRITICAL)
	simulation.call("advance", 0.1, Vector2(100.0, 0.0))
	_check(world.get_position(materialized) == Vector2.ZERO, "proxy simulation never moves materialized actors")
	_check(world.get_position(smart) == Vector2.ZERO, "first proxy slice excludes smart archetypes")
	_check(world.get_position(protected) == Vector2.ZERO, "proxy simulation never moves critical records")

	var stale := _spawn(world, &"stale", Vector2.ZERO)
	world.remove_enemy(stale, &"proxy_stale")
	simulation.call("advance", 0.1, Vector2(100.0, 0.0))
	_check(not world.is_valid_handle(stale), "proxy simulation ignores stale handles safely")

	simulation.queue_free()
	world.queue_free()
	await get_tree().process_frame

	world = WorldScript.new()
	add_child(world)
	simulation = SimulationScript.new()
	simulation.set("update_hz", 10.0)
	simulation.set("slice_count", 6)
	simulation.call("setup", world)
	add_child(simulation)
	for index in range(600):
		_spawn(world, StringName("bulk_%d" % index), Vector2(float(index % 30), float(index / 30)), 75.0)
	var started := Time.get_ticks_usec()
	for _step in range(200):
		simulation.call("advance", 0.1, Vector2(1000.0, 1000.0))
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var counters := simulation.call("get_debug_counters") as Dictionary
	_check(int(counters.get("total_updates", 0)) == 120000, "rotating slices update every one of 600 records at 10 Hz")
	_check(elapsed_ms < 5000.0, "600-record proxy simulation stays within the headless regression budget")
	var all_finite := true
	var handles: Array[int] = []
	world.active_handles(handles)
	for handle in handles:
		if not world.get_position(handle).is_finite():
			all_finite = false
			break
	_check(all_finite, "600-record proxy simulation keeps every position finite")
	print("EnemyProxySimulationBenchmark records=600 updates=120000 elapsed_ms=", snapped(elapsed_ms, 0.001))

	simulation.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("EnemyProxySimulationTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
