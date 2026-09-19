extends Node

# Cold-chunk streaming phase profile (performance war room, 2026-09-19).
# Streams a fresh seed the way a walking player does: the centre steps one
# chunk east ten times, every step plans and activates the missing chunks
# through the real queue, and every activation's per-phase cost (setup,
# ground + decals, content, floor stamps, blockers + tiling) is collected.
# Prints per-phase percentiles, how many activations exceed the 2 ms
# activation budget and the 16.7 ms frame, and the five worst chunks with
# their phase split, so the staging work knows which phase to defer.
#
# Read-only: no gameplay change; the manager is configured like
# ChunkStreamingPerformanceAudit with sites, decals and deco on.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/ChunkColdStreamProbe.tscn
# Env: PROBE_SEED (902611), PROBE_STEPS (10), PROBE_RADIUS (2)

const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
const PHASES: Array[String] = ["setup_ms", "ground_ms", "content_ms", "floor_ms", "blocker_ms", "total_ms"]

var _samples: Dictionary = {}  # coord string -> phase dict


func _ready() -> void:
	call_deferred(&"_run")


func _env_int(key: String, fallback: int) -> int:
	var value := OS.get_environment(key).strip_edges()
	return int(value) if value.is_valid_int() else fallback


func _configured_manager(seed_value: int, radius: int) -> ChunkManager:
	var manager := ChunkManager.new()
	manager.world_seed = seed_value
	manager.load_radius = radius
	manager.unload_radius = radius + 1
	manager.use_camera_stream_bounds = false
	manager.stream_activation_budget_ms = 2.0
	manager.max_chunk_generations_per_frame = 4
	manager.batched_chunk_blockers = true
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


func _collect(manager: ChunkManager) -> void:
	var stats := manager.get_chunk_stream_debug_stats()
	for sample in stats.get("build_phase_samples", []):
		if sample is Dictionary:
			_samples[String((sample as Dictionary).get("coord", "?"))] = (sample as Dictionary).duplicate()


func _pct(values: Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[clampi(int(ceil(p * sorted.size())) - 1, 0, sorted.size() - 1)])


func _run() -> void:
	var seed_value := _env_int("PROBE_SEED", 902611)
	var steps := _env_int("PROBE_STEPS", 10)
	var radius := _env_int("PROBE_RADIUS", 2)
	var manager := _configured_manager(seed_value, radius)
	manager.start_streaming(Vector2.ZERO)
	manager.process_chunk_generation_queue(100)
	await get_tree().process_frame
	_collect(manager)
	var initial := _samples.size()
	var initial_coords: Dictionary = {}
	for key in _samples:
		initial_coords[key] = true
	for step in range(steps):
		manager.set("_current_center", (manager.get("_current_center") as Vector2i) + Vector2i(1, 0))
		manager.call("_update_streaming")
		# Activate every queued chunk this step, like a frame with no budget
		# left would not: the point is the per-activation cost, not pacing.
		manager.process_chunk_generation_queue(100)
		await get_tree().process_frame
		_collect(manager)
	var rows: Array = _samples.values()
	print("ChunkColdStreamProbe: seed %d, radius %d, %d steps east, %d activations (%d initial + %d streamed)" % [seed_value, radius, steps, rows.size(), initial, rows.size() - initial])
	print("| phase | p50 ms | p95 ms | max ms | share of total |")
	print("|---|---:|---:|---:|---:|")
	var total_sum := 0.0
	for r in rows:
		total_sum += float(r.get("total_ms", 0.0))
	for phase in PHASES:
		var values: Array = []
		var phase_sum := 0.0
		for r in rows:
			values.append(float(r.get(phase, 0.0)))
			phase_sum += float(r.get(phase, 0.0))
		print("| %s | %.2f | %.2f | %.2f | %.0f%% |" % [phase.trim_suffix("_ms"), _pct(values, 0.5), _pct(values, 0.95), _pct(values, 1.0), (phase_sum / total_sum * 100.0) if total_sum > 0.0 and phase != "total_ms" else 100.0])
	var over_budget := 0
	var over_frame := 0
	for r in rows:
		if float(r.get("total_ms", 0.0)) > 2.0:
			over_budget += 1
		if float(r.get("total_ms", 0.0)) > 16.7:
			over_frame += 1
	print("activations over the 2 ms budget: %d of %d; over 16.7 ms: %d" % [over_budget, rows.size(), over_frame])
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("total_ms", 0.0)) > float(b.get("total_ms", 0.0)))
	print("worst chunks (total: setup / ground / content / floor / blocker):")
	for i in range(mini(5, rows.size())):
		var r: Dictionary = rows[i]
		var coord_key := String(r.get("coord", "?"))
		print("  %s%s %.2f ms: %.2f / %.2f / %.2f / %.2f / %.2f" % [coord_key, " (initial)" if initial_coords.has(coord_key) else "", float(r.get("total_ms", 0.0)), float(r.get("setup_ms", 0.0)), float(r.get("ground_ms", 0.0)), float(r.get("content_ms", 0.0)), float(r.get("floor_ms", 0.0)), float(r.get("blocker_ms", 0.0))])
	print("passes=1 failures=0")
	get_tree().quit(0)
