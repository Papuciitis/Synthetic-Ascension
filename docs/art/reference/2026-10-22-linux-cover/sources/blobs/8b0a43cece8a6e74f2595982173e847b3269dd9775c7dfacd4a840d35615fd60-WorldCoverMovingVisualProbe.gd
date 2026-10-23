extends "res://tools/dev/CityMovingCoverPreview.gd"
## Adds actual published enemy/icon/player fragment observations to the existing
## live Game route. RGB values are review evidence, not isolated shader pixels.
## Native command: see WorldCoverMovingVisualProbe.md beside this script.

var _visual_frames: Array[Dictionary] = []
var _visual_tracks: Dictionary = {}
var _visual_images: Dictionary = {}
var _visual_counts: Dictionary = {}
var _visual_home_entities: Array[WeakRef] = []
var _visual_home_staged: bool = false
var _visual_home_plates: Array[Dictionary] = []
var _visual_home_walks: int = 0
var _visual_material_failures: Dictionary = {}
var _visual_runtime_fps: int = 60


func _prepare_runtime() -> void:
	super._prepare_runtime()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runtime-fps="):
			var requested: int = clampi(int(arg.trim_prefix("--runtime-fps=")), 30, 60)
			_visual_runtime_fps = 30 if requested < 45 else 60
	# Render cadence only; the inherited live physics/AI contract is retained.
	Engine.max_fps = _visual_runtime_fps


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Scripted shooting pauses for the staged indoor demonstration. Enemy AI,
	# scheduling, physics and all ordinary ambient producers keep running.
	if _phase == "actual doorway cutaway":
		Input.action_release(&"attack")


func _grab_live() -> void:
	var before: int = _pixels.size()
	await super._grab_live()
	if _pixels.size() > before:
		var image: Image = _pixels.back()
		_visual_frames.append(_visual_frame(image, "frames/frame-%04d.png" % before))


func _walk_to(desired: Vector2, strict_perimeter: bool = false) -> void:
	await super._walk_to(desired, strict_perimeter)
	if _phase == "actual doorway cutaway":
		_visual_home_walks += 1
		if _visual_home_walks == 1 and not _visual_home_staged:
			_visual_home_staged = true
			_stage_visual_home()
			await _live_wait(0.2)
			await _visual_plate("home-covered-before-entry")
		elif _visual_home_walks == 2:
			await _live_wait(0.6)
			await _visual_plate("home-inside-real-cutaway")
		elif _visual_home_walks == 3:
			await _live_wait(0.6)
			await _visual_plate("home-outside-roof-restored")


func _stage_visual_home() -> void:
	var points: Array[Vector2] = []
	var roof_target: Dictionary = _roof_target()
	# Search the actual IndoorVolume footprint. Only reachable, walkable cells
	# with original opaque roof cover qualify; no collision or roof changes.
	var reachable: Dictionary = _player_reachable_cells()
	for y in range(_volume.cell_tl.y, _volume.cell_tl.y + _volume.size_cells.y):
		for x in range(_volume.cell_tl.x, _volume.cell_tl.x + _volume.size_cells.x):
			var cell: Vector2i = Vector2i(x, y)
			if not reachable.has(cell) or not _chunks.is_cell_walkable(cell):
				continue
			var point: Vector2 = _chunks.cell_to_world_center(cell)
			if _target_strength(roof_target, point, point.y) < 0.99:
				continue
			points.append(point)
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(_volume.global_position) < b.distance_squared_to(_volume.global_position))
	if points.size() < 3:
		_fail("Visual home probe needs three real reachable roof-covered interior cells")
		return
	var actor: EnemyActor = _spawn_actor("Brute", points[0])
	_visual_home_entities.append(weakref(actor))
	_live_staging.append({"kind":"visual home ordinary live Brute", "requested":str(points[0]), "actual":str(actor.global_position), "frozen":false, "walkable":_chunks.is_cell_walkable(_chunks.world_to_cell(actor.global_position))})
	var item: ItemPickup = ITEM_SCENE.instantiate() as ItemPickup
	var data: ItemData = Global.get_item_data("ring_crusher")
	if data == null:
		_fail("Visual home probe requires the real ring_crusher item")
		item.free()
		return
	item.item_instance = ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.25, false)
	item.position = points[1]
	item.pickup_delay = 120.0
	item.persistent_world_drop = true
	_game.add_child(item)
	_visual_home_entities.append(weakref(item))
	var health: HealthPickup = HEALTH_SCENE.instantiate() as HealthPickup
	health.position = points[2]
	health.pickup_delay = 120.0
	health.lifetime_seconds = 120.0
	_game.add_child(health)
	_visual_home_entities.append(weakref(health))
	for pickup: Node2D in [item, health]:
		_live_staging.append({"kind":"visual home locked " + pickup.get_class(), "path":str(pickup.get_path()), "actual":str(pickup.global_position), "pickup_delay":120.0, "monitoring":(pickup as Area2D).monitoring, "walkable":true})


func _visual_plate(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	_save_image(image, _out.path_join(label + ".png"))
	_visual_home_plates.append(_visual_frame(image, label + ".png"))


func _visual_frame(image: Image, file: String) -> Dictionary:
	if _evidence_renderer == null:
		var root: Node = get_tree().get_first_node_in_group(&"enemy_proxy_root")
		if root != null:
			_evidence_renderer = root.get("renderer") as EnemyProxyRenderer
	var entities: Array[Dictionary] = []
	var home_ids: Dictionary = {}
	if _evidence_renderer != null:
		for ref: WeakRef in _visual_home_entities:
			var actor: EnemyActor = ref.get_ref() as EnemyActor
			if actor != null and not actor.dead:
				var record: Dictionary = _visual_enemy(actor, image)
				if not record.is_empty():
					entities.append(record)
					home_ids[actor.get_instance_id()] = true
		var inspected: int = 0
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			var actor: EnemyActor = node as EnemyActor
			if actor == null or actor.dead or not actor._visual_batched or home_ids.has(actor.get_instance_id()):
				continue
			var record: Dictionary = _visual_enemy(actor, image)
			if record.is_empty():
				continue
			entities.append(record)
			inspected += 1
			if inspected >= 24:
				break
	var pickup: Node2D = _live_pickup.get_ref() as Node2D if _live_pickup != null else null
	if pickup != null:
		entities.append(_visual_pickup(pickup, image))
	for ref: WeakRef in _visual_home_entities:
		var node: Node2D = ref.get_ref() as Node2D
		if node != null and not node is EnemyActor:
			entities.append(_visual_pickup(node, image))
	var player_fragments: Array[Dictionary] = []
	var feet_y: float = (_player.get_node("Visual") as Node2D).global_position.y
	for sample: Dictionary in _player_fragment_samples():
		player_fragments.append(_visual_fragment(sample.world, feet_y, float(sample.source_alpha), image))
	return {"file":file, "simulation_time":_combat_time, "phase":_phase, "player":str(_player.global_position), "player_fragments":player_fragments, "roof_inside_count":_roof._inside_count, "roof_alpha":(_roof.get_node("RoofPoly") as Polygon2D).modulate.a, "entities":entities}


func _visual_enemy(actor: EnemyActor, image: Image) -> Dictionary:
	var entries: Dictionary = _evidence_renderer.get("_actors")
	var entry: Dictionary = entries.get(actor.get_instance_id(), {})
	var batches: Dictionary = _evidence_renderer.get("_batches")
	var batch: Dictionary = batches.get(entry.get("batch_key"), {})
	var draw: MultiMeshInstance2D = batch.get("instance") as MultiMeshInstance2D
	if draw == null or not draw.is_visible_in_tree():
		return {}
	var transform: Transform2D = _evidence_renderer.debug_actor_instance_transform(actor)
	if absf(transform.determinant()) < 0.001 or not get_viewport().get_visible_rect().has_point(get_viewport().get_canvas_transform() * transform.origin):
		return {}
	var uv: Rect2 = _evidence_renderer.debug_actor_instance_uv(actor)
	var fragments: Array[Dictionary] = _visual_texture_fragments(draw.texture, uv, transform, (transform * Vector2(0, -0.5)).y, image)
	var material: ShaderMaterial = draw.material as ShaderMaterial
	var result: Dictionary = {"kind":"elite" if actor.is_elite else "ordinary", "instance_id":actor.get_instance_id(), "path":str(actor.get_path()), "world":str(actor.global_position), "published_transform":str(transform), "published_uv":str(uv), "texture":draw.texture.resource_path, "batched":true, "physics_processing":actor.is_physics_processing(), "fragments":fragments, "material":_visual_material(material)}
	_visual_track(result, actor.global_position)
	return result


func _visual_pickup(pickup: Node2D, image: Image) -> Dictionary:
	var icon: Sprite2D = pickup.get_node("Icon") as Sprite2D
	var texture: Texture2D = icon.texture
	var transform: Transform2D = icon.global_transform.translated_local(icon.get_rect().get_center()).scaled_local(Vector2(texture.get_width(), -texture.get_height()))
	var fragments: Array[Dictionary] = _visual_texture_fragments(texture, Rect2(0, 0, 1, 1), transform, pickup.global_position.y, image)
	var result: Dictionary = {"kind":"health" if pickup is HealthPickup else "equipment", "instance_id":pickup.get_instance_id(), "path":str(pickup.get_path()), "world":str(pickup.global_position), "texture":texture.resource_path, "icon_modulate":str(icon.modulate), "monitoring":(pickup as Area2D).monitoring, "pickup_ready":pickup.get("_pickup_ready"), "material":_visual_material(icon.material as ShaderMaterial), "fragments":fragments}
	_visual_track(result, pickup.global_position)
	return result


func _visual_texture_fragments(texture: Texture2D, uv: Rect2, transform: Transform2D, feet_y: float, image: Image) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if texture == null:
		return result
	var key: int = texture.get_instance_id()
	if not _visual_images.has(key):
		var source: Image = texture.get_image()
		if source != null and source.is_compressed():
			source.decompress()
		_visual_images[key] = source
	var source: Image = _visual_images[key] as Image
	if source == null:
		return result
	for gy in range(1, 6):
		for gx in range(1, 6):
			var unit: Vector2 = Vector2(gx, gy) / 6.0
			var source_pixel: Vector2i = Vector2i((uv.position + uv.size * unit) * Vector2(source.get_size()))
			if not Rect2i(Vector2i.ZERO, source.get_size()).has_point(source_pixel):
				continue
			var alpha: float = source.get_pixelv(source_pixel).a
			if alpha >= 0.85:
				result.append(_visual_fragment(transform * Vector2(unit.x - 0.5, 0.5 - unit.y), feet_y, alpha, image))
	return result


func _visual_fragment(point: Vector2, feet_y: float, alpha: float, image: Image) -> Dictionary:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var canvas_point: Vector2 = get_viewport().get_canvas_transform() * point
	var pixel: Vector2i = Vector2i((canvas_point - viewport_rect.position) * Vector2(image.get_size()) / viewport_rect.size)
	var on_image: bool = Rect2i(Vector2i.ZERO, image.get_size()).has_point(pixel)
	return {"world":str(point), "feet_y":feet_y, "source_alpha":alpha, "cover_strength":float(_evidence_cover.call("strength_at", point, feet_y)), "tree_strength":_target_strength(_live_tree, point, feet_y) if not _live_tree.is_empty() else 0.0, "screen":str(pixel), "on_image":on_image, "framebuffer_rgb":str(image.get_pixelv(pixel)) if on_image else ""}


func _visual_material(material: ShaderMaterial) -> Dictionary:
	return {"id":material.get_instance_id() if material != null else 0, "shader":material.shader.resource_path if material != null and material.shader != null else "", "cover_enabled":material.get_shader_parameter("world_cover_enabled") if material != null else false}


func _visual_track(record: Dictionary, world: Vector2) -> void:
	var key: int = int(record.instance_id)
	var state: Dictionary = _visual_tracks.get(key, {"kind":record.kind, "first_world":world, "distance":0.0, "covered":0, "exposed":0, "first_covered":-1.0, "first_exposed":-1.0})
	state.distance = maxf(float(state.distance), world.distance_to(state.first_world))
	var positive_cover: bool = false
	for fragment: Dictionary in record.fragments:
		if not bool(fragment.on_image):
			continue
		var condition: String = "covered" if float(fragment.cover_strength) >= 0.65 else ("exposed" if float(fragment.cover_strength) <= 0.01 else "partial")
		positive_cover = positive_cover or float(fragment.cover_strength) > 0.01
		var count_key: String = String(record.kind) + "/" + condition
		_visual_counts[count_key] = int(_visual_counts.get(count_key, 0)) + 1
		if condition in ["covered", "exposed"]:
			state[condition] = int(state[condition]) + 1
			if float(state["first_" + condition]) < 0.0:
				state["first_" + condition] = _combat_time
	if positive_cover and not bool(record.material.cover_enabled):
		_visual_material_failures[key] = record.path
	_visual_tracks[key] = state


func _shutdown() -> void:
	var moving_transitions: Array[Dictionary] = []
	for key: Variant in _visual_tracks:
		var track: Dictionary = _visual_tracks[key]
		if String(track.kind) in ["ordinary", "elite"] and float(track.distance) >= 12.0 and int(track.covered) > 0 and int(track.exposed) > 0:
			moving_transitions.append({"instance_id":key, "kind":track.kind, "max_displacement":track.distance, "first_covered":track.first_covered, "first_exposed":track.first_exposed})
	if _visual_frames.is_empty():
		_fail("Visual probe recorded no actual live native frames")
	if moving_transitions.is_empty():
		_fail("Visual probe did not observe the same moving enemy body with covered and exposed opaque fragments")
	if not _visual_material_failures.is_empty():
		_fail("Actual visible consumers lost enabled shared cover: " + str(_visual_material_failures))
	if _visual_home_plates.size() != 3:
		_fail("Visual probe requires before/inside/restored native home plates")
	else:
		if float(_visual_home_plates[0].roof_alpha) < 0.99 or int(_visual_home_plates[0].roof_inside_count) != 0:
			_fail("Visual home before-entry plate did not retain its actual opaque roof")
		if float(_visual_home_plates[1].roof_alpha) > 0.01 or int(_visual_home_plates[1].roof_inside_count) <= 0:
			_fail("Visual home interior plate did not show the physical player cutaway")
		if float(_visual_home_plates[2].roof_alpha) < 0.99 or int(_visual_home_plates[2].roof_inside_count) != 0:
			_fail("Visual home exit plate did not restore its actual opaque roof")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var file: FileAccess = FileAccess.open(_out.path_join("visual-cover-info.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"tool":"res://tools/dev/WorldCoverMovingVisualProbe.tscn", "scene":"res://scenes/game.tscn", "args":OS.get_cmdline_user_args(), "engine_max_fps":Engine.max_fps, "physics_ticks_per_second":Engine.physics_ticks_per_second, "counts":_visual_counts, "moving_enemy_transitions":moving_transitions, "material_failures":_visual_material_failures, "home_plates":_visual_home_plates, "frames":_visual_frames, "save_writes":SaveManager.debug_save_writes - _save_writes_before, "failures":_failures, "limits":"Extends the live CityMovingCoverPreview route and its controls. Optional runtime-fps changes render cadence only; physics and AI stay live. The render cap is not performance evidence. Adds one ordinary live Brute plus real locked equipment/health pickups in reachable walkable cells of the generated home before entry. Pickup delay/lifetime is 120 seconds; monitoring is untouched. Scripted player fire pauses during home demonstration; enemy AI/scheduler/physics/spawning/streaming stay live. Enemy samples decode the actual renderer upload transform/atlas region and batch material, never the hidden Sprite2D transform. Covered/exposed counts are repeated source-opaque fragment observations, not unique actors or framebuffer color assertions. RGB samples include native scenery blending and overlap. Existing native render suites supply isolated compositing checks; the attached frames/plates require visual review. This route is not spontaneous placement, performance, balance or human-play acceptance."}, "\t"))
		file.close()
	else:
		_fail("Cannot write native visual cover manifest")
	print("WorldCoverMovingVisualProbe: frames=%d moving_body_transitions=%d home_plates=%d failures=%d" % [_visual_frames.size(), moving_transitions.size(), _visual_home_plates.size(), _failures])
	await super._shutdown()
