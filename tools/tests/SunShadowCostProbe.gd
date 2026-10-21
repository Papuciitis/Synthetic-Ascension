extends Node2D
## Headless CPU probe for the building sun casts and wall contact (chunk build
## cost, not GPU). Builds real district chunks for a bright, an overcast and a
## long-shadow theme through the actual ChunkManager, reports the whole chunk
## build and, per chunk, the isolated cost of the cast/contact work as rebuilt
## by trim_paving. Informational; it fails only if the work goes missing.

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const GEOMETRY := preload("res://scenes/world/buildings/CityFootprintGeometry.gd")
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const REPEATS := 5
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var rows: Array[Dictionary] = []
	for target: Dictionary in [{"segment":2,"theme":&"service_courtyards"},{"segment":7,"theme":&"canal_services"},{"segment":9,"theme":&"outer_wall"}]:
		var segment: int = target.segment
		Global.attempt_segment = segment
		for seed_value in range(1,257):
			var theme := SegmentThemePicker.get_theme(segment,seed_value)
			if theme.id != target.theme: continue
			DEPTH.use_theme(theme.id)
			var plan := DistrictPlan.generate(segment,seed_value,2048,theme)
			var chunks: Array[Vector2i] = []
			for coord: Vector2i in plan.role_by_chunk:
				if plan.role_by_chunk[coord] in [&"district_fill",&"secondary_reward_building",&"main_route"] and chunks.size() < 4: chunks.append(coord)
			for coord: Vector2i in chunks:
				var row := _measure(theme,plan,coord)
				if int(row.kits) > 0: rows.append(row)
			break
	DEPTH.reset_light()
	var kits := 0
	var total_us := 0.0
	var worst_us := 0.0
	for row: Dictionary in rows:
		kits += int(row.kits)
		total_us += float(row.cast_contact_us)
		worst_us = maxf(worst_us,float(row.cast_contact_us))
		print("SunShadowCost %s" % JSON.stringify(row))
	if kits == 0:
		_failures += 1
		push_error("FAIL: no styled kit was measured")
	print("SunShadowCostProbe: chunks=%d kits=%d mean_per_chunk_ms=%.2f worst_chunk_ms=%.2f mean_per_kit_ms=%.3f failures=%d" % [rows.size(),kits,total_us/maxf(1.0,rows.size())/1000.0,worst_us/1000.0,total_us/maxf(1.0,kits)/1000.0,_failures])
	player.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _measure(theme: SegmentThemeData, plan: Dictionary, coord: Vector2i) -> Dictionary:
	var manager := ChunkManager.new()
	theme.apply_to_chunk_manager(manager)
	manager.world_seed = int(plan.seed)
	manager.ground_enabled = false
	manager.ground_splat_enabled = false
	manager.world_atmosphere_enabled = false
	manager.decals_enabled = false
	manager.deco_enabled = false
	manager.sites_enabled = false
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
	manager.generation_enabled = true
	var started := Time.get_ticks_usec()
	var chunk := manager._create_chunk(coord)
	var build_us := Time.get_ticks_usec()-started
	var kits: Array[Node] = []
	var footprints: Array[Rect2i] = []
	for child: Node in chunk.get_children():
		if child.is_in_group(&"city_block_building"):
			kits.append(child)
			footprints.append(child.get_meta(&"footprint_cells"))
	var cast_us := 0.0
	var faces := 0
	for repeat in REPEATS:
		var t0 := Time.get_ticks_usec()
		var walls := GEOMETRY.occupied_wall_parts(chunk,footprints,64)
		for kit: Node in kits:
			kit.set("_sun_shapes",kit.call(&"sun_cast_shapes",true))
			kit.call(&"_rebuild_sun_shadow",kit.call(&"_sibling_casts"),walls)
			kit.call(&"_add_contact_shade")
		cast_us += float(Time.get_ticks_usec()-t0)
	for kit: Node in kits:
		for child: Node in kit.get_children():
			if child is Polygon2D and (child.has_meta(&"city_sun_shadow") or child.has_meta(&"city_contact_shade")) and (child as Polygon2D).texture == null:
				faces += (child as Polygon2D).polygons.size()
	var row := {"segment":Global.attempt_segment,"theme":String(theme.id),"chunk":str(coord),"kits":kits.size(),"chunk_build_ms":snappedf(build_us/1000.0,0.01),"cast_contact_us":roundf(cast_us/REPEATS),"faces":faces}
	manager.queue_free()
	return row
