extends Node

var _passes := 0
var _failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error(message)

func _fixture(styled: bool, door_dir: Vector2i = Vector2i.DOWN, irregular: bool = false) -> Dictionary:
	var cm := ChunkManager.new()
	cm.world_seed = 16102026
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
	cm._active_build_data = ChunkBuildData.new(Vector2i.ZERO, 32)
	var chunk := Node2D.new()
	cm.add_child(chunk)
	var cfg := {"city_block_style": styled, "secondary_objective_id": 41, "local_encounter_enabled": true}
	var placed: Array[Rect2i] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 16102026
	for rect in [Rect2i(2, 4, 11, 9), Rect2i(15, 4, 9, 9)]:
		var generator := SiteParcelsImpl.new()
		var ok := generator._spawn_building_footprint(cm, chunk, Vector2i.ZERO, rect, door_dir, &"workshop", [], placed, cfg, rng, Rect2i(0,0,32,32)) if irregular else generator._spawn_building_rect(cm, chunk, Vector2i.ZERO, rect, door_dir, &"workshop", [], placed, cfg, rng, Rect2i(0, 0, 32, 32))
		_check(ok, "fixture parcel must place")
	return {"cm": cm, "chunk": chunk, "data": cm._active_build_data}

func _run() -> void:
	var kit_script := preload("res://scenes/world/buildings/CityBlockKit.gd")
	_check(kit_script._texture("wall_lantern.png") == kit_script._texture("wall_lantern.png"),"streamed family instances share original texture resources")
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var plain := _fixture(false)
	var styled := _fixture(true)
	var data_a: ChunkBuildData = plain.data
	var data_b: ChunkBuildData = styled.data
	var intact := true
	for index: int in data_b.occupied_indices():
		intact = intact and (data_b.variant_at(data_b.cell_for_index(index)) & 4) != 0
	_check(intact,"ordinary building walls declare an intact envelope instead of ruin rhythm")
	for y in range(32):
		for x in range(32):
			var cell := Vector2i(x, y)
			_check(data_a.kind_at(cell) == data_b.kind_at(cell), "style changed blocker at " + str(cell))
	var kits := []
	for child: Node in styled.chunk.get_children():
		if child.is_in_group(&"city_block_building"):
			kits.append(child)
	_check(kits.size() == 2, "first block needs civic and attached frontage presentations")
	if kits.size() == 2:
		_check(kits[0].get_meta(&"city_role") == &"civic", "reward building receives civic identity")
		_check(kits[1].get_meta(&"city_role") == &"residential", "attached frontage receives residential identity")
		var volume: IndoorVolume
		for child: Node in styled.chunk.get_children():
			if child is IndoorVolume and child.secondary_objective_id == 41: volume = child
		_check(volume != null and is_equal_approx(float(kits[0].get("_door_x")), volume.to_global(volume.get("_presentation_entry")).x), "painted opening aligns with exact real doorway centre")
	var ids_a: Array[int] = []
	var ids_b: Array[int] = []
	for child: Node in plain.chunk.get_children():
		if child is IndoorVolume: ids_a.append(child.building_id)
	for child: Node in styled.chunk.get_children():
		if child is IndoorVolume: ids_b.append(child.building_id)
	_check(ids_a == ids_b and ids_a.size() == 2, "presentation preserves seeded building identities")
	var again := _fixture(true)
	_check((again.data as ChunkBuildData).occupied_indices() == data_b.occupied_indices(), "seeded regeneration keeps occupied cells stable")
	for kit: Node2D in kits:
		var kit_cover := kit.get("_roof") as RoofOverlay
		kit_cover._set_alpha(0.0)
		var mounted_details := 0
		for child: Node in kit.get_children():
			if child is CanvasItem and child.has_meta(&"city_facade_detail"):
				mounted_details += 1
				_check(is_zero_approx(child.modulate.a),"actual roof cutaway hides its mounted awning/lantern")
			if child is Polygon2D and child.has_meta(&"city_sun_shadow") and child.texture != null:
				_check(is_equal_approx(child.modulate.a,1.0),"independent foliage shadow stays present when the neighboring roof opens")
		_check(mounted_details > 0,"both civic and domestic frontage receive their appropriate painted detail")
		kit_cover._set_alpha(1.0)
		var entry_ground := kit.get_node_or_null("EntranceGround") as Node2D
		_check(entry_ground != null and is_equal_approx(float(entry_ground.get_meta(&"door_center",0.0)),float(kit.get("_door_x"))), "flush entrance wear follows the real doorway")
		if entry_ground != null:
			_check(entry_ground.find_children("*","CollisionObject2D",true,false).is_empty(), "entrance contact and apron add no physical obstruction")
		if bool(kit.get("civic")):
			var records := kit.get("_records_board") as Node2D
			_check(records != null, "civic interior has one wall-mounted records group")
			if records != null:
				var cover := kit.get("_roof") as RoofOverlay
				_check(records.get_parent() == cover and records.get_index() < cover.get_node("RoofPoly").get_index() and records.z_index == RoofOverlay.ROOF_Z, "records faces draw above wall fills but below the opaque roof")
				var faces := 0
				for face: Node in records.get_children():
					if face is Polygon2D and face.has_meta(&"records_face"):
						faces += 1
						_check(is_equal_approx(face.color.a,1.0),"ledger faces are opaque above masonry fills")
				_check(faces == 2,"records board has only two broad ledger faces")
				var extent: Rect2 = records.get_meta(&"wall_bounds")
				var footprint: Rect2 = kit.get("bounds")
				_check(footprint.encloses(extent) and extent.end.y <= footprint.position.y+64, "records group remains inside the blocked north-wall band")
		_check(kit.get_node_or_null("CityInteriorFloor") != null, "interior has its own quiet floor treatment instead of outdoor paving overdraw")
		var interior := kit.get_node("CityInteriorFloor") as Polygon2D
		_check(interior.z_index + kit.z_index > -94, "interior surface draws above legacy indoor stamps in either ground renderer")
		var bounds: Rect2 = kit.get("bounds")
		var strips := 0
		for child: Node in kit.get_children():
			if child is Polygon2D and child.has_meta(&"city_paving"):
				strips += 1
				_check(not Geometry2D.is_point_in_polygon(bounds.get_center(), child.polygon), "outdoor paving excludes interior floor")
		_check(strips == 4, "frontage uses four bounded paving strips")
		if bool(kit.get("civic")):
			_check(not bool(kit.call("_draws_services")), "the sliced civic arcade keeps its painted downpipe; no drawn pipe or cabinet doubles it")
	await get_tree().process_frame
	var neighbouring_footprints: Array[Rect2i] = [Rect2i(13, 4, 7, 9)]
	for kit: Node2D in kits:
		kit.trim_paving(neighbouring_footprints, 64)
	await get_tree().process_frame
	for kit: Node2D in kits:
		for child: Node in kit.get_children():
			if child is Polygon2D and child.has_meta(&"city_paving"):
				var overlap := Geometry2D.intersect_polygons(child.polygon, PackedVector2Array([Vector2(832,256), Vector2(1280,256), Vector2(1280,832), Vector2(832,832)]))
				_check(overlap.is_empty(), "paving excludes neighbouring footprint")
	for child: Node in styled.chunk.get_children():
		if child is RoofOverlay:
			var poly := child.get_node("RoofPoly") as Polygon2D
			var chimneys := 0
			for assembly: Node in poly.find_children("*","Node2D",true,false):
				if not assembly.has_meta(&"city_chimney"): continue
				chimneys += 1
				_check(assembly.get_node_or_null("FlueMouth") != null,"chimney has a broad functional flue mouth")
				var flashing := assembly.get_node_or_null("RoofFlashing") as Polygon2D
				_check(flashing != null,"chimney is seated in a flashing skirt")
				if flashing != null:
					var support: PackedVector2Array = assembly.get_meta(&"support_polygon")
					for corner: Vector2 in flashing.polygon:
						_check(Geometry2D.is_point_in_polygon(corner+assembly.position,support),"procedural flashing stays on its supporting roof plane")
			_check(chimneys == 1,"each safe sample roof has one role-specific installed chimney")
			var forms := 0
			var orientations: Dictionary = {}
			for plane: Node in poly.find_children("*", "Polygon2D", true, false):
				if plane.has_meta(&"city_roof_form"):
					forms += 1
					var plane_material := plane.material as ShaderMaterial
					orientations[plane_material.get_shader_parameter("ridge_along_x")] = true
					_check(float(plane_material.get_shader_parameter("material_contrast")) <= 0.5, "city roof material recedes behind its structural planes")
			_check(forms >= 2, "occupied building has composed roof forms, not one uninterrupted tile field")
			_check(orientations.size() == 2, "compound roof uses distinct connected gable directions")
			var box := Rect2(poly.polygon[0], Vector2.ZERO)
			for point: Vector2 in poly.polygon: box = box.expand(point)
			var material := poly.material as ShaderMaterial
			_check(material.get_shader_parameter("bounds") == Vector4(box.position.x, box.position.y, box.end.x, box.end.y), "roof shading bounds follow the shortened roof")
			child._set_alpha(0.0)
			for kit: Node2D in kits:
				if kit.get("_roof") == child: _check(is_zero_approx(float(kit.get("_facade_alpha"))), "raised facade fades with its actual roof")
			for shadow: Node in poly.get_children():
				if shadow is Node2D and String(shadow.name).begins_with("EaveShadow"):
					for strip: Node in shadow.get_children():
						if strip is Polygon2D:
							_check(strip.polygon[0].y <= box.end.y + 0.01, "eave shadow follows the current roof edge")
	var block_footprints: Array[Rect2i] = [Rect2i(2, 4, 11, 9), Rect2i(15, 4, 9, 9)]
	preload("res://scenes/world/buildings/CityBlockKit.gd").compose_street(styled.chunk, block_footprints, Rect2i(0, 15, 32, 2), Rect2i(0, 0, 2, 32), 64)
	await get_tree().process_frame
	var street_owners := 0
	var passage_paved := false
	for kit: Node2D in kits:
		if (kit.get("composed_street_area") as Rect2).has_area(): street_owners += 1
		_check(kit.get_node_or_null("CityInteriorFloor") != null, "shared street preserves separate indoor floor")
		for strip: Node in kit.get_children():
			if not (strip is Polygon2D and strip.has_meta(&"city_paving")): continue
			if Geometry2D.is_point_in_polygon(Vector2(896, 448), strip.polygon): passage_paved = true
			for footprint: Rect2i in block_footprints:
				var area := Rect2(Vector2(footprint.position) * 64, Vector2(footprint.size) * 64)
				var corners := PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
				_check(Geometry2D.intersect_polygons(strip.polygon, corners).is_empty(), "shared paving excludes every occupied parcel")
	_check(street_owners == 1, "one continuous street treatment owns the block border")
	_check(passage_paved, "the alley joins the same continuous paved area")
	var north_entry := _fixture(true, Vector2i.UP)
	for child: Node in north_entry.chunk.get_children():
		if child.is_in_group(&"city_block_building") and bool(child.get("civic")):
			_check(child.get("_records_board") == null, "north entrance remains visually open instead of being covered by a records cupboard")
	var tiny_support := Polygon2D.new()
	for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var irregular_plain := _fixture(false,direction,true)
		var irregular_styled := _fixture(true,direction,true)
		_check(irregular_plain.data.occupied_indices() == irregular_styled.data.occupied_indices(), "directional irregular styling preserves physical occupancy")
		var count := 0
		for kit: Node in irregular_styled.chunk.get_children():
			if not kit.is_in_group(&"city_block_building"): continue
			count += 1
			_check(kit.has_meta(&"city_irregular_outline"),"irregular family follows actual outline")
			_check(kit.get_node_or_null("PaintedDomesticAwning") == null and kit.get_node_or_null("CityInteriorFloor") == null,"irregular parcels don't use bounding-box awnings or floors")
			var composed_fields := kit.find_children("*","Polygon2D",true,false).filter(func(node: Node) -> bool: return node.has_meta(&"facade_wall_field"))
			_check(not kit.find_children("FootprintWallBay*","Sprite2D",true,false).is_empty() or not composed_fields.is_empty(),"irregular silhouette has inhabited wall bays under its own exposed edges")
			var cover: RoofOverlay = kit.get("_roof")
			for entrance: Dictionary in cover._doors:
				var gap := preload("res://scenes/world/buildings/CityBlockFrontages.gd")._door_box(entrance,64)
				if entrance.dir == Vector2i.DOWN and not kit.find_children("FacadeDoorFrame*","Polygon2D",true,false).is_empty():
					# Composed frontage: one doorway module whose opening spans the real gap.
					var frames := kit.find_children("FacadeDoorFrame*","Polygon2D",true,false)
					var openings := kit.find_children("FacadeDoorOpening*","Sprite2D",true,false)
					_check(frames.size() >= 3 and openings.size() == 1,"irregular south opening has a coherent upright portal")
					if not openings.is_empty():
						var opening_face: Rect2 = openings[0].get_meta(&"facade_door_opening")
						_check(absf(opening_face.size.x-gap.size.x) < 0.5 and absf(opening_face.position.x-gap.position.x) < 0.5,"composed doorway opening keeps the actual door width and position")
						_check(not openings[0].is_in_group(&"foreground_occluders") and frames[0].is_in_group(&"foreground_solid_occluders"),"doorway frame occludes while the walkable opening stays uncovered")
						cover._set_alpha(0)
						_check(is_zero_approx((frames[0].get_parent() as CanvasItem).modulate.a),"irregular portal fades with actual roof cutaway")
						cover._set_alpha(1)
				elif entrance.dir == Vector2i.DOWN:
					var portals := kit.find_children("IrregularUprightPortal*","Node2D",true,false)
					_check(portals.size() == 1,"irregular south opening has a coherent upright portal")
					if not portals.is_empty():
						var portal: Node2D = portals[0]
						var opening: Rect2 = portal.get_meta(&"opening_face")
						_check(is_equal_approx(opening.size.x,gap.size.x) and is_equal_approx(opening.size.y,112),"portal retains actual door width and existing irregular wall height")
						for name: String in ["LeftJamb","RightJamb","Lintel","Recess","FlushThreshold"]:
							_check(portal.get_node_or_null(name) != null,"upright portal has physical presentation component "+name)
						cover._set_alpha(0)
						_check(is_zero_approx((portal.get_parent().get_parent() as CanvasItem).modulate.a),"irregular portal fades with actual roof cutaway")
						cover._set_alpha(1)
				for y in range(int(gap.position.y/64),int(gap.end.y/64)):
					for x in range(int(gap.position.x/64),int(gap.end.x/64)):
						_check(irregular_styled.data.kind_at(Vector2i(x,y)) < 0,"irregular visual entry records match physically carved door cells")
			var source := cover._inset_outline(cover.footprint_outline_px,RoofOverlay.ROOF_INSET_PX)
			_check_irregular_perimeter(kit,irregular_styled.data,cover)
			for point: Vector2 in cover.get_node("RoofPoly").polygon:
				_check(Geometry2D.is_point_in_polygon(point,source),"irregular roof setback preserves its real footprint")
		_check(count == 2,"all irregular parcels receive city presentation")
		irregular_plain.cm.queue_free()
		irregular_styled.cm.queue_free()
	tiny_support.polygon = PackedVector2Array([Vector2.ZERO,Vector2(90,0),Vector2(90,70),Vector2(0,70)])
	var optional_group := Node2D.new()
	add_child(optional_group)
	for civic in [true,false]:
		_check(not preload("res://scenes/world/buildings/CityBlockRoofForms.gd")._chimney(optional_group,tiny_support,civic) and optional_group.get_child_count() == 0,"unsafe optional chimney span is skipped cleanly")
	tiny_support.free()
	optional_group.queue_free()
	for fixture: Dictionary in [plain, styled, again, north_entry]:
		fixture.cm.queue_free()
	await get_tree().process_frame
	print("CityBlockKitTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check_irregular_perimeter(kit: Node, data: ChunkBuildData, cover: RoofOverlay) -> void:
	var rect: Rect2i = kit.get_meta(&"footprint_cells")
	var footprint: Dictionary = {}
	var walls: Dictionary = {}
	var doors: Dictionary = {}
	for entrance: Dictionary in cover._doors:
		var gap := preload("res://scenes/world/buildings/CityBlockFrontages.gd")._door_box(entrance,64)
		for y in range(int(gap.position.y/64),int(gap.end.y/64)):
			for x in range(int(gap.position.x/64),int(gap.end.x/64)): doors[Vector2i(x,y)] = true
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var cell := Vector2i(x,y)
			if Geometry2D.is_point_in_polygon((Vector2(cell)+Vector2.ONE*0.5)*64,cover.footprint_outline_px): footprint[cell] = true
	var complete := true
	var intact := true
	for cell: Vector2i in footprint:
		var boundary := false
		for dy in range(-1,2):
			for dx in range(-1,2):
				if not footprint.has(cell+Vector2i(dx,dy)): boundary = true
		if boundary and not doors.has(cell): complete = complete and data.kind_at(cell) >= 0
		if data.kind_at(cell) >= 0:
			walls[cell] = true
			intact = intact and (data.variant_at(cell)&4) != 0
	_check(complete,"irregular inward corners include the joining wall cell, without unintended diagonal gaps")
	_check(intact,"irregular envelope excludes broken/pier ruin treatment")
	var visited: Dictionary = {}
	var pending: Array[Vector2i] = []
	if not walls.is_empty(): pending.append(walls.keys()[0])
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if visited.has(cell): continue
		visited[cell] = true
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			if walls.has(cell+direction) and not visited.has(cell+direction): pending.append(cell+direction)
	_check(visited.size() == walls.size(),"irregular one-door perimeter is continuous around the intended opening, with no isolated bars")
