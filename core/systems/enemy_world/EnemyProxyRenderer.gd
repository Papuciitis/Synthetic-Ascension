class_name EnemyProxyRenderer
extends Node2D

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")

# Transform2D (8, padded) + colour (4) + custom data (4): the custom vec4 is
# the atlas region an instance shows, see EnemyProxyRegion.gdshader.
const FLOATS_PER_INSTANCE := 16
const FULL_UV := Rect2(0.0, 0.0, 1.0, 1.0)
const REGION_SHADER: Shader = preload("res://core/systems/enemy_world/EnemyProxyRegion.gdshader")
const DIAGNOSTIC_KEY := &"__diagnostic__"
const DIAGNOSTIC_COLOR := Color(1.0, 0.0, 0.8, 1.0)
const ELITE_DIAGNOSTIC_COLOR := Color(1.0, 0.35, 0.05, 1.0)
const MIN_PROXY_SIZE := 4.0
# Off-screen instances are not published (FPS audit 2026-10-04, item 4):
# proxies live 480-640+ px from the player and many materialized smart
# actors further still, while the 1920x1080 view spans 960x540 each way.
# The margins keep a sprite that straddles the edge drawn, and cover the
# camera's travel between two half-rate proxy uploads.
const PROXY_CULL_MARGIN := 128.0
const ACTOR_CULL_MARGIN := 256.0
# Hit flash: a damaged instance draws white for this long. The flag rides in
# the sign of the region height (INSTANCE_CUSTOM.w, always positive
# otherwise) so the colour and the region keep their full precision;
# EnemyProxyRegion.gdshader mixes toward white by hit_flash_strength.
const HIT_FLASH_USEC := 70_000
const FLASH_STRENGTH_PARAM := &"hit_flash_strength"

var _world: EnemyWorldService = null
var _batches: Dictionary = {}
# Publishes in a row where a batch used <= a quarter of its capacity. After
# SHRINK_AFTER_PUBLISHES the multimesh is reallocated to fit, so a single
# peak does not leave every later frame uploading the high-water buffer.
const SHRINK_AFTER_PUBLISHES := 120
const MIN_SHRINK_CAPACITY := 16
var _visual_profiles: Dictionary = {}
var _diagnostic_texture: ImageTexture = null
var _region_material: ShaderMaterial = null
var _visible_count := 0
var _last_upload_usec := 0
var _profile_sweep_counter := 0
# Materialized enemies rendered through the same batches: instance id ->
# {actor, sprite, texture, key}. Registration is per node instance; freed
# or pooled actors are pruned/skipped during publish.
var _actors: Dictionary = {}
var _visible_proxy_count := 0
# handle -> usec the proxy's hit flash ends (EnemyCombatService reports
# damage on data-only records through proxy_damage_listener).
var _proxy_flash_until: Dictionary = {}
# The data-only population, read in bulk once per publish.
var _view_handles: Array[int] = []
var _view_positions := PackedVector2Array()
var _view_previous := PackedVector2Array()
var _view_update_times := PackedFloat32Array()
var _view_flags := PackedInt64Array()
var _view_draw := PackedVector2Array()


func setup(world: EnemyWorldService) -> void:
	_world = world
	_visible_count = 0
	_visible_proxy_count = 0
	_last_upload_usec = 0
	_ensure_region_material()
	if SettingsManager != null and not SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.connect(_on_settings_changed)


func register_actor(actor: Node2D, sprite: Sprite2D) -> void:
	if actor == null or sprite == null:
		return
	_actors[actor.get_instance_id()] = {
		"actor": actor,
		# Typed handle for the per-frame "dead" test; null for other nodes.
		"enemy": actor as EnemyActor,
		"sprite": sprite,
		"texture": null,
		"texture_size": Vector2.ONE,
		"key": &"",
		"batch_index": -1,
	}


func unregister_actor(actor: Node2D) -> void:
	if actor != null:
		_actors.erase(actor.get_instance_id())


func reset_actor_snapshot(actor: Node2D) -> void:
	# A pooled node reused for a new spawn must not interpolate from its
	# previous occupant's last (death) transform. Erasing the snapshot keys
	# makes the next publish reseed from the node's current transform.
	if actor == null:
		return
	var entry_variant: Variant = _actors.get(actor.get_instance_id())
	if entry_variant == null:
		return
	var entry := entry_variant as Dictionary
	entry.erase("curr_xf")
	entry.erase("prev_xf")
	entry.erase("snap_usec")
	entry.erase("interval_usec")


func registered_actor_count() -> int:
	return _actors.size()


## A damaged data-only enemy flashes white for HIT_FLASH_USEC.
func flash_handle(handle: int) -> void:
	_proxy_flash_until[handle] = Time.get_ticks_usec() + HIT_FLASH_USEC


## The same flash for a batched materialized actor (its sprite is hidden, so
## a flash on the sprite's own material never shows).
func flash_actor(actor: Node2D) -> void:
	if actor == null:
		return
	var entry_variant: Variant = _actors.get(actor.get_instance_id())
	if entry_variant is Dictionary:
		(entry_variant as Dictionary)["flash_until"] = Time.get_ticks_usec() + HIT_FLASH_USEC


func publish(
	interpolation_alpha: float = 1.0,
	include_proxies: bool = true,
	proxy_clock: float = -1.0,
	proxy_interval: float = 0.0,
) -> int:
	var started := Time.get_ticks_usec()
	_visible_count = 0
	if _world == null or not is_instance_valid(_world):
		_visible_proxy_count = 0
		_hide_all_batches()
		_last_upload_usec = Time.get_ticks_usec() - started
		return 0

	var view := _view_rect()
	var culling := view.has_area()
	var proxy_view := view.grow(PROXY_CULL_MARGIN)
	var actor_view := view.grow(ACTOR_CULL_MARGIN)
	var groups: Dictionary = {}
	var group_metadata: Dictionary = {}
	if not include_proxies:
		# Proxy batches keep last frame's buffers this frame (half-rate under
		# load); count their instances so visible_count stays truthful.
		_visible_count += _visible_proxy_count
	else:
		_visible_proxy_count = 0
		_world.gather_proxy_view(_view_handles, _view_positions, _view_previous, _view_update_times, _view_flags)
		var count := _view_handles.size()
		_view_draw.resize(count)
		var alpha := clampf(interpolation_alpha, 0.0, 1.0)
		var per_handle_blend := proxy_clock >= 0.0 and proxy_interval > 0.0
		for index in range(count):
			# Slices update at different times inside the fixed step; a
			# per-handle blend from the handle's own update time removes the
			# swarm micro-jitter a single global phase produces.
			var blend := alpha
			if per_handle_blend:
				blend = clampf((proxy_clock - _view_update_times[index]) / proxy_interval, 0.0, 1.0)
			var drawn := _view_previous[index].lerp(_view_positions[index], blend)
			if culling and not proxy_view.has_point(drawn):
				continue
			_view_draw[index] = drawn
			var handle := _view_handles[index]
			var profile := _profile_for(handle)
			var visual_key := profile.get("key", DIAGNOSTIC_KEY) as StringName
			var group_variant: Variant = groups.get(visual_key)
			if group_variant == null:
				group_variant = PackedInt32Array()
				group_metadata[visual_key] = profile
			var group := group_variant as PackedInt32Array
			group.append(index)
			groups[visual_key] = group

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
		var enemy := entry.get("enemy") as EnemyActor
		if (
			not actor.is_inside_tree()
			or not actor.visible
			or bool(actor.get_meta(&"__in_pool", false))
			or (enemy.dead if enemy != null else ("dead" in actor and bool(actor.get("dead"))))
			or sprite.texture == null
		):
			entry["batch_index"] = -1
			continue
		if culling and not actor_view.has_point(actor.global_position):
			# Off screen: not drawn, and its interpolation restarts from its
			# real transform when it comes back instead of sliding in from
			# where it was last seen.
			if entry.has("curr_xf"):
				entry.erase("curr_xf")
			entry["batch_index"] = -1
			continue
		if entry.get("texture") != sprite.texture:
			entry["texture"] = sprite.texture
			entry["texture_size"] = _safe_texture_size(sprite.texture)
			entry["key"] = StringName("actor:" + sprite.texture.resource_path)
		var actor_key := entry.get("key") as StringName
		var actor_group_variant: Variant = actor_groups.get(actor_key)
		if actor_group_variant == null:
			actor_group_variant = [] as Array[Dictionary]
			actor_groups[actor_key] = actor_group_variant
			actor_metadata[actor_key] = {"key": actor_key, "texture": sprite.texture, "z_index": 0}
		(actor_group_variant as Array[Dictionary]).append(entry)
	for dead_id in dead_actor_ids:
		_actors.erase(dead_id)

	var now_usec := Time.get_ticks_usec()
	var seen: Dictionary = {}
	if not include_proxies:
		for batch_key_variant in _batches:
			if not String(batch_key_variant).begins_with("actor:"):
				seen[batch_key_variant] = true
	for visual_key_variant in groups:
		var visual_key := visual_key_variant as StringName
		seen[visual_key] = true
		var batch := _batch_for(visual_key, group_metadata[visual_key] as Dictionary)
		_publish_batch(visual_key, batch, groups[visual_key] as PackedInt32Array, now_usec)
	for actor_key_variant in actor_groups:
		var actor_key := actor_key_variant as StringName
		seen[actor_key] = true
		var actor_batch := _batch_for(actor_key, actor_metadata[actor_key] as Dictionary)
		_publish_actor_batch(actor_key, actor_batch, actor_groups[actor_key] as Array[Dictionary], now_usec)
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


## Proxy instances drawn by the last publish that included proxies.
func visible_proxy_count() -> int:
	return _visible_proxy_count


## The canvas-space rect the viewport shows, or an empty rect when there is
## nothing sensible to cull against (no viewport yet).
func _view_rect() -> Rect2:
	if not is_inside_tree():
		return Rect2()
	var viewport_rect := get_viewport_rect()
	if not viewport_rect.has_area():
		return Rect2()
	return get_canvas_transform().affine_inverse() * viewport_rect


func batch_count() -> int:
	return _batches.size()


func has_visible_handle(handle: int) -> bool:
	return not _locate(handle).is_empty()


func last_upload_usec() -> int:
	return _last_upload_usec


func invalidate_visual_profile(handle: int) -> void:
	_visual_profiles.erase(handle)


func debug_instance_transform(handle: int) -> Transform2D:
	var located := _locate(handle)
	if located.is_empty():
		return Transform2D()
	return _buffer_transform(located[0] as Dictionary, int(located[1]))


func debug_instance_color(handle: int) -> Color:
	var located := _locate(handle)
	if located.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	return _buffer_color(located[0] as Dictionary, int(located[1]))


## Debug/test: whether the proxy's published instance carries the hit flash.
func debug_instance_flashing(handle: int) -> bool:
	var located := _locate(handle)
	if located.is_empty():
		return false
	var buffer := (located[0] as Dictionary).get("buffer", PackedFloat32Array()) as PackedFloat32Array
	var base := int(located[1]) * FLOATS_PER_INSTANCE
	return base >= 0 and base + FLOATS_PER_INSTANCE <= buffer.size() and buffer[base + 15] < 0.0


# The debug readers decode the upload buffer itself: the per-frame mirror
# arrays they used to read cost two writes per instance per frame.
func _buffer_transform(batch: Dictionary, index: int) -> Transform2D:
	var buffer := batch.get("buffer", PackedFloat32Array()) as PackedFloat32Array
	var base := index * FLOATS_PER_INSTANCE
	if index < 0 or index >= int(batch.get("published_count", 0)) or base + FLOATS_PER_INSTANCE > buffer.size():
		return Transform2D()
	return Transform2D(
		Vector2(buffer[base], buffer[base + 4]),
		Vector2(buffer[base + 1], buffer[base + 5]),
		Vector2(buffer[base + 3], buffer[base + 7]),
	)


func _buffer_color(batch: Dictionary, index: int) -> Color:
	var buffer := batch.get("buffer", PackedFloat32Array()) as PackedFloat32Array
	var base := index * FLOATS_PER_INSTANCE
	if index < 0 or index >= int(batch.get("published_count", 0)) or base + FLOATS_PER_INSTANCE > buffer.size():
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color(buffer[base + 8], buffer[base + 9], buffer[base + 10], buffer[base + 11])


func debug_all_batches_hidden() -> bool:
	for batch_variant in _batches.values():
		var batch := batch_variant as Dictionary
		var multimesh := batch.get("multimesh") as MultiMesh
		if multimesh != null and multimesh.visible_instance_count != 0:
			return false
	return true


func debug_rendered_instance_transform(handle: int) -> Transform2D:
	var located := _locate(handle)
	if located.is_empty():
		return Transform2D()
	var batch_variant: Variant = located[0]
	if not (batch_variant is Dictionary):
		return Transform2D()
	var multimesh := (batch_variant as Dictionary).get("multimesh") as MultiMesh
	var index := int(located[1])
	if multimesh == null or index < 0 or index >= multimesh.visible_instance_count:
		return Transform2D()
	return multimesh.get_instance_transform_2d(index)


func debug_rendered_instance_color(handle: int) -> Color:
	var located := _locate(handle)
	if located.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	var batch_variant: Variant = located[0]
	if not (batch_variant is Dictionary):
		return Color(0.0, 0.0, 0.0, 0.0)
	var multimesh := (batch_variant as Dictionary).get("multimesh") as MultiMesh
	var index := int(located[1])
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
	multimesh.use_custom_data = true
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
	instance.material = _ensure_region_material()
	add_child(instance)
	var batch := {
		"instance": instance,
		"multimesh": multimesh,
		"capacity": 0,
		"handles": [] as Array[int],
		"published_count": 0,
		"texture_size": _safe_texture_size(instance.texture),
	}
	_batches[visual_key] = batch
	return batch


func _publish_batch(
	_batch_key: StringName,
	batch: Dictionary,
	indices: PackedInt32Array,
	now_usec: int,
) -> void:
	var count := indices.size()
	var capacity := _ensure_capacity(batch, count)
	# The buffer persists on the batch: at hundreds of proxies, reallocating
	# it every frame for every batch was measurable process-time churn
	# (session 5: ~29ms avg process at 200+ enemies).
	var buffer := batch.get("buffer", PackedFloat32Array()) as PackedFloat32Array
	var handles: Array[int] = []
	handles.resize(count)
	var flashing := not _proxy_flash_until.is_empty()
	for slot in range(count):
		var index := indices[slot]
		var handle := _view_handles[index]
		handles[slot] = handle
		var profile := _profile_for(handle)
		var position := _view_draw[index]
		var size := profile.get("size", Vector2(MIN_PROXY_SIZE, MIN_PROXY_SIZE)) as Vector2
		var color: Color
		if bool(profile.get("has_explicit_color", false)):
			color = profile.get("color", DIAGNOSTIC_COLOR) as Color
		else:
			color = ELITE_DIAGNOSTIC_COLOR if (_view_flags[index] & Types.Flags.ELITE) != 0 else DIAGNOSTIC_COLOR
		var uv := profile.get("region", FULL_UV) as Rect2
		var uv_height := uv.size.y
		if flashing and int(_proxy_flash_until.get(handle, 0)) > now_usec:
			uv_height = -uv_height
		# Inlined _write_instance. The unit quad renders 1px; instance scale
		# is the target pixel size directly (dividing by texture size shrank
		# proxies to sub-pixel dots). Y is negated: the quad mesh UVs assume
		# Y-up while the canvas is Y-down, so an unflipped basis renders the
		# texture upside down. RenderingServer stores Transform2D as two
		# padded rows: the origin sits at offsets 3 and 7, then RGBA, then
		# the region.
		var base := slot * FLOATS_PER_INSTANCE
		buffer[base] = size.x
		buffer[base + 1] = 0.0
		buffer[base + 2] = 0.0
		buffer[base + 3] = position.x
		buffer[base + 4] = 0.0
		buffer[base + 5] = -size.y
		buffer[base + 6] = 0.0
		buffer[base + 7] = position.y
		buffer[base + 8] = color.r
		buffer[base + 9] = color.g
		buffer[base + 10] = color.b
		buffer[base + 11] = color.a
		buffer[base + 12] = uv.position.x
		buffer[base + 13] = uv.position.y
		buffer[base + 14] = uv.size.x
		buffer[base + 15] = uv_height
	_clear_stale_tail(batch, buffer, count, capacity)
	var multimesh := batch.get("multimesh") as MultiMesh
	if multimesh != null and capacity > 0:
		multimesh.buffer = buffer
		multimesh.visible_instance_count = count
		# Without the change signal the canvas item keeps a stale culling
		# rect from when the multimesh was empty, so batches render only
		# near the world origin. ProjectileSlotReuseTest guards the same
		# lesson on the bullet renderer.
		multimesh.emit_changed()
	batch["handles"] = handles
	batch["buffer"] = buffer
	batch["last_count"] = count
	batch["published_count"] = count
	_visible_count += count
	_visible_proxy_count += count
	if flashing:
		_expire_flashes(now_usec)


func _publish_actor_batch(
	visual_key: StringName,
	batch: Dictionary,
	entries: Array[Dictionary],
	now_usec: int,
) -> void:
	var count := entries.size()
	var capacity := _ensure_capacity(batch, count)
	var buffer := batch.get("buffer", PackedFloat32Array()) as PackedFloat32Array
	for index in range(count):
		var entry := entries[index]
		var actor := entry.get("actor") as Node2D
		var sprite := entry.get("sprite") as Sprite2D
		var actor_transform := _interpolated_actor_transform(
			entry,
			actor.global_transform,
			now_usec
		)
		# The unit quad renders 1px; bake the texture size in so instances
		# render at the sprite's native pixel size under node/sprite scales.
		# Texture Y is negated: the quad mesh UVs assume Y-up while the
		# canvas is Y-down, so an unflipped basis renders upside down.
		var texture_size := entry.get("texture_size", Vector2.ONE) as Vector2
		# A sheet-animated sprite shows one region: size the quad to the frame
		# and hand the shader that frame's UV rectangle.
		var frame_size := texture_size
		var uv := FULL_UV
		if sprite.region_enabled:
			frame_size = sprite.region_rect.size
			uv = Rect2(sprite.region_rect.position / texture_size, frame_size / texture_size)
		if sprite.flip_h:
			uv = Rect2(uv.position.x + uv.size.x, uv.position.y, -uv.size.x, uv.size.y)
		if int(entry.get("flash_until", 0)) > now_usec:
			uv.size.y = -uv.size.y
		var instance_transform := (actor_transform * sprite.transform).scaled_local(
			Vector2(frame_size.x, -frame_size.y)
		)
		var color := sprite.modulate * actor.modulate
		_write_instance_transform(buffer, index * FLOATS_PER_INSTANCE, instance_transform, color, uv)
		# Slot bookkeeping lives on the persistent entry dict: a fresh location
		# dictionary per actor per frame was pure allocation churn at 1000+.
		entry["batch_key"] = visual_key
		entry["batch_index"] = index
	_clear_stale_tail(batch, buffer, count, capacity)
	var multimesh := batch.get("multimesh") as MultiMesh
	if multimesh != null and capacity > 0:
		multimesh.buffer = buffer
		multimesh.visible_instance_count = count
		# Same stale-culling-rect guard as the proxy batches above.
		multimesh.emit_changed()
	batch["buffer"] = buffer
	batch["last_count"] = count
	batch["published_count"] = count
	_visible_count += count


## Only the tail that was occupied last publish needs clearing; slots past it
## were zeroed on allocation or by an earlier publish.
func _clear_stale_tail(batch: Dictionary, buffer: PackedFloat32Array, count: int, capacity: int) -> void:
	var stale_tail: int = mini(int(batch.get("last_count", capacity)), capacity)
	for index in range(count, stale_tail):
		_write_instance(
			buffer,
			index * FLOATS_PER_INSTANCE,
			Vector2.ONE,
			Vector2.ZERO,
			Color(0.0, 0.0, 0.0, 0.0),
		)


func _expire_flashes(now_usec: int) -> void:
	for handle_variant in _proxy_flash_until.keys():
		if int(_proxy_flash_until[handle_variant]) <= now_usec:
			_proxy_flash_until.erase(handle_variant)


func _interpolated_actor_transform(
	entry: Dictionary,
	current: Transform2D,
	now_usec: int,
) -> Transform2D:
	# Snapshot interpolation: the visual lerps between the actor's last two
	# real transform updates, so 60Hz full-tier and 20Hz mid-tier movement
	# both render smoothly (2D has no engine transform interpolation in this
	# build). The interval is stamped and clamped at snapshot time, so one
	# late first update can never stretch the blend window past 200ms.
	var curr_variant: Variant = entry.get("curr_xf")
	if curr_variant == null:
		entry["prev_xf"] = current
		entry["curr_xf"] = current
		entry["snap_usec"] = now_usec
		entry["interval_usec"] = 0
		return current
	var curr := curr_variant as Transform2D
	if not curr.is_equal_approx(current):
		entry["prev_xf"] = curr
		entry["interval_usec"] = clampi(now_usec - int(entry.get("snap_usec", now_usec)), 0, 200_000)
		entry["curr_xf"] = current
		entry["snap_usec"] = now_usec
	var interval := int(entry.get("interval_usec", 0))
	if interval <= 0:
		return current
	var interp_alpha := clampf(
		float(now_usec - int(entry.get("snap_usec", now_usec))) / float(interval),
		0.0,
		1.0
	)
	return (entry.get("prev_xf") as Transform2D).interpolate_with(current, interp_alpha)


func debug_actor_instance_transform(actor: Node2D) -> Transform2D:
	var entry := _actors.get(actor.get_instance_id(), {}) as Dictionary
	if entry.is_empty():
		return Transform2D()
	var batch := _batches.get(entry.get("batch_key"), {}) as Dictionary
	return _buffer_transform(batch, int(entry.get("batch_index", -1)))


## Debug/test: the atlas UV rectangle written for a registered actor.
func debug_actor_instance_uv(actor: Node2D) -> Rect2:
	var entry_variant: Variant = _actors.get(actor.get_instance_id()) if actor != null else null
	if not (entry_variant is Dictionary):
		return Rect2()
	var entry := entry_variant as Dictionary
	var batch_variant: Variant = _batches.get(entry.get("batch_key", &""))
	if not (batch_variant is Dictionary):
		return Rect2()
	var buffer := (batch_variant as Dictionary).get("buffer", PackedFloat32Array()) as PackedFloat32Array
	var base := int(entry.get("batch_index", -1)) * FLOATS_PER_INSTANCE
	if base < 0 or base + FLOATS_PER_INSTANCE > buffer.size():
		return Rect2()
	return Rect2(buffer[base + 12], buffer[base + 13], buffer[base + 14], absf(buffer[base + 15]))


func debug_actor_instance_color(actor: Node2D) -> Color:
	var entry := _actors.get(actor.get_instance_id(), {}) as Dictionary
	if entry.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	var batch := _batches.get(entry.get("batch_key"), {}) as Dictionary
	return _buffer_color(batch, int(entry.get("batch_index", -1)))


func _write_instance_transform(
	buffer: PackedFloat32Array,
	base: int,
	instance_transform: Transform2D,
	color: Color,
	uv: Rect2 = FULL_UV,
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
	buffer[base + 12] = uv.position.x
	buffer[base + 13] = uv.position.y
	buffer[base + 14] = uv.size.x
	buffer[base + 15] = uv.size.y


# Debug/test lookups only: locate a proxy handle's batch and slot by scanning
# the published handle lists, so the hot publish path keeps no per-handle map.
func _locate(handle: int) -> Array:
	for batch_variant in _batches.values():
		var batch := batch_variant as Dictionary
		var index := (batch.get("handles", [] as Array[int]) as Array[int]).find(handle)
		if index >= 0:
			return [batch, index]
	return []


func _ensure_capacity(batch: Dictionary, required: int) -> int:
	var capacity := int(batch.get("capacity", 0))
	var shrinkable := required * 4 <= capacity and capacity > MIN_SHRINK_CAPACITY
	var streak := int(batch.get("shrink_streak", 0)) + 1 if shrinkable else 0
	batch["shrink_streak"] = streak
	if required <= capacity and streak < SHRINK_AFTER_PUBLISHES:
		return capacity
	batch["shrink_streak"] = 0
	capacity = maxi(MIN_SHRINK_CAPACITY, nearest_po2(required))
	var multimesh := batch.get("multimesh") as MultiMesh
	if multimesh != null:
		multimesh.instance_count = capacity
		multimesh.visible_instance_count = 0
	batch["capacity"] = capacity
	# The buffer is the one owner of its size: zero-filled here on every
	# reallocation, so no stale tail exists for the publish to clear.
	var buffer := batch.get("buffer", PackedFloat32Array()) as PackedFloat32Array
	buffer.resize(capacity * FLOATS_PER_INSTANCE)
	buffer.fill(0.0)
	batch["buffer"] = buffer
	batch["last_count"] = 0
	return capacity


func _hide_batch(batch: Dictionary) -> void:
	var multimesh := batch.get("multimesh") as MultiMesh
	if multimesh != null:
		multimesh.visible_instance_count = 0
	batch["handles"] = [] as Array[int]
	batch["published_count"] = 0
	# Hidden batches restart clean: clear the whole occupied tail next time.
	batch["last_count"] = int(batch.get("capacity", 0))


func _hide_all_batches() -> void:
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
		"region": cold_state.get("proxy_region", FULL_UV) if cold_state.get("proxy_region") is Rect2 else FULL_UV,
	}
	_visual_profiles[handle] = profile
	return profile


func _ensure_region_material() -> ShaderMaterial:
	if _region_material == null:
		_region_material = ShaderMaterial.new()
		_region_material.shader = REGION_SHADER
		_apply_flash_strength()
	return _region_material


## The accessibility setting scales the white mix (off / 40% / full), the
## same contract as every other combat flash (AccessibilityPresentation).
func _apply_flash_strength() -> void:
	if _region_material != null:
		_region_material.set_shader_parameter(FLASH_STRENGTH_PARAM, AccessibilityPresentation.current_flash_alpha(1.0))


func _on_settings_changed(section: StringName, key: StringName, _value: Variant) -> void:
	if section == &"accessibility" and key == &"combat_flash":
		_apply_flash_strength()


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
	uv: Rect2 = FULL_UV,
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
	buffer[base + 12] = uv.position.x
	buffer[base + 13] = uv.position.y
	buffer[base + 14] = uv.size.x
	buffer[base + 15] = uv.size.y
