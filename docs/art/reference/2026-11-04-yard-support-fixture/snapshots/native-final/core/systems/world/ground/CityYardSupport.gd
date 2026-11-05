extends RefCounted
## Presentation only: one soft patch outside an unused actual footprint corner.
## All geometry is chunk-local pixels, matching CityGroundCare's input contract.
## No gameplay RNG, assets, scene state, or care-planner implementation is used.

const MAX_CELLS := 256
const MAX_CELL_PX := 4096
const MAX_VERTICES := 64
const MAX_DOORS := 32
const MAX_COORD := 1000000
const MAX_PIXEL := 10000000.0


## Invalid grid dimensions return an empty array; other invalid input returns a
## correctly sized zero field. These limits also bound allocation and polygon work.
static func plan(coord: Vector2i, spec: Dictionary, cell_px: int, cells_per_chunk: int) -> PackedByteArray:
	var weights := PackedByteArray()
	if cells_per_chunk <= 0 or cells_per_chunk > MAX_CELLS:
		return weights
	weights.resize(cells_per_chunk*cells_per_chunk)
	if cell_px <= 0 or cell_px > MAX_CELL_PX or absi(coord.x) > MAX_COORD or absi(coord.y) > MAX_COORD:
		return weights
	if typeof(spec.get("footprint_px")) != TYPE_PACKED_VECTOR2_ARRAY:
		return weights
	var footprint: PackedVector2Array = spec.footprint_px
	var signed_area := _area_if_simple(footprint)
	if signed_area == 0.0:
		return weights
	if typeof(spec.get("doors",[])) != TYPE_ARRAY or typeof(spec.get("visual_seed",0)) != TYPE_INT:
		return weights
	var doors: Array = spec.get("doors",[])
	if not _valid_doors(doors):
		return weights
	var bounds := Rect2(footprint[0],Vector2.ZERO)
	for point: Vector2 in footprint:
		bounds = bounds.expand(point)
	var garden := Vector2(bounds.position.x,bounds.end.y)
	if spec.has("garden_contact_px"):
		if typeof(spec.garden_contact_px) != TYPE_VECTOR2 or not _valid_point(spec.garden_contact_px):
			return weights
		garden = spec.garden_contact_px
	var seed_value: int = spec.get("visual_seed",0)
	var chosen := Vector2.ZERO
	var outward := Vector2.ZERO
	var best_score := -INF
	for i in footprint.size():
		var corner := footprint[i]
		var incoming := corner-footprint[(i-1+footprint.size())%footprint.size()]
		var outgoing := footprint[(i+1)%footprint.size()]-corner
		# A reflex notch cannot seed a yard corner, in either winding.
		if incoming.cross(outgoing)*signf(signed_area) <= 0.001:
			continue
		var a := incoming.normalized()
		var b := outgoing.normalized()
		var normal := (Vector2(a.y,-a.x)+Vector2(b.y,-b.x)).normalized()*signf(signed_area)
		if normal.is_zero_approx() or Geometry2D.is_point_in_polygon(corner+normal*cell_px*0.5,footprint):
			continue
		if corner.distance_to(garden) <= cell_px*4.5 or _is_access(corner,doors,cell_px):
			continue
		var center := corner+normal*cell_px*1.1
		if _is_access(center,doors,cell_px):
			continue
		# Prefer the least planted corner. Seed resolves near-equal alternatives.
		var score := corner.distance_to(garden)/cell_px+_hash(Vector2i(corner),seed_value)*0.25
		if score > best_score:
			best_score = score
			chosen = corner
			outward = normal
	if best_score == -INF:
		return weights
	var center := chosen+outward*cell_px*1.1
	var tangent := Vector2(-outward.y,outward.x)
	var world_corner := Vector2i(chosen/cell_px)+coord*cells_per_chunk
	var variation := _hash(world_corner,seed_value)
	var long_radius := cell_px*(2.9+variation*0.4)
	var short_radius := cell_px*(2.15+_hash(world_corner+Vector2i(31,17),seed_value)*0.3)
	var phase := variation*TAU
	# Visit a constant-size window, even when the polygon is far outside the chunk.
	var first := Vector2i(clampi(floori(center.x/cell_px-4.5),0,cells_per_chunk),clampi(floori(center.y/cell_px-4.5),0,cells_per_chunk))
	var last := Vector2i(clampi(ceili(center.x/cell_px+4.5),0,cells_per_chunk),clampi(ceili(center.y/cell_px+4.5),0,cells_per_chunk))
	for y in range(first.y,last.y):
		for x in range(first.x,last.x):
			var point := (Vector2(x,y)+Vector2(0.5,0.5))*cell_px
			if Geometry2D.is_point_in_polygon(point,footprint) or point.distance_to(garden) <= cell_px*3.5 or _is_access(point,doors,cell_px):
				continue
			var delta := point-center
			var ellipse := Vector2(delta.dot(outward)/long_radius,delta.dot(tangent)/short_radius)
			# Smooth angular lobes avoid a rectangular stamp and hard noise holes.
			var angle := ellipse.angle()
			var radius := ellipse.length()/(1.0+0.07*sin(angle*3.0+phase)+0.04*sin(angle*5.0-phase))
			if radius >= 1.0:
				continue
			var strength := 1.0-smoothstep(0.22,1.0,radius)
			weights[y*cells_per_chunk+x] = clampi(roundi(strength*220.0),0,220)
	return weights


static func _valid_point(point: Vector2) -> bool:
	return point.is_finite() and absf(point.x) <= MAX_PIXEL and absf(point.y) <= MAX_PIXEL


static func _area_if_simple(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3 or polygon.size() > MAX_VERTICES:
		return 0.0
	var area := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		if not _valid_point(a) or not _valid_point(b) or a.distance_squared_to(b) < 1.0:
			return 0.0
		area += a.cross(b)
		for j in range(i+1,polygon.size()):
			if j == i+1 or (i == 0 and j == polygon.size()-1):
				continue
			var c := polygon[j]
			var d := polygon[(j+1)%polygon.size()]
			if not _valid_point(c) or not _valid_point(d):
				return 0.0
			if Geometry2D.segment_intersects_segment(a,b,c,d) != null:
				return 0.0
			# Geometry2D excludes parallel overlap; reject self-touching edges too.
			if Geometry2D.get_closest_point_to_segment(c,a,b).distance_squared_to(c) < 0.001 or Geometry2D.get_closest_point_to_segment(d,a,b).distance_squared_to(d) < 0.001:
				return 0.0
	return area if absf(area) >= 1.0 else 0.0


static func _valid_doors(doors: Array) -> bool:
	if doors.size() > MAX_DOORS:
		return false
	for door in doors:
		if typeof(door) != TYPE_DICTIONARY or typeof(door.get("pos")) != TYPE_VECTOR2I or typeof(door.get("dir")) != TYPE_VECTOR2I or typeof(door.get("width",2)) != TYPE_INT:
			return false
		var direction: Vector2i = door.dir
		var pos: Vector2i = door.pos
		var width: int = door.get("width",2)
		if absi(direction.x)+absi(direction.y) != 1 or absi(pos.x) > MAX_COORD or absi(pos.y) > MAX_COORD or width < 1 or width > 16:
			return false
	return true


## Door positions are cell coordinates. Width extends along the signed across
## axis; the half-cell correction keeps even widths aligned in all four directions.
static func _is_access(point: Vector2, doors: Array, cell_px: int) -> bool:
	for door: Dictionary in doors:
		var direction := Vector2(door.dir)
		var across := Vector2(-direction.y,direction.x)
		var width: int = door.get("width",2)
		var center := (Vector2(door.pos)+Vector2(0.5,0.5)+across*(float(width-1)*0.5-float(width>>1)))*cell_px
		var delta := (point-center)/cell_px
		var distance := delta.dot(direction)
		if distance >= -0.6 and distance <= 4.0 and absf(delta.dot(across)) <= float(width)*0.5+0.65:
			return true
	return false


static func _hash(cell: Vector2i, seed_value: int) -> float:
	# Mask before multiplication so even extreme caller seeds stay in int64 range.
	var bits := ((cell.x*374761393)^(cell.y*668265263)^seed_value)&0x7fffffff
	bits = ((bits^(bits>>13))*1274126177)&0x7fffffff
	return float((bits^(bits>>16))&0x7fffffff)/2147483647.0
