extends RefCounted
# Centralised texture access for ChunkManager and procedural generators.
# Deliberately not a global class: consumers explicitly preload this script, avoiding stale global-class member caches.

const _TEX_TILE_PX: int = 1024
# Cethiel source tiles are 512 px, processed to 1024 px. One active tile covers 1024 world pixels.
const _GROUND_REPEAT_WORLD_PX: int = 1024
const _GROUND_GRASS_REPEAT_WORLD_PX: int = 768
const _GROUND_BASE_TEX_INDEX: int = 0

const _GROUND_TEX_PATHS := [
	"res://assets/world/ground/ground_grass_01.png",
	"res://assets/world/ground/ground_dirt_01.png",
	"res://assets/world/ground/ground_cobble_01.png",
	"res://assets/world/ground/ground_stone_tiles_01.png",
	"res://assets/world/ground/ground_dirt_path_01.png",
	"res://assets/world/ground/ground_mud_wet_01.png",
	"res://assets/world/ground/ground_city_base_01.png",
	"res://assets/world/ground/ground_civic_brick_01.png",
	"res://assets/world/ground/ground_mossy_brick_01.png",
	"res://assets/world/ground/ground_round_cobble_01.png",
]

# Ground assets can arrive in the same overlay that introduces WorldArt. Directly
# preloading them makes Godot parse this script before its importer has registered
# the new PNGs. Cache them on first use instead, with a source-image fallback that
# does not depend on generated .godot import metadata.
static var _ground_tex_cache: Array[Texture2D] = []

const _DECAL_TEX := [
	preload("res://assets/world/decals/decal_cracks_01.png"),
	preload("res://assets/world/decals/decal_stain_01.png"),
	preload("res://assets/world/decals/decal_sigil_01.png"),
]

const _VEG_TEX := [
	preload("res://assets/world/vegetation/veg_bush_cluster_01.png"),
	preload("res://assets/world/vegetation/veg_overgrowth_island_01.png"),
	preload("res://assets/world/vegetation/veg_dead_tree_01.png"),
]

const _LANDMARK_TEX := [
	preload("res://assets/world/landmarks/landmark_obelisk_01.png"),
	preload("res://assets/world/landmarks/landmark_shrine_piece_01.png"),
	preload("res://assets/world/landmarks/landmark_big_statue_01.png"),
]

static func texture_tile_px() -> int:
	return _TEX_TILE_PX

static func ground_repeat_world_px(texture_index: int = -1) -> int:
	# The quieter patchy grass reads better slightly smaller than the masonry materials.
	if texture_index == 0:
		return _GROUND_GRASS_REPEAT_WORLD_PX
	return _GROUND_REPEAT_WORLD_PX

static func ground_base_texture_index() -> int:
	return _GROUND_BASE_TEX_INDEX

static func ground_texture_count() -> int:
	return _GROUND_TEX_PATHS.size()

static func ground_texture(index: int) -> Texture2D:
	if index < 0 or index >= _GROUND_TEX_PATHS.size():
		return null
	while _ground_tex_cache.size() < _GROUND_TEX_PATHS.size():
		_ground_tex_cache.append(null)

	var cached: Texture2D = _ground_tex_cache[index]
	if cached != null:
		return cached

	var path: String = str(_GROUND_TEX_PATHS[index])
	var loaded: Resource = null
	# `exists()` is quiet while the editor is still discovering PNG importers;
	# calling `load()` unconditionally recreates the reported loader error.
	if ResourceLoader.exists(path, "Texture2D"):
		loaded = ResourceLoader.load(path, "Texture2D")
	if loaded is Texture2D:
		cached = loaded as Texture2D
	else:
		var image := Image.new()
		var load_error: Error = image.load(path)
		if load_error == OK and not image.is_empty():
			cached = ImageTexture.create_from_image(image)

	_ground_tex_cache[index] = cached
	return cached

static func decal_texture_count() -> int:
	return _DECAL_TEX.size()

static func decal_texture(index: int) -> Texture2D:
	if index < 0 or index >= _DECAL_TEX.size():
		return null
	return _DECAL_TEX[index] as Texture2D

static func vegetation_texture_count() -> int:
	return _VEG_TEX.size()

static func vegetation_texture(index: int) -> Texture2D:
	if index < 0 or index >= _VEG_TEX.size():
		return null
	return _VEG_TEX[index] as Texture2D

static func landmark_texture_count() -> int:
	return _LANDMARK_TEX.size()

static func landmark_texture(index: int) -> Texture2D:
	if index < 0 or index >= _LANDMARK_TEX.size():
		return null
	return _LANDMARK_TEX[index] as Texture2D
