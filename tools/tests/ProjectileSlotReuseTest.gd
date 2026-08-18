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
	var change_counter := {&"count": 0}
	multimesh.changed.connect(func() -> void: change_counter[&"count"] = int(change_counter[&"count"]) + 1)
	manager.call("_update_renderer")
	_check(int(change_counter[&"count"]) > 0, "raw buffer upload notifies the MultiMeshInstance2D to redraw")
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

	# Compare a diagonal, non-uniform projectile against a transform/color record
	# generated through Godot's canonical per-instance MultiMesh API. This catches
	# raw-buffer layouts that look plausible in CPU arrays but render incorrectly.
	var diagonal_origin := Vector2(321.0, 240.0)
	manager.call("spawn_enemy", diagonal_origin, Vector2(3.0, 4.0), 125.0, 1.0, 5.0, null)
	manager.call("_update_renderer")
	var diagonal_index := int(manager.call("active_count")) - 1
	var positions: PackedVector2Array = manager.get("_positions") as PackedVector2Array
	var velocities: PackedVector2Array = manager.get("_velocities") as PackedVector2Array
	var body_lengths: PackedFloat32Array = manager.get("_body_length") as PackedFloat32Array
	var body_widths: PackedFloat32Array = manager.get("_body_width") as PackedFloat32Array
	var colors: PackedColorArray = manager.get("_colors") as PackedColorArray
	var reference := MultiMesh.new()
	reference.transform_format = MultiMesh.TRANSFORM_2D
	reference.use_colors = true
	reference.instance_count = 1
	var reference_transform := Transform2D(velocities[diagonal_index].angle(), positions[diagonal_index])
	reference_transform = reference_transform.scaled_local(Vector2(body_lengths[diagonal_index] / 18.0, body_widths[diagonal_index] / 4.0))
	reference.set_instance_transform_2d(0, reference_transform)
	reference.set_instance_color(0, colors[diagonal_index])
	var canonical: PackedFloat32Array = reference.get_buffer()
	buffer = manager.get("_render_buffer") as PackedFloat32Array
	var record_matches := canonical.is_empty() or canonical.size() == 12
	if not canonical.is_empty():
		for offset in range(8):
			record_matches = record_matches and is_equal_approx(buffer[diagonal_index * 12 + offset], canonical[offset])
		for offset in range(8, 12):
			record_matches = record_matches and absf(buffer[diagonal_index * 12 + offset] - canonical[offset]) < 0.001
	_check(record_matches, "raw renderer record matches Godot's canonical diagonal transform and color")

	# The dummy headless renderer has no readable framebuffer. With a real display,
	# verify the uploaded record produces visible pixels under a far-world Camera2D,
	# matching procedural gameplay rather than only screen-origin coordinates.
	if DisplayServer.get_name() != "headless":
		manager.call("_clear_all")
		var camera := Camera2D.new()
		camera.position = Vector2(10000.0, 10000.0)
		camera.enabled = true
		add_child(camera)
		manager.call("_update_renderer")
		await RenderingServer.frame_post_draw
		var baseline_image := get_viewport().get_texture().get_image()
		var profile := HitProfileAdapter.new()
		manager.call("spawn_player", camera.position, Vector2.RIGHT, profile, null)
		manager.call("_update_renderer")
		var far_bounds := multimesh.get_aabb()
		_check(far_bounds.has_point(Vector3(camera.position.x, camera.position.y, 0.0)), "raw upload bounds include the far-world projectile")
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var projectile_screen_position := Vector2i(image.get_width() / 2, image.get_height() / 2)
		var visible_pixel_found := _region_changed(baseline_image, image, projectile_screen_position)
		_check(visible_pixel_found, "raw MultiMesh upload draws a player projectile under a far-world camera")

	manager.call("_clear_all")
	_check(int(manager.call("active_count")) == 0, "clear removes all projectiles")

	manager.queue_free()
	print("ProjectileSlotReuseTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _region_changed(baseline: Image, current: Image, center: Vector2i) -> bool:
	for y in range(center.y - 20, center.y + 21):
		for x in range(center.x - 20, center.x + 21):
			var pixel := current.get_pixel(x, y)
			var baseline_pixel := baseline.get_pixel(x, y)
			var color_delta := Vector3(pixel.r - baseline_pixel.r, pixel.g - baseline_pixel.g, pixel.b - baseline_pixel.b).length()
			if color_delta > 0.05:
				return true
	return false
