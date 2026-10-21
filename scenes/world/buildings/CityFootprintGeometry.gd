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


## Real walls stand 16 px inside the parcel cells (a 32 px band through each
## edge cell); the outer rim is open ground that shadow and contact may shade.
const WALL_FACE_INSET := 16.0


## Occupied wall faces of every placed parcel: the receivers no exterior cast
## may darken (interiors show through in cutaway). Convex pieces.
static func occupied_wall_parts(chunk: Node, footprints: Array[Rect2i], cell_px: int) -> Array[PackedVector2Array]:
	var exact: Dictionary = {}
	for child: Node in chunk.get_children():
		if child.is_in_group(&"city_block_building") and child.has_meta(&"footprint_cells"):
			exact[child.get_meta(&"footprint_cells")] = child
	var result: Array[PackedVector2Array] = []
	for footprint: Rect2i in footprints:
		var kit: Node = exact.get(footprint)
		if kit != null and kit.has_method(&"wall_parts"):
			result.append_array(kit.call(&"wall_parts"))
			continue
		var outline: PackedVector2Array = outline_for(kit) if kit != null else rect_polygon(Rect2(Vector2(footprint.position)*cell_px,Vector2(footprint.size)*cell_px))
		result.append_array(convex_parts(inset_outline(outline,WALL_FACE_INSET)))
	return result


static func inset_outline(outline: PackedVector2Array, inset: float) -> PackedVector2Array:
	if inset <= 0.0 or outline.size() < 3: return outline.duplicate()
	var best := PackedVector2Array()
	for candidate: PackedVector2Array in Geometry2D.offset_polygon(outline,-inset,Geometry2D.JOIN_MITER):
		if absf(_area(candidate)) > absf(_area(best)): best = candidate
	return best


## Ground footprint of a building whose south walls are drawn `wall_height`
## tall: the drawn roof field dropped by its eave height onto the wall base.
## Outlines (not convex pieces); empty when no wing reaches the ground.
static func ground_footprint(outline: PackedVector2Array, wall_height: float, kit_height: float = 28.0) -> Array[PackedVector2Array]:
	var base := inset_outline(outline,WALL_FACE_INSET)
	var result: Array[PackedVector2Array] = []
	if base.size() < 3: return result
	var lifted := base.duplicate()
	var drop := maxf(0.0,wall_height-kit_height)
	for index in lifted.size(): lifted[index] += Vector2(0.0,drop)
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(base,lifted):
		if absf(_area(piece)) > 1.0: result.append(piece)
	return result


## Convex casters for the sun: the ground footprint, plus any drawn wing too
## shallow to reach the ground, which keeps its whole wall base as caster.
static func ground_casters(outline: PackedVector2Array, wall_height: float, kit_height: float = 28.0) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for piece: PackedVector2Array in ground_footprint(outline,wall_height,kit_height):
		result.append_array(convex_parts(piece))
	for part: PackedVector2Array in convex_parts(inset_outline(outline,WALL_FACE_INSET)):
		var reached := false
		var part_bounds := bounds_of(part)
		for caster: PackedVector2Array in result:
			if part_bounds.intersection(bounds_of(caster)).get_area() > 1.0:
				reached = true
				break
		if not reached: result.append(part)
	return result


## One convex caster swept along the sun: its hull, the hull inset by the
## penumbra (full shade) and the mitred band between them, where shade
## fades to zero at the outer edge. A band's alpha is an exact plane:
## clamp(dot(p - origin, normal) / width, 0, 1).
static func cast_shape(caster: PackedVector2Array, offset: Vector2, penumbra: float) -> Dictionary:
	var cloud := caster.duplicate()
	for point: Vector2 in caster: cloud.append(point+offset)
	var hull := _open(Geometry2D.convex_hull(cloud))
	var box := bounds_of(hull)
	var width := minf(penumbra,minf(box.size.x,box.size.y)*0.2)
	var shape := {"hull":hull,"core":hull,"bands":[],"bounds":box}
	if width < 0.5 or hull.size() < 3: return shape
	var inner := _inset_convex(hull,width)
	if inner.size() != hull.size(): return shape
	shape.core = inner
	var bands: Array[Dictionary] = []
	for index in hull.size():
		var a := hull[index]
		var b := hull[(index+1)%hull.size()]
		var quad := PackedVector2Array([a,b,inner[(index+1)%hull.size()],inner[index]])
		if absf(_area(quad)) <= EPS: continue
		bands.append({"points":quad,"origin":a,"normal":_inward_normal(hull,index),"width":width})
	shape.bands = bands
	return shape


## Disjoint soft cast faces for `own` casters (cast_shape dictionaries with an
## integer "key"). Every other nearby caster's full-shade core is excluded so
## no ground darkens twice; earlier keys own shared shade. Receivers are cut
## out and the result stays inside `clip`. Returns points, faces and colours
## ready for one Polygon2D, plus the exact core pieces drawn.
static func soft_cast(own: Array[Dictionary], others: Array[Dictionary], receivers: Array[PackedVector2Array], clip: Rect2) -> Dictionary:
	var everyone: Array[Dictionary] = own.duplicate()
	everyone.append_array(others)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var faces: Array[PackedInt32Array] = []
	var cores: Array[PackedVector2Array] = []
	for shape: Dictionary in own:
		var key := int(shape.key)
		var area := shape.bounds as Rect2
		var core_cuts: Array[PackedVector2Array] = []
		var band_cuts: Array[PackedVector2Array] = []
		for other: Dictionary in everyone:
			if is_same(other,shape) or not (other.bounds as Rect2).grow(1.0).intersects(area): continue
			band_cuts.append(other.core as PackedVector2Array)
			if int(other.key) < key:
				core_cuts.append(other.core as PackedVector2Array)
				for band: Dictionary in other.bands: band_cuts.append(band.points as PackedVector2Array)
		var local_receivers := _near(receivers,area)
		var core_pieces: Array[PackedVector2Array] = [shape.core as PackedVector2Array]
		for piece: PackedVector2Array in subtract_convex(subtract_convex(core_pieces,core_cuts),local_receivers):
			var clipped := clip_to_rect(piece,clip)
			if clipped.size() < 3: continue
			cores.append(clipped)
			_append_face(points,colors,faces,clipped,Vector2.ZERO,Vector2.ZERO,0.0)
		for band: Dictionary in shape.bands:
			var band_pieces: Array[PackedVector2Array] = [band.points as PackedVector2Array]
			for piece: PackedVector2Array in subtract_convex(subtract_convex(band_pieces,band_cuts),local_receivers):
				var clipped := clip_to_rect(piece,clip)
				if clipped.size() < 3: continue
				_append_face(points,colors,faces,clipped,band.origin,band.normal,float(band.width))
	return {"points":points,"colors":colors,"faces":faces,"cores":cores}


## Convex subtraction that leaves a subject whole unless a cut really
## overlaps it (separating axes), so faces are not split needlessly.
static func subtract_convex(subjects: Array[PackedVector2Array], cuts: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = subjects.duplicate()
	var boxes: Array[Rect2] = []
	var reach := Rect2()
	for subject: PackedVector2Array in result:
		var box := bounds_of(subject)
		boxes.append(box)
		reach = box if not reach.has_area() else reach.merge(box)
	for cut: PackedVector2Array in cuts:
		if cut.size() < 3: continue
		var cut_bounds := bounds_of(cut)
		if not cut_bounds.intersects(reach): continue
		var next: Array[PackedVector2Array] = []
		var next_boxes: Array[Rect2] = []
		for index in result.size():
			var subject := result[index]
			if not boxes[index].intersects(cut_bounds) or not convex_overlap(subject,cut):
				next.append(subject)
				next_boxes.append(boxes[index])
				continue
			var single: Array[PackedVector2Array] = [subject]
			var single_cut: Array[PackedVector2Array] = [cut]
			for piece: PackedVector2Array in difference(single,single_cut):
				next.append(piece)
				next_boxes.append(bounds_of(piece))
		result = next
		boxes = next_boxes
		if result.is_empty(): break
	return result


## True when two convex polygons share interior area (no separating axis).
static func convex_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for polygon: PackedVector2Array in [a,b]:
		for index in polygon.size():
			var edge := polygon[(index+1)%polygon.size()]-polygon[index]
			if edge.length_squared() <= EPS: continue
			var axis := Vector2(-edge.y,edge.x)
			var a_min := INF
			var a_max := -INF
			for point: Vector2 in a:
				var value := axis.dot(point)
				a_min = minf(a_min,value)
				a_max = maxf(a_max,value)
			var b_min := INF
			var b_max := -INF
			for point: Vector2 in b:
				var value := axis.dot(point)
				b_min = minf(b_min,value)
				b_max = maxf(b_max,value)
			var tolerance := 0.01*sqrt(axis.length_squared())
			if a_max <= b_min+tolerance or b_max <= a_min+tolerance: return false
	return true


## Wall-base contact shade along a ground footprint: strips outside every
## edge facing south, west or east (each Vector2(width_px, strength)),
## softened convex corners and a small patch in each reflex corner
## (Vector2(size_px, strength)). Door cuts and receivers are removed.
## Returns faces as soft_cast does.
static func contact_shade(ground: Array[PackedVector2Array], south: Vector2, west: Vector2, east: Vector2, corner: Vector2, cuts: Array[PackedVector2Array], clip: Rect2) -> Dictionary:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var faces: Array[PackedInt32Array] = []
	for outline: PackedVector2Array in ground:
		var count := outline.size()
		if count < 3: continue
		var normals: Array[Vector2] = []
		var specs: Array[Vector2] = []
		for index in count:
			var normal := -_inward_normal(outline,index)
			normals.append(normal)
			var spec := Vector2.ZERO
			if normal.y > 0.5: spec = south
			elif normal.x < -0.5: spec = west
			elif normal.x > 0.5: spec = east
			specs.append(spec)
		for index in count:
			var spec := specs[index]
			if spec.x <= 0.0 or spec.y <= 0.0: continue
			var a := outline[index]
			var b := outline[(index+1)%count]
			var normal := normals[index]
			var strip: Array[PackedVector2Array] = [PackedVector2Array([a,b,b+normal*spec.x,a+normal*spec.x])]
			for piece: PackedVector2Array in subtract_convex(strip,_near(cuts,bounds_of(strip[0]))):
				var clipped := clip_to_rect(piece,clip)
				if clipped.size() < 3: continue
				_append_face(points,colors,faces,clipped,a+normal*spec.x,-normal,spec.x,spec.y)
		for index in count:
			var previous := (index-1+count)%count
			var at := outline[index]
			var before := specs[previous]
			var after := specs[index]
			var incoming := outline[index]-outline[previous]
			var outgoing := outline[(index+1)%count]-outline[index]
			var turn := incoming.cross(outgoing)
			# Straight-through vertices (collinear output points) are no corner.
			if absf(turn) <= 0.05*incoming.length()*outgoing.length(): continue
			var convex := (turn > 0.0) == (_area(outline) > 0.0)
			var patch := PackedVector2Array()
			var shades := PackedFloat32Array()
			if convex and before.x > 0.0 and after.x > 0.0:
				var n0 := normals[previous]*before.x
				var n1 := normals[index]*after.x
				patch = PackedVector2Array([at,at+n0,at+n0+n1,at+n1])
				shades = PackedFloat32Array([(before.y+after.y)*0.5,0.0,0.0,0.0])
			elif not convex and (before.x > 0.0 or after.x > 0.0) and corner.x > 0.0:
				var into := (normals[previous]+normals[index]).normalized()
				var across := Vector2(-into.y,into.x)
				patch = PackedVector2Array([at,at+(into+across)*corner.x*0.7,at+into*corner.x,at+(into-across)*corner.x*0.7])
				shades = PackedFloat32Array([corner.y,0.0,0.0,0.0])
			if patch.size() < 3 or absf(_area(patch)) <= EPS: continue
			var blocked := false
			for cut: PackedVector2Array in _near(cuts,bounds_of(patch)):
				if convex_overlap(patch,cut):
					blocked = true
					break
			if blocked: continue
			var start := points.size()
			var face := PackedInt32Array()
			for corner_index in patch.size():
				points.append(patch[corner_index])
				colors.append(Color(1,1,1,shades[corner_index]))
				face.append(start+corner_index)
			faces.append(face)
	return {"points":points,"colors":colors,"faces":faces}


## Every drawn face of a (possibly multi-face) Polygon2D, as outlines.
static func faces_of(shape: Polygon2D) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if shape.polygons.is_empty():
		result.append(shape.polygon)
		return result
	for face_value: Variant in shape.polygons:
		var face := PackedVector2Array()
		for index: int in (face_value as PackedInt32Array): face.append(shape.polygon[index])
		result.append(face)
	return result


static func clip_to_rect(points: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	if not rect.has_area(): return points
	if rect.encloses(bounds_of(points)): return points
	var result := points
	for edge: Array in [[rect.position,Vector2(rect.end.x,rect.position.y)],[Vector2(rect.end.x,rect.position.y),rect.end],[rect.end,Vector2(rect.position.x,rect.end.y)],[Vector2(rect.position.x,rect.end.y),rect.position]]:
		if result.size() < 3: break
		var side := 1.0 if (edge[1]-edge[0]).cross(rect.get_center()-edge[0]) > 0.0 else -1.0
		result = _half_plane(result,edge[0],edge[1],side)
	if result.size() < 3 or absf(_area(result)) <= EPS: return PackedVector2Array()
	return result


static func _append_face(points: PackedVector2Array, colors: PackedColorArray, faces: Array[PackedInt32Array], piece: PackedVector2Array, origin: Vector2, normal: Vector2, width: float, strength: float = 1.0) -> void:
	var start := points.size()
	var face := PackedInt32Array()
	for index in piece.size():
		var point := piece[index]
		var alpha := strength
		if width > 0.0: alpha = strength*clampf((point-origin).dot(normal)/width,0.0,1.0)
		points.append(point)
		colors.append(Color(1,1,1,alpha))
		face.append(start+index)
	faces.append(face)


static func _near(polygons: Array[PackedVector2Array], area: Rect2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in polygons:
		if bounds_of(polygon).intersects(area): result.append(polygon)
	return result


static func _open(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if result.size() > 1 and result[0].is_equal_approx(result[-1]): result.remove_at(result.size()-1)
	return result


## Unit normal of edge `index` pointing into a simple polygon.
static func _inward_normal(polygon: PackedVector2Array, index: int) -> Vector2:
	var a := polygon[index]
	var b := polygon[(index+1)%polygon.size()]
	var edge := (b-a).normalized()
	var normal := Vector2(-edge.y,edge.x)
	return normal if _area(polygon) > 0.0 else -normal


## Mitred inset of a convex polygon; empty when an edge would collapse.
static func _inset_convex(polygon: PackedVector2Array, width: float) -> PackedVector2Array:
	var count := polygon.size()
	var result := PackedVector2Array()
	for index in count:
		var n0 := _inward_normal(polygon,(index-1+count)%count)
		var n1 := _inward_normal(polygon,index)
		var denominator := 1.0+n0.dot(n1)
		if denominator < 0.15: return PackedVector2Array()
		result.append(polygon[index]+(n0+n1)*width/denominator)
	for index in count:
		var original := polygon[(index+1)%count]-polygon[index]
		var inset := result[(index+1)%count]-result[index]
		if original.dot(inset) <= 0.0: return PackedVector2Array()
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
