extends "res://tools/tests/ProcChunkReachabilityTest.gd"

const FRUIT_TREE_PATH := "res://assets/world/domestic_gardens/v1/fruit_tree_overhead_v2.png"

func _runtime_building(chunk: Node2D, kit: Node, context: String) -> Dictionary:
	# The roof's real entry signals identify its volumes, including both wings
	# of an irregular home. A visual RNG seed is not an identity contract.
	var roof := kit.get("_roof") as RoofOverlay
	var ids: Array[int] = []
	var volume_count := 0
	var entry_count := 0
	var entry_world := Vector2.ZERO
	var entry_direction := Vector2.ZERO
	var owners_valid := roof != null
	for child: Node in chunk.get_children():
		if not child is IndoorVolume: continue
		var volume := child as IndoorVolume
		var roof_owners: Array[RoofOverlay] = []
		for connection: Dictionary in volume.body_entered.get_connections():
			var owner := (connection.callable as Callable).get_object() as RoofOverlay
			if owner != null and not roof_owners.has(owner): roof_owners.append(owner)
		if not roof_owners.has(roof): continue
		volume_count += 1
		if roof_owners.size() != 1: owners_valid = false
		if not ids.has(volume.building_id): ids.append(volume.building_id)
		if float(volume.get("_presentation_width")) > 0.0:
			entry_count += 1
			entry_world = volume.to_global(volume.get("_presentation_entry"))
			entry_direction = volume.get("_presentation_outward")
	var resolved := owners_valid and ids.size() == 1 and ids[0] > 0 and entry_count == 1
	if not resolved: failures.append("Natural parcel runtime ownership unresolved %s ids=%s volumes=%d entries=%d" % [context,ids,volume_count,entry_count])
	return {"building_id":ids[0] if resolved else 0,"runtime_id_resolved":resolved,"indoor_volumes":volume_count,"entry_volumes":entry_count,"entry_world":str(entry_world),"entry_direction":str(entry_direction)}

func _check_handoff_samples(samples: Array) -> void:
	for expected: Dictionary in [
		{"seed":16102026,"coord":Vector2i(0,3),"entry_direction":Vector2.DOWN,"garden_variant":0,"kitchen_bed":true,"fruit_tree":false,"irregular":true},
		{"seed":17,"coord":Vector2i(-3,5),"entry_direction":Vector2.UP,"garden_variant":1,"kitchen_bed":false,"fruit_tree":true},
	]:
		var homes: Array[Dictionary] = []
		for sample: Dictionary in samples:
			if sample.seed != expected.seed or sample.coord != str(expected.coord): continue
			for parcel: Dictionary in sample.parcels:
				if parcel.usage == "row_house" and not parcel.annex: homes.append(parcel)
		var context := "seed=%d coord=%s" % [expected.seed,expected.coord]
		if homes.size() != 1:
			failures.append("Handoff sample must resolve exactly one generated home %s count=%d" % [context,homes.size()])
			continue
		var home := homes[0]
		if home.civic or not home.runtime_id_resolved or int(home.building_id) <= 0:
			failures.append("Handoff home lacks unique domestic runtime identity " + context)
		if home.entry_direction != str(expected.entry_direction): failures.append("Handoff home entry direction changed " + context)
		if expected.has("irregular") and home.irregular != expected.irregular: failures.append("Handoff home footprint changed " + context)
		if home.garden_variant != expected.garden_variant or home.kitchen_bed != expected.kitchen_bed or home.fruit_tree != expected.fruit_tree:
			failures.append("Handoff home garden fit changed " + context)

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
				var garden_node := child.get_node_or_null("DomesticGarden") as Node2D
				var kitchen_bed := false
				if garden_node != null:
					if StringName(child.get_meta(&"building_usage",&"")) != &"row_house" or child.get("civic"): failures.append("Household garden assigned to a non-dwelling")
					child.call("_on_roof_alpha",0.0)
					if not is_equal_approx(garden_node.modulate.a,1.0): failures.append("Outdoor garden fades with an interior roof")
					child.call("_on_roof_alpha",1.0)
					# The garden belongs to its house: it stands on the home's own
					# blocked wall foot, never on road or footway paving.
					var contact: Vector2 = garden_node.get_meta(&"city_garden_contact",Vector2.INF)
					var contact_cell := Vector2i((contact/64.0).floor())
					if not (child.get("bounds") as Rect2).has_point(contact) or data.kind_at(contact_cell) < 0: failures.append("Household garden contact leaves its own wall foot seed=%d coord=%s" % [seed_value,coord])
					for item: Node in garden_node.get_children():
						if not item.has_meta(&"city_dressing_prop"): continue
						if item.get_meta(&"city_dressing_prop") == &"garden_bed": kitchen_bed = true
						var foot: Vector2 = item.get_meta(&"city_dressing_contact")
						if data.kind_at(Vector2i((foot/64.0).floor())) < 0: failures.append("Garden piece stands on walkable ground seed=%d coord=%s" % [seed_value,coord])
				var tree := child.get_node_or_null("CityTemperateTree") as Sprite2D
				var fruit_tree := tree != null and tree.texture != null and tree.texture.resource_path == FRUIT_TREE_PATH
				var garden_variant := int(garden_node.get_meta(&"city_domestic_garden",-1)) if garden_node != null else -1
				var parcel := {"bounds":str(child.get("bounds")),"usage":String(child.get_meta(&"building_usage",&"")),"civic":child.get("civic"),"annex":annex,"visual_seed":child.get("_district_profile").get("visual_seed"),"doors":str(child.get("_doors")),"irregular":bool(child.get("_irregular")),"garden_variant":garden_variant,"kitchen_bed":kitchen_bed,"fruit_tree":fruit_tree}
				parcel.merge(_runtime_building(chunk,child,"seed=%d coord=%s bounds=%s" % [seed_value,coord,child.get("bounds")]))
				parcels.append(parcel)
			if annexes > 1: failures.append("Natural sparse lane received more than one annex")
			samples.append({"seed":seed_value,"plan_seed":plan.seed,"coord":str(coord),"parcels":parcels,"annexes":annexes})
			cm.free()
	var populated := 0
	for sample: Dictionary in samples:
		if not (sample.parcels as Array).is_empty(): populated += 1
	if populated == 0: failures.append("Natural survey generated no buildings at all")
	_check_handoff_samples(samples)
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
