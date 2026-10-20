extends RefCounted
## Small shared S2 footways, fitted to the generated parcels. No physics or RNG.

static func plan(box: Rect2, doors: Array, cell: int, extent: Rect2, lane_h: Rect2 = Rect2(), lane_v: Rect2 = Rect2()) -> Array[Rect2]:
	var areas: Array[Rect2] = []
	for door: Dictionary in doors:
		var direction: Vector2i = door.dir
		var apron := box
		if direction.y != 0:
			var reach := cell*1.75
			if lane_h.has_area():
				var distance_to_lane := lane_h.position.y-box.end.y if direction.y > 0 else box.position.y-lane_h.end.y
				if distance_to_lane >= 0 and distance_to_lane <= cell*4: reach = distance_to_lane+cell*0.5
			apron.position.y = box.end.y if direction.y > 0 else box.position.y-reach
			apron.size.y = reach
			apron.position.x -= cell*0.25
			apron.size.x += cell*0.5
		else:
			var reach := cell*1.75
			if lane_v.has_area():
				var distance_to_lane := lane_v.position.x-box.end.x if direction.x > 0 else box.position.x-lane_v.end.x
				if distance_to_lane >= 0 and distance_to_lane <= cell*4: reach = distance_to_lane+cell*0.5
			apron.position.x = box.end.x if direction.x > 0 else box.position.x-reach
			apron.size.x = reach
			# A side entry has a local landing, not a slab along the entire house.
			apron.position.y = float((door.pos as Vector2i).y)*cell-cell
			apron.size.y = cell*3.0
		areas.append(apron.intersection(extent))
	return areas

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
	var cuts: Array[Rect2] = []
	var extent := Rect2(0,0,cells*cell,cells*cell)
	for footprint: Rect2i in footprints:
		cuts.append(Rect2(Vector2(footprint.position)*cell,Vector2(footprint.size)*cell))
	for kit: Node in chunk.get_children():
		if not kit.is_in_group(&"city_block_building"): continue
		areas.append_array(plan(kit.get("bounds"),kit.get("_doors"),cell,extent,Rect2(Vector2(lane_h.position)*cell,Vector2(lane_h.size)*cell),Rect2(Vector2(lane_v.position)*cell,Vector2(lane_v.size)*cell)))
	# Subtract earlier surfaces too: overlaps must not darken at lot joins.
	var occupied := cuts.duplicate()
	var group := Node2D.new()
	group.name = "ConnectedStreetFrontages"
	group.z_index = -93
	chunk.add_child(group)
	for area: Rect2 in areas:
		for piece: Rect2 in subtract([area],occupied):
			var paving := Polygon2D.new()
			paving.name = "ParcelFootway"
			paving.polygon = PackedVector2Array([piece.position,Vector2(piece.end.x,piece.position.y),piece.end,Vector2(piece.position.x,piece.end.y)])
			paving.texture = preload("res://scenes/world/buildings/CityBlockKit.gd")._texture("paving.png")
			paving.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			paving.texture_scale = Vector2.ONE*3.0
			var material := ShaderMaterial.new()
			material.shader = preload("res://scenes/world/buildings/city_paving.gdshader")
			material.set_shader_parameter("area",Vector4(piece.position.x,piece.position.y,piece.end.x,piece.end.y))
			material.set_shader_parameter("edge_feather",1.5)
			material.set_shader_parameter("surface_contrast",0.27)
			material.set_shader_parameter("surface_mid",Vector3(0.57,0.59,0.55))
			paving.material = material
			group.add_child(paving)
			occupied.append(piece)
