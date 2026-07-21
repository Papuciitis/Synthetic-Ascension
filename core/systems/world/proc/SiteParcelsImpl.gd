extends RefCounted
class_name SiteParcelsImpl

const RECT_FAC := preload("res://core/systems/world/proc/RectFacilityCarver.gd")
const INDOOR_VOLUME_SCENE: PackedScene = preload("res://scenes/world/volumes/IndoorVolume.tscn")
const ROOF_OVERLAY_SCENE: PackedScene = preload("res://scenes/world/buildings/RoofOverlay.tscn")
const LOOT_SPAWNER_SCENE: PackedScene = preload("res://scenes/world/pickups/ExplorationLootSpawner.tscn")

func decorate_district_parcels(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	lane_rect_h: Rect2i,
	lane_rect_v: Rect2i,
	keepout_rects: Array[Rect2i],
	cfg: Dictionary
) -> Array[Rect2i]:
	# Returns local building rects placed (for extra keepout).
	var placed: Array[Rect2i] = []

	var has_h: bool = lane_rect_h.size.y > 0
	var has_v: bool = lane_rect_v.size.x > 0
	# Skip intersections for now (cleaner streets).
	if has_h == has_v:
		return placed

	var cpc: int = int(chunk_manager._cells_per_chunk())
	var chunk_rect := Rect2i(Vector2i(0, 0), Vector2i(cpc, cpc))

	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4001)

	var chance_side: float = float(cfg.get("parcel_chance_per_side", 0.55))
	var max_per_side: int = int(cfg.get("parcel_max_per_side", 1))
	var depth: int = int(cfg.get("parcel_depth_cells", 10))
	var street_gap: int = int(cfg.get("parcel_street_gap_cells", 1))

	# --- Place parcels depending on lane orientation ---
	if has_h:
		# North band (above lane): door faces south (toward lane)
		var top_band_y1 := lane_rect_h.position.y - street_gap
		var top_y0 := top_band_y1 - depth
		var band_n := Rect2i(Vector2i(2, top_y0), Vector2i(cpc - 4, depth))
		if _rect_can_place(band_n, chunk_rect, keepout_rects, placed) and rng.randf() < chance_side:
			for _j in range(max_per_side):
				_spawn_building_in_band(chunk_manager, chunk, coord, band_n, Vector2i(0, 1), keepout_rects, placed, cfg, rng, chunk_rect)

		# South band: door faces north
		var bot_y0 := lane_rect_h.position.y + lane_rect_h.size.y + street_gap
		var band_s := Rect2i(Vector2i(2, bot_y0), Vector2i(cpc - 4, depth))
		if _rect_can_place(band_s, chunk_rect, keepout_rects, placed) and rng.randf() < chance_side:
			for _j in range(max_per_side):
				_spawn_building_in_band(chunk_manager, chunk, coord, band_s, Vector2i(0, -1), keepout_rects, placed, cfg, rng, chunk_rect)

	else:
		# West band: door faces east
		var left_x1 := lane_rect_v.position.x - street_gap
		var left_x0 := left_x1 - depth
		var band_w := Rect2i(Vector2i(left_x0, 2), Vector2i(depth, cpc - 4))
		if _rect_can_place(band_w, chunk_rect, keepout_rects, placed) and rng.randf() < chance_side:
			for _j in range(max_per_side):
				_spawn_building_in_band(chunk_manager, chunk, coord, band_w, Vector2i(1, 0), keepout_rects, placed, cfg, rng, chunk_rect)

		# East band: door faces west
		var right_x0 := lane_rect_v.position.x + lane_rect_v.size.x + street_gap
		var band_e := Rect2i(Vector2i(right_x0, 2), Vector2i(depth, cpc - 4))
		if _rect_can_place(band_e, chunk_rect, keepout_rects, placed) and rng.randf() < chance_side:
			for _j in range(max_per_side):
				_spawn_building_in_band(chunk_manager, chunk, coord, band_e, Vector2i(-1, 0), keepout_rects, placed, cfg, rng, chunk_rect)

	return placed


func _rect_can_place(r: Rect2i, chunk_rect: Rect2i, keepout_rects: Array[Rect2i], placed: Array[Rect2i]) -> bool:
	if r.size.x <= 0 or r.size.y <= 0:
		return false
	if not chunk_rect.encloses(r):
		return false
	for k: Rect2i in keepout_rects:
		if k.size.x > 0 and k.size.y > 0 and k.intersects(r):
			return false
	for b: Rect2i in placed:
		if b.intersects(r.grow(1)):
			return false
	return true


func _spawn_building_in_band(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	band: Rect2i,
	door_dir: Vector2i,
	keepout_rects: Array[Rect2i],
	placed: Array[Rect2i],
	cfg: Dictionary,
	rng: RandomNumberGenerator,
	chunk_rect: Rect2i
) -> void:
	var cpc: int = int(chunk_manager._cells_per_chunk())
	var margin: int = int(cfg.get("parcel_building_margin_cells", 1))
	var depth: int = int(cfg.get("parcel_depth_cells", 10))
	var len_min: int = int(cfg.get("parcel_length_min_cells", 10))
	var len_max: int = int(cfg.get("parcel_length_max_cells", 18))
	var door_w: int = int(cfg.get("parcel_door_width", 2))
	var apron_len: int = int(cfg.get("parcel_apron_len", 2))

	var usable := band.grow(-margin)
	if usable.size.x < 8 or usable.size.y < 8:
		return

	# Determine orientation: if door_dir has Y, street is horizontal and building extends on X.
	var build_rect: Rect2i

	if door_dir.y != 0:
		var b_len := clampi(rng.randi_range(len_min, len_max), 8, usable.size.x)
		var b_depth := clampi(depth - margin * 2, 8, usable.size.y)
		var x0 := rng.randi_range(usable.position.x, maxi(usable.position.x, usable.position.x + usable.size.x - b_len))
		var y0 := usable.position.y
		build_rect = Rect2i(Vector2i(x0, y0), Vector2i(b_len, b_depth))
	else:
		var b_len2 := clampi(rng.randi_range(len_min, len_max), 8, usable.size.y)
		var b_depth2 := clampi(depth - margin * 2, 8, usable.size.x)
		var y02 := rng.randi_range(usable.position.y, maxi(usable.position.y, usable.position.y + usable.size.y - b_len2))
		var x02 := usable.position.x
		build_rect = Rect2i(Vector2i(x02, y02), Vector2i(b_depth2, b_len2))

	if not _rect_can_place(build_rect, chunk_rect, keepout_rects, placed):
		return

	# Door position on border (centered), facing the lane.
	var cx: int = int(round(float(build_rect.size.x - 1) * 0.5))
	var cy: int = int(round(float(build_rect.size.y - 1) * 0.5))
	var door_pos: Vector2i = Vector2i.ZERO
	if door_dir == Vector2i(0, -1): # N
		door_pos = Vector2i(build_rect.position.x + cx, build_rect.position.y)
	elif door_dir == Vector2i(0, 1): # S
		door_pos = Vector2i(build_rect.position.x + cx, build_rect.position.y + build_rect.size.y - 1)
	elif door_dir == Vector2i(1, 0): # E
		door_pos = Vector2i(build_rect.position.x + build_rect.size.x - 1, build_rect.position.y + cy)
	else: # W
		door_pos = Vector2i(build_rect.position.x, build_rect.position.y + cy)

	var entrances: Array[Dictionary] = [
		{"pos": door_pos, "dir": door_dir, "width": door_w}
	]

	# Base floor (interior)
	var rng_stamp := RandomNumberGenerator.new()
	rng_stamp.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4013 + build_rect.position.x * 17 + build_rect.position.y * 31)
	chunk_manager._stamp_floor_rect_cells(
		chunk,
		build_rect,
		int(cfg.get("indoor_floor_tex", 3)),
		rng_stamp,
		float(cfg.get("indoor_floor_alpha", 0.95)),
		int(cfg.get("indoor_floor_z", -94))
	)

	# Carve interior partitions (room-first)
	var rng_carve := RandomNumberGenerator.new()
	rng_carve.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4027 + build_rect.position.x * 19 + build_rect.position.y * 23)

	var room_attempts := int(cfg.get("facility_room_attempts", 30))
	var room_min := cfg.get("facility_room_min", Vector2i(5, 5)) as Vector2i
	var room_max := cfg.get("facility_room_max", Vector2i(10, 9)) as Vector2i
	var room_pad := int(cfg.get("facility_room_padding", 1))
	var corridor_w := int(cfg.get("facility_corridor_w", 1))
	var window_ch := float(cfg.get("facility_window_chance", 0.18))
	var tex_room := int(cfg.get("facility_floor_room_tex", 3))
	var tex_corr := int(cfg.get("facility_floor_corr_tex", 2))

	var carve := RECT_FAC.carve_room_first(
		build_rect,
		rng_carve,
		room_attempts,
		room_min,
		room_max,
		room_pad,
		corridor_w,
		window_ch,
		entrances,
		tex_room,
		tex_corr
	)

	# Walls + windows
	var wall_cells_chunk: Dictionary = {}
	var window_cells_chunk: Dictionary = {}
	for k in carve.wall_cells.keys():
		var p: Vector2i = k as Vector2i
		wall_cells_chunk[p] = true
	for k in carve.window_cells.keys():
		var p2: Vector2i = k as Vector2i
		window_cells_chunk[p2] = true

	_trim_wall_spurs(wall_cells_chunk, 2)
	for k in window_cells_chunk.keys():
		if not wall_cells_chunk.has(k):
			window_cells_chunk.erase(k)

	chunk_manager._spawn_wall_cells(chunk, wall_cells_chunk, window_cells_chunk)

	# Door apron outside (non-blocking floor stamp)
	var apron: Rect2i
	match door_dir:
		Vector2i(0, -1): # N
			apron = Rect2i(Vector2i(door_pos.x - 2, build_rect.position.y - apron_len), Vector2i(5, apron_len))
		Vector2i(0, 1): # S
			apron = Rect2i(Vector2i(door_pos.x - 2, build_rect.position.y + build_rect.size.y), Vector2i(5, apron_len))
		Vector2i(1, 0): # E
			apron = Rect2i(Vector2i(build_rect.position.x + build_rect.size.x, door_pos.y - 2), Vector2i(apron_len, 5))
		_: # W
			apron = Rect2i(Vector2i(build_rect.position.x - apron_len, door_pos.y - 2), Vector2i(apron_len, 5))

	var clip := apron.intersection(chunk_rect)
	if clip.size.x > 0 and clip.size.y > 0:
		var rng_ap := RandomNumberGenerator.new()
		rng_ap.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4099 + clip.position.x * 7 + clip.position.y * 11)
		chunk_manager._stamp_floor_rect_cells(chunk, clip, int(cfg.get("door_apron_tex", 4)), rng_ap, float(cfg.get("door_apron_alpha", 0.92)), int(cfg.get("door_apron_z", -93)))

	# Indoor volume (inset)
	if INDOOR_VOLUME_SCENE != null:
		var interior := build_rect.grow(-1)
		if interior.size.x > 0 and interior.size.y > 0:
			var vol := INDOOR_VOLUME_SCENE.instantiate()
			chunk.add_child(vol)
			var global_tl := coord * cpc + interior.position
			vol.configure(global_tl, interior.size, int(chunk_manager.cell_size_px), int(_mix_seed(int(chunk_manager.world_seed), global_tl.x, global_tl.y, 77)))

			# Exploration loot: small streetfront buildings (deterministic per building_id)
			if bool(cfg.get('use_legacy_parcel_loot_spawner', false)) and LOOT_SPAWNER_SCENE != null:
				var lid: int = int(vol.building_id)
				if lid == 0:
					# fallback: stable from world seed + location
					lid = int(_mix_seed(int(chunk_manager.world_seed), global_tl.x, global_tl.y, 177) & 0x7fffffff) + 1

				# Roll ONCE here (so the spawner always spawns if created).
				var rng_loot := RandomNumberGenerator.new()
				rng_loot.seed = int(_mix_seed(int(chunk_manager.world_seed), lid, 0, 31337) & 0x7fffffff)
				var chance: float = float(cfg.get('parcel_loot_chance', 0.55))
				if rng_loot.randf() < clampf(chance, 0.0, 1.0):
					var sp := LOOT_SPAWNER_SCENE.instantiate() as Node2D
					if sp != null:
						chunk.add_child(sp)
						var _loot_center_cell: Vector2 = Vector2(global_tl) + Vector2(interior.size) * 0.5
						sp.global_position = (_loot_center_cell + Vector2(0.5, 0.5)) * float(chunk_manager.cell_size_px)
						sp.set('loot_id', lid)
						sp.set('spawn_chance', 1.0)
						sp.set('count_min', int(cfg.get('parcel_loot_count_min', 1)))
						sp.set('count_max', int(cfg.get('parcel_loot_count_max', 1)))
						sp.set('rarity_min', int(cfg.get('parcel_loot_rarity_min', 4)))
						sp.set('rarity_max', int(cfg.get('parcel_loot_rarity_max', 6)))
						sp.set('rarity_bonus_per_segment', int(cfg.get('parcel_loot_rarity_bonus_per_segment', 0)))
						sp.set('scatter_radius', float(cfg.get('parcel_loot_scatter_radius', 24.0)))
						sp.set('pickup_delay', float(cfg.get('parcel_loot_pickup_delay', 0.15)))
			# Roof/overhang silhouette (fades when player is indoors)
			if ROOF_OVERLAY_SCENE != null:
				var roof := ROOF_OVERLAY_SCENE.instantiate()
				chunk.add_child(roof)
				if roof.has_method("configure"):
					roof.configure(build_rect, int(chunk_manager.cell_size_px), door_dir, vol)

	placed.append(build_rect)

func _mix_seed(a: int, b: int, c: int, d: int) -> int:
	# Simple 32-bit-ish integer mix (deterministic)
	var x: int = a * 1103515245 + 12345
	x = int(x ^ (b * 374761393))
	x = int(x ^ (c * 668265263))
	x = int(x ^ (d * 2246822519))
	x = int((x ^ (x >> 13)) * 1274126177)
	x = int(x ^ (x >> 16))
	return x

func _trim_wall_spurs(wall_cells: Dictionary, iterations: int) -> void:
	if iterations <= 0:
		return
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for _i in range(iterations):
		var to_remove: Array[Vector2i] = []
		for k in wall_cells.keys():
			var p: Vector2i = k as Vector2i
			var n: int = 0
			for d in dirs:
				if wall_cells.has(p + d):
					n += 1
			if n <= 1:
				to_remove.append(p)
		for p in to_remove:
			wall_cells.erase(p)


# -------------------------------------------------------------------
# District streetfront parcels (shops/facilities hugging the lane)
# -------------------------------------------------------------------
