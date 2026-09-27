extends RefCounted
class_name ChunkShapeGen
## Cell-mask geometry for the chunk generator (2026-09-27, "non-block city"
## pass, after docs/../hub_world_gen_thoughts.md). Everything here works on
## the same 64 px cell grid the game plays on: a shape is a Dictionary of
## Vector2i -> true. Continuous inputs (polygons, polylines) are rasterised
## by cell CENTRE, so gameplay (keepout, walkability, wall spawning) and the
## visible floor stay identical. Pure functions, seeded only by the RNG the
## caller passes, so chunk generation stays deterministic.

const DIRS_4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


# ---- masks -----------------------------------------------------------------

static func rect_cells(rect: Rect2i) -> Dictionary:
	var cells: Dictionary = {}
	add_rect(cells, rect)
	return cells


static func add_rect(cells: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells[Vector2i(x, y)] = true


static func subtract_rect(cells: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.erase(Vector2i(x, y))


static func add_cells(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = true


static func erase_cells(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target.erase(key)


static func grow(cells: Dictionary, steps: int = 1) -> Dictionary:
	var out: Dictionary = cells.duplicate()
	for _i in range(steps):
		var ring: Dictionary = {}
		for key in out.keys():
			var cell: Vector2i = key
			for dir in DIRS_4:
				var n := cell + dir
				if not out.has(n):
					ring[n] = true
		add_cells(out, ring)
	return out


static func bounds_of(cells: Dictionary) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var min_c := Vector2i(1 << 30, 1 << 30)
	var max_c := Vector2i(-(1 << 30), -(1 << 30))
	for key in cells.keys():
		var c: Vector2i = key
		min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	return Rect2i(min_c, max_c - min_c + Vector2i.ONE)


static func intersects_rect(cells: Dictionary, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if cells.has(Vector2i(x, y)):
				return true
	return false


static func rect_inside(cells: Dictionary, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not cells.has(Vector2i(x, y)):
				return false
	return true


## The fill cells that touch the outside on any of their four sides.
static func boundary_from_fill(fill: Dictionary) -> Dictionary:
	var walls: Dictionary = {}
	for key in fill.keys():
		var cell: Vector2i = key
		for dir in DIRS_4:
			if not fill.has(cell + dir):
				walls[cell] = true
				break
	return walls


## The ring of OUTSIDE cells that touch the fill on any of their four sides.
static func outline_of_fill(fill: Dictionary) -> Dictionary:
	var ring: Dictionary = {}
	for key in fill.keys():
		var cell: Vector2i = key
		for dir in DIRS_4:
			var n := cell + dir
			if not fill.has(n):
				ring[n] = true
	return ring


## Largest axis-aligned rectangle made only of `cells` (histogram method).
## Returns a zero-size rect for an empty mask.
static func largest_inscribed_rect(cells: Dictionary) -> Rect2i:
	var b := bounds_of(cells)
	if b.size.x <= 0 or b.size.y <= 0:
		return Rect2i()
	var heights := PackedInt32Array()
	heights.resize(b.size.x)
	var best := Rect2i()
	var best_area := 0
	for y in range(b.position.y, b.end.y):
		for i in range(b.size.x):
			heights[i] = (heights[i] + 1) if cells.has(Vector2i(b.position.x + i, y)) else 0
		# Largest rectangle under the histogram, bottom row y.
		var stack: Array[int] = []
		for i in range(b.size.x + 1):
			var h := heights[i] if i < b.size.x else 0
			while not stack.is_empty() and heights[stack[-1]] >= h:
				var top: int = stack.pop_back()
				var height := heights[top]
				var left: int = (stack[-1] + 1) if not stack.is_empty() else 0
				var width := i - left
				var area := width * height
				if area > best_area and height > 0:
					best_area = area
					best = Rect2i(Vector2i(b.position.x + left, y - height + 1), Vector2i(width, height))
			stack.append(i)
	return best


## Packs a mask into the fewest row-run rectangles: runs on consecutive rows
## with the same x-span merge into one rect. Covers exactly the mask.
static func cells_to_rects(cells: Dictionary) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var b := bounds_of(cells)
	if b.size.x <= 0:
		return rects
	var open: Dictionary = {}  # x0 -> [x1, rect index]
	for y in range(b.position.y, b.end.y):
		var runs: Dictionary = {}
		var x := b.position.x
		while x < b.end.x:
			if not cells.has(Vector2i(x, y)):
				x += 1
				continue
			var x0 := x
			while x < b.end.x and cells.has(Vector2i(x, y)):
				x += 1
			runs[x0] = x - 1
		var next_open: Dictionary = {}
		for x0 in runs.keys():
			var x1: int = runs[x0]
			if open.has(x0) and int((open[x0] as Array)[0]) == x1:
				var idx: int = (open[x0] as Array)[1]
				var r: Rect2i = rects[idx]
				r.size.y += 1
				rects[idx] = r
				next_open[x0] = [x1, idx]
			else:
				rects.append(Rect2i(Vector2i(x0, y), Vector2i(x1 - x0 + 1, 1)))
				next_open[x0] = [x1, rects.size() - 1]
		open = next_open
	return rects


# ---- rasterisation -----------------------------------------------------------

## Cells whose centre lies inside `polygon` (cell units), limited to `bounds`.
static func rasterize_polygon(polygon: PackedVector2Array, bounds: Rect2i) -> Dictionary:
	var cells: Dictionary = {}
	if polygon.size() < 3:
		return cells
	var pb := Rect2i()
	var pmin := polygon[0]
	var pmax := polygon[0]
	for p in polygon:
		pmin = Vector2(minf(pmin.x, p.x), minf(pmin.y, p.y))
		pmax = Vector2(maxf(pmax.x, p.x), maxf(pmax.y, p.y))
	pb = Rect2i(Vector2i(int(floor(pmin.x)) - 1, int(floor(pmin.y)) - 1), Vector2i(int(ceil(pmax.x - pmin.x)) + 3, int(ceil(pmax.y - pmin.y)) + 3)).intersection(bounds)
	for y in range(pb.position.y, pb.end.y):
		for x in range(pb.position.x, pb.end.x):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), polygon):
				cells[Vector2i(x, y)] = true
	return cells


## Cells whose centre lies within `radius` (cell units) of the polyline.
static func rasterize_polyline(path: PackedVector2Array, radius: float, bounds: Rect2i) -> Dictionary:
	var cells: Dictionary = {}
	if path.size() == 0:
		return cells
	if path.size() == 1:
		path.append(path[0])
	var pmin := path[0]
	var pmax := path[0]
	for p in path:
		pmin = Vector2(minf(pmin.x, p.x), minf(pmin.y, p.y))
		pmax = Vector2(maxf(pmax.x, p.x), maxf(pmax.y, p.y))
	var pad := int(ceil(radius)) + 1
	var pb := Rect2i(Vector2i(int(floor(pmin.x)) - pad, int(floor(pmin.y)) - pad), Vector2i(int(ceil(pmax.x - pmin.x)) + 2 * pad + 1, int(ceil(pmax.y - pmin.y)) + 2 * pad + 1)).intersection(bounds)
	var r2 := radius * radius
	for y in range(pb.position.y, pb.end.y):
		for x in range(pb.position.x, pb.end.x):
			var p := Vector2(x + 0.5, y + 0.5)
			for i in range(path.size() - 1):
				var nearest := Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])
				if p.distance_squared_to(nearest) <= r2:
					cells[Vector2i(x, y)] = true
					break
	return cells


# ---- authored shapes -----------------------------------------------------------

## A road centre-line from `from` to `to` (cell units) with one sideways
## bend of up to `max_bend` cells, placed between 35% and 65% of the way.
## Endpoints never move, so chunk seams and connector sockets stay exact.
static func build_road_path(from: Vector2, to: Vector2, rng: RandomNumberGenerator, max_bend: float = 2.5) -> PackedVector2Array:
	var delta := to - from
	if delta.length() < 6.0 or max_bend <= 0.0:
		return PackedVector2Array([from, to])
	var t := rng.randf_range(0.35, 0.65)
	var perpendicular := Vector2(-delta.y, delta.x).normalized()
	var bend := from + delta * t + perpendicular * rng.randf_range(-max_bend, max_bend)
	return PackedVector2Array([from, bend, to])


## A deterministic irregular building footprint from a base rectangle: one
## corner notch (75%), and sometimes a shallow side indentation (35%).
## Every notch keeps at least `min_wall` cells of wall on each affected
## side, and the result stays one 4-connected mass.
static func generate_building_footprint(rng: RandomNumberGenerator, rect: Rect2i, min_wall: int = 4) -> Dictionary:
	var cells := rect_cells(rect)
	if rect.size.x < min_wall * 2 + 2 or rect.size.y < min_wall * 2 + 2:
		return cells
	if rng.randf() < 0.75:
		var notch_w := rng.randi_range(2, maxi(2, rect.size.x - min_wall * 2))
		var notch_h := rng.randi_range(2, maxi(2, rect.size.y - min_wall * 2))
		notch_w = mini(notch_w, rect.size.x >> 1)
		notch_h = mini(notch_h, rect.size.y >> 1)
		var corner := rng.randi_range(0, 3)
		var notch := Rect2i()
		match corner:
			0: notch = Rect2i(rect.position, Vector2i(notch_w, notch_h))
			1: notch = Rect2i(Vector2i(rect.end.x - notch_w, rect.position.y), Vector2i(notch_w, notch_h))
			2: notch = Rect2i(Vector2i(rect.position.x, rect.end.y - notch_h), Vector2i(notch_w, notch_h))
			_: notch = Rect2i(rect.end - Vector2i(notch_w, notch_h), Vector2i(notch_w, notch_h))
		subtract_rect(cells, notch)
	if rng.randf() < 0.35:
		var side := rng.randi_range(0, 3)
		var depth := 2
		if side == 0 or side == 2:
			var notch_w := rng.randi_range(2, 4)
			if rect.size.x - notch_w >= min_wall * 2:
				var x := rng.randi_range(rect.position.x + min_wall, rect.end.x - notch_w - min_wall)
				var y := rect.position.y if side == 0 else rect.end.y - depth
				var indent := Rect2i(Vector2i(x, y), Vector2i(notch_w, depth))
				if not intersects_rect(_missing(cells, rect), indent.grow(1)):
					subtract_rect(cells, indent)
		else:
			var notch_h := rng.randi_range(2, 4)
			if rect.size.y - notch_h >= min_wall * 2:
				var y := rng.randi_range(rect.position.y + min_wall, rect.end.y - notch_h - min_wall)
				var x := rect.position.x if side == 3 else rect.end.x - depth
				var indent := Rect2i(Vector2i(x, y), Vector2i(depth, notch_h))
				if not intersects_rect(_missing(cells, rect), indent.grow(1)):
					subtract_rect(cells, indent)
	return cells


## Plaza outlines that are not squares: an irregular octagon ("worn"), a
## chamfered slab ("cut"), or a lopsided blob ("blob"). Returned in cell
## units around `center`, roughly `half_size` across.
static func plaza_polygon(rng: RandomNumberGenerator, center: Vector2, half_size: float, family: int = -1) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var kind := family if family >= 0 else rng.randi_range(0, 2)
	match kind:
		0:
			# Worn octagon: eight spokes with jittered radii.
			for i in range(8):
				var a := TAU * (float(i) + 0.5) / 8.0
				var r := half_size * rng.randf_range(0.82, 1.0)
				pts.append(center + Vector2(cos(a), sin(a)) * r)
		1:
			# Chamfered slab: a rectangle with two or three corners cut away.
			var hw := half_size
			var hh := half_size * rng.randf_range(0.7, 0.95)
			var cut := half_size * rng.randf_range(0.25, 0.45)
			var cut_mask := rng.randi_range(1, 15)
			var corners := [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
			var dirs := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
			for i in range(4):
				var c: Vector2 = corners[i]
				var d: Vector2 = dirs[i]
				if (cut_mask >> i) & 1:
					var next := Vector2(c.x + d.x * cut, c.y)
					var prev := Vector2(c.x, c.y + d.y * cut)
					if i == 0 or i == 2:
						pts.append(center + prev)
						pts.append(center + next)
					else:
						pts.append(center + next)
						pts.append(center + prev)
				else:
					pts.append(center + c)
		_:
			# Lopsided blob: ten spokes with a low-frequency radius wobble.
			var phase := rng.randf() * TAU
			var wobble := rng.randf_range(0.12, 0.22)
			for i in range(10):
				var a := TAU * float(i) / 10.0
				var r := half_size * (1.0 - wobble + wobble * sin(a * 2.0 + phase)) * rng.randf_range(0.94, 1.0)
				pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


static func _missing(cells: Dictionary, rect: Rect2i) -> Dictionary:
	var missing: Dictionary = {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if not cells.has(c):
				missing[c] = true
	return missing
