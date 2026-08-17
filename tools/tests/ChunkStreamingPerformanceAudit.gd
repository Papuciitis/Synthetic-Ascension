extends Node

const AUDIT_SEED := 251337
const AUDIT_RADIUS := 2
const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")

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


func _configured_manager() -> ChunkManager:
	var manager := ChunkManager.new()
	manager.world_seed = AUDIT_SEED
	manager.load_radius = AUDIT_RADIUS
	manager.unload_radius = AUDIT_RADIUS + 1
	manager.use_camera_stream_bounds = false
	manager.stream_activation_budget_ms = 2.0
	manager.max_chunk_generations_per_frame = 4
	manager.batched_chunk_blockers = true
	manager.tiled_world_rendering = false
	manager.debug_draw_chunk_outlines = false
	manager.debug_show_blocks = false
	manager.decals_enabled = true
	manager.deco_enabled = true
	manager.sites_enabled = true
	manager.cover_full_scene = COVER_FULL
	manager.cover_window_scene = COVER_WINDOW
	manager.cover_half_scene = COVER_HALF
	add_child(manager)
	return manager


func _run() -> void:
	var warmup := _configured_manager()
	# This seed's first deterministic site chunk also warms the facility carver.
	warmup.call("_create_chunk", Vector2i(0, -2))
	await get_tree().process_frame
	warmup.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	var static_baseline := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var manager := _configured_manager()
	_check(manager.has_method("get_chunk_stream_debug_stats"), "chunk manager exposes streaming timing diagnostics")
	manager.start_streaming(Vector2.ZERO)
	var queued_before_activation := manager.debug_chunk_queue().size()
	manager.process_chunk_generation_queue(100)
	await get_tree().process_frame

	var stream_stats := manager.call("get_chunk_stream_debug_stats") as Dictionary if manager.has_method("get_chunk_stream_debug_stats") else {}
	var block_stats := manager.get_block_batch_stats()
	var render_stats := manager.get_chunk_render_stats()
	var loaded_chunks := manager.loaded_chunk_count()
	var cover_nodes := _count_cover_nodes(manager)
	var all_collision_shape_nodes := manager.find_children("*", "CollisionShape2D", true, false).size()
	var collision_shape_nodes := _count_blocker_collision_shape_nodes(manager)
	var blocker_body_count := manager.find_children("*", "StaticBody2D", true, false).size()
	var blocker_shape_count := _count_owned_shapes(manager)
	var blocker_cells := int((manager.get("_blocked_cells") as Dictionary).size())
	var ground_tile_cells := int(render_stats.get("procedural_tile_cells", -1))
	var static_after := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var timings := stream_stats.get("build_samples_ms", []) as Array
	var median_chunk_ms := float(stream_stats.get("median_build_ms", INF))
	var max_chunk_ms := float(stream_stats.get("max_build_ms", INF))

	_check(loaded_chunks == 25, "compatibility radius 2 activates 25 chunks")
	_check(queued_before_activation == 24, "center activation leaves one 24-chunk boundary stream")
	_check(timings.size() == loaded_chunks, "every active chunk contributes one timing sample")
	_check(cover_nodes == 0, "generated blocker scenes are eliminated")
	_check(collision_shape_nodes == 0, "generated CollisionShape2D nodes are eliminated")
	_check(blocker_body_count <= loaded_chunks * 3, "blocker bodies scale with chunks")
	_check(ground_tile_cells == 0, "ground does not expand into TileMap cells")
	_check(median_chunk_ms < 4.0, "median warmed chunk activation is below 4 ms")
	_check(max_chunk_ms < 12.0, "no warmed chunk activation exceeds 12 ms")
	_check(int(block_stats.get("instances", 0)) == blocker_cells, "MultiMesh blocker instances match compact blocker cells")
	_check(_overlay_exposes_streaming_diagnostics(), "performance overlay exposes streaming queue, timing, blocker, renderer, and budget diagnostics")

	var audit := {
		"seed": AUDIT_SEED,
		"radius": AUDIT_RADIUS,
		"plan_ms": float(stream_stats.get("last_plan_ms", 0.0)),
		"chunk_build_ms": timings,
		"chunk_build_phases": stream_stats.get("build_phase_samples", []),
		"median_chunk_ms": median_chunk_ms,
		"max_chunk_ms": max_chunk_ms,
		"loaded_chunks": loaded_chunks,
		"queued_boundary_chunks": queued_before_activation,
		"remaining_queue": manager.debug_chunk_queue().size(),
		"blocker_cells": blocker_cells,
		"blocker_bodies": blocker_body_count,
		"blocker_shapes": blocker_shape_count,
		"cover_nodes": cover_nodes,
		"collision_shape_nodes": collision_shape_nodes,
		"interactive_collision_shape_nodes": all_collision_shape_nodes - collision_shape_nodes,
		"multimesh_batches": int(block_stats.get("batches", 0)),
		"multimesh_instances": int(block_stats.get("instances", 0)),
		"ground_sprites": int(render_stats.get("ground_sprites", 0)),
		"floor_sprites": int(render_stats.get("floor_sprites", 0)),
		"procedural_tile_cells": ground_tile_cells,
		"stream_budget_ms": manager.stream_activation_budget_ms,
		"static_memory_baseline_bytes": static_baseline,
		"static_memory_active_bytes": static_after,
		"static_memory_delta_bytes": static_after - static_baseline,
	}
	print("CHUNK_AUDIT ", JSON.stringify(audit))
	print("ChunkStreamingPerformanceAudit: %d passed, %d failed" % [_passes, _failures])
	manager.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _count_cover_nodes(root: Node) -> int:
	var count := 0
	for candidate in root.find_children("*", "Node", true, false):
		if candidate.is_in_group(&"cover_wall") or candidate.is_in_group(&"cover_half"):
			count += 1
	return count


func _count_owned_shapes(root: Node) -> int:
	var count := 0
	for candidate in root.find_children("*", "StaticBody2D", true, false):
		var body := candidate as StaticBody2D
		for owner_id in body.get_shape_owners():
			count += body.shape_owner_get_shape_count(owner_id)
	return count


func _count_blocker_collision_shape_nodes(root: Node) -> int:
	var count := 0
	for candidate in root.find_children("*", "CollisionShape2D", true, false):
		if candidate.get_parent() is StaticBody2D:
			count += 1
	return count


func _overlay_exposes_streaming_diagnostics() -> bool:
	var overlay := PerformanceOverlay.new()
	var details := overlay.format_details({
		"chunk_stream": {
			"queue_length": 7,
			"oldest_request_ms": 12.5,
			"last_build_ms": 1.25,
			"median_build_ms": 0.75,
			"activation_budget_ms": 2.0,
		},
		"chunk_blocks": {"instances": 123, "batches": 9, "bodies": 6, "shapes": 44},
		"authored_tiles": {"cells": 88, "layers": 2},
	}) as Dictionary
	overlay.free()
	var world := String(details.get("world", ""))
	return (
		world.contains("queue 7")
		and world.contains("oldest 12.50 ms")
		and world.contains("last/median 1.25/0.75 ms")
		and world.contains("blockers 123")
		and world.contains("bodies/shapes 6/44")
		and world.contains("batches 9")
		and world.contains("budget 2.00 ms")
		and world.contains("Authored tiles 88")
	)
