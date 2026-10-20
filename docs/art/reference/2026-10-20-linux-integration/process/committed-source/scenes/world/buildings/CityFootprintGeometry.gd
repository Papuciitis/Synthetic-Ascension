extends RefCounted
## Chunk-build geometry only. Filled convex pieces let subtraction preserve
## concave exteriors and enclosed cuts without drawing Clipper hole contours.

const EPS := 0.001


static func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])


static func outline_for(kit: Node) -> PackedVector2Array:
	var roof := kit.get("_roof") as RoofOverlay
	if is_instance_valid(roof) and roof.footprint_outline_px.size() >= 3:
		return roof.footprint_outline_px.duplicate()
	return rect_polygon(kit.get("bounds"))


static func occupied_parts(chunk: Node, footprints: Array[Rect2i], cell_px: int) -> Array[PackedVector2Array]:
	var exact: Dictionary = {}
	for child: Node in chunk.get_children():
		if child.is_in_group(&"city_block_building") and child.has_meta(&"footprint_cells"):
			exact[child.get_meta(&"footprint_cells")] = outline_for(child)
	var result: Array[PackedVector2Array] = []
	for footprint: Rect2i in footprints:
		var outline: PackedVector2Array = exact.get(footprint,rect_polygon(Rect2(Vector2(footprint.position)*cell_px,Vector2(footprint.size)*cell_px)))
		result.append_array(convex_parts(outline))
	return result


static func convex_parts(outline: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if outline.size() < 3 or absf(_area(outline)) < EPS: return result
	if _is_convex(outline):
		result.append(outline)
		return result
	# Actual city footprints are orthogonal. Coalesce their horizontal bands
	# into rectangles before sweeping; an L needs two pieces rather than many
	# diagonally triangulated overlapping casts. Other simple outlines retain
	# a safe triangulated fallback.
	var levels: Array[float] = []
	var orthogonal := true
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index+1)%outline.size()]
		if not is_equal_approx(a.x,b.x) and not is_equal_approx(a.y,b.y): orthogonal = false
		if not levels.has(a.y): levels.append(a.y)
	if orthogonal:
		levels.sort()
		var rectangles: Array[Rect2] = []
		for row in range(levels.size()-1):
			var middle := (levels[row]+levels[row+1])*0.5
			var crosses: Array[float] = []
			for index in outline.size():
				var a := outline[index]
				var b := outline[(index+1)%outline.size()]
				if middle > minf(a.y,b.y) and middle < maxf(a.y,b.y): crosses.append(a.x)
			crosses.sort()
			for pair in range(0,crosses.size()-1,2):
				var rect := Rect2(crosses[pair],levels[row],crosses[pair+1]-crosses[pair],levels[row+1]-levels[row])
				var merged := false
				for index in rectangles.size():
					var previous := rectangles[index]
					if is_equal_approx(previous.end.y,rect.position.y) and is_equal_approx(previous.position.x,rect.position.x) and is_equal_approx(previous.size.x,rect.size.x):
						previous.size.y += rect.size.y
						rectangles[index] = previous
						merged = true
						break
				if not merged and rect.has_area(): rectangles.append(rect)
		for rect: Rect2 in rectangles: result.append(rect_polygon(rect))
		return result
	var triangles := Geometry2D.triangulate_polygon(outline)
	for index in range(0,triangles.size(),3):
		result.append(PackedVector2Array([outline[triangles[index]],outline[triangles[index+1]],outline[triangles[index+2]]]))
	return result


static func shadow(outline: PackedVector2Array, offset: Vector2) -> Array[PackedVector2Array]:
	var sources := convex_parts(outline)
	var result: Array[PackedVector2Array] = []
	for source: PackedVector2Array in sources:
		var cast := source.duplicate()
		for point: Vector2 in source: cast.append(point+offset)
		var candidates: Array[PackedVector2Array] = [Geometry2D.convex_hull(cast)]
		# Removing earlier emitted pieces makes every fill disjoint, including
		# at inward corners where one wing shadows the other's sweep.
		result.append_array(difference(difference(candidates,sources),result))
	return result


static func difference(subjects: Array[PackedVector2Array], cuts: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = subjects.duplicate()
	for cut: PackedVector2Array in cuts:
		var next: Array[PackedVector2Array] = []
		var cut_bounds := bounds_of(cut)
		for subject: PackedVector2Array in result:
			if bounds_of(subject).intersection(cut_bounds).get_area() <= EPS:
				next.append(subject)
				continue
			var inside := subject
			var orientation := 1.0 if _area(cut) > 0.0 else -1.0
			for index in cut.size():
				if inside.size() < 3: break
				var a := cut[index]
				var b := cut[(index+1)%cut.size()]
				var outside := _half_plane(inside,a,b,-orientation)
				if outside.size() >= 3 and absf(_area(outside)) > EPS: next.append(outside)
				inside = _half_plane(inside,a,b,orientation)
		result = next
		if result.is_empty(): break
	return result


static func bounds_of(points: PackedVector2Array) -> Rect2:
	if points.is_empty(): return Rect2()
	var bounds := Rect2(points[0],Vector2.ZERO)
	for point: Vector2 in points: bounds = bounds.expand(point)
	return bounds


static func _half_plane(points: PackedVector2Array, a: Vector2, b: Vector2, side: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.is_empty(): return result
	var previous := points[-1]
	var previous_distance := (b-a).cross(previous-a)*side
	for point: Vector2 in points:
		var distance := (b-a).cross(point-a)*side
		if (distance >= 0.0) != (previous_distance >= 0.0):
			var crossing := previous.lerp(point,previous_distance/(previous_distance-distance))
			if result.is_empty() or not result[-1].is_equal_approx(crossing): result.append(crossing)
		if distance >= 0.0 and (result.is_empty() or not result[-1].is_equal_approx(point)): result.append(point)
		previous = point
		previous_distance = distance
	if result.size() > 1 and result[0].is_equal_approx(result[-1]): result.remove_at(result.size()-1)
	return result


static func _area(points: PackedVector2Array) -> float:
	var result := 0.0
	for index in points.size(): result += points[index].cross(points[(index+1)%points.size()])
	return result*0.5


static func _is_convex(points: PackedVector2Array) -> bool:
	var positive := false
	var negative := false
	for index in points.size():
		var cross := (points[(index+1)%points.size()]-points[index]).cross(points[(index+2)%points.size()]-points[(index+1)%points.size()])
		positive = positive or cross > EPS
		negative = negative or cross < -EPS
	return not (positive and negative)
