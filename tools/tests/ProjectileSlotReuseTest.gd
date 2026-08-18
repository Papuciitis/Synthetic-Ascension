extends Node

# Removing a projectile used to shrink 21 packed arrays (realloc + copy per
# despawn, hundreds of times per second at bullet-heaven kill rates). Slots
# must be swap-removed and reused at their high-water capacity instead.

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
	var manager_script := load("res://core/combat/projectile/ProjectileSimulationManager.gd") as Script
	var manager: Node2D = manager_script.new()
	add_child(manager)
	manager.set_physics_process(false)

	for i in range(10):
		manager.call("spawn_enemy", Vector2(float(i) * 10.0, 0.0), Vector2.RIGHT, 100.0, 1.0, 5.0, null)
	_check(int(manager.call("active_count")) == 10, "ten projectiles spawn")
	var high_water := (manager.get("_positions") as PackedVector2Array).size()
	_check(high_water == 10, "spawns fill packed slots")

	manager.call("_remove", 0)
	manager.call("_remove", 0)
	_check(int(manager.call("active_count")) == 8, "removals shrink the active count")
	_check(
		(manager.get("_positions") as PackedVector2Array).size() == high_water,
		"removals keep the high-water capacity instead of resizing every array"
	)

	manager.call("spawn_enemy", Vector2(500.0, 0.0), Vector2.RIGHT, 100.0, 1.0, 5.0, null)
	_check(int(manager.call("active_count")) == 9, "spawning after removal reuses a retained slot")
	_check(
		(manager.get("_positions") as PackedVector2Array).size() == high_water,
		"slot reuse does not grow the arrays"
	)
	_check(
		(manager.get("_positions") as PackedVector2Array)[8] == Vector2(500.0, 0.0),
		"the reused slot carries the new projectile's data"
	)

	manager.call("_update_renderer")
	var multimesh: MultiMesh = manager.get("_multimesh")
	_check(multimesh != null and multimesh.visible_instance_count == 9, "renderer shows exactly the active projectiles")
	# Transform read-back is not supported by the headless dummy renderer (it
	# also failed against the old per-instance API), so the buffer content is
	# validated directly instead.
	var buffer: PackedFloat32Array = manager.get("_render_buffer")
	var expected: Vector2 = (manager.get("_positions") as PackedVector2Array)[0]
	_check(
		buffer.size() >= 12
		and is_equal_approx(buffer[3], expected.x)
		and is_equal_approx(buffer[7], expected.y),
		"render buffer carries the simulation position"
	)

	manager.call("_clear_all")
	_check(int(manager.call("active_count")) == 0, "clear removes all projectiles")

	manager.queue_free()
	print("ProjectileSlotReuseTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
