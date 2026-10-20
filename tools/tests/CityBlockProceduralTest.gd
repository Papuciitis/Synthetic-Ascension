extends Node2D
## The real frontage generator, rather than hand-positioned sample buildings.

var _passed := 0
var _failed := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: _passed += 1
	else:
		_failed += 1
		push_error(message)

func _fixture(seed_value: int, styled: bool, road_kind: int, origin: Vector2 = Vector2.ZERO) -> Dictionary:
	var cm := ChunkManager.new()
	cm.world_seed = seed_value
	cm.generation_enabled = false
	cm.ground_enabled = false
	cm.ground_splat_enabled = false
	cm.decals_enabled = false
	cm.deco_enabled = false
	cm.sites_enabled = false
	cm.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn")
	cm.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn")
	add_child(cm)
	cm._gen_coord = Vector2i.ZERO
	cm._chunk_blocked[Vector2i.ZERO] = []
	cm._active_build_data = ChunkBuildData.new(Vector2i.ZERO,32)
	var chunk := Node2D.new()
	chunk.position = origin
	cm.add_child(chunk)
	var horizontal := Rect2i(0,14,32,3) if road_kind != 1 else Rect2i()
	var vertical := Rect2i(14,0,3,32) if road_kind != 0 else Rect2i()
	if road_kind == 3:
		horizontal = Rect2i(14,14,18,3)
		vertical = Rect2i(14,0,3,17)
	elif road_kind == 4:
		vertical = Rect2i(14,0,3,17)
	var keepouts: Array[Rect2i] = []
	for lane: Rect2i in [horizontal,vertical]:
		if lane.has_area(): keepouts.append(lane.grow(1))
	var cfg := {"city_block_style":styled,"secondary_objective_id":41,"local_encounter_enabled":false,"force_parcel":true,"parcel_depth_cells":10,"parcel_length_min_cells":7,"parcel_length_max_cells":13}
	var placed := SiteParcelsImpl.new().decorate_district_parcels(cm,chunk,Vector2i.ZERO,horizontal,vertical,keepouts,cfg)
	return {"cm":cm,"chunk":chunk,"data":cm._active_build_data,"placed":placed,"horizontal":horizontal,"vertical":vertical}

func _signature(fixture: Dictionary) -> Dictionary:
	var cells := PackedInt32Array()
	var data: ChunkBuildData = fixture.data
	for y in range(32):
		for x in range(32):
			var cell := Vector2i(x,y)
			cells.append(WorldBlockerGeometry.pack(data.kind_at(cell),data.mask_at(cell)))
	var volumes: Array[String] = []
	for child: Node in fixture.chunk.get_children():
		if child is IndoorVolume:
			volumes.append("%d:%s:%s" % [child.building_id,str(child.to_global(child.get("_presentation_entry"))),str(child.get("_presentation_outward"))])
	return {"cells":cells,"volumes":volumes,"placed":fixture.placed}

func _run() -> void:
	var previous_segment: int = Global.attempt_segment
	Global.attempt_segment = 2
	var kit_script := preload("res://scenes/world/buildings/CityBlockKit.gd")
	for role: StringName in [&"secondary_reward_building", &"secondary_route", &"service_lane", &"district_fill", &"dangerous_alley", &"main_route"]:
		_check(kit_script.enabled_for(role, 2), "S2 neighboring production parcels carry the accepted city families: " + String(role))
		_check(not kit_script.enabled_for(role, 1), "family rollout stays in S2")
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	var layouts: Dictionary = {}
	var sizes: Dictionary = {}
	var directions: Dictionary = {}
	var buildings := 0
	var kit_instances := 0
	var kit_sizes: Dictionary = {}
	for seed_value in [17,211,2026,16102026]:
		for road_kind in range(5):
			var styled := _fixture(seed_value,true,road_kind)
			var plain := _fixture(seed_value,false,road_kind)
			var repeat := _fixture(seed_value,true,road_kind)
			_check(not styled.placed.is_empty(),"seeded frontage must generate actual parcels")
			_check(_signature(styled) == _signature(plain),"styling preserves generated shapes, real doors, blockers and identities")
			_check(_signature(styled) == _signature(repeat),"same seed and road arms regenerate the same block")
			_check_ground(styled, repeat)
			layouts[str(styled.placed)] = true
			var styled_count := 0
			for candidate: Node in styled.chunk.get_children():
				if candidate.is_in_group(&"city_block_building"):
					styled_count += 1
					_check(candidate.get("_facade") != null or candidate.has_meta(&"city_irregular_outline"), "every direction has inhabited frontage or an explicit footprint fallback")
					var cover: RoofOverlay = candidate.get("_roof")
					for door: Dictionary in cover._doors:
						var gap := preload("res://scenes/world/buildings/CityBlockFrontages.gd")._door_box(door,64).grow(-1)
						var cut := PackedVector2Array([gap.position,Vector2(gap.end.x,gap.position.y),gap.end,Vector2(gap.position.x,gap.end.y)])
						for plane: Node in cover.get_node("RoofPoly").find_children("*","Polygon2D",true,false):
							if plane.get_parent().name != &"CityRoofComposition": continue
							_check(Geometry2D.intersect_polygons(plane.polygon,cut).is_empty(), "compound roof caps preserve real doorway: door=%s plane=%s polygon=%s" % [str(door),plane.name,str(plane.polygon)])
			_check(styled_count == styled.placed.size(), "irregular and rectangular parcels both receive the family")
			for parcel: Rect2i in styled.placed:
				sizes[str(parcel.size)] = true
				buildings += 1
			for child: Node in styled.chunk.get_children():
				if child.is_in_group(&"city_block_building"):
					kit_instances += 1
					var footprint: Rect2i = child.get_meta(&"footprint_cells")
					kit_sizes[str(footprint.size)] = true
				if child is IndoorVolume:
					var outward: Vector2 = child.get("_presentation_outward")
					directions[str(outward)] = true
					var door: Vector2 = child.to_global(child.get("_presentation_entry"))
					_check((styled.data as ChunkBuildData).kind_at(styled.cm.world_to_cell(door)) < 0,"generated real entry remains open")
			for lane: Rect2i in [styled.horizontal,styled.vertical]:
				for y in range(lane.position.y,lane.end.y):
					for x in range(lane.position.x,lane.end.x):
						_check((styled.data as ChunkBuildData).kind_at(Vector2i(x,y)) < 0,"generation preserves the road connector")
			for fixture: Dictionary in [styled,plain,repeat]: fixture.cm.queue_free()
			await get_tree().process_frame
	_check(layouts.size() >= 4,"different seeds produce visibly different layouts")
	_check(sizes.size() >= 3,"the kit is exercised at multiple generated parcel sizes")
	_check(directions.size() == 4,"procedural layout sweep covers all four entrance directions")
	_check(kit_sizes.size() >= 3,"styled rectangular kit itself supports multiple generated sizes")
	var shifted := _fixture(17,true,3,Vector2(4096,18432))
	var shifted_repeat := _fixture(17,true,3,Vector2(4096,18432))
	_check_ground(shifted,shifted_repeat)
	for kit: Node in shifted.chunk.get_children():
		for surface: Node in kit.get_children():
			if surface is Polygon2D and surface.has_meta(&"city_paving"):
				_check((surface.material as ShaderMaterial).get_shader_parameter("ground_origin") == Vector2(4096,18432),"ground textures retain world alignment in a translated streamed chunk")
	shifted.cm.queue_free()
	shifted_repeat.cm.queue_free()
	Global.attempt_segment = previous_segment
	print("CityBlockProceduralTest: %d passed, %d failed; 20 layouts, %d parcels, %d unique layouts, %d sizes, %d entrance directions, %d styled kit instances across %d sizes" % [_passed,_failed,buildings,layouts.size(),sizes.size(),directions.size(),kit_instances,kit_sizes.size()])
	get_tree().quit(1 if _failed > 0 else 0)

func _check_ground(fixture: Dictionary, repeated: Dictionary) -> void:
	var surfaces: Array[Polygon2D] = []
	var shadows: Array[Polygon2D] = []
	var receivers: Dictionary = {}
	for kit: Node in fixture.chunk.get_children():
		if kit.is_in_group(&"city_block_building"):
			var roof := kit.get("_roof") as RoofOverlay
			var rect: Rect2i = kit.get_meta(&"footprint_cells")
			_check(roof != null and roof.footprint_outline_px.size() >= 3,"each actual placed kit supplies its occupied roof outline")
			_check(not receivers.has(rect),"each placed parcel has one actual occupied receiver")
			if roof != null and roof.footprint_outline_px.size() >= 3:
				receivers[rect] = roof
				_check_receiver_detector(roof)
		for child: Node in kit.get_children():
			if child.has_meta(&"city_ground_contact"):
				var rect: Rect2i = kit.get_meta(&"footprint_cells")
				_check(Rect2(Vector2(rect.position)*64,Vector2(rect.size)*64).has_point(child.get_meta(&"city_ground_contact")),"tree/planter physical contact stays on the actual occupied corner band")
			if child is Polygon2D and child.has_meta(&"city_paving"):
				surfaces.append(child)
			if child is Polygon2D and child.has_meta(&"city_sun_shadow"): shadows.append(child)
	_check(not surfaces.is_empty(), "generated blocks have exterior surfaces")
	if surfaces.is_empty(): return
	_check(receivers.size() == fixture.placed.size(),"shadow receiver set retains every actual placed parcel")
	var material := surfaces[0].material as ShaderMaterial
	var road_h: Variant = material.get_shader_parameter("road_h")
	var road_v: Variant = material.get_shader_parameter("road_v")
	for pair: Array in [[road_h,fixture.horizontal],[road_v,fixture.vertical]]:
		var lane: Rect2i = pair[1]
		var expected := Vector4(lane.position.x*64,lane.position.y*64,lane.end.x*64,lane.end.y*64) if lane.has_area() else Vector4.ZERO
		_check(pair[0] == expected, "ground road ownership follows actual arms, including missing L/T branches")
	for surface: Polygon2D in surfaces:
		var inside_chunk := true
		for point: Vector2 in surface.polygon:
			inside_chunk = inside_chunk and point.x >= 0.0 and point.y >= 0.0 and point.x <= 2048.0 and point.y <= 2048.0
		_check(inside_chunk,"composed frontage never paints over an uninspected neighboring chunk or interior")
		for rect: Rect2i in fixture.placed:
			var cut := Rect2(Vector2(rect.position)*64,Vector2(rect.size)*64)
			var box := PackedVector2Array([cut.position,Vector2(cut.end.x,cut.position.y),cut.end,Vector2(cut.position.x,cut.end.y)])
			var overlap := Geometry2D.intersect_polygons(surface.polygon,box)
			_check(overlap.is_empty(), "outdoor road/soil/grass treatment never paints a building interior")
	for shadow: Polygon2D in shadows:
		if shadow.texture != null:
			var shrub := load("res://assets/world/dressing/generated/olive_shrub.tres") as AtlasTexture
			_check(not shadow.texture is AtlasTexture,"foliage polygon resolves the atlas source before drawing")
			var region := shrub.region if shadow.texture == shrub.atlas else Rect2(Vector2.ZERO,shadow.texture.get_size())
			for uv: Vector2 in shadow.uv:
				_check(region.grow(0.1).has_point(uv),"clipped foliage shadow UVs stay inside their actual source image region")
		for rect: Rect2i in fixture.placed:
			var receiver := receivers.get(rect) as RoofOverlay
			_check(receiver != null and not _shadow_overlaps_receiver(shadow,receiver),"building sun shadows exclude every actual occupied receiver: seed=%d parcel=%s" % [fixture.cm.world_seed,str(rect)])
	var repeated_material: ShaderMaterial
	for kit: Node in repeated.chunk.get_children():
		for child: Node in kit.get_children():
			if child is Polygon2D and child.has_meta(&"city_paving"): repeated_material = child.material
	_check(repeated_material != null and material.get_shader_parameter("ground_origin") == repeated_material.get_shader_parameter("ground_origin"), "surface variation regenerates at the same world coordinates")


func _shadow_overlaps_receiver(shadow: Polygon2D, receiver: RoofOverlay) -> bool:
	# Independent live occupancy, rather than the caster's subtraction helper
	# or the parcel bounding rectangle: an L notch is actual exterior ground.
	var occupied := PackedVector2Array()
	for point: Vector2 in receiver.footprint_outline_px:
		occupied.append(shadow.to_local(receiver.to_global(point)))
	return not Geometry2D.intersect_polygons(shadow.polygon,occupied).is_empty()


func _check_receiver_detector(receiver: RoofOverlay) -> void:
	var outline := receiver.footprint_outline_px
	var triangles := Geometry2D.triangulate_polygon(outline)
	_check(triangles.size() >= 3,"actual receiver contains a triangulated positive interior probe")
	if triangles.size() < 3: return
	var triangle := PackedVector2Array([outline[triangles[0]],outline[triangles[1]],outline[triangles[2]]])
	var center := (triangle[0]+triangle[1]+triangle[2])/3.0
	var probe := Polygon2D.new()
	probe.position = Vector2(73,-31)
	probe.rotation = 0.17
	probe.scale = Vector2(0.8,1.2)
	add_child(probe)
	var points := PackedVector2Array()
	for point: Vector2 in triangle:
		points.append(probe.to_local(receiver.to_global(center+(point-center)*0.25)))
	probe.polygon = points
	_check(_shadow_overlaps_receiver(probe,receiver),"shadow occupancy detector rejects deliberate real-interior overlap across transforms")
	probe.free()
