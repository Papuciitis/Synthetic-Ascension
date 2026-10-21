extends Node

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
var passed := 0
var failed := 0
var samples: Array[Dictionary] = []

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)

func _fixture(theme: SegmentThemeData, plan: Dictionary, coord: Vector2i, original: bool) -> Dictionary:
	KIT.preview_original_materials = original
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
	manager.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn")
	manager.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn")
	manager.cover_half_scene = load("res://scenes/world/cover/CoverHalf.tscn")
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
	var kits := 0
	var roofs := 0
	var paving := 0
	var volumes: Array = []
	var door_records: Array = []
	for child: Node in chunk.get_children():
		if child is RoofOverlay:
			roofs += 1
			door_records.append([child._doors,child.footprint_outline_px])
		if child is IndoorVolume:
			volumes.append([child.cell_tl,child.size_cells,child.building_id,child.secondary_objective_id,child.local_encounter_enabled,child.local_encounter_count,child.small_loot_chance])
		if child.is_in_group(&"city_block_building"):
			kits += 1
			for detail: Node in child.get_children():
				if detail.has_meta(&"city_paving"): paving += 1
	var variants := data.blocker_variant.duplicate()
	var kinds := data.blocker_kind_code.duplicate()
	var masks := data.blocker_mask.duplicate()
	for index: int in data.occupied_indices():
		if data.blocker_kind_code[index]-1 in [WorldBlockerGeometry.Kind.WALL,WorldBlockerGeometry.Kind.WINDOW]: variants[index] &= ~(ChunkBlockVisualCatalog.VARIANT_CITY_STONE|ChunkBlockVisualCatalog.VARIANT_DOMESTIC_STONE)
		# Accepted household furnishing deliberately adds its own reviewed
		# half-cover cells; every other physical byte must stay identical.
		if (data.blocker_variant[index] & ChunkBlockVisualCatalog.VARIANT_FURNITURE_ART) != 0:
			kinds[index] = 0
			masks[index] = 0
			variants[index] = 0
	var snapshot := str([kinds,masks,variants,data.floor_rect_and_style,data.floor_alpha,volumes,door_records,chunk.get_meta(&"_proc_clear_cells",{})]).sha256_text()
	manager.free()
	return {"kits":kits,"roofs":roofs,"paving":paving,"snapshot":snapshot}

func _run() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	for segment in [2,3,4,5,6,7,8,9,10,11,20,100]:
		_check(KIT.enabled_for(&"district_fill",segment),"Ordinary city coverage must include segment %d" % segment)
	for segment in [-1,0,1]:
		_check(not KIT.enabled_for(&"secondary_reward_building",segment),"Authored/special and out-of-run segments stay excluded: %d" % segment)
	KIT.preview_original_materials = true
	_check(not KIT.enabled_for(&"district_fill",8),"Original-material preview still disables the style")
	KIT.preview_original_materials = false
	for target: Dictionary in [
		{"segment":2,"theme":&"service_courtyards"},
		{"segment":3,"theme":&"checkpoint_lanes"},
		{"segment":4,"theme":&"collapsed_ward"},
		{"segment":4,"theme":&"civilian_cutthrough"},
		{"segment":5,"theme":&"inner_district_gate"},
		{"segment":6,"theme":&"industrial_cutthrough"},
		{"segment":6,"theme":&"ruined_services"},
		{"segment":7,"theme":&"underpass_veins"},
		{"segment":7,"theme":&"canal_services"},
		{"segment":8,"theme":&"rail_yard"},
		{"segment":8,"theme":&"military_staging"},
		{"segment":9,"theme":&"outer_wall"},
		{"segment":9,"theme":&"siege_services"},
		{"segment":10,"theme":&"gate_district"},
		{"segment":11,"theme":&"service_courtyards"}]:
		var segment: int = target.segment
		Global.attempt_segment = segment
		var found := false
		for seed_value in range(1,257):
			var theme := SegmentThemePicker.get_theme(segment,seed_value)
			if theme.id != target.theme: continue
			var plan := DistrictPlan.generate(segment,seed_value,2048,theme)
			var roles: Dictionary = {}
			for coord: Vector2i in plan.role_by_chunk:
				var role: StringName = plan.role_by_chunk[coord]
				if role in [&"district_fill",&"secondary_reward_building"] and not roles.has(role): roles[role] = coord
			if roles.size() != 2: continue
			found = true
			for role: StringName in roles:
				var coord: Vector2i = roles[role]
				var baseline := _fixture(theme,plan,coord,true)
				var styled := _fixture(theme,plan,coord,false)
				_check(baseline.kits == 0,"Original-material production fixture remains unstyled")
				_check(styled.roofs > 0 and styled.kits == styled.roofs,"Every actual ordinary parcel receives style segment=%d theme=%s role=%s" % [segment,theme.id,role])
				_check(styled.snapshot == baseline.snapshot,"Style preserves geometry, doors, floors, keepouts, IDs, rewards and security segment=%d role=%s" % [segment,role])
				if segment != 2: _check(styled.paving == 0,"Later city theme keeps shared terrain/road ownership, including reward parcels")
				elif role == &"secondary_reward_building": _check(styled.paving > 0,"S2 accepted reward-block composed paving remains")
				samples.append({"segment":segment,"attempt_seed":seed_value,"theme":String(theme.id),"role":String(role),"coord":str(coord),"kits":styled.kits,"paving":styled.paving,"physical_equal":styled.snapshot == baseline.snapshot})
			break
		_check(found,"Natural production plan found for %s" % target.theme)
	KIT.preview_original_materials = false
	print("CitySegmentCoverage samples: ",JSON.stringify(samples))
	print("CitySegmentCoverageTest: %d passed, %d failed" % [passed,failed])
	get_tree().quit(1 if failed else 0)
