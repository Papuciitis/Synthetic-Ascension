extends Node2D

var passed := 0
var failed := 0

func _check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed < 12: push_error(message)

func _ready() -> void: _run.call_deferred()

func _run() -> void:
	Global.debug_disable_autosave = true
	Global.attempt_segment = 3
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var theme := SegmentThemePicker.get_theme(3,2026)
	var district := DistrictPlan.generate(3,2026,2048,theme)
	var manager := ChunkManager.new()
	theme.apply_to_chunk_manager(manager)
	manager.world_seed = district.seed
	manager.generation_enabled = false
	manager.ground_enabled = false
	manager.ground_splat_enabled = false
	manager.decals_enabled = false
	manager.deco_enabled = false
	manager.parcels_chunk_chance = 0.95
	manager.district_sidewalk_width_cells = 1
	manager.district_sidewalk_corner_pad_cells = 1
	manager.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn")
	manager.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn")
	manager.cover_half_scene = load("res://scenes/world/cover/CoverHalf.tscn")
	manager._site_mgr = SiteManager.new()
	add_child(manager)
	manager._chunk_connectors = district.connectors_by_chunk.duplicate()
	manager._chunk_role = district.role_by_chunk.duplicate()
	manager._chunk_archetype = district.archetype_by_chunk.duplicate()
	manager._chunk_urban_access = district.urban_access_by_chunk.duplicate()
	var coord := Vector2i(-3,-3)
	manager._gen_coord = coord
	manager._chunk_blocked[coord] = []
	manager._active_build_data = ChunkBuildData.new(coord,32)
	var chunk := Node2D.new()
	chunk.position = Vector2(coord)*2048
	manager.add_child(chunk)
	manager._generate_chunk(coord,chunk)
	var plans: Array = chunk.get_meta(&"dungeon_plans",[])
	_check(plans.size() == 2,"Genuine S3 CA candidate receives two actual enclosed dungeon plans")
	var data := manager._active_build_data
	for cell: Vector2i in chunk.get_meta(&"_proc_clear_cells",{}): _check(data.kind_at(cell)<0,"Actual protected connector/access remains clear")
	for plan: Dictionary in plans:
		for cell: Vector2i in plan.carve.wall_cells:
			_check(data.kind_at(cell) in [WorldBlockerGeometry.Kind.WALL,WorldBlockerGeometry.Kind.WINDOW],"Final CA blockers retain every planned enclosure/chamber wall")
			_check((data.variant_at(cell)&ChunkBlockVisualCatalog.VARIANT_BUILDING_ENVELOPE)!=0,"CA dungeon intact-art flag reaches real blocker data")
		for cell: Vector2i in plan.entrance_cells: _check(data.kind_at(cell)<0,"Actual CA doorway stays open")
		var court_world := chunk.global_position+Vector2(plan.court.get_center())*64+Vector2.ONE*32
		for child: Node in chunk.get_children():
			if child is IndoorVolume and plan.get("court_outdoor",true): _check(not child.contains_world_point(court_world),"Open court is not tagged indoors")
		var deco_clear: Dictionary = chunk.get_meta(&"_proc_deco_clear_cells",{})
		for cell: Vector2i in ChunkShapeGen.rect_cells(plan.region): _check(deco_clear.has(cell),"Compound paving excludes ambient vegetation scatter")
	_check(chunk.find_children("DungeonWing*","Node2D",true,false).size() >= 6,"Actual compact dungeons own distinct streamed roof wings")
	_check(chunk.find_children("DungeonInteriorFloor","Polygon2D",true,false).size() == 2,"Each compact dungeon has a continuous indoor floor instead of street/grass blending")
	if not plans.is_empty():
		var plan: Dictionary = plans[0]
		var room: Rect2i = plan.rooms[0]
		player.global_position = chunk.global_position+(Vector2(room.get_center())+Vector2.ONE*0.5)*64
		for frame in range(18): await get_tree().process_frame
		var rebuilt := preload("res://scenes/world/buildings/DungeonBuilding.gd").attach(chunk,plan,Vector2i.ZERO,32,64)
		for roof: Node in rebuilt.find_children("DungeonWing*","Node2D",true,false):
			_check(roof._inside_count == 1 and roof.get_node("RoofPoly").modulate.a == 0,"Reload while inside starts cut away without a visible roof flash")
		player.global_position = chunk.global_position+Vector2(1024,-256)
		await get_tree().create_timer(0.25).timeout
		for roof: Node in rebuilt.find_children("DungeonWing*","Node2D",true,false):
			_check(roof._inside_count == 0 and roof.get_node("RoofPoly").modulate.a > 0.99,"Exterior restores the same connected wing roofs")
		var roofs := rebuilt.find_children("DungeonWing*","Node2D",true,false)
		if not roofs.is_empty():
			var roof: RoofOverlay = roofs[0]
			var poly := roof.get_node("RoofPoly") as Polygon2D
			var sample := poly.to_global((poly.polygon[0]+poly.polygon[2])*0.5)
			var body := AnimatedSprite2D.new()
			var head := AnimatedSprite2D.new()
			add_child(body)
			add_child(head)
			var occlusion := preload("res://core/actors/player/PlayerRoofOcclusion.gd").new()
			occlusion.configure(body,head)
			var bounds := Rect2(sample-Vector2(16,32),Vector2(32,64))
			occlusion.update(self,sample-Vector2(0,150),bounds)
			_check(occlusion.strength_at(sample)>0.9,"Actual streamed dungeon roof participates in behind-roof actor silhouette")
			_check(occlusion._triangles.size() <= 32,"Overlapping rebuilt wing coverage stays within actor shader triangle budget")
			var foot := roof.to_global(roof.footprint_outline_px[2])+Vector2(0,32)
			occlusion.update(self,foot,bounds)
			_check(occlusion.strength_at(sample)==0,"Actor standing in front of dungeon remains clear")
	manager.free()
	print("DungeonProductionTest: %d passed, %d failed" % [passed,failed])
	get_tree().quit(1 if failed else 0)
