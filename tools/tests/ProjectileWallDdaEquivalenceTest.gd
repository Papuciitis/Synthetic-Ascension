extends Node

## ChunkManager.projectile_hit_t skips the 3x3 neighbourhood test for trace
## cells with no blocker within one cell (FPS audit 2026-10-04, item 7). That
## must never change an answer: this test compares it with the old DDA (the
## neighbourhood test on every traversed cell) over thousands of random
## segments on streamed procedural chunks, after every kind of blocker
## change - manual blocks added, removed and cleared, owned projectile
## blockers registered and unregistered, chunks unloaded by streaming, and a
## world reset - and checks the dilated set against a fresh rebuild each time.

const SEED := 424242
const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")

## The old loop as a typed caller, for the cost comparison only.
class ReferenceDda:
	extends RefCounted
	var manager: ChunkManager

	func hit_t(from_pos: Vector2, to_pos: Vector2, projectile_radius: float) -> float:
		var cell_size_px := manager.cell_size_px
		var start_cell: Vector2i = manager.world_to_cell(from_pos)
		var end_cell: Vector2i = manager.world_to_cell(to_pos)
		var cell: Vector2i = start_cell
		var delta: Vector2 = to_pos - from_pos
		var step_x: int = signi(int(signf(delta.x)))
		var step_y: int = signi(int(signf(delta.y)))
		var t_delta_x: float = INF if step_x == 0 else absf(float(cell_size_px) / delta.x)
		var t_delta_y: float = INF if step_y == 0 else absf(float(cell_size_px) / delta.y)
		var boundary_x: float = float((cell.x + (1 if step_x > 0 else 0)) * cell_size_px)
		var boundary_y: float = float((cell.y + (1 if step_y > 0 else 0)) * cell_size_px)
		var t_max_x: float = INF if step_x == 0 else (boundary_x - from_pos.x) / delta.x
		var t_max_y: float = INF if step_y == 0 else (boundary_y - from_pos.y) / delta.y
		var best: float = 2.0
		var guard: int = 0
		while guard < 512:
			guard += 1
			best = minf(best, manager._projectile_neighborhood_hit_t(cell, from_pos, to_pos, projectile_radius))
			if cell == end_cell or minf(t_max_x, t_max_y) > best:
				break
			if t_max_x < t_max_y:
				cell.x += step_x
				t_max_x += t_delta_x
			else:
				cell.y += step_y
				t_max_y += t_delta_y
		return best if best <= 1.0 else -1.0


var _passes := 0
var _failures := 0
var _rng := RandomNumberGenerator.new()
var _segments_checked := 0
var _hits_checked := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _manager() -> ChunkManager:
	var manager := ChunkManager.new()
	manager.world_seed = SEED
	manager.load_radius = 1
	manager.unload_radius = 1
	manager.use_camera_stream_bounds = false
	manager.stream_activation_budget_ms = 1000.0
	manager.max_chunk_generations_per_frame = 1
	manager.batched_chunk_blockers = true
	manager.staged_blocker_activation = false
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


func _drain(manager: ChunkManager) -> void:
	var calls := 0
	while calls < 64 and (not manager.debug_chunk_queue().is_empty() or manager.pending_blocker_stage_count() > 0):
		manager.process_chunk_generation_queue()
		calls += 1


## The pre-2026-10-04 projectile_hit_t: the neighbourhood test on every cell.
func _reference_hit_t(manager: ChunkManager, from_pos: Vector2, to_pos: Vector2, projectile_radius: float) -> float:
	var cell_size_px := int(manager.cell_size_px)
	var start_cell: Vector2i = manager.world_to_cell(from_pos)
	var end_cell: Vector2i = manager.world_to_cell(to_pos)
	var cell: Vector2i = start_cell
	var delta: Vector2 = to_pos - from_pos
	var step_x: int = signi(int(signf(delta.x)))
	var step_y: int = signi(int(signf(delta.y)))
	var t_delta_x: float = INF if step_x == 0 else absf(float(cell_size_px) / delta.x)
	var t_delta_y: float = INF if step_y == 0 else absf(float(cell_size_px) / delta.y)
	var boundary_x: float = float((cell.x + (1 if step_x > 0 else 0)) * cell_size_px)
	var boundary_y: float = float((cell.y + (1 if step_y > 0 else 0)) * cell_size_px)
	var t_max_x: float = INF if step_x == 0 else (boundary_x - from_pos.x) / delta.x
	var t_max_y: float = INF if step_y == 0 else (boundary_y - from_pos.y) / delta.y
	var best: float = 2.0
	var guard: int = 0
	while guard < 512:
		guard += 1
		best = minf(best, float(manager.call("_projectile_neighborhood_hit_t", cell, from_pos, to_pos, projectile_radius)))
		if cell == end_cell or minf(t_max_x, t_max_y) > best:
			break
		if t_max_x < t_max_y:
			cell.x += step_x
			t_max_x += t_delta_x
		else:
			cell.y += step_y
			t_max_y += t_delta_y
	return best if best <= 1.0 else -1.0


func _random_segment(center: Vector2, spread: float) -> Array:
	var from_pos := center + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))
	var length := _rng.randf_range(0.0, 220.0) if _rng.randf() < 0.85 else _rng.randf_range(200.0, 1600.0)
	var direction := Vector2.RIGHT.rotated(_rng.randf() * TAU)
	var roll := _rng.randf()
	if roll < 0.06:
		direction = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN][_rng.randi_range(0, 3)]
	elif roll < 0.08:
		length = 0.0
	elif roll < 0.10:
		# Exactly on a cell boundary.
		from_pos = Vector2(round(from_pos.x / 64.0) * 64.0, from_pos.y)
	return [from_pos, from_pos + direction * length, [0.0, 2.0, 5.0, 8.0, 12.0][_rng.randi_range(0, 4)]]


func _compare_phase(manager: ChunkManager, label: String, center: Vector2, count: int) -> void:
	var near: Dictionary = manager.get("_near_blockers")
	var stored := near.duplicate()
	manager.call("_rebuild_near_blockers")
	_check(stored == manager.get("_near_blockers"), "%s: the incremental dilation equals a fresh rebuild (%d cells)" % [label, stored.size()])
	var mismatches := 0
	var hits := 0
	for i in range(count):
		var segment := _random_segment(center, 1100.0)
		var expected := _reference_hit_t(manager, segment[0], segment[1], segment[2])
		var actual := manager.projectile_hit_t(segment[0], segment[1], segment[2])
		if expected != actual:
			mismatches += 1
			if mismatches <= 3:
				push_error("%s mismatch %s -> %s r=%s: old %s new %s" % [label, str(segment[0]), str(segment[1]), str(segment[2]), str(expected), str(actual)])
		if expected >= 0.0:
			hits += 1
	_segments_checked += count
	_hits_checked += hits
	_check(mismatches == 0, "%s: %d random segments, identical wall answers (%d hits)" % [label, count, hits])


func _run() -> void:
	_rng.seed = SEED
	var manager := _manager()
	manager.start_streaming(Vector2.ZERO)
	_drain(manager)
	_check(manager.loaded_chunk_count() == 9, "nine procedural chunks stream in")
	_compare_phase(manager, "streamed chunks", Vector2.ZERO, 1500)

	var manual: Array[Vector2i] = []
	for i in range(60):
		var cell := Vector2i(_rng.randi_range(-20, 20), _rng.randi_range(-20, 20))
		manager.register_manual_block_cell(cell)
		manual.append(cell)
	_compare_phase(manager, "manual blocks added", Vector2.ZERO, 1000)
	for i in range(0, manual.size(), 2):
		manager.unregister_manual_block_cell(manual[i])
	_compare_phase(manager, "half the manual blocks removed", Vector2.ZERO, 1000)

	var owned: Array = []
	for i in range(40):
		var world_position := Vector2(_rng.randf_range(-1200.0, 1200.0), _rng.randf_range(-1200.0, 1200.0))
		var descriptor := WorldBlockerGeometry.pack(WorldBlockerGeometry.Kind.SOLID_CELL)
		manager.register_projectile_blocker_world(world_position, descriptor, 1000 + i)
		owned.append([world_position, 1000 + i])
	_compare_phase(manager, "owned projectile blockers registered", Vector2.ZERO, 1000)
	for i in range(0, owned.size(), 3):
		manager.unregister_projectile_blocker_world(owned[i][0], owned[i][1])
	# A wrong owner must change nothing.
	manager.unregister_projectile_blocker_world(owned[1][0], 1)
	_compare_phase(manager, "some owned blockers unregistered", Vector2.ZERO, 1000)
	manager.clear_manual_blocks()
	_compare_phase(manager, "manual blocks cleared", Vector2.ZERO, 1000)

	# Stream two chunks east: the western column unloads.
	var chunk_px := float(manager.cell_size_px * manager.call("_cells_per_chunk"))
	manager.set("_current_center", Vector2i(2, 0))
	manager.call("_update_streaming")
	_drain(manager)
	_compare_phase(manager, "after streaming moved and unloaded chunks", Vector2(chunk_px * 2.0, 0.0), 1500)

	manager.reset_world()
	_compare_phase(manager, "after a world reset", Vector2.ZERO, 500)
	# A reset without a player recentres far away; stream the origin back.
	manager.set("_current_center", Vector2i.ZERO)
	manager.call("_update_streaming")
	_drain(manager)
	_check(manager.get("_chunks").has(Vector2i.ZERO), "the reset world streams back around the origin")
	_compare_phase(manager, "after restreaming the reset world", Vector2.ZERO, 1000)
	_check(_hits_checked > 1000, "the comparison covered real wall hits (%d of %d segments)" % [_hits_checked, _segments_checked])

	# Cost of one frame of bullet travel (10-25 px, what ProjectileManager
	# asks per bullet per frame), both through a direct call.
	var loaded_cells := manager.loaded_chunk_count() * int(manager.call("_cells_per_chunk")) * int(manager.call("_cells_per_chunk"))
	var near_cells := (manager.get("_near_blockers") as Dictionary).size()
	print("ProjectileWallDdaEquivalenceTest: %d of %d loaded cells lie within one cell of a blocker" % [near_cells, loaded_cells])
	var segments: Array = []
	for i in range(4000):
		var from_pos := Vector2(_rng.randf_range(-900.0, 900.0), _rng.randf_range(-900.0, 900.0))
		segments.append([from_pos, from_pos + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(10.0, 25.0), 4.0])
	var reference := ReferenceDda.new()
	reference.manager = manager
	var started := Time.get_ticks_usec()
	for segment in segments:
		reference.hit_t(segment[0], segment[1], segment[2])
	var old_usec := float(Time.get_ticks_usec() - started) / float(segments.size())
	started = Time.get_ticks_usec()
	for segment in segments:
		manager.projectile_hit_t(segment[0], segment[1], segment[2])
	var new_usec := float(Time.get_ticks_usec() - started) / float(segments.size())
	print("ProjectileWallDdaEquivalenceTest: per-frame bullet wall test %.2f us (every cell) vs %.2f us (near-blocker cells only)" % [old_usec, new_usec])
	_check(new_usec < old_usec, "skipping blocker-free cells is cheaper")
	manager.queue_free()
	await get_tree().process_frame
	print("ProjectileWallDdaEquivalenceTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
