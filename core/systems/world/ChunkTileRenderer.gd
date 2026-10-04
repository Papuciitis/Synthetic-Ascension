extends RefCounted
class_name ChunkTileRenderer

## Runtime tile renderer for repeated procedural-world artwork.
## Collision scenes and navigation data remain owned by ChunkManager.

var enabled := true

# Decals (FPS audit 2026-10-04, item 8b): one atlas source per decal
# texture, built once from the texture resized to a cell, with one
# alternative tile per alpha level; the orientation rides the cell's tile
# transform flags. The generic path keyed a source on texture x turns x
# flips x the decal's random alpha (~3,800 keys), so nearly every decal paid
# a GPU read-back (texture.get_image), a 512->64 Lanczos resize and a
# TileSet.add_source that re-renders every layer using the set: 77-178 ms
# per segment-1 chunk activation. The levels are the bin centres of the
# 0.12-0.25 alpha ChunkManager draws decals at; a decal snaps to the nearest,
# at most 0.016 off, with the mean unchanged.
const DECAL_ALPHA_LEVELS := [0.13625, 0.16875, 0.20125, 0.23375]
# The cell transform that shows the texture as the old image pipeline baked
# it (flip_x if flip_h, flip_y if flip_v, then quarter_turns clockwise
# rotations), indexed [turns * 4 + flip_h * 2 + flip_v]. Derived from the
# canvas shader: flips mirror the destination rect, transpose swaps the
# texture axes.
const _T := TileSetAtlasSource.TRANSFORM_TRANSPOSE
const _H := TileSetAtlasSource.TRANSFORM_FLIP_H
const _V := TileSetAtlasSource.TRANSFORM_FLIP_V
const DECAL_TRANSFORMS := [
	0, _V, _H, _H | _V,
	_T | _H, _T, _T | _H | _V, _T | _V,
	_H | _V, _H, _V, 0,
	_T | _V, _T | _H | _V, _T, _T | _H,
]

var _cell_size := 64
var _tile_set: TileSet = null
var _source_by_texture: Dictionary = {}
var _host: Node2D = null
var _layers: Dictionary = {}
# Cells this renderer painted, filed by the chunk rect they fall in:
# chunk coord -> {layer key -> {global cell -> true}}. clear_chunk erases
# exactly these instead of every cell of every layer in the rect (a
# 32x32 x layers erase_cell loop on every unload).
var _painted: Dictionary = {}


func configure_host(host: Node2D, cell_size: int) -> void:
	_host = host
	_cell_size = maxi(1, cell_size)
	_ensure_tile_set()


func begin_chunk(chunk: Node2D, cell_size: int) -> void:
	if chunk == null:
		return
	_cell_size = maxi(1, cell_size)
	_ensure_tile_set()
	if not chunk.has_meta(&"_chunk_tile_layer_keys"):
		chunk.set_meta(&"_chunk_tile_layer_keys", {})
		chunk.set_meta(&"_chunk_tile_cells", 0)


func paint_texture(
	chunk: Node2D,
	layer_kind: StringName,
	cell: Vector2i,
	texture: Texture2D,
	z_index: int,
	modulate: Color = Color.WHITE
) -> bool:
	if not enabled or chunk == null or texture == null:
		return false
	begin_chunk(chunk, _cell_size)
	var source_id := _source_for_texture(texture, modulate)
	if source_id < 0:
		return false
	var layer := _layer_for(chunk, layer_kind, z_index, modulate)
	var target_cell := _global_cell(chunk, cell)
	var was_empty := layer.get_cell_source_id(target_cell) < 0
	layer.set_cell(target_cell, source_id, Vector2i.ZERO, 0)
	_note_painted(chunk, layer_kind, z_index, target_cell)
	if was_empty:
		chunk.set_meta(&"_chunk_tile_cells", int(chunk.get_meta(&"_chunk_tile_cells", 0)) + 1)
	return true


func paint_sprite(
	chunk: Node2D,
	layer_kind: StringName,
	cell: Vector2i,
	sprite: Sprite2D,
	z_index: int
) -> bool:
	if not enabled or sprite == null or sprite.texture == null:
		return false
	begin_chunk(chunk, _cell_size)
	var quarter_turns := posmod(roundi(sprite.rotation / (PI * 0.5)), 4)
	var transform_key := "%s:%d:%d:%d:%s" % [
		_texture_key(sprite.texture),
		quarter_turns,
		1 if sprite.flip_h else 0,
		1 if sprite.flip_v else 0,
		sprite.modulate.to_html(),
	]
	var source_id := _source_for_transformed_texture(
		sprite.texture,
		transform_key,
		quarter_turns,
		sprite.flip_h,
		sprite.flip_v,
		sprite.modulate
	)
	if source_id < 0:
		return false
	var layer := _layer_for(chunk, layer_kind, z_index, sprite.modulate)
	var target_cell := _global_cell(chunk, cell)
	var was_empty := layer.get_cell_source_id(target_cell) < 0
	layer.set_cell(target_cell, source_id, Vector2i.ZERO, 0)
	_note_painted(chunk, layer_kind, z_index, target_cell)
	if was_empty:
		chunk.set_meta(&"_chunk_tile_cells", int(chunk.get_meta(&"_chunk_tile_cells", 0)) + 1)
	return true


func paint_transformed_texture(
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
	if not enabled or texture == null:
		return false
	var turns := posmod(quarter_turns, 4)
	var transform_key := "%s:%d:%d:%d:%s" % [
		_texture_key(texture), turns, 1 if flip_h else 0, 1 if flip_v else 0, modulate.to_html(),
	]
	var source_id := _source_for_transformed_texture(texture, transform_key, turns, flip_h, flip_v, modulate)
	if source_id < 0:
		return false
	var layer := _layer_for(chunk, layer_kind, z_index, modulate)
	var target_cell := _global_cell(chunk, cell)
	var was_empty := layer.get_cell_source_id(target_cell) < 0
	layer.set_cell(target_cell, source_id, Vector2i.ZERO, 0)
	_note_painted(chunk, layer_kind, z_index, target_cell)
	if was_empty:
		chunk.set_meta(&"_chunk_tile_cells", int(chunk.get_meta(&"_chunk_tile_cells", 0)) + 1)
	return true


## A decal: `texture` in one of the eight orientations (quarter turns, then
## flips, exactly as paint_transformed_texture bakes them) at the alpha level
## nearest `alpha`. The decal's source is built once (warm_decal); nothing
## here reads the texture or touches the TileSet after that.
func paint_decal(
	chunk: Node2D,
	layer_kind: StringName,
	cell: Vector2i,
	texture: Texture2D,
	z_index: int,
	quarter_turns: int,
	flip_h: bool,
	flip_v: bool,
	alpha: float,
) -> bool:
	if not enabled or chunk == null or texture == null:
		return false
	var source_id := warm_decal(texture)
	if source_id < 0:
		return false
	var layer := _layer_for(chunk, layer_kind, z_index, Color(1.0, 1.0, 1.0, alpha))
	var target_cell := _global_cell(chunk, cell)
	var was_empty := layer.get_cell_source_id(target_cell) < 0
	var orientation := posmod(quarter_turns, 4) * 4 + (2 if flip_h else 0) + (1 if flip_v else 0)
	layer.set_cell(target_cell, source_id, Vector2i.ZERO, decal_alpha_level(alpha) | int(DECAL_TRANSFORMS[orientation]))
	_note_painted(chunk, layer_kind, z_index, target_cell)
	if was_empty:
		chunk.set_meta(&"_chunk_tile_cells", int(chunk.get_meta(&"_chunk_tile_cells", 0)) + 1)
	return true


## The alternative tile (= level index) whose alpha is nearest `alpha`.
static func decal_alpha_level(alpha: float) -> int:
	var best := 0
	for level in range(1, DECAL_ALPHA_LEVELS.size()):
		if absf(float(DECAL_ALPHA_LEVELS[level]) - alpha) < absf(float(DECAL_ALPHA_LEVELS[best]) - alpha):
			best = level
	return best


## Builds (once) the decal source for `texture` and returns its id, -1 when
## the texture has no readable image (the headless dummy renderer).
## ChunkManager calls it for every decal texture while the segment builds.
func warm_decal(texture: Texture2D) -> int:
	if texture == null:
		return -1
	_ensure_tile_set()
	var key := "decal:%s" % _texture_key(texture)
	var cached: Variant = _source_by_texture.get(key)
	if cached != null:
		return int(cached)
	var image := texture.get_image()
	if image == null or image.is_empty():
		return -1
	image = image.duplicate()
	if image.get_width() != _cell_size or image.get_height() != _cell_size:
		image.resize(_cell_size, _cell_size, Image.INTERPOLATE_LANCZOS)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(_cell_size, _cell_size)
	source.create_tile(Vector2i.ZERO)
	for level in range(DECAL_ALPHA_LEVELS.size()):
		var alternative := 0 if level == 0 else source.create_alternative_tile(Vector2i.ZERO, level)
		source.get_tile_data(Vector2i.ZERO, alternative).modulate = Color(1.0, 1.0, 1.0, float(DECAL_ALPHA_LEVELS[level]))
	var source_id := _tile_set.add_source(source)
	_source_by_texture[key] = source_id
	return source_id


func paint_repeating_rect(
	chunk: Node2D,
	layer_kind: StringName,
	rect: Rect2i,
	texture: Texture2D,
	repeat_world_px: int,
	z_index: int,
	modulate: Color = Color.WHITE
) -> int:
	if not enabled or chunk == null or texture == null or rect.size.x <= 0 or rect.size.y <= 0:
		return 0
	begin_chunk(chunk, _cell_size)
	var repeat_px := maxi(_cell_size, repeat_world_px)
	repeat_px = maxi(_cell_size, int(round(float(repeat_px) / float(_cell_size))) * _cell_size)
	var period_cells := maxi(1, floori(float(repeat_px) / float(_cell_size)))
	var source_id := _source_for_repeating_texture(texture, repeat_px, modulate)
	if source_id < 0:
		return 0
	var layer := _layer_for(chunk, layer_kind, z_index, modulate)
	var chunk_coord := chunk.get_meta(&"_chunk_tile_coord", Vector2i.ZERO) as Vector2i
	var cells_per_chunk := int(chunk.get_meta(&"_chunk_cells_per_side", 0))
	var painted := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var global_cell := cell + chunk_coord * cells_per_chunk
			var atlas := Vector2i(posmod(global_cell.x, period_cells), posmod(global_cell.y, period_cells))
			var was_empty := layer.get_cell_source_id(global_cell) < 0
			layer.set_cell(global_cell, source_id, atlas, 0)
			_note_painted(chunk, layer_kind, z_index, global_cell)
			if was_empty:
				painted += 1
	if painted > 0:
		chunk.set_meta(&"_chunk_tile_cells", int(chunk.get_meta(&"_chunk_tile_cells", 0)) + painted)
	return painted


func get_chunk_stats(chunk: Node2D) -> Dictionary:
	if chunk == null:
		return {"layers": 0, "cells": 0}
	return {
		"layers": (chunk.get_meta(&"_chunk_tile_layer_keys", {}) as Dictionary).size(),
		"cells": int(chunk.get_meta(&"_chunk_tile_cells", 0)),
	}


func get_layer_count() -> int:
	return _layers.size()


func erase_cell(chunk: Node2D, layer_kind: StringName, cell: Vector2i) -> bool:
	if chunk == null:
		return false
	var target_cell := _global_cell(chunk, cell)
	var erased := false
	for key_variant in _layers.keys():
		var key := String(key_variant)
		if not key.begins_with(String(layer_kind) + ":"):
			continue
		var layer := _layers[key_variant] as TileMapLayer
		if layer != null and layer.get_cell_source_id(target_cell) >= 0:
			layer.erase_cell(target_cell)
			_forget_painted(chunk, key, target_cell)
			erased = true
	if erased:
		chunk.set_meta(&"_chunk_tile_cells", maxi(0, int(chunk.get_meta(&"_chunk_tile_cells", 0)) - 1))
	return erased


func clear_chunk(chunk: Node2D) -> void:
	if chunk == null:
		return
	var coord := chunk.get_meta(&"_chunk_tile_coord", Vector2i.ZERO) as Vector2i
	var side := int(chunk.get_meta(&"_chunk_cells_per_side", 0))
	if side <= 0:
		return
	# Every non-empty cell of the chunk's rect was painted here and filed
	# under this coord; erasing the rest of the rect only re-checked empties.
	var by_layer_variant: Variant = _painted.get(coord)
	if by_layer_variant == null:
		return
	var by_layer := by_layer_variant as Dictionary
	for layer_key in by_layer:
		var layer := _layers.get(layer_key) as TileMapLayer
		if layer == null:
			continue
		for cell in (by_layer[layer_key] as Dictionary):
			layer.erase_cell(cell)
	_painted.erase(coord)


func clear_all() -> void:
	for layer_variant in _layers.values():
		var layer := layer_variant as TileMapLayer
		if layer != null:
			layer.clear()
	_painted.clear()


func _ensure_tile_set() -> void:
	if _tile_set != null and _tile_set.tile_size == Vector2i(_cell_size, _cell_size):
		return
	_tile_set = TileSet.new()
	_tile_set.tile_size = Vector2i(_cell_size, _cell_size)
	_source_by_texture.clear()


func _source_for_texture(texture: Texture2D, modulate: Color = Color.WHITE) -> int:
	var key := "%s:%s" % [_texture_key(texture), modulate.to_html()]
	return _source_for_transformed_texture(texture, key, 0, false, false, modulate)


func _source_for_transformed_texture(
	texture: Texture2D,
	key: Variant,
	quarter_turns: int,
	flip_h: bool,
	flip_v: bool,
	modulate: Color
) -> int:
	_ensure_tile_set()
	if _source_by_texture.has(key):
		return int(_source_by_texture[key])
	var image := texture.get_image()
	if image == null or image.is_empty():
		return -1
	image = image.duplicate()
	if flip_h:
		image.flip_x()
	if flip_v:
		image.flip_y()
	for _turn in range(quarter_turns):
		image.rotate_90(CLOCKWISE)
	if image.get_width() != _cell_size or image.get_height() != _cell_size:
		image.resize(_cell_size, _cell_size, Image.INTERPOLATE_LANCZOS)
	var tile_texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = tile_texture
	source.texture_region_size = Vector2i(_cell_size, _cell_size)
	source.create_tile(Vector2i.ZERO)
	source.get_tile_data(Vector2i.ZERO, 0).modulate = modulate
	var source_id := _tile_set.add_source(source)
	_source_by_texture[key] = source_id
	return source_id


func _source_for_repeating_texture(texture: Texture2D, repeat_px: int, modulate: Color) -> int:
	_ensure_tile_set()
	var key := "repeat:%s:%d:%s" % [_texture_key(texture), repeat_px, modulate.to_html()]
	if _source_by_texture.has(key):
		return int(_source_by_texture[key])
	var image := texture.get_image()
	if image == null or image.is_empty():
		return -1
	image = image.duplicate()
	if image.get_width() != repeat_px or image.get_height() != repeat_px:
		image.resize(repeat_px, repeat_px, Image.INTERPOLATE_LANCZOS)
	var tile_texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = tile_texture
	source.texture_region_size = Vector2i(_cell_size, _cell_size)
	var period_cells := maxi(1, floori(float(repeat_px) / float(_cell_size)))
	for y in range(period_cells):
		for x in range(period_cells):
			var atlas := Vector2i(x, y)
			source.create_tile(atlas)
			source.get_tile_data(atlas, 0).modulate = modulate
	var source_id := _tile_set.add_source(source)
	_source_by_texture[key] = source_id
	return source_id


func _texture_key(texture: Texture2D) -> String:
	return texture.resource_path if not texture.resource_path.is_empty() else "instance:%d" % texture.get_instance_id()


func _layer_for(
	chunk: Node2D,
	layer_kind: StringName,
	z_index: int,
	modulate: Color
) -> TileMapLayer:
	var key := "%s:%d" % [String(layer_kind), z_index]
	if _layers.has(key):
		_register_chunk_layer(chunk, key)
		return _layers[key] as TileMapLayer
	var layer := TileMapLayer.new()
	layer.name = "WorldTiles_%s_%d" % [String(layer_kind), absi(z_index)]
	layer.tile_set = _tile_set
	layer.z_index = z_index
	layer.modulate = Color.WHITE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var host := _host if _host != null and is_instance_valid(_host) else chunk
	host.add_child(layer)
	_layers[key] = layer
	_register_chunk_layer(chunk, key)
	return layer


func _register_chunk_layer(chunk: Node2D, key: String) -> void:
	var keys := chunk.get_meta(&"_chunk_tile_layer_keys", {}) as Dictionary
	keys[key] = true
	chunk.set_meta(&"_chunk_tile_layer_keys", keys)


func _global_cell(chunk: Node2D, local_cell: Vector2i) -> Vector2i:
	var coord := chunk.get_meta(&"_chunk_tile_coord", Vector2i.ZERO) as Vector2i
	var side := int(chunk.get_meta(&"_chunk_cells_per_side", 0))
	return local_cell + coord * side


func _note_painted(chunk: Node2D, layer_kind: StringName, z_index: int, global_cell: Vector2i) -> void:
	var side := int(chunk.get_meta(&"_chunk_cells_per_side", 0))
	if side <= 0:
		return
	var coord := Vector2i(floori(float(global_cell.x) / float(side)), floori(float(global_cell.y) / float(side)))
	var by_layer_variant: Variant = _painted.get(coord)
	var by_layer: Dictionary
	if by_layer_variant == null:
		by_layer = {}
		_painted[coord] = by_layer
	else:
		by_layer = by_layer_variant
	var layer_key := "%s:%d" % [String(layer_kind), z_index]
	var cells_variant: Variant = by_layer.get(layer_key)
	var cells: Dictionary
	if cells_variant == null:
		cells = {}
		by_layer[layer_key] = cells
	else:
		cells = cells_variant
	cells[global_cell] = true


func _forget_painted(chunk: Node2D, layer_key: String, global_cell: Vector2i) -> void:
	var side := int(chunk.get_meta(&"_chunk_cells_per_side", 0))
	if side <= 0:
		return
	var coord := Vector2i(floori(float(global_cell.x) / float(side)), floori(float(global_cell.y) / float(side)))
	var by_layer_variant: Variant = _painted.get(coord)
	if by_layer_variant == null:
		return
	var cells_variant: Variant = (by_layer_variant as Dictionary).get(layer_key)
	if cells_variant != null:
		(cells_variant as Dictionary).erase(global_cell)
