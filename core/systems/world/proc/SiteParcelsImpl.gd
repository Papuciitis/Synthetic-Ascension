extends RefCounted
class_name SiteParcelsImpl

const RECT_FAC := preload("res://core/systems/world/proc/RectFacilityCarver.gd")
const INDOOR_VOLUME_SCENE: PackedScene = preload("res://scenes/world/volumes/IndoorVolume.tscn")
const ROOF_OVERLAY_SCENE: PackedScene = preload("res://scenes/world/buildings/RoofOverlay.tscn")
const _DIR_N: int = 1
const _DIR_E: int = 2
const _DIR_S: int = 4
const _DIR_W: int = 8

# Dense street frontage generator. Roads define bands, bands are divided into lots,
# and every blank frontage is an intentional passage rather than an accidental field.
func decorate_district_parcels(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	lane_rect_h: Rect2i,
	lane_rect_v: Rect2i,
	keepout_rects: Array[Rect2i],
	cfg: Dictionary
) -> Array[Rect2i]:
	var placed: Array[Rect2i] = []
	var has_h: bool = lane_rect_h.size.x > 0 and lane_rect_h.size.y > 0
	var has_v: bool = lane_rect_v.size.x > 0 and lane_rect_v.size.y > 0
	if not has_h and not has_v:
		return placed

	var cpc: int = int(chunk_manager._cells_per_chunk())
	var chunk_rect := Rect2i(Vector2i.ZERO, Vector2i(cpc, cpc))
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4001)

	var depth: int = clampi(int(cfg.get("parcel_depth_cells", 10)), 8, maxi(8, int(cpc / 2.0) - 2))
	var street_gap: int = maxi(1, int(cfg.get("parcel_street_gap_cells", 1)))
	var bands: Array[Dictionary] = []

	# Each exact road arm contributes its own frontage. This preserves L-turns and
	# T-junctions: a missing west arm no longer receives west-facing "phantom" shops.
	# Overlaps at real intersections are resolved lot-by-lot against road keepouts and
	# already placed buildings.
	if has_h:
		var span_x0: int = clampi(lane_rect_h.position.x + 1, 2, cpc - 3)
		var span_x1: int = clampi(lane_rect_h.position.x + lane_rect_h.size.x - 1, span_x0 + 1, cpc - 2)
		_add_band(bands, Rect2i(Vector2i(span_x0, lane_rect_h.position.y - street_gap - depth), Vector2i(span_x1 - span_x0, depth)), Vector2i(0, 1))
		_add_band(bands, Rect2i(Vector2i(span_x0, lane_rect_h.position.y + lane_rect_h.size.y + street_gap), Vector2i(span_x1 - span_x0, depth)), Vector2i(0, -1))
	if has_v:
		var span_y0: int = clampi(lane_rect_v.position.y + 1, 2, cpc - 3)
		var span_y1: int = clampi(lane_rect_v.position.y + lane_rect_v.size.y - 1, span_y0 + 1, cpc - 2)
		_add_band(bands, Rect2i(Vector2i(lane_rect_v.position.x - street_gap - depth, span_y0), Vector2i(depth, span_y1 - span_y0)), Vector2i(1, 0))
		_add_band(bands, Rect2i(Vector2i(lane_rect_v.position.x + lane_rect_v.size.x + street_gap, span_y0), Vector2i(depth, span_y1 - span_y0)), Vector2i(-1, 0))

	var working_cfg: Dictionary = cfg.duplicate(true)
	working_cfg["_secondary_assigned"] = false
	var force_parcel: bool = bool(working_cfg.get("force_parcel", false))
	var filled_any: bool = false
	for band_variant in bands:
		var band_data: Dictionary = band_variant as Dictionary
		var band: Rect2i = band_data.get("rect", Rect2i()) as Rect2i
		var door_dir: Vector2i = band_data.get("door_dir", Vector2i.ZERO) as Vector2i
		if not _rect_inside_chunk(band, chunk_rect):
			continue
		if _fill_frontage_band(chunk_manager, chunk, coord, band, door_dir, keepout_rects, placed, working_cfg, rng, chunk_rect, force_parcel and not filled_any):
			filled_any = true

	return placed


# Generates a complete courtyard block in a district-fill chunk. These chunks form
# the one-chunk urban envelope around roads and stop the district reading as a road
# laid across grass.
func decorate_urban_fill(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	cfg: Dictionary
) -> Array[Rect2i]:
	var placed: Array[Rect2i] = []
	var cpc: int = int(chunk_manager._cells_per_chunk())
	if cpc < 24:
		return placed
	var chunk_rect := Rect2i(Vector2i.ZERO, Vector2i(cpc, cpc))
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 8123)

	var court_w: int = clampi(rng.randi_range(9, 13), 8, cpc - 16)
	var court_h: int = clampi(rng.randi_range(9, 13), 8, cpc - 16)
	var court_x: int = clampi(int(cpc / 2.0) - int(court_w / 2.0) + rng.randi_range(-2, 2), 7, cpc - court_w - 7)
	var court_y: int = clampi(int(cpc / 2.0) - int(court_h / 2.0) + rng.randi_range(-2, 2), 7, cpc - court_h - 7)
	var courtyard := Rect2i(Vector2i(court_x, court_y), Vector2i(court_w, court_h))
	var keepouts: Array[Rect2i] = [courtyard.grow(1)]

	var floor_rng := RandomNumberGenerator.new()
	floor_rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 8131)
	chunk_manager._stamp_floor_rect_cells_patchy(chunk, courtyard, int(cfg.get("courtyard_floor_tex", 8)), floor_rng, 0.88, -95)

	# Urban-access masks are reciprocal with the neighbouring chunk. Passages meet
	# the chunk edge at its centre, so both independently generated sides align.
	var passage_dirs: Array[Vector2i] = _passage_dirs_from_mask(int(cfg.get("urban_access_mask", 0)))
	if passage_dirs.is_empty():
		passage_dirs = _pick_courtyard_passage_dirs(chunk_manager, coord, rng)
	var passage_w: int = 3
	var edge_center: int = int(cpc / 2.0) - int(passage_w / 2.0)
	for passage_dir in passage_dirs:
		var passage := Rect2i()
		if passage_dir == Vector2i(0, -1):
			passage = Rect2i(Vector2i(edge_center, 0), Vector2i(passage_w, court_y + 1))
		elif passage_dir == Vector2i(0, 1):
			var passage_south_y: int = court_y + court_h - 1
			passage = Rect2i(Vector2i(edge_center, passage_south_y), Vector2i(passage_w, cpc - passage_south_y))
		elif passage_dir == Vector2i(-1, 0):
			passage = Rect2i(Vector2i(0, edge_center), Vector2i(court_x + 1, passage_w))
		else:
			var passage_east_x: int = court_x + court_w - 1
			passage = Rect2i(Vector2i(passage_east_x, edge_center), Vector2i(cpc - passage_east_x, passage_w))
		if passage.size.x > 0 and passage.size.y > 0:
			keepouts.append(passage.grow(1).intersection(chunk_rect))
			chunk_manager._stamp_floor_rect_cells_patchy(chunk, passage, int(cfg.get("passage_floor_tex", 4)), floor_rng, 0.80, -94)

	# Fill the ring between the chunk edge and the courtyard. Keep the bands deep
	# enough for real interiors even after clipping; pedestrian passages carve the
	# deliberate gaps through these rows via keepouts.
	var north_h: int = maxi(0, court_y - 2)
	var south_y: int = court_y + court_h + 2
	var south_h: int = maxi(0, cpc - south_y - 1)
	var west_w: int = maxi(0, court_x - 2)
	var east_x: int = court_x + court_w + 2
	var east_w: int = maxi(0, cpc - east_x - 1)
	var bands: Array[Dictionary] = []
	_add_band(bands, Rect2i(Vector2i(1, 1), Vector2i(cpc - 2, north_h)), Vector2i(0, 1))
	_add_band(bands, Rect2i(Vector2i(1, south_y), Vector2i(cpc - 2, south_h)), Vector2i(0, -1))
	_add_band(bands, Rect2i(Vector2i(1, 1), Vector2i(west_w, cpc - 2)), Vector2i(1, 0))
	_add_band(bands, Rect2i(Vector2i(east_x, 1), Vector2i(east_w, cpc - 2)), Vector2i(-1, 0))

	var fill_cfg: Dictionary = cfg.duplicate(true)
	fill_cfg["frontage_target"] = float(cfg.get("urban_fill_frontage_target", 0.78))
	fill_cfg["parcel_length_min_cells"] = 7
	fill_cfg["parcel_length_max_cells"] = 12
	fill_cfg["parcel_depth_cells"] = 10
	fill_cfg["parcel_building_margin_cells"] = 0
	fill_cfg["parcel_loot_chance"] = float(cfg.get("urban_fill_loot_chance", 0.18))
	fill_cfg["local_encounter_enabled"] = false

	for band_variant in bands:
		var band_data: Dictionary = band_variant as Dictionary
		var band: Rect2i = band_data.get("rect", Rect2i()) as Rect2i
		var door_dir: Vector2i = band_data.get("door_dir", Vector2i.ZERO) as Vector2i
		if not _rect_inside_chunk(band, chunk_rect):
			continue
		_fill_frontage_band(chunk_manager, chunk, coord, band, door_dir, keepouts, placed, fill_cfg, rng, chunk_rect, false)

	_decorate_courtyard_props(chunk_manager, chunk, courtyard, passage_dirs, rng)

	# Courtyard combat/ambush sockets, but no dormant enemies are created here.
	for socket_offset in [Vector2(court_w * 0.25, court_h * 0.5), Vector2(court_w * 0.75, court_h * 0.5), Vector2(court_w * 0.5, court_h * 0.25)]:
		var socket := Marker2D.new()
		socket.name = "CourtyardSpawnSocket"
		socket.position = (Vector2(courtyard.position) + socket_offset) * float(chunk_manager.cell_size_px)
		socket.add_to_group(&"enemy_spawn_socket")
		socket.set_meta("spawn_socket_kind", &"courtyard")
		chunk.add_child(socket)

	return placed


func _decorate_courtyard_props(chunk_manager: Node, chunk: Node2D, courtyard: Rect2i, passage_dirs: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	if not chunk_manager.has_method("_spawn_block"):
		return
	var prop_scene: PackedScene = chunk_manager.get("cover_half_scene") as PackedScene
	if prop_scene == null:
		return
	var candidates: Array[Vector2i] = [
		courtyard.position + Vector2i(2, 2),
		Vector2i(courtyard.position.x + courtyard.size.x - 3, courtyard.position.y + 2),
		Vector2i(courtyard.position.x + 2, courtyard.position.y + courtyard.size.y - 3),
		courtyard.position + courtyard.size - Vector2i(3, 3),
	]
	var budget: int = rng.randi_range(2, 3)
	for _i in range(budget):
		if candidates.is_empty():
			break
		var pick_index: int = rng.randi_range(0, candidates.size() - 1)
		var prop_cell: Vector2i = candidates[pick_index]
		candidates.remove_at(pick_index)
		# Keep the edge-facing half of a courtyard clearer when it is a formal access.
		var blocked_by_access: bool = false
		for passage_dir in passage_dirs:
			if passage_dir == Vector2i(0, -1) and prop_cell.y <= courtyard.position.y + 2:
				blocked_by_access = true
			elif passage_dir == Vector2i(0, 1) and prop_cell.y >= courtyard.position.y + courtyard.size.y - 3:
				blocked_by_access = true
			elif passage_dir == Vector2i(-1, 0) and prop_cell.x <= courtyard.position.x + 2:
				blocked_by_access = true
			elif passage_dir == Vector2i(1, 0) and prop_cell.x >= courtyard.position.x + courtyard.size.x - 3:
				blocked_by_access = true
		if blocked_by_access:
			continue
		chunk_manager.call("_spawn_block", chunk, prop_scene, prop_cell.x, prop_cell.y)


func _passage_dirs_from_mask(mask: int) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	if (mask & _DIR_N) != 0:
		dirs.append(Vector2i(0, -1))
	if (mask & _DIR_E) != 0:
		dirs.append(Vector2i(1, 0))
	if (mask & _DIR_S) != 0:
		dirs.append(Vector2i(0, 1))
	if (mask & _DIR_W) != 0:
		dirs.append(Vector2i(-1, 0))
	return dirs


func _pick_courtyard_passage_dirs(chunk_manager: Node, coord: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	var candidates: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for dir in candidates:
		if not chunk_manager.has_method("get_chunk_role"):
			continue
		var neighbor_role: StringName = StringName(chunk_manager.call("get_chunk_role", coord + dir))
		if neighbor_role != &"unplanned":
			dirs.append(dir)
	if dirs.is_empty():
		dirs.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	return dirs


func _add_band(bands: Array[Dictionary], rect: Rect2i, door_dir: Vector2i) -> void:
	if rect.size.x < 7 or rect.size.y < 7:
		return
	bands.append({"rect": rect, "door_dir": door_dir})


func _fill_frontage_band(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	band: Rect2i,
	door_dir: Vector2i,
	keepout_rects: Array[Rect2i],
	placed: Array[Rect2i],
	cfg: Dictionary,
	rng: RandomNumberGenerator,
	chunk_rect: Rect2i,
	force_one: bool
) -> bool:
	var margin: int = maxi(0, int(cfg.get("parcel_building_margin_cells", 1)))
	var usable: Rect2i = band.grow(-margin)
	if usable.size.x < 7 or usable.size.y < 7:
		return false

	var frontage_horizontal: bool = door_dir.y != 0
	var frontage_len: int = usable.size.x if frontage_horizontal else usable.size.y
	var depth_available: int = usable.size.y if frontage_horizontal else usable.size.x
	if frontage_len < 7 or depth_available < 7:
		return false

	var target: float = clampf(float(cfg.get("frontage_target", 0.84)), 0.35, 0.96)
	var min_len: int = clampi(int(cfg.get("parcel_length_min_cells", 7)), 6, 16)
	var max_len: int = clampi(int(cfg.get("parcel_length_max_cells", 13)), min_len, 20)
	var desired_coverage: int = maxi(min_len, int(round(float(frontage_len) * target)))
	var cursor: int = 0
	var coverage: int = 0
	var made_any: bool = false
	var safety: int = 0

	while cursor + min_len <= frontage_len and coverage < desired_coverage and safety < 12:
		safety += 1
		var remaining: int = frontage_len - cursor
		var lot_len: int = mini(rng.randi_range(min_len, max_len), remaining)
		if lot_len < min_len:
			break
		var template: StringName = _pick_template(rng, lot_len, cfg)
		if template == &"workshop":
			lot_len = mini(maxi(lot_len, 11), remaining)
		var depth_roll_max: int = maxi(7, mini(12, depth_available))
		var building_depth: int = clampi(rng.randi_range(7, depth_roll_max), 7, depth_available)
		if template == &"workshop":
			building_depth = depth_available

		var build_rect := Rect2i()
		if frontage_horizontal:
			var x0: int = usable.position.x + cursor
			var y0: int = usable.position.y
			if door_dir == Vector2i(0, 1):
				y0 = usable.position.y + usable.size.y - building_depth
			build_rect = Rect2i(Vector2i(x0, y0), Vector2i(lot_len, building_depth))
		else:
			var y0v: int = usable.position.y + cursor
			var x0v: int = usable.position.x
			if door_dir == Vector2i(1, 0):
				x0v = usable.position.x + usable.size.x - building_depth
			build_rect = Rect2i(Vector2i(x0v, y0v), Vector2i(building_depth, lot_len))

		if _spawn_building_rect(chunk_manager, chunk, coord, build_rect, door_dir, template, keepout_rects, placed, cfg, rng, chunk_rect):
			made_any = true
			coverage += lot_len
			cursor += lot_len
		else:
			cursor += 2

		# One-cell separations read as attached rows. Occasional wider gaps are
		# deliberate service passages and visual breathing points.
		var gap: int = 1
		if rng.randf() < float(cfg.get("frontage_passage_chance", 0.24)):
			gap = rng.randi_range(2, 3)
		cursor += gap

	if force_one and not made_any:
		var forced_len: int = mini(maxi(min_len, 9), frontage_len)
		var forced_depth: int = mini(maxi(8, depth_available), depth_available)
		var forced_rect := Rect2i()
		if frontage_horizontal:
			var fy: int = usable.position.y + usable.size.y - forced_depth if door_dir == Vector2i(0, 1) else usable.position.y
			forced_rect = Rect2i(Vector2i(usable.position.x, fy), Vector2i(forced_len, forced_depth))
		else:
			var fx: int = usable.position.x + usable.size.x - forced_depth if door_dir == Vector2i(1, 0) else usable.position.x
			forced_rect = Rect2i(Vector2i(fx, usable.position.y), Vector2i(forced_depth, forced_len))
		made_any = _spawn_building_rect(chunk_manager, chunk, coord, forced_rect, door_dir, &"workshop", keepout_rects, placed, cfg, rng, chunk_rect)

	return made_any


func _pick_template(rng: RandomNumberGenerator, frontage_len: int, cfg: Dictionary) -> StringName:
	if int(cfg.get("secondary_objective_id", 0)) > 0 and not bool(cfg.get("_secondary_assigned", false)):
		return &"workshop"
	var roll: float = rng.randf()
	if frontage_len >= 11 and roll < 0.20:
		return &"workshop"
	if roll < 0.43:
		return &"shop"
	if roll < 0.60 and bool(cfg.get("passage_buildings_enabled", true)):
		return &"passage"
	return &"row_house"


func _spawn_building_rect(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	build_rect: Rect2i,
	door_dir: Vector2i,
	template: StringName,
	keepout_rects: Array[Rect2i],
	placed: Array[Rect2i],
	cfg: Dictionary,
	_rng: RandomNumberGenerator,
	chunk_rect: Rect2i
) -> bool:
	if not _rect_can_place(build_rect, chunk_rect, keepout_rects, placed):
		return false

	var cpc: int = int(chunk_manager._cells_per_chunk())
	var door_w: int = maxi(2, int(cfg.get("parcel_door_width", 2)))
	var apron_len: int = maxi(1, int(cfg.get("parcel_apron_len", 2)))
	var center_x: int = build_rect.position.x + int(round(float(build_rect.size.x - 1) * 0.5))
	var center_y: int = build_rect.position.y + int(round(float(build_rect.size.y - 1) * 0.5))
	var door_pos := Vector2i.ZERO
	if door_dir == Vector2i(0, -1):
		door_pos = Vector2i(center_x, build_rect.position.y)
	elif door_dir == Vector2i(0, 1):
		door_pos = Vector2i(center_x, build_rect.position.y + build_rect.size.y - 1)
	elif door_dir == Vector2i(1, 0):
		door_pos = Vector2i(build_rect.position.x + build_rect.size.x - 1, center_y)
	else:
		door_pos = Vector2i(build_rect.position.x, center_y)

	var entrances: Array[Dictionary] = [{"pos": door_pos, "dir": door_dir, "width": door_w}]
	if template == &"passage" and build_rect.size.x >= 8 and build_rect.size.y >= 8:
		var rear_dir: Vector2i = -door_dir
		var rear_pos: Vector2i = door_pos
		if rear_dir == Vector2i(0, -1):
			rear_pos = Vector2i(center_x, build_rect.position.y)
		elif rear_dir == Vector2i(0, 1):
			rear_pos = Vector2i(center_x, build_rect.position.y + build_rect.size.y - 1)
		elif rear_dir == Vector2i(1, 0):
			rear_pos = Vector2i(build_rect.position.x + build_rect.size.x - 1, center_y)
		else:
			rear_pos = Vector2i(build_rect.position.x, center_y)
		entrances.append({"pos": rear_pos, "dir": rear_dir, "width": door_w})

	var floor_tex: int = int(cfg.get("indoor_floor_tex", 3))
	if template == &"workshop":
		floor_tex = int(cfg.get("workshop_floor_tex", 4))
	elif template == &"row_house":
		floor_tex = int(cfg.get("residential_floor_tex", 2))
	var stamp_rng := RandomNumberGenerator.new()
	stamp_rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4013 + build_rect.position.x * 17 + build_rect.position.y * 31)
	chunk_manager._stamp_floor_rect_cells(chunk, build_rect, floor_tex, stamp_rng, float(cfg.get("indoor_floor_alpha", 0.95)), int(cfg.get("indoor_floor_z", -94)))

	var carve_rng := RandomNumberGenerator.new()
	carve_rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4027 + build_rect.position.x * 19 + build_rect.position.y * 23)
	var room_attempts: int = int(cfg.get("facility_room_attempts", 24))
	if template == &"row_house":
		room_attempts = 12
	elif template == &"shop":
		room_attempts = 18
	elif template == &"workshop":
		room_attempts = 10
	var room_min: Vector2i = Vector2i(4, 4)
	var room_max: Vector2i = Vector2i(maxi(5, mini(9, build_rect.size.x - 2)), maxi(5, mini(8, build_rect.size.y - 2)))
	var carve := RECT_FAC.carve_room_first(
		build_rect,
		carve_rng,
		room_attempts,
		room_min,
		room_max,
		1,
		1,
		float(cfg.get("facility_window_chance", 0.18)),
		entrances,
		floor_tex,
		int(cfg.get("facility_floor_corr_tex", 2))
	)

	var wall_cells: Dictionary = {}
	var window_cells: Dictionary = {}
	for wall_key in carve.wall_cells.keys():
		wall_cells[wall_key] = true
	for window_key in carve.window_cells.keys():
		window_cells[window_key] = true
	for window_key in window_cells.keys():
		if not wall_cells.has(window_key):
			window_cells.erase(window_key)
	chunk_manager._spawn_wall_cells(chunk, wall_cells, window_cells)

	for entrance in entrances:
		var entrance_pos: Vector2i = entrance.get("pos", Vector2i.ZERO) as Vector2i
		var entrance_dir: Vector2i = entrance.get("dir", Vector2i.ZERO) as Vector2i
		_stamp_door_apron(chunk_manager, chunk, coord, build_rect, entrance_pos, entrance_dir, apron_len, cfg, chunk_rect)
		var door_socket := Marker2D.new()
		door_socket.name = "DoorSpawnSocket"
		door_socket.position = (Vector2(entrance_pos + entrance_dir) + Vector2(0.5, 0.5)) * float(chunk_manager.cell_size_px)
		door_socket.add_to_group(&"enemy_spawn_socket")
		door_socket.set_meta("spawn_socket_kind", &"door")
		chunk.add_child(door_socket)

	var configured_secondary_id: int = int(cfg.get("secondary_objective_id", 0))
	var building_secondary_id: int = 0
	var building_local_encounter: bool = false
	if configured_secondary_id > 0 and not bool(cfg.get("_secondary_assigned", false)):
		building_secondary_id = configured_secondary_id
		building_local_encounter = bool(cfg.get("local_encounter_enabled", false))
		cfg["_secondary_assigned"] = true
	var building_loot_chance: float = float(cfg.get("parcel_loot_chance", 0.22))
	if configured_secondary_id > 0 and building_secondary_id == 0:
		building_loot_chance = float(cfg.get("ambient_parcel_loot_chance", 0.24))

	if INDOOR_VOLUME_SCENE != null:
		var interior: Rect2i = build_rect.grow(-1)
		if interior.size.x > 0 and interior.size.y > 0:
			var volume := INDOOR_VOLUME_SCENE.instantiate() as IndoorVolume
			if volume != null:
				var global_tl: Vector2i = coord * cpc + interior.position
				var building_id: int = int(_mix_seed(int(chunk_manager.world_seed), global_tl.x, global_tl.y, 77) & 0x7fffffff) + 1
				var loot_cfg: Dictionary = {
					"small_loot_chance": building_loot_chance,
					"small_count_min": int(cfg.get("parcel_loot_count_min", 1)),
					"small_count_max": int(cfg.get("parcel_loot_count_max", 1)),
					"small_rarity_min": int(cfg.get("parcel_loot_rarity_min", 3)),
					"small_rarity_max": int(cfg.get("parcel_loot_rarity_max", 6)),
					"small_rarity_bonus_per_segment": int(cfg.get("parcel_loot_rarity_bonus_per_segment", 0)),
					"scatter_radius_px": float(cfg.get("parcel_loot_scatter_radius", 24.0)),
					"pickup_delay": float(cfg.get("parcel_loot_pickup_delay", 0.15)),
					"local_encounter_enabled": building_local_encounter,
					"local_encounter_count": int(cfg.get("local_encounter_count", 5)),
					"secondary_objective_id": building_secondary_id,
				}
				volume.configure(global_tl, interior.size, int(chunk_manager.cell_size_px), building_id, loot_cfg)
				chunk.add_child(volume)
				if ROOF_OVERLAY_SCENE != null:
					var roof := ROOF_OVERLAY_SCENE.instantiate()
					chunk.add_child(roof)
					if roof.has_method("configure"):
						roof.configure(build_rect, int(chunk_manager.cell_size_px), door_dir, volume, template, building_id)

	placed.append(build_rect)
	return true


func _stamp_door_apron(chunk_manager: Node, chunk: Node2D, coord: Vector2i, build_rect: Rect2i, door_pos: Vector2i, door_dir: Vector2i, apron_len: int, cfg: Dictionary, chunk_rect: Rect2i) -> void:
	var apron := Rect2i()
	if door_dir == Vector2i(0, -1):
		apron = Rect2i(Vector2i(door_pos.x - 2, build_rect.position.y - apron_len), Vector2i(5, apron_len))
	elif door_dir == Vector2i(0, 1):
		apron = Rect2i(Vector2i(door_pos.x - 2, build_rect.position.y + build_rect.size.y), Vector2i(5, apron_len))
	elif door_dir == Vector2i(1, 0):
		apron = Rect2i(Vector2i(build_rect.position.x + build_rect.size.x, door_pos.y - 2), Vector2i(apron_len, 5))
	else:
		apron = Rect2i(Vector2i(build_rect.position.x - apron_len, door_pos.y - 2), Vector2i(apron_len, 5))
	var clipped: Rect2i = apron.intersection(chunk_rect)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	var apron_rng := RandomNumberGenerator.new()
	apron_rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4099 + clipped.position.x * 7 + clipped.position.y * 11)
	chunk_manager._stamp_floor_rect_cells(chunk, clipped, int(cfg.get("door_apron_tex", 4)), apron_rng, float(cfg.get("door_apron_alpha", 0.92)), int(cfg.get("door_apron_z", -93)))


func _rect_inside_chunk(rect: Rect2i, chunk_rect: Rect2i) -> bool:
	return rect.size.x > 0 and rect.size.y > 0 and chunk_rect.encloses(rect)


func _rect_can_place(rect: Rect2i, chunk_rect: Rect2i, keepout_rects: Array[Rect2i], placed: Array[Rect2i]) -> bool:
	if not _rect_inside_chunk(rect, chunk_rect):
		return false
	for keepout in keepout_rects:
		if keepout.size.x > 0 and keepout.size.y > 0 and keepout.intersects(rect):
			return false
	for existing in placed:
		if existing.intersects(rect):
			return false
	return true


func _mix_seed(a: int, b: int, c: int, d: int) -> int:
	var x: int = a * 1103515245 + 12345
	x = int(x ^ (b * 374761393))
	x = int(x ^ (c * 668265263))
	x = int(x ^ (d * 2246822519))
	x = int((x ^ (x >> 13)) * 1274126177)
	x = int(x ^ (x >> 16))
	return x
