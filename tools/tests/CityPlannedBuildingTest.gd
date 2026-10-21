extends "res://tools/tests/ProcChunkReachabilityTest.gd"

func _run() -> void:
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	Global.attempt_segment = 2
	var families: Dictionary = {}
	var directions: Dictionary = {}
	var styled_buildings := 0
	for seed_value in [17,211,2026,16102026]:
		var theme := SegmentThemePicker.get_theme(2,seed_value)
		var plan := DistrictPlan.generate(2,seed_value,2048,theme)
		var seen_roles: Dictionary = {}
		for coord: Vector2i in plan.role_by_chunk:
			var role: StringName = plan.role_by_chunk[coord]
			if role not in [&"secondary_reward_building",&"secondary_route",&"service_lane",&"district_fill",&"dangerous_alley",&"main_street"] or seen_roles.has(role): continue
			seen_roles[role] = true
			var manager := ChunkManager.new()
			theme.apply_to_chunk_manager(manager)
			manager.world_seed = int(plan.seed)
			manager.generation_enabled = false
			manager.ground_enabled = false
			manager.ground_splat_enabled = false
			manager.decals_enabled = false
			manager.deco_enabled = false
			manager.sites_enabled = false
			manager.parcels_chunk_chance = 0.95
			manager.district_sidewalk_width_cells = 1
			manager.cover_full_scene = COVER_FULL
			manager.cover_window_scene = COVER_WINDOW
			manager.cover_half_scene = COVER_HALF
			manager._site_mgr = SiteManager.new()
			add_child(manager)
			manager._chunk_connectors = plan.connectors_by_chunk.duplicate()
			manager._chunk_role = plan.role_by_chunk.duplicate()
			manager._chunk_archetype = plan.archetype_by_chunk.duplicate()
			manager._chunk_urban_access = plan.urban_access_by_chunk.duplicate()
			manager._gen_coord = coord
			manager._chunk_blocked[coord] = []
			var data := ChunkBuildData.new(coord,32)
			manager._active_build_data = data
			var chunk := Node2D.new()
			chunk.position = Vector2(coord)*2048
			manager.add_child(chunk)
			manager._generate_chunk(coord,chunk)
			var gen: ChunkGenImpl = manager._content_gen
			var mask := manager.get_chunk_connectors(coord)
			var cx := gen._lane_center_for_col(coord.x,32)
			var cy := gen._lane_center_for_row(coord.y,32)
			var start := Vector2i(cx,0) if mask & 1 else Vector2i(31,cy) if mask & 2 else Vector2i(cx,31) if mask & 4 else Vector2i(0,cy)
			var reachable := _reachable(data,start)
			for cell: Vector2i in chunk.get_meta(&"_proc_clear_cells",{}):
				if data.kind_at(cell) >= 0: failures.append("Protected road/courtyard access blocked seed=%d cell=%s" % [seed_value,cell])
			var objectives := 0
			var roofs := 0
			var kits := 0
			for child: Node in chunk.get_children():
				if child is RoofOverlay: roofs += 1
				if child.is_in_group(&"city_block_building"):
					kits += 1
					styled_buildings += 1
					families[child.get_meta(&"city_role")] = true
					var roof: RoofOverlay = child.get("_roof")
					_check_envelope(data,roof,seed_value,role)
					for door: Dictionary in roof._doors: directions[str(door.dir)] = true
				if child is IndoorVolume and child.secondary_objective_id > 0:
					objectives += 1
					var doorway := Vector2i(chunk.to_local(child.to_global(child.get("_presentation_entry")))/64)
					if not reachable.has(doorway): failures.append("Required generated building has unreachable real door seed=%d door=%s" % [seed_value,doorway])
			if role == &"secondary_reward_building" and objectives != 1: failures.append("seed=%d coord=%s mask=%d access=%d needs one actual planned searchable building, got %d" % [seed_value,coord,manager.get_chunk_connectors(coord),manager.get_chunk_urban_access(coord),objectives])
			if roofs != kits: failures.append("Every actual generated parcel needs family coverage seed=%d role=%s roofs=%d kits=%d" % [seed_value,role,roofs,kits])
			chunks += 1
			manager.free()
	if families.size() != 2 or directions.size() != 4: failures.append("Actual plans must carry both families and all four door directions")
	for failure: String in failures: push_error(failure)
	print("CityPlannedBuildingTest: chunks=%d styled_buildings=%d families=%d directions=%d failures=%d" % [chunks,styled_buildings,families.size(),directions.size(),failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)

func _check_envelope(data: ChunkBuildData, roof: RoofOverlay, seed_value: int, role: StringName) -> void:
	var cells: Dictionary = {}
	var doors: Dictionary = {}
	for y in range(32):
		for x in range(32):
			if Geometry2D.is_point_in_polygon((Vector2(x,y)+Vector2.ONE*0.5)*64,roof.footprint_outline_px): cells[Vector2i(x,y)] = true
	for entrance: Dictionary in roof._doors:
		var gap := preload("res://scenes/world/buildings/CityBlockFrontages.gd")._door_box(entrance,64)
		for y in range(int(gap.position.y/64),int(gap.end.y/64)):
			for x in range(int(gap.position.x/64),int(gap.end.x/64)): doors[Vector2i(x,y)] = true
	for cell: Vector2i in cells:
		if doors.has(cell): continue
		var boundary := false
		for dy in range(-1,2):
			for dx in range(-1,2):
				if not cells.has(cell+Vector2i(dx,dy)): boundary = true
		if not boundary: continue
		if data.kind_at(cell) not in [WorldBlockerGeometry.Kind.WALL,WorldBlockerGeometry.Kind.WINDOW]:
			failures.append("Actual production envelope gap seed=%d role=%s cell=%s" % [seed_value,role,cell])
		elif (data.variant_at(cell)&ChunkBlockVisualCatalog.VARIANT_BUILDING_ENVELOPE) == 0:
			failures.append("Actual building wall uses ruin presentation seed=%d role=%s cell=%s" % [seed_value,role,cell])
