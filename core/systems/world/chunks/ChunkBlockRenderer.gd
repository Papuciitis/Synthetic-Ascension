extends RefCounted
class_name ChunkBlockRenderer

const VISUAL_SCALE := Vector2(0.0625, 0.0625)
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const MATERIALS := preload("res://core/systems/world/WorldDressingMaterials.gd")
const CITY_STONE := preload("res://scenes/world/buildings/city_stone.gdshader")
const DOMESTIC_STONE := preload("res://scenes/world/buildings/domestic_stone.gdshader")
const PLAZA_EDGE := preload("res://core/systems/world/chunks/PlazaEdgeKit.gd")
const SHADOW_OFFSET := DEPTH.SHADOW_DIRECTION * 8.0
## Alpha-blend colours kept for authored cover (WorldCoverVisuals/CoverWall).
## Batched chunk shadows below use the shared multiplicative sun shade.
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)
## Three-quarter walls cast their full kit height away from the light (top
## right), the same rule as every other caster; low props keep the short
## contact shadow.
const WALL_SHADOW_OFFSET := DEPTH.SHADOW_DIRECTION * ChunkBlockVisualCatalog.KIT_HEIGHT
const WALL_SHADOW_COLOR := Color(0.02, 0.02, 0.04, 0.42)
## The authored Institution (S1, Level1Builder) keeps its reviewed wall
## shadow; the shared city light below applies to procedural segments.
const LEGACY_WALL_SHADOW_OFFSET := Vector2(-9.0, 7.0)
## Share of the sun shade under a wall-kit silhouette and a plain prop.
const WALL_SHADE := 0.92
const PROP_SHADE := 0.85
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
var _city_material: ShaderMaterial
var _domestic_material: ShaderMaterial
var _contact_by_chunk: Dictionary = {}

func _city_stone_material() -> ShaderMaterial:
	if _city_material == null:
		_city_material = ShaderMaterial.new()
		_city_material.shader = CITY_STONE
		# Pale dressed ashlar keeps the kit's baked relief in every segment.
		_city_material.set_shader_parameter("source_relief", 1.0)
	return _city_material


func _domestic_stone_material() -> ShaderMaterial:
	if _domestic_material == null:
		_domestic_material = ShaderMaterial.new()
		_domestic_material.shader = DOMESTIC_STONE
	return _domestic_material


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
	var city_light := _city_light()
	for occupied_index in data.occupied_indices():
		var cell := data.cell_for_index(occupied_index)
		var kind := data.kind_at(cell)
		var texture: Texture2D
		var rotation := 0.0
		# Plaza ring cells draw as low edges (PlazaEdgeKit).
		var plaza_edge := PLAZA_EDGE.owns(kind, data.variant_at(cell))
		if kind == WorldBlockerGeometry.Kind.HALF_COVER:
			var variant := data.variant_at(cell)
			if (variant & ChunkBlockVisualCatalog.VARIANT_FURNITURE_ART) != 0:
				continue
			texture = ChunkBlockVisualCatalog.half_texture(variant)
			rotation = ChunkBlockVisualCatalog.half_rotation(variant)
		elif plaza_edge:
			texture = PLAZA_EDGE.texture_for(data, cell)
		else:
			var global_cell := data.coord * data.cells_per_side + cell
			texture = ChunkBlockVisualCatalog.wall_texture_at(kind, data.mask_at(cell), global_cell, data.variant_at(cell))
		if texture == null:
			continue
		var key := _texture_key(texture)
		var wall_like := kind == WorldBlockerGeometry.Kind.WALL or kind == WorldBlockerGeometry.Kind.WINDOW
		var kit := wall_like and (ChunkBlockVisualCatalog.three_quarter_walls or plaza_edge)
		var under_roof := kit and (data.variant_at(cell) & ChunkBlockVisualCatalog.VARIANT_UNDER_ROOF) != 0
		var z := ChunkBlockVisualCatalog.PROP_Z if kind == WorldBlockerGeometry.Kind.HALF_COVER or under_roof else ChunkBlockVisualCatalog.WALL_Z
		if under_roof:
			key += "#under_roof"
		if not city_light:
			key += "#authored"
		var city_stone := wall_like and (data.variant_at(cell) & ChunkBlockVisualCatalog.VARIANT_CITY_STONE) != 0
		if city_stone:
			key += "#city_stone"
		var domestic_stone := wall_like and (data.variant_at(cell) & ChunkBlockVisualCatalog.VARIANT_DOMESTIC_STONE) != 0
		if domestic_stone:
			key += "#domestic_stone"
		# Materials are keyed by masonry family, never by segment: every city
		# segment shares the pale ashlar relief and domestic homes their warm
		# rubble, so streamed loads cannot swap a surviving owner's material.
		var batch := _get_or_create_batch(key, texture, false, kit, z, city_light)
		if domestic_stone:
			batch.visual.material = _domestic_stone_material()
		elif city_stone:
			batch.visual.material = _city_stone_material()
		if not touched.has(key):
			touched[key] = batch.transforms.size()
		var world_center := chunk_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * float(_cell_size)
		var scale := ChunkBlockVisualCatalog.cell_scale(texture, float(_cell_size))
		if kind == WorldBlockerGeometry.Kind.HALF_COVER and texture is AtlasTexture:
			# Painted three-quarter props stand on the same blocked cell. Keep
			# their width, source aspect and baked light direction intact.
			var at := world_center - Vector2(0, float(texture.get_height()) * scale.y * 0.5)
			var prop_transform := Transform2D(0.0, at).scaled_local(Vector2(scale.x, -scale.y))
			batch.transforms.append(prop_transform)
			batch.shadow_transforms.append(DEPTH.project_transform(prop_transform, world_center))
			batch.owners.append(data.coord)
			continue
		if kit:
			# QuadMesh is authored Y-up (3D), so in 2D its texture draws upside
			# down; the kit pieces are not vertically symmetric.
			var flipped := Vector2(scale.x, -scale.y)
			var at := world_center + ChunkBlockVisualCatalog.KIT_OFFSET
			var shadow_offset := PLAZA_EDGE.SHADOW_OFFSET if plaza_edge else WALL_SHADOW_OFFSET
			batch.transforms.append(Transform2D(0.0, at).scaled_local(flipped))
			# A building envelope's kit or DonJon owns its soft cast and wall
			# contact; a second hard silhouette there would darken twice.
			var owned := (data.variant_at(cell) & (ChunkBlockVisualCatalog.VARIANT_BUILDING_ENVELOPE | ChunkBlockVisualCatalog.VARIANT_CITY_STONE)) == (ChunkBlockVisualCatalog.VARIANT_BUILDING_ENVELOPE | ChunkBlockVisualCatalog.VARIANT_CITY_STONE) and not under_roof
			var cast_offset := shadow_offset if city_light else LEGACY_WALL_SHADOW_OFFSET
			batch.shadow_transforms.append(Transform2D(0.0, at + cast_offset).scaled_local(Vector2.ZERO if owned and city_light else flipped))
			batch.owners.append(data.coord)
			if plaza_edge:
				_add_plaza_fills(data, cell, world_center, touched)
			else:
				_add_corner_fills(data, cell, world_center, touched, under_roof)
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
	if city_light:
		_add_wall_contact(data, chunk_origin)


## Procedural city segments share the one sun model; the authored S1
## Institution keeps its reviewed wall presentation.
static func _city_light() -> bool:
	return Global.attempt_segment >= 2


## Soft contact where freestanding wall/window cells meet open ground on their
## shaded south and west faces: one multiplicative mesh per chunk. Building
## envelopes draw their own kit contact.
func _add_wall_contact(data: ChunkBuildData, chunk_origin: Vector2) -> void:
	if not ChunkBlockVisualCatalog.three_quarter_walls:
		return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var faces: Array[PackedInt32Array] = []
	var cell_px := float(_cell_size)
	var half := cell_px * 0.5
	var band := cell_px * 0.25
	var south := Vector2(DEPTH.CONTACT_SOUTH_PX, DEPTH.CONTACT_SOUTH * DEPTH.contact_strength * 0.85)
	var west := Vector2(DEPTH.CONTACT_WEST_PX, DEPTH.CONTACT_WEST * DEPTH.contact_strength * 0.85)
	for occupied_index in data.occupied_indices():
		var cell := data.cell_for_index(occupied_index)
		var kind := data.kind_at(cell)
		if kind != WorldBlockerGeometry.Kind.WALL and kind != WorldBlockerGeometry.Kind.WINDOW:
			continue
		var variant := data.variant_at(cell)
		if (variant & ChunkBlockVisualCatalog.VARIANT_UNDER_ROOF) != 0:
			continue
		if (variant & ChunkBlockVisualCatalog.VARIANT_BUILDING_ENVELOPE) != 0 and (variant & ChunkBlockVisualCatalog.VARIANT_CITY_STONE) != 0:
			continue
		var mask := data.mask_at(cell)
		var center := chunk_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_px
		# The kit's wall band is the middle half of the cell; connected arms
		# run on to the cell edge.
		var left := center.x - (half if (mask & WorldBlockerGeometry.W) != 0 else band)
		var right := center.x + (half if (mask & WorldBlockerGeometry.E) != 0 else band)
		var top := center.y - (half if (mask & WorldBlockerGeometry.N) != 0 else band)
		var bottom := center.y + (half if (mask & WorldBlockerGeometry.S) != 0 else band)
		if (mask & WorldBlockerGeometry.S) == 0:
			_contact_face(points, colors, faces, PackedVector2Array([Vector2(left, bottom), Vector2(right, bottom), Vector2(right, bottom + south.x), Vector2(left, bottom + south.x)]), PackedFloat32Array([south.y, south.y, 0.0, 0.0]))
		if (mask & WorldBlockerGeometry.W) == 0:
			var foot := bottom if (mask & WorldBlockerGeometry.S) != 0 else bottom + south.x * 0.5
			_contact_face(points, colors, faces, PackedVector2Array([Vector2(left - west.x, top), Vector2(left, top), Vector2(left, foot), Vector2(left - west.x, foot)]), PackedFloat32Array([0.0, west.y, west.y, 0.0]))
	if faces.is_empty():
		return
	var contact := Polygon2D.new()
	contact.name = "WallContact_%d_%d" % [data.coord.x, data.coord.y]
	contact.polygon = points
	contact.polygons = faces
	contact.vertex_colors = colors
	contact.material = DEPTH.SUN_SHADOW_MATERIAL
	# The shared ground shade layer, like building casts and kit contact.
	DEPTH.place_ground_shade(contact)
	contact.set_meta(&"wall_contact_shade", true)
	_host.add_child(contact)
	_contact_by_chunk[data.coord] = contact


static func _contact_face(points: PackedVector2Array, colors: PackedColorArray, faces: Array[PackedInt32Array], quad: PackedVector2Array, alphas: PackedFloat32Array) -> void:
	var face := PackedInt32Array()
	for index in quad.size():
		face.append(points.size())
		points.append(quad[index])
		colors.append(Color(1, 1, 1, alphas[index]))
	faces.append(face)


## Solid blocks of wall cells: fill the open corner between two arms where
## the diagonal neighbour is wall too (within the chunk).
func _add_corner_fills(data: ChunkBuildData, cell: Vector2i, world_center: Vector2, touched: Dictionary, under_roof: bool = false) -> void:
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
		var city_stone := (data.variant_at(cell) & ChunkBlockVisualCatalog.VARIANT_CITY_STONE) != 0
		var domestic_stone := (data.variant_at(cell) & ChunkBlockVisualCatalog.VARIANT_DOMESTIC_STONE) != 0
		var key := _texture_key(texture) + ("#under_roof" if under_roof else "") + ("#city_stone" if city_stone else "") + ("#domestic_stone" if domestic_stone else "")
		var fill_z := ChunkBlockVisualCatalog.PROP_Z if under_roof else ChunkBlockVisualCatalog.FILL_Z
		var batch := _get_or_create_batch(key, texture, true, false, fill_z)
		if domestic_stone:
			batch.visual.material = _domestic_stone_material()
		elif city_stone:
			batch.visual.material = _city_stone_material()
		if not touched.has(key):
			touched[key] = batch.transforms.size()
		var at := world_center + ChunkBlockVisualCatalog.fill_offset(diagonal)
		var fill_scale := ChunkBlockVisualCatalog.cell_scale(texture, 16.0)
		batch.transforms.append(Transform2D(0.0, at).scaled_local(Vector2(fill_scale.x, -fill_scale.y)))
		batch.shadow_transforms.append(Transform2D())
		batch.owners.append(data.coord)


## Plaza edge blocks (two arms and the diagonal are edge cells of the same
## style) close their open quadrant with the kit's fill, so the block reads as
## one bed or one parapet slab.
func _add_plaza_fills(data: ChunkBuildData, cell: Vector2i, world_center: Vector2, touched: Dictionary) -> void:
	var mask := data.mask_at(cell)
	var variant := data.variant_at(cell)
	for fill in ChunkBlockVisualCatalog.KIT_FILLS:
		var bits := int(fill[0])
		if (mask & bits) != bits:
			continue
		var diagonal: Vector2i = fill[1]
		var neighbour_variant := data.variant_at(cell + diagonal)
		if not PLAZA_EDGE.owns(data.kind_at(cell + diagonal), neighbour_variant) or PLAZA_EDGE.is_balustrade(neighbour_variant) != PLAZA_EDGE.is_balustrade(variant):
			continue
		var texture := PLAZA_EDGE.fill_texture(variant)
		var key := _texture_key(texture)
		var batch := _get_or_create_batch(key, texture, true, false, ChunkBlockVisualCatalog.FILL_Z)
		if not touched.has(key):
			touched[key] = batch.transforms.size()
		var scale := ChunkBlockVisualCatalog.cell_scale(texture, float(texture.get_width()) * 0.5)
		batch.transforms.append(Transform2D(0.0, world_center + PLAZA_EDGE.fill_offset(variant, diagonal)).scaled_local(Vector2(scale.x, -scale.y)))
		batch.shadow_transforms.append(Transform2D())
		batch.owners.append(data.coord)


func remove_chunk(coord: Vector2i) -> void:
	var contact := _contact_by_chunk.get(coord) as Polygon2D
	if contact != null:
		_contact_by_chunk.erase(coord)
		if is_instance_valid(contact):
			if contact.get_parent() != null:
				contact.get_parent().remove_child(contact)
			contact.queue_free()
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
	for contact_value in _contact_by_chunk.values():
		var contact := contact_value as Polygon2D
		if is_instance_valid(contact):
			if contact.get_parent() != null:
				contact.get_parent().remove_child(contact)
			contact.queue_free()
	_contact_by_chunk.clear()


func get_stats() -> Dictionary:
	var instances := 0
	var shadow_instances := 0
	var face_instances := 0
	var fill_instances := 0
	var batch_nodes := 0
	for batch_value in _batches.values():
		var batch := batch_value as TextureBatch
		if batch.shadowless and batch.texture.resource_path.get_file().contains("34_fill"):
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


func _get_or_create_batch(key: String, texture: Texture2D, shadowless: bool = false, wall_shadow: bool = false, z: int = ChunkBlockVisualCatalog.WALL_Z, city_light: bool = true) -> TextureBatch:
	if _batches.has(key):
		return _batches[key] as TextureBatch
	var batch := TextureBatch.new()
	batch.texture = texture
	batch.shadowless = shadowless
	batch.visual_mesh = _new_multimesh(texture)
	batch.shadow_mesh = _new_multimesh(texture)
	batch.visual = _new_instance("BlockVisual_%s" % _safe_name(key), texture, batch.visual_mesh)
	batch.shadow = _new_instance("BlockShadow_%s" % _safe_name(key), texture, batch.shadow_mesh)
	# Silhouettes multiply the ground by the shared sun shade, like buildings.
	batch.shadow.self_modulate = Color(1, 1, 1, WALL_SHADE if wall_shadow else PROP_SHADE)
	batch.shadow.material = DEPTH.SUN_SHADOW_MATERIAL
	if not city_light:
		batch.shadow.self_modulate = WALL_SHADOW_COLOR if wall_shadow else SHADOW_COLOR
		batch.shadow.material = null
	if texture is AtlasTexture:
		batch.shadow.self_modulate = Color.WHITE
		batch.shadow.material = MATERIALS.shadow_material(texture)
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
	instance.texture = MATERIALS.base_texture(texture)
	instance.material = MATERIALS.visual_material(texture)
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
