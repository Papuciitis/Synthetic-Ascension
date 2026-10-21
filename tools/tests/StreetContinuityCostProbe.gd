extends Node
## Street continuity cost probe (2026-10-21). For one production plan of every
## district theme it builds every planned chunk through ChunkManager._create_chunk
## (ground, decals, deco, content, floors, blockers) with the street continuity
## pass off, then on, and reports per-chunk build phases, building counts and
## node counts. Read-only: prints one JSON line per theme plus totals.
## Run: --headless res://tools/tests/StreetContinuityCostProbe.tscn [-- --out=/abs/path.json]

const THEMES := [[2, ""], [3, ""], [4, "collapsed_ward"], [4, "civilian_cutthrough"], [5, ""],
	[6, "industrial_cutthrough"], [6, "ruined_services"], [7, "underpass_veins"], [7, "canal_services"],
	[8, "rail_yard"], [8, "military_staging"], [9, "outer_wall"], [9, "siege_services"], [10, ""]]
const BASE_SEED := 16102026


func _ready() -> void:
	call_deferred("_run")


func _theme_seed(segment: int, theme_id: String) -> int:
	if theme_id.is_empty():
		return BASE_SEED
	for step in 400:
		if String(SegmentThemePicker.get_theme(segment, BASE_SEED + step).id) == theme_id:
			return BASE_SEED + step
	return -1


func _manager(theme: SegmentThemeData, plan: Dictionary, enabled: bool) -> ChunkManager:
	var cm := ChunkManager.new()
	theme.apply_to_chunk_manager(cm)
	cm.parcels_chunk_chance = 0.95
	cm.parcels_chance_per_side = 0.80
	cm.parcels_max_per_side = 2
	cm.district_sidewalk_width_cells = 1
	cm.district_sidewalk_corner_pad_cells = 1
	cm.debug_draw_chunk_outlines = false
	cm.debug_show_blocks = false
	cm.street_continuity_enabled = enabled
	cm.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn")
	cm.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn")
	cm.cover_half_scene = load("res://scenes/world/cover/CoverHalf.tscn")
	add_child(cm)
	cm.set_process(false)
	cm.configure_procedural_world(int(plan.seed), plan.connectors_by_chunk, plan.urban_access_by_chunk, plan.role_by_chunk, plan.terrain_by_chunk, plan.archetype_by_chunk)
	return cm


func _percentile(values: Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[clampi(int(round(fraction * float(sorted.size() - 1))), 0, sorted.size() - 1)])


func _measure(theme: SegmentThemeData, plan: Dictionary, enabled: bool) -> Dictionary:
	var cm := _manager(theme, plan, enabled)
	var coords: Array[Vector2i] = []
	for coord: Vector2i in plan.role_by_chunk:
		coords.append(coord)
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var totals: Array = []
	var contents: Array = []
	var blockers: Array = []
	var buildings := 0
	var infill := 0
	var nodes := 0
	var by_role: Dictionary = {}
	for coord: Vector2i in coords:
		var chunk := cm._create_chunk(coord)
		var sample: Dictionary = cm._phase_sample_by_coord.get(coord, {})
		totals.append(float(sample.get("total_ms", 0.0)))
		contents.append(float(sample.get("content_ms", 0.0)))
		blockers.append(float(sample.get("blocker_ms", 0.0)))
		var role := String(plan.role_by_chunk[coord])
		var role_entry: Dictionary = by_role.get(role, {"chunks": 0, "total_ms": 0.0})
		role_entry.chunks += 1
		role_entry.total_ms += float(sample.get("total_ms", 0.0))
		by_role[role] = role_entry
		for kit: Node in chunk.get_children():
			if kit.is_in_group(&"city_block_building"):
				buildings += 1
				if kit.has_meta(&"city_street_infill"): infill += 1
		nodes += chunk.find_children("*", "", true, false).size()
		cm._unregister_chunk_cells(coord)
		cm._chunk_build_data.erase(coord)
		cm._phase_sample_by_coord.erase(coord)
		chunk.free()
	cm.free()
	var sum := 0.0
	for value: float in totals: sum += value
	var role_means: Dictionary = {}
	for key: String in by_role:
		role_means[key] = snappedf(float(by_role[key].total_ms) / float(by_role[key].chunks), 0.01)
	return {
		"chunks": coords.size(), "buildings": buildings, "infill_buildings": infill, "nodes": nodes,
		"total_ms_sum": snappedf(sum, 0.01), "total_ms_median": snappedf(_percentile(totals, 0.5), 0.001),
		"total_ms_p90": snappedf(_percentile(totals, 0.9), 0.001), "total_ms_max": snappedf(_percentile(totals, 1.0), 0.001),
		"content_ms_median": snappedf(_percentile(contents, 0.5), 0.001), "content_ms_p90": snappedf(_percentile(contents, 0.9), 0.001),
		"blocker_ms_median": snappedf(_percentile(blockers, 0.5), 0.001),
		"by_role_mean_ms": role_means,
	}


func _run() -> void:
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	var previous_segment: int = Global.attempt_segment
	var results: Array = []
	# Warm shared resources once so the first theme does not pay first-touch loads.
	var warm_theme := SegmentThemePicker.get_theme(2, BASE_SEED)
	var warm_plan := DistrictPlan.generate(2, BASE_SEED, 2048, warm_theme)
	Global.attempt_segment = 2
	_measure(warm_theme, warm_plan, true)
	for entry: Array in THEMES:
		var segment: int = entry[0]
		var seed_value := _theme_seed(segment, entry[1])
		if seed_value < 0:
			continue
		Global.attempt_segment = segment
		var theme := SegmentThemePicker.get_theme(segment, seed_value)
		var plan := DistrictPlan.generate(segment, seed_value, 2048, theme)
		var off := _measure(theme, plan, false)
		var on := _measure(theme, plan, true)
		var row := {"segment": segment, "theme": String(theme.id), "attempt_seed": seed_value, "off": off, "on": on}
		results.append(row)
		print(JSON.stringify({"segment": segment, "theme": String(theme.id), "chunks": off.chunks,
			"buildings_off": off.buildings, "buildings_on": on.buildings, "nodes_off": off.nodes, "nodes_on": on.nodes,
			"median_ms_off": off.total_ms_median, "median_ms_on": on.total_ms_median,
			"p90_ms_off": off.total_ms_p90, "p90_ms_on": on.total_ms_p90,
			"max_ms_off": off.total_ms_max, "max_ms_on": on.total_ms_max,
			"sum_ms_off": off.total_ms_sum, "sum_ms_on": on.total_ms_sum}))
	Global.attempt_segment = previous_segment
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(results, "\t"))
			file.close()
	print("StreetContinuityCostProbe: themes=%d" % results.size())
	get_tree().quit(0)
