extends RefCounted
class_name RectFacilityCarver

# Room-first "facility/shop" interior generator.
# Goal: guaranteed partitions (rooms + corridors) and readable perimeter walls.
# Output matches DonjonCarver.CarveResult so existing spawning code can stay unchanged.

const DONJON := preload("res://core/systems/world/proc/DonjonCarver.gd")

static func _rect_center_cell(r: Rect2i) -> Vector2i:
	# Rounded center cell within a rect (avoids integer division warnings).
	return Vector2i(
		r.position.x + int(round(float(r.size.x - 1) * 0.5)),
		r.position.y + int(round(float(r.size.y - 1) * 0.5))
	)


static func carve_room_first(
	region: Rect2i,
	rng: RandomNumberGenerator,
	room_attempts: int,
	room_min: Vector2i,
	room_max: Vector2i,
	room_padding: int,
	corridor_width: int,
	window_chance: float,
	entrances: Array[Dictionary],
	floor_room_tex: int,
	floor_corr_tex: int
) -> DONJON.CarveResult:
	var res := DONJON.CarveResult.new()
	if region.size.x < 6 or region.size.y < 6:
		return res

	var inner := region.grow(-1)
	if inner.size.x < 4 or inner.size.y < 4:
		inner = region

	# Floors are stored as a sparse set: Vector2i -> true
	var floor_cells: Dictionary = {}

	var rooms: Array[Rect2i] = []
	var centers: Array[Vector2i] = []

	# --- Place rectangular rooms (non-overlapping + padding) ---
	room_attempts = maxi(room_attempts, 4)
	for _i in range(room_attempts):
		var w := rng.randi_range(maxi(3, room_min.x), maxi(3, room_max.x))
		var h := rng.randi_range(maxi(3, room_min.y), maxi(3, room_max.y))
		if w >= inner.size.x - 1 or h >= inner.size.y - 1:
			continue

		var x0 := rng.randi_range(inner.position.x, inner.position.x + inner.size.x - w)
		var y0 := rng.randi_range(inner.position.y, inner.position.y + inner.size.y - h)
		var rr := Rect2i(Vector2i(x0, y0), Vector2i(w, h))

		var ok := true
		for ex in rooms:
			if rr.grow(room_padding).intersects(ex.grow(room_padding)):
				ok = false
				break
		if not ok:
			continue

		rooms.append(rr)
		centers.append(_rect_center_cell(rr))

		# stamp room floor
		_fill_rect(floor_cells, rr)
		res.floor_stamps.append({
			"rect": rr,
			"tex": floor_room_tex,
			"alpha": 0.98,
			"z": -93
		})

	# Ensure at least a couple rooms
	if rooms.size() < 2:
		var rr2 := Rect2i(
			Vector2i(inner.position.x + 1, inner.position.y + 1),
			Vector2i(maxi(3, inner.size.x - 2), maxi(3, inner.size.y - 2))
		)
		rooms = [rr2]
		centers = [_rect_center_cell(rr2)]
		_fill_rect(floor_cells, rr2)
		res.floor_stamps.append({"rect": rr2, "tex": floor_room_tex, "alpha": 0.98, "z": -93})

	# --- Door openings + entry corridor ---
	for e in entrances:
		if not e.has("pos") or not e.has("dir") or not e.has("width"):
			continue
		var pos: Vector2i = e["pos"] as Vector2i
		var dir: Vector2i = e["dir"] as Vector2i
		var width: int = int(e["width"])

		_carve_entrance(floor_cells, region, pos, dir, width, corridor_width)

		# Connect entry point to nearest room center
		if centers.size() > 0:
			var entry_in := pos + dir * 2
			entry_in = _clamp_to_rect(entry_in, inner)
			var nearest_idx := 0
			var best := 1_000_000
			for j in range(centers.size()):
				var d: int = absi(centers[j].x - entry_in.x) + absi(centers[j].y - entry_in.y)
				if d < best:
					best = d
					nearest_idx = j
			_carve_corridor(floor_cells, entry_in, centers[nearest_idx], corridor_width, inner, rng)
			_add_corridor_stamps(res, entry_in, centers[nearest_idx], corridor_width, inner, floor_corr_tex)

	# --- Connect rooms using a small MST (ensures connectivity) ---
	if centers.size() >= 2:
		var connected: Array[int] = [0]
		var remaining: Array[int] = []
		for i in range(1, centers.size()):
			remaining.append(i)

		while remaining.size() > 0:
			var best_i := connected[0]
			var best_j := remaining[0]
			var best_d := 1_000_000
			for i in connected:
				var ci := centers[i]
				for j in remaining:
					var cj := centers[j]
					var d: int = absi(ci.x - cj.x) + absi(ci.y - cj.y)
					if d < best_d:
						best_d = d
						best_i = i
						best_j = j
			# carve corridor
			_carve_corridor(floor_cells, centers[best_i], centers[best_j], corridor_width, inner, rng)
			_add_corridor_stamps(res, centers[best_i], centers[best_j], corridor_width, inner, floor_corr_tex)

			connected.append(best_j)
			remaining.erase(best_j)

	# --- Build walls: perimeter + boundary walls ---
	var wall: Dictionary = {}
	var door_cells: Dictionary = _collect_door_cells(region, entrances)

	# perimeter walls (always)
	var rx0 := region.position.x
	var ry0 := region.position.y
	var rx1 := region.position.x + region.size.x - 1
	var ry1 := region.position.y + region.size.y - 1
	for x in range(rx0, rx1 + 1):
		var t := Vector2i(x, ry0)
		var b := Vector2i(x, ry1)
		if not door_cells.has(t):
			wall[t] = true
		if not door_cells.has(b):
			wall[b] = true
	for y in range(ry0, ry1 + 1):
		var l := Vector2i(rx0, y)
		var r := Vector2i(rx1, y)
		if not door_cells.has(l):
			wall[l] = true
		if not door_cells.has(r):
			wall[r] = true

	# boundary walls inside (wall cell adjacent to floor)
	for y in range(region.position.y, region.position.y + region.size.y):
		for x in range(region.position.x, region.position.x + region.size.x):
			var p := Vector2i(x, y)
			if floor_cells.has(p):
				continue
			if _has_floor_neighbor(p, floor_cells):
				wall[p] = true

	# windows (rare) on straight wall segments
	if window_chance > 0.0:
		for k in wall.keys():
			var p: Vector2i = k as Vector2i
			# Prefer perimeter windows
			if not (p.x == rx0 or p.x == rx1 or p.y == ry0 or p.y == ry1):
				continue
			var mask := _wall_mask(p, wall)
			var is_straight := (mask == 5 or mask == 10)
			if is_straight and rng.randf() < window_chance:
				res.window_cells[p] = true

	# Remove windows on door cells
	for k in door_cells.keys():
		if res.window_cells.has(k):
			res.window_cells.erase(k)

	res.wall_cells = wall

	# half cover: sample a few floor cells near walls
	var cover_budget := 6
	var floor_keys: Array = floor_cells.keys()
	for _i in range(cover_budget * 8):
		if res.half_cover_cells.size() >= cover_budget:
			break
		if floor_keys.is_empty():
			break
		var pp: Vector2i = floor_keys[rng.randi_range(0, floor_keys.size() - 1)] as Vector2i
		if _has_wall_neighbor(pp, wall) and rng.randf() < 0.35:
			res.half_cover_cells.append(pp)

	return res


static func _fill_rect(floor_cells: Dictionary, r: Rect2i) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			floor_cells[Vector2i(x, y)] = true


static func _carve_entrance(floor_cells: Dictionary, region: Rect2i, pos: Vector2i, dir: Vector2i, width: int, corridor_width: int) -> void:
	# Carve a door hole on the region border with a short entry stub.
	var perp := Vector2i(-dir.y, dir.x)
	var half_w: int = width >> 1
	var w0 := -half_w
	for i in range(width):
		var dp := pos + perp * (w0 + i)
		floor_cells[dp] = true
		floor_cells[dp + dir] = true

	# Entry stub
	var entry_len := maxi(3, corridor_width + 1)
	for t in range(1, entry_len + 1):
		var center := pos + dir * t
		_carve_corridor_brush(floor_cells, center, corridor_width, region.grow(-1))


static func _carve_corridor(
	floor_cells: Dictionary,
	a: Vector2i,
	b: Vector2i,
	width: int,
	bounds: Rect2i,
	rng: RandomNumberGenerator
) -> void:
	var horiz_first := rng.randf() < 0.5
	if horiz_first:
		_carve_h(floor_cells, a, Vector2i(b.x, a.y), width, bounds)
		_carve_v(floor_cells, Vector2i(b.x, a.y), b, width, bounds)
	else:
		_carve_v(floor_cells, a, Vector2i(a.x, b.y), width, bounds)
		_carve_h(floor_cells, Vector2i(a.x, b.y), b, width, bounds)


static func _add_corridor_stamps(
	res: DONJON.CarveResult,
	a: Vector2i,
	b: Vector2i,
	width: int,
	bounds: Rect2i,
	tex: int
) -> void:
	# A small set of rect stamps approximating the corridor segments.
	var half: int = width >> 1
	# Horizontal segment approximation
	var mid1 := Vector2i(b.x, a.y)
	var mid2 := Vector2i(a.x, b.y)

	# We'll stamp both possible L paths; it doesn't hurt (overlaps are fine).
	var xs := mini(a.x, mid1.x)
	var xe := maxi(a.x, mid1.x)
	var hr := Rect2i(Vector2i(xs, a.y - half), Vector2i((xe - xs) + 1, width))
	hr = hr.intersection(bounds)
	if hr.size.x > 0 and hr.size.y > 0:
		res.floor_stamps.append({"rect": hr, "tex": tex, "alpha": 0.92, "z": -93})

	var ys := mini(a.y, mid2.y)
	var ye := maxi(a.y, mid2.y)
	var vr := Rect2i(Vector2i(a.x - half, ys), Vector2i(width, (ye - ys) + 1))
	vr = vr.intersection(bounds)
	if vr.size.x > 0 and vr.size.y > 0:
		res.floor_stamps.append({"rect": vr, "tex": tex, "alpha": 0.92, "z": -93})

	# Second leg from the other bend
	var xs2 := mini(mid2.x, b.x)
	var xe2 := maxi(mid2.x, b.x)
	var hr2 := Rect2i(Vector2i(xs2, b.y - half), Vector2i((xe2 - xs2) + 1, width))
	hr2 = hr2.intersection(bounds)
	if hr2.size.x > 0 and hr2.size.y > 0:
		res.floor_stamps.append({"rect": hr2, "tex": tex, "alpha": 0.92, "z": -93})

	var ys2 := mini(mid1.y, b.y)
	var ye2 := maxi(mid1.y, b.y)
	var vr2 := Rect2i(Vector2i(b.x - half, ys2), Vector2i(width, (ye2 - ys2) + 1))
	vr2 = vr2.intersection(bounds)
	if vr2.size.x > 0 and vr2.size.y > 0:
		res.floor_stamps.append({"rect": vr2, "tex": tex, "alpha": 0.92, "z": -93})


static func _carve_h(floor_cells: Dictionary, a: Vector2i, b: Vector2i, width: int, bounds: Rect2i) -> void:
	var y := a.y
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	for x in range(x0, x1 + 1):
		_carve_corridor_brush(floor_cells, Vector2i(x, y), width, bounds)


static func _carve_v(floor_cells: Dictionary, a: Vector2i, b: Vector2i, width: int, bounds: Rect2i) -> void:
	var x := a.x
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	for y in range(y0, y1 + 1):
		_carve_corridor_brush(floor_cells, Vector2i(x, y), width, bounds)


static func _carve_corridor_brush(floor_cells: Dictionary, center: Vector2i, width: int, bounds: Rect2i) -> void:
	var half: int = width >> 1
	for oy in range(-half, -half + width):
		for ox in range(-half, -half + width):
			var p := Vector2i(center.x + ox, center.y + oy)
			if bounds.has_point(p):
				floor_cells[p] = true


static func _has_floor_neighbor(p: Vector2i, floor_cells: Dictionary) -> bool:
	return floor_cells.has(p + Vector2i(1, 0)) or floor_cells.has(p + Vector2i(-1, 0)) or floor_cells.has(p + Vector2i(0, 1)) or floor_cells.has(p + Vector2i(0, -1))


static func _has_wall_neighbor(p: Vector2i, wall: Dictionary) -> bool:
	return wall.has(p + Vector2i(1, 0)) or wall.has(p + Vector2i(-1, 0)) or wall.has(p + Vector2i(0, 1)) or wall.has(p + Vector2i(0, -1))


static func _wall_mask(p: Vector2i, wall: Dictionary) -> int:
	var m := 0
	if wall.has(p + Vector2i(0, -1)): m |= 1
	if wall.has(p + Vector2i(1, 0)): m |= 2
	if wall.has(p + Vector2i(0, 1)): m |= 4
	if wall.has(p + Vector2i(-1, 0)): m |= 8
	return m


static func _collect_door_cells(region: Rect2i, entrances: Array[Dictionary]) -> Dictionary:
	var door: Dictionary = {}
	for e in entrances:
		if not e.has("pos") or not e.has("dir") or not e.has("width"):
			continue
		var pos: Vector2i = e["pos"] as Vector2i
		var dir: Vector2i = e["dir"] as Vector2i
		var width: int = int(e["width"])
		var perp := Vector2i(-dir.y, dir.x)
		var half_w: int = width >> 1
		var w0 := -half_w
		for i in range(width):
			var dp := pos + perp * (w0 + i)
			if region.has_point(dp):
				door[dp] = true
	return door


static func _rand_floor_cell(floor_cells: Dictionary, rng: RandomNumberGenerator) -> Variant:
	if floor_cells.is_empty():
		return null
	var keys: Array = floor_cells.keys()
	return keys[rng.randi_range(0, keys.size() - 1)]


static func _clamp_to_rect(p: Vector2i, r: Rect2i) -> Vector2i:
	var x := clampi(p.x, r.position.x, r.position.x + r.size.x - 1)
	var y := clampi(p.y, r.position.y, r.position.y + r.size.y - 1)
	return Vector2i(x, y)
