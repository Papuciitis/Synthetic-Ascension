extends RefCounted
class_name ChunkTileRenderer

## Runtime tile renderer for repeated procedural-world artwork.
## Collision scenes and navigation data remain owned by ChunkManager.

var enabled := true

var _cell_size := 64
var _tile_set: TileSet = null
var _source_by_texture: Dictionary = {}
var _host: Node2D = null
var _layers: Dictionary = {}


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
	if was_empty:
		chunk.set_meta(&"_chunk_tile_cells", int(chunk.get_meta(&"_chunk_tile_cells", 0)) + 1)
	return true


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
	var rect := Rect2i(coord * side, Vector2i(side, side))
	for layer_variant in _layers.values():
		var layer := layer_variant as TileMapLayer
		if layer == null:
			continue
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				layer.erase_cell(Vector2i(x, y))


func clear_all() -> void:
	for layer_variant in _layers.values():
		var layer := layer_variant as TileMapLayer
		if layer != null:
			layer.clear()


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
