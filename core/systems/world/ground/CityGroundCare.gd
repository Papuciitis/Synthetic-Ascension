extends RefCounted
## Presentation weights in chunk-local cells. Final overgrowth ownership may be
## supplied by GroundSplatRenderer so the pocket fits the ground left by stamps.


static func plan(coord: Vector2i, spec: Dictionary, cell_px: int, cells_per_chunk: int, eligible: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var weights := PackedByteArray()
	weights.resize(cells_per_chunk*cells_per_chunk)
	var footprint: PackedVector2Array = spec.get("footprint_px",PackedVector2Array())
	if footprint.size() < 3 or cell_px <= 0:
		return weights
	var bounds := Rect2(footprint[0],Vector2.ZERO)
	for point: Vector2 in footprint:
		bounds = bounds.expand(point)
	var anchor: Vector2 = spec.get("garden_contact_px",Vector2(bounds.position.x,bounds.end.y))
	var edge := _nearest_edge(footprint,anchor,float(cell_px))
	if edge.is_empty():
		return weights
	var contact: Vector2 = edge.contact
	var normal: Vector2 = edge.normal
	var tangent: Vector2 = edge.tangent
	# The planted edge opens into one small side/back pocket. Moving slightly
	# toward its nearest corner joins both kept southwest beds/tree roots without
	# surrounding the house or assuming that its door faces the planted side.
	var center := contact+normal*cell_px*1.35+tangent*cell_px*0.45
	var seed_value: int = int(spec.get("visual_seed",0))
	var origin := coord*cells_per_chunk
	var doors: Array = spec.get("doors",[])
	var has_ground := eligible.size() == weights.size()
	var cells: Array[Vector2i] = []
	var points := PackedVector2Array()
	var variation := PackedFloat32Array()
	for y in cells_per_chunk:
		for x in cells_per_chunk:
			if has_ground and eligible[y*cells_per_chunk+x] == 0:
				continue
			var point := (Vector2(x,y)+Vector2(0.5,0.5))*cell_px
			if point.distance_to(anchor) >= cell_px*6.0 or Geometry2D.is_point_in_polygon(point,footprint) or _is_access(point,doors,cell_px):
				continue
			cells.append(Vector2i(x,y))
			points.append(point)
			variation.append(0.90+_noise(Vector2(origin+Vector2i(x,y))/3.6,seed_value)*0.20)
	var field := _field(center,normal,tangent,points,variation,cell_px)
	# Keep a useful planted-corner fit in place (including the reviewed tree).
	# If paving consumes it, choose one nearby available center and reorient to
	# its nearest real footprint edge. The footprint, garden and paving stay put.
	if has_ground and not _usable(field):
		var best_score := _score(field,center.distance_to(anchor)/cell_px)
		for candidate: Vector2 in points:
			if candidate.distance_to(anchor) > cell_px*4.0:
				continue
			var candidate_edge := _nearest_edge(footprint,candidate,float(cell_px))
			if candidate_edge.is_empty() or candidate.distance_to(candidate_edge.contact) > cell_px*3.0:
				continue
			var candidate_field := _field(candidate,candidate_edge.normal,candidate_edge.tangent,points,variation,cell_px)
			var score := _score(candidate_field,candidate.distance_to(anchor)/cell_px)
			if score > best_score:
				best_score = score
				field = candidate_field
	for index in cells.size():
		var cell := cells[index]
		weights[cell.y*cells_per_chunk+cell.x] = field[index]
	return weights


static func _field(center: Vector2, normal: Vector2, tangent: Vector2, points: PackedVector2Array, variation: PackedFloat32Array, cell_px: int) -> PackedByteArray:
	var field := PackedByteArray()
	field.resize(points.size())
	for index in points.size():
		var relative := (points[index]-center)/cell_px
		var along := relative.dot(tangent)/2.6
		var outward := relative.dot(normal)/2.1
		var radius := Vector2(along,outward).length()/variation[index]
		# Keep the existing irregular support while giving its legal center a
		# useful short-grass area; the outer edge and all ground vetoes stay put.
		field[index] = roundi((1.0-smoothstep(0.50,1.05,radius))*255.0)
	return field


static func _usable(field: PackedByteArray) -> bool:
	var positive := 0
	var strong := 0
	for amount in field:
		if amount > 0: positive += 1
		if amount >= 179: strong += 1
	return positive >= 8 and strong >= 3


static func _score(field: PackedByteArray, distance_cells: float) -> float:
	var positive := 0
	var strong := 0
	var mass := 0
	for amount in field:
		if amount > 0: positive += 1
		if amount >= 179: strong += 1
		mass += amount
	# Prefer a pocket with a useful intact core, then its actual available area
	# and proximity to the unchanged planted corner. Fixed iteration breaks ties.
	return (100.0 if strong >= 3 else 0.0)+(20.0 if positive >= 8 else 0.0)+float(mass)/255.0-distance_cells*0.9


static func _nearest_edge(footprint: PackedVector2Array, anchor: Vector2, cell_px: float) -> Dictionary:
	var nearest := INF
	var result: Dictionary = {}
	for index in footprint.size():
		var a := footprint[index]
		var b := footprint[(index+1)%footprint.size()]
		if a.is_equal_approx(b):
			continue
		var contact := Geometry2D.get_closest_point_to_segment(anchor,a,b)
		var distance := contact.distance_squared_to(anchor)
		if distance >= nearest:
			continue
		var tangent := (b-a).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		var midpoint := (a+b)*0.5
		if Geometry2D.is_point_in_polygon(midpoint+normal*cell_px*0.25,footprint):
			normal = -normal
		var toward := a-contact if contact.distance_squared_to(a) <= contact.distance_squared_to(b) else b-contact
		if toward.length_squared() > 0.01:
			tangent = toward.normalized()
		nearest = distance
		result = {"contact":contact,"normal":normal,"tangent":tangent}
	return result


static func _is_access(point: Vector2, doors: Array, cell_px: int) -> bool:
	for door: Dictionary in doors:
		var direction := Vector2(door.get("dir",Vector2i.ZERO))
		if direction.is_zero_approx():
			continue
		var across := Vector2(-direction.y,direction.x)
		var width: int = maxi(1,int(door.get("width",2)))
		var center := (Vector2(door.get("pos",Vector2i.ZERO))+Vector2(0.5,0.5)+across*(float(width-1)*0.5-float(width>>1)))*cell_px
		var relative := (point-center)/cell_px
		var outward := relative.dot(direction)
		if outward >= -0.6 and outward <= 4.0 and absf(relative.dot(across)) <= width*0.5+0.65:
			return true
	return false


static func _noise(point: Vector2, seed_value: int) -> float:
	var lattice := Vector2i(floori(point.x),floori(point.y))
	var fraction := point-Vector2(lattice)
	fraction = fraction*fraction*(Vector2(3,3)-2.0*fraction)
	return lerpf(lerpf(_hash(lattice,seed_value),_hash(lattice+Vector2i.RIGHT,seed_value),fraction.x),lerpf(_hash(lattice+Vector2i.DOWN,seed_value),_hash(lattice+Vector2i.ONE,seed_value),fraction.x),fraction.y)


static func _hash(cell: Vector2i, seed_value: int) -> float:
	var bits := (cell.x*374761393)^(cell.y*668265263)^seed_value
	bits = ((bits^(bits>>13))&0x7fffffff)*1274126177
	bits = (bits^(bits>>16))&0x7fffffff
	return float(bits)/2147483647.0
