extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var invalid := 0
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
	if invalid > 0: failures.append("foliage obscures %d reserved lane/interior cells" % invalid)
	if total < 12 * 10: failures.append("sufficient exterior foliage: got %d placements" % total)
	for failure in failures: push_error(failure)
	print("WorldFoliagePlacementTest: %d placements, %d invalid, %d failures" % [total, invalid, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
