extends "res://tools/tests/ProcChunkReachabilityTest.gd"

func actual_fixture(theme: SegmentThemeData, plan: Dictionary, coord: Vector2i) -> Dictionary:
	var cm := ChunkManager.new()
	theme.apply_to_chunk_manager(cm)
	cm.world_seed = int(plan.seed)
	cm.generation_enabled = false
	cm.ground_enabled = false
	cm.ground_splat_enabled = false
	cm.decals_enabled = false
	cm.deco_enabled = false
	cm.sites_enabled = false
	cm.parcels_chunk_chance = 0.95
	cm.district_sidewalk_width_cells = 1
	cm.district_sidewalk_corner_pad_cells = 1
	cm.cover_full_scene = COVER_FULL
	cm.cover_window_scene = COVER_WINDOW
	cm.cover_half_scene = COVER_HALF
	add_child(cm)
	cm._chunk_connectors = plan.connectors_by_chunk.duplicate()
	cm._chunk_role = plan.role_by_chunk.duplicate()
	cm._chunk_archetype = plan.archetype_by_chunk.duplicate()
	cm._chunk_urban_access = plan.urban_access_by_chunk.duplicate()
	cm._gen_coord = coord
	cm._chunk_blocked[coord] = []
	var data := ChunkBuildData.new(coord,32)
	cm._active_build_data = data
	var chunk := Node2D.new()
	chunk.position = Vector2(coord)*2048
	cm.add_child(chunk)
	cm._generate_chunk(coord,chunk)
	return {"cm":cm,"chunk":chunk,"data":data}

func _run() -> void:
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	Global.attempt_segment = 2
	var samples: Array = []
	for seed_value in [16102026,211,17,2026]:
		var theme := SegmentThemePicker.get_theme(2,seed_value)
		var plan := DistrictPlan.generate(2,seed_value,2048,theme)
		var count := 0
		for coord: Vector2i in plan.role_by_chunk:
			if plan.role_by_chunk[coord] != &"service_lane" or count >= 3: continue
			count += 1
			var fixture := actual_fixture(theme,plan,coord)
			var cm: ChunkManager = fixture.cm
			var chunk: Node2D = fixture.chunk
			var data: ChunkBuildData = fixture.data
			var gen: ChunkGenImpl = cm._content_gen
			var mask := cm.get_chunk_connectors(coord)
			var cx := gen._lane_center_for_col(coord.x,32)
			var cy := gen._lane_center_for_row(coord.y,32)
			var start := Vector2i(cx,0) if mask & 1 else Vector2i(31,cy) if mask & 2 else Vector2i(cx,31) if mask & 4 else Vector2i(0,cy)
			var reachable := _reachable(data,start)
			for cell: Vector2i in chunk.get_meta(&"_proc_clear_cells",{}):
				if data.kind_at(cell) >= 0: failures.append("Natural annex blocks protected route seed=%d coord=%s cell=%s" % [seed_value,coord,cell])
			var parcels: Array = []
			var annexes := 0
			for child: Node in chunk.get_children():
				if child is IndoorVolume:
					var door := Vector2i(chunk.to_local(child.to_global(child.get("_presentation_entry")))/64)
					if not reachable.has(door): failures.append("Natural parcel entry unreachable seed=%d coord=%s door=%s" % [seed_value,coord,door])
				if not child.is_in_group(&"city_block_building"): continue
				var annex := bool(child.get_meta(&"city_service_annex",false))
				if annex: annexes += 1
				if child.get_node_or_null("DomesticHerbBed") != null or child.get_node_or_null("TendedDomesticBed") != null:
					if StringName(child.get_meta(&"building_usage",&"")) != &"row_house" or child.get("civic"): failures.append("Household garden assigned to a non-dwelling")
					var garden := child.get_node("TendedDomesticBed") as CanvasItem
					child.call("_on_roof_alpha",0.0)
					if not is_equal_approx(garden.modulate.a,1.0): failures.append("Outdoor garden fades with an interior roof")
					child.call("_on_roof_alpha",1.0)
				parcels.append({"bounds":str(child.get("bounds")),"usage":String(child.get_meta(&"building_usage",&"")),"civic":child.get("civic"),"annex":annex,"visual_seed":child.get("_district_profile").get("visual_seed"),"doors":str(child.get("_doors"))})
			if annexes > 1: failures.append("Natural sparse lane received more than one annex")
			samples.append({"seed":seed_value,"plan_seed":plan.seed,"coord":str(coord),"parcels":parcels,"annexes":annexes})
			cm.free()
	var populated := 0
	for sample: Dictionary in samples:
		if not (sample.parcels as Array).is_empty(): populated += 1
	if populated == 0: failures.append("Natural survey generated no buildings at all")
	var output := "user://natural-streets.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":samples,"failures":failures},"\t"))
	file.close()
	for failure: String in failures: push_error(failure)
	print("CityServiceNaturalTest: chunks=%d failures=%d" % [samples.size(),failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
