extends Node

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


func _configured_manager(batched: bool) -> ChunkManager:
	var manager := ChunkManager.new()
	manager.set("batched_chunk_blockers", batched)
	manager.world_seed = 424242
	manager.ground_enabled = false
	manager.decals_enabled = false
	manager.deco_enabled = false
	manager.sites_enabled = false
	manager.debug_draw_chunk_outlines = false
	manager.debug_show_blocks = false
	manager.tiled_world_rendering = false
	manager.debug_force_content = true
	manager.weight_empty = 0.0
	manager.weight_building = 1.0
	manager.weight_ruins = 0.0
	manager.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn") as PackedScene
	manager.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn") as PackedScene
	manager.cover_half_scene = load("res://scenes/world/cover/CoverHalf.tscn") as PackedScene
	add_child(manager)
	return manager


func _run() -> void:
	var batched := _configured_manager(true)
	var chunk := batched.call("_create_chunk", Vector2i.ZERO) as Node2D
	await get_tree().process_frame
	var blocked := (batched.get("_blocked_cells") as Dictionary).duplicate()
	var projectile := (batched.get("_projectile_blockers") as Dictionary).duplicate()
	var data: ChunkBuildData
	if batched.has_method("get_chunk_build_data"):
		data = batched.call("get_chunk_build_data", Vector2i.ZERO) as ChunkBuildData
	_check(not blocked.is_empty(), "deterministic building generates blocked cells")
	_check(data != null and data.occupied_indices().size() == blocked.size(), "each blocked cell has one compact descriptor")
	if data != null:
		for index in data.occupied_indices():
			var cell := data.cell_for_index(index)
			var global_cell := Vector2i.ZERO * data.cells_per_side + cell
			var expected := WorldBlockerGeometry.pack(data.kind_at(cell), data.mask_at(cell))
			_check(int(projectile.get(global_cell, -1)) == expected, "compact blocker preserves its projectile descriptor at %s" % global_cell)
	var legacy_cover_nodes := 0
	for candidate in chunk.find_children("*", "Node", true, false):
		if candidate.is_in_group(&"cover_wall") or candidate.is_in_group(&"cover_half"):
			legacy_cover_nodes += 1
	_check(legacy_cover_nodes == 0, "batched generation creates no CoverWall or CoverHalf nodes")
	var blocker_shape_nodes := 0
	for candidate in chunk.find_children("*", "CollisionShape2D", true, false):
		if candidate.get_parent() is StaticBody2D:
			blocker_shape_nodes += 1
	_check(blocker_shape_nodes == 0, "batched blockers create no CollisionShape2D descendants")
	_check(chunk.find_children("*", "StaticBody2D", true, false).size() <= 3, "procedural chunk owns at most three blocker bodies")
	if batched.has_method("get_block_batch_stats"):
		var stats := batched.call("get_block_batch_stats") as Dictionary
		_check(int(stats.get("instances", 0)) == blocked.size(), "visual batches contain one instance per blocked cell")
	else:
		_check(false, "chunk manager exposes blocker batch diagnostics")

	batched.queue_free()
	await get_tree().process_frame

	var legacy := _configured_manager(false)
	legacy.call("_create_chunk", Vector2i.ZERO)
	await get_tree().process_frame
	var legacy_blocked := (legacy.get("_blocked_cells") as Dictionary).duplicate()
	var legacy_projectile := (legacy.get("_projectile_blockers") as Dictionary).duplicate()
	_check(blocked == legacy_blocked, "batched and legacy generation preserve the same blocked cells")
	_check(projectile == legacy_projectile, "batched and legacy generation preserve projectile geometry")
	legacy.queue_free()
	await get_tree().process_frame

	_test_unknown_scene_fallback()
	print("ChunkBlockIntegrationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_unknown_scene_fallback() -> void:
	var manager := _configured_manager(true)
	var chunk := Node2D.new()
	manager.add_child(chunk)
	manager.set("_gen_coord", Vector2i(9, 9))
	var source := Node2D.new()
	source.name = "CustomProceduralBlock"
	var custom_scene := PackedScene.new()
	_check(custom_scene.pack(source) == OK, "custom blocker fixture packs")
	source.free()
	var spawned := manager.call("_spawn_block", chunk, custom_scene, 1, 1) as Node2D
	_check(spawned != null and spawned.get_parent() == chunk, "unknown procedural scenes keep the legacy instantiation fallback")
	manager.queue_free()
