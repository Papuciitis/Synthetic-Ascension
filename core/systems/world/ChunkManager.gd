extends Node2D
class_name ChunkManager

@export var world_seed: int = 1337

@export_group("Chunk Streaming")
@export var chunk_size_px: int = 2048
@export var load_radius: int = 2
@export var unload_radius: int = 3
@export var player_group: StringName = &"player"
@export_range(1, 4, 1) var max_chunk_generations_per_frame: int = 1

@export_group("Generation Grid")
@export var cell_size_px: int = 64
@export var padding_cells: int = 3

@export_group("Ground Art")
@export var ground_enabled: bool = true
@export var decals_enabled: bool = true
@export_range(0, 6, 1) var decals_per_chunk_min: int = 0
@export_range(0, 6, 1) var decals_per_chunk_max: int = 2

@export_group("Environment Deco")
@export var deco_enabled: bool = true
@export_range(0, 8, 1) var veg_per_chunk_min: int = 0
@export_range(0, 8, 1) var veg_per_chunk_max: int = 3
@export_range(0, 3, 1) var landmark_chance_per_special_chunk: int = 1 # 1 => ~33%


const _WORLD_ART = preload("res://core/systems/world/WorldArt.gd")
const _SITE_MGR: Script = preload("res://core/systems/world/proc/SiteManager.gd")
const _GEN_IMPL: Script = preload("res://core/systems/world/proc/ChunkGenImpl.gd")
const _TILE_RENDERER: Script = preload("res://core/systems/world/ChunkTileRenderer.gd")

@export var generation_enabled: bool = true
@export_group("Rendering")
@export var tiled_world_rendering: bool = true

@export_group("Generation Weights")
@export_range(0.0, 1.0, 0.01) var weight_empty: float = 0.70
@export_range(0.0, 1.0, 0.01) var weight_building: float = 0.20
@export_range(0.0, 1.0, 0.01) var weight_ruins: float = 0.10

@export_group("District Generation")
@export var district_enabled: bool = true
@export_range(6, 18, 1) var district_lane_width_cells: int = 12
@export_range(6, 16, 1) var district_plaza_size_cells: int = 18
@export_range(0.0, 1.0, 0.01) var district_window_chance: float = 0.12
@export_range(0.0, 1.0, 0.01) var district_gap_chance: float = 0.10

@export_range(0, 3, 1) var district_sidewalk_width_cells: int = 2
@export_range(0, 6, 1) var district_sidewalk_corner_pad_cells: int = 3
@export_range(0.0, 1.0, 0.01) var district_sidewalk_alpha: float = 0.88
@export_range(0.0, 1.0, 0.01) var district_road_edge_noise_chance: float = 0.16
@export_range(0, 8, 1) var district_plaza_islands_max: int = 2
@export_range(0.0, 1.0, 0.01) var district_plaza_island_chance: float = 0.35

@export_group("Donjon Inside District")
@export var donjon_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var donjon_strength: float = 0.55
@export_range(0.30, 0.70, 0.01) var donjon_fill_wall_chance: float = 0.48
@export_range(1, 8, 1) var donjon_ca_steps: int = 4
@export_range(6, 60, 1) var donjon_room_attempts: int = 24
@export var donjon_room_min: Vector2i = Vector2i(4, 4)
@export var donjon_room_max: Vector2i = Vector2i(9, 8)
@export_range(0, 4, 1) var donjon_room_padding: int = 1
@export_range(1, 3, 1) var donjon_corridor_width: int = 2


@export_group("Streetfront Parcels")
@export var parcels_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var parcels_chunk_chance: float = 0.85
@export_range(0.0, 1.0, 0.01) var parcels_chance_per_side: float = 0.55
@export_range(0, 2, 1) var parcels_max_per_side: int = 1
@export_range(6, 16, 1) var parcels_depth_cells: int = 10
@export_range(8, 24, 1) var parcels_length_min_cells: int = 10
@export_range(10, 30, 1) var parcels_length_max_cells: int = 18
@export_range(0, 4, 1) var parcels_street_gap_cells: int = 1
@export_range(0, 4, 1) var parcels_building_margin_cells: int = 1
@export_range(1, 4, 1) var parcels_door_width: int = 2
@export_range(1, 4, 1) var parcels_apron_len: int = 2
@export_range(0.0, 1.0, 0.01) var parcels_window_chance: float = 0.22


@export_group("Sites (POI Overlay)")
@export var sites_enabled: bool = true
@export var sites_only_on_default_chunks: bool = true # safety
@export_range(1, 6, 1) var sites_anchor_spacing: int = 2
@export_range(0.0, 1.0, 0.01) var sites_anchor_chance: float = 0.20
@export_range(1, 3, 1) var sites_max_size_chunks_x: int = 2
@export_range(1, 3, 1) var sites_max_size_chunks_y: int = 2
@export_range(0, 6, 1) var sites_padding_cells: int = 2
@export var sites_debug_label: bool = false


# Per-chunk connector mask set by segment builders (Donjon-style coherency).
# N=1 E=2 S=4 W=8
var _chunk_connectors: Dictionary = {} # Vector2i -> int
# Separate pedestrian/courtyard access. These do not become road connectors.
var _chunk_urban_access: Dictionary = {} # Vector2i -> int, N=1 E=2 S=4 W=8

# Optional per-chunk archetype overrides set by segment builders.
# Examples: "courtyard", "street", "arena".
var _chunk_archetype: Dictionary = {} # Vector2i -> StringName

# Semantic plan data. Roles drive module behaviour; terrain selects the low-level base surface.
var _chunk_role: Dictionary = {} # Vector2i -> StringName
var _chunk_terrain: Dictionary = {} # Vector2i -> StringName
var _fallback_terrain: StringName = &"grass"

var _site_mgr: SiteManager = null
var _content_gen: ChunkGenImpl = null
var _tile_renderer: ChunkTileRenderer = null
var _external_tile_roots: Array[Node2D] = []


@export_group("Scenes (assign in Inspector)")
@export var cover_full_scene: PackedScene
@export var cover_window_scene: PackedScene
@export var cover_half_scene: PackedScene

@export_group("Debug")
@export var debug_draw_chunk_outlines: bool = true
@export var debug_chunk_line_width: float = 4.0
@export var debug_show_blocks: bool = true
@export var debug_block_color: Color = Color(0.2, 0.9, 0.4, 0.35)
@export var debug_force_content: bool = false   # <- turn ON to force buildings/ruins in every chunk
@export var debug_print_generation: bool = false

# Internal
var _player: Node2D
var _chunks: Dictionary = {}   # Vector2i -> Node2D
var _current_center: Vector2i = Vector2i(999999, 999999)
var _blocked_cells: Dictionary = {}      # Vector2i -> true
var _manual_blocked_cells: Dictionary = {} # Vector2i -> true (handcrafted, never unloaded)
var _chunk_blocked: Dictionary = {}      # Vector2i(chunk_coord) -> Array[Vector2i(global_cell)]
var _projectile_blockers: Dictionary = {} # Vector2i -> packed WorldBlockerGeometry descriptor
var _projectile_blocker_owners: Dictionary = {} # Vector2i -> instance id
var _gen_coord: Vector2i = Vector2i.ZERO
var _nav_revision: int = 0
var _nav_revision_pending := false
var _nav_revision_requests := 0
var _nav_revision_commits := 0
var _nav_revision_reasons: Dictionary = {}
var _nav_revision_last_reason: StringName = &""
var _chunk_generation_queue: Array[Vector2i] = []
var _queued_chunk_coords: Dictionary = {}

var _debug_tex: Texture2D = null

func _ready() -> void:
	add_to_group(&"chunk_manager")
	_ensure_tile_renderer()

	_player = get_tree().get_first_node_in_group(String(player_group)) as Node2D

	if unload_radius < load_radius:
		unload_radius = load_radius + 1

	if _player == null:
		push_warning("[ChunkManager] Player not found (group '%s')." % String(player_group))
		return

	if _site_mgr == null:
		_site_mgr = _SITE_MGR.new() as SiteManager

	_current_center = _world_to_chunk(_player.global_position)
	_update_streaming()

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(String(player_group)) as Node2D
		if _player == null:
			return

	var c: Vector2i = _world_to_chunk(_player.global_position)
	if c != _current_center:
		_current_center = c
		_update_streaming()
	process_chunk_generation_queue()


func loaded_chunk_count() -> int:
	return _chunks.size()

func _update_streaming() -> void:
	# The center must exist immediately; surrounding chunks are safely beyond the
	# viewport and are generated nearest-first across subsequent frames.
	if _chunks.is_empty() and not _chunks.has(_current_center):
		_chunks[_current_center] = _create_chunk(_current_center)
	queue_missing_chunks(_current_center)

	# Unload far chunks
	var to_remove: Array[Vector2i] = []
	for k in _chunks.keys():
		var key: Vector2i = k
		var d := _chebyshev_dist(key, _current_center)
		if d > unload_radius:
			to_remove.append(key)

	for key in to_remove:
		_unregister_chunk_cells(key)

		var n: Node2D = _chunks[key] as Node2D
		if n != null:
			if _tile_renderer != null:
				_tile_renderer.clear_chunk(n)
			n.queue_free()
		_chunks.erase(key)
	if not to_remove.is_empty() and PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_counter_event(&"world", &"chunks_unloaded", to_remove.size())


func queue_missing_chunks(center: Vector2i) -> void:
	_chunk_generation_queue.clear()
	_queued_chunk_coords.clear()
	for dy in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var coord := Vector2i(center.x + dx, center.y + dy)
			if _chunks.has(coord) or _queued_chunk_coords.has(coord):
				continue
			_chunk_generation_queue.append(coord)
			_queued_chunk_coords[coord] = true
	_chunk_generation_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := _chebyshev_dist(a, center)
		var db := _chebyshev_dist(b, center)
		if da != db:
			return da < db
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)


func process_chunk_generation_queue(limit: int = -1) -> int:
	var budget := maxi(1, max_chunk_generations_per_frame) if limit < 0 else maxi(0, limit)
	var generated := 0
	while generated < budget and not _chunk_generation_queue.is_empty():
		var coord: Vector2i = _chunk_generation_queue.pop_front()
		_queued_chunk_coords.erase(coord)
		if _chunks.has(coord):
			continue
		if _chebyshev_dist(coord, _current_center) > load_radius:
			continue
		_chunks[coord] = _create_chunk(coord)
		generated += 1
	if _chunk_generation_queue.is_empty() and _nav_revision_pending:
		call_deferred("commit_pending_nav_revision")
	return generated


func debug_chunk_queue() -> Array[Vector2i]:
	return _chunk_generation_queue.duplicate()

func _create_chunk(coord: Vector2i) -> Node2D:
	var generation_started := Time.get_ticks_usec()
	var chunk := Node2D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk.position = _chunk_to_world_origin(coord)
	add_child(chunk)
	_prepare_chunk_rendering(chunk, coord)

	# Prepare blocked list for this chunk
	_chunk_blocked[coord] = []

	# Ground visuals (one sprite per chunk, region-repeated)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for_chunk(coord)
	if ground_enabled:
		_add_ground(chunk, rng, coord)
		if decals_enabled:
			_add_decals(chunk, rng)


	if debug_draw_chunk_outlines:
		_add_chunk_outline(chunk)

	if generation_enabled:
		_generate_chunk(coord, chunk)
		_tile_repeated_visuals(chunk)
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_counter_event(&"world", &"chunk_created", 1, {
			"coord": str(coord),
			"generation_usec": Time.get_ticks_usec() - generation_started,
		})
	return chunk


# ------------------------------------------------------------
# Segment builder API
# ------------------------------------------------------------

func set_chunk_archetype(coord: Vector2i, archetype: StringName) -> void:
	_chunk_archetype[coord] = archetype

func clear_chunk_archetypes() -> void:
	_chunk_archetype.clear()

func get_chunk_archetype(coord: Vector2i) -> StringName:
	return _chunk_archetype.get(coord, &"default") as StringName

func set_chunk_connectors(coord: Vector2i, mask: int) -> void:
	_chunk_connectors[coord] = mask

func clear_chunk_connectors() -> void:
	_chunk_connectors.clear()

func get_chunk_connectors(coord: Vector2i) -> int:
	return int(_chunk_connectors.get(coord, 0))

func set_chunk_urban_access(coord: Vector2i, mask: int) -> void:
	_chunk_urban_access[coord] = mask

func clear_chunk_urban_access() -> void:
	_chunk_urban_access.clear()

func get_chunk_urban_access(coord: Vector2i) -> int:
	return int(_chunk_urban_access.get(coord, 0))

func set_chunk_role(coord: Vector2i, role: StringName) -> void:
	_chunk_role[coord] = role

func clear_chunk_roles() -> void:
	_chunk_role.clear()

func get_chunk_role(coord: Vector2i) -> StringName:
	return _chunk_role.get(coord, &"unplanned") as StringName

func set_chunk_terrain(coord: Vector2i, terrain: StringName) -> void:
	_chunk_terrain[coord] = terrain

func clear_chunk_terrain() -> void:
	_chunk_terrain.clear()

func get_chunk_terrain(coord: Vector2i) -> StringName:
	return _chunk_terrain.get(coord, &"") as StringName

func set_fallback_terrain(terrain: StringName) -> void:
	_fallback_terrain = terrain if terrain != &"" else &"grass"

func reset_world() -> void:
	# Clears all streamed chunks and blocked-cell caches, then reloads around the player.
	if _tile_renderer != null:
		_tile_renderer.clear_all()
	var keys: Array = _chunks.keys()
	for k in keys:
		var cc: Vector2i = k
		_unregister_chunk_cells(cc)
		var n: Node2D = _chunks[cc] as Node2D
		if n != null:
			n.queue_free()

	_chunks.clear()
	_chunk_blocked.clear()
	_blocked_cells.clear()
	_projectile_blockers.clear()
	_projectile_blocker_owners.clear()
	if _site_mgr != null:
		_site_mgr.reset()

	request_nav_revision(&"world_reset")
	_current_center = _world_to_chunk(_player.global_position) if _player != null else Vector2i(999999, 999999)
	_update_streaming()


func _add_ground(chunk: Node2D, _rng: RandomNumberGenerator, coord: Vector2i) -> void:
	var ground_count: int = _WORLD_ART.ground_texture_count()
	if ground_count <= 0:
		return

	var terrain: StringName = get_chunk_terrain(coord)
	if terrain == &"":
		terrain = _fallback_terrain
		# Unplanned streamed chunks stay explorable and natural instead of becoming
		# square city slabs. Add a little deterministic dirt variation.
		if terrain == &"grass" and posmod(_seed_for_chunk(coord), 5) == 0:
			terrain = &"dirt"

	var tex_index: int = _ground_index_for_terrain(terrain)
	tex_index = clampi(tex_index, 0, ground_count - 1)
	var ground_tex: Texture2D = _WORLD_ART.ground_texture(tex_index)
	if ground_tex == null:
		return
	if tiled_world_rendering:
		_ensure_tile_renderer()
		if _tile_renderer != null:
			_tile_renderer.paint_repeating_rect(
				chunk,
				&"ground",
				Rect2i(Vector2i.ZERO, Vector2i(_cells_per_chunk(), _cells_per_chunk())),
				ground_tex,
				_WORLD_ART.ground_repeat_world_px(tex_index),
				-100,
				Color.WHITE
			)
		return

	var spr := Sprite2D.new()
	spr.name = "Ground"
	spr.z_index = -100
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.texture = ground_tex
	spr.region_enabled = true

	# Keep the texture continuous in world space across chunk boundaries.
	var tile_px: int = _WORLD_ART.texture_tile_px()
	var repeat_world_px: int = _WORLD_ART.ground_repeat_world_px(tex_index)
	var source_per_world: float = float(tile_px) / float(repeat_world_px)
	var phase_x: float = float(posmod(world_seed * 31, tile_px))
	var phase_y: float = float(posmod(world_seed * 53, tile_px))
	var world_x: float = float(coord.x * chunk_size_px)
	var world_y: float = float(coord.y * chunk_size_px)
	var ox: float = fposmod(phase_x + world_x * source_per_world, float(tile_px))
	var oy: float = fposmod(phase_y + world_y * source_per_world, float(tile_px))
	spr.region_rect = Rect2(ox, oy, float(chunk_size_px) * source_per_world, float(chunk_size_px) * source_per_world)

	var texture_scale: float = float(repeat_world_px) / float(tile_px)
	spr.scale = Vector2(texture_scale, texture_scale)
	spr.modulate = Color.WHITE
	spr.position = Vector2(float(chunk_size_px) * 0.5, float(chunk_size_px) * 0.5)
	chunk.add_child(spr)

func _ground_index_for_terrain(terrain: StringName) -> int:
	match terrain:
		&"grass":
			return 0
		&"dirt":
			return 1
		&"mud":
			return 5
		&"urban":
			return 6
		_:
			return 0

func _add_decals(chunk: Node2D, rng: RandomNumberGenerator) -> void:
	var decal_count: int = _WORLD_ART.decal_texture_count()
	if decal_count <= 0:
		return

	var n: int = rng.randi_range(decals_per_chunk_min, decals_per_chunk_max)
	if n <= 0:
		return

	var cells: int = _cells_per_chunk()
	var s: float = float(cell_size_px) / float(_WORLD_ART.texture_tile_px())

	for i in range(n):
		var texture := _WORLD_ART.decal_texture(rng.randi_range(0, decal_count - 1))
		var alpha := rng.randf_range(0.12, 0.25)
		var _scale_variation := rng.randf_range(0.75, 1.25)
		var quarter_turns := rng.randi_range(0, 3)
		var flip_h := rng.randf() < 0.5
		var flip_v := rng.randf() < 0.5
		var cx: int = rng.randi_range(0, cells - 1)
		var cy: int = rng.randi_range(0, cells - 1)
		if tiled_world_rendering:
			_ensure_tile_renderer()
			if _tile_renderer != null:
				_tile_renderer.paint_transformed_texture(
					chunk, &"decal", Vector2i(cx, cy), texture, -90,
					quarter_turns, flip_h, flip_v, Color(1, 1, 1, alpha)
				)
			continue
		var spr := Sprite2D.new()
		spr.name = "Decal_%d" % i
		spr.z_index = -90
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.texture = texture

		# Keep decals subtle; they're just to break repetition.
		spr.modulate = Color(1, 1, 1, alpha)

		# Size + rotation variety
		var ss := s * _scale_variation
		spr.scale = Vector2(ss, ss)
		spr.rotation = float(quarter_turns) * PI * 0.5
		spr.flip_h = flip_h
		spr.flip_v = flip_v
		spr.position = Vector2(float(cx * cell_size_px) + float(cell_size_px) * 0.5, float(cy * cell_size_px) + float(cell_size_px) * 0.5)
		spr.set_meta(&"_tile_repeat_visual", true)

		chunk.add_child(spr)


func _add_environment_deco(chunk: Node2D, rng: RandomNumberGenerator, archetype: StringName, _conn_mask: int) -> void:
	# Non-blocking flavor: vegetation + landmarks so the world doesn't feel empty.
	var role: StringName = get_chunk_role(_gen_coord)
	var cells: int = _cells_per_chunk()
	if cells <= 0:
		return

	# Vegetation scatter (more in open/plaza, less in gate).
	var n := rng.randi_range(veg_per_chunk_min, veg_per_chunk_max)
	if role == &"service_lane" or role == &"exploration_reward" or role == &"unplanned":
		n += 2
	if archetype == &"gate" or role == &"checkpoint" or role == &"miniboss_arena":
		n = maxi(0, n - 1)

	var vegetation_count: int = _WORLD_ART.vegetation_texture_count()
	if vegetation_count > 0:
		for i in range(n):
			var c := _pick_free_cell_local(rng, cells)
			if c.x < 0:
				break
			var texture := _WORLD_ART.vegetation_texture(rng.randi_range(0, vegetation_count - 1))
			var _scale_variation := rng.randf_range(0.9, 1.15)
			var quarter_turns := rng.randi_range(0, 3)
			var alpha := rng.randf_range(0.55, 0.85)
			if tiled_world_rendering:
				_ensure_tile_renderer()
				if _tile_renderer != null:
					_tile_renderer.paint_transformed_texture(
						chunk, &"deco", c, texture, -85,
						quarter_turns, false, false, Color(1, 1, 1, alpha)
					)
				continue
			var spr := Sprite2D.new()
			spr.name = "Veg_%d" % i
			spr.z_index = -85
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			spr.texture = texture
			spr.scale = Vector2(0.0625, 0.0625) * _scale_variation
			spr.rotation = float(quarter_turns) * PI * 0.5
			spr.modulate.a = alpha
			spr.position = Vector2(float(c.x * cell_size_px) + float(cell_size_px) * 0.5, float(c.y * cell_size_px) + float(cell_size_px) * 0.5)
			spr.set_meta(&"_tile_repeat_visual", true)
			chunk.add_child(spr)

	# Landmark plazas always receive a memorable object; other special chunks keep a rare chance.
	var force_landmark: bool = (role == &"landmark_plaza")
	var special_landmark_roll: bool = (archetype == &"plaza" or archetype == &"arena" or archetype == &"gate") and rng.randi_range(0, landmark_chance_per_special_chunk) == 0
	if force_landmark or special_landmark_roll:
		var landmark_count: int = _WORLD_ART.landmark_texture_count()
		if landmark_count <= 0:
			return
		var texture := _WORLD_ART.landmark_texture(rng.randi_range(0, landmark_count - 1))
		var offset_cells: int = 4 if force_landmark else 2
		var ox_cells := rng.randi_range(-offset_cells, offset_cells)
		var oy_cells := rng.randi_range(-offset_cells, offset_cells)
		var landmark_cell := Vector2i(cells / 2 + ox_cells, cells / 2 + oy_cells)
		var alpha := 0.82 if force_landmark else 0.72
		if tiled_world_rendering:
			_ensure_tile_renderer()
			if _tile_renderer != null:
				_tile_renderer.paint_transformed_texture(
					chunk, &"landmark", landmark_cell, texture, -83,
					0, false, false, Color(1, 1, 1, alpha)
				)
			return
		var spr2 := Sprite2D.new()
		spr2.name = "Landmark"
		spr2.z_index = -83
		spr2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr2.texture = texture
		spr2.scale = Vector2(0.0625, 0.0625)
		var ox := float(ox_cells * cell_size_px)
		var oy := float(oy_cells * cell_size_px)
		spr2.position = Vector2(float(chunk_size_px) * 0.5 + ox, float(chunk_size_px) * 0.5 + oy)
		spr2.modulate.a = alpha
		chunk.add_child(spr2)

func _pick_free_cell_local(rng: RandomNumberGenerator, cells: int) -> Vector2i:
	# Picks a local cell that isn't blocked by our spawned cover. Used for decorative sprites.
	for _t in range(50):
		var x := rng.randi_range(padding_cells, cells - padding_cells - 1)
		var y := rng.randi_range(padding_cells, cells - padding_cells - 1)

		var global_cell: Vector2i = Vector2i(_gen_coord.x * cells + x, _gen_coord.y * cells + y)
		if _blocked_cells.has(global_cell) or _manual_blocked_cells.has(global_cell):
			continue
		return Vector2i(x, y)
	return Vector2i(-1, -1)


func _add_chunk_outline(chunk: Node2D) -> void:
	var l := Line2D.new()
	l.name = "ChunkOutline"
	l.width = debug_chunk_line_width
	l.default_color = Color(1, 1, 1, 0.20)
	l.antialiased = true

	var s: float = float(chunk_size_px)
	l.points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(s, 0),
		Vector2(s, s),
		Vector2(0, s),
		Vector2(0, 0)
	])

	chunk.add_child(l)


# ------------------------------------------------------------
# Procedural content (delegated to ChunkGenImpl)
# ------------------------------------------------------------

func _ensure_content_gen() -> void:
	if _content_gen == null:
		_content_gen = _GEN_IMPL.new() as ChunkGenImpl
	if _content_gen != null:
		_content_gen.bind(self)

func _generate_chunk(coord: Vector2i, chunk: Node2D) -> void:
	_ensure_content_gen()
	if _content_gen != null:
		_content_gen._generate_chunk(coord, chunk)

# Optional: keep these helpers on ChunkManager for other systems.
func _stamp_floor_rect_cells(chunk: Node2D, rect: Rect2i, tex_index: int, rng: RandomNumberGenerator, alpha: float, z: int) -> void:
	_ensure_content_gen()
	if _content_gen != null:
		_content_gen._stamp_floor_rect_cells(chunk, rect, tex_index, rng, alpha, z)

func _stamp_floor_rect_cells_patchy(chunk: Node2D, rect: Rect2i, tex_index: int, rng: RandomNumberGenerator, alpha: float, z: int) -> void:
	_ensure_content_gen()
	if _content_gen != null:
		_content_gen._stamp_floor_rect_cells_patchy(chunk, rect, tex_index, rng, alpha, z)

func _spawn_wall_cells(chunk: Node2D, wall_cells: Dictionary, window_cells: Dictionary) -> void:
	_ensure_content_gen()
	if _content_gen != null:
		_content_gen._spawn_wall_cells(chunk, wall_cells, window_cells)

func _cells_per_chunk() -> int:
	return int(floor(float(chunk_size_px) / float(cell_size_px)))

func _ensure_debug_tex() -> void:
	if _debug_tex != null:
		return
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_debug_tex = ImageTexture.create_from_image(img)

func _spawn_block(chunk: Node2D, scene: PackedScene, cell_x: int, cell_y: int) -> Node2D:
	# Compute global cell first so we can avoid double-spawns (corners, ruin overlaps, etc.)
	var cells_per_chunk: int = _cells_per_chunk()
	var global_cell: Vector2i = Vector2i(
		_gen_coord.x * cells_per_chunk + cell_x,
		_gen_coord.y * cells_per_chunk + cell_y
	)

	if _blocked_cells.has(global_cell) or _manual_blocked_cells.has(global_cell):
		return null

	var n := scene.instantiate()
	var b := n as Node2D
	if b == null:
		n.queue_free()
		return null

	var px: float = float(cell_x * cell_size_px) + float(cell_size_px) * 0.5
	var py: float = float(cell_y * cell_size_px) + float(cell_size_px) * 0.5
	b.position = Vector2(px, py)

	chunk.add_child(b)
	b.set_meta(&"_tile_repeat_visual", true)

	# --- register blocked cell in global grid ---
	_blocked_cells[global_cell] = true
	if _chunk_blocked.has(_gen_coord):
		(_chunk_blocked[_gen_coord] as Array).append(global_cell)

	# If cover scenes have no visuals, add a debug square
	if debug_show_blocks:
		_ensure_debug_tex()
		if b.get_node_or_null("DebugVis") == null and b.get_node_or_null("Sprite2D") == null:
			var s := Sprite2D.new()
			s.name = "DebugVis"
			s.texture = _debug_tex
			s.centered = true
			s.modulate = debug_block_color
			s.scale = Vector2(float(cell_size_px), float(cell_size_px))
			b.add_child(s)

	return b


func _ensure_tile_renderer() -> void:
	if _tile_renderer == null:
		_tile_renderer = _TILE_RENDERER.new() as ChunkTileRenderer
	if _tile_renderer != null:
		_tile_renderer.enabled = tiled_world_rendering
		_tile_renderer.configure_host(self, cell_size_px)


func _prepare_chunk_rendering(chunk: Node2D, _coord: Vector2i) -> void:
	_ensure_tile_renderer()
	if _tile_renderer != null:
		chunk.set_meta(&"_chunk_tile_coord", _coord)
		chunk.set_meta(&"_chunk_cells_per_side", _cells_per_chunk())
		_tile_renderer.begin_chunk(chunk, cell_size_px)
		if chunk.get_parent() != self and not _external_tile_roots.has(chunk):
			_external_tile_roots.append(chunk)


func _tile_repeated_visuals(chunk: Node2D) -> void:
	_ensure_tile_renderer()
	if not tiled_world_rendering or _tile_renderer == null or chunk == null:
		return
	var sprites: Array[Node] = chunk.find_children("*", "Sprite2D", true, false)
	for candidate in sprites:
		var sprite := candidate as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var owner_marked := sprite.has_meta(&"_tile_repeat_visual")
		var parent_marked := sprite.get_parent() != null and sprite.get_parent().has_meta(&"_tile_repeat_visual")
		if not owner_marked and not parent_marked:
			continue
		if sprite.name == "Shadow":
			sprite.queue_free()
			continue
		var local_position := chunk.to_local(sprite.global_position)
		var cell := Vector2i(
			floori(local_position.x / float(cell_size_px)),
			floori(local_position.y / float(cell_size_px))
		)
		var layer_kind: StringName = &"structure" if parent_marked else &"deco"
		if _tile_renderer.paint_sprite(chunk, layer_kind, cell, sprite, sprite.z_index):
			sprite.queue_free()


func get_tiled_render_stats() -> Dictionary:
	_ensure_tile_renderer()
	var totals := {"chunks": 0, "layers": 0, "cells": 0}
	if _tile_renderer == null:
		return totals
	totals["layers"] = _tile_renderer.get_layer_count()
	for chunk_variant in _chunks.values():
		var chunk := chunk_variant as Node2D
		if chunk == null:
			continue
		var stats := _tile_renderer.get_chunk_stats(chunk)
		totals["chunks"] = int(totals["chunks"]) + 1
		totals["cells"] = int(totals["cells"]) + int(stats.get("cells", 0))
	for chunk in _external_tile_roots:
		if chunk == null or not is_instance_valid(chunk):
			continue
		var stats := _tile_renderer.get_chunk_stats(chunk)
		totals["chunks"] = int(totals["chunks"]) + 1
		totals["cells"] = int(totals["cells"]) + int(stats.get("cells", 0))
	return totals


func erase_repeated_visual(chunk: Node2D, cell: Vector2i) -> bool:
	_ensure_tile_renderer()
	if _tile_renderer == null:
		return false
	return _tile_renderer.erase_cell(chunk, &"structure", cell)


func repaint_repeated_visual(chunk: Node2D, cell: Vector2i, visual_owner: Node) -> bool:
	_ensure_tile_renderer()
	if _tile_renderer == null or visual_owner == null or not visual_owner.has_method("get_visual_texture"):
		return false
	var texture := visual_owner.call("get_visual_texture") as Texture2D
	return _tile_renderer.paint_texture(chunk, &"structure", cell, texture, 0)


func paint_tiled_rect(
	chunk: Node2D,
	layer_kind: StringName,
	rect: Rect2i,
	texture: Texture2D,
	repeat_world_px: int,
	z_index: int,
	modulate: Color
) -> int:
	_ensure_tile_renderer()
	if _tile_renderer == null:
		return 0
	return _tile_renderer.paint_repeating_rect(
		chunk, layer_kind, rect, texture, repeat_world_px, z_index, modulate
	)


func paint_tiled_texture(
	chunk: Node2D,
	layer_kind: StringName,
	cell: Vector2i,
	texture: Texture2D,
	z_index: int,
	quarter_turns: int = 0,
	flip_h: bool = false,
	flip_v: bool = false,
	modulate: Color = Color.WHITE
) -> bool:
	_ensure_tile_renderer()
	if _tile_renderer == null:
		return false
	return _tile_renderer.paint_transformed_texture(
		chunk, layer_kind, cell, texture, z_index,
		quarter_turns, flip_h, flip_v, modulate
	)


func _world_to_chunk(p: Vector2) -> Vector2i:
	var cx: int = floori(p.x / float(chunk_size_px))
	var cy: int = floori(p.y / float(chunk_size_px))
	return Vector2i(cx, cy)

func _chunk_to_world_origin(c: Vector2i) -> Vector2:
	return Vector2(float(c.x * chunk_size_px), float(c.y * chunk_size_px))

func _chebyshev_dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _seed_for_chunk(c: Vector2i) -> int:
	var h: int = world_seed
	h = int((h ^ (c.x * 73856093)) & 0x7FFFFFFF)
	h = int((h ^ (c.y * 19349663)) & 0x7FFFFFFF)
	h = int((h * 83492791)) & 0x7FFFFFFF
	return h

func is_cell_blocked(cell: Vector2i) -> bool:
	return _blocked_cells.has(cell) or _manual_blocked_cells.has(cell)


func is_cell_walkable(cell: Vector2i) -> bool:
	# treat unloaded chunks as not-walkable so pathing doesn't route into void
	var cc: Vector2i = _cell_to_chunk(cell)
	if not _chunks.has(cc):
		return false
	return (not _blocked_cells.has(cell)) and (not _manual_blocked_cells.has(cell))


func register_manual_block_cell(cell: Vector2i) -> void:
	_manual_blocked_cells[cell] = true
	request_nav_revision(&"manual_block_added")

func register_manual_block_world(pos: Vector2) -> void:
	register_manual_block_cell(world_to_cell(pos))

func unregister_manual_block_cell(cell: Vector2i) -> void:
	if not _manual_blocked_cells.has(cell):
		return
	_manual_blocked_cells.erase(cell)
	request_nav_revision(&"manual_block_removed")

func clear_manual_blocks() -> void:
	if _manual_blocked_cells.size() == 0:
		return
	_manual_blocked_cells.clear()
	request_nav_revision(&"manual_blocks_cleared")

func register_projectile_blocker_world(world_position: Vector2, descriptor: int, owner_id: int) -> void:
	var cell: Vector2i = world_to_cell(world_position)
	_projectile_blockers[cell] = descriptor
	_projectile_blocker_owners[cell] = owner_id

func unregister_projectile_blocker_world(world_position: Vector2, owner_id: int) -> void:
	var cell: Vector2i = world_to_cell(world_position)
	if int(_projectile_blocker_owners.get(cell, -1)) != owner_id:
		return
	_projectile_blockers.erase(cell)
	_projectile_blocker_owners.erase(cell)

## Grid DDA broad phase plus swept primitive narrow phase. No physics nodes,
## per-projectile arrays, or per-frame allocation are needed on this hot path.
func projectile_hit_t(from_pos: Vector2, to_pos: Vector2, projectile_radius: float) -> float:
	var start_cell: Vector2i = world_to_cell(from_pos)
	var end_cell: Vector2i = world_to_cell(to_pos)
	var cell: Vector2i = start_cell
	var delta: Vector2 = to_pos - from_pos
	var step_x: int = signi(int(signf(delta.x)))
	var step_y: int = signi(int(signf(delta.y)))
	var t_delta_x: float = INF if step_x == 0 else absf(float(cell_size_px) / delta.x)
	var t_delta_y: float = INF if step_y == 0 else absf(float(cell_size_px) / delta.y)
	var boundary_x: float = float((cell.x + (1 if step_x > 0 else 0)) * cell_size_px)
	var boundary_y: float = float((cell.y + (1 if step_y > 0 else 0)) * cell_size_px)
	var t_max_x: float = INF if step_x == 0 else (boundary_x - from_pos.x) / delta.x
	var t_max_y: float = INF if step_y == 0 else (boundary_y - from_pos.y) / delta.y
	var best: float = 2.0
	var guard: int = 0
	while guard < 512:
		guard += 1
		best = minf(best, _projectile_neighborhood_hit_t(cell, from_pos, to_pos, projectile_radius))
		if cell == end_cell or minf(t_max_x, t_max_y) > best:
			break
		if t_max_x < t_max_y:
			cell.x += step_x
			t_max_x += t_delta_x
		else:
			cell.y += step_y
			t_max_y += t_delta_y
	return best if best <= 1.0 else -1.0

func _projectile_neighborhood_hit_t(trace_cell: Vector2i, from_pos: Vector2, to_pos: Vector2, projectile_radius: float) -> float:
	var best: float = 2.0
	var oy: int = -1
	while oy <= 1:
		var ox: int = -1
		while ox <= 1:
			var candidate: Vector2i = trace_cell + Vector2i(ox, oy)
			var descriptor: int = -1
			if _projectile_blockers.has(candidate):
				descriptor = int(_projectile_blockers[candidate])
			elif is_cell_blocked(candidate):
				descriptor = WorldBlockerGeometry.pack(WorldBlockerGeometry.Kind.SOLID_CELL)
			if descriptor >= 0:
				var hit_t: float = WorldBlockerGeometry.swept_hit_t(descriptor, cell_to_world_center(candidate), from_pos, to_pos, projectile_radius, float(cell_size_px))
				if hit_t >= 0.0:
					best = minf(best, hit_t)
			ox += 1
		oy += 1
	# Preserve the old safety rule at the actual path cell: projectiles do not
	# escape into an unloaded chunk, but loaded neighboring cells do not become
	# false 64 px blockers merely because the broad phase examined them.
	if not _chunks.has(_cell_to_chunk(trace_cell)):
		var void_t: float = WorldBlockerGeometry.swept_hit_t(WorldBlockerGeometry.pack(WorldBlockerGeometry.Kind.SOLID_CELL), cell_to_world_center(trace_cell), from_pos, to_pos, projectile_radius, float(cell_size_px))
		if void_t >= 0.0:
			best = minf(best, void_t)
	return best


func world_to_cell(p: Vector2) -> Vector2i:
	var cs: float = float(cell_size_px)
	return Vector2i(floori(p.x / cs), floori(p.y / cs))


func cell_to_world_center(c: Vector2i) -> Vector2:
	var cs: float = float(cell_size_px)
	return Vector2((float(c.x) + 0.5) * cs, (float(c.y) + 0.5) * cs)


func _cell_to_chunk(cell: Vector2i) -> Vector2i:
	var cpc: int = _cells_per_chunk()
	# floor division that works for negatives too
	var cx: int = floori(float(cell.x) / float(cpc))
	var cy: int = floori(float(cell.y) / float(cpc))
	return Vector2i(cx, cy)


func _unregister_chunk_cells(chunk_coord: Vector2i) -> void:
	if not _chunk_blocked.has(chunk_coord):
		return

	var arr: Array = _chunk_blocked[chunk_coord] as Array
	for c in arr:
		var cell: Vector2i = c
		_blocked_cells.erase(cell)

	_chunk_blocked.erase(chunk_coord)


	# ✅ tell nav "the blocked grid changed"
	request_nav_revision(&"chunk_unloaded")

func get_nav_revision() -> int:
	return _nav_revision


func request_nav_revision(reason: StringName = &"world_changed") -> void:
	_nav_revision_requests += 1
	_nav_revision_reasons[reason] = int(_nav_revision_reasons.get(reason, 0)) + 1
	_nav_revision_last_reason = reason
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_counter_event(&"world", &"nav_revision_requested", 1, {"reason": String(reason)})
	if _nav_revision_pending:
		if reason == &"chunk_generated" and _chunk_generation_queue.is_empty():
			call_deferred("commit_pending_nav_revision")
		return
	_nav_revision_pending = true
	if reason == &"chunk_generated" and not _chunk_generation_queue.is_empty():
		return
	call_deferred("commit_pending_nav_revision")


func commit_pending_nav_revision() -> void:
	if not _nav_revision_pending:
		return
	_nav_revision_pending = false
	_nav_revision += 1
	_nav_revision_commits += 1
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_event(&"world", &"nav_revision_committed", {
			"revision": _nav_revision,
			"reason": String(_nav_revision_last_reason),
		})


func get_nav_debug_counters() -> Dictionary:
	return {
		"revision": _nav_revision,
		"pending": _nav_revision_pending,
		"requests": _nav_revision_requests,
		"commits": _nav_revision_commits,
		"last_reason": _nav_revision_last_reason,
		"reasons": _nav_revision_reasons.duplicate(),
	}
