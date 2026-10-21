extends Node2D
## Draw-order contract for the shared ground shade (WorldDepthStyle):
## building casts, kit foliage casts and wall-base contact draw on one
## absolute layer above every flat ground layer, so what a shadow darkens
## is decided by z, never by a kit's child order. Review 2026-10-21: an
## isolated kit kept its configure-time cast early in tree order and one
## in five S2 garden soil beds drew over (outside) their building's shade.
## Builds real district chunks through ChunkManager; headless.

const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const GEOMETRY := preload("res://scenes/world/buildings/CityFootprintGeometry.gd")
## Flat ground a kit draws itself; each must lie below the shade layer.
const FLAT_GROUND: Array[StringName] = [&"QuietFrontagePaving",&"CityInteriorFloor",&"TendedDomesticBed",&"DomesticHerbBed"]
## Kit layers at or below this z are ground-level; upright art (plants,
## props, walls, actors) draws far above it.
const GROUND_BAND_TOP := -60
var _passes := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: "+label)


static func effective_z(item: CanvasItem) -> int:
	var z := item.z_index
	var node: CanvasItem = item
	while node.z_as_relative:
		var parent := node.get_parent() as CanvasItem
		if parent == null: break
		z += parent.z_index
		node = parent
	return z


## True when `later` is drawn after (over) `earlier` on the same canvas.
static func draws_after(later: CanvasItem, earlier: CanvasItem) -> bool:
	var a := effective_z(later)
	var b := effective_z(earlier)
	if a != b: return a > b
	return later.is_greater_than(earlier)


static func is_shade(item: Node) -> bool:
	return item is Polygon2D and (item.has_meta(&"city_sun_shadow") or item.has_meta(&"city_contact_shade") or item.has_meta(&"wall_contact_shade"))


func _manager(theme: SegmentThemeData, plan: Dictionary, coord: Vector2i) -> ChunkManager:
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
	return manager


func _run() -> void:
	var previous := Global.attempt_segment
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var kits := 0
	var shades := 0
	var beds := 0
	var beds_in_cast := 0
	var herb_beds := 0
	var wall_contacts := 0
	var stats := {"layer_mismatch":0,"shared_layer":0,"ground_above":0,"bed_unshaded":0,"cast_count":0}
	for target: Array in [[2,[16102026,17,4,1,2,3]],[3,[16102026]],[9,[16102026]]]:
		var segment: int = target[0]
		Global.attempt_segment = segment
		for seed_value: int in target[1]:
			var theme := SegmentThemePicker.get_theme(segment,seed_value)
			DEPTH.use_theme(theme.id)
			var plan := DistrictPlan.generate(segment,seed_value,2048,theme)
			# S2 samples the reviewed garden chunks; later segments add plazas
			# and checkpoints, whose freestanding walls carry wall contact.
			var roles: Array[StringName] = [&"district_fill",&"secondary_reward_building",&"main_route"]
			if segment != 2: roles.append_array([&"landmark_plaza",&"checkpoint"])
			var coords: Array[Vector2i] = []
			for coord: Vector2i in plan.role_by_chunk:
				if plan.role_by_chunk[coord] in roles and coords.size() < (6 if segment == 2 else 9): coords.append(coord)
			for coord: Vector2i in coords:
				var manager := _manager(theme,plan,coord)
				# Inspected synchronously: production finishes every kit's
				# cast inside the chunk build itself, not on a later frame.
				var chunk: Node2D = manager._create_chunk(coord)
				for child: Node in chunk.get_children():
					if not child.is_in_group(&"city_block_building"): continue
					kits += 1
					var where := "S%d seed=%d chunk=%s fp=%s" % [segment,seed_value,str(coord),str(child.get_meta(&"footprint_cells"))]
					var casts: Array[Polygon2D] = []
					for item: Node in child.find_children("*","CanvasItem",true,false):
						var canvas := item as CanvasItem
						var z := effective_z(canvas)
						if is_shade(canvas):
							if item.get_parent() != child: continue # roof-on-roof casts belong to the roof layer
							shades += 1
							if z != DEPTH.GROUND_SHADE_Z:
								stats.layer_mismatch += 1
								_check(false,"%s: %s draws on z %d, not the shared ground shade layer %d" % [where,item.name,z,DEPTH.GROUND_SHADE_Z])
							if item.has_meta(&"city_sun_shadow") and (item as Polygon2D).texture == null: casts.append(item as Polygon2D)
							continue
						if z == DEPTH.GROUND_SHADE_Z:
							stats.shared_layer += 1
							_check(false,"%s: %s shares the ground shade layer, so tree order would decide its shading" % [where,item.name])
						elif z > DEPTH.GROUND_SHADE_Z and (z <= GROUND_BAND_TOP or (item.get_parent() == child and StringName(item.name) in FLAT_GROUND)):
							stats.ground_above += 1
							_check(false,"%s: flat ground %s draws above the shade layer (z %d)" % [where,item.name,z])
					if casts.size() != 1:
						stats.cast_count += 1
						_check(false,"%s: expected one building cast after the chunk build, found %d" % [where,casts.size()])
					# Household gardens are laid by CityFrontageDressing: the flat
					# kitchen bed is a garden_bed prop under the DomesticGarden node.
					var soil: Sprite2D = null
					var garden := child.get_node_or_null(^"DomesticGarden")
					if garden != null:
						for prop: Node in garden.get_children():
							if prop is Sprite2D and prop.get_meta(&"city_dressing_prop",&"") == &"garden_bed": soil = prop
					if soil == null: continue
					herb_beds += 1
					beds += 1
					var centre: Vector2 = soil.get_meta(&"city_dressing_contact")
					for cast: Polygon2D in casts:
						var inside := false
						for face: PackedVector2Array in GEOMETRY.faces_of(cast):
							if Geometry2D.is_point_in_polygon(centre,face): inside = true
						if not inside: continue
						beds_in_cast += 1
						if not draws_after(cast,soil):
							stats.bed_unshaded += 1
							_check(false,"%s: the garden soil draws over its building's cast (unshaded)" % where)
				for item: Node in manager.get_children():
					if item.has_meta(&"wall_contact_shade"):
						wall_contacts += 1
						_check(effective_z(item as CanvasItem) == DEPTH.GROUND_SHADE_Z,"S%d chunk=%s: freestanding wall contact draws on the shared ground shade layer" % [segment,str(coord)])
				manager.queue_free()
				await get_tree().process_frame
	DEPTH.reset_light()
	Global.attempt_segment = previous
	_check(kits > 20 and shades > kits,"real chunks exercise many kits and their shades (kits=%d shades=%d)" % [kits,shades])
	_check(beds > 10 and beds_in_cast > 10,"real S2 garden beds lie inside their building casts (beds=%d in_cast=%d)" % [beds,beds_in_cast])
	_check(herb_beds > 0,"kitchen garden bed sprites are exercised (%d)" % herb_beds)
	_check(stats.layer_mismatch == 0 and stats.shared_layer == 0 and stats.ground_above == 0 and stats.bed_unshaded == 0 and stats.cast_count == 0,"layering summary %s" % str(stats))
	print("SunShadowLayerTest stats kits=%d shades=%d beds=%d beds_in_cast=%d herb_beds=%d wall_contacts=%d %s" % [kits,shades,beds,beds_in_cast,herb_beds,wall_contacts,str(stats)])
	player.queue_free()
	await get_tree().process_frame
	print("SunShadowLayerTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
