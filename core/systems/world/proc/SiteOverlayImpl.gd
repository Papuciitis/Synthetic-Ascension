extends RefCounted
class_name SiteOverlayImpl

# Multi-chunk "Site" overlay generator.
# Step focus: coherence + readable indoors.
# - Deterministic per world_seed + chunk coords
# - Generates connected wall clusters (no random wall speckles)
# - Stamps indoor floors + door thresholds
# - Adds IndoorVolume rectangles for indoor detection/vignette later

const DONJON := preload("res://core/systems/world/proc/DonjonCarver.gd")
const RECT_FAC := preload("res://core/systems/world/proc/RectFacilityCarver.gd")
const INDOOR_VOLUME_SCENE: PackedScene = preload("res://scenes/world/volumes/IndoorVolume.tscn")
const LOOT_SPAWNER_SCENE: PackedScene = preload("res://scenes/world/pickups/ExplorationLootSpawner.tscn")

class SitePlan:
	var root_chunk: Vector2i
	var size_chunks: Vector2i
	var site_seed: int
	var role: StringName = &"shop"
	var theme: StringName = &"facility"
	var region: Rect2i # site-local cell rect
	var door_side: int = 0 # 0=N,1=E,2=S,3=W
	var door_pos: Vector2i = Vector2i.ZERO # site-local cell on region border
	var door_width: int = 2
	var carve: DONJON.CarveResult

var _cache: Dictionary = {} # Vector2i(root_chunk)->SitePlan
var _cache_order: Array[Vector2i] = []
var _cache_limit: int = 64


func reset() -> void:
	_cache.clear()
	_cache_order.clear()


func decorate_chunk(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	cfg: Dictionary
) -> bool:
	# Find an overlapping site (by scanning possible roots around this chunk).
	var cpc: int = int(chunk_manager._cells_per_chunk())
	var spacing: int = int(cfg.get("anchor_spacing", 2))
	var chance: float = float(cfg.get("anchor_chance", 0.20))
	var max_w: int = int(cfg.get("max_site_chunks_x", 2))
	var max_h: int = int(cfg.get("max_site_chunks_y", 2))

	var chosen: SitePlan = null

	for dy in range(max_h):
		for dx in range(max_w):
			var root := coord - Vector2i(dx, dy)
			if not _is_anchor(root, spacing):
				continue
			if not _anchor_passes(root, int(chunk_manager.world_seed), chance):
				continue
			var plan := _get_plan(root, chunk_manager, cfg)
			if plan == null:
				continue
			if _coord_in_site(coord, plan.root_chunk, plan.size_chunks):
				chosen = plan
				break
		if chosen != null:
			break

	if chosen == null:
		return false

	# Stamp into this chunk.
	var chunk_offset_cells := (coord - chosen.root_chunk) * cpc
	var chunk_site_rect := Rect2i(chunk_offset_cells, Vector2i(cpc, cpc))

	# Base indoor floor for the whole region (clipped to this chunk)
	var base_rect := chosen.region.intersection(chunk_site_rect)
	if base_rect.size.x > 0 and base_rect.size.y > 0:
		var local := Rect2i(base_rect.position - chunk_offset_cells, base_rect.size)
		var rng_stamp := RandomNumberGenerator.new()
		rng_stamp.seed = _mix_seed(chosen.site_seed, base_rect.position.x, base_rect.position.y, 9137)
		chunk_manager._stamp_floor_rect_cells(chunk, local, int(cfg.get("indoor_floor_tex", 3)), rng_stamp, float(cfg.get("indoor_floor_alpha", 0.95)), int(cfg.get("indoor_floor_z", -94)))

	# Donjon-carved floor details (corridors etc)
	for s in chosen.carve.floor_stamps:
		var r: Rect2i = s["rect"]
		var inter := r.intersection(chunk_site_rect)
		if inter.size.x <= 0 or inter.size.y <= 0:
			continue
		var local_r := Rect2i(inter.position - chunk_offset_cells, inter.size)
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = _mix_seed(chosen.site_seed, r.position.x, r.position.y, int(s["tex"]))
		chunk_manager._stamp_floor_rect_cells(chunk, local_r, int(s["tex"]), rng2, float(s["alpha"]), int(s["z"]))

	# Walls (clipped)
	var wall_cells_chunk: Dictionary = {}
	var window_cells_chunk: Dictionary = {}
	for k in chosen.carve.wall_cells.keys():
		var p: Vector2i = k as Vector2i
		if not chunk_site_rect.has_point(p):
			continue
		wall_cells_chunk[p - chunk_offset_cells] = true
	for k in chosen.carve.window_cells.keys():
		var p: Vector2i = k as Vector2i
		if not chunk_site_rect.has_point(p):
			continue
		window_cells_chunk[p - chunk_offset_cells] = true

	# Trim micro-spurs (prevents "wall confetti")
	_trim_wall_spurs(wall_cells_chunk, 2)
	# Remove windows that no longer exist after trim
	for k in window_cells_chunk.keys():
		if not wall_cells_chunk.has(k):
			window_cells_chunk.erase(k)

	chunk_manager._spawn_wall_cells(chunk, wall_cells_chunk, window_cells_chunk)

	# Some half-cover props from carve (clipped)
	var max_props: int = int(cfg.get("indoor_cover_budget", 4))
	var placed := 0
	for p in chosen.carve.half_cover_cells:
		if placed >= max_props:
			break
		if chunk_site_rect.has_point(p):
			var lp := p - chunk_offset_cells
			chunk_manager._spawn_block(chunk, chunk_manager.cover_half_scene, lp.x, lp.y)
			placed += 1

	# Door threshold: stamp a small apron outside the entrance (if it lands in this chunk)
	_stamp_door_threshold(chunk_manager, chunk, coord, chosen, cfg)

	# Indoor volume: per-chunk overlap of interior (region inset by 1 cell)
	_spawn_indoor_volumes(chunk_manager, chunk, coord, chosen, cfg)

	# Optional debug label
	if bool(cfg.get("debug_label", false)):
		var lbl := Label.new()
		lbl.text = "SITE:%s %s %s" % [str(chosen.role), str(chosen.size_chunks), str(chosen.root_chunk)]
		lbl.position = Vector2(10, 10)
		lbl.modulate = Color(1, 1, 1, 0.65)
		chunk.add_child(lbl)

	return true


func _get_plan(root: Vector2i, chunk_manager: Node, cfg: Dictionary) -> SitePlan:
	if _cache.has(root):
		return _cache[root] as SitePlan

	var plan := SitePlan.new()
	plan.root_chunk = root
	plan.site_seed = _mix_seed(int(chunk_manager.world_seed), root.x, root.y, 777)

	var rng := RandomNumberGenerator.new()
	rng.seed = plan.site_seed

	# Size in chunks (small shack -> 1x1, small facility -> 2x1/1x2, rare 2x2)
	var roll := rng.randf()
	if roll < 0.70:
		plan.size_chunks = Vector2i(1, 1)
	elif roll < 0.92:
		plan.size_chunks = Vector2i(2, 1) if rng.randf() < 0.5 else Vector2i(1, 2)
	else:
		plan.size_chunks = Vector2i(2, 2)

	var cpc: int = int(chunk_manager._cells_per_chunk())
	var pad: int = int(cfg.get("site_padding_cells", 2))
	var w_cells := plan.size_chunks.x * cpc
	var h_cells := plan.size_chunks.y * cpc

	# The actual indoor region (leave some grass margin around it)
	var region := Rect2i(Vector2i(pad, pad), Vector2i(w_cells - pad * 2, h_cells - pad * 2))
	# Ensure region isn't too small for carver
	if region.size.x < 10 or region.size.y < 10:
		region = Rect2i(Vector2i(1, 1), Vector2i(maxi(10, w_cells - 2), maxi(10, h_cells - 2)))

	plan.region = region

	# Door on a random side, biased to chunk-center-facing for readability (mild)
	plan.door_side = int(rng.randi_range(0, 3))
	plan.door_width = int(cfg.get("door_width_cells", 2))

	var rx0 := region.position.x
	var ry0 := region.position.y
	var rx1 := region.position.x + region.size.x - 1
	var ry1 := region.position.y + region.size.y - 1

	match plan.door_side:
		0: # N
			var x := rng.randi_range(rx0 + 2, rx1 - plan.door_width - 2)
			plan.door_pos = Vector2i(x, ry0)
		1: # E
			var y := rng.randi_range(ry0 + 2, ry1 - plan.door_width - 2)
			plan.door_pos = Vector2i(rx1, y)
		2: # S
			var x := rng.randi_range(rx0 + 2, rx1 - plan.door_width - 2)
			plan.door_pos = Vector2i(x, ry1)
		3: # W
			var y := rng.randi_range(ry0 + 2, ry1 - plan.door_width - 2)
			plan.door_pos = Vector2i(rx0, y)

	var dir := Vector2i.ZERO
	match plan.door_side:
		0: dir = Vector2i(0, 1)
		1: dir = Vector2i(-1, 0)
		2: dir = Vector2i(0, -1)
		3: dir = Vector2i(1, 0)

	var entrances: Array[Dictionary] = [
		{"pos": plan.door_pos, "dir": dir, "width": plan.door_width}
	]

	# Room-first facility/shop interior (guaranteed partitions; no cave-first CA)
	var room_attempts := int(cfg.get("facility_room_attempts", 34))
	var room_min := cfg.get("facility_room_min", Vector2i(5, 5)) as Vector2i
	var room_max := cfg.get("facility_room_max", Vector2i(10, 9)) as Vector2i
	var room_pad := int(cfg.get("facility_room_padding", 1))
	var corridor_w := int(cfg.get("facility_corridor_width", 2))
	var window_ch := float(cfg.get("facility_window_chance", 0.06))
	var floor_room_tex := int(cfg.get("facility_floor_room_tex", 3))
	var floor_corr_tex := int(cfg.get("facility_floor_corr_tex", 2))

	plan.carve = RECT_FAC.carve_room_first(
		region,
		rng,
		room_attempts,
		room_min,
		room_max,
		room_pad,
		corridor_w,
		window_ch,
		entrances,
		floor_room_tex,
		floor_corr_tex
	)


	# Cache
	_cache[root] = plan
	_cache_order.append(root)
	if _cache_order.size() > _cache_limit:
		var old: Vector2i = _cache_order.pop_front() as Vector2i
		_cache.erase(old)

	return plan


func _spawn_indoor_volumes(chunk_manager: Node, chunk: Node2D, coord: Vector2i, plan: SitePlan, cfg: Dictionary) -> void:
	if INDOOR_VOLUME_SCENE == null:
		return
	var cpc: int = int(chunk_manager._cells_per_chunk())
	var chunk_offset := (coord - plan.root_chunk) * cpc
	var chunk_rect := Rect2i(chunk_offset, Vector2i(cpc, cpc))

	# inset by 1 cell to avoid walls
	var interior := Rect2i(plan.region.position + Vector2i(1, 1), plan.region.size - Vector2i(2, 2))
	if interior.size.x <= 0 or interior.size.y <= 0:
		return

	var inter := interior.intersection(chunk_rect)
	if inter.size.x <= 0 or inter.size.y <= 0:
		return

	# Create per-chunk volume (so streaming never drops indoor detection while inside)
	var vol := INDOOR_VOLUME_SCENE.instantiate()
	chunk.add_child(vol)

	# global cell tl
	var global_tl := plan.root_chunk * cpc + inter.position
	var b_id := int(cfg.get("building_id_base", 0)) + int(plan.site_seed & 0x7fffffff)
	if b_id == 0:
		b_id = int(_mix_seed(plan.site_seed, plan.root_chunk.x, plan.root_chunk.y, 19) & 0x7fffffff) + 1

	vol.configure(global_tl, inter.size, int(chunk_manager.cell_size_px), b_id)

	# Exploration loot: large sites / dungeons
	# Spawn ONCE per site (root chunk only) to avoid duplication across streamed chunks.
	if bool(cfg.get('use_legacy_site_loot_spawner', false)) and LOOT_SPAWNER_SCENE != null and coord == plan.root_chunk:
		var lid: int = int(plan.site_seed & 0x7fffffff)
		if lid == 0:
			lid = int(_mix_seed(plan.site_seed, plan.root_chunk.x, plan.root_chunk.y, 202) & 0x7fffffff) + 1

		# Deterministic roll per site.
		var rng_loot := RandomNumberGenerator.new()
		rng_loot.seed = int(_mix_seed(int(chunk_manager.world_seed), lid, 0, 4242) & 0x7fffffff)
		var chance: float = float(cfg.get('site_loot_chance', 0.85))
		if rng_loot.randf() < clampf(chance, 0.0, 1.0):
			var sp := LOOT_SPAWNER_SCENE.instantiate() as Node2D
			if sp != null:
				chunk.add_child(sp)
				sp.set('loot_id', lid)
				sp.set('spawn_chance', 1.0)
				sp.set('count_min', int(cfg.get('site_loot_count_min', 2)))
				sp.set('count_max', int(cfg.get('site_loot_count_max', 4)))
				sp.set('rarity_min', int(cfg.get('site_loot_rarity_min', 5)))
				sp.set('rarity_max', int(cfg.get('site_loot_rarity_max', 8)))
				sp.set('rarity_bonus_per_segment', int(cfg.get('site_loot_rarity_bonus_per_segment', 1)))
				sp.set('scatter_radius', float(cfg.get('site_loot_scatter_radius', 48.0)))
				sp.set('pickup_delay', float(cfg.get('site_loot_pickup_delay', 0.15)))

				# place roughly at the site interior center (global space)
				var _loot_cpc: int = int(chunk_manager._cells_per_chunk())
				var _loot_center_cell: Vector2 = Vector2(plan.root_chunk * _loot_cpc + plan.region.position) + Vector2(plan.region.size) * 0.5
				sp.global_position = (_loot_center_cell + Vector2(0.5, 0.5)) * float(chunk_manager.cell_size_px)


func _stamp_door_threshold(chunk_manager: Node, chunk: Node2D, coord: Vector2i, plan: SitePlan, cfg: Dictionary) -> void:
	var cpc: int = int(chunk_manager._cells_per_chunk())
	var chunk_offset := (coord - plan.root_chunk) * cpc
	var chunk_rect := Rect2i(chunk_offset, Vector2i(cpc, cpc))

	# Door span rect on border
	var door0 := plan.door_pos
	var door_span := Rect2i()
	var dir := Vector2i.ZERO
	match plan.door_side:
		0:
			door_span = Rect2i(door0, Vector2i(plan.door_width, 1))
			dir = Vector2i(0, -1)
		1:
			door_span = Rect2i(door0, Vector2i(1, plan.door_width))
			dir = Vector2i(1, 0)
		2:
			door_span = Rect2i(door0 - Vector2i(plan.door_width - 1, 0), Vector2i(plan.door_width, 1))
			dir = Vector2i(0, 1)
		3:
			door_span = Rect2i(door0 - Vector2i(0, plan.door_width - 1), Vector2i(1, plan.door_width))
			dir = Vector2i(-1, 0)

	# Apron outside building
	var apron_len := int(cfg.get("door_apron_len", 2))
	var apron_w := plan.door_width + 2
	var apron_pos := door_span.position + dir
	if plan.door_side == 0 or plan.door_side == 2:
		apron_pos.x -= 1
		var apron := Rect2i(apron_pos, Vector2i(apron_w, apron_len))
		var inter := apron.intersection(chunk_rect)
		if inter.size.x > 0 and inter.size.y > 0:
			var local := Rect2i(inter.position - chunk_offset, inter.size)
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = _mix_seed(plan.site_seed, 123, door_span.position.x, door_span.position.y)
			chunk_manager._stamp_floor_rect_cells(chunk, local, int(cfg.get("door_floor_tex", 4)), rng2, float(cfg.get("door_floor_alpha", 0.92)), int(cfg.get("door_floor_z", -93)))
	else:
		apron_pos.y -= 1
		var apron := Rect2i(apron_pos, Vector2i(apron_len, apron_w))
		var inter := apron.intersection(chunk_rect)
		if inter.size.x > 0 and inter.size.y > 0:
			var local := Rect2i(inter.position - chunk_offset, inter.size)
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = _mix_seed(plan.site_seed, 456, door_span.position.x, door_span.position.y)
			chunk_manager._stamp_floor_rect_cells(chunk, local, int(cfg.get("door_floor_tex", 4)), rng2, float(cfg.get("door_floor_alpha", 0.92)), int(cfg.get("door_floor_z", -93)))


func _is_anchor(c: Vector2i, spacing: int) -> bool:
	if spacing <= 0:
		return true
	return _posmod(c.x, spacing) == 0 and _posmod(c.y, spacing) == 0


func _anchor_passes(root: Vector2i, world_seed: int, chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(world_seed, root.x, root.y, 991)
	return rng.randf() < chance


func _coord_in_site(c: Vector2i, root: Vector2i, size_chunks: Vector2i) -> bool:
	return c.x >= root.x and c.y >= root.y and c.x < root.x + size_chunks.x and c.y < root.y + size_chunks.y


func _posmod(a: int, m: int) -> int:
	var r := a % m
	return r + m if r < 0 else r


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
