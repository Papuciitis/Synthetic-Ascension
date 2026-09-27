extends Object
# Auto-extracted from ChunkGenImpl.gd to keep the generator modular.
# Do not keep state here; use the passed `gen` (ChunkGenImpl) as context.

const LOOT_SPAWNER_SCENE: PackedScene = preload("res://scenes/world/pickups/ExplorationLootSpawner.tscn")
const INDOOR_VOLUME_SCENE: PackedScene = preload("res://scenes/world/volumes/IndoorVolume.tscn")

static func _spawn_building(gen: ChunkGenImpl, chunk: Node2D, rng: RandomNumberGenerator) -> void:
	var cells_per_chunk: int = gen._cells_per_chunk()

	# Slightly larger, more "room-like" footprints
	var w: int = rng.randi_range(10, 16)
	var h: int = rng.randi_range(8, 14)

	var min_x: int = gen.padding_cells
	var min_y: int = gen.padding_cells
	var max_x: int = cells_per_chunk - gen.padding_cells - w
	var max_y: int = cells_per_chunk - gen.padding_cells - h
	if max_x <= min_x or max_y <= min_y:
		return

	var x0: int = rng.randi_range(min_x, max_x)
	var y0: int = rng.randi_range(min_y, max_y)

	# Door placement
	var side: int = rng.randi_range(0, 3) # 0=N 1=E 2=S 3=W
	var door_span: int = 2
	var door_offset: int

	if side == 0 or side == 2:
		door_offset = rng.randi_range(2, maxi(2, w - door_span - 2))
	else:
		door_offset = rng.randi_range(2, maxi(2, h - door_span - 2))

	# Non-block city pass (2026-09-27): the footprint is a notched mass, not
	# the base rectangle; its boundary is the wall ring, its inside the floor.
	# The RNG draws for the footprint happen after the door roll so the old
	# layout choices above keep their sequence.
	var base_rect := Rect2i(Vector2i(x0, y0), Vector2i(w, h))
	var footprint: Dictionary = ChunkShapeGen.generate_building_footprint(rng, base_rect) if gen.organic_shapes_enabled else ChunkShapeGen.rect_cells(base_rect)
	var wall_cells: Dictionary = ChunkShapeGen.boundary_from_fill(footprint)
	var floor_cells: Dictionary = footprint.duplicate()
	ChunkShapeGen.erase_cells(floor_cells, wall_cells)
	var interior: Rect2i = ChunkShapeGen.largest_inscribed_rect(floor_cells)
	if interior.size.x <= 0 or interior.size.y <= 0:
		return

	# --- readable indoors: floor + threshold ---
	gen._stamp_floor_cells(chunk, floor_cells, 3, rng, 0.96, -94)

	# The door: a run of `door_span` boundary cells on the chosen side whose
	# outside is open and whose inside is floor, nearest the rolled offset.
	var outward: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][side]
	var along := Vector2i(1, 0) if (side == 0 or side == 2) else Vector2i(0, 1)
	var door_cells: Array[Vector2i] = []
	var best_dist := 1 << 30
	for key in wall_cells.keys():
		var c: Vector2i = key
		if footprint.has(c + outward) or not floor_cells.has(c - outward):
			continue
		var ok := true
		for i in range(1, door_span):
			var d := c + along * i
			if not wall_cells.has(d) or footprint.has(d + outward) or not floor_cells.has(d - outward):
				ok = false
				break
		if not ok:
			continue
		var pos_along: int = (c.x - x0) if along.x != 0 else (c.y - y0)
		var dist := absi(pos_along - door_offset)
		if dist < best_dist:
			best_dist = dist
			door_cells.clear()
			for i in range(door_span):
				door_cells.append(c + along * i)
	for d in door_cells:
		wall_cells.erase(d)

	# Door apron (outside) so entrances read from a distance
	var apron_len := 2
	if not door_cells.is_empty():
		var apron_cells: Dictionary = {}
		for d in door_cells:
			for step in range(1, apron_len + 1):
				apron_cells[d + outward * step] = true
			apron_cells[d - along + outward] = true
			apron_cells[d + along * door_span + outward] = true
		ChunkShapeGen.erase_cells(apron_cells, footprint)
		var chunk_rect := Rect2i(Vector2i(0, 0), Vector2i(cells_per_chunk, cells_per_chunk))
		for key in apron_cells.keys():
			if not chunk_rect.has_point(key):
				apron_cells.erase(key)
		gen._stamp_floor_cells(chunk, apron_cells, 4, rng, 0.92, -93)

	# --- perimeter walls (windows only on straight runs) ---
	var window_cells: Dictionary = {}
	for c in wall_cells.keys():
		var cell := c as Vector2i
		var mask: int = gen._wall_connections_mask(cell, wall_cells)
		if (mask == 5 or mask == 10) and rng.randf() < 0.12:
			window_cells[cell] = true
	gen._spawn_wall_cells(chunk, wall_cells, window_cells)

	# Indoor volume for generic buildings (enables indoor detection + spawn-on-enter exploration loot).
	if INDOOR_VOLUME_SCENE != null and gen.cm != null and is_instance_valid(gen.cm):
		var vol := INDOOR_VOLUME_SCENE.instantiate() as Area2D
		if vol != null:
			chunk.add_child(vol)
			# Global cell top-left of the interior rect
			var tl_world := chunk.global_position + Vector2(float(interior.position.x), float(interior.position.y)) * float(gen.cell_size_px)
			var cell_tl: Vector2i = gen.cm.world_to_cell(tl_world)
			# Stable id derived from world seed + tl cell
			var lid: int = gen._mix_seed_int(int(gen.cm.world_seed), cell_tl.x)
			lid = gen._mix_seed_int(lid, cell_tl.y)
			lid = gen._mix_seed_int(lid, 7717)
			lid = int(lid & 0x7fffffff) + 1
			if vol.has_method("configure"):
				vol.call("configure", cell_tl, interior.size, int(gen.cell_size_px), lid)


	# Exploration loot (structure buildings): low chance, but makes "random buildings" worth checking.
	if false and LOOT_SPAWNER_SCENE != null and rng.randf() < 0.18:
		var sp := LOOT_SPAWNER_SCENE.instantiate() as Node2D
		if sp != null:
			chunk.add_child(sp)
			# building center in world space (chunk is positioned at world origin of its cell grid)
			var cx := float(x0) + float(w) * 0.5
			var cy := float(y0) + float(h) * 0.5
			sp.global_position = chunk.global_position + Vector2(cx, cy) * float(gen.cell_size_px)

			# stable loot id derived from world seed + position
			var ws: int = int(gen.cm.world_seed) if gen.cm != null and gen.cm.has_method("get") and gen.cm.get("world_seed") != null else 1337
			var base := gen._mix_seed_int(ws, int(sp.global_position.x))
			base = gen._mix_seed_int(base, int(sp.global_position.y))
			var lid := gen._mix_seed_int(base, 909) + 1
			sp.set("loot_id", lid)
			sp.set("spawn_chance", 1.0)
			sp.set("count_min", 1)
			sp.set("count_max", 1)
			sp.set("rarity_min", 3)
			sp.set("rarity_max", 6)
			sp.set("scatter_radius", 22.0)
			sp.set("pickup_delay", 0.15)


	# --- interior structure (Donjon micro-carve) inside the largest open
	# rectangle of the footprint, entered from the door when it opens there.
	var door_inside: Vector2i = (door_cells[0] - outward) if not door_cells.is_empty() else Vector2i(-1, -1)
	var carve_rect: Rect2i = interior
	if interior.size.x >= 10 and interior.size.y >= 10 and rng.randf() < 0.90:
		var entrances: Array[Dictionary] = []
		if carve_rect.has_point(door_inside):
			entrances.append({"pos": door_inside, "dir": -outward, "width": door_span})

		var carve_rng := RandomNumberGenerator.new()
		carve_rng.seed = rng.randi() ^ 0x51A1BEEF

		var carve: DonjonCarver.CarveResult = DonjonCarver.carve_region(
			carve_rect,
			carve_rng,
			0.42,
			1,
			14,
			Vector2i(4, 4),
			Vector2i(7, 6),
			1,
			2,
			0.08,
			entrances,
			3,
			2
		)

		for s in carve.floor_stamps:
			gen._stamp_floor_rect_cells(chunk, s["rect"], int(s["tex"]), carve_rng, float(s["alpha"]), int(s["z"]))
		# Trim tiny wall spurs to avoid "confetti"
		gen._trim_wall_spurs(carve.wall_cells, 2)
		for k in carve.window_cells.keys():
			if not carve.wall_cells.has(k):
				carve.window_cells.erase(k)

		gen._spawn_wall_cells(chunk, carve.wall_cells, carve.window_cells)

		# A few cover props inside
		var placed := 0
		for p in carve.half_cover_cells:
			if placed >= 4:
				break
			gen._spawn_block(chunk, gen.cover_half_scene, p.x, p.y)
			placed += 1
	else:
		# Light interior props (fallback), only on open floor
		var props: int = rng.randi_range(1, 3)
		for i in range(props):
			var px: int = rng.randi_range(interior.position.x, interior.end.x - 1)
			var py: int = rng.randi_range(interior.position.y, interior.end.y - 1)
			if floor_cells.has(Vector2i(px, py)):
				gen._spawn_block(chunk, gen.cover_half_scene, px, py)

	# Indoor volume for vignette/indoor detection (one per building)
	var b_id: int = int((gen._seed_for_chunk(gen._gen_coord) ^ (x0 << 16) ^ y0) & 0x7fffffff)
	gen._spawn_indoor_volume_local_rect(chunk, interior.position, interior.size, b_id)


static func _spawn_ruins(gen: ChunkGenImpl, chunk: Node2D, rng: RandomNumberGenerator) -> void:
	var cells_per_chunk: int = gen._cells_per_chunk()
	var _chunk_rect := Rect2i(Vector2i(0, 0), Vector2i(cells_per_chunk, cells_per_chunk))

	var wall_cells: Dictionary = {}
	var window_cells: Dictionary = {}

	# Coherent ruin clusters (no random wall speckles).
	var clusters: int = rng.randi_range(1, 3)
	for _i in range(clusters):
		var style := rng.randi_range(0, 2) # 0=broken_rect 1=courtyard 2=alley
		var w := rng.randi_range(8, 16)
		var h := rng.randi_range(7, 14)
		var x0 := rng.randi_range(gen.padding_cells, maxi(gen.padding_cells, cells_per_chunk - gen.padding_cells - w))
		var y0 := rng.randi_range(gen.padding_cells, maxi(gen.padding_cells, cells_per_chunk - gen.padding_cells - h))


		if style == 2:
			# Alley: two parallel walls, but broken + end-capped so it reads like ruins, not fence lines.
			var seg_len := rng.randi_range(8, 14)
			var gap := rng.randi_range(3, 5)
			var horiz := rng.randf() < 0.5
			var breaks := rng.randi_range(1, 2)

			if horiz:
				var ay := rng.randi_range(gen.padding_cells, cells_per_chunk - gen.padding_cells - gap - 2)
				var ax := rng.randi_range(gen.padding_cells, maxi(gen.padding_cells, cells_per_chunk - gen.padding_cells - seg_len))
				for x in range(ax, ax + seg_len):
					# internal breaks
					if breaks > 0 and rng.randf() < 0.12:
						breaks -= 1
						continue
					wall_cells[Vector2i(x, ay)] = true
					wall_cells[Vector2i(x, ay + gap)] = true

				# end caps (partial)
				if rng.randf() < 0.75:
					for j in range(1, rng.randi_range(2, 4)):
						wall_cells[Vector2i(ax, ay + j)] = true
						wall_cells[Vector2i(ax + seg_len - 1, ay + gap - j)] = true

				# occasional return so it reads like a broken L-shape, not a fence
				if rng.randf() < 0.35 and seg_len >= 8:
					var rx := ax + rng.randi_range(2, seg_len - 3)
					for j in range(1, rng.randi_range(2, 4)):
						wall_cells[Vector2i(rx, ay + j)] = true
			else:
				var ax := rng.randi_range(gen.padding_cells, cells_per_chunk - gen.padding_cells - gap - 2)
				var ay := rng.randi_range(gen.padding_cells, maxi(gen.padding_cells, cells_per_chunk - gen.padding_cells - seg_len))
				for y in range(ay, ay + seg_len):
					if breaks > 0 and rng.randf() < 0.12:
						breaks -= 1
						continue
					wall_cells[Vector2i(ax, y)] = true
					wall_cells[Vector2i(ax + gap, y)] = true

				if rng.randf() < 0.75:
					for j in range(1, rng.randi_range(2, 4)):
						wall_cells[Vector2i(ax + j, ay)] = true
						wall_cells[Vector2i(ax + gap - j, ay + seg_len - 1)] = true

				if rng.randf() < 0.35 and seg_len >= 8:
					var ry := ay + rng.randi_range(2, seg_len - 3)
					for j in range(1, rng.randi_range(2, 4)):
						wall_cells[Vector2i(ax + j, ry)] = true
		else:
			# Broken rectangle / courtyard
			var open_side := -1
			if style == 1 and rng.randf() < 0.75:
				open_side = rng.randi_range(0, 3)
			var break_ch := 0.18
			for x in range(x0, x0 + w):
				var top := Vector2i(x, y0)
				var bot := Vector2i(x, y0 + h - 1)
				if open_side != 0 and (x == x0 or x == x0 + w - 1 or rng.randf() > break_ch):
					wall_cells[top] = true
				if open_side != 2 and (x == x0 or x == x0 + w - 1 or rng.randf() > break_ch):
					wall_cells[bot] = true
			for y in range(y0, y0 + h):
				var left := Vector2i(x0, y)
				var right := Vector2i(x0 + w - 1, y)
				if open_side != 3 and (y == y0 or y == y0 + h - 1 or rng.randf() > break_ch):
					wall_cells[left] = true
				if open_side != 1 and (y == y0 or y == y0 + h - 1 or rng.randf() > break_ch):
					wall_cells[right] = true

			# A partial interior spine for readability
			if rng.randf() < 0.35:
				if rng.randf() < 0.5:
					var sy := rng.randi_range(y0 + 2, y0 + h - 3)
					for x in range(x0 + 2, x0 + w - 2):
						if rng.randf() > 0.25:
							wall_cells[Vector2i(x, sy)] = true
				else:
					var sx := rng.randi_range(x0 + 2, x0 + w - 3)
					for y in range(y0 + 2, y0 + h - 2):
						if rng.randf() > 0.25:
							wall_cells[Vector2i(sx, y)] = true

	# Cleanup pass: remove tiny isolated components + trim spurs (kills wall confetti)
	gen._prune_small_wall_components(wall_cells, 10)
	gen._trim_wall_spurs(wall_cells, 2)

	# Windows only on straight segments (rare)
	for c in wall_cells.keys():
		var cell := c as Vector2i
		var mask: int = gen._wall_connections_mask(cell, wall_cells)
		var is_straight: bool = (mask == 5 or mask == 10)
		if is_straight and rng.randf() < 0.08:
			window_cells[cell] = true

	# Ensure windows still exist after pruning
	for c in window_cells.keys():
		if not wall_cells.has(c):
			window_cells.erase(c)

	gen._spawn_wall_cells(chunk, wall_cells, window_cells)
