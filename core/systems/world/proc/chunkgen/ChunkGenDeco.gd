extends Object
# Auto-extracted from ChunkGenImpl.gd to keep the generator modular.
# Do not keep state here; use the passed `gen` (ChunkGenImpl) as context.

static func _add_environment_deco(gen: ChunkGenImpl, chunk: Node2D, rng: RandomNumberGenerator, archetype: StringName, conn_mask: int) -> void:
	if gen.cm != null:
		gen.cm._add_environment_deco(chunk, rng, archetype, conn_mask)


## A bounded, deterministic dressing plan. Street cores, indoor volumes and
## door aprons stay readable; most clumps hug a wall or a paving edge.
static func plan_vegetation(cm: ChunkManager, chunk: Node2D, rng: RandomNumberGenerator, cells: int, budget: int) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if budget <= 0:
		return placements
	var reserved: Dictionary = (chunk.get_meta(&"_proc_clear_cells", {}) as Dictionary).duplicate()
	ChunkShapeGen.add_cells(reserved, chunk.get_meta(&"_proc_deco_clear_cells", {}))
	var interiors: Dictionary = {}
	for child in chunk.get_children():
		if child is IndoorVolume:
			var volume := child as IndoorVolume
			ChunkShapeGen.add_cells(interiors, ChunkShapeGen.rect_cells(Rect2i(volume.cell_tl - cm._gen_coord * cells, volume.size_cells)))
		elif child is Marker2D and child.get_meta(&"spawn_socket_kind", &"") == &"door":
			var door := Vector2i((child as Node2D).position / float(cm.cell_size_px))
			ChunkShapeGen.add_cells(reserved, ChunkShapeGen.rect_cells(Rect2i(door - Vector2i.ONE, Vector2i(3, 3))))
	var available: Dictionary = {}
	var preferred: Array[Vector2i] = []
	var candidates: Array[Vector2i] = []
	for y in range(cm.padding_cells, cells - cm.padding_cells):
		for x in range(cm.padding_cells, cells - cm.padding_cells):
			var cell := Vector2i(x, y)
			if not cm._is_free_cell_local(cell, cells) or interiors.has(cell):
				continue
			# One cell of margin keeps the larger sprites off combat lanes.
			var clear := true
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if reserved.has(cell + Vector2i(ox, oy)): clear = false
			if not clear:
				continue
			available[cell] = true
			candidates.append(cell)
			var edge := false
			for dir in ChunkShapeGen.DIRS_4:
				var global_neighbour := cm._gen_coord * cells + cell + dir
				if cm._blocked_cells.has(global_neighbour) or reserved.has(cell + dir * 2): edge = true
			if edge: preferred.append(cell)
	if candidates.is_empty():
		return placements
	var occupied: Dictionary = {}
	for _clump in range(32):
		if placements.size() >= budget:
			break
		var source: Array[Vector2i] = preferred if not preferred.is_empty() and rng.randf() < 0.8 else candidates
		var centre := source[rng.randi_range(0, source.size() - 1)]
		if occupied.has(centre):
			continue
		var species := rng.randi_range(0, 1)
		# Taller accents stay sparse; a tree is one object, never a six-tree pile.
		var taller := rng.randf() < 0.22
		if taller: species = posmod(rng.randi_range(2, 4), 3)
		var want := 1 if taller else mini(rng.randi_range(cm.veg_clump_min, cm.veg_clump_max), budget - placements.size())
		for member in range(want):
			var cell := centre
			if member > 0:
				var radius := cm.veg_clump_radius_cells
				cell += Vector2i(rng.randi_range(-radius, radius), rng.randi_range(-radius, radius))
			if not available.has(cell) or occupied.has(cell):
				continue
			occupied[cell] = true
			var scale_value := rng.randf_range(1.4, 1.9) if taller else rng.randf_range(0.65, 1.05)
			if species == 2: scale_value *= 1.25
			placements.append({
				"cell": cell,
				"species": species,
				"scale": scale_value,
				"alpha": rng.randf_range(0.68, 0.92),
				"turns": 0 if taller else rng.randi_range(0, 3),
			})
	return placements
