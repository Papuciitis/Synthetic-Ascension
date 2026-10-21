extends Node

const CITY_KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var invalid := 0
	var crowded := 0
	var total := 0
	for seed_value in range(12):
		var manager := ChunkManager.new()
		manager._gen_coord = Vector2i.ZERO
		manager.tiled_world_rendering = false
		var chunk := Node2D.new()
		manager.add_child(chunk)
		var indoor := IndoorVolume.new()
		indoor.cell_tl = Vector2i(8, 8)
		indoor.size_cells = Vector2i(12, 12)
		chunk.add_child(indoor)
		var interior := Rect2i(indoor.cell_tl, indoor.size_cells)
		var clear := ChunkShapeGen.rect_cells(Rect2i(Vector2i(20, 3), Vector2i(5, 26)))
		chunk.set_meta(&"_proc_clear_cells", clear)
		for y in range(3, 29): manager._blocked_cells[Vector2i(3, y)] = true
		# A dressed city frontage: its garden/street groups reserve their wall
		# foot so wild scatter keeps the doorstep row in front of them clear.
		var kit := CITY_KIT.new()
		chunk.add_child(kit)
		kit.configure(Rect2i(21, 21, 9, 7), 64, [{"pos": Vector2i(25, 27), "dir": Vector2i.DOWN, "width": 2}], null, true, PackedVector2Array(), true, {"building_usage": &"workshop", "visual_seed": 9001 + seed_value, "family_id": &"service_courtyards"})
		var dressed: Dictionary = chunk.get_meta(&"_proc_deco_clear_cells", {}).duplicate()
		if dressed.is_empty(): failures.append("dressed frontage reserves its wall foot from wild scatter at seed %d" % seed_value)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		manager._scatter_vegetation(chunk, rng, 32, 20)
		var placements: Array = chunk.get_meta(&"_foliage_placements", [])
		if placements.is_empty():
			for child in chunk.get_children():
				if child is Sprite2D and String(child.name).begins_with("Veg_"):
					placements.append({"cell": Vector2i(child.position / 64.0)})
		for placement in placements:
			var cell: Vector2i = placement.cell
			if interior.has_point(cell) or clear.has(cell) or manager._blocked_cells.has(cell): invalid += 1
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if dressed.has(cell + Vector2i(ox, oy)): crowded += 1
		var repeat_rng := RandomNumberGenerator.new()
		repeat_rng.seed = seed_value
		var repeated: Array = manager._DECO_PLANNER.plan_vegetation(manager, chunk, repeat_rng, 32, 20)
		if repeated != placements: failures.append("foliage plan differs at seed %d" % seed_value)
		var batches := chunk.get_node_or_null("FoliageBatches")
		if batches == null or batches.get_child_count() > 6: failures.append("foliage must use at most three texture batches and three shadows")
		var instances := 0
		if batches != null:
			for batch in batches.get_children():
				if batch is MultiMeshInstance2D: instances += batch.multimesh.instance_count
		if instances != placements.size() * 2: failures.append("every plant has one batched visual and shadow")
		total += placements.size()
		manager.free()
	_check_built_paving()
	if invalid > 0: failures.append("foliage obscures %d reserved lane/interior cells" % invalid)
	if crowded > 0: failures.append("wild foliage crowds %d tended garden/street dressing cells" % crowded)
	if total < 12 * 10: failures.append("sufficient exterior foliage: got %d placements" % total)
	for failure in failures: push_error(failure)
	print("WorldFoliagePlacementTest: %d placements, %d invalid, %d crowding dressing, %d failures" % [total, invalid, crowded, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)


## In a district drawn by a ground policy, wild scatter stays off the built
## paving (roads, lanes, footways, the district surface) but keeps lawn, bare
## earth and planted beds; the plan itself is untouched.
func _check_built_paving() -> void:
	var manager := ChunkManager.new()
	manager._gen_coord = Vector2i(3, 2)
	manager.tiled_world_rendering = false
	manager.ground_splat_enabled = true
	manager.district_family = &"service_courtyards"
	manager._chunk_terrain[Vector2i(3, 2)] = &"urban"
	var chunk := Node2D.new()
	manager.add_child(chunk)
	var data := ChunkBuildData.new(Vector2i(3, 2), 32)
	data.add_floor_stamp(Rect2i(0, 0, 32, 10), 7, 1.0, -95)
	data.add_floor_stamp(Rect2i(0, 10, 16, 22), 0, 1.0, -95)
	data.add_floor_stamp(Rect2i(4, 12, 4, 4), 2, 1.0, -94)
	data.add_floor_stamp(Rect2i(10, 12, 4, 4), 7, 0.2, -93)
	chunk.set_meta(&"_chunk_build_data", data)
	chunk.set_meta(&"_ground_planting_rects", [Rect2i(20, 20, 3, 3)])
	var plan: Array[Dictionary] = []
	for cell: Vector2i in [Vector2i(5, 5), Vector2i(5, 13), Vector2i(2, 20), Vector2i(11, 13), Vector2i(24, 14), Vector2i(21, 21)]:
		plan.append({"cell": cell, "species": 0, "scale": 1.0, "alpha": 0.8, "turns": 0})
	var kept: Array[Dictionary] = manager._DECO_PLANNER.off_built_paving(manager, chunk, plan)
	var cells: Array[Vector2i] = []
	for placement: Dictionary in kept: cells.append(placement.cell)
	if cells != [Vector2i(2, 20), Vector2i(11, 13), Vector2i(21, 21)]:
		failures.append("built paving drops road, footway and district-surface plants but keeps lawn, a stained lawn and a planted bed: got %s" % str(cells))
	if plan.size() != 6: failures.append("filtering never edits the plan")
	manager.district_family = &""
	if manager._DECO_PLANNER.off_built_paving(manager, chunk, plan).size() != plan.size():
		failures.append("worlds without a district ground policy keep every plant")
	manager.free()

