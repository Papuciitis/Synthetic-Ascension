extends RefCounted
class_name DonjonCarver

# Simple Donjon-ish micro-carver for a rectangular sub-region of a chunk (cell grid).
# Produces: boundary wall cells + window candidates, corridor/room floor stamps, and some prop cells.
#
# Coordinates are in *chunk-local cell space* (0..cells-1), but all outputs are returned as chunk-local cells too.
#
# We deliberately return ONLY boundary walls (wall cells adjacent to open floor). This keeps node count sane.

class CarveResult:
	var wall_cells: Dictionary = {}     # Vector2i -> true
	var window_cells: Dictionary = {}   # Vector2i -> true
	var floor_stamps: Array = []        # [{ "rect": Rect2i, "tex": int, "alpha": float, "z": int }, ...]
	var half_cover_cells: Array[Vector2i] = []


static func carve_region(
	region: Rect2i,
	rng: RandomNumberGenerator,
	fill_wall_chance: float,
	ca_steps: int,
	room_attempts: int,
	room_min: Vector2i,
	room_max: Vector2i,
	room_padding: int,
	corridor_width: int,
	window_chance: float,
	entrances: Array[Dictionary], # [{ "pos": Vector2i, "dir": Vector2i, "width": int }]
	floor_tex_room: int,
	floor_tex_corr: int
) -> CarveResult:
	var res := CarveResult.new()

	if region.size.x < 8 or region.size.y < 8:
		return res

	var w: int = region.size.x
	var h: int = region.size.y
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(w * h)

	# 0 = wall, 1 = floor
	# --- init random cave ---
	for y in range(h):
		for x in range(w):
			var i := y * w + x
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				grid[i] = 0
			else:
				grid[i] = (0 if rng.randf() < fill_wall_chance else 1)

	# --- cellular automata smoothing ---
	for _s in range(maxi(0, ca_steps)):
		var next := grid.duplicate()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var walls := _count_wall_neighbors(grid, w, h, x, y)
				next[y * w + x] = (0 if walls >= 5 else 1)
		grid = next

	# --- keep largest open region ---
	_keep_largest_open(grid, w, h)

	# --- stamp rectangular rooms (force floor) ---
	var rooms: Array[Rect2i] = []
	var centers: Array[Vector2i] = []

	for _i in range(maxi(0, room_attempts)):
		var rw: int = rng.randi_range(room_min.x, room_max.x)
		var rh: int = rng.randi_range(room_min.y, room_max.y)
		if rw >= w - 2 or rh >= h - 2:
			continue

		var rx: int = rng.randi_range(1, w - rw - 2)
		var ry: int = rng.randi_range(1, h - rh - 2)
		var rect := Rect2i(Vector2i(rx, ry), Vector2i(rw, rh))

		if not _room_fits(rect, rooms, room_padding):
			continue

		_carve_rect(grid, w, rect)
		rooms.append(rect)
		centers.append(Vector2i(rect.position.x + int(float(rect.size.x) * 0.5), rect.position.y + int(float(rect.size.y) * 0.5)))

	# Stamp room floors (visual only).
	for r in rooms:
		res.floor_stamps.append({
			"rect": Rect2i(region.position + r.position, r.size),
			"tex": floor_tex_room,
			"alpha": 0.92,
			"z": -92
		})

	# --- connect graph: entrances + room centers ---
	var nodes: Array[Vector2i] = []
	for e in entrances:
		nodes.append((e["pos"] as Vector2i) - region.position)
	for c in centers:
		nodes.append(c)

	if nodes.size() >= 2:
		var edges := _mst_edges(nodes)
		# a couple extra edges for loops
		if nodes.size() >= 5 and rng.randf() < 0.35:
			edges.append([rng.randi_range(0, nodes.size() - 1), rng.randi_range(0, nodes.size() - 1)])
		for e in edges:
			var a: Vector2i = nodes[int(e[0])]
			var b: Vector2i = nodes[int(e[1])]
			_dig_corridor(grid, w, h, a, b, rng, corridor_width, res, region, floor_tex_corr)

	# Ensure entrances are carved open and wide enough.
	for e in entrances:
		var p: Vector2i = (e["pos"] as Vector2i) - region.position
		var dir: Vector2i = e["dir"] as Vector2i
		var wid: int = int(e.get("width", 2))
		_carve_entrance(grid, w, h, p, dir, wid)

	# --- boundary wall extraction ---
	_extract_boundary_walls(grid, w, h, region, rng, window_chance, res)

	# --- half cover props inside rooms/caves (keep low) ---
	var prop_budget: int = 3 if rooms.size() >= 2 else 2
	for _p in range(prop_budget):
		var pick := _pick_floor_cell(grid, w, h, rng)
		if pick.x < 0:
			break
		res.half_cover_cells.append(region.position + pick)

	return res


static func _count_wall_neighbors(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> int:
	var count := 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			var nx := x + ox
			var ny := y + oy
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				count += 1
			else:
				if grid[ny * w + nx] == 0:
					count += 1
	return count


static func _keep_largest_open(grid: PackedByteArray, w: int, h: int) -> void:
	var visited := PackedByteArray()
	visited.resize(w * h)

	var best: Array[int] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var idx := y * w + x
			if visited[idx] == 1:
				continue
			if grid[idx] != 1:
				continue
			var region := _flood(grid, visited, w, h, Vector2i(x, y))
			if region.size() > best.size():
				best = region

	var keep := PackedByteArray()
	keep.resize(w * h)
	for idx2 in best:
		keep[idx2] = 1
	for i in range(w * h):
		if keep[i] == 0:
			grid[i] = 0


static func _flood(grid: PackedByteArray, visited: PackedByteArray, w: int, h: int, start: Vector2i) -> Array[int]:
	var stack: Array[Vector2i] = [start]
	var out: Array[int] = []
	while stack.size() > 0:
		var p: Vector2i = stack.pop_back()
		if p.x <= 0 or p.y <= 0 or p.x >= w - 1 or p.y >= h - 1:
			continue
		var idx: int = p.y * w + p.x
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		if grid[idx] != 1:
			continue
		out.append(idx)
		stack.append(p + Vector2i(1,0))
		stack.append(p + Vector2i(-1,0))
		stack.append(p + Vector2i(0,1))
		stack.append(p + Vector2i(0,-1))
	return out


static func _room_fits(rect: Rect2i, rooms: Array[Rect2i], pad: int) -> bool:
	var padded := Rect2i(rect.position - Vector2i(pad, pad), rect.size + Vector2i(pad * 2, pad * 2))
	for r in rooms:
		if padded.intersects(r):
			return false
	return true


static func _carve_rect(grid: PackedByteArray, w: int, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			grid[y * w + x] = 1


static func _mst_edges(nodes: Array[Vector2i]) -> Array:
	# Prim MST over manhattan distances
	var n := nodes.size()
	var in_tree := PackedByteArray()
	in_tree.resize(n)
	in_tree[0] = 1
	var edges: Array = []
	var remaining := n - 1

	while remaining > 0:
		var best_a := -1
		var best_b := -1
		var best_d := 999999

		for a in range(n):
			if in_tree[a] == 0:
				continue
			var pa: Vector2i = nodes[a]
			for b in range(n):
				if in_tree[b] == 1:
					continue
				var pb: Vector2i = nodes[b]
				var d := absi(pa.x - pb.x) + absi(pa.y - pb.y)
				if d < best_d:
					best_d = d
					best_a = a
					best_b = b

		if best_a == -1:
			break
		in_tree[best_b] = 1
		remaining -= 1
		edges.append([best_a, best_b])

	return edges


static func _dig_corridor(
	grid: PackedByteArray, w: int, h: int,
	start: Vector2i, goal: Vector2i,
	rng: RandomNumberGenerator,
	corridor_width: int,
	res: CarveResult,
	region: Rect2i,
	floor_tex_corr: int
) -> void:
	var p: Vector2i = start
	var dir: Vector2i = Vector2i.ZERO

	var run_start: Vector2i = p
	var run_dir: Vector2i = Vector2i.ZERO
	var run_len: int = 0

	var guard: int = w * h
	while p != goal and guard > 0:
		guard -= 1

		_carve_corridor_cell(grid, w, h, p, dir, corridor_width)

		var dx: int = signi(goal.x - p.x)
		var dy: int = signi(goal.y - p.y)
		var options: Array[Vector2i] = []
		if dx != 0:
			options.append(Vector2i(dx, 0))
		if dy != 0:
			options.append(Vector2i(0, dy))
		if options.is_empty():
			break

		var pick: Vector2i
		if dir != Vector2i.ZERO and options.has(dir) and rng.randf() < 0.60:
			pick = dir
		else:
			pick = options[rng.randi_range(0, options.size() - 1)]
		dir = pick

		# Track floor stamp runs (only along the corridor spine; width handled by stamp size).
		if run_len == 0:
			run_start = p
			run_dir = dir
			run_len = 1
		elif dir == run_dir:
			run_len += 1
		else:
			_flush_corridor_run(res, region, run_start, run_dir, run_len, corridor_width, floor_tex_corr)
			run_start = p
			run_dir = dir
			run_len = 1

		p += dir

	# final cell
	_carve_corridor_cell(grid, w, h, goal, dir, corridor_width)
	if run_len > 0:
		_flush_corridor_run(res, region, run_start, run_dir, run_len, corridor_width, floor_tex_corr)


static func _carve_corridor_cell(grid: PackedByteArray, w: int, h: int, p: Vector2i, dir: Vector2i, corridor_width: int) -> void:
	# carve a small "tube" around p
	if p.x < 1 or p.y < 1 or p.x >= w - 1 or p.y >= h - 1:
		return

	grid[p.y * w + p.x] = 1
	if corridor_width <= 1:
		return

	# widen perpendicular to direction (default vertical widen if no dir yet)
	var perp := Vector2i(0, 1)
	if dir == Vector2i(1, 0) or dir == Vector2i(-1, 0):
		perp = Vector2i(0, 1)
	elif dir == Vector2i(0, 1) or dir == Vector2i(0, -1):
		perp = Vector2i(1, 0)

	for k in range(1, corridor_width):
		var pp := p + perp * k
		if pp.x < 1 or pp.y < 1 or pp.x >= w - 1 or pp.y >= h - 1:
			continue
		grid[pp.y * w + pp.x] = 1


static func _flush_corridor_run(res: CarveResult, region: Rect2i, start: Vector2i, dir: Vector2i, length: int, width: int, tex: int) -> void:
	if length <= 0:
		return
	# Build a Rect2i in chunk-local coords.
	var size := Vector2i(1, 1)
	if dir.x != 0:
		size = Vector2i(length + 1, width)
	elif dir.y != 0:
		size = Vector2i(width, length + 1)

	var pos := start
	# Include the starting cell in rect; for horizontal we extend in +x or -x.
	if dir.x < 0:
		pos = Vector2i(start.x - length, start.y)
	if dir.y < 0:
		pos = Vector2i(start.x, start.y - length)

	res.floor_stamps.append({
		"rect": Rect2i(region.position + pos, size),
		"tex": tex,
		"alpha": 0.80,
		"z": -93
	})


static func _carve_entrance(grid: PackedByteArray, w: int, h: int, p: Vector2i, dir: Vector2i, wid: int) -> void:
	# carve a short entrance corridor into the region
	for i in range(3):
		var q := p + dir * i
		if q.x < 1 or q.y < 1 or q.x >= w - 1 or q.y >= h - 1:
			continue
		grid[q.y * w + q.x] = 1
		# widen
		var perp := Vector2i(0, 1)
		if dir == Vector2i(1,0) or dir == Vector2i(-1,0):
			perp = Vector2i(0, 1)
		else:
			perp = Vector2i(1, 0)
		for k in range(1, wid):
			var qq := q + perp * k
			if qq.x < 1 or qq.y < 1 or qq.x >= w - 1 or qq.y >= h - 1:
				continue
			grid[qq.y * w + qq.x] = 1


static func _extract_boundary_walls(
	grid: PackedByteArray, w: int, h: int,
	region: Rect2i,
	rng: RandomNumberGenerator,
	window_chance: float,
	res: CarveResult
) -> void:
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var idx := y * w + x
			if grid[idx] != 0:
				continue
			# If any 4-neighbor is floor => boundary wall
			var open := false
			if grid[y * w + (x + 1)] == 1: open = true
			elif grid[y * w + (x - 1)] == 1: open = true
			elif grid[(y + 1) * w + x] == 1: open = true
			elif grid[(y - 1) * w + x] == 1: open = true

			if not open:
				continue

			var cell := region.position + Vector2i(x, y)
			res.wall_cells[cell] = true

			if window_chance > 0.0 and rng.randf() < window_chance:
				# Basic window heuristic: only on walls that sit on a straight line (2 opposite open)
				var open_n := (grid[(y - 1) * w + x] == 1)
				var open_s := (grid[(y + 1) * w + x] == 1)
				var open_e := (grid[y * w + (x + 1)] == 1)
				var open_w := (grid[y * w + (x - 1)] == 1)
				var straight := (open_n and open_s) or (open_e and open_w)
				if straight:
					res.window_cells[cell] = true


static func _pick_floor_cell(grid: PackedByteArray, w: int, h: int, rng: RandomNumberGenerator) -> Vector2i:
	for _t in range(60):
		var x := rng.randi_range(2, w - 3)
		var y := rng.randi_range(2, h - 3)
		if grid[y * w + x] != 1:
			continue
		return Vector2i(x, y)
	return Vector2i(-1, -1)
