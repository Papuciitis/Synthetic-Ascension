extends Node

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const PROFILE_PATH := "res://scenes/world/buildings/DistrictVisualProfiles.gd"
var passed := 0
var failed := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)

func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.name) == property_name: return true
	return false

func _fixture(theme: SegmentThemeData, plan: Dictionary, coord: Vector2i, common_preview: bool, caller_rng: RandomNumberGenerator = null, activate_chunk: bool = false) -> Dictionary:
	var manager := ChunkManager.new()
	theme.apply_to_chunk_manager(manager)
	if _has_property(manager, &"district_common_base_preview"):
		manager.set("district_common_base_preview", common_preview)
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
	var data: ChunkBuildData
	var chunk: Node2D
	if activate_chunk:
		manager.generation_enabled = true
		chunk = manager._create_chunk(coord)
		data = manager.get_chunk_build_data(coord)
	else:
		data = ChunkBuildData.new(coord,32)
		manager._active_build_data = data
		chunk = Node2D.new()
		chunk.position = Vector2(coord)*2048
		manager.add_child(chunk)
		if caller_rng == null:
			manager._generate_chunk(coord,chunk)
		else:
			var placed: Array[Rect2i] = []
			var cfg := {"city_block_style":true,"city_shared_ground":true,"district_family":theme.district_family,"district_common_base_preview":common_preview,"secondary_objective_id":41}
			var placed_ok := SiteParcelsImpl.new()._spawn_building_rect(manager,chunk,coord,Rect2i(2,4,11,9),Vector2i.DOWN,&"workshop",[],placed,cfg,caller_rng,Rect2i(0,0,32,32))
			_check(placed_ok,"Caller-RNG fixture uses a real fitted civic parcel")
	var profiles: Array = []
	var records: Array = []
	var volumes: Array = []
	var doors: Array = []
	for child: Node in chunk.get_children():
		if child.is_in_group(&"city_block_building"):
			profiles.append([child.get_meta(&"city_role"), child.get_meta(&"district_visual_profile", &"missing")])
			var roof := child.get("_roof") as RoofOverlay
			var presentation: Dictionary = child.get("_district_profile")
			records.append({"city_role":String(child.get_meta(&"city_role")),"profile":String(child.get_meta(&"district_visual_profile",&"missing")),"building_id":int(presentation.get("visual_seed",0)),"irregular":bool(child.get("_irregular")),"door_direction":str(roof._doors[0].dir) if not roof._doors.is_empty() else "","doors":str(roof._doors),"footprint":str(roof.footprint_outline_px),"form_signature":str(roof.get_meta(&"district_form_plan",{})).sha256_text()})
		if child is RoofOverlay: doors.append([child._doors, child.footprint_outline_px])
		if child is IndoorVolume:
			volumes.append([child.cell_tl, child.size_cells, child.building_id, child.secondary_objective_id, child.local_encounter_enabled, child.local_encounter_count, child.small_loot_chance])
	var snapshot := str([data.blocker_kind_code, data.blocker_mask, data.blocker_variant, data.floor_rect_and_style, data.floor_alpha, volumes, doors, chunk.get_meta(&"_proc_clear_cells", {})]).sha256_text()
	var node_count := chunk.find_children("*","",true,false).size()+1
	var phase_samples: Array = manager.get_chunk_stream_debug_stats().get("build_phase_samples",[])
	var phase: Dictionary = phase_samples[-1].duplicate(true) if not phase_samples.is_empty() else {}
	manager.free()
	return {"profiles": profiles, "snapshot": snapshot,"records":records,"nodes":node_count,"phase":phase}

func _run() -> void:
	KIT.preview_original_materials = false
	var profiles_script: Script = load(PROFILE_PATH) if ResourceLoader.exists(PROFILE_PATH) else null
	_check(profiles_script != null, "The selected district needs a presentation profile catalogue")
	if profiles_script != null:
		for family: StringName in [&"service_courtyards", &"checkpoint_lanes", &"collapsed_ward", &"civilian_cutthrough", &"inner_district_gate", &"industrial_cutthrough", &"ruined_services", &"underpass_veins", &"canal_services", &"rail_yard", &"military_staging", &"outer_wall", &"siege_services", &"gate_district", &"", &"unknown"]:
			var resolved: Dictionary = profiles_script.resolve(family)
			var wanted: StringName = &"checkpoint_guard_loggia" if family == &"checkpoint_lanes" else &"common_base"
			_check(resolved.get("profile_id") == wanted, "Only the selected checkpoint family changes architecture: %s" % family)
			resolved["visual_seed"] = 91
			_check(not profiles_script.resolve(family).has("visual_seed"), "Per-building visual seed cannot mutate shared catalogue data")
	var manager := ChunkManager.new()
	var theme := SegmentThemePicker.get_theme(3, 1)
	theme.apply_to_chunk_manager(manager)
	_check(manager.get("district_family") == &"checkpoint_lanes", "Theme application forwards selected identity before streaming")
	if _has_property(manager, &"district_family"):
		manager.world_seed = 999997
		var generator := ChunkGenImpl.new()
		generator.bind(manager)
		_check(generator.get("district_family") == &"checkpoint_lanes", "Mixed manager seed cannot reroll the original family")
		SegmentThemePicker.get_theme(2, 1).apply_to_chunk_manager(manager)
		generator.sync_from_chunk_manager()
		_check(generator.get("district_family") == &"service_courtyards", "Reusing a manager does not keep the previous district identity")
	_check(_has_property(manager, &"district_common_base_preview"), "Common-base comparison is instance-local")
	if _has_property(manager, &"district_common_base_preview"):
		manager.set("district_common_base_preview", true)
		var other_manager := ChunkManager.new()
		_check(not bool(other_manager.get("district_common_base_preview")), "Another live manager does not inherit a comparison override")
		other_manager.free()
	manager.free()
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	for sample: Dictionary in [{"segment":2,"seed":1},{"segment":3,"seed":1},{"segment":7,"seed":4},{"segment":11,"seed":3}]:
		var segment: int = sample.segment
		Global.attempt_segment = segment
		var selected_theme := SegmentThemePicker.get_theme(segment, int(sample.seed))
		var plan := DistrictPlan.generate(segment, int(sample.seed), 2048, selected_theme)
		var seen_roles: Dictionary = {}
		for coord: Vector2i in plan.role_by_chunk:
			var role: StringName = plan.role_by_chunk[coord]
			if role not in [&"secondary_reward_building", &"district_fill"] or seen_roles.has(role): continue
			seen_roles[role] = true
			var base := _fixture(selected_theme, plan, coord, true)
			var styled := _fixture(selected_theme, plan, coord, false)
			_check(base.snapshot == styled.snapshot, "Family routing preserves full physical/interaction state seg=%d role=%s" % [segment, role])
			_check(not styled.profiles.is_empty(), "Actual production parcel path contains buildings seg=%d role=%s" % [segment, role])
			if segment == 3 and role == &"secondary_reward_building":
				var caller_rng := RandomNumberGenerator.new()
				caller_rng.seed = 404
				var original_state := caller_rng.state
				var direct_base := _fixture(selected_theme, plan, coord, true, caller_rng)
				_check(caller_rng.state == original_state, "Common-base architecture preserves the caller's layout RNG state")
				var direct_guard := _fixture(selected_theme, plan, coord, false, caller_rng)
				_check(caller_rng.state == original_state, "Guard-family selection cannot draw from the caller's layout RNG")
				_check(direct_base.snapshot == direct_guard.snapshot, "Direct seeded parcel retains its physical and reward contract")
			for profile: Array in base.profiles:
				_check(profile[1] == &"common_base", "One manager can force common base without changing the theme")
			for profile: Array in styled.profiles:
				var wanted: StringName = &"checkpoint_guard_loggia" if segment == 3 and profile[0] == &"civic" else &"common_base"
				_check(profile[1] == wanted, "Real street/fill parcels use the selected family only for civic architecture seg=%d role=%s" % [segment, role])
		_check(seen_roles.size() == 2, "Natural plan exercises both street reward and courtyard-fill paths")
	print("DistrictFamilyVisualTest: %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed else 0)
