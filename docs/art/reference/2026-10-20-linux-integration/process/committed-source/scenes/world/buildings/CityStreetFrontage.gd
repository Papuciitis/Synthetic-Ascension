extends RefCounted
## Small shared S2 footways, fitted to the generated parcels. No physics or RNG.

const GEOMETRY := preload("res://scenes/world/buildings/CityFootprintGeometry.gd")
const EDGE_SHADER := preload("res://scenes/world/buildings/city_footway.gdshader")

static func plan(box: Rect2, doors: Array, cell: int, extent: Rect2, lane_h: Rect2 = Rect2(), lane_v: Rect2 = Rect2(), outline: PackedVector2Array = PackedVector2Array()) -> Array[Rect2]:
	var areas: Array[Rect2] = []
	for door: Dictionary in doors:
		var direction: Vector2i = door.dir
		var edge := _entry_edge(box,outline,door,cell)
		var apron := box
		if direction.y != 0:
			var front := edge.x
			apron.position.x = edge.y-cell*0.25
			apron.size.x = edge.z-edge.y+cell*0.5
			var reach := cell*1.75
			if lane_h.has_area():
				var distance_to_lane := lane_h.position.y-front if direction.y > 0 else front-lane_h.end.y
				if distance_to_lane >= 0 and distance_to_lane <= cell*4: reach = distance_to_lane+cell*0.5
			apron.position.y = front if direction.y > 0 else front-reach
			apron.size.y = reach
		else:
			var front := edge.x
			var reach := cell*1.75
			if lane_v.has_area():
				var distance_to_lane := lane_v.position.x-front if direction.x > 0 else front-lane_v.end.x
				if distance_to_lane >= 0 and distance_to_lane <= cell*4: reach = distance_to_lane+cell*0.5
			apron.position.x = front if direction.x > 0 else front-reach
			apron.size.x = reach
			# A side entry has a local landing, not a slab along the entire house.
			var center := _door_center(door,cell).y
			var half_width := (maxi(1,int(door.get("width",2)))+1)*cell*0.5
			apron.position.y = maxf(edge.y-cell*0.25,center-half_width)
			apron.size.y = minf(edge.z+cell*0.25,center+half_width)-apron.position.y
		var clipped := apron.intersection(extent)
		if clipped.has_area(): areas.append(clipped)
	return areas

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
	var areas: Array[Rect2] = []
	var extent := Rect2(0,0,cells*cell,cells*cell)
	var horizontal := Rect2(Vector2(lane_h.position)*cell,Vector2(lane_h.size)*cell)
	var vertical := Rect2(Vector2(lane_v.position)*cell,Vector2(lane_v.size)*cell)
	var cuts := GEOMETRY.occupied_parts(chunk,footprints,cell)
	for kit: Node in chunk.get_children():
		if not kit.is_in_group(&"city_block_building"): continue
		areas.append_array(plan(kit.get("bounds"),kit.get("_doors"),cell,extent,horizontal,vertical,GEOMETRY.outline_for(kit)))
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
	var edges := _external_edges(areas,cuts,[horizontal,vertical])
	var edge_image := Image.create(maxi(1,edges.size()),1,false,Image.FORMAT_RGBAF)
	for index in edges.size():
		var edge := edges[index]
		edge_image.set_pixel(index,0,Color(edge.x,edge.y,edge.z,edge.w))
	material.set_shader_parameter("external_edges",ImageTexture.create_from_image(edge_image))
	material.set_shader_parameter("external_edge_count",edges.size())
	for area: Rect2 in areas:
		var candidates: Array[PackedVector2Array] = [GEOMETRY.rect_polygon(area)]
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
static func _external_edges(areas: Array[Rect2], cuts: Array[PackedVector2Array], lanes: Array[Rect2]) -> Array[Vector4]:
	var result: Array[Vector4] = []
	var seen: Dictionary = {}
	var split_rects: Array[Rect2] = areas.duplicate()
	for cut: PackedVector2Array in cuts: split_rects.append(GEOMETRY.bounds_of(cut))
	split_rects.append_array(lanes)
	for area: Rect2 in areas:
		var corners := GEOMETRY.rect_polygon(area)
		for side in 4:
			var a := corners[side]
			var b := corners[(side+1)%4]
			var horizontal := is_equal_approx(a.y,b.y)
			var normal := Vector2((b-a).y,-(b-a).x).normalized()
			var low := minf(a.x,b.x) if horizontal else minf(a.y,b.y)
			var high := maxf(a.x,b.x) if horizontal else maxf(a.y,b.y)
			var levels: Array[float] = [low,high]
			for other: Rect2 in split_rects:
				var boundaries: Array[float] = []
				if horizontal: boundaries.assign([other.position.x,other.end.x])
				else: boundaries.assign([other.position.y,other.end.y])
				for value: float in boundaries:
					if value > low and value < high and not levels.has(value): levels.append(value)
			levels.sort()
			for index in range(levels.size()-1):
				var start := Vector2(levels[index],a.y) if horizontal else Vector2(a.x,levels[index])
				var end := Vector2(levels[index+1],a.y) if horizontal else Vector2(a.x,levels[index+1])
				var outside := (start+end)*0.5+normal*0.1
				var boundary := true
				for other: Rect2 in areas:
					if other.has_point(outside): boundary = false
				for cut: PackedVector2Array in cuts:
					if Geometry2D.is_point_in_polygon(outside,cut): boundary = false
				for lane: Rect2 in lanes:
					if lane.has_area() and lane.has_point(outside): boundary = false
				var edge := Vector4(start.x,start.y,end.x,end.y)
				if boundary and not seen.has(edge):
					seen[edge] = true
					result.append(edge)
	return result
