extends Node

# Performance war room M1: the staged blocker activation (M1b) and the
# ground-texture warm-up (M1a).
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/ChunkStagedBlockerTest.tscn

const SEED := 251337
const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
const _WORLD_ART := preload("res://core/systems/world/WorldArt.gd")

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


func _manager(staged: bool) -> ChunkManager:
	var manager := ChunkManager.new()
	manager.world_seed = SEED
	manager.load_radius = 1
	manager.unload_radius = 2
	manager.use_camera_stream_bounds = false
	# One content activation per queue call, every pending stage first.
	manager.stream_activation_budget_ms = 1000.0
	manager.max_chunk_generations_per_frame = 1
	manager.batched_chunk_blockers = true
	manager.staged_blocker_activation = staged
	manager.tiled_world_rendering = false
	manager.debug_draw_chunk_outlines = false
	manager.debug_show_blocks = false
	manager.decals_enabled = false
	manager.deco_enabled = true
	manager.sites_enabled = true
	manager.cover_full_scene = COVER_FULL
	manager.cover_window_scene = COVER_WINDOW
	manager.cover_half_scene = COVER_HALF
	add_child(manager)
	return manager


func _blocker_cells(manager: ChunkManager, coord: Vector2i) -> int:
	var data := manager.get_chunk_build_data(coord)
	return data.occupied_indices().size() if data != null else 0


func _has_physics(manager: ChunkManager, coord: Vector2i) -> bool:
	var chunk := manager.get("_chunks").get(coord) as Node2D
	return chunk != null and chunk.get_node_or_null("ChunkBlockPhysics") != null


func _loaded_blocker_cells(manager: ChunkManager) -> int:
	var total := 0
	for coord in manager.get("_chunks").keys():
		total += _blocker_cells(manager, coord)
	return total


func _drain(manager: ChunkManager, max_calls: int = 64) -> int:
	var calls := 0
	while calls < max_calls and (not manager.debug_chunk_queue().is_empty() or manager.pending_blocker_stage_count() > 0):
		manager.process_chunk_generation_queue()
		calls += 1
	return calls


func _run() -> void:
	_test_stages_follow_content()
	_test_staged_equals_synchronous()
	_test_unload_before_stage()
	_test_explicit_limit_is_synchronous()
	_test_ground_textures_warm()
	print("ChunkStagedBlockerTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_stages_follow_content() -> void:
	var manager := _manager(true)
	manager.start_streaming(Vector2.ZERO)
	var queue := manager.debug_chunk_queue()
	_check(queue.size() == 8, "radius 1 leaves eight chunks to stream around the synchronous centre")
	_check(manager.pending_blocker_stage_count() == 0, "the synchronous centre chunk stages nothing")
	var first: Vector2i = queue[0]

	manager.process_chunk_generation_queue()
	_check(manager.get("_chunks").has(first), "the first queue call activates the first chunk's content")
	_check(manager.pending_blocker_stage_count() == 1, "its blocker work is pending (one staged entry)")
	_check(not _has_physics(manager, first), "no physics node before the physics stage")
	var instances_before := int(manager.get_block_batch_stats().get("instances", 0))
	var centre_cells := _blocker_cells(manager, Vector2i.ZERO)
	_check(instances_before == centre_cells, "the renderer holds only the centre chunk's instances before the stages")
	var sample: Dictionary = manager.get("_phase_sample_by_coord").get(first, {})
	_check(bool(sample.get("staged_pending", false)) and float(sample.get("blocker_ms", 1.0)) == 0.0 and float(sample.get("blocker_physics_ms", 1.0)) == 0.0, "the phase sample is marked pending with no blocker cost yet")

	var second: Vector2i = manager.debug_chunk_queue()[0]
	manager.process_chunk_generation_queue()
	_check(_has_physics(manager, first) == (_blocker_cells(manager, first) > 0), "the next call builds the first chunk's bodies (when it has blockers)")
	_check(int(manager.get_block_batch_stats().get("instances", 0)) == centre_cells + _blocker_cells(manager, first), "and adds exactly its instances to the renderer")
	_check(manager.get("_chunks").has(second) and manager.pending_blocker_stage_count() == 1, "then activates the second chunk's content, leaving its stages pending")
	_check(not bool(sample.get("staged_pending", true)) and float(sample.get("blocker_ms", -1.0)) >= 0.0, "the first chunk's phase sample completes with its blocker split")
	_check(absf(float(sample.get("blocker_ms", -1.0)) - (float(sample.get("blocker_physics_ms", 0.0)) + float(sample.get("blocker_render_ms", 0.0)))) < 0.0001, "blocker_ms is the sum of the physics and render stages")

	var calls := _drain(manager)
	_check(manager.pending_blocker_stage_count() == 0 and manager.debug_chunk_queue().is_empty(), "draining leaves no queue and no pending stage (%d calls)" % calls)
	var stats := manager.get_chunk_stream_debug_stats()
	_check(int(stats.get("pending_blocker_stages", -1)) == 0 and stats.has("max_blocker_stage_ms"), "streaming stats expose the pending count and the stage cost")
	manager.queue_free()


func _test_staged_equals_synchronous() -> void:
	var staged := _manager(true)
	staged.start_streaming(Vector2.ZERO)
	_drain(staged)
	var sync := _manager(false)
	sync.start_streaming(Vector2.ZERO)
	_drain(sync)
	var a := staged.get_block_batch_stats()
	var b := sync.get_block_batch_stats()
	_check(int(a.get("instances", -1)) == int(b.get("instances", -2)), "staged and synchronous activation draw the same blocker instances (%d)" % int(a.get("instances", -1)))
	_check(int(a.get("bodies", -1)) == int(b.get("bodies", -2)) and int(a.get("shapes", -1)) == int(b.get("shapes", -2)), "and build the same bodies and shapes (%d / %d)" % [int(a.get("bodies", -1)), int(a.get("shapes", -1))])
	_check(int(a.get("instances", -1)) == _loaded_blocker_cells(staged), "instances match the loaded chunks' blocker cells")
	_check(staged.loaded_chunk_count() == 9 and sync.loaded_chunk_count() == 9, "both managers hold the nine chunks")
	staged.queue_free()
	sync.queue_free()


func _test_unload_before_stage() -> void:
	var manager := _manager(true)
	manager.start_streaming(Vector2.ZERO)
	manager.process_chunk_generation_queue()
	var pending_coord: Vector2i = manager.get("_pending_blocker_stages")[0].get("coord")
	_check(manager.pending_blocker_stage_count() == 1, "one chunk's stages are pending")
	# Teleport far: the pending chunk unloads before its stages run.
	manager.set("_current_center", Vector2i(40, 40))
	manager.call("_update_streaming")
	_check(not manager.get("_chunks").has(pending_coord), "the pending chunk unloaded")
	var before := manager.pending_blocker_stage_count()
	_drain(manager)
	_check(before >= 1 and manager.pending_blocker_stage_count() == 0, "the stale stage is dropped without error")
	_check(int(manager.get_block_batch_stats().get("instances", 0)) == _loaded_blocker_cells(manager), "no orphan renderer instances after the unload (%d)" % int(manager.get_block_batch_stats().get("instances", 0)))
	manager.queue_free()


func _test_explicit_limit_is_synchronous() -> void:
	var manager := _manager(true)
	manager.start_streaming(Vector2.ZERO)
	manager.process_chunk_generation_queue()
	_check(manager.pending_blocker_stage_count() == 1, "frame path staged the first chunk")
	var generated := manager.process_chunk_generation_queue(2)
	_check(generated == 2 and manager.pending_blocker_stage_count() == 0, "an explicit-limit call flushes the pending stage and activates synchronously")
	var all_have_blockers := true
	for coord in manager.get("_chunks").keys():
		if _blocker_cells(manager, coord) > 0 and not _has_physics(manager, coord):
			all_have_blockers = false
	_check(all_have_blockers, "every loaded chunk with blocker cells has its physics node")
	manager.queue_free()


func _test_ground_textures_warm() -> void:
	_WORLD_ART.release_static_caches()
	var count: int = _WORLD_ART.ground_texture_count()
	var cold := 0
	for index in count:
		if not _WORLD_ART.ground_texture_is_cached(index):
			cold += 1
	_check(cold == count, "ground textures start cold (%d)" % count)
	var manager := _manager(false)
	_WORLD_ART.release_static_caches()
	manager.configure_procedural_world(SEED, {}, {}, {}, {}, {})
	var warm := 0
	for index in count:
		if _WORLD_ART.ground_texture_is_cached(index):
			warm += 1
	_check(warm == count, "configuring the procedural world warms every ground texture, road and plaza stamps included")
	manager.queue_free()
