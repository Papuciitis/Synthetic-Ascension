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
var _visual_phase: String = "full"
var _visual_deadline_hit: bool = false
var _visual_tree_plates: Array[Dictionary] = []
var _visual_phase_summary: Dictionary = {}
var _visual_tree_fixture: Dictionary = {}
var _visual_tree_attempts: Array[Dictionary] = []


func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): _visual_phase = arg.trim_prefix("--phase=")


func _prepare_runtime() -> void:
	super._prepare_runtime()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runtime-fps="):
			var requested: int = int(arg.trim_prefix("--runtime-fps="))
			if requested in [15, 20, 30, 60]: _visual_runtime_fps = requested
			else: _fail("runtime-fps must be one of 15, 20, 30, 60")
	# Render cadence only; the inherited live physics/AI contract is retained.
	Engine.max_fps = _visual_runtime_fps


func _run() -> void:
	if _visual_phase == "full":
		await super._run()
		return
	if _visual_phase not in ["home", "tree"] or DisplayServer.get_name() == "headless" or _target_building_id <= 0 or not _has_target_chunk:
		_fail("Short native phase requires --phase=home|tree and an explicit actual home/chunk")
		await _shutdown()
		return
	_prepare_runtime()
	Global.attempt_segment = _city_segment
	Global.attempt_world_seed = _city_world_seed
	Global.debug_encounter_beats = true
	_reduced_motion = _review == "reduced"
	SettingsManager.set_value(&"accessibility", &"reduced_motion", _reduced_motion, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", "off" if _reduced_motion else "full", false)
	get_window().size = Vector2i(960, 540) if _review in ["small", "reduced"] else Vector2i(1280, 720)
	get_window().title = "Synthetic Ascension — live cover " + _visual_phase
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out.path_join("frames")))
	_game = GAME.instantiate() as Node2D
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.top_level = true
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	_connect_evidence_events()
	RunEvents.spawn_request_resolved.connect(_on_live_spawn)
	await _settle()
	_dismiss_dossiers()
	var warp: Vector2 = (Vector2(_target_chunk) + Vector2.ONE * 0.5) * _chunks.chunk_size_px + Vector2(0, 600)
	_player.global_position = warp
	await _settle()
	_dismiss_dossiers()
	for node: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if node is IndoorVolume and _matches_volume(node as IndoorVolume, _target_building_id): _volume = node as IndoorVolume
	if _volume == null:
		_fail("Explicit live phase home did not stream")
		await _shutdown()
		return
	for connection: Dictionary in _volume.body_entered.get_connections():
		var subscriber: Object = (connection.callable as Callable).get_object()
		if subscriber is RoofOverlay: _roof = subscriber as RoofOverlay
	for kit: Node in get_tree().get_nodes_in_group(&"city_block_building"):
		if kit.get("_roof") == _roof: _evidence_kit = kit as Node2D
	if _roof == null or _evidence_kit == null or _failures > 0:
		_fail("Actual phase home lacks its original roof/kit")
		await _shutdown()
		return
	_evidence_cover = COVER_PROVIDER.get_for(_player)
	var door: Vector2 = _volume.to_global(_volume.get("_presentation_entry"))
	var outward: Vector2 = _volume.get("_presentation_outward")
	var front: Vector2 = _chunks.cell_to_world_center(_chunks.world_to_cell(door + outward * 96.0))
	var behind: Vector2 = Vector2.INF
	if _visual_phase == "tree":
		_visual_tree_fixture = _visual_select_tree_fixture()
		if not _visual_tree_fixture.is_empty():
			_live_tree = _visual_tree_fixture.target
			front = _visual_tree_fixture.front
			behind = _visual_tree_fixture.behind
	else: _live_tree = _tree_target()
	if front == Vector2.INF or not _chunks.is_cell_walkable(_chunks.world_to_cell(front)) or (_visual_phase == "tree" and behind == Vector2.INF):
		_fail("Phase lacks a verified walkable initial/front/covered pair")
		await _shutdown()
		return
	_player.global_position = front
	_live_staging.append({"kind":"phase initial player warp", "streaming_destination":str(warp), "recording_start":str(front), "phase":_visual_phase})
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	if _visual_phase == "tree":
		var before_view: Dictionary = _visual_view_state()
		var before_physics: int = Engine.get_physics_frames()
		_camera.global_position = front + Vector2(140, -160)
		_camera.rotation = 0.0
		_camera.reset_smoothing()
		_camera.force_update_scroll()
		for _tick: int in range(4):
			await get_tree().physics_frame
			await get_tree().process_frame
		_camera.force_update_scroll()
		await RenderingServer.frame_post_draw
		_evidence_cover.call("refresh", _player, true)
		_live_staging.append({"kind":"tree initial effective camera settle", "before":before_view, "after":_visual_view_state(), "ordinary_physics_frames":Engine.get_physics_frames()-before_physics})
	else: await _frames(4)
	_live_scheduler_start = EnemySimulationScheduler.get_debug_counters()
	_live_last_player = _player.global_position
	_live_start = Time.get_ticks_usec()
	_live_recording = true
	if _visual_phase == "home":
		_phase = "actual doorway cutaway"
		await _walk_to(front)
		await _walk_to(door - outward * float(_chunks.cell_size_px))
		await _walk_to(door + outward * 160.0)
	else:
		_phase = "tree foreground crossing"
		var actor: EnemyActor = _spawn_actor("Brute", behind)
		_visual_home_entities.append(weakref(actor))
		_live_staging.append({"kind":"ordinary live tree Brute", "requested":str(behind), "actual":str(actor.global_position), "frozen":false})
		_evidence_cover.call("refresh", _player, true)
		var covered_pickups: Array[Vector2] = _visual_tree_fixture.pickups
		if covered_pickups.size() >= 2: _visual_add_pickups(covered_pickups[0], covered_pickups[1], "tree covered")
		else: _fail("Tree phase needs two reachable opaque covered pickup cells")
		_visual_add_pickups(front + Vector2(128, 64), front + Vector2(256, 64), "tree front control", true)
		_stage_live_shooters()
		await _live_wait(0.2)
		await _visual_plate("tree-front")
		await _live_wait(2.0)
		await _walk_to(behind)
		await _live_wait(0.3)
		await _visual_plate("tree-behind")
		await _walk_to(front)
		await _live_wait(0.3)
		await _visual_plate("tree-front-restored")
		await _live_wait(2.5)
	await _visual_finish_phase()


func _visual_finish_phase() -> void:
	_live_recording = false
	_release_inputs()
	await RenderingServer.frame_post_draw
	get_tree().paused = true
	var scheduler_end: Dictionary = EnemySimulationScheduler.get_debug_counters()
	if not _live_flags_ok: _fail("Required phase producer stopped during recording")
	if scheduler_end == _live_scheduler_start: _fail("Live phase scheduler counters did not advance")
	if int(_live_spawns.get("ambient", 0)) <= 0: _fail("No ordinary ambient spawn resolved during live phase")
	if SaveManager.debug_save_writes != _save_writes_before or SaveManager.current_save != null: _fail("Phase selected or wrote a profile")
	if _visual_phase == "tree" and (_live_projectile_covered <= 0 or _live_projectile_exposed <= 0 or _live_tell_covered <= 0 or _live_tell_exposed <= 0): _fail("Tree phase requires covered/exposed live projectiles and ordinary windups")
	_visual_phase_summary = {"phase":_visual_phase, "simulation_seconds":_combat_time, "simulation_deadline_seconds":30.0, "deadline_hit":_visual_deadline_hit, "wall_seconds":float(Time.get_ticks_usec()-_live_start)/1000000.0, "distance_walked":_live_distance, "route":_route_notes, "staging":_live_staging, "tree_fixture_attempts":_visual_tree_attempts, "producers_stayed_live":_live_flags_ok, "scheduler_start":_live_scheduler_start, "scheduler_end":scheduler_end, "spawned_by_source":_live_spawns, "chunk_centers":_live_centers, "projectile_covered":_live_projectile_covered, "projectile_exposed":_live_projectile_exposed, "tell_covered":_live_tell_covered, "tell_exposed":_live_tell_exposed, "first_foreground_crossings":_live_first_crossings, "omitted_gates":["ordinary item collection/inventory", "mandatory streaming boundary", "player fire/hit proof"]}
	for index: int in range(_pixels.size()):
		_save_image(_pixels[index], _out.path_join("frames/frame-%04d.png" % index))
		await get_tree().create_timer(0.08, true, false, true).timeout
	AudioManager.stop_all(true)
	await _shutdown()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Scripted shooting pauses for the staged indoor demonstration. Enemy AI,
	# scheduling, physics and all ordinary ambient producers keep running.
	if _phase == "actual doorway cutaway" or _visual_phase != "full":
		Input.action_release(&"attack")
	if _visual_phase != "full" and _live_recording and _combat_time >= 30.0 and not _visual_deadline_hit:
		_visual_deadline_hit = true
		_release_inputs()
		_fail("Short live visual phase exceeded its 30-second simulation deadline")


func _grab_live() -> void:
	if _visual_phase != "full" and _pixels.size() >= 12:
		_live_grabbing = false
		_next_usec = Time.get_ticks_usec() + 1000000
		return
	var before: int = _pixels.size()
	await super._grab_live()
	if _pixels.size() > before:
		var image: Image = _pixels.back()
		_visual_frames.append(_visual_frame(image, "frames/frame-%04d.png" % before))
	if _visual_phase != "full": _next_usec = Time.get_ticks_usec() + 1000000


func _walk_to(desired: Vector2, strict_perimeter: bool = false) -> void:
	if _visual_deadline_hit: return
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


func _live_wait(seconds: float) -> void:
	if _visual_phase == "full":
		await super._live_wait(seconds)
		return
	var until: float = minf(_combat_time + seconds, 30.0)
	while _combat_time < until and not _visual_deadline_hit:
		await get_tree().physics_frame
		if get_tree().paused:
			_fail("Unexpected modal paused short live phase")
			return


func _live_step(target: Vector2) -> bool:
	if _visual_phase == "full": return await super._live_step(target)
	var last_progress: Vector2 = _player.global_position
	var still_ticks: int = 0
	for _tick: int in range(120):
		if _visual_deadline_hit: return false
		var movement: Vector2 = target - _player.global_position
		if movement.length() < 8.0: return true
		var axis: Vector2 = movement.normalized()
		_set_axis(&"move_left", &"move_right", axis.x)
		_set_axis(&"move_up", &"move_down", axis.y)
		await get_tree().physics_frame
		if get_tree().paused: return false
		if _player.global_position.distance_to(last_progress) < 1.0: still_ticks += 1
		else:
			still_ticks = 0
			last_progress = _player.global_position
		if still_ticks >= 30: return false
	return false


func _live_sidestep(goal: Vector2, blocked: Dictionary) -> bool:
	if _visual_deadline_hit: return false
	return await super._live_sidestep(goal, blocked)


func _visual_add_pickups(item_point: Vector2, health_point: Vector2, label: String, exposed: bool = false) -> void:
	var data: ItemData = Global.get_item_data("ring_crusher")
	if data == null:
		_fail("Tree phase requires the real ring_crusher item")
		return
	if not exposed and (not _chunks.is_cell_walkable(_chunks.world_to_cell(item_point)) or not _chunks.is_cell_walkable(_chunks.world_to_cell(health_point))):
		_fail("Verified tree pickup points lost walkable cells")
		return
	var item: ItemPickup = ITEM_SCENE.instantiate() as ItemPickup
	item.item_instance = ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.25, false)
	item.position = item_point
	item.pickup_delay = 120.0
	item.persistent_world_drop = true
	_game.add_child(item)
	var health: HealthPickup = HEALTH_SCENE.instantiate() as HealthPickup
	health.position = health_point
	health.pickup_delay = 120.0
	health.lifetime_seconds = 120.0
	_game.add_child(health)
	if exposed:
		var item_probes: Array[Vector2] = _visual_sprite_probes(item.get_node("Icon") as Sprite2D, item.global_position)
		var health_probes: Array[Vector2] = _visual_sprite_probes(health.get_node("Icon") as Sprite2D, health.global_position, health.bob_height)
		var selected_item: Vector2 = _visual_exposed_point(item_point, item_probes, "equipment") if not item_probes.is_empty() else Vector2.INF
		if selected_item != Vector2.INF: _occupied.append(selected_item)
		var selected_health: Vector2 = _visual_exposed_point(health_point, health_probes, "health") if not health_probes.is_empty() else Vector2.INF
		if selected_item == Vector2.INF or selected_health == Vector2.INF:
			_fail("Tree phase needs actual shared-uncovered front pickup cells")
			item.queue_free()
			health.queue_free()
			return
		item.global_position = selected_item
		health.global_position = selected_health
		_occupied.append(selected_health)
	for pickup: Node2D in [item, health]:
		_visual_home_entities.append(weakref(pickup))
		_live_staging.append({"kind":label + " locked pickup", "path":str(pickup.get_path()), "actual":str(pickup.global_position), "cell":str(_chunks.world_to_cell(pickup.global_position)), "tree_strength_at_foot":_target_strength(_live_tree, pickup.global_position, pickup.global_position.y), "pickup_delay":120.0, "monitoring":(pickup as Area2D).monitoring, "walkable":_chunks.is_cell_walkable(_chunks.world_to_cell(pickup.global_position))})


func _visual_tree_pickup_points(target: Dictionary, reachable: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var bounds: Rect2 = target.bounds
	var first: Vector2i = _chunks.world_to_cell(bounds.position)
	var last: Vector2i = _chunks.world_to_cell(bounds.end)
	var step: float = float(_chunks.cell_size_px) / 8.0
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not reachable.has(cell) or not _chunks.is_cell_walkable(cell): continue
			var centre: Vector2 = _chunks.cell_to_world_center(cell)
			var selected: Vector2 = Vector2.INF
			for oy: int in range(-3, 4):
				for ox: int in range(-3, 4):
					var point: Vector2 = centre + Vector2(ox, oy) * step
					if _target_strength(target, point, point.y) < 0.99: continue
					var separated: bool = true
					for previous: Vector2 in result:
						if previous.distance_to(point) < 32.0: separated = false
					if not separated: continue
					if not _visual_capsule_clear(point, centre): continue
					if selected == Vector2.INF or point.distance_squared_to(centre) < selected.distance_squared_to(centre): selected = point
			if selected != Vector2.INF: result.append(selected)
			if result.size() >= 2: return result
	return result


func _visual_select_tree_fixture() -> Dictionary:
	var candidates: Array[Sprite2D] = []
	for node: Node in get_tree().get_nodes_in_group(FOREGROUND.GROUP):
		if not node is Sprite2D or not String(node.name).contains("Tree"): continue
		var sprite: Sprite2D = node as Sprite2D
		var fruit: bool = sprite.texture != null and sprite.texture.resource_path.contains("fruit_tree")
		if (_tree_kind == "fruit" and not fruit) or (_tree_kind == "ordinary" and fruit): continue
		candidates.append(sprite)
	candidates.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.global_position.distance_squared_to(_volume.global_position) < b.global_position.distance_squared_to(_volume.global_position))
	var reachable: Dictionary = _player_reachable_cells()
	var samples: Array[Dictionary] = _player_fragment_samples()
	for index: int in range(mini(8, candidates.size())):
		var descriptor: Dictionary = _sprite_surface(candidates[index])
		if descriptor.is_empty(): continue
		var target: Dictionary = {"kind":"fruit-tree" if String(descriptor.texture).contains("fruit_tree") else "ordinary-tree", "bounds":descriptor.bounds, "front_y":descriptor.front_y, "ground_world":descriptor.ground_world, "surfaces":[descriptor]}
		var front: Vector2 = _player_tree_waypoint(target, reachable, samples, false)
		var behind: Vector2 = _player_tree_waypoint(target, reachable, samples, true)
		var points: Array[Vector2] = _visual_tree_pickup_points(target, reachable)
		var shooter: Vector2 = _visual_covered_shooter_cell(target, reachable, front, behind)
		var checks: Array[Dictionary] = []
		for point: Vector2 in points:
			var cell: Vector2i = _chunks.world_to_cell(point)
			checks.append({"world":str(point), "cell":str(cell), "walkable":_chunks.is_cell_walkable(cell), "reachable":reachable.has(cell), "opaque_foot_strength":_target_strength(target, point, point.y), "capsule_from_cell_centre_clear":_visual_capsule_clear(point, _chunks.cell_to_world_center(cell)), "capsule_query":"actual shape / World2D static overlap + swept motion; player body registration not required"})
		_visual_tree_attempts.append({"path":descriptor.path, "texture":descriptor.texture, "bounds":str(target.bounds), "front_y":target.front_y, "ground_world":str(target.ground_world), "front":str(front), "behind":str(behind), "covered_pickup_checks":checks, "point_step_px":float(_chunks.cell_size_px)/8.0, "opaque_foot_threshold":0.99, "distinct_reachable_pickup_cells":points.size(), "covered_shooter_cell":str(shooter)})
		if front != Vector2.INF and behind != Vector2.INF and points.size() >= 2 and shooter != Vector2.INF: return {"target":target, "front":front, "behind":behind, "pickups":points, "covered_shooter":shooter}
	_fail("No bounded actual tree supplies a reachable front/behind pair and two opaque pickup cells")
	return {}


func _visual_view_state() -> Dictionary:
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	return {"camera_world":str(_camera.global_position), "camera_zoom":str(_camera.zoom), "canvas_transform":str(get_viewport().get_canvas_transform()), "logical_viewport":str(get_viewport().get_visible_rect()), "world_bounds":[view.position.x, view.position.y, view.size.x, view.size.y]}


func _visual_capsule_clear(point: Vector2, from_point: Vector2 = Vector2.INF) -> bool:
	var capsule: CollisionShape2D = _player.get_node("CollisionShape2D") as CollisionShape2D
	if capsule == null or capsule.shape == null: return false
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = capsule.shape
	query.collision_mask = _player.collision_mask & ~2
	query.exclude = [_player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 2.0
	var placement: Transform2D = capsule.global_transform
	placement.origin += point - _player.global_position
	query.transform = placement
	var space: PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	if from_point != Vector2.INF:
		placement.origin += from_point - point
		query.transform = placement
		if not space.intersect_shape(query, 1).is_empty(): return false
		query.motion = point - from_point
		var travel: PackedFloat32Array = space.cast_motion(query)
		if travel.size() != 2 or travel[0] < 1.0: return false
	return true


func _visual_sprite_probes(sprite: Sprite2D, origin: Vector2, bob: float = 0.0) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if sprite == null or sprite.texture == null: return result
	var key: int = sprite.texture.get_instance_id()
	if not _visual_images.has(key):
		var loaded: Image = sprite.texture.get_image()
		if loaded != null and loaded.is_compressed(): loaded.decompress()
		_visual_images[key] = loaded
	var source: Image = _visual_images[key] as Image
	if source == null: return result
	var region: Rect2 = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size())
	region.size /= Vector2(sprite.hframes, sprite.vframes)
	region.position += Vector2(sprite.frame_coords) * region.size
	var image_origin: Vector2 = (sprite.texture as AtlasTexture).margin.position if sprite.texture is AtlasTexture else Vector2.ZERO
	for gy: int in range(1, 6):
		for gx: int in range(1, 6):
			var unit: Vector2 = Vector2(gx, gy) / 6.0
			var pixel: Vector2i = Vector2i(region.position + region.size * unit - image_origin)
			if not Rect2i(Vector2i.ZERO, source.get_size()).has_point(pixel) or source.get_pixelv(pixel).a < 0.85: continue
			var draw_unit: Vector2 = Vector2(1.0-unit.x if sprite.flip_h else unit.x, 1.0-unit.y if sprite.flip_v else unit.y)
			var offset: Vector2 = sprite.to_global(sprite.get_rect().position + sprite.get_rect().size * draw_unit) - origin
			result.append(offset)
			if bob > 0.0:
				result.append(offset + Vector2(0, -bob))
				result.append(offset + Vector2(0, bob))
	return result


func _visual_exposed_point(desired: Vector2, source_probes: Array[Vector2], role: String, muzzle: bool = false, own_reservation: Vector2 = Vector2.INF) -> Vector2:
	var reachable: Dictionary = _player_reachable_cells()
	var centre: Vector2i = _chunks.world_to_cell(desired)
	var chosen: Vector2 = Vector2.INF
	var best: float = INF
	var rejected: Dictionary = {"unreachable":0, "not_walkable":0, "offscreen":0, "shared_cover":0, "occupied":0, "capsule":0, "eligible":0}
	var probes: Array[Vector2] = [Vector2.ZERO, Vector2(-32, 0), Vector2(32, 0), Vector2(0, -32), Vector2(0, 32)]
	probes.append_array(source_probes)
	for y: int in range(-4, 5):
		for x: int in range(-4, 5):
			var cell: Vector2i = centre + Vector2i(x, y)
			if not reachable.has(cell):
				rejected.unreachable += 1
				continue
			if not _chunks.is_cell_walkable(cell):
				rejected.not_walkable += 1
				continue
			var point: Vector2 = _chunks.cell_to_world_center(cell)
			var reason: String = ""
			for offset: Vector2 in probes:
				if not get_viewport().get_visible_rect().has_point(get_viewport().get_canvas_transform() * (point + offset)): reason = "offscreen"
				elif float(_evidence_cover.call("strength_at", point + offset, point.y)) > 0.01 and reason == "": reason = "shared_cover"
			if muzzle:
				var at: Vector2 = point + point.direction_to(_player.global_position) * 14.0
				if not get_viewport().get_visible_rect().has_point(get_viewport().get_canvas_transform() * at): reason = "offscreen"
				elif float(_evidence_cover.call("strength_at", at, at.y)) > 0.01 and reason == "": reason = "shared_cover"
			for occupied: Vector2 in _occupied:
				if occupied != own_reservation and occupied.distance_to(point) < 44.0 and reason == "": reason = "occupied"
			if reason == "" and not _visual_capsule_clear(point): reason = "capsule"
			if reason != "":
				rejected[reason] = int(rejected[reason]) + 1
				continue
			rejected.eligible += 1
			if point.distance_squared_to(desired) < best:
				chosen = point
				best = point.distance_squared_to(desired)
	_live_staging.append({"kind":"shared-uncovered control search", "role":role, "desired":str(desired), "selected":str(chosen), "view":_visual_view_state(), "candidates":81, "filter_counts":rejected, "reachable_cells":reachable.size(), "reserved_points":_occupied.size(), "source_opaque_probes":source_probes.size(), "muzzle_own_depth":muzzle})
	return chosen


func _stage_live_shooters() -> void:
	if _visual_phase != "tree":
		super._stage_live_shooters()
		return
	# Keep the existing covered producer; find an actual exposed producer on
	# clear reachable ground instead of assuming the western arcade is exposed.
	var chosen: Vector2 = _visual_tree_fixture.covered_shooter
	var covered: EnemyActor = _spawn_actor("Spitter", chosen)
	_visual_home_entities.append(weakref(covered))
	var covered_muzzle: Vector2 = covered.global_position + covered.global_position.direction_to(_player.global_position) * 14.0
	var covered_strength: float = _target_strength(_live_tree, covered_muzzle, covered_muzzle.y)
	_live_staging.append({"kind":"ordinary live covered tree Spitter", "actual":str(covered.global_position), "tree_muzzle_cover":covered_strength, "frozen":false})
	if covered_strength < 0.65: _fail("Actual covered shooter resolved out of its selected tree canopy")
	var desired: Vector2 = _player.global_position + Vector2(256, 96)
	var exposed: EnemyActor = _spawn_actor("Spitter", desired)
	var reservation: Vector2 = exposed.global_position
	var probes: Array[Vector2] = _visual_sprite_probes(exposed.get_node("Sprite2D") as Sprite2D, reservation)
	var exposed_point: Vector2 = _visual_exposed_point(desired, probes, "Spitter configured source + muzzle", true, reservation) if not probes.is_empty() else Vector2.INF
	if exposed_point == Vector2.INF:
		_fail("No actual shared-uncovered shooter control cell")
		return
	exposed.global_position = exposed_point
	_occupied[_occupied.size()-1] = exposed_point
	_visual_home_entities.append(weakref(exposed))
	var actual_muzzle: Vector2 = exposed.global_position + exposed.global_position.direction_to(_player.global_position) * 14.0
	var strength: float = float(_evidence_cover.call("strength_at", actual_muzzle, actual_muzzle.y))
	_live_staging.append({"kind":"ordinary live exposed tree Spitter", "actual":str(exposed.global_position), "muzzle_cover":strength, "frozen":false})
	if strength > 0.01: _fail("Actual exposed shooter resolved into shared cover")


func _visual_covered_shooter_cell(target: Dictionary, reachable: Dictionary, front: Vector2, behind: Vector2) -> Vector2:
	if front == Vector2.INF or behind == Vector2.INF: return Vector2.INF
	var bounds: Rect2 = target.bounds
	var chosen: Vector2 = Vector2.INF
	var best: float = INF
	var first: Vector2i = _chunks.world_to_cell(bounds.position)
	var last: Vector2i = _chunks.world_to_cell(bounds.end)
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not reachable.has(cell) or not _chunks.is_cell_walkable(cell): continue
			var point: Vector2 = _chunks.cell_to_world_center(cell)
			var muzzle: Vector2 = point + point.direction_to(front) * 14.0
			if _target_strength(target, muzzle, muzzle.y) < 0.65 or point.distance_to(behind) < 44.0: continue
			if point.distance_squared_to(front) < best:
				chosen = point
				best = point.distance_squared_to(front)
	return chosen


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
	var record: Dictionary = _visual_frame(image, label + ".png")
	if label.begins_with("tree-"): _visual_tree_plates.append(record)
	else: _visual_home_plates.append(record)


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
	return {"file":file, "simulation_time":_combat_time, "phase":_phase, "player":str(_player.global_position), "camera":str(_camera.global_position), "camera_zoom":str(_camera.zoom), "window":str(get_window().size), "logical_viewport":str(get_viewport().get_visible_rect()), "canvas_transform":str(get_viewport().get_canvas_transform()), "chunk_center":str(_chunks._current_center), "player_fragments":player_fragments, "roof_inside_count":_roof._inside_count, "roof_alpha":(_roof.get_node("RoofPoly") as Polygon2D).modulate.a, "entities":entities}


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
	var state: Dictionary = _visual_tracks.get(key, {"kind":record.kind, "first_world":world, "distance":0.0, "covered":0, "exposed":0, "tree_covered":0, "tree_exposed":0, "first_covered":-1.0, "first_exposed":-1.0})
	state.distance = maxf(float(state.distance), world.distance_to(state.first_world))
	var positive_cover: bool = false
	for fragment: Dictionary in record.fragments:
		if not bool(fragment.on_image):
			continue
		var condition: String = "covered" if float(fragment.cover_strength) >= 0.65 else ("exposed" if float(fragment.cover_strength) <= 0.01 else "partial")
		positive_cover = positive_cover or float(fragment.cover_strength) > 0.01
		var count_key: String = String(record.kind) + "/" + condition
		_visual_counts[count_key] = int(_visual_counts.get(count_key, 0)) + 1
		if float(fragment.tree_strength) >= 0.65:
			state.tree_covered = int(state.tree_covered) + 1
			var tree_key: String = String(record.kind) + "/tree/covered"
			_visual_counts[tree_key] = int(_visual_counts.get(tree_key, 0)) + 1
		elif float(fragment.tree_strength) <= 0.01: state.tree_exposed = int(state.tree_exposed) + 1
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
		if String(track.kind) in ["ordinary", "elite"] and float(track.distance) >= 12.0 and int(track.covered) > 0 and int(track.exposed) > 0 and (_visual_phase != "tree" or (int(track.tree_covered) > 0 and int(track.tree_exposed) > 0)):
			moving_transitions.append({"instance_id":key, "kind":track.kind, "max_displacement":track.distance, "first_covered":track.first_covered, "first_exposed":track.first_exposed, "tree_covered":track.tree_covered, "tree_exposed":track.tree_exposed})
	if _visual_frames.is_empty():
		_fail("Visual probe recorded no actual live native frames")
	if moving_transitions.is_empty():
		_fail("Visual probe did not observe the same moving enemy body with covered and exposed opaque fragments")
	if not _visual_material_failures.is_empty():
		_fail("Actual visible consumers lost enabled shared cover: " + str(_visual_material_failures))
	if _visual_phase != "tree" and _visual_home_plates.size() != 3:
		_fail("Visual probe requires before/inside/restored native home plates")
	elif _visual_phase != "tree":
		if float(_visual_home_plates[0].roof_alpha) < 0.99 or int(_visual_home_plates[0].roof_inside_count) != 0:
			_fail("Visual home before-entry plate did not retain its actual opaque roof")
		if float(_visual_home_plates[1].roof_alpha) > 0.01 or int(_visual_home_plates[1].roof_inside_count) <= 0:
			_fail("Visual home interior plate did not show the physical player cutaway")
		if float(_visual_home_plates[2].roof_alpha) < 0.99 or int(_visual_home_plates[2].roof_inside_count) != 0:
			_fail("Visual home exit plate did not restore its actual opaque roof")
	if _visual_phase == "tree":
		if _visual_tree_plates.size() != 3: _fail("Tree phase requires native front/behind/restored plates")
		else:
			for index: int in range(3):
				var maximum: float = 0.0
				for fragment: Dictionary in _visual_tree_plates[index].player_fragments:
					if bool(fragment.on_image): maximum = maxf(maximum, float(fragment.tree_strength))
				if (index == 1 and maximum < 0.65) or (index != 1 and maximum > 0.01): _fail("Tree phase player did not achieve its actual covered/front-depth plate")
		for kind: String in ["equipment", "health"]:
			if int(_visual_counts.get(kind + "/tree/covered", 0)) <= 0 or int(_visual_counts.get(kind + "/exposed", 0)) <= 0: _fail("Tree phase lacks covered and exposed real " + kind + " icon fragments")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var file: FileAccess = FileAccess.open(_out.path_join("visual-cover-info.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"tool":"res://tools/dev/WorldCoverMovingVisualProbe.tscn", "scene":"res://scenes/game.tscn", "args":OS.get_cmdline_user_args(), "phase":_visual_phase, "phase_summary":_visual_phase_summary, "tree_fixture_attempts":_visual_tree_attempts, "tree_plates":_visual_tree_plates, "engine_max_fps":Engine.max_fps, "physics_ticks_per_second":Engine.physics_ticks_per_second, "counts":_visual_counts, "moving_enemy_transitions":moving_transitions, "material_failures":_visual_material_failures, "home_plates":_visual_home_plates, "frames":_visual_frames, "save_writes":SaveManager.debug_save_writes - _save_writes_before, "failures":_failures, "limits":"Default full phase extends the live CityMovingCoverPreview route and all its controls. Explicit home/tree phases independently bound live recording to30 simulation seconds, <=12 route frames plus3 phase plates, and yield80ms between post-route PNGs. They omit collection/inventory, mandatory stream-boundary and player fire/hit gates; those are never reported as passed. Initial player placement is staged near the actual doorway or verified real-tree front waypoint. Tree phase adds live Brute/Spitters and real locked covered/front pickups. Native player front/behind/front depth, tree-specific same-enemy opaque covered/exposed fragments, real windups/projectiles, original home roof entry/restoration, scheduler/producer activity, materials and saves remain asserted where applicable. Optional runtime-fps changes render cadence only; physics and AI stay live. The render cap is not performance evidence. Adds one ordinary live Brute plus real locked equipment/health pickups in reachable walkable cells of the generated home before entry. Pickup delay/lifetime is 120 seconds; monitoring is untouched. Scripted player fire pauses during home demonstration; enemy AI/scheduler/physics/spawning/streaming stay live. Enemy samples decode the actual renderer upload transform/atlas region and batch material, never the hidden Sprite2D transform. Covered/exposed counts are repeated source-opaque fragment observations, not unique actors or framebuffer color assertions. RGB samples include native scenery blending and overlap. Existing native render suites supply isolated compositing checks; the attached frames/plates require visual review. This route is not spontaneous placement, performance, balance or human-play acceptance."}, "\t"))
		file.close()
	else:
		_fail("Cannot write native visual cover manifest")
	print("WorldCoverMovingVisualProbe: frames=%d moving_body_transitions=%d home_plates=%d failures=%d" % [_visual_frames.size(), moving_transitions.size(), _visual_home_plates.size(), _failures])
	await super._shutdown()
