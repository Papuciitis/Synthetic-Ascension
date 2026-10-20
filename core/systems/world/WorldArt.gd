@static_unload
extends RefCounted
# Centralised texture access for ChunkManager and procedural generators.
# Deliberately not a global class: consumers explicitly preload this script, avoiding stale global-class member caches.

const _TEX_TILE_PX: int = 1024
# Cethiel source tiles are 512 px, processed to 1024 px. One active tile covers 1024 world pixels.
## World pixels one ground tile covers.
##
## This was 1024, and the masonry textures carry about four blocks across a
## tile - so a single paving stone rendered roughly 256 px, five times the
## player sprite. The whole world read as a giant's floor rather than a street,
## and the enormous repeat also made every chunk seam a hard visible step
## because two adjacent chunks each showed a different quarter of the pattern.
##
## 384 puts a paving stone at about 96 px - a stride and a half - which is the
## scale the wall and prop art is already drawn at.
const _GROUND_REPEAT_WORLD_PX: int = 384
const _GROUND_GRASS_REPEAT_WORLD_PX: int = 320
const _GROUND_BASE_TEX_INDEX: int = 0
## Shader-only household care; never allocate this as a semantic terrain slot.
const GROUND_CARED_LAWN_INDEX: int = 13

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
	# Existing meadow/scrub remain wild. Semantic moss retains index12 while
	# drawing the selected subdued source for damp canals and underpasses.
	"res://assets/world/ground/ground_grass_02.png",
	"res://assets/world/ground/ground_grass_dry_01.png",
	"res://assets/world/ground/city_care/v1/damp_moss_soil.png",
	"res://assets/world/ground/city_care/v1/cared_lawn.png",
]

## Indices that read as vegetation and repeat at the grass scale.
const _GRASS_LIKE_INDICES := [0, 10, 11, 12]

# Ground assets can arrive in the same overlay that introduces WorldArt. Directly
# preloading them makes Godot parse this script before its importer has registered
# the new PNGs. Cache them on first use instead, with a source-image fallback that
# does not depend on generated .godot import metadata.
static var _ground_tex_cache: Array[Texture2D] = []

# Floor marks with real alpha. The three decal_*.png that used to be here are
# rendered images with a baked black-to-white vignette instead of transparency,
# so every one of them painted a glowing white asterisk onto the ground - which
# is what the world's "subtle repetition-breaking decals" have actually been.
# They are still on disk; nothing should scatter them.
const _DECAL_TEX := [
	preload("res://assets/world/decals/floor/floor_cracks_01.png"),
	preload("res://assets/world/decals/floor/floor_grime_01.png"),
	preload("res://assets/world/decals/floor/floor_scorch_01.png"),
	preload("res://assets/world/decals/floor/floor_spill_01.png"),
	preload("res://assets/world/decals/floor/floor_marking_01.png"),
	preload("res://assets/world/decals/floor/floor_scuff_01.png"),
	preload("res://assets/world/decals/floor/floor_rubble_01.png"),
]

const _VEG_TEX := [
	"res://assets/world/dressing/generated/fern.tres",
	"res://assets/world/dressing/generated/olive_shrub.tres",
	"res://assets/world/vegetation/veg_dead_tree_01.png",
]
const _DRESSING_ROOT := "res://assets/world/dressing/generated/"
const _DRESSING_NAMES := [&"fern", &"olive_shrub", &"mossy_rubble", &"crate", &"broken_pillar", &"hooded_statue"]
static var _dressing_cache: Dictionary = {}

const _LANDMARK_TEX := [
	preload("res://assets/world/landmarks/landmark_obelisk_01.png"),
	preload("res://assets/world/landmarks/landmark_shrine_piece_01.png"),
	preload("res://assets/world/landmarks/landmark_big_statue_01.png"),
]

static func texture_tile_px() -> int:
	return _TEX_TILE_PX

static func ground_repeat_world_px(texture_index: int = -1) -> int:
	# The quieter patchy grass reads better slightly smaller than the masonry materials.
	if texture_index in _GRASS_LIKE_INDICES or texture_index == GROUND_CARED_LAWN_INDEX:
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


static func release_static_caches() -> void:
	# Called at application shutdown: script statics destruct during script
	# server teardown, after rendering cleanup has begun, so RID-backed
	# resources held here must be released while the servers are still whole.
	_ground_tex_cache.clear()
	_ground_array = null
	_dressing_cache.clear()


## Pixel size of one ground layer in the splat texture array. The sources are
## 1024 px for a 320-384 px world repeat, so half resolution is still above
## 1:1 on screen.
const _GROUND_ARRAY_LAYER_PX: int = 512
const GROUND_ARRAY_CACHE_REVISION: int = 1
const GROUND_ARRAY_CACHE_PATH := "res://assets/world/ground/baked/ground_materials.res"
const GROUND_ARRAY_MANIFEST_PATH := "res://assets/world/ground/baked/ground_materials.json"
static var _ground_array: Texture2DArray = null


## Every ground texture as one Texture2DArray (layer = ground texture index),
## for the ground splat shader. The committed derived array avoids native
## GPU readback during first entry. The original builder remains available
## for missing-cache fallback, rebaking and exact pixel verification.
static func ground_material_array(prefer_baked: bool = true) -> Texture2DArray:
	if _ground_array != null:
		return _ground_array
	if prefer_baked and prepare_baked_ground_materials():
		return _ground_array
	var images: Array[Image] = []
	for index in _GROUND_TEX_PATHS.size():
		images.append(prepare_ground_material_layer(index))
	return cache_ground_material_layers(images)


static func prepare_baked_ground_materials() -> bool:
	if _ground_array != null:
		return true
	if not _baked_ground_materials_are_available():
		return false
	return _load_baked_ground_materials()


## Keep source fingerprinting and native array loading on separate transition
## frames. Direct startup still uses the synchronous method above.
static func prepare_baked_ground_materials_for_transition(tree: SceneTree) -> bool:
	if _ground_array != null:
		return true
	if not _baked_ground_materials_are_available():
		return false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	await tree.process_frame
	# Another request may have completed the same array during this yield.
	return _load_baked_ground_materials()


static func _baked_ground_materials_are_available() -> bool:
	if not ResourceLoader.exists(GROUND_ARRAY_CACHE_PATH, "Texture2DArray"):
		return false
	# Source checkouts must not silently show yesterday's pixels after an art
	# edit. Exported builds retain the resource-only contract: import sidecars
	# and original PNG/JSON files need not be present in their package.
	if OS.has_feature("editor"):
		if not FileAccess.file_exists(GROUND_ARRAY_MANIFEST_PATH):
			return false
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(GROUND_ARRAY_MANIFEST_PATH))
		if not ground_material_manifest_is_current(manifest):
			return false
	return true


static func _load_baked_ground_materials() -> bool:
	if _ground_array != null:
		return true
	var array := ResourceLoader.load(GROUND_ARRAY_CACHE_PATH, "Texture2DArray") as Texture2DArray
	if array == null or array.get_layers() != _GROUND_TEX_PATHS.size() or array.get_width() != _GROUND_ARRAY_LAYER_PX or array.get_height() != _GROUND_ARRAY_LAYER_PX or array.get_format() != Image.FORMAT_RGB8:
		return false
	_ground_array = array
	return true


## Validate provenance without GPU readback. Native pixel verification still
## compares every baked layer/mipmap with prepare_ground_material_layer().
static func ground_material_manifest_is_current(manifest: Variant) -> bool:
	if not manifest is Dictionary:
		return false
	var record: Dictionary = manifest
	var revision: Variant = record.get("algorithm_revision")
	var layer_size: Variant = record.get("layer_size")
	if not (revision is int or revision is float) or revision != GROUND_ARRAY_CACHE_REVISION:
		return false
	if not (layer_size is int or layer_size is float) or layer_size != _GROUND_ARRAY_LAYER_PX:
		return false
	var format: Variant = record.get("format")
	if not format is String or format != "RGB8 with generated mipmaps":
		return false
	var sources: Variant = record.get("sources")
	if not sources is Array:
		return false
	var source_list: Array = sources
	# Check the length before indexing either list, including malformed manifests.
	if source_list.size() != _GROUND_TEX_PATHS.size():
		return false
	if not _ground_cache_hash_matches(record.get("cache_sha256"), GROUND_ARRAY_CACHE_PATH):
		return false
	for index in source_list.size():
		if not source_list[index] is Dictionary:
			return false
		var entry: Dictionary = source_list[index]
		var path: String = _GROUND_TEX_PATHS[index]
		var recorded_path: Variant = entry.get("path")
		if not recorded_path is String or recorded_path != path:
			return false
		if not _ground_cache_hash_matches(entry.get("sha256"), path):
			return false
		if not _ground_cache_hash_matches(entry.get("import_sha256"), path + ".import"):
			return false
	return true


static func _ground_cache_hash_matches(recorded_hash: Variant, path: String) -> bool:
	if not recorded_hash is String:
		return false
	var digest: String = recorded_hash
	return digest.length() == 64 and FileAccess.file_exists(path) and digest == FileAccess.get_sha256(path)


static func ground_material_array_is_cached() -> bool:
	return _ground_array != null


## The same layer preparation used by synchronous worlds, exposed as one
## bounded unit so the transition can render between expensive first loads.
static func prepare_ground_material_layer(index: int) -> Image:
	var texture := ground_texture(index)
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.is_empty():
		image = Image.create(_GROUND_ARRAY_LAYER_PX, _GROUND_ARRAY_LAYER_PX, false, Image.FORMAT_RGB8)
		image.fill(Color(0.35, 0.35, 0.33))
	else:
		image = image.duplicate() as Image
		if image.is_compressed():
			image.decompress()
		image.clear_mipmaps()
		image.convert(Image.FORMAT_RGB8)
		while image.get_width() >= _GROUND_ARRAY_LAYER_PX * 2 and image.get_height() >= _GROUND_ARRAY_LAYER_PX * 2:
			image.shrink_x2()
		if image.get_width() != _GROUND_ARRAY_LAYER_PX or image.get_height() != _GROUND_ARRAY_LAYER_PX:
			image.resize(_GROUND_ARRAY_LAYER_PX, _GROUND_ARRAY_LAYER_PX, Image.INTERPOLATE_BILINEAR)
	image.generate_mipmaps()
	return image


static func cache_ground_material_layers(images: Array[Image]) -> Texture2DArray:
	# A superseding Game request may finish the same preparation first.
	if _ground_array != null:
		return _ground_array
	if images.size() != _GROUND_TEX_PATHS.size():
		return null
	var array := Texture2DArray.new()
	if array.create_from_images(images) != OK:
		return null
	_ground_array = array
	return _ground_array


## Ground texture index for a texture resource, or -1 (authored stamps pass
## textures, the splat works in indices).
static func ground_index_for_texture(texture: Texture2D) -> int:
	if texture == null:
		return -1
	var path := texture.resource_path
	for index in _GROUND_TEX_PATHS.size():
		if str(_GROUND_TEX_PATHS[index]) == path:
			return index
	return -1


static func is_overgrowth_ground(index: int) -> bool:
	return index in _GRASS_LIKE_INDICES


static func ground_texture_is_cached(index: int) -> bool:
	return index >= 0 and index < _ground_tex_cache.size() and _ground_tex_cache[index] != null


static func warm_ground_textures(indices: PackedInt32Array) -> void:
	# Resource loading is deliberately kept outside chunk activation. A first-time
	# PNG import/cache miss can take tens of milliseconds even though creating the
	# region Sprite2D itself is cheap.
	for index in indices:
		ground_texture(index)

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
	return _cached_dressing_texture(_VEG_TEX[index])


static func dressing_texture(id: StringName) -> Texture2D:
	if not id in _DRESSING_NAMES:
		return null
	return _cached_dressing_texture(_DRESSING_ROOT + String(id) + ".tres")


static func _cached_dressing_texture(path: String) -> Texture2D:
	var cached := _dressing_cache.get(path) as Texture2D
	if cached == null and ResourceLoader.exists(path, "Texture2D"):
		cached = ResourceLoader.load(path, "Texture2D") as Texture2D
		if cached != null:
			_dressing_cache[path] = cached
	return cached

static func landmark_texture_count() -> int:
	return _LANDMARK_TEX.size()

static func landmark_texture(index: int) -> Texture2D:
	if index < 0 or index >= _LANDMARK_TEX.size():
		return null
	return _LANDMARK_TEX[index] as Texture2D
