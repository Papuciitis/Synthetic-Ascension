class_name EnemyProxyRenderer
extends Node2D

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")

const FLOATS_PER_INSTANCE := 12
const DIAGNOSTIC_KEY := &"__diagnostic__"
const DIAGNOSTIC_COLOR := Color(1.0, 0.0, 0.8, 1.0)
const ELITE_DIAGNOSTIC_COLOR := Color(1.0, 0.35, 0.05, 1.0)
const MIN_PROXY_SIZE := 4.0

var _world: EnemyWorldService = null
var _handles: Array[int] = []
var _batches: Dictionary = {}
var _handle_locations: Dictionary = {}
var _visual_profiles: Dictionary = {}
var _diagnostic_texture: ImageTexture = null
var _visible_count := 0
var _last_upload_usec := 0
var _profile_sweep_counter := 0
# Materialized enemies rendered through the same batches: instance id ->
# {actor, sprite, texture, key}. Registration is per node instance; freed
# or pooled actors are pruned/skipped during publish.
var _actors: Dictionary = {}
var _actor_locations: Dictionary = {}


func setup(world: EnemyWorldService) -> void:
	_world = world
	_visible_count = 0
	_last_upload_usec = 0


func register_actor(actor: Node2D, sprite: Sprite2D) -> void:
	if actor == null or sprite == null:
		return
	_actors[actor.get_instance_id()] = {
		"actor": actor,
		"sprite": sprite,
		"texture": null,
		"key": &"",
	}


func unregister_actor(actor: Node2D) -> void:
	if actor != null:
		_actors.erase(actor.get_instance_id())


func registered_actor_count() -> int:
	return _actors.size()


func publish(interpolation_alpha: float = 1.0, include_proxies: bool = true) -> int:
	var started := Time.get_ticks_usec()
	_visible_count = 0
	_handle_locations.clear()
	if _world == null or not is_instance_valid(_world):
		_hide_all_batches()
		_last_upload_usec = Time.get_ticks_usec() - started
		return 0

	var groups: Dictionary = {}
	var group_metadata: Dictionary = {}
	if not include_proxies:
		# Proxy batches keep last frame's buffers this frame (half-rate under
		# load); count their instances so visible_count stays truthful.
		for batch_key_variant in _batches:
			if not String(batch_key_variant).begins_with("actor:"):
				_visible_count += int((_batches[batch_key_variant] as Dictionary).get("last_count", 0))
	_world.active_handles(_handles)
	for handle in _handles:
		if not include_proxies:
			break
		if (
			not _world.is_valid_handle(handle)
			or _world.is_dying(handle)
			or _world.get_representation(handle) != Types.Representation.DATA_ONLY
		):
			continue
		var profile := _profile_for(handle)
		var visual_key := profile.get("key", DIAGNOSTIC_KEY) as StringName
		if not groups.has(visual_key):
			groups[visual_key] = [] as Array[int]
			group_metadata[visual_key] = profile
		var group := groups[visual_key] as Array[int]
		group.append(handle)

	var actor_groups: Dictionary = {}
	var actor_metadata: Dictionary = {}
	var dead_actor_ids: Array = []
	for actor_id_variant in _actors:
		var entry := _actors[actor_id_variant] as Dictionary
		var actor_variant: Variant = entry.get("actor")
		var sprite_variant: Variant = entry.get("sprite")
		# Validity must be checked on the raw Variant: casting a freed object
		# is itself a script error.
		if not is_instance_valid(actor_variant) or not is_instance_valid(sprite_variant):
			dead_actor_ids.append(actor_id_variant)
			continue
		var actor := actor_variant as Node2D
		var sprite := sprite_variant as Sprite2D
		if (
			not actor.is_inside_tree()
			or not actor.visible
			or bool(actor.get_meta("__in_pool", false))
			or ("dead" in actor and bool(actor.get("dead")))
			or sprite.texture == null
		):
			continue
		if entry.get("texture") != sprite.texture:
			entry["texture"] = sprite.texture
			entry["key"] = StringName("actor:" + sprite.texture.resource_path)
		var actor_key := entry.get("key") as StringName
		if not actor_groups.has(actor_key):
			actor_groups[actor_key] = [] as Array[Dictionary]
			actor_metadata[actor_key] = {"key": actor_key, "texture": sprite.texture, "z_index": 0}
		(actor_groups[actor_key] as Array[Dictionary]).append(entry)
	for dead_id in dead_actor_ids:
		_actors.erase(dead_id)

	var seen: Dictionary = {}
	if not include_proxies:
		for batch_key_variant in _batches:
			if not String(batch_key_variant).begins_with("actor:"):
				seen[batch_key_variant] = true
	for visual_key_variant in groups:
		var visual_key := visual_key_variant as StringName
		seen[visual_key] = true
		var batch := _batch_for(visual_key, group_metadata[visual_key] as Dictionary)
		_publish_batch(
			visual_key,
			batch,
			groups[visual_key] as Array[int],
			clampf(interpolation_alpha, 0.0, 1.0),
		)
	_actor_locations.clear()
	for actor_key_variant in actor_groups:
		var actor_key := actor_key_variant as StringName
		seen[actor_key] = true
		var actor_batch := _batch_for(actor_key, actor_metadata[actor_key] as Dictionary)
		_publish_actor_batch(actor_key, actor_batch, actor_groups[actor_key] as Array[Dictionary])
	for visual_key_variant in _batches:
		if not seen.has(visual_key_variant):
			_hide_batch(_batches[visual_key_variant] as Dictionary)
	_profile_sweep_counter += 1
	if _profile_sweep_counter >= 60:
		_sweep_stale_profiles()
		_profile_sweep_counter = 0

	_last_upload_usec = Time.get_ticks_usec() - started
	return _visible_count


func visible_count() -> int:
	return _visible_count


func batch_count() -> int:
	return _batches.size()


func has_visible_handle(handle: int) -> bool:
	return _handle_locations.has(handle)


func last_upload_usec() -> int:
	return _last_upload_usec


func invalidate_visual_profile(handle: int) -> void:
	_visual_profiles.erase(handle)


func debug_instance_transform(handle: int) -> Transform2D:
	var location_variant: Variant = _handle_locations.get(handle)
	if not (location_variant is Dictionary):
		return Transform2D()
	var location := location_variant as Dictionary
	var batch_variant: Variant = _batches.get(location.get("key", DIAGNOSTIC_KEY))
	if not (batch_variant is Dictionary):
		return Transform2D()
	var transforms := (batch_variant as Dictionary).get("transforms", []) as Array[Transform2D]
	var index := int(location.get("index", -1))
	if index < 0 or index >= transforms.size():
		return Transform2D()
	return transforms[index]


func debug_instance_color(handle: int) -> Color:
	var location_variant: Variant = _handle_locations.get(handle)
	if not (location_variant is Dictionary):
		return Color(0.0, 0.0, 0.0, 0.0)
	var location := location_variant as Dictionary
	var batch_variant: Variant = _batches.get(location.get("key", DIAGNOSTIC_KEY))
	if not (batch_variant is Dictionary):
		return Color(0.0, 0.0, 0.0, 0.0)
	var colors := (batch_variant as Dictionary).get("colors", []) as Array[Color]
	var index := int(location.get("index", -1))
	if index < 0 or index >= colors.size():
		return Color(0.0, 0.0, 0.0, 0.0)
	return colors[index]


func debug_all_batches_hidden() -> bool:
	for batch_variant in _batches.values():
		var batch := batch_variant as Dictionary
		var multimesh := batch.get("multimesh") as MultiMesh
		if multimesh != null and multimesh.visible_instance_count != 0:
			return false
	return true


func debug_rendered_instance_transform(handle: int) -> Transform2D:
	var location_variant: Variant = _handle_locations.get(handle)
	if not (location_variant is Dictionary):
		return Transform2D()
	var location := location_variant as Dictionary
	var batch_variant: Variant = _batches.get(location.get("key", DIAGNOSTIC_KEY))
	if not (batch_variant is Dictionary):
		return Transform2D()
	var multimesh := (batch_variant as Dictionary).get("multimesh") as MultiMesh
	var index := int(location.get("index", -1))
	if multimesh == null or index < 0 or index >= multimesh.visible_instance_count:
		return Transform2D()
	return multimesh.get_instance_transform_2d(index)


func debug_rendered_instance_color(handle: int) -> Color:
	var location_variant: Variant = _handle_locations.get(handle)
	if not (location_variant is Dictionary):
		return Color(0.0, 0.0, 0.0, 0.0)
	var location := location_variant as Dictionary
	var batch_variant: Variant = _batches.get(location.get("key", DIAGNOSTIC_KEY))
	if not (batch_variant is Dictionary):
		return Color(0.0, 0.0, 0.0, 0.0)
	var multimesh := (batch_variant as Dictionary).get("multimesh") as MultiMesh
	var index := int(location.get("index", -1))
	if multimesh == null or index < 0 or index >= multimesh.visible_instance_count:
		return Color(0.0, 0.0, 0.0, 0.0)
	return multimesh.get_instance_color(index)


func _batch_for(visual_key: StringName, profile: Dictionary) -> Dictionary:
	var existing: Variant = _batches.get(visual_key)
	if existing is Dictionary:
		return existing as Dictionary
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh.mesh = quad
	multimesh.instance_count = 0
	multimesh.visible_instance_count = 0
	var instance := MultiMeshInstance2D.new()
	instance.name = "ProxyBatch_%s" % String(visual_key).validate_node_name()
	instance.multimesh = multimesh
	instance.texture = _texture_for(profile)
	instance.z_index = int(profile.get("z_index", 0))
	instance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(instance)
	var batch := {
		"instance": instance,
		"multimesh": multimesh,
		"capacity": 0,
		"handles": [] as Array[int],
		"transforms": [] as Array[Transform2D],
		"colors": [] as Array[Color],
		"texture_size": _safe_texture_size(instance.texture),
	}
	_batches[visual_key] = batch
	return batch


func _publish_batch(
	visual_key: StringName,
	batch: Dictionary,
	handles: Array[int],
	alpha: float,
) -> void:
	var count := handles.size()
	var capacity := _ensure_capacity(batch, count)
	# The buffer and mirror arrays persist on the batch: at hundreds of
	# proxies, reallocating them every frame for every batch was measurable
	# process-time churn (session 5: ~29ms avg process at 200+ enemies).
	var buffer := batch.get("buffer", PackedFloat32Array()) as PackedFloat32Array
	if buffer.size() != capacity * FLOATS_PER_INSTANCE:
		buffer.resize(capacity * FLOATS_PER_INSTANCE)
	var transforms := batch.get("transforms", [] as Array[Transform2D]) as Array[Transform2D]
	var colors := batch.get("colors", [] as Array[Color]) as Array[Color]
	transforms.resize(count)
	colors.resize(count)
	var texture_size := batch.get("texture_size", Vector2.ONE) as Vector2
	for index in range(count):
		var handle := handles[index]
		var profile := _profile_for(handle)
		var proxy_position := _world.get_previous_position(handle).lerp(_world.get_position(handle), alpha)
		var size := profile.get("size", Vector2(MIN_PROXY_SIZE, MIN_PROXY_SIZE)) as Vector2
		var proxy_scale := Vector2(size.x / texture_size.x, size.y / texture_size.y)
		var color := _profile_color(handle, profile)
		_write_instance(buffer, index * FLOATS_PER_INSTANCE, proxy_scale, proxy_position, color)
		transforms[index] = Transform2D(
			Vector2(proxy_scale.x, 0.0),
			Vector2(0.0, proxy_scale.y),
			proxy_position,
		)
		colors[index] = color
		_handle_locations[handle] = {"key": visual_key, "index": index}
	# Only the tail that was occupied last publish needs clearing; slots past
	# it were zeroed on allocation or by an earlier publish.
	var stale_tail: int = mini(int(batch.get("last_count", capacity)), capacity)
	for index in range(count, stale_tail):
		_write_instance(
			buffer,
			index * FLOATS_PER_INSTANCE,
			Vector2.ONE,
			Vector2.ZERO,
			Color(0.0, 0.0, 0.0, 0.0),
		)
	var multimesh := batch.get("multimesh") as MultiMesh
	if multimesh != null and capacity > 0:
		multimesh.buffer = buffer
		multimesh.visible_instance_count = count
	# The group arrays are rebuilt from scratch each publish, so storing them
	# without duplicating is safe.
	batch["handles"] = handles
	batch["buffer"] = buffer
	batch["transforms"] = transforms
	batch["colors"] = colors
	batch["last_count"] = count
	_visible_count += count


func _publish_actor_batch(
	visual_key: StringName,
	batch: Dictionary,
	entries: Array[Dictionary],
) -> void:
	var count := entries.size()
	var capacity := _ensure_capacity(batch, count)
	var buffer := batch.get("buffer", PackedFloat32Array()) as PackedFloat32Array
	if buffer.size() != capacity * FLOATS_PER_INSTANCE:
		buffer.resize(capacity * FLOATS_PER_INSTANCE)
	var transforms := batch.get("transforms", [] as Array[Transform2D]) as Array[Transform2D]
	var colors := batch.get("colors", [] as Array[Color]) as Array[Color]
	transforms.resize(count)
	colors.resize(count)
	for index in range(count):
		var entry := entries[index]
		var actor := entry.get("actor") as Node2D
		var sprite := entry.get("sprite") as Sprite2D
		var actor_transform: Transform2D = (
			actor.get_global_transform_interpolated()
			if actor.has_method("get_global_transform_interpolated")
			else actor.global_transform
		)
		var instance_transform := actor_transform * sprite.transform
		var color := sprite.modulate * actor.modulate
		_write_instance_transform(buffer, index * FLOATS_PER_INSTANCE, instance_transform, color)
		transforms[index] = instance_transform
		colors[index] = color
		_actor_locations[actor.get_instance_id()] = {"key": visual_key, "index": index}
	var stale_tail: int = mini(int(batch.get("last_count", capacity)), capacity)
	for index in range(count, stale_tail):
		_write_instance(
			buffer,
			index * FLOATS_PER_INSTANCE,
			Vector2.ONE,
			Vector2.ZERO,
			Color(0.0, 0.0, 0.0, 0.0),
		)
	var multimesh := batch.get("multimesh") as MultiMesh
	if multimesh != null and capacity > 0:
		multimesh.buffer = buffer
		multimesh.visible_instance_count = count
	batch["buffer"] = buffer
	batch["transforms"] = transforms
	batch["colors"] = colors
	batch["last_count"] = count
	_visible_count += count


func debug_actor_instance_transform(actor: Node2D) -> Transform2D:
	var location := _actor_locations.get(actor.get_instance_id(), {}) as Dictionary
	if location.is_empty():
		return Transform2D()
	var batch := _batches.get(location.get("key"), {}) as Dictionary
	var transforms := batch.get("transforms", [] as Array[Transform2D]) as Array[Transform2D]
	var index := int(location.get("index", -1))
	if index < 0 or index >= transforms.size():
		return Transform2D()
	return transforms[index]


func debug_actor_instance_color(actor: Node2D) -> Color:
	var location := _actor_locations.get(actor.get_instance_id(), {}) as Dictionary
	if location.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	var batch := _batches.get(location.get("key"), {}) as Dictionary
	var colors := batch.get("colors", [] as Array[Color]) as Array[Color]
	var index := int(location.get("index", -1))
	if index < 0 or index >= colors.size():
		return Color(0.0, 0.0, 0.0, 0.0)
	return colors[index]


func _write_instance_transform(
	buffer: PackedFloat32Array,
	base: int,
	instance_transform: Transform2D,
	color: Color,
) -> void:
	buffer[base] = instance_transform.x.x
	buffer[base + 1] = instance_transform.y.x
	buffer[base + 2] = 0.0
	buffer[base + 3] = instance_transform.origin.x
	buffer[base + 4] = instance_transform.x.y
	buffer[base + 5] = instance_transform.y.y
	buffer[base + 6] = 0.0
	buffer[base + 7] = instance_transform.origin.y
	buffer[base + 8] = color.r
	buffer[base + 9] = color.g
	buffer[base + 10] = color.b
	buffer[base + 11] = color.a


func _ensure_capacity(batch: Dictionary, required: int) -> int:
	var capacity := int(batch.get("capacity", 0))
	if required <= capacity:
		return capacity
	capacity = 1
	while capacity < required:
		capacity *= 2
	var multimesh := batch.get("multimesh") as MultiMesh
	if multimesh != null:
		multimesh.instance_count = capacity
		multimesh.visible_instance_count = 0
	batch["capacity"] = capacity
	return capacity


func _hide_batch(batch: Dictionary) -> void:
	var multimesh := batch.get("multimesh") as MultiMesh
	if multimesh != null:
		multimesh.visible_instance_count = 0
	batch["handles"] = [] as Array[int]
	batch["transforms"] = [] as Array[Transform2D]
	batch["colors"] = [] as Array[Color]
	# Hidden batches restart clean: clear the whole occupied tail next time.
	batch["last_count"] = int(batch.get("capacity", 0))


func _hide_all_batches() -> void:
	_handle_locations.clear()
	_actor_locations.clear()
	_visible_count = 0
	for batch_variant in _batches.values():
		_hide_batch(batch_variant as Dictionary)


func _visual_key(cold_state: Dictionary) -> StringName:
	var value: Variant = cold_state.get("proxy_visual_key", DIAGNOSTIC_KEY)
	var text := String(value).strip_edges()
	return StringName(text) if not text.is_empty() else DIAGNOSTIC_KEY


func _profile_for(handle: int) -> Dictionary:
	var existing: Variant = _visual_profiles.get(handle)
	if existing is Dictionary:
		return existing as Dictionary
	var cold_state := _world.get_cold_state(handle)
	var fallback := maxf(_world.get_collision_radius(handle) * 2.0, MIN_PROXY_SIZE)
	var value: Variant = cold_state.get("proxy_size", Vector2(fallback, fallback))
	var size := Vector2(fallback, fallback)
	if value is Vector2:
		var vector := value as Vector2
		size = Vector2(maxf(absf(vector.x), MIN_PROXY_SIZE), maxf(absf(vector.y), MIN_PROXY_SIZE))
	elif value is float or value is int:
		var scalar := maxf(absf(float(value)), MIN_PROXY_SIZE)
		size = Vector2(scalar, scalar)
	var fallback_color := ELITE_DIAGNOSTIC_COLOR if (_world.get_flags(handle) & Types.Flags.ELITE) != 0 else DIAGNOSTIC_COLOR
	var has_explicit_color := cold_state.has("proxy_color")
	var color_value: Variant = cold_state.get("proxy_color", fallback_color)
	var explicit_color := _color_from_variant(color_value, fallback_color)
	if not (color_value is Color or color_value is String or color_value is StringName):
		has_explicit_color = false
	var profile := {
		"key": _visual_key(cold_state),
		"size": size,
		"has_explicit_color": has_explicit_color,
		"color": explicit_color,
		"texture_path": String(cold_state.get("proxy_texture_path", "")),
		"z_index": int(cold_state.get("proxy_z_index", 0)),
	}
	_visual_profiles[handle] = profile
	return profile


func _profile_color(handle: int, profile: Dictionary) -> Color:
	var fallback := ELITE_DIAGNOSTIC_COLOR if (_world.get_flags(handle) & Types.Flags.ELITE) != 0 else DIAGNOSTIC_COLOR
	if bool(profile.get("has_explicit_color", false)):
		return profile.get("color", fallback) as Color
	return fallback


func _color_from_variant(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value as Color
	if value is String or value is StringName:
		return Color.from_string(String(value), fallback)
	return fallback


func _texture_for(profile: Dictionary) -> Texture2D:
	var direct := profile.get("texture") as Texture2D
	if direct != null:
		return direct
	var path := String(profile.get("texture_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		var loaded := load(path) as Texture2D
		if loaded != null:
			return loaded
	if _diagnostic_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_diagnostic_texture = ImageTexture.create_from_image(image)
	return _diagnostic_texture


func _sweep_stale_profiles() -> void:
	if _world == null or not is_instance_valid(_world):
		_visual_profiles.clear()
		return
	var cached_handles := _visual_profiles.keys()
	for handle_variant in cached_handles:
		var handle := int(handle_variant)
		if not _world.is_valid_handle(handle):
			_visual_profiles.erase(handle)


func _safe_texture_size(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var size := texture.get_size()
	return Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))


func _write_instance(
	buffer: PackedFloat32Array,
	base: int,
	instance_scale: Vector2,
	instance_position: Vector2,
	color: Color,
) -> void:
	# RenderingServer stores Transform2D as two padded rows. The origin is
	# therefore at offsets 3 and 7, followed by four RGBA floats.
	buffer[base] = instance_scale.x
	buffer[base + 1] = 0.0
	buffer[base + 2] = 0.0
	buffer[base + 3] = instance_position.x
	buffer[base + 4] = 0.0
	buffer[base + 5] = instance_scale.y
	buffer[base + 6] = 0.0
	buffer[base + 7] = instance_position.y
	buffer[base + 8] = color.r
	buffer[base + 9] = color.g
	buffer[base + 10] = color.b
	buffer[base + 11] = color.a
