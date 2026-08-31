extends RefCounted
class_name ChunkGenImpl
# Procedural chunk content generator extracted from ChunkManager.gd.
# ChunkManager remains the authoritative "streaming + nav" orchestrator.

const INDOOR_VOLUME_SCENE: PackedScene = preload("res://scenes/world/volumes/IndoorVolume.tscn")

const _ARCH: Script = preload("res://core/systems/world/proc/chunkgen/ChunkGenArchetypes.gd")
const _DIST: Script = preload("res://core/systems/world/proc/chunkgen/ChunkGenDistrict.gd")
const _STAMP: Script = preload("res://core/systems/world/proc/chunkgen/ChunkGenStamp.gd")
const _WALLS: Script = preload("res://core/systems/world/proc/chunkgen/ChunkGenWalls.gd")
const _STRUCT: Script = preload("res://core/systems/world/proc/chunkgen/ChunkGenStructures.gd")
const _DECO: Script = preload("res://core/systems/world/proc/chunkgen/ChunkGenDeco.gd")

var cm: ChunkManager = null
var _site_mgr: SiteManager = null

# Internal (kept here so debug printing stays local)
var _printed_once: bool = false
# _generate_chunk() runs for every streamed chunk, so the unassigned-cover
# report is claimed once per generator.
var _warned_missing_cover: bool = false
var _gen_coord: Vector2i = Vector2i.ZERO

# Mirrored settings from ChunkManager (sync_from_chunk_manager()).
var world_seed: int = 1337
var chunk_size_px: int = 2048
var load_radius: int = 2
var unload_radius: int = 3
var player_group: StringName = &"player"
var cell_size_px: int = 64
var padding_cells: int = 3
var ground_enabled: bool = true
var decals_enabled: bool = true
var decals_per_chunk_min: int = 0
var decals_per_chunk_max: int = 2
var deco_enabled: bool = true
var veg_per_chunk_min: int = 0
var veg_per_chunk_max: int = 3
var landmark_chance_per_special_chunk: int = 1
var generation_enabled: bool = true
var weight_empty: float = 0.70
var weight_building: float = 0.20
var weight_ruins: float = 0.10
var district_enabled: bool = true
var district_lane_width_cells: int = 12
var district_plaza_size_cells: int = 18
var district_window_chance: float = 0.12
var district_gap_chance: float = 0.10
var district_sidewalk_width_cells: int = 2
var district_sidewalk_corner_pad_cells: int = 3
var district_sidewalk_alpha: float = 0.88
var district_road_edge_noise_chance: float = 0.35
var district_plaza_islands_max: int = 4
var district_plaza_island_chance: float = 0.65
var donjon_enabled: bool = true
var donjon_strength: float = 0.55
var donjon_fill_wall_chance: float = 0.48
var donjon_ca_steps: int = 4
var donjon_room_attempts: int = 24
var donjon_room_min: Vector2i = Vector2i(4, 4)
var donjon_room_max: Vector2i = Vector2i(9, 8)
var donjon_room_padding: int = 1
var donjon_corridor_width: int = 2
var parcels_enabled: bool = true
var parcels_chunk_chance: float = 0.85
var parcels_chance_per_side: float = 0.55
var parcels_max_per_side: int = 1
var parcels_depth_cells: int = 10
var parcels_length_min_cells: int = 10
var parcels_length_max_cells: int = 18
var parcels_street_gap_cells: int = 1
var parcels_building_margin_cells: int = 1
var parcels_door_width: int = 2
var parcels_apron_len: int = 2
var parcels_window_chance: float = 0.22
var sites_enabled: bool = true
var sites_only_on_default_chunks: bool = true
var sites_anchor_spacing: int = 2
var sites_anchor_chance: float = 0.20
var sites_max_size_chunks_x: int = 2
var sites_max_size_chunks_y: int = 2
var sites_padding_cells: int = 2
var sites_debug_label: bool = false
var debug_draw_chunk_outlines: bool = true
var debug_chunk_line_width: float = 4.0
var debug_show_blocks: bool = true
var debug_block_color: Color = Color(0.2, 0.9, 0.4, 0.35)
var debug_force_content: bool = false
var debug_print_generation: bool = false
var cover_full_scene: PackedScene = null
var cover_window_scene: PackedScene = null
var cover_half_scene: PackedScene = null

func bind(chunk_manager: ChunkManager) -> void:
	cm = chunk_manager
	_site_mgr = chunk_manager._site_mgr
	sync_from_chunk_manager()

func sync_from_chunk_manager() -> void:
	if cm == null:
		return
	world_seed = cm.world_seed
	chunk_size_px = cm.chunk_size_px
	load_radius = cm.load_radius
	unload_radius = cm.unload_radius
	player_group = cm.player_group
	cell_size_px = cm.cell_size_px
	padding_cells = cm.padding_cells
	ground_enabled = cm.ground_enabled
	decals_enabled = cm.decals_enabled
	decals_per_chunk_min = cm.decals_per_chunk_min
	decals_per_chunk_max = cm.decals_per_chunk_max
	deco_enabled = cm.deco_enabled
	veg_per_chunk_min = cm.veg_per_chunk_min
	veg_per_chunk_max = cm.veg_per_chunk_max
	landmark_chance_per_special_chunk = cm.landmark_chance_per_special_chunk
	generation_enabled = cm.generation_enabled
	weight_empty = cm.weight_empty
	weight_building = cm.weight_building
	weight_ruins = cm.weight_ruins
	district_enabled = cm.district_enabled
	district_lane_width_cells = cm.district_lane_width_cells
	district_plaza_size_cells = cm.district_plaza_size_cells
	district_window_chance = cm.district_window_chance
	district_gap_chance = cm.district_gap_chance
	district_sidewalk_width_cells = cm.district_sidewalk_width_cells
	district_sidewalk_corner_pad_cells = cm.district_sidewalk_corner_pad_cells
	district_sidewalk_alpha = cm.district_sidewalk_alpha
	district_road_edge_noise_chance = cm.district_road_edge_noise_chance
	district_plaza_islands_max = cm.district_plaza_islands_max
	district_plaza_island_chance = cm.district_plaza_island_chance
	donjon_enabled = cm.donjon_enabled
	donjon_strength = cm.donjon_strength
	donjon_fill_wall_chance = cm.donjon_fill_wall_chance
	donjon_ca_steps = cm.donjon_ca_steps
	donjon_room_attempts = cm.donjon_room_attempts
	donjon_room_min = cm.donjon_room_min
	donjon_room_max = cm.donjon_room_max
	donjon_room_padding = cm.donjon_room_padding
	donjon_corridor_width = cm.donjon_corridor_width
	parcels_enabled = cm.parcels_enabled
	parcels_chunk_chance = cm.parcels_chunk_chance
	parcels_chance_per_side = cm.parcels_chance_per_side
	parcels_max_per_side = cm.parcels_max_per_side
	parcels_depth_cells = cm.parcels_depth_cells
	parcels_length_min_cells = cm.parcels_length_min_cells
	parcels_length_max_cells = cm.parcels_length_max_cells
	parcels_street_gap_cells = cm.parcels_street_gap_cells
	parcels_building_margin_cells = cm.parcels_building_margin_cells
	parcels_door_width = cm.parcels_door_width
	parcels_apron_len = cm.parcels_apron_len
	parcels_window_chance = cm.parcels_window_chance
	sites_enabled = cm.sites_enabled
	sites_only_on_default_chunks = cm.sites_only_on_default_chunks
	sites_anchor_spacing = cm.sites_anchor_spacing
	sites_anchor_chance = cm.sites_anchor_chance
	sites_max_size_chunks_x = cm.sites_max_size_chunks_x
	sites_max_size_chunks_y = cm.sites_max_size_chunks_y
	sites_padding_cells = cm.sites_padding_cells
	sites_debug_label = cm.sites_debug_label
	debug_draw_chunk_outlines = cm.debug_draw_chunk_outlines
	debug_chunk_line_width = cm.debug_chunk_line_width
	debug_show_blocks = cm.debug_show_blocks
	debug_block_color = cm.debug_block_color
	debug_force_content = cm.debug_force_content
	debug_print_generation = cm.debug_print_generation
	cover_full_scene = cm.cover_full_scene
	cover_window_scene = cm.cover_window_scene
	cover_half_scene = cm.cover_half_scene

func _set_gen_coord(c: Vector2i) -> void:
	_gen_coord = c
	if cm != null:
		cm._gen_coord = c

func _bump_nav_revision() -> void:
	if cm != null:
		cm.request_nav_revision(&"chunk_generated")

# Forwarders so the extracted code can stay nearly identical.
func get_chunk_archetype(coord: Vector2i) -> StringName:
	if cm == null:
		return &"default"
	return cm.get_chunk_archetype(coord)

func get_chunk_connectors(coord: Vector2i) -> int:
	if cm == null:
		return 0
	return cm.get_chunk_connectors(coord)

func get_chunk_urban_access(coord: Vector2i) -> int:
	if cm == null:
		return 0
	return cm.get_chunk_urban_access(coord)

func get_chunk_role(coord: Vector2i) -> StringName:
	if cm == null:
		return &"unplanned"
	return cm.get_chunk_role(coord)

func _seed_for_chunk(c: Vector2i) -> int:
	if cm == null:
		return 0
	return cm._seed_for_chunk(c)

func _add_environment_deco(chunk: Node2D, rng: RandomNumberGenerator, archetype: StringName, conn_mask: int) -> void:
	_DECO._add_environment_deco(self, chunk, rng, archetype, conn_mask)

func _spawn_block(chunk: Node2D, scene: PackedScene, cell_x: int, cell_y: int, connections_mask: int = 0) -> Node2D:
	if cm == null:
		return null
	return cm._spawn_block(chunk, scene, cell_x, cell_y, connections_mask)


func _generate_chunk(coord: Vector2i, chunk: Node2D) -> void:
	if cover_full_scene == null or cover_window_scene == null or cover_half_scene == null:
		if not _warned_missing_cover:
			_warned_missing_cover = true
			var missing := PackedStringArray()
			if cover_full_scene == null:
				missing.append("full")
			if cover_window_scene == null:
				missing.append("window")
			if cover_half_scene == null:
				missing.append("half")
			push_error(
				"[ChunkGenImpl] cannot generate chunks: cover scenes unassigned=[%s] chunk_manager=%s; every streamed chunk stays empty"
				% [",".join(missing), (String(cm.name) if cm != null else "<null>")]
			)
		return

	# Remember which chunk we're generating so _spawn_block can register cells
	_set_gen_coord(coord)

	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for_chunk(coord)

	if debug_print_generation and not _printed_once:
		_printed_once = true
		print("[ChunkManager] Generating chunks. debug_force_content=", debug_force_content)

	var archetype: StringName = get_chunk_archetype(coord)
	var conn_mask: int = get_chunk_connectors(coord)

	# Sites overlay (multi-chunk POIs). Runs before base chunk content.
	if sites_enabled and _site_mgr != null:
		if (not sites_only_on_default_chunks) or (archetype == &"default" and conn_mask == 0):
			var cfg := {
				"anchor_spacing": sites_anchor_spacing,
				"anchor_chance": sites_anchor_chance,
				"max_site_chunks_x": sites_max_size_chunks_x,
				"max_site_chunks_y": sites_max_size_chunks_y,
				"site_padding_cells": sites_padding_cells,
				"debug_label": sites_debug_label,
				# --- exploration loot (large sites) ---
				"site_loot_chance": 1.0,
				"site_loot_count_min": 1,
				"site_loot_count_max": 3,
				"site_loot_rarity_min": 5,
				"site_loot_rarity_max": 8,
				"site_loot_rarity_bonus_per_segment": 1,
				"site_loot_scatter_radius": 48.0,
				"site_loot_pickup_delay": 0.15,
			}
			if _site_mgr.decorate_chunk(cm, chunk, coord, cfg):
				# Skip base content generation; site already placed.
				_bump_nav_revision()
				return


	# Donjon-ish district chunks (connector-driven). Segment builders set archetype+connectors.
	if district_enabled and (conn_mask != 0 or archetype == &"district" or archetype == &"plaza" or archetype == &"gate" or archetype == &"arena"):
		_generate_district(chunk, rng, coord, archetype, conn_mask)
	else:
		match archetype:
			&"arena":
				_generate_arena(chunk, rng)
			&"courtyard":
				_generate_courtyard(chunk, rng)
			&"street":
				_generate_street(chunk, rng)
			_:
				# Default weighted mix
				_generate_default(chunk, rng)

	# Post-pass: non-blocking environment deco (veg/landmarks)
	if deco_enabled:
		_add_environment_deco(chunk, rng, archetype, conn_mask)

	# ✅ tell nav "the blocked grid changed"
	_bump_nav_revision()


func _generate_default(chunk: Node2D, rng: RandomNumberGenerator) -> void:
	_ARCH._generate_default(self, chunk, rng)

func _generate_arena(chunk: Node2D, rng: RandomNumberGenerator) -> void:
	_ARCH._generate_arena(self, chunk, rng)

func _generate_courtyard(chunk: Node2D, rng: RandomNumberGenerator) -> void:
	_ARCH._generate_courtyard(self, chunk, rng)

func _generate_street(chunk: Node2D, rng: RandomNumberGenerator) -> void:
	_ARCH._generate_street(self, chunk, rng)

func _generate_district(chunk: Node2D, rng: RandomNumberGenerator, coord: Vector2i, archetype: StringName, conn_mask: int) -> void:
	_DIST._generate_district(self, chunk, rng, coord, archetype, conn_mask)

func _add_wall_segment_line(wall_cells: Dictionary, window_cells: Dictionary, start: Vector2i, dir: Vector2i, length: int, rng: RandomNumberGenerator) -> void:
	_DIST._add_wall_segment_line(self, wall_cells, window_cells, start, dir, length, rng)

func _lane_center_for_row(row: int, cells: int) -> int:
	return _DIST._lane_center_for_row(self, row, cells)

func _lane_center_for_col(col: int, cells: int) -> int:
	return _DIST._lane_center_for_col(self, col, cells)

func _mix_seed_int(a: int, b: int) -> int:
	var h: int = int((a ^ (b * 0x9E3779B9)) & 0x7FFFFFFF)
	h = int((h * 1103515245 + 12345) & 0x7FFFFFFF)
	return h

func _stamp_floor_rect_cells(chunk: Node2D, rect: Rect2i, tex_index: int, rng: RandomNumberGenerator, alpha: float, z: int) -> void:
	_STAMP._stamp_floor_rect_cells(self, chunk, rect, tex_index, rng, alpha, z)

func _stamp_floor_rect_cells_patchy(chunk: Node2D, rect: Rect2i, tex_index: int, rng: RandomNumberGenerator, alpha: float, z: int) -> void:
	_STAMP._stamp_floor_rect_cells_patchy(self, chunk, rect, tex_index, rng, alpha, z)

func _stamp_district_sidewalks(chunk: Node2D, bounds: Rect2i, lane_rect_h: Rect2i, lane_rect_v: Rect2i, rng: RandomNumberGenerator) -> void:
	_STAMP._stamp_district_sidewalks(self, chunk, bounds, lane_rect_h, lane_rect_v, rng)

func _stamp_district_road_edge_noise(chunk: Node2D, bounds: Rect2i, lane_rect_h: Rect2i, lane_rect_v: Rect2i, rng: RandomNumberGenerator) -> void:
	_STAMP._stamp_district_road_edge_noise(self, chunk, bounds, lane_rect_h, lane_rect_v, rng)

func _decorate_plaza_floor(chunk: Node2D, bounds: Rect2i, plaza_rect: Rect2i, rng: RandomNumberGenerator, archetype: StringName) -> void:
	_STAMP._decorate_plaza_floor(self, chunk, bounds, plaza_rect, rng, archetype)

func _cells_per_chunk() -> int:
	return int(floor(float(chunk_size_px) / float(cell_size_px)))




func _erase_cells_in_rect(wall_cells: Dictionary, window_cells: Dictionary, rect: Rect2i) -> void:
	_STAMP._erase_cells_in_rect(self, wall_cells, window_cells, rect)

func _add_plaza_ring(wall_cells: Dictionary, plaza_rect: Rect2i, cells_per_chunk: int, rng: RandomNumberGenerator, archetype: StringName) -> void:
	_STAMP._add_plaza_ring(self, wall_cells, plaza_rect, cells_per_chunk, rng, archetype)

func _prune_small_wall_components(wall_cells: Dictionary, min_size: int) -> void:
	_WALLS._prune_small_wall_components(self, wall_cells, min_size)

func _trim_wall_spurs(wall_cells: Dictionary, iterations: int) -> void:
	_WALLS._trim_wall_spurs(self, wall_cells, iterations)

func _wall_connections_mask(cell: Vector2i, wall_cells: Dictionary) -> int:
	return _WALLS._wall_connections_mask(self, cell, wall_cells)

func _spawn_wall_cells(chunk: Node2D, wall_cells: Dictionary, window_cells: Dictionary) -> void:
	_WALLS._spawn_wall_cells(self, chunk, wall_cells, window_cells)


func _spawn_indoor_volume_local_rect(chunk: Node2D, tl_local: Vector2i, size_local: Vector2i, building_id: int) -> void:
	if INDOOR_VOLUME_SCENE == null:
		return
	if size_local.x <= 0 or size_local.y <= 0:
		return
	var vol := INDOOR_VOLUME_SCENE.instantiate()
	chunk.add_child(vol)
	var cpc: int = _cells_per_chunk()
	var global_tl := _gen_coord * cpc + tl_local
	vol.configure(global_tl, size_local, cell_size_px, building_id)

func _spawn_building(chunk: Node2D, rng: RandomNumberGenerator) -> void:
	_STRUCT._spawn_building(self, chunk, rng)

func _spawn_ruins(chunk: Node2D, rng: RandomNumberGenerator) -> void:
	_STRUCT._spawn_ruins(self, chunk, rng)

func _spawn_wall_rect_cells(
	chunk: Node2D,
	x0: int, y0: int, w: int, h: int,
	door_side: int, door_offset: int, door_span: int,
	rng: RandomNumberGenerator
) -> void:
	_WALLS._spawn_wall_rect_cells(self, chunk, x0, y0, w, h, door_side, door_offset, door_span, rng)


func _spawn_wall_line(
	chunk: Node2D,
	x0: int, y0: int, w: int, h: int,
	has_door: bool, door_offset: int, door_span: int,
	rng: RandomNumberGenerator
) -> void:
	_WALLS._spawn_wall_line(self, chunk, x0, y0, w, h, has_door, door_offset, door_span, rng)
