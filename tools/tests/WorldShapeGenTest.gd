extends Node

# ChunkShapeGen (2026-09-27, non-block city pass): the cell-mask geometry the
# district generator uses for irregular footprints, bent roads and polygon
# plazas. Pure functions, so these checks are exact.
#
# Run: <godot> --headless --path . res://tools/tests/WorldShapeGenTest.tscn

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _connected(cells: Dictionary) -> bool:
	if cells.is_empty():
		return true
	var start: Vector2i = cells.keys()[0]
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in ChunkShapeGen.DIRS_4:
			var n: Vector2i = c + d
			if cells.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen.size() == cells.size()


func _run() -> void:
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(32, 32))

	# Rect masks and boundary extraction.
	var rect := Rect2i(Vector2i(4, 4), Vector2i(10, 8))
	var fill := ChunkShapeGen.rect_cells(rect)
	_check(fill.size() == 80, "rect_cells fills every cell of a 10x8 rect (%d)" % fill.size())
	var walls := ChunkShapeGen.boundary_from_fill(fill)
	_check(walls.size() == 2 * 10 + 2 * 6, "boundary_from_fill of a rect is its perimeter (%d)" % walls.size())
	var ring := ChunkShapeGen.outline_of_fill(fill)
	_check(ring.size() == 2 * 10 + 2 * 8 and not ring.has(Vector2i(3, 3)), "outline_of_fill is the outside ring without corners (%d)" % ring.size())

	# Polygon rasterisation: a diamond covers the cells whose centres it holds.
	var diamond := PackedVector2Array([Vector2(16, 8), Vector2(24, 16), Vector2(16, 24), Vector2(8, 16)])
	var dcells := ChunkShapeGen.rasterize_polygon(diamond, bounds)
	_check(dcells.has(Vector2i(16, 16)) and dcells.has(Vector2i(16, 9)) and not dcells.has(Vector2i(8, 8)) and not dcells.has(Vector2i(16, 24)), "rasterize_polygon keeps centres inside the diamond and drops corners outside")
	_check(dcells.size() >= 112 and dcells.size() <= 150, "the diamond covers about half its 16x16 bounding square (%d)" % dcells.size())

	# Polyline rasterisation: a bent road keeps its full width and its ends.
	var path := ChunkShapeGen.build_road_path(Vector2(0.0, 16.0), Vector2(32.0, 16.0), _rng(7), 3.0)
	_check(path.size() == 3 and path[0] == Vector2(0.0, 16.0) and path[2] == Vector2(32.0, 16.0), "build_road_path bends once and never moves its endpoints")
	_check(absf(path[1].y - 16.0) <= 3.0 and path[1].x > 8.0 and path[1].x < 24.0, "the bend stays within 3 cells sideways and in the middle band (%s)" % str(path[1]))
	var road := ChunkShapeGen.rasterize_polyline(path, 3.0, bounds)
	_check(road.has(Vector2i(0, 16)) and road.has(Vector2i(31, 16)) and road.has(Vector2i(0, 14)) and road.has(Vector2i(0, 18)), "the road reaches both chunk edges at the connector centre, six cells wide")
	var straight := ChunkShapeGen.rasterize_polyline(PackedVector2Array([Vector2(0.0, 16.0), Vector2(32.0, 16.0)]), 3.0, bounds)
	_check(straight.size() == 32 * 6, "a straight radius-3 road is exactly six rows (%d)" % straight.size())
	_check(_connected(road), "a bent road is one connected mass")

	# Packing a mask into row-run rectangles covers it exactly, with few rects.
	var rects := ChunkShapeGen.cells_to_rects(road)
	var covered: Dictionary = {}
	var overlap := false
	for r in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if covered.has(c):
					overlap = true
				covered[c] = true
	_check(covered.size() == road.size() and not overlap and covered.keys().all(func(k): return road.has(k)), "cells_to_rects covers the bent road exactly once")
	_check(rects.size() <= 12, "a one-bend road packs into a handful of rectangles (%d)" % rects.size())
	_check(ChunkShapeGen.cells_to_rects(straight).size() == 1, "a straight road packs into one rectangle")

	# Footprints: deterministic, notched, connected, with a full wall ring.
	var base := Rect2i(Vector2i(6, 6), Vector2i(14, 12))
	var fp_a := ChunkShapeGen.generate_building_footprint(_rng(99), base)
	var fp_b := ChunkShapeGen.generate_building_footprint(_rng(99), base)
	_check(fp_a.size() == fp_b.size() and fp_a.keys().all(func(k): return fp_b.has(k)), "the same seed gives the same footprint")
	var notched := 0
	var all_connected := true
	var min_cells := 1 << 30
	for seed_value in range(100):
		var fp := ChunkShapeGen.generate_building_footprint(_rng(seed_value), base)
		if fp.size() < base.size.x * base.size.y:
			notched += 1
		all_connected = all_connected and _connected(fp)
		min_cells = mini(min_cells, fp.size())
	_check(notched >= 60, "most footprints are notched (%d of 100)" % notched)
	_check(all_connected, "every footprint is one 4-connected mass")
	_check(min_cells >= (base.size.x * base.size.y) >> 1, "a footprint keeps at least half its base area (%d)" % min_cells)
	var inner := ChunkShapeGen.largest_inscribed_rect(fp_a)
	_check(inner.size.x >= 4 and inner.size.y >= 4 and ChunkShapeGen.rect_inside(fp_a, inner), "largest_inscribed_rect returns a usable rect fully inside the footprint (%s)" % str(inner))
	var square := ChunkShapeGen.largest_inscribed_rect(fill)
	_check(square == rect, "largest_inscribed_rect of a rect is the rect itself (%s)" % str(square))

	# Plazas: every family yields a polygon that rasterises to a sizeable,
	# connected, non-square mass.
	for family in range(3):
		var poly := ChunkShapeGen.plaza_polygon(_rng(11 + family), Vector2(16, 16), 7.0, family)
		var cells := ChunkShapeGen.rasterize_polygon(poly, bounds)
		var b := ChunkShapeGen.bounds_of(cells)
		var square_area := b.size.x * b.size.y
		_check(cells.size() >= 80 and cells.size() < square_area and _connected(cells), "plaza family %d is a connected non-square mass (%d cells in a %s box)" % [family, cells.size(), str(b.size)])

	# The hub courtyard (HubWorld statics): an authored polygon whose walls
	# are its outline, with both gates open and every station on floor.
	var hub_fill: Dictionary = HubWorld.courtyard_cells()
	var hub_walls: Dictionary = HubWorld.courtyard_walls(hub_fill)
	var hub_mid := HubWorld.WIDTH >> 1
	_check(hub_fill.size() < HubWorld.WIDTH * HubWorld.HEIGHT and hub_fill.size() > (HubWorld.WIDTH * HubWorld.HEIGHT) >> 1, "the hub floor is an authored polygon, not the full box (%d cells)" % hub_fill.size())
	_check(_connected(hub_fill), "the hub floor is one connected mass")
	var hub_overlap := false
	for key in hub_walls.keys():
		if hub_fill.has(key):
			hub_overlap = true
	_check(not hub_overlap, "hub walls sit outside the floor, so every floor cell is walkable")
	var gates_open := true
	for x in range(hub_mid - HubWorld.GATE_HALF_W, hub_mid + HubWorld.GATE_HALF_W + 1):
		gates_open = gates_open and not hub_walls.has(Vector2i(x, -1)) and not hub_walls.has(Vector2i(x, HubWorld.HEIGHT)) and hub_fill.has(Vector2i(x, 0)) and hub_fill.has(Vector2i(x, HubWorld.HEIGHT - 1))
	_check(gates_open, "both hub gates open onto floor")
	for at in HubWorld.STATION_CELLS.values():
		var cell := Vector2i(int(floor(at.x)), int(floor(at.y)))
		_check(hub_fill.has(cell), "hub point %s stands on floor" % str(at))

	print("WorldShapeGenTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
