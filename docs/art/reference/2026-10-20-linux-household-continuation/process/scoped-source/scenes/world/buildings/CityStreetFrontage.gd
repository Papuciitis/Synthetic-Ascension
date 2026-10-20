extends RefCounted
## Small shared S2 footways, fitted to the generated parcels. No physics or RNG.

const GEOMETRY := preload("res://scenes/world/buildings/CityFootprintGeometry.gd")
const EDGE_SHADER := preload("res://scenes/world/buildings/city_footway.gdshader")

static func plan(box: Rect2, doors: Array, cell: int, extent: Rect2, lane_h: Rect2 = Rect2(), lane_v: Rect2 = Rect2(), outline: PackedVector2Array = PackedVector2Array()) -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for polygon: PackedVector2Array in _approaches(box,doors,cell,extent,lane_h,lane_v,outline):
		bounds.append(GEOMETRY.bounds_of(polygon))
	return bounds


## A doorway-sized walking approach with shoulders opening toward the street.
## It does not pave the full house frontage. The small fixed asymmetry follows
## the door position; no procedural RNG or walkability is consumed/changed.
static func _approaches(box: Rect2, doors: Array, cell: int, extent: Rect2, lane_h: Rect2, lane_v: Rect2, outline: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for door: Dictionary in doors:
		var direction: Vector2i = door.dir
		var outward := Vector2(direction)
		var tangent := Vector2(direction.y,-direction.x)
		var edge := _entry_edge(box,outline,door,cell)
		var center := _door_center(door,cell)
		if direction.y != 0: center.y = edge.x
		else: center.x = edge.x
		var reach := cell*1.75
		var lane := lane_h if direction.y != 0 else lane_v
		if lane.has_area():
			var distance_to_lane := 0.0
			if direction == Vector2i.DOWN: distance_to_lane = lane.position.y-center.y
			elif direction == Vector2i.UP: distance_to_lane = center.y-lane.end.y
			elif direction == Vector2i.RIGHT: distance_to_lane = lane.position.x-center.x
			else: distance_to_lane = center.x-lane.end.x
			if distance_to_lane >= 0.0 and distance_to_lane <= cell*4.0:
				reach = distance_to_lane+cell*0.5
		var neck := maxi(1,int(door.get("width",2)))*cell*0.5+cell*0.5
		var shoulder := neck+cell*0.5
		var drift := sin(center.x*0.013+center.y*0.009)*cell*0.12
		var shape := PackedVector2Array()
		for point: Vector2 in [Vector2(-neck,0),Vector2(neck,0),Vector2(neck+cell*0.18,reach*0.32),Vector2(shoulder+drift,reach*0.75),Vector2(shoulder-cell*0.25+drift,reach),Vector2(-shoulder+cell*0.3+drift,reach),Vector2(-shoulder+drift,reach*0.68),Vector2(-neck-cell*0.12,reach*0.28)]:
			shape.append(center+tangent*point.x+outward*point.y)
		for clipped: PackedVector2Array in Geometry2D.intersect_polygons(shape,GEOMETRY.rect_polygon(extent)):
			result.append(clipped)
	return result


static func _door_center(door: Dictionary, cell: int) -> Vector2:
	var direction: Vector2i = door.dir
	var perpendicular := Vector2i(-direction.y,direction.x)
	var width := maxi(1,int(door.get("width",2)))
	var first: Vector2i = door.pos-perpendicular*(width>>1)
	return (Vector2(first)+Vector2.ONE*0.5+Vector2(perpendicular)*float(width-1)*0.5)*cell

## x is the front coordinate; y/z are the supported span along that edge.
static func _entry_edge(box: Rect2, outline: PackedVector2Array, door: Dictionary, cell: int) -> Vector3:
	var direction: Vector2i = door.dir
	var result := Vector3(box.end.y if direction.y > 0 else box.position.y,box.position.x,box.end.x) if direction.y != 0 else Vector3(box.end.x if direction.x > 0 else box.position.x,box.position.y,box.end.y)
	if outline.size() < 3: return result
	var center := _door_center(door,cell)
	var nearest := INF
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index+1)%outline.size()]
		if direction.y != 0 and not is_equal_approx(a.y,b.y): continue
		if direction.x != 0 and not is_equal_approx(a.x,b.x): continue
		var midpoint := (a+b)*0.5
		if Geometry2D.is_point_in_polygon(midpoint+Vector2(direction),outline): continue
		var contact := Geometry2D.get_closest_point_to_segment(center,a,b)
		var distance := contact.distance_squared_to(center)
		if distance >= nearest: continue
		nearest = distance
		result = Vector3(a.y,minf(a.x,b.x),maxf(a.x,b.x)) if direction.y != 0 else Vector3(a.x,minf(a.y,b.y),maxf(a.y,b.y))
	return result

static func subtract(areas: Array, cuts: Array[Rect2]) -> Array[Rect2]:
	var pieces: Array[Rect2] = []
	for area: Rect2 in areas:
		if area.has_area(): pieces.append(area)
	for cut: Rect2 in cuts:
		var remaining: Array[Rect2] = []
		for area: Rect2 in pieces:
			var overlap := area.intersection(cut)
			if not overlap.has_area():
				remaining.append(area)
				continue
			for piece: Rect2 in [Rect2(area.position,Vector2(area.size.x,overlap.position.y-area.position.y)),Rect2(area.position.x,overlap.end.y,area.size.x,area.end.y-overlap.end.y),Rect2(area.position.x,overlap.position.y,overlap.position.x-area.position.x,overlap.size.y),Rect2(overlap.end.x,overlap.position.y,area.end.x-overlap.end.x,overlap.size.y)]:
				if piece.has_area(): remaining.append(piece)
		pieces = remaining
	return pieces

static func compose(chunk: Node2D, footprints: Array[Rect2i], cell: int, cells: int, lane_h: Rect2i = Rect2i(), lane_v: Rect2i = Rect2i()) -> void:
	var areas: Array[PackedVector2Array] = []
	var extent := Rect2(0,0,cells*cell,cells*cell)
	var horizontal := Rect2(Vector2(lane_h.position)*cell,Vector2(lane_h.size)*cell)
	var vertical := Rect2(Vector2(lane_v.position)*cell,Vector2(lane_v.size)*cell)
	var cuts := GEOMETRY.occupied_parts(chunk,footprints,cell)
	for kit: Node in chunk.get_children():
		if not kit.is_in_group(&"city_block_building"): continue
		areas.append_array(_approaches(kit.get("bounds"),kit.get("_doors"),cell,extent,horizontal,vertical,GEOMETRY.outline_for(kit)))
	# Subtract earlier surfaces too: overlaps must not darken at lot joins.
	var occupied: Array[PackedVector2Array] = cuts.duplicate()
	var group := Node2D.new()
	group.name = "ConnectedStreetFrontages"
	group.z_index = -93
	chunk.add_child(group)
	if areas.is_empty(): return
	# All splits share the same external boundary. A piece created by a
	# neighbor/parcel cut is not a new verge and must not grow an alpha seam.
	var material := ShaderMaterial.new()
	material.shader = EDGE_SHADER
	for entry: Array in [["street_h",horizontal],["street_v",vertical]]:
		var lane: Rect2 = entry[1]
		material.set_shader_parameter(entry[0],Vector4(lane.position.x,lane.position.y,lane.end.x,lane.end.y) if lane.has_area() else Vector4.ZERO)
	var edges := _external_edges(areas,cuts,[horizontal,vertical])
	var edge_image := Image.create(maxi(1,edges.size()),1,false,Image.FORMAT_RGBAF)
	for index in edges.size():
		var edge := edges[index]
		edge_image.set_pixel(index,0,Color(edge.x,edge.y,edge.z,edge.w))
	material.set_shader_parameter("external_edges",ImageTexture.create_from_image(edge_image))
	material.set_shader_parameter("external_edge_count",edges.size())
	for area: PackedVector2Array in areas:
		var candidates := GEOMETRY.convex_parts(area)
		for piece: PackedVector2Array in GEOMETRY.difference(candidates,occupied):
			var paving := Polygon2D.new()
			paving.name = "ParcelFootway"
			paving.polygon = piece
			paving.texture = preload("res://scenes/world/buildings/CityBlockKit.gd")._texture("paving.png")
			paving.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			paving.texture_scale = Vector2.ONE*3.0
			paving.material = material
			group.add_child(paving)
			occupied.append(piece)

## Only the outside of the complete footway union is a fading verge.
## A float texel per segment avoids a fixed shader cap or a material per
## subtraction piece. This small descriptor lives/frees with its chunk.
static func _external_edges(areas: Array[PackedVector2Array], cuts: Array[PackedVector2Array], lanes: Array[Rect2]) -> Array[Vector4]:
	var result: Array[Vector4] = []
	var seen: Dictionary = {}
	var boundaries: Array[PackedVector2Array] = areas.duplicate()
	boundaries.append_array(cuts)
	for lane: Rect2 in lanes:
		if lane.has_area(): boundaries.append(GEOMETRY.rect_polygon(lane))
	for area: PackedVector2Array in areas:
		for side: int in area.size():
			var a := area[side]
			var b := area[(side+1)%area.size()]
			var direction := b-a
			if direction.length_squared() < 0.001: continue
			var normal := Vector2(direction.y,-direction.x).normalized()
			# Clipper winding is not an outward-normal contract.
			if Geometry2D.is_point_in_polygon((a+b)*0.5+normal*0.1,area): normal = -normal
			var levels: Array[float] = [0.0,1.0]
			for other: PackedVector2Array in boundaries:
				for edge: int in other.size():
					var c := other[edge]
					var d := other[(edge+1)%other.size()]
					var crossing: Variant = Geometry2D.segment_intersects_segment(a,b,c,d)
					if crossing != null:
						var along := ((crossing as Vector2)-a).dot(direction)/direction.length_squared()
						if along > 0.0001 and along < 0.9999 and not levels.has(along): levels.append(along)
					# Collinear joins still need their endpoints to split a side.
					for point: Vector2 in [c,d]:
						if absf(direction.cross(point-a)) > 0.01: continue
						var along := (point-a).dot(direction)/direction.length_squared()
						if along > 0.0001 and along < 0.9999 and not levels.has(along): levels.append(along)
			levels.sort()
			for index: int in range(levels.size()-1):
				if levels[index+1]-levels[index] < 0.0001: continue
				var start := a+direction*levels[index]
				var end := a+direction*levels[index+1]
				var outside := (start+end)*0.5+normal*0.1
				var boundary := true
				for other: PackedVector2Array in areas:
					if Geometry2D.is_point_in_polygon(outside,other): boundary = false
				for cut: PackedVector2Array in cuts:
					if Geometry2D.is_point_in_polygon(outside,cut): boundary = false
				for lane: Rect2 in lanes:
					if lane.has_area() and lane.has_point(outside): boundary = false
				var edge := Vector4(start.x,start.y,end.x,end.y)
				if boundary and not seen.has(edge):
					seen[edge] = true
					result.append(edge)
	return result
