extends Node

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
	var manager := ChunkManager.new()
	manager.generation_enabled = false
	manager.ground_enabled = false
	manager.debug_draw_chunk_outlines = false
	add_child(manager)
	var loaded_chunk := Node2D.new()
	manager.add_child(loaded_chunk)
	manager.set("_chunks", {Vector2i.ZERO: loaded_chunk})

	var flow := FlowFieldNav.new()
	flow.radius_cells = 3
	flow.max_expansions_per_frame = 1000
	flow.max_ms_per_frame = 0.0
	# This test drives the sliced build/load-shedding path directly; leaving the
	# threaded default on races the worker against the manual _step_build calls.
	flow.set("threaded_build", false)
	add_child(flow)
	flow.set("_cm", manager)
	flow.call("_ensure_buffers")

	_check(flow.has_method("current_build_budget_ms"), "flow exposes pressure-aware build budget")
	_check(flow.has_method("debug_active_generation"), "flow exposes completed active generation")
	flow.call("_start_rebuild", Vector2i(3, 3), 1)
	flow.call("_step_build")
	var first_generation := int(flow.call("debug_active_generation")) if flow.has_method("debug_active_generation") else -1
	var first_cost := flow.sample_cost(Vector2(1.0, 3.0) * float(flow.cell_size_px))
	_check(first_cost < 1_000_000_000, "first completed flow field is readable")

	flow.max_expansions_per_frame = 1
	flow.call("_start_rebuild", Vector2i(4, 3), 2)
	flow.call("_step_build")
	var partial_generation := int(flow.call("debug_active_generation")) if flow.has_method("debug_active_generation") else -2
	var partial_cost := flow.sample_cost(Vector2(1.0, 3.0) * float(flow.cell_size_px))
	_check(bool(flow.get("_building")), "replacement flow remains incremental after one step")
	_check(partial_generation == first_generation, "partial replacement does not publish a generation")
	_check(partial_cost == first_cost, "partial replacement leaves completed samples stable")

	var scheduler := get_node_or_null("/root/EnemySimulationScheduler")
	_check(scheduler != null and scheduler.has_method("set_physics_pressure_override"), "scheduler exposes deterministic pressure override")
	if scheduler != null and scheduler.has_method("set_physics_pressure_override") and flow.has_method("current_build_budget_ms"):
		flow.max_ms_per_frame = 1.5
		flow.set("pressured_ms_per_frame", 0.5)
		scheduler.call("set_physics_pressure_override", false)
		_check(is_equal_approx(float(flow.call("current_build_budget_ms")), 1.5), "normal flow build keeps configured budget")
		scheduler.call("set_physics_pressure_override", true)
		_check(is_equal_approx(float(flow.call("current_build_budget_ms")), 0.5), "physics pressure sheds flow build work")
		_check(bool(flow.get("_building")), "load shedding does not cancel active flow build")
		scheduler.call("set_physics_pressure_override", null)

	flow.queue_free()
	manager.queue_free()
	print("FlowFieldLoadSheddingTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
