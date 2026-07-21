extends Object
const LOOT_SPAWNER_SCENE: PackedScene = preload("res://scenes/world/pickups/ExplorationLootSpawner.tscn")

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


	var lane_w := clampi(gen.district_lane_width_cells, 6, cells - 6)
	var plaza_size := clampi(gen.district_plaza_size_cells, 10, cells - 4)

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
	# Roads: dirt path. Plazas/arenas/gates: cobble/tiles.
	if has_h:
		var y0 := clampi(lane_cy - int(lane_w / 2.0), 1, cells - lane_w - 1)
		lane_rect_h = Rect2i(Vector2i(0, y0), Vector2i(cells, lane_w))
		keepout_rects.append(lane_rect_h)
		gen._stamp_floor_rect_cells_patchy(chunk, lane_rect_h, 4, rng_roads, 0.85, -95)

	if has_v:
		var x0 := clampi(lane_cx - int(lane_w / 2.0), 1, cells - lane_w - 1)
		lane_rect_v = Rect2i(Vector2i(x0, 0), Vector2i(lane_w, cells))
		keepout_rects.append(lane_rect_v)
		gen._stamp_floor_rect_cells_patchy(chunk, lane_rect_v, 4, rng_roads, 0.85, -95)

	if archetype == &"plaza" or archetype == &"arena" or archetype == &"gate":
		var pcx := (lane_cx if has_v else int(cells / 2.0))
		var pcy := (lane_cy if has_h else int(cells / 2.0))

		var px0 := clampi(pcx - int(plaza_size / 2.0), 2, cells - plaza_size - 2)
		var py0 := clampi(pcy - int(plaza_size / 2.0), 2, cells - plaza_size - 2)

		has_plaza = true
		plaza_rect = Rect2i(Vector2i(px0, py0), Vector2i(plaza_size, plaza_size))

		var tex_idx := (3 if archetype == &"gate" else 2)
		gen._stamp_floor_rect_cells_patchy(chunk, Rect2i(Vector2i(px0, py0), Vector2i(plaza_size, plaza_size)), tex_idx, rng_roads, 0.95, -94)

	
	# --- sidewalks + curb pads (visual readability) ---
	gen._stamp_district_sidewalks(chunk, bounds, lane_rect_h, lane_rect_v, rng_sidewalk)
	gen._stamp_district_road_edge_noise(chunk, bounds, lane_rect_h, lane_rect_v, rng_edge)

	# --- streetfront parcels (shops/facilities hugging the lane) ---
	var parcels_placed: bool = false
	if gen.parcels_enabled and gen._site_mgr != null and rng.randf() < gen.parcels_chunk_chance and not has_plaza:
		# Only on straight street segments (clean readability).
		if has_h != has_v and (archetype == &"street" or archetype == &"district"):
			var pcfg := {
				"parcel_chance_per_side": gen.parcels_chance_per_side,
				"parcel_max_per_side": gen.parcels_max_per_side,
				"parcel_depth_cells": gen.parcels_depth_cells,
				"parcel_length_min_cells": gen.parcels_length_min_cells,
				"parcel_length_max_cells": gen.parcels_length_max_cells,
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
				"facility_room_attempts": 28,
				"facility_room_min": Vector2i(5, 5),
				"facility_room_max": Vector2i(10, 9),
				"facility_room_padding": 1,
				"facility_corridor_w": 1,
				"facility_floor_room_tex": 3,
				"facility_floor_corr_tex": 2,
				# --- exploration loot (small buildings) ---
				"parcel_loot_chance": 0.55,
				"parcel_loot_count_min": 1,
				"parcel_loot_count_max": 1,
				"parcel_loot_rarity_min": 4,
				"parcel_loot_rarity_max": 6,
				"parcel_loot_rarity_bonus_per_segment": 0,
				"parcel_loot_scatter_radius": 24.0,
				"parcel_loot_pickup_delay": 0.15,
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
	if gen.donjon_enabled and not parcels_placed and rng.randf() < gen.donjon_strength:
		# Derive lane extents (even if only one axis exists).
		var lane_x0: int = (clampi(lane_cx - int(lane_w / 2.0), 1, cells - lane_w - 1) if has_v else 2)
		var lane_y0: int = (clampi(lane_cy - int(lane_w / 2.0), 1, cells - lane_w - 1) if has_h else 2)
		var lane_x1: int = (lane_x0 + lane_w - 1 if has_v else cells - 3)
		var lane_y1: int = (lane_y0 + lane_w - 1 if has_h else cells - 3)

		var regions: Array[Rect2i] = []
		if has_h and has_v:
			regions = [
				Rect2i(Vector2i(2, 2), Vector2i(lane_x0 - 2, lane_y0 - 2)),
				Rect2i(Vector2i(lane_x1 + 2, 2), Vector2i(cells - (lane_x1 + 2) - 2, lane_y0 - 2)),
				Rect2i(Vector2i(2, lane_y1 + 2), Vector2i(lane_x0 - 2, cells - (lane_y1 + 2) - 2)),
				Rect2i(Vector2i(lane_x1 + 2, lane_y1 + 2), Vector2i(cells - (lane_x1 + 2) - 2, cells - (lane_y1 + 2) - 2)),
			]
		elif has_h:
			regions = [
				Rect2i(Vector2i(2, 2), Vector2i(cells - 4, lane_y0 - 2)),
				Rect2i(Vector2i(2, lane_y1 + 2), Vector2i(cells - 4, cells - (lane_y1 + 2) - 2)),
			]
		elif has_v:
			regions = [
				Rect2i(Vector2i(2, 2), Vector2i(lane_x0 - 2, cells - 4)),
				Rect2i(Vector2i(lane_x1 + 2, 2), Vector2i(cells - (lane_x1 + 2) - 2, cells - 4)),
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
			if has_h and (r.position.y + r.size.y) == lane_y0:
				var y_edge: int = r.position.y + r.size.y - 1
				var cx: int = clampi(lane_cx, r.position.x + 2, r.position.x + r.size.x - 4)
				gap_cells = [Vector2i(cx, y_edge), Vector2i(cx + 1, y_edge)]
				entrances.append({ "pos": Vector2i(cx, y_edge - 1), "dir": Vector2i(0, -1), "width": 2 })
			# North-facing (region below a horizontal lane)
			elif has_h and r.position.y == (lane_y1 + 1):
				var y_edge2: int = r.position.y
				var cx2: int = clampi(lane_cx, r.position.x + 2, r.position.x + r.size.x - 4)
				gap_cells = [Vector2i(cx2, y_edge2), Vector2i(cx2 + 1, y_edge2)]
				entrances.append({ "pos": Vector2i(cx2, y_edge2 + 1), "dir": Vector2i(0, 1), "width": 2 })
			# East-facing (region left of a vertical lane)
			elif has_v and (r.position.x + r.size.x) == lane_x0:
				var x_edge: int = r.position.x + r.size.x - 1
				var cy3: int = clampi(lane_cy, r.position.y + 2, r.position.y + r.size.y - 4)
				gap_cells = [Vector2i(x_edge, cy3), Vector2i(x_edge, cy3 + 1)]
				entrances.append({ "pos": Vector2i(x_edge - 1, cy3), "dir": Vector2i(-1, 0), "width": 2 })
			# West-facing (region right of a vertical lane)
			elif has_v and r.position.x == (lane_x1 + 1):
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

			if gap_cells.size() > 0:
				door_gaps.append(gap_cells)

			used_donjon = true



	# ------------------------------------------------------------
	# Exploration loot: big dungeon interiors (Donjon-carved regions)
	# Guarantee at least 1 item if this chunk used Donjon carving.
	# ------------------------------------------------------------
	if (not parcels_placed) and best_dungeon_score > 0 and LOOT_SPAWNER_SCENE != null:
		var sp := LOOT_SPAWNER_SCENE.instantiate() as Node2D
		if sp != null:
			chunk.add_child(sp)
			sp.global_position = chunk.global_position + (Vector2(best_dungeon_cell) + Vector2(0.5, 0.5)) * float(gen.cell_size_px)

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
	# If parcels were placed, we already created coherent streetfront structures.
	if parcels_placed:
		used_donjon = true
	# If donjon didn't run (small regions / chance), fall back to straight street-edge lines.
	if not used_donjon:
		if has_h:
			var y_top := clampi(lane_cy - int(lane_w / 2.0) - 1, 2, cells - 3)
			var y_bot := clampi(lane_cy + int(lane_w / 2.0), 2, cells - 3)
			gen._add_wall_segment_line(wall_cells, window_cells, Vector2i(2, y_top), Vector2i(1, 0), cells - 4, rng)
			gen._add_wall_segment_line(wall_cells, window_cells, Vector2i(2, y_bot), Vector2i(1, 0), cells - 4, rng)

		if has_v:
			var x_left := clampi(lane_cx - int(lane_w / 2.0) - 1, 2, cells - 3)
			var x_right := clampi(lane_cx + int(lane_w / 2.0), 2, cells - 3)
			gen._add_wall_segment_line(wall_cells, window_cells, Vector2i(x_left, 2), Vector2i(0, 1), cells - 4, rng)
			gen._add_wall_segment_line(wall_cells, window_cells, Vector2i(x_right, 2), Vector2i(0, 1), cells - 4, rng)

	# Apply door gaps (2-cell openings) after all wall merges.
	for g in door_gaps:
		for dc in g:
			wall_cells.erase(dc)
			window_cells.erase(dc)

	# A couple of building rectangles in corners (readable "rooms" on the sides).

	var corner_buildings := (1 if archetype == &"district" else 2)
	for _i in range(corner_buildings):
		var bw := rng.randi_range(7, 12)
		var bh := rng.randi_range(6, 10)

		var q := rng.randi_range(0, 3) # quadrant
		var bx0 := (2 if q == 0 or q == 2 else cells - bw - 2)
		var by0 := (2 if q == 0 or q == 1 else cells - bh - 2)

		var brect := Rect2i(Vector2i(bx0, by0), Vector2i(bw, bh))

		# Avoid cutting across lane cores (we still allow overlap on the very edge for organic feel).
		var ok := true
		if has_h:
			var ry0 := clampi(lane_cy - int(lane_w / 2.0), 0, cells - lane_w)
			var rrect := Rect2i(Vector2i(0, ry0), Vector2i(cells, lane_w))
			if brect.intersects(rrect):
				ok = false
		if ok and has_v:
			var rx0 := clampi(lane_cx - int(lane_w / 2.0), 0, cells - lane_w)
			var rrect2 := Rect2i(Vector2i(rx0, 0), Vector2i(lane_w, cells))
			if brect.intersects(rrect2):
				ok = false
		if not ok:
			continue

		# Door side biased toward "inside" (toward chunk center) for readability.
		var door_side := 0
		if bx0 < int(cells / 2.0) and by0 < int(cells / 2.0): door_side = 2 # bottom
		elif bx0 >= int(cells / 2.0) and by0 < int(cells / 2.0): door_side = 3 # left
		elif bx0 < int(cells / 2.0) and by0 >= int(cells / 2.0): door_side = 1 # right
		else: door_side = 0 # top

		var door_offset := 2
		var door_span := 2
		gen._spawn_wall_rect_cells(chunk, bx0, by0, bw, bh, door_side, door_offset, door_span, rng)

		# Light interior props.
		if rng.randf() < 0.35:
			var px := rng.randi_range(bx0 + 2, bx0 + bw - 3)
			var py := rng.randi_range(by0 + 2, by0 + bh - 3)
			gen._spawn_block(chunk, gen.cover_half_scene, px, py)

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
			var c := start + dir * (idx + i)
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
