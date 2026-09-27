extends RefCounted
class_name ChunkBlockRenderer

const VISUAL_SCALE := Vector2(0.0625, 0.0625)
const SHADOW_OFFSET := Vector2(2.0, 3.0)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)
## Three-quarter walls cast a longer shadow away from the light (top right),
## like the reference; low props keep the short contact shadow.
const WALL_SHADOW_OFFSET := Vector2(-9.0, 7.0)
const WALL_SHADOW_COLOR := Color(0.02, 0.02, 0.04, 0.42)
## Shallow depth (Phase 3): caps lift slightly north and an exposed south
## edge hangs a stone face under the cap band (the art occupies the middle
## ~24 px of the cell, so the face sits at the band's foot, inside the cell).
const CAP_LIFT := Vector2(0.0, -6.0)
const FACE_OFFSET := Vector2(0.0, 17.0)
static var depth_faces_enabled := true

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
	## Faces are pure depth dressing: no drop shadow of their own.
	var shadowless := false

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
	# key -> instance count BEFORE this chunk appended anything, so the upload
	# below can write only the new tail. _sync_batch used to rewrite every
	# instance in the batch on every activation, so loading chunk 25 re-uploaded
	# all twenty-five chunks' transforms - quadratic in the number of live
	# chunks, for an append.
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
		var wall_like := kind == WorldBlockerGeometry.Kind.WALL or kind == WorldBlockerGeometry.Kind.WINDOW
		var kit := wall_like and ChunkBlockVisualCatalog.three_quarter_walls
		var batch := _get_or_create_batch(key, texture, false, kit)
		if not touched.has(key):
			touched[key] = batch.transforms.size()
		var world_center := chunk_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * float(_cell_size)
		var scale := ChunkBlockVisualCatalog.cell_scale(texture, float(_cell_size))
		if kit:
			# QuadMesh is authored Y-up (3D), so in 2D its texture draws upside
			# down; the kit pieces are not vertically symmetric.
			var flipped := Vector2(scale.x, -scale.y)
			var at := world_center + ChunkBlockVisualCatalog.wall_offset()
			batch.transforms.append(Transform2D(0.0, at).scaled_local(flipped))
			batch.shadow_transforms.append(Transform2D(0.0, at + WALL_SHADOW_OFFSET).scaled_local(flipped))
			batch.owners.append(data.coord)
			_add_corner_fills(data, cell, world_center, touched)
			continue
		var lift := Vector2.ZERO
		if depth_faces_enabled and kind != WorldBlockerGeometry.Kind.HALF_COVER:
			lift = CAP_LIFT
		var transform := Transform2D(rotation, world_center + lift).scaled_local(scale)
		var shadow_transform := Transform2D(rotation, world_center + SHADOW_OFFSET).scaled_local(scale)
		batch.transforms.append(transform)
		batch.shadow_transforms.append(shadow_transform)
		batch.owners.append(data.coord)
		if depth_faces_enabled:
			var face := ChunkBlockVisualCatalog.face_texture(kind, data.mask_at(cell))
			if face != null:
				var face_key := _texture_key(face)
				var face_batch := _get_or_create_batch(face_key, face, true)
				if not touched.has(face_key):
					touched[face_key] = face_batch.transforms.size()
				face_batch.transforms.append(Transform2D(0.0, world_center + lift + FACE_OFFSET).scaled_local(VISUAL_SCALE))
				face_batch.shadow_transforms.append(Transform2D())
				face_batch.owners.append(data.coord)
	for key in touched:
		_sync_batch(_batches[key] as TextureBatch, int(touched[key]))


## Solid blocks of wall cells: fill the open corner between two arms where
## the diagonal neighbour is wall too (within the chunk).
func _add_corner_fills(data: ChunkBuildData, cell: Vector2i, world_center: Vector2, touched: Dictionary) -> void:
	var mask := data.mask_at(cell)
	for fill in ChunkBlockVisualCatalog.KIT_FILLS:
		var bits := int(fill[0])
		if (mask & bits) != bits:
			continue
		var diagonal: Vector2i = fill[1]
		var neighbour := data.kind_at(cell + diagonal)
		if neighbour != WorldBlockerGeometry.Kind.WALL and neighbour != WorldBlockerGeometry.Kind.WINDOW:
			continue
		var texture: Texture2D = fill[2]
		var key := _texture_key(texture)
		var batch := _get_or_create_batch(key, texture, true, false, ChunkBlockVisualCatalog.FILL_Z)
		if not touched.has(key):
			touched[key] = batch.transforms.size()
		var at := world_center + ChunkBlockVisualCatalog.fill_offset(diagonal)
		var fill_scale := ChunkBlockVisualCatalog.cell_scale(texture, 16.0)
		batch.transforms.append(Transform2D(0.0, at).scaled_local(Vector2(fill_scale.x, -fill_scale.y)))
		batch.shadow_transforms.append(Transform2D())
		batch.owners.append(data.coord)


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
	var face_instances := 0
	var fill_instances := 0
	var batch_nodes := 0
	for batch_value in _batches.values():
		var batch := batch_value as TextureBatch
		if batch.shadowless and batch.texture.resource_path.get_file().begins_with("wall34_fill"):
			fill_instances += batch.visual_mesh.visible_instance_count
		elif batch.shadowless:
			face_instances += batch.visual_mesh.visible_instance_count
		else:
			instances += batch.visual_mesh.visible_instance_count
		shadow_instances += batch.shadow_mesh.visible_instance_count
		batch_nodes += 2
	return {
		"batches": batch_nodes,
		"instances": instances,
		"shadow_instances": shadow_instances,
		"face_instances": face_instances,
		"fill_instances": fill_instances,
		"runtime_images_created": 0,
	}


func _get_or_create_batch(key: String, texture: Texture2D, shadowless: bool = false, wall_shadow: bool = false, z: int = ChunkBlockVisualCatalog.WALL_Z) -> TextureBatch:
	if _batches.has(key):
		return _batches[key] as TextureBatch
	var batch := TextureBatch.new()
	batch.texture = texture
	batch.shadowless = shadowless
	batch.visual_mesh = _new_multimesh(texture)
	batch.shadow_mesh = _new_multimesh(texture)
	batch.visual = _new_instance("BlockVisual_%s" % _safe_name(key), texture, batch.visual_mesh)
	batch.shadow = _new_instance("BlockShadow_%s" % _safe_name(key), texture, batch.shadow_mesh)
	batch.shadow.self_modulate = WALL_SHADOW_COLOR if wall_shadow else SHADOW_COLOR
	batch.visual.z_index = z
	batch.shadow.z_index = z - 1
	batch.shadow.visible = not shadowless
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


## `from_index` is the first instance that actually changed. Appends pass the
## pre-append count; anything that compacts the arrays (remove_chunk) must pass
## 0, because every index after the removal has shifted.
func _sync_batch(batch: TextureBatch, from_index: int = 0) -> void:
	var count := batch.transforms.size()
	if count > batch.capacity:
		batch.capacity = maxi(1, batch.capacity)
		while batch.capacity < count:
			batch.capacity *= 2
		batch.visual_mesh.instance_count = batch.capacity
		batch.shadow_mesh.instance_count = batch.capacity
		# Growing reallocates the MultiMesh, so every instance has to be
		# rewritten regardless of what the caller asked for.
		from_index = 0
	for index in range(clampi(from_index, 0, count), count):
		batch.visual_mesh.set_instance_transform_2d(index, batch.transforms[index])
		if not batch.shadowless:
			batch.shadow_mesh.set_instance_transform_2d(index, batch.shadow_transforms[index])
	batch.visual_mesh.visible_instance_count = count
	batch.shadow_mesh.visible_instance_count = 0 if batch.shadowless else count


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
