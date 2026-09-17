extends Object
const LOOT_SPAWNER_SCENE: PackedScene = preload("res://scenes/world/pickups/ExplorationLootSpawner.tscn")
const INDOOR_VOLUME_SCENE: PackedScene = preload("res://scenes/world/volumes/IndoorVolume.tscn")

# Direction bits used by `conn_mask` (must match the producer of conn_mask).
const _DIR_N: int = 1
const _DIR_E: int = 2
const _DIR_S: int = 4
const _DIR_W: int = 8
# Auto-extracted from ChunkGenImpl.gd to keep the generator modular.
# Do not keep state here; use the passed `gen` (ChunkGenImpl) as context.

static func _generate_district(gen: ChunkGenImpl, chunk: Node2D, rng: RandomNumberGenerator, coord: Vector2i, archetype: StringName, conn_mask: int) -> void:
	var cells := gen._cells_per_chunk()
	if cells < 8:
		return
	var role: StringName = gen.get_chunk_role(coord)
	var urban_access_mask: int = gen.get_chunk_urban_access(coord)

	# Urban-envelope chunks are full courtyard blocks rather than empty terrain. They
	# intentionally have no road connectors, so they cannot create fake streets.
	if role == &"district_fill" and conn_mask == 0 and gen._site_mgr != null:
		var fill_cfg: Dictionary = {
			"courtyard_floor_tex": 8,
			"passage_floor_tex": 4,
			"urban_fill_frontage_target": 0.82,
			"urban_fill_loot_chance": 0.18,
			"parcel_building_margin_cells": 0,
			"parcel_door_width": 2,
			"parcel_apron_len": 2,
			"facility_window_chance": maxf(0.16, gen.parcels_window_chance),
			"indoor_floor_tex": 3,
			"residential_floor_tex": 2,
			"workshop_floor_tex": 4,
			"facility_floor_corr_tex": 2,
			"door_apron_tex": 4,
			"door_apron_alpha": 0.92,
			"door_apron_z": -93,
			"parcel_loot_count_min": 1,
			"parcel_loot_count_max": 1,
			"parcel_loot_rarity_min": 3,
			"parcel_loot_rarity_max": 5,
			"parcel_loot_pickup_delay": 0.15,
			"urban_access_mask": urban_access_mask,
		}
		gen._site_mgr.decorate_urban_fill(gen.cm, chunk, coord, fill_cfg)
		return

	# Dedicated RNGs for floor/sidewalk visuals so wall/prop layout stays stable.
	var base_seed: int = gen._seed_for_chunk(coord)
	var rng_roads := RandomNumberGenerator.new()
	rng_roads.seed = gen._mix_seed_int(base_seed, 9001)
	var rng_sidewalk := RandomNumberGenerator.new()
	rng_sidewalk.seed = gen._mix_seed_int(base_seed, 9002)
	var rng_edge := RandomNumberGenerator.new()
	rng_edge.seed = gen._mix_seed_int(base_seed, 9003)
	var rng_plaza_deco := RandomNumberGenerator.new()
	rng_plaza_deco.seed = gen._mix_seed_int(base_seed, 9004)
	var bounds: Rect2i = Rect2i(Vector2i(0, 0), Vector2i(cells, cells))


	# Urban hierarchy is semantic rather than one theme-wide boulevard width.
	# At the project's 64 px cell scale these become 384-512 px main roads,
	# 256-320 px secondary roads, and genuinely tight 128-192 px alleys.
	var lane_w: int = 7
	match role:
		&"secondary_route": lane_w = 5
		&"service_lane", &"secondary_reward_building": lane_w = 3
		&"dangerous_alley", &"secondary_alley_cache": lane_w = 2
		&"checkpoint", &"exit_approach", &"gate": lane_w = 7
		&"primary_objective": lane_w = 6
		# REMAPPED, not clamped.
		#
		# Themes author 10-16 and this originally clamped to 6-8, so every main
		# street collapsed to exactly 8 and boulevard districts were the same
		# width as tight-lane ones. Widening the clamp to 14 fixed that and
		# broke something worse: the donjon side regions are the road lane's
		# leftovers, they are dropped below 10x10, and at lane_w 13-14 roughly
		# HALF of all rows produce no carvable region at all - so half the
		# chunks lost their buildings and became two wall lines flanking a road.
		# That is the exact "routes drawn across a field" symptom the envelope
		# change was fixing.
		#
		# Remapping preserves the ordering the themes are expressing while
		# keeping every width inside the band that still leaves a carvable
		# region on both sides.
		_: lane_w = _remapped_lane_width(gen.district_lane_width_cells)
	lane_w = clampi(lane_w, 2, cells - 6)

	var plaza_size := clampi(gen.district_plaza_size_cells, 10, cells - 4)
	if role == &"landmark_plaza":
		plaza_size = mini(cells - 4, plaza_size + 4)
	elif role == &"entry_court" or role == &"wardstone_court" or role == &"checkpoint":
		plaza_size = mini(cells - 4, plaza_size + 2)

	var lane_cy := gen._lane_center_for_row(coord.y, cells)
	var lane_cx := gen._lane_center_for_col(coord.x, cells)

	var has_h: bool = (conn_mask & (_DIR_E | _DIR_W)) != 0
	var has_v: bool = (conn_mask & (_DIR_N | _DIR_S)) != 0

	var has_plaza: bool = false
	var plaza_rect: Rect2i = Rect2i()

	# Lane keepout (contract): never allow walls/solid props in the street cores.
	var lane_rect_h: Rect2i = Rect2i()
	var lane_rect_v: Rect2i = Rect2i()
	var keepout_rects: Array[Rect2i] = []

	# --- floors ---
	# Main streets use restrained masonry; side/service routes use dirt paths so the
	# player can read route hierarchy without invisible walls or hard boundaries.
	var road_tex_index: int = 7
	var road_alpha: float = 0.88
	if role == &"secondary_route":
		road_tex_index = 8
		road_alpha = 0.80
	elif role == &"service_lane" or role == &"secondary_reward_building":
		road_tex_index = 4
		road_alpha = 0.78
	elif role == &"dangerous_alley" or role == &"secondary_alley_cache":
		road_tex_index = 8
		road_alpha = 0.74
	elif role == &"checkpoint" or role == &"exit_approach":
		road_tex_index = 3
		road_alpha = 0.92
	elif role == &"primary_objective":
		road_tex_index = 9
		road_alpha = 0.94

	var lane_y0 := clampi(lane_cy - int(lane_w / 2.0), 1, cells - lane_w - 1)
	var lane_x0 := clampi(lane_cx - int(lane_w / 2.0), 1, cells - lane_w - 1)
	var hub_x1: int = lane_x0 + lane_w
	var hub_y1: int = lane_y0 + lane_w

	# Exact connector arms. N+E is an L-turn, not an accidental four-way road.
	if has_h:
		var h_x0: int = 0 if (conn_mask & _DIR_W) != 0 else lane_x0
		var h_x1: int = cells if (conn_mask & _DIR_E) != 0 else hub_x1
		lane_rect_h = Rect2i(Vector2i(h_x0, lane_y0), Vector2i(maxi(1, h_x1 - h_x0), lane_w))
		keepout_rects.append(lane_rect_h)
		gen._stamp_floor_rect_cells_patchy(chunk, lane_rect_h, road_tex_index, rng_roads, road_alpha, -95)

	if has_v:
		var v_y0: int = 0 if (conn_mask & _DIR_N) != 0 else lane_y0
		var v_y1: int = cells if (conn_mask & _DIR_S) != 0 else hub_y1
		lane_rect_v = Rect2i(Vector2i(lane_x0, v_y0), Vector2i(lane_w, maxi(1, v_y1 - v_y0)))
		keepout_rects.append(lane_rect_v)
		gen._stamp_floor_rect_cells_patchy(chunk, lane_rect_v, road_tex_index, rng_roads, road_alpha, -95)

	# Courtyard-access corridors meet neighbouring urban blocks at the centre of
	# the shared edge, then bend toward this chunk's road hub. They are kept clear
	# of buildings and wall decoration just like street cores.
	var urban_access_rects: Array[Rect2i] = _urban_access_corridors(urban_access_mask, cells, lane_cx, lane_cy)
	for access_rect in urban_access_rects:
		keepout_rects.append(access_rect.grow(1).intersection(bounds))
		gen._stamp_floor_rect_cells_patchy(chunk, access_rect, 4, rng_roads, 0.82, -94)

	_add_connector_spawn_sockets(chunk, conn_mask, lane_cx, lane_cy, cells, gen.cell_size_px)

	var semantic_plaza: bool = role == &"entry_court" or role == &"landmark_plaza" or role == &"wardstone_court" or role == &"checkpoint" or role == &"exploration_reward" or role == &"primary_objective" or role == &"miniboss_arena" or role == &"boss_arena"
	if archetype == &"plaza" or archetype == &"arena" or archetype == &"gate" or semantic_plaza:
		var pcx := (lane_cx if has_v else int(cells / 2.0))
		var pcy := (lane_cy if has_h else int(cells / 2.0))

		var px0 := clampi(pcx - int(plaza_size / 2.0), 2, cells - plaza_size - 2)
		var py0 := clampi(pcy - int(plaza_size / 2.0), 2, cells - plaza_size - 2)

		has_plaza = true
		plaza_rect = Rect2i(Vector2i(px0, py0), Vector2i(plaza_size, plaza_size))

		var tex_idx: int = 7
		if archetype == &"gate" or role == &"checkpoint" or role == &"miniboss_arena" or role == &"boss_arena":
			tex_idx = 3
		elif role == &"primary_objective":
			tex_idx = 9
		gen._stamp_floor_rect_cells_patchy(chunk, Rect2i(Vector2i(px0, py0), Vector2i(plaza_size, plaza_size)), tex_idx, rng_roads, 0.95, -94)

	
	# --- sidewalks + curb pads (visual readability) ---
	gen._stamp_district_sidewalks(chunk, bounds, lane_rect_h, lane_rect_v, rng_sidewalk)
	gen._stamp_district_road_edge_noise(chunk, bounds, lane_rect_h, lane_rect_v, rng_edge)

	# --- streetfront parcels (shops/facilities hugging the lane) ---
	var parcels_placed: bool = false
	var forced_reward_building: bool = role == &"optional_interior" or role == &"secondary_reward_building"
	var parcel_roll_chance: float = 1.0 if forced_reward_building else gen.parcels_chunk_chance
	if gen.parcels_enabled and gen._site_mgr != null and rng.randf() < parcel_roll_chance and not has_plaza:
		if (has_h or has_v) and (archetype == &"street" or archetype == &"district"):
			var pcfg := {
				"force_parcel": forced_reward_building,
				"frontage_target": (0.92 if role == &"dangerous_alley" or role == &"secondary_alley_cache" else 0.84),
				"frontage_passage_chance": (0.14 if role == &"dangerous_alley" or role == &"secondary_alley_cache" else 0.24),
				"passage_buildings_enabled": true,
				"parcel_chance_per_side": 1.0,
				"parcel_max_per_side": 4,
				"parcel_depth_cells": gen.parcels_depth_cells,
				"parcel_length_min_cells": 7,
				"parcel_length_max_cells": 13,
				"parcel_street_gap_cells": gen.parcels_street_gap_cells,
				"parcel_building_margin_cells": gen.parcels_building_margin_cells,
				"parcel_door_width": gen.parcels_door_width,
				"parcel_apron_len": gen.parcels_apron_len,
				"facility_window_chance": gen.parcels_window_chance,
				"indoor_floor_tex": 3,
				"indoor_floor_alpha": 0.95,
				"indoor_floor_z": -94,
				"door_apron_tex": 4,
				"door_apron_alpha": 0.92,
				"door_apron_z": -93,
				"facility_room_attempts": (34 if role == &"optional_interior" else 28),
				"facility_room_min": Vector2i(5, 5),
				"facility_room_max": Vector2i(10, 9),
				"facility_room_padding": 1,
				"facility_corridor_w": 1,
				"facility_floor_room_tex": 3,
				"facility_floor_corr_tex": 2,
				"residential_floor_tex": 2,
				"workshop_floor_tex": 4,
				# --- exploration loot (small buildings) ---
				"parcel_loot_chance": (1.0 if forced_reward_building else 0.55),
				"ambient_parcel_loot_chance": 0.24,
				"parcel_loot_count_min": 1,
				"parcel_loot_count_max": 1,
				"parcel_loot_rarity_min": 4,
				"parcel_loot_rarity_max": 6,
				"parcel_loot_rarity_bonus_per_segment": 0,
				"parcel_loot_scatter_radius": 24.0,
				"parcel_loot_pickup_delay": 0.15,
				"local_encounter_enabled": role == &"secondary_reward_building",
				"local_encounter_count": 5 + mini(3, int(float(Global.attempt_segment if Global != null else 2) / 3.0)),
				"secondary_objective_id": (DistrictPlan.secondary_objective_id(gen.world_seed, coord, &"searchable_reward_building") if role == &"secondary_reward_building" else 0),
			}
			var parcel_rects: Array[Rect2i] = gen._site_mgr.decorate_district_parcels(gen.cm, chunk, coord, lane_rect_h, lane_rect_v, keepout_rects, pcfg)
			if parcel_rects.size() > 0:
				parcels_placed = true
				for r: Rect2i in parcel_rects:
					keepout_rects.append(r)

	# --- walls / building edges (kept connected to avoid unreachable spawn pockets) ---
	var wall_cells: Dictionary = {}
	var window_cells: Dictionary = {}

	# Plazas/arenas/gates: break up huge slabs + add a stronger perimeter language.
	if has_plaza:
		if role != &"primary_objective":
			gen._decorate_plaza_floor(chunk, bounds, plaza_rect, rng_plaza_deco, archetype)
		var rng_ring := RandomNumberGenerator.new()
		rng_ring.seed = gen._mix_seed_int(base_seed, 9011)
		gen._add_plaza_ring(wall_cells, plaza_rect, cells, rng_ring, archetype)

	# Donjon-style micro carving in the side regions:
	# - Keeps the street cores open (your bullet-heaven needs space)
	# - Makes the "built" parts read like rooms + corridors instead of random wall lines
	var used_donjon: bool = false
	var door_gaps: Array[Array] = [] # Array[Array[Vector2i]]

	# Track biggest Donjon-carved region in this chunk for guaranteed dungeon loot.
	var best_dungeon_score: int = 0
	var best_dungeon_cell: Vector2i = Vector2i(-999999, -999999)
	var best_dungeon_id_seed: int = 0
	var best_dungeon_region: Rect2i = Rect2i()
	if gen.donjon_enabled and not parcels_placed and not (has_h and has_v) and rng.randf() < gen.donjon_strength:
		# Derive lane extents (even if only one axis exists).
		var donjon_lane_x0: int = (clampi(lane_cx - int(lane_w / 2.0), 1, cells - lane_w - 1) if has_v else 2)
		var donjon_lane_y0: int = (clampi(lane_cy - int(lane_w / 2.0), 1, cells - lane_w - 1) if has_h else 2)
		var donjon_lane_x1: int = (donjon_lane_x0 + lane_w - 1 if has_v else cells - 3)
		var donjon_lane_y1: int = (donjon_lane_y0 + lane_w - 1 if has_h else cells - 3)

		var regions: Array[Rect2i] = []
		if has_h and has_v:
			regions = [
				Rect2i(Vector2i(2, 2), Vector2i(donjon_lane_x0 - 2, donjon_lane_y0 - 2)),
				Rect2i(Vector2i(donjon_lane_x1 + 2, 2), Vector2i(cells - (donjon_lane_x1 + 2) - 2, donjon_lane_y0 - 2)),
				Rect2i(Vector2i(2, donjon_lane_y1 + 2), Vector2i(donjon_lane_x0 - 2, cells - (donjon_lane_y1 + 2) - 2)),
				Rect2i(Vector2i(donjon_lane_x1 + 2, donjon_lane_y1 + 2), Vector2i(cells - (donjon_lane_x1 + 2) - 2, cells - (donjon_lane_y1 + 2) - 2)),
			]
		elif has_h:
			regions = [
				Rect2i(Vector2i(2, 2), Vector2i(cells - 4, donjon_lane_y0 - 2)),
				Rect2i(Vector2i(2, donjon_lane_y1 + 2), Vector2i(cells - 4, cells - (donjon_lane_y1 + 2) - 2)),
			]
		elif has_v:
			regions = [
				Rect2i(Vector2i(2, 2), Vector2i(donjon_lane_x0 - 2, cells - 4)),
				Rect2i(Vector2i(donjon_lane_x1 + 2, 2), Vector2i(cells - (donjon_lane_x1 + 2) - 2, cells - 4)),
			]

		for r in regions:
			if r.size.x < 10 or r.size.y < 10:
				continue
			if has_plaza and r.intersects(plaza_rect.grow(1)):
				continue

			# --- dungeon loot anchor selection (largest region) ---
			var score: int = int(r.size.x) * int(r.size.y)
			if score > best_dungeon_score:
				best_dungeon_score = score
				var cx: int = r.position.x + int(floor(float(r.size.x) * 0.5))
				var cy: int = r.position.y + int(floor(float(r.size.y) * 0.5))
				best_dungeon_cell = Vector2i(cx, cy)
				var seed0: int = gen._mix_seed_int(int(gen.cm.world_seed), r.position.x)
				seed0 = gen._mix_seed_int(seed0, r.position.y)
				best_dungeon_id_seed = gen._mix_seed_int(seed0, 515)
				best_dungeon_region = r

			# Find which side faces a lane; place a 2-cell "door" gap there.
			var entrances: Array[Dictionary] = []
			var gap_cells: Array[Vector2i] = []
			# South-facing (region above a horizontal lane)
			if has_h and (r.position.y + r.size.y) == donjon_lane_y0:
				var y_edge: int = r.position.y + r.size.y - 1
				var cx: int = clampi(lane_cx, r.position.x + 2, r.position.x + r.size.x - 4)
				gap_cells = [Vector2i(cx, y_edge), Vector2i(cx + 1, y_edge)]
				entrances.append({ "pos": Vector2i(cx, y_edge - 1), "dir": Vector2i(0, -1), "width": 2 })
			# North-facing (region below a horizontal lane)
			elif has_h and r.position.y == (donjon_lane_y1 + 1):
				var y_edge2: int = r.position.y
				var cx2: int = clampi(lane_cx, r.position.x + 2, r.position.x + r.size.x - 4)
				gap_cells = [Vector2i(cx2, y_edge2), Vector2i(cx2 + 1, y_edge2)]
				entrances.append({ "pos": Vector2i(cx2, y_edge2 + 1), "dir": Vector2i(0, 1), "width": 2 })
			# East-facing (region left of a vertical lane)
			elif has_v and (r.position.x + r.size.x) == donjon_lane_x0:
				var x_edge: int = r.position.x + r.size.x - 1
				var cy3: int = clampi(lane_cy, r.position.y + 2, r.position.y + r.size.y - 4)
				gap_cells = [Vector2i(x_edge, cy3), Vector2i(x_edge, cy3 + 1)]
				entrances.append({ "pos": Vector2i(x_edge - 1, cy3), "dir": Vector2i(-1, 0), "width": 2 })
			# West-facing (region right of a vertical lane)
			elif has_v and r.position.x == (donjon_lane_x1 + 1):
				var x_edge2: int = r.position.x
				var cy4: int = clampi(lane_cy, r.position.y + 2, r.position.y + r.size.y - 4)
				gap_cells = [Vector2i(x_edge2, cy4), Vector2i(x_edge2, cy4 + 1)]
				entrances.append({ "pos": Vector2i(x_edge2 + 1, cy4), "dir": Vector2i(1, 0), "width": 2 })

			var result: DonjonCarver.CarveResult = DonjonCarver.carve_region(
				r, rng,
				gen.donjon_fill_wall_chance,
				gen.donjon_ca_steps,
				gen.donjon_room_attempts,
				gen.donjon_room_min,
				gen.donjon_room_max,
				gen.donjon_room_padding,
				gen.donjon_corridor_width,
				gen.district_window_chance * 0.65,
				entrances,
				3, # room floor: stone tiles
				4  # corridor floor: dirt path
			)

			# If this is the chosen 'best' region, refine the loot anchor to a real floor stamp center.
			if best_dungeon_region.size != Vector2i.ZERO and r == best_dungeon_region and result != null:
				if result.floor_stamps.size() > 0:
					var best_fs_area: int = -1
					var best_fs_rect: Rect2i = Rect2i()
					for fs in result.floor_stamps:
						var rr: Rect2i = fs.get('rect', Rect2i())
						var a: int = int(rr.size.x) * int(rr.size.y)
						if a > best_fs_area:
							best_fs_area = a
							best_fs_rect = rr
					if best_fs_area > 0:
						var fx: int = best_fs_rect.position.x + int(floor(float(best_fs_rect.size.x) * 0.5))
						var fy: int = best_fs_rect.position.y + int(floor(float(best_fs_rect.size.y) * 0.5))
						best_dungeon_cell = Vector2i(fx, fy)

			# Floors (stamps)
			for fs in result.floor_stamps:
				gen._stamp_floor_rect_cells(chunk, fs["rect"], int(fs["tex"]), rng, float(fs["alpha"]), int(fs["z"]))

			# Props
			for hc in result.half_cover_cells:
				var c2: Vector2i = hc
				gen._spawn_block(chunk, gen.cover_half_scene, c2.x, c2.y)

			# Walls
			for wk in result.wall_cells.keys():
				wall_cells[wk] = true
			for wk2 in result.window_cells.keys():
				window_cells[wk2] = true

			# Everything below is PER CARVED REGION, not per window cell. It used to
			# be indented into the loop above, which meant a region with twenty
			# windows built twenty identical overlapping IndoorVolume areas - twenty
			# physics bodies and twenty loot/encounter state machines on one room -
			# and appended the same door-gap array twenty times. Worse, a region with
			# NO windows never reached `used_donjon = true`, so the fallback
			# street-edge wall lines further down ran as well and stacked a second
			# set of walls on top of the carved geometry.
			if gap_cells.size() > 0:
				door_gaps.append(gap_cells)

			# Mark connected Donjon rooms as interiors so ambient spawns stay on
			# streets until the player actually enters the structure.
			if INDOOR_VOLUME_SCENE != null:
				var indoor_volume := INDOOR_VOLUME_SCENE.instantiate() as IndoorVolume
				if indoor_volume != null:
					var global_tl: Vector2i = coord * cells + r.position
					var building_id: int = int(gen._mix_seed_int(base_seed, r.position.x * 101 + r.position.y * 307) & 0x7fffffff) + 1
					indoor_volume.configure(global_tl, r.size, gen.cell_size_px, building_id, {"exploration_loot_enabled": false})
					chunk.add_child(indoor_volume)

			used_donjon = true



	# ------------------------------------------------------------
	# Exploration loot: big dungeon interiors (Donjon-carved regions)
	# Guarantee at least 1 item if this chunk used Donjon carving.
	# ------------------------------------------------------------
	if (not parcels_placed) and best_dungeon_score > 0 and LOOT_SPAWNER_SCENE != null:
		var sp := LOOT_SPAWNER_SCENE.instantiate() as Node2D
		if sp != null:
			var lid: int = gen._mix_seed_int(best_dungeon_id_seed, coord.x)
			lid = gen._mix_seed_int(lid, coord.y)
			lid = gen._mix_seed_int(lid, 9901)
			lid = int(lid & 0x7fffffff) + 1

			sp.set("loot_id", lid)
			sp.set("spawn_chance", 1.0)
			sp.set("count_min", 1)
			sp.set("count_max", 2)
			sp.set("rarity_min", 4)
			sp.set("rarity_max", 7)
			sp.set("scatter_radius", 32.0)
			sp.set("require_walkable", true)
			sp.set("pos_attempts", 20)
			# optional: toggle to true while testing
			# sp.set("debug_draw_marker", true)
			sp.set("pickup_delay", 0.15)
			sp.position = (Vector2(best_dungeon_cell) + Vector2(0.5, 0.5)) * float(gen.cell_size_px)
			chunk.add_child(sp)
	# If parcels were placed, we already created coherent streetfront structures.
	if parcels_placed:
		used_donjon = true
	# If donjon didn't run (small regions / chance), fall back to straight street-edge lines.
	if not used_donjon:
		if has_h and lane_rect_h.size.x > 0:
			var y_top := clampi(lane_rect_h.position.y - 1, 2, cells - 3)
			var y_bot := clampi(lane_rect_h.position.y + lane_rect_h.size.y, 2, cells - 3)
			var wall_x0: int = clampi(lane_rect_h.position.x + 1, 2, cells - 3)
			var wall_len_h: int = mini(lane_rect_h.size.x - 2, cells - wall_x0 - 2)
			gen._add_wall_segment_line(wall_cells, window_cells, Vector2i(wall_x0, y_top), Vector2i(1, 0), wall_len_h, rng)
			gen._add_wall_segment_line(wall_cells, window_cells, Vector2i(wall_x0, y_bot), Vector2i(1, 0), wall_len_h, rng)

		if has_v and lane_rect_v.size.y > 0:
			var x_left := clampi(lane_rect_v.position.x - 1, 2, cells - 3)
			var x_right := clampi(lane_rect_v.position.x + lane_rect_v.size.x, 2, cells - 3)
			var wall_y0: int = clampi(lane_rect_v.position.y + 1, 2, cells - 3)
			var wall_len_v: int = mini(lane_rect_v.size.y - 2, cells - wall_y0 - 2)
			gen._add_wall_segment_line(wall_cells, window_cells, Vector2i(x_left, wall_y0), Vector2i(0, 1), wall_len_v, rng)
			gen._add_wall_segment_line(wall_cells, window_cells, Vector2i(x_right, wall_y0), Vector2i(0, 1), wall_len_v, rng)

	# Apply door gaps (2-cell openings) after all wall merges.
	for g in door_gaps:
		for dc in g:
			wall_cells.erase(dc)
			window_cells.erase(dc)

	# Arena/gate: perimeter clutter, but keep center mostly open.
	if archetype == &"arena" or archetype == &"gate":
		var props := rng.randi_range(5, 9)
		for _j in range(props):
			var x := rng.randi_range(3, cells - 4)
			var y := rng.randi_range(3, cells - 4)
			var cell: Vector2i = Vector2i(x, y)
			var in_keepout: bool = false
			for r: Rect2i in keepout_rects:
				if r.has_point(cell):
					in_keepout = true
					break
			if in_keepout:
				continue
			var dx := absi(x - int(cells / 2.0))
			var dy := absi(y - int(cells / 2.0))
			if dx <= 4 and dy <= 4:
				continue
			gen._spawn_block(chunk, gen.cover_half_scene, x, y)

	# Checkpoint language: paired barricade clusters just outside the road core.
	# They shape combat without closing the route or creating a mandatory corridor.
	if role == &"checkpoint":
		var center_cell: int = int(cells / 2.0)
		if has_h and lane_rect_h.size.y > 0:
			var top_y: int = clampi(lane_rect_h.position.y - 2, 2, cells - 3)
			var bottom_y: int = clampi(lane_rect_h.position.y + lane_rect_h.size.y + 1, 2, cells - 3)
			for x_offset in [-6, 6]:
				gen._spawn_block(chunk, gen.cover_half_scene, clampi(center_cell + x_offset, 2, cells - 3), top_y)
				gen._spawn_block(chunk, gen.cover_half_scene, clampi(center_cell + x_offset, 2, cells - 3), bottom_y)
		if has_v and lane_rect_v.size.x > 0:
			var left_x: int = clampi(lane_rect_v.position.x - 2, 2, cells - 3)
			var right_x: int = clampi(lane_rect_v.position.x + lane_rect_v.size.x + 1, 2, cells - 3)
			for y_offset in [-6, 6]:
				gen._spawn_block(chunk, gen.cover_half_scene, left_x, clampi(center_cell + y_offset, 2, cells - 3))
				gen._spawn_block(chunk, gen.cover_half_scene, right_x, clampi(center_cell + y_offset, 2, cells - 3))

	# Lane contract: ensure street cores are never blocked.
	for r: Rect2i in keepout_rects:
		gen._erase_cells_in_rect(wall_cells, window_cells, r)

	# Prune tiny wall bits (prevents wall confetti)
	gen._prune_small_wall_components(wall_cells, 12)
	gen._trim_wall_spurs(wall_cells, 2)
	for k in window_cells.keys():
		if not wall_cells.has(k):
			window_cells.erase(k)

	gen._spawn_wall_cells(chunk, wall_cells, window_cells)

	# Every true exploration dead end carries a reward. This makes side travel intentional
	# and lets the macro validator treat these endpoints as meaningful rather than accidental.
	if (role == &"exploration_reward" or role == &"secondary_alley_cache") and LOOT_SPAWNER_SCENE != null:
		var reward_spawner := LOOT_SPAWNER_SCENE.instantiate() as Node2D
		if reward_spawner != null:
			var reward_rng := RandomNumberGenerator.new()
			reward_rng.seed = gen._mix_seed_int(base_seed, 77881)
			var reward_cell := Vector2i(
				clampi(int(cells / 2.0) + reward_rng.randi_range(-3, 3), 3, cells - 4),
				clampi(int(cells / 2.0) + reward_rng.randi_range(-3, 3), 3, cells - 4)
			)
			var reward_id: int = gen._mix_seed_int(base_seed, 0x51DE)
			reward_spawner.set("loot_id", int(reward_id & 0x7fffffff) + 1)
			if role == &"secondary_alley_cache":
				reward_spawner.set("secondary_objective_id", DistrictPlan.secondary_objective_id(gen.world_seed, coord, &"dangerous_alley_cache"))
			reward_spawner.set("spawn_chance", 1.0)
			reward_spawner.set("count_min", 1)
			reward_spawner.set("count_max", 2)
			reward_spawner.set("rarity_min", 5)
			reward_spawner.set("rarity_max", 8)
			reward_spawner.set("scatter_radius", 36.0)
			reward_spawner.set("require_walkable", true)
			reward_spawner.set("pos_attempts", 24)
			reward_spawner.set("pickup_delay", 0.15)
			reward_spawner.position = (Vector2(reward_cell) + Vector2(0.5, 0.5)) * float(gen.cell_size_px)
			chunk.add_child(reward_spawner)


static func _add_wall_segment_line(gen: ChunkGenImpl, wall_cells: Dictionary, window_cells: Dictionary, start: Vector2i, dir: Vector2i, length: int, rng: RandomNumberGenerator) -> void:
	# Street-edge fallback: avoid "fence post" reads by clustering into segments + small L-returns.
	if length <= 0:
		return

	var seg_min: int = 4
	var seg_max: int = 10
	var gap_min: int = 2
	var gap_max: int = 5

	# Guess outward direction from which half of the chunk we are in (keeps returns away from the street core).
	var outward := Vector2i.ZERO
	if dir.x != 0:
		outward = Vector2i(0, -1 if start.y < int(gen._cells_per_chunk() / 2.0) else 1)
	else:
		outward = Vector2i(-1 if start.x < int(gen._cells_per_chunk() / 2.0) else 1, 0)

	var idx: int = 0
	while idx < length:
		var seg_len: int = clampi(rng.randi_range(seg_min, seg_max), 1, length - idx)
		# Place the main segment
		for i in range(seg_len):
			var c: Vector2i = start + dir * (idx + i)
			wall_cells[c] = true

		# Small returns (1-2 cells) at a couple points to read like "ruin remnants", not 1-tile lines.
		if rng.randf() < 0.35 and outward != Vector2i.ZERO and seg_len >= 5:
			var nubs: int = rng.randi_range(1, 2)
			for _n in range(nubs):
				var at_i: int = rng.randi_range(1, seg_len - 2)
				var base := start + dir * (idx + at_i)
				var nub_len: int = rng.randi_range(1, 2)
				for j in range(1, nub_len + 1):
					wall_cells[base + outward * j] = true

		# Windows (rare, straight-ish only)
		if seg_len >= 7:
			var win_n := rng.randi_range(0, 1 if rng.randf() < 0.55 else 2)
			for _w in range(win_n):
				var wi: int = rng.randi_range(2, seg_len - 3)
				window_cells[start + dir * (idx + wi)] = true

		idx += seg_len + rng.randi_range(gap_min, gap_max)

	# Keep window cells consistent with walls
	for k in window_cells.keys():
		if not wall_cells.has(k):
			window_cells.erase(k)

static func _urban_access_corridors(access_mask: int, cells: int, lane_cx: int, lane_cy: int) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	if access_mask == 0:
		return rects
	var passage_w: int = 3
	var half_w: int = int(passage_w / 2.0)
	var edge_axis: int = int(cells / 2.0)

	if (access_mask & _DIR_N) != 0:
		rects.append(Rect2i(Vector2i(edge_axis - half_w, 0), Vector2i(passage_w, lane_cy + half_w + 1)))
		var x0_n: int = mini(edge_axis, lane_cx) - half_w
		rects.append(Rect2i(Vector2i(x0_n, lane_cy - half_w), Vector2i(absi(edge_axis - lane_cx) + passage_w, passage_w)))
	if (access_mask & _DIR_S) != 0:
		rects.append(Rect2i(Vector2i(edge_axis - half_w, lane_cy - half_w), Vector2i(passage_w, cells - lane_cy + half_w)))
		var x0_s: int = mini(edge_axis, lane_cx) - half_w
		rects.append(Rect2i(Vector2i(x0_s, lane_cy - half_w), Vector2i(absi(edge_axis - lane_cx) + passage_w, passage_w)))
	if (access_mask & _DIR_W) != 0:
		rects.append(Rect2i(Vector2i(0, edge_axis - half_w), Vector2i(lane_cx + half_w + 1, passage_w)))
		var y0_w: int = mini(edge_axis, lane_cy) - half_w
		rects.append(Rect2i(Vector2i(lane_cx - half_w, y0_w), Vector2i(passage_w, absi(edge_axis - lane_cy) + passage_w)))
	if (access_mask & _DIR_E) != 0:
		rects.append(Rect2i(Vector2i(lane_cx - half_w, edge_axis - half_w), Vector2i(cells - lane_cx + half_w, passage_w)))
		var y0_e: int = mini(edge_axis, lane_cy) - half_w
		rects.append(Rect2i(Vector2i(lane_cx - half_w, y0_e), Vector2i(passage_w, absi(edge_axis - lane_cy) + passage_w)))
	return rects


static func _add_connector_spawn_sockets(chunk: Node2D, conn_mask: int, lane_cx: int, lane_cy: int, cells: int, cell_size_px: int) -> void:
	var socket_cells: Array[Vector2i] = []
	if (conn_mask & _DIR_N) != 0:
		socket_cells.append(Vector2i(lane_cx, 3))
	if (conn_mask & _DIR_E) != 0:
		socket_cells.append(Vector2i(cells - 4, lane_cy))
	if (conn_mask & _DIR_S) != 0:
		socket_cells.append(Vector2i(lane_cx, cells - 4))
	if (conn_mask & _DIR_W) != 0:
		socket_cells.append(Vector2i(3, lane_cy))
	for index in range(socket_cells.size()):
		var marker := Marker2D.new()
		marker.name = "StreetSpawnSocket%02d" % index
		marker.position = (Vector2(socket_cells[index]) + Vector2(0.5, 0.5)) * float(cell_size_px)
		marker.add_to_group(&"enemy_spawn_socket")
		marker.set_meta("spawn_socket_kind", &"street")
		chunk.add_child(marker)


## Authored 10-16 -> 6-9 cells. The top of the band is chosen so the leftover
## side regions clear the carver's 10x10 minimum for every lane centre the
## deterministic row/column hash can produce.
static func _remapped_lane_width(authored_cells: int) -> int:
	var t: float = clampf((float(authored_cells) - 10.0) / 6.0, 0.0, 1.0)
	return clampi(int(round(lerpf(6.0, 9.0, t))), 6, 9)


static func _lane_center_for_row(gen: ChunkGenImpl, row: int, cells: int) -> int:
	# Deterministic per row so E/W neighbor chunks align visually.
	var rr := RandomNumberGenerator.new()
	rr.seed = gen._mix_seed_int(gen.world_seed, row * 1299721 + 1013)
	return rr.randi_range(int(floor(float(cells) * 0.35)), int(ceil(float(cells) * 0.65)))


static func _lane_center_for_col(gen: ChunkGenImpl, col: int, cells: int) -> int:
	# Deterministic per column so N/S neighbor chunks align visually.
	var rr := RandomNumberGenerator.new()
	rr.seed = gen._mix_seed_int(gen.world_seed, col * 928371 + 7703)
	return rr.randi_range(int(floor(float(cells) * 0.35)), int(ceil(float(cells) * 0.65)))
