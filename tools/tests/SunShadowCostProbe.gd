extends Node2D
## Headless CPU probe for the building sun casts and wall contact (chunk build
## cost, not GPU). Builds real district chunks for a bright, an overcast and a
## long-shadow theme through the actual ChunkManager and reports the whole
## chunk build. On each built chunk it then times, interleaved, the shadow
## work of three pipelines: d7761960 (one hard hull sweep per building at
## configure, cut by every footprint in trim), 3a740886 (each kit cast alone
## at configure, walls collected per kit, recast in trim unless isolated)
## and the current one (each kit cast once, in trim, walls collected once
## per pass). Informational; it fails only if the work goes missing.

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
	var baseline_us := 0.0
	var legacy_us := 0.0
	var current_us := 0.0
	var worst_legacy := 0.0
	var worst_current := 0.0
	for row: Dictionary in rows:
		kits += int(row.kits)
		baseline_us += float(row.baseline_us)
		legacy_us += float(row.legacy_us)
		current_us += float(row.current_us)
		worst_legacy = maxf(worst_legacy,float(row.legacy_us))
		worst_current = maxf(worst_current,float(row.current_us))
		print("SunShadowCost %s" % JSON.stringify(row))
	if kits == 0:
		_failures += 1
		push_error("FAIL: no styled kit was measured")
	var chunk_count := maxf(1.0,rows.size())
	print("SunShadowCostProbe: chunks=%d kits=%d baseline_mean_chunk_ms=%.2f legacy_mean_chunk_ms=%.2f current_mean_chunk_ms=%.2f legacy_worst_chunk_ms=%.2f current_worst_chunk_ms=%.2f current_per_kit_ms=%.3f saved_vs_legacy=%.0f%% failures=%d" % [rows.size(),kits,baseline_us/chunk_count/1000.0,legacy_us/chunk_count/1000.0,current_us/chunk_count/1000.0,worst_legacy/1000.0,worst_current/1000.0,current_us/maxf(1.0,kits)/1000.0,100.0*(1.0-current_us/maxf(1.0,legacy_us)),_failures])
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
	var baseline_us := 0.0
	var legacy_us := 0.0
	var current_us := 0.0
	var recast := 0
	for repeat in REPEATS:
		var t0 := Time.get_ticks_usec()
		_baseline_pass(chunk,kits,footprints)
		baseline_us += float(Time.get_ticks_usec()-t0)
		t0 = Time.get_ticks_usec()
		recast = _legacy_pass(chunk,kits,footprints)
		legacy_us += float(Time.get_ticks_usec()-t0)
		t0 = Time.get_ticks_usec()
		_current_pass(chunk,kits,footprints)
		current_us += float(Time.get_ticks_usec()-t0)
	var faces := 0
	for kit: Node in kits:
		for child: Node in kit.get_children():
			if child is Polygon2D and (child.has_meta(&"city_sun_shadow") or child.has_meta(&"city_contact_shade")) and (child as Polygon2D).texture == null:
				faces += (child as Polygon2D).polygons.size()
	var row := {"segment":Global.attempt_segment,"theme":String(theme.id),"chunk":str(coord),"kits":kits.size(),"legacy_recast_kits":recast,"chunk_build_ms":snappedf(build_us/1000.0,0.01),"baseline_us":roundf(baseline_us/REPEATS),"legacy_us":roundf(legacy_us/REPEATS),"current_us":roundf(current_us/REPEATS),"faces":faces}
	manager.queue_free()
	return row


## d7761960: a hard hull sweep of the drawn footprint (126/170 px houses) at
## configure, cut by every parcel footprint in each kit's trim. No penumbra,
## contact or foliage handling; its pieces are discarded afterwards.
func _baseline_pass(chunk: Node, kits: Array[Node], footprints: Array[Rect2i]) -> void:
	var made: Dictionary = {}
	for kit: Node in kits:
		var offset := DEPTH.offset_for_height(170.0 if bool(kit.get("civic")) else 126.0)
		var pieces: Array[Polygon2D] = []
		for piece: PackedVector2Array in GEOMETRY.shadow(GEOMETRY.outline_for(kit),offset):
			var shade := Polygon2D.new()
			shade.polygon = piece
			shade.color = Color(0.10,0.15,0.20,0.21)
			kit.add_child(shade)
			pieces.append(shade)
		made[kit] = pieces
	for kit: Node in kits:
		var cuts := GEOMETRY.occupied_parts(chunk,footprints,64)
		var trimmed: Array[Polygon2D] = []
		for shade: Polygon2D in made[kit]:
			for piece: PackedVector2Array in GEOMETRY.difference(GEOMETRY.convex_parts(shade.polygon),cuts):
				var cut_shade := Polygon2D.new()
				cut_shade.polygon = piece
				cut_shade.color = shade.color
				kit.add_child(cut_shade)
				trimmed.append(cut_shade)
			kit.remove_child(shade)
			shade.free()
		for shade: Polygon2D in trimmed:
			kit.remove_child(shade)
			shade.free()


## 3a740886: configure cast alone + contact + foliage recut; trim collects
## the walls per kit and recasts unless isolated. Returns the recast count.
func _legacy_pass(chunk: Node, kits: Array[Node], footprints: Array[Rect2i]) -> int:
	for kit: Node in kits:
		kit.set("_sun_shapes",kit.call(&"sun_cast_shapes",true))
		var own: Array[PackedVector2Array] = kit.call(&"_own_wall_parts")
		var none: Array[Dictionary] = []
		kit.call(&"_rebuild_sun_shadow",none,own)
		kit.call(&"_add_contact_shade")
		kit.call(&"_recut_foliage_shadows",own)
	var recast := 0
	for kit: Node in kits:
		chunk.remove_meta(&"_city_wall_parts")
		var walls := GEOMETRY.occupied_wall_parts(chunk,footprints,64)
		var others: Array[Dictionary] = kit.call(&"_sibling_casts")
		if not others.is_empty() or _foreign_walls_near(kit,walls):
			recast += 1
			kit.call(&"_rebuild_sun_shadow",others,walls)
			kit.call(&"_recut_foliage_shadows",walls)
	return recast


## Current: configure keeps the casters and contact; trim casts once with
## the chunk's walls collected once per pass.
func _current_pass(chunk: Node, kits: Array[Node], footprints: Array[Rect2i]) -> void:
	for kit: Node in kits:
		kit.set("_sun_shapes",kit.call(&"sun_cast_shapes",true))
		kit.call(&"_add_contact_shade")
	chunk.remove_meta(&"_city_wall_parts")
	for kit: Node in kits:
		kit.call(&"_draw_sun_cast",kit.call(&"_sibling_casts"),GEOMETRY.occupied_wall_parts(chunk,footprints,64))


## The 3a740886 isolation test, verbatim in behaviour.
static func _foreign_walls_near(kit: Node, walls: Array[PackedVector2Array]) -> bool:
	var reach := Rect2()
	for shape: Dictionary in kit.call(&"sun_cast_shapes"):
		reach = shape.bounds if not reach.has_area() else reach.merge(shape.bounds)
	for child: Node in kit.get_children():
		if child is Polygon2D and child.has_meta(&"city_sun_shadow") and (child as Polygon2D).texture != null:
			var foliage := GEOMETRY.bounds_of((child as Polygon2D).polygon)
			reach = foliage if not reach.has_area() else reach.merge(foliage)
	var own: Array[PackedVector2Array] = kit.call(&"wall_parts")
	for part: PackedVector2Array in walls:
		if own.has(part): continue
		if GEOMETRY.bounds_of(part).intersects(reach.grow(1.0)): return true
	return false
