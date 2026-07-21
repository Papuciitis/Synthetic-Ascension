extends Object
# Auto-extracted from ChunkGenImpl.gd to keep the generator modular.
# Do not keep state here; use the passed `gen` (ChunkGenImpl) as context.

static func _prune_small_wall_components(_gen: ChunkGenImpl, wall_cells: Dictionary, min_size: int) -> void:
	if wall_cells.is_empty() or min_size <= 1:
		return
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var visited: Dictionary = {}
	var keys: Array = wall_cells.keys()
	for k in keys:
		var start: Vector2i = k as Vector2i
		if visited.has(start) or not wall_cells.has(start):
			continue
		var q: Array[Vector2i] = [start]
		visited[start] = true
		var comp: Array[Vector2i] = []
		while not q.is_empty():
			var p: Vector2i = q.pop_back() as Vector2i
			comp.append(p)
			for d in dirs:
				var n: Vector2i = p + d
				if wall_cells.has(n) and not visited.has(n):
					visited[n] = true
					q.append(n)
		if comp.size() < min_size:
			for p in comp:
				wall_cells.erase(p)



static func _trim_wall_spurs(_gen: ChunkGenImpl, wall_cells: Dictionary, iterations: int) -> void:
	if wall_cells.is_empty() or iterations <= 0:
		return
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for _i in range(iterations):
		var to_remove: Array[Vector2i] = []
		for k in wall_cells.keys():
			var p: Vector2i = k
			var n := 0
			for d in dirs:
				if wall_cells.has(p + d):
					n += 1
			if n <= 1:
				to_remove.append(p)
		for p in to_remove:
			wall_cells.erase(p)



static func _spawn_wall_rect_cells(gen: ChunkGenImpl, 
	chunk: Node2D,
	x0: int, y0: int, w: int, h: int,
	door_side: int, door_offset: int, door_span: int,
	rng: RandomNumberGenerator
) -> void:
	# Build a set of perimeter wall cells (no duplicates), then choose window cells
	var wall_cells: Dictionary = {}    # Vector2i -> true
	var window_cells: Dictionary = {}  # Vector2i -> true

	# Top (side 0)
	for i in range(w):
		if door_side == 0 and i >= door_offset and i < door_offset + door_span:
			continue
		wall_cells[Vector2i(x0 + i, y0)] = true

	# Bottom (side 2)
	for i in range(w):
		if door_side == 2 and i >= door_offset and i < door_offset + door_span:
			continue
		wall_cells[Vector2i(x0 + i, y0 + h - 1)] = true

	# Left (side 3)
	for i in range(h):
		if door_side == 3 and i >= door_offset and i < door_offset + door_span:
			continue
		wall_cells[Vector2i(x0, y0 + i)] = true

	# Right (side 1)
	for i in range(h):
		if door_side == 1 and i >= door_offset and i < door_offset + door_span:
			continue
		wall_cells[Vector2i(x0 + w - 1, y0 + i)] = true

	# Choose windows only on straight segments
	for c in wall_cells.keys():
		var cell := c as Vector2i
		var mask: int = gen._wall_connections_mask(cell, wall_cells)
		var is_straight: bool = (mask == 5 or mask == 10) # N|S or E|W
		if is_straight and rng.randf() < 0.12:
			window_cells[cell] = true

	gen._spawn_wall_cells(chunk, wall_cells, window_cells)


static func _wall_connections_mask(_gen: ChunkGenImpl, cell: Vector2i, wall_cells: Dictionary) -> int:
	# Connection bitmask: N=1, E=2, S=4, W=8
	var mask: int = 0
	if wall_cells.has(cell + Vector2i(0, -1)): mask |= 1
	if wall_cells.has(cell + Vector2i(1, 0)):  mask |= 2
	if wall_cells.has(cell + Vector2i(0, 1)):  mask |= 4
	if wall_cells.has(cell + Vector2i(-1, 0)): mask |= 8
	return mask


static func _spawn_wall_cells(gen: ChunkGenImpl, chunk: Node2D, wall_cells: Dictionary, window_cells: Dictionary) -> void:
	for c in wall_cells.keys():
		var cell := c as Vector2i
		var mask: int = gen._wall_connections_mask(cell, wall_cells)

		var use_window: bool = window_cells.has(cell)
		var scene: PackedScene = (gen.cover_window_scene if use_window else gen.cover_full_scene)

		var b := gen._spawn_block(chunk, scene, cell.x, cell.y)
		if b != null:
			# CoverWall.gd expects this; harmless for other cover scenes.
			b.set("connections_mask", mask)
			if b.has_method("_apply"):
				b.call("_apply")


static func _spawn_wall_line(gen: ChunkGenImpl, 
	chunk: Node2D,
	x0: int, y0: int, w: int, h: int,
	has_door: bool, door_offset: int, door_span: int,
	rng: RandomNumberGenerator
) -> void:
	# Legacy helper (kept for experimentation). Spawns a simple line without corners/Ts.
	var is_horizontal: bool = (w > h)
	var length: int = (w if is_horizontal else h)

	for i in range(length):
		if has_door and i >= door_offset and i < door_offset + door_span:
			continue

		var cx: int = x0 + (i if is_horizontal else 0)
		var cy: int = y0 + (0 if is_horizontal else i)

		var use_window: bool = (rng.randf() < 0.12)
		var scene: PackedScene = (gen.cover_window_scene if use_window else gen.cover_full_scene)

		var b := gen._spawn_block(chunk, scene, cx, cy)
		if b != null:
			# Straight line connections only
			b.set("connections_mask", (10 if is_horizontal else 5))
