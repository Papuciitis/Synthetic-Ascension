extends "res://tools/tests/ProcChunkReachabilityTest.gd"
## Real DistrictPlan chunks, including final floor stamps and household care.
## -- --out=user://city-ground-care-natural.json

const ART := preload("res://core/systems/world/WorldArt.gd")
const MAX_S2_CHUNKS := 24
const MAX_S7_PAIRS := 8
const PAVING := [2,3,4,6,7,8,9]


func _manager(theme: SegmentThemeData, plan: Dictionary) -> ChunkManager:
	var cm := ChunkManager.new()
	theme.apply_to_chunk_manager(cm)
	cm.generation_enabled = false
	cm.ground_enabled = true
	cm.ground_splat_enabled = true
	cm.decals_enabled = false
	cm.deco_enabled = false
	cm.sites_enabled = false
	# Match the original natural-street fixture and the production parcel fit.
	cm.parcels_chunk_chance = 0.95
	cm.district_sidewalk_width_cells = 1
	cm.district_sidewalk_corner_pad_cells = 1
	cm.cover_full_scene = COVER_FULL
	cm.cover_window_scene = COVER_WINDOW
	cm.cover_half_scene = COVER_HALF
	add_child(cm)
	cm.set_process(false)
	cm.configure_procedural_world(int(plan.seed),plan.connectors_by_chunk,plan.urban_access_by_chunk,plan.role_by_chunk,plan.terrain_by_chunk,plan.archetype_by_chunk)
	return cm


func _load_chunk(cm: ChunkManager, coord: Vector2i) -> Node2D:
	if not cm._chunks.has(coord):
		cm._chunks[coord] = cm._create_chunk(coord)
		chunks += 1
	return cm._chunks[coord] as Node2D


func _runtime_ids(chunk: Node2D, kit: Node) -> Array[int]:
	var roof := kit.get("_roof") as RoofOverlay
	var ids: Array[int] = []
	for child: Node in chunk.get_children():
		if not child is IndoorVolume: continue
		for connection: Dictionary in child.body_entered.get_connections():
			if (connection.callable as Callable).get_object() == roof and not ids.has(child.building_id):
				ids.append(child.building_id)
	return ids


func _physical(cm: ChunkManager, coord: Vector2i) -> Dictionary:
	var data := cm.get_chunk_build_data(coord)
	var ids: Array[int] = []
	for child: Node in (cm._chunks[coord] as Node).get_children():
		if child is IndoorVolume: ids.append(child.building_id)
	return {"kinds":data.blocker_kind_code.duplicate(),"masks":data.blocker_mask.duplicate(),"variants":data.blocker_variant.duplicate(),"floors":data.floor_rect_and_style.duplicate(),"floor_alpha":data.floor_alpha.duplicate(),"ids":ids,"blocked":cm._chunk_blocked[coord].duplicate(),"projectile_blockers":cm._projectile_blockers.duplicate(true),"terrain":cm._chunk_terrain.duplicate(),"roles":cm._chunk_role.duplicate(),"connectors":cm._chunk_connectors.duplicate(),"urban_access":cm._chunk_urban_access.duplicate(),"archetypes":cm._chunk_archetype.duplicate()}


func _coverage(splat: GroundSplatRenderer) -> Dictionary:
	var light := splat._light.get_data()
	for index in range(2,light.size(),4): light[index] = 0
	return {"a":splat._cover_a.get_data(),"b":splat._cover_b.get_data(),"light_without_care":light,"slots":splat._slot_material.duplicate()}


func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _check_stability(cm: ChunkManager, coord: Vector2i) -> Dictionary:
	var chunk := cm._chunks[coord] as Node2D
	var splat := cm.get_ground_splat()
	var physical_before := _physical(cm,coord)
	var coverage_before := _coverage(splat)
	var before := splat.care_signature(coord)
	var run_rng_state := Global._rng.state
	# Check the engine's global RNG independently of the run-owned RNG.
	seed(10202026)
	var expected_next := randi()
	seed(10202026)
	for repeat in 3: cm._activate_ground_care(coord,chunk)
	var global_rng_equal := randi() == expected_next
	var run_rng_equal := Global._rng.state == run_rng_state
	var repeated_equal := before == splat.care_signature(coord)
	var physical_equal := physical_before == _physical(cm,coord)
	var coverage_equal := coverage_before == _coverage(splat)
	# Rebuild through the original base/stamp path; this must first clear care.
	cm._add_ground(chunk,RandomNumberGenerator.new(),coord)
	splat.paint_chunk_stamps(cm.get_chunk_build_data(coord))
	var reset := splat.care_signature(coord)
	var reset_empty := reset.count(0) == reset.size()
	cm._activate_ground_care(coord,chunk)
	var rebuilt_equal := before == splat.care_signature(coord)
	coverage_equal = coverage_equal and coverage_before == _coverage(splat)
	physical_equal = physical_equal and physical_before == _physical(cm,coord)
	if not repeated_equal or not rebuilt_equal or not reset_empty: failures.append("Natural care reset/rebuild changed exact bytes coord="+str(coord))
	if not physical_equal or not coverage_equal: failures.append("Natural care changed physical, semantic or coverage data coord="+str(coord))
	if not global_rng_equal or not run_rng_equal: failures.append("Natural care consumed RNG coord="+str(coord))
	return {"care_sha256":_hash(before),"cared_cells":before.size()-before.count(0),"repeated_exact":repeated_equal,"rebuilt_exact":rebuilt_equal,"base_stamp_reset_empty":reset_empty,"physical_equal":physical_equal,"semantic_coverage_equal":coverage_equal,"global_rng_equal":global_rng_equal,"run_rng_equal":run_rng_equal}


func _outside_buildings(chunk: Node2D, local_px: Vector2) -> bool:
	for kit: Node in chunk.get_children():
		if not kit.is_in_group(&"city_block_building"): continue
		var roof := kit.get("_roof") as RoofOverlay
		if roof != null and Geometry2D.is_point_in_polygon(local_px,roof.footprint_outline_px): return false
	return true


func _wild_point(cm: ChunkManager, coord: Vector2i, contact: Vector2) -> Dictionary:
	var splat := cm.get_ground_splat()
	var chunk := cm._chunks[coord] as Node2D
	var best_score := -INF
	var result: Dictionary = {}
	for y in range(3,CPC-3):
		for x in range(3,CPC-3):
			var cell := coord*CPC+Vector2i(x,y)
			var world := cm.cell_to_world_center(cell)
			var distance := world.distance_to(contact)
			if distance < 6*cm.cell_size_px or distance > 1100.0 or not cm.is_cell_walkable(cell): continue
			if not ART.is_overgrowth_ground(splat.material_at(cell)) or splat.care_at(cell) != 0.0: continue
			if not _outside_buildings(chunk,chunk.to_local(world)): continue
			var wild_cells := 0
			for dy in range(-2,3):
				for dx in range(-2,3):
					var near := cell+Vector2i(dx,dy)
					if ART.is_overgrowth_ground(splat.material_at(near)) and splat.care_at(near) == 0.0 and cm.is_cell_walkable(near): wild_cells += 1
			if wild_cells < 20: continue
			var score := float(wild_cells)*1000.0-distance
			if score <= best_score: continue
			best_score = score
			result = {"classification":"actual_uncared_wild_ground","coord":str(coord),"cell":[cell.x,cell.y],"world_px":[world.x,world.y],"material":splat.material_at(cell),"care":splat.care_at(cell),"walkable":true,"uncared_walkable_overgrowth_cells_in_5x5":wild_cells,"distance_from_garden_px":distance}
	return result


func _home(seed_value: int, coord: Vector2i, expected_id: int) -> Dictionary:
	Global.attempt_segment = 2
	var theme := SegmentThemePicker.get_theme(2,seed_value)
	var plan := DistrictPlan.generate(2,seed_value,2048,theme)
	var cm := _manager(theme,plan)
	var chunk := _load_chunk(cm,coord)
	var selected: Node = null
	for kit: Node in chunk.get_children():
		if kit.is_in_group(&"city_block_building") and _runtime_ids(chunk,kit).has(expected_id): selected = kit
	var result := {"segment":2,"seed":seed_value,"plan_seed":plan.seed,"theme":String(theme.id),"coord":str(coord),"target_building_id":expected_id}
	if selected == null:
		failures.append("Natural handoff home missing seed=%d coord=%s id=%d" % [seed_value,coord,expected_id])
		cm.free()
		return result
	var spec: Dictionary = selected.call("ground_care_spec")
	if spec.is_empty(): failures.append("Actual handoff home was not eligible for care id="+str(expected_id))
	var profile: Dictionary = selected.get("_district_profile")
	var contact := chunk.to_global(spec.get("garden_contact_px",Vector2.ZERO))
	var near_garden := 0
	for y in CPC:
		for x in CPC:
			var cell := coord*CPC+Vector2i(x,y)
			if cm.cell_to_world_center(cell).distance_to(contact) < 6*cm.cell_size_px and cm.get_ground_splat().care_at(cell) > 0.0: near_garden += 1
	result.merge({"building_ids":_runtime_ids(chunk,selected),"usage":String(selected.get_meta(&"building_usage",&"")),"civic":selected.get("civic"),"visual_seed":profile.get("visual_seed"),"garden_variant":absi(int(profile.get("visual_seed",0)))%4,"care_spec":str(spec),"cared_cells_near_actual_garden":near_garden,"stability":_check_stability(cm,coord)})
	if near_garden <= 0 or int(result.stability.cared_cells) <= 0: failures.append("Actual handoff home has no cared ground at its planted corner id="+str(expected_id))
	var wild := _wild_point(cm,coord,contact)
	if wild.is_empty(): failures.append("No real uncared wild comparison near home id="+str(expected_id))
	else:
		cm._activate_ground_care(coord,chunk)
		var cell_data: Array = wild.cell
		if cm.get_ground_splat().care_at(Vector2i(int(cell_data[0]),int(cell_data[1]))) != 0.0: failures.append("Repeated care reached selected wild control")
	result["wild"] = wild
	# Optional comparison: only explicit actual-use, noncivic variant three
	# qualifies as untended. A missing prop is never evidence of neglect.
	var candidates: Array = plan.role_by_chunk.keys()
	candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		var da := (a-coord).length_squared()
		var db := (b-coord).length_squared()
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	var generated := 1
	var untended: Dictionary = {}
	for candidate: Vector2i in candidates:
		if candidate == coord or plan.role_by_chunk[candidate] != &"service_lane": continue
		if generated >= MAX_S2_CHUNKS: break
		var neighbor := _load_chunk(cm,candidate)
		generated += 1
		for kit: Node in neighbor.get_children():
			if not kit.is_in_group(&"city_block_building") or kit.get_meta(&"building_usage",&"") != &"row_house" or bool(kit.get("civic")): continue
			var actual_profile: Dictionary = kit.get("_district_profile")
			var visual_seed := int(actual_profile.get("visual_seed",0))
			if absi(visual_seed)%4 != 3: continue
			var actual_ids := _runtime_ids(neighbor,kit)
			if actual_ids.size() != 1 or actual_ids[0] <= 0: continue
			if not (kit.call("ground_care_spec") as Dictionary).is_empty(): failures.append("Actual untended variant-three home exposes care")
			untended = {"classification":"actual_non_civic_row_house_variant_three","coord":str(candidate),"building_ids":actual_ids,"visual_seed":visual_seed,"garden_variant":3,"care_spec_empty":(kit.call("ground_care_spec") as Dictionary).is_empty(),"stability":_check_stability(cm,candidate)}
			break
		if not untended.is_empty(): break
	result["optional_untended_home"] = untended
	result["generated_chunks_for_seed"] = generated
	result["search_limit"] = MAX_S2_CHUNKS
	cm.free()
	return result


func _material_window(cm: ChunkManager, cell: Vector2i) -> Dictionary:
	var splat := cm.get_ground_splat()
	var counts: Dictionary = {"12":0,"5":0,"paving":0}
	for y in range(cell.y-8,cell.y+9):
		for x in range(cell.x-12,cell.x+13):
			var at := Vector2i(x,y)
			if not cm._chunks.has(cm._world_to_chunk(cm.cell_to_world_center(at))): continue
			var material := splat.material_at(at)
			var key := str(material)
			counts[key] = int(counts.get(key,0))+1
			if material in PAVING: counts.paving = int(counts.paving)+1
	return counts


func _s7_boundary() -> Dictionary:
	Global.attempt_segment = 7
	var theme := SegmentThemePicker.get_theme(7,4)
	var plan := DistrictPlan.generate(7,4,2048,theme)
	var result := {"segment":7,"seed":4,"plan_seed":plan.seed,"theme":String(theme.id),"pair_limit":MAX_S7_PAIRS}
	if theme.id != &"canal_services": failures.append("Natural S7 seed four no longer selects canal_services")
	var pairs := 0
	var selected: Dictionary = {}
	for coord: Vector2i in plan.terrain_by_chunk:
		if plan.terrain_by_chunk[coord] != &"moss": continue
		for direction: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var neighbor := coord+direction
			if plan.terrain_by_chunk.get(neighbor,&"") != &"mud": continue
			if pairs >= MAX_S7_PAIRS: break
			pairs += 1
			var cm := _manager(theme,plan)
			_load_chunk(cm,coord)
			_load_chunk(cm,neighbor)
			for along in range(1,CPC-1):
				var local := Vector2i(CPC-1,along) if direction == Vector2i.RIGHT else Vector2i(0,along) if direction == Vector2i.LEFT else Vector2i(along,CPC-1) if direction == Vector2i.DOWN else Vector2i(along,0)
				var cell := coord*CPC+local
				if not cm.is_cell_walkable(cell) or not cm.is_cell_walkable(cell+direction): continue
				var counts := _material_window(cm,cell)
				if int(counts["12"]) <= 0 or int(counts["5"]) <= 0 or int(counts.paving) <= 0: continue
				var world := cm.cell_to_world_center(cell)
				selected = {"classification":"natural_moss_mud_paving_boundary","moss_coord":str(coord),"mud_coord":str(neighbor),"coord":str(coord),"cell":[cell.x,cell.y],"world_px":[world.x,world.y],"walkable":true,"material_at_point":cm.get_ground_splat().material_at(cell),"care_at_point":cm.get_ground_splat().care_at(cell),"material_window_half_extent_cells":[12,8],"material_counts":counts,"moss_stability":_check_stability(cm,coord),"mud_stability":_check_stability(cm,neighbor)}
				if int(selected.moss_stability.cared_cells) != 0 or int(selected.mud_stability.cared_cells) != 0: failures.append("S7 natural ground acquired household care")
				break
			cm.free()
			if not selected.is_empty(): break
		if not selected.is_empty() or pairs >= MAX_S7_PAIRS: break
	result["adjacent_pairs_tested"] = pairs
	result["sample"] = selected
	if selected.is_empty(): failures.append("No bounded natural S7 moss/mud/paving view found")
	return result


func _run() -> void:
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	var samples: Array[Dictionary] = [
		_home(16102026,Vector2i(0,3),944996572),
		_home(17,Vector2i(-3,5),2128236757),
	]
	var s7 := _s7_boundary()
	var output := "user://city-ground-care-natural.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write natural ground evidence: "+output)
	else:
		file.store_string(JSON.stringify({"scene":"res://tools/tests/CityGroundCareNaturalTest.tscn","args":OS.get_cmdline_user_args(),"samples":samples,"s7":s7,"chunks":chunks,"ground_enabled":true,"ground_splat_enabled":true,"parcels_chunk_chance":0.95,"sidewalk_cells":1,"decals_deco_sites_enabled":false,"failures":failures},"\t"))
		file.close()
	for failure: String in failures: push_error(failure)
	print("CityGroundCareNaturalTest: chunks=%d failures=%d" % [chunks,failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
