extends Node2D
class_name ChunkManager

@export var world_seed: int = 1337

@export_group("Chunk Streaming")
@export var chunk_size_px: int = 2048
@export var load_radius: int = 2
@export var unload_radius: int = 3
@export var player_group: StringName = &"player"

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


const _SITE_MGR: Script = preload("res://core/systems/world/proc/SiteManager.gd")
const _GEN_IMPL: Script = preload("res://core/systems/world/proc/ChunkGenImpl.gd")

@export var generation_enabled: bool = true

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
@export_range(0.0, 1.0, 0.01) var district_road_edge_noise_chance: float = 0.35
@export_range(0, 8, 1) var district_plaza_islands_max: int = 4
@export_range(0.0, 1.0, 0.01) var district_plaza_island_chance: float = 0.65

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

# Optional per-chunk archetype overrides set by segment builders.
# Examples: "courtyard", "street", "arena".
var _chunk_archetype: Dictionary = {} # Vector2i -> StringName

var _site_mgr: SiteManager = null
var _content_gen: ChunkGenImpl = null


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
var _gen_coord: Vector2i = Vector2i.ZERO
var _nav_revision: int = 0

var _debug_tex: Texture2D = null

func _ready() -> void:
	add_to_group(&"chunk_manager")

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

func _update_streaming() -> void:
	# Load needed chunks
	for dy in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var cc := Vector2i(_current_center.x + dx, _current_center.y + dy)
			if not _chunks.has(cc):
				_chunks[cc] = _create_chunk(cc)

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
			n.queue_free()
		_chunks.erase(key)

func _create_chunk(coord: Vector2i) -> Node2D:
	var chunk := Node2D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk.position = _chunk_to_world_origin(coord)
	add_child(chunk)

	# Prepare blocked list for this chunk
	_chunk_blocked[coord] = []

	# Ground visuals (one sprite per chunk, region-repeated)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for_chunk(coord)
	if ground_enabled:
		_add_ground(chunk, rng)
		if decals_enabled:
			_add_decals(chunk, rng)


	if debug_draw_chunk_outlines:
		_add_chunk_outline(chunk)

	if generation_enabled:
		_generate_chunk(coord, chunk)
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


func reset_world() -> void:
	# Clears all streamed chunks and blocked-cell caches, then reloads around the player.
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
	if _site_mgr != null:
		_site_mgr.reset()

	_nav_revision += 1
	_current_center = _world_to_chunk(_player.global_position) if _player != null else Vector2i(999999, 999999)
	_update_streaming()


func _add_ground(chunk: Node2D, rng: RandomNumberGenerator) -> void:
	if WorldArt.GROUND_TEX.is_empty():
		return

	var spr := Sprite2D.new()
	spr.name = "Ground"
	spr.z_index = -100
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	var cells: int = _cells_per_chunk()

	# Grass base first (less busy), others become stamps/variation later.
	var tex: Texture2D = WorldArt.GROUND_TEX[0]
	spr.texture = tex

	spr.region_enabled = true
	# Random offset so seams don't line up if texture isn't perfectly tileable
	var ox: float = float(rng.randi_range(0, WorldArt.TEX_TILE_PX - 1))
	var oy: float = float(rng.randi_range(0, WorldArt.TEX_TILE_PX - 1))
	spr.region_rect = Rect2(ox, oy, float(WorldArt.TEX_TILE_PX * cells), float(WorldArt.TEX_TILE_PX * cells))

	var s: float = float(cell_size_px) / float(WorldArt.TEX_TILE_PX)
	spr.scale = Vector2(s, s)

	# Slight per-chunk value variance (breaks "samey" without adding noise)
	var b: float = rng.randf_range(0.95, 1.05)
	spr.modulate = Color(b, b, b, 1.0)

	spr.position = Vector2(float(chunk_size_px) * 0.5, float(chunk_size_px) * 0.5)
	chunk.add_child(spr)

func _add_decals(chunk: Node2D, rng: RandomNumberGenerator) -> void:
	if WorldArt.DECAL_TEX.is_empty():
		return

	var n: int = rng.randi_range(decals_per_chunk_min, decals_per_chunk_max)
	if n <= 0:
		return

	var cells: int = _cells_per_chunk()
	var s: float = float(cell_size_px) / float(WorldArt.TEX_TILE_PX)

	for i in range(n):
		var spr := Sprite2D.new()
		spr.name = "Decal_%d" % i
		spr.z_index = -90
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.texture = WorldArt.DECAL_TEX[rng.randi_range(0, WorldArt.DECAL_TEX.size() - 1)]

		# Keep decals subtle; they're just to break repetition.
		spr.modulate = Color(1, 1, 1, rng.randf_range(0.12, 0.25))

		# Size + rotation variety
		var ss := s * rng.randf_range(0.75, 1.25)
		spr.scale = Vector2(ss, ss)
		spr.rotation = rng.randf_range(0.0, TAU)
		spr.flip_h = rng.randf() < 0.5
		spr.flip_v = rng.randf() < 0.5

		var cx: int = rng.randi_range(0, cells - 1)
		var cy: int = rng.randi_range(0, cells - 1)
		spr.position = Vector2(float(cx * cell_size_px) + float(cell_size_px) * 0.5, float(cy * cell_size_px) + float(cell_size_px) * 0.5)

		chunk.add_child(spr)


func _add_environment_deco(chunk: Node2D, rng: RandomNumberGenerator, archetype: StringName, _conn_mask: int) -> void:
	# Non-blocking flavor: vegetation + landmarks so the world doesn't feel like empty green.
	var cells: int = _cells_per_chunk()
	if cells <= 0:
		return

	# Vegetation scatter (more in open/plaza, less in gate).
	var n := rng.randi_range(veg_per_chunk_min, veg_per_chunk_max)
	if archetype == &"gate":
		n = maxi(0, n - 1)

	for i in range(n):
		var c := _pick_free_cell_local(rng, cells)
		if c.x < 0:
			break
		var spr := Sprite2D.new()
		spr.name = "Veg_%d" % i
		spr.z_index = -85
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.texture = WorldArt.VEG_TEX[rng.randi_range(0, WorldArt.VEG_TEX.size() - 1)]
		spr.scale = Vector2(0.0625, 0.0625) * rng.randf_range(0.9, 1.15)
		spr.rotation = rng.randf_range(0.0, TAU)
		spr.modulate.a = rng.randf_range(0.55, 0.85)
		spr.position = Vector2(float(c.x * cell_size_px) + float(cell_size_px) * 0.5, float(c.y * cell_size_px) + float(cell_size_px) * 0.5)
		chunk.add_child(spr)

	# Landmarks: only for special chunks (plaza/arena/gate) and not every time.
	if archetype == &"plaza" or archetype == &"arena" or archetype == &"gate":
		if rng.randi_range(0, landmark_chance_per_special_chunk) == 0:
			var spr2 := Sprite2D.new()
			spr2.name = "Landmark"
			spr2.z_index = -83
			spr2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			spr2.texture = WorldArt.LANDMARK_TEX[rng.randi_range(0, WorldArt.LANDMARK_TEX.size() - 1)]
			spr2.scale = Vector2(0.0625, 0.0625)
			# Slight offset so it doesn't sit exactly on top of a wardstone/gate
			var ox := float(rng.randi_range(-2, 2) * cell_size_px)
			var oy := float(rng.randi_range(-2, 2) * cell_size_px)
			spr2.position = Vector2(float(chunk_size_px) * 0.5 + ox, float(chunk_size_px) * 0.5 + oy)
			spr2.modulate.a = 0.75
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
	_nav_revision += 1

func register_manual_block_world(pos: Vector2) -> void:
	register_manual_block_cell(world_to_cell(pos))

func unregister_manual_block_cell(cell: Vector2i) -> void:
	if not _manual_blocked_cells.has(cell):
		return
	_manual_blocked_cells.erase(cell)
	_nav_revision += 1

func clear_manual_blocks() -> void:
	if _manual_blocked_cells.size() == 0:
		return
	_manual_blocked_cells.clear()
	_nav_revision += 1


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
	_nav_revision += 1

func get_nav_revision() -> int:
	return _nav_revision
