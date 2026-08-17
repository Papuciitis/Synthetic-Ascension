extends RefCounted
class_name ChunkBlockRenderer

const VISUAL_SCALE := Vector2(0.0625, 0.0625)
const SHADOW_OFFSET := Vector2(2.0, 3.0)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)

class TextureBatch extends RefCounted:
	var texture: Texture2D
	var visual: MultiMeshInstance2D
	var shadow: MultiMeshInstance2D
	var visual_mesh: MultiMesh
	var shadow_mesh: MultiMesh
	var transforms: Array[Transform2D] = []
	var shadow_transforms: Array[Transform2D] = []
	var owners: Array[Vector2i] = []
	var capacity := 0

var _host: Node2D
var _chunk_size := 2048
var _cell_size := 64
var _batches: Dictionary = {}


func configure(host: Node2D, chunk_size: int, cell_size: int) -> void:
	if _host != host:
		clear()
	_host = host
	_chunk_size = maxi(1, chunk_size)
	_cell_size = maxi(1, cell_size)


func add_chunk(data: ChunkBuildData) -> void:
	if not is_instance_valid(_host):
		return
	remove_chunk(data.coord)
	var chunk_origin := Vector2(data.coord) * float(_chunk_size)
	var touched: Dictionary = {}
	for occupied_index in data.occupied_indices():
		var cell := data.cell_for_index(occupied_index)
		var kind := data.kind_at(cell)
		var texture: Texture2D
		var rotation := 0.0
		if kind == WorldBlockerGeometry.Kind.HALF_COVER:
			var variant := data.variant_at(cell)
			texture = ChunkBlockVisualCatalog.half_texture(variant)
			rotation = ChunkBlockVisualCatalog.half_rotation(variant)
		else:
			texture = ChunkBlockVisualCatalog.wall_texture(kind, data.mask_at(cell))
		if texture == null:
			continue
		var key := _texture_key(texture)
		var batch := _get_or_create_batch(key, texture)
		var world_center := chunk_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * float(_cell_size)
		var transform := Transform2D(rotation, world_center).scaled_local(VISUAL_SCALE)
		var shadow_transform := Transform2D(rotation, world_center + SHADOW_OFFSET).scaled_local(VISUAL_SCALE)
		batch.transforms.append(transform)
		batch.shadow_transforms.append(shadow_transform)
		batch.owners.append(data.coord)
		touched[key] = true
	for key in touched:
		_sync_batch(_batches[key] as TextureBatch)


func remove_chunk(coord: Vector2i) -> void:
	var empty_keys: Array[String] = []
	for key_value in _batches.keys():
		var key := String(key_value)
		var batch := _batches[key] as TextureBatch
		var changed := false
		for index in range(batch.owners.size() - 1, -1, -1):
			if batch.owners[index] != coord:
				continue
			var last := batch.owners.size() - 1
			if index != last:
				batch.owners[index] = batch.owners[last]
				batch.transforms[index] = batch.transforms[last]
				batch.shadow_transforms[index] = batch.shadow_transforms[last]
			batch.owners.pop_back()
			batch.transforms.pop_back()
			batch.shadow_transforms.pop_back()
			changed = true
		if not changed:
			continue
		if batch.owners.is_empty():
			empty_keys.append(key)
		else:
			_sync_batch(batch)
	for key in empty_keys:
		_destroy_batch(_batches[key] as TextureBatch)
		_batches.erase(key)


func clear() -> void:
	for batch_value in _batches.values():
		_destroy_batch(batch_value as TextureBatch)
	_batches.clear()


func get_stats() -> Dictionary:
	var instances := 0
	var shadow_instances := 0
	var batch_nodes := 0
	for batch_value in _batches.values():
		var batch := batch_value as TextureBatch
		instances += batch.visual_mesh.visible_instance_count
		shadow_instances += batch.shadow_mesh.visible_instance_count
		batch_nodes += 2
	return {
		"batches": batch_nodes,
		"instances": instances,
		"shadow_instances": shadow_instances,
		"runtime_images_created": 0,
	}


func _get_or_create_batch(key: String, texture: Texture2D) -> TextureBatch:
	if _batches.has(key):
		return _batches[key] as TextureBatch
	var batch := TextureBatch.new()
	batch.texture = texture
	batch.visual_mesh = _new_multimesh(texture)
	batch.shadow_mesh = _new_multimesh(texture)
	batch.visual = _new_instance("BlockVisual_%s" % _safe_name(key), texture, batch.visual_mesh)
	batch.shadow = _new_instance("BlockShadow_%s" % _safe_name(key), texture, batch.shadow_mesh)
	batch.shadow.self_modulate = SHADOW_COLOR
	batch.shadow.z_index = -1
	_host.add_child(batch.shadow)
	_host.add_child(batch.visual)
	_batches[key] = batch
	return batch


func _new_multimesh(texture: Texture2D) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(texture.get_size())
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = quad
	multimesh.instance_count = 0
	multimesh.visible_instance_count = 0
	return multimesh


func _new_instance(node_name: String, texture: Texture2D, multimesh: MultiMesh) -> MultiMeshInstance2D:
	var instance := MultiMeshInstance2D.new()
	instance.name = node_name
	instance.texture = texture
	instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	instance.multimesh = multimesh
	return instance


func _sync_batch(batch: TextureBatch) -> void:
	var count := batch.transforms.size()
	if count > batch.capacity:
		batch.capacity = maxi(1, batch.capacity)
		while batch.capacity < count:
			batch.capacity *= 2
		batch.visual_mesh.instance_count = batch.capacity
		batch.shadow_mesh.instance_count = batch.capacity
	for index in count:
		batch.visual_mesh.set_instance_transform_2d(index, batch.transforms[index])
		batch.shadow_mesh.set_instance_transform_2d(index, batch.shadow_transforms[index])
	batch.visual_mesh.visible_instance_count = count
	batch.shadow_mesh.visible_instance_count = count


func _destroy_batch(batch: TextureBatch) -> void:
	for node in [batch.visual, batch.shadow]:
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()


static func _texture_key(texture: Texture2D) -> String:
	if not texture.resource_path.is_empty():
		return texture.resource_path
	return "texture_%d" % texture.get_instance_id()


static func _safe_name(key: String) -> String:
	return key.get_file().get_basename().validate_node_name()
