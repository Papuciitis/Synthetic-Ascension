extends "res://tools/dev/CityEntityCoverPreview.gd"
## A bounded actual-Game route: normal ambient spawning, streaming, scheduled
## enemies and pickup eligibility stay live. Only initial player/enemy/item
## placement, god mode and input/aim are controlled. No reload/freeze fixture.
## -- --world-seed=16102026 --target-building-id=944996572 --target-chunk=0,3
##    --review=small --out=<fresh directory>

var _live_recording := false
var _live_grabbing := false
var _live_last_sample := 0.0
var _live_start := 0
var _live_distance := 0.0
var _live_last_player := Vector2.ZERO
var _live_centers: Array[String] = []
var _live_spawns: Dictionary = {}
var _live_spawn_requests := 0
var _live_projectile_covered := 0
var _live_projectile_exposed := 0
var _live_tell_covered := 0
var _live_tell_exposed := 0
var _live_tree: Dictionary = {}
var _live_staging: Array[Dictionary] = []
var _live_first_crossings: Array[Dictionary] = []
var _live_pickup: WeakRef
var _live_pickup_state: Dictionary = {}
var _live_pickup_instance: ItemInstance
var _live_scheduler_start: Dictionary = {}
var _live_flags_ok := true


func _run() -> void:
	if DisplayServer.get_name() == "headless" or _target_building_id <= 0 or not _has_target_chunk:
		_fail("Moving evidence requires native rendering and an explicit actual home/chunk")
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
	get_window().title = "Synthetic Ascension — moving occupied cover route"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out.path_join("frames")))
	_game = GAME.instantiate() as Node2D
	# The only initial process hold is the player's, while its destination
	# streams. The spawner, procedural director, chunk manager and scheduler
	# keep their production process modes from scene creation through recording.
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
	var warp := (Vector2(_target_chunk) + Vector2.ONE * 0.5) * _chunks.chunk_size_px + Vector2(0, 600)
	_player.global_position = warp
	await _settle()
	_dismiss_dossiers()
	for node: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if node is IndoorVolume and _matches_volume(node as IndoorVolume, _target_building_id):
			_volume = node as IndoorVolume
			break
	if _volume == null:
		_fail("Explicit home failed to stream with its real producer active")
		await _shutdown()
		return
	for connection: Dictionary in _volume.body_entered.get_connections():
		var subscriber: Object = (connection.callable as Callable).get_object()
		if subscriber is RoofOverlay: _roof = subscriber as RoofOverlay
	for kit: Node in get_tree().get_nodes_in_group(&"city_block_building"):
		if kit.get("_roof") == _roof: _evidence_kit = kit as Node2D
	if _roof == null or _evidence_kit == null:
		_fail("Actual home lost its roof/kit ownership")
		await _shutdown()
		return
	_evidence_cover = COVER_PROVIDER.get_for(_player)
	var door := _volume.to_global(_volume.get("_presentation_entry"))
	var outward: Vector2 = _volume.get("_presentation_outward")
	_live_tree = _tree_target()
	var front := _free_spawn_position(door + outward * 224.0)
	if not _live_tree.is_empty():
		# Start on the real tree's front street so the first live windup and
		# projectile crossing are inside the normal moving camera, not offscreen.
		front = _free_spawn_position((_live_tree.ground_world as Vector2) + Vector2(0, 224))
	_player.global_position = front
	_live_staging.append({"kind":"player initial warp", "streaming_destination":str(warp), "recording_start":str(front), "actual_home_door":str(door)})
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(4)
	_stage_ordinary_pickup(front + Vector2(256, 0))
	await _frames(75) # The real one-second dropped-instance arming delay.
	if _live_pickup != null:
		var pickup := _live_pickup.get_ref() as ItemPickup
		if pickup != null:
			_live_pickup_state["armed"] = pickup._pickup_ready
			_live_pickup_state["monitoring"] = pickup.monitoring
			_live_pickup_state["start_distance"] = pickup.global_position.distance_to(_player.global_position)
	_live_scheduler_start = EnemySimulationScheduler.get_debug_counters()
	_live_last_player = _player.global_position
	_live_start = Time.get_ticks_usec()
	_live_recording = true
	_stage_live_shooters()
	_phase = "live tells and exposed controls"
	# Let the staged ordinary shooters complete real windups before player fire.
	await _live_wait(2.5)
	_phase = "ordinary pickup collection"
	var pickup_node := _live_pickup.get_ref() as ItemPickup if _live_pickup != null else null
	if pickup_node != null: await _walk_to(pickup_node.global_position)
	await _live_wait(1.5)
	_phase = "tree foreground crossing"
	if not _live_tree.is_empty():
		var reachable := _player_reachable_cells()
		var samples := _player_fragment_samples()
		var behind := _player_tree_waypoint(_live_tree, reachable, samples, true)
		var ahead := _player_tree_waypoint(_live_tree, reachable, samples, false)
		if behind != Vector2.INF: await _walk_to(behind)
		else: _fail("No reachable actual canopy crossing point")
		await _live_wait(1.0)
		if ahead != Vector2.INF: await _walk_to(ahead)
	_phase = "actual doorway cutaway"
	await _walk_to(door + outward * 96.0)
	await _walk_to(door - outward * float(_chunks.cell_size_px))
	await _live_wait(0.6)
	var inside := _roof._inside_count > 0 and (_roof.get_node("RoofPoly") as Polygon2D).modulate.a < 0.01
	if not inside: _fail("Live player entry failed to open actual roof")
	await _walk_to(door + outward * 160.0)
	await _live_wait(0.6)
	var restored := _roof._inside_count == 0 and (_roof.get_node("RoofPoly") as Polygon2D).modulate.a > 0.99
	if not restored: _fail("Live exit failed to restore actual roof")
	_phase = "active chunk boundary crossing"
	var crossing := Vector2(-96.0 if _target_chunk.x == 0 else float(_target_chunk.x) * _chunks.chunk_size_px - 96.0, _player.global_position.y)
	await _walk_to(crossing)
	await _live_wait(1.5)
	var boundary_arrived := _player.global_position.x < float(_target_chunk.x)*_chunks.chunk_size_px and _chunks._current_center.x == _target_chunk.x-1
	if not boundary_arrived: _fail("Mandatory westbound owning-chunk boundary arrival was not reached")
	_live_recording = false
	var route_wall_seconds := float(Time.get_ticks_usec() - _live_start) / 1000000.0
	var encoding_started := Time.get_ticks_usec()
	_release_inputs()
	# Readback occurred at a bounded cadence during live play. Encoding starts
	# only after the route; these timings are not a performance benchmark.
	get_tree().paused = true
	var scheduler_end := EnemySimulationScheduler.get_debug_counters()
	var writes := SaveManager.debug_save_writes - _save_writes_before
	var ambient := int(_live_spawns.get("ambient", 0))
	if ambient <= 0: _fail("No ordinary ambient spawn resolved during live route")
	if _live_centers.size() < 2: _fail("No active streaming center transition was observed")
	if not _live_flags_ok: _fail("A required live producer stopped processing during recording")
	if scheduler_end == _live_scheduler_start: _fail("Scheduled simulation counters did not advance")
	if not bool(_live_pickup_state.get("picked", false)): _fail("Ordinary staged item was not collected by production eligibility/magnet/contact")
	var inventory_received := _inventory_has_staged_instance()
	if not inventory_received: _fail("Collected ordinary instance is absent from inventory and bag")
	if _live_projectile_covered <= 0 or _live_projectile_exposed <= 0: _fail("Live projectile samples did not include both actual foreground cover and exposed controls")
	if _live_tell_covered <= 0 or _live_tell_exposed <= 0: _fail("Live visible ordinary windups did not include covered and exposed controls")
	if _weapon_fires <= 0 or _player_hits <= 0: _fail("The moving player did not fire and land real attacks")
	if writes != 0 or SaveManager.current_save != null: _fail("Moving capture selected or wrote a profile")
	for index in range(_pixels.size()):
		_save_image(_pixels[index], _out.path_join("frames/frame-%04d.png" % index))
		if index % 16 == 0: await get_tree().process_frame
	if not _pixels.is_empty():
		_save_image(_pixels[0], _out.path_join("moving-opening.png"))
		_save_image(_pixels[floori(float(_pixels.size()) * 0.5)], _out.path_join("moving-midpoint.png"))
		_save_image(_pixels.back(), _out.path_join("moving-ending.png"))
	var report := {"capture_scene":"res://tools/dev/CityMovingCoverPreview.tscn", "scene":"res://scenes/game.tscn", "args":OS.get_cmdline_user_args(), "world_seed":_city_world_seed, "segment":_city_segment, "building_id":_target_building_id, "chunk":str(_target_chunk), "image_size":str(get_window().size), "viewport":str(PROJECT_VIEWPORT), "camera_zoom":str(_camera.zoom), "simulation_seconds":_combat_time, "wall_seconds":route_wall_seconds, "encoding_wall_seconds":float(Time.get_ticks_usec()-encoding_started)/1000000.0, "distance_walked":_live_distance, "chunk_centers":_live_centers, "mandatory_west_boundary_arrived":boundary_arrived, "ambient_spawned":ambient, "spawned_by_source":_live_spawns, "spawn_requests":_live_spawn_requests, "scheduler_start":_live_scheduler_start, "scheduler_end":scheduler_end, "producers_stayed_live":_live_flags_ok, "projectile_covered_observations":_live_projectile_covered, "projectile_exposed_observations":_live_projectile_exposed, "tell_covered_observations":_live_tell_covered, "tell_exposed_observations":_live_tell_exposed, "weapon_fires":_weapon_fires, "player_hits":_player_hits, "enemy_deaths":_deaths, "max_projectiles":_max_projectiles, "ordinary_pickup":_live_pickup_state, "inventory_received_staged_instance":inventory_received, "inside_cutaway":inside, "outside_restored":restored, "staging":_live_staging, "first_foreground_crossings":_live_first_crossings, "route":_route_notes, "frames":_capture_info, "save_writes":writes, "failures":_failures, "limits":"Initial player warp and two ordinary live Spitters plus one ordinary ring instance are staged; god mode and native scripted movement/aim/fire are enabled. Modal dossier onboarding is bypassed. Ambient spawner, encounter beats, procedural director, chunk streaming, enemy scheduler, collisions, pickup delay/eligibility/magnet/collection, real combat and normal HUD remain active. No never_cull metadata, actor freeze, pickup monitoring override or direct collection call. Camera follows the moving player. Low-rate framebuffer readback and post-route encoding make this visual/gameplay evidence, not a performance or human-play acceptance test. Counts are sampled on-screen observations, not unique projectiles/tells."}
	var output := FileAccess.open(_out.path_join("capture-info.json"), FileAccess.WRITE)
	if output == null: _fail("Cannot write moving capture manifest")
	else:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	print("CityMovingCoverPreview: frames=%d sim=%.2f distance=%.1f ambient=%d covered_projectiles=%d covered_tells=%d collected=%s failures=%d save_writes=%d" % [_pixels.size(), _combat_time, _live_distance, ambient, _live_projectile_covered, _live_tell_covered, str(inventory_received), _failures, writes])
	AudioManager.stop_all(true)
	await _shutdown()


func _stage_live_shooters() -> void:
	if _live_tree.is_empty(): return
	var bounds: Rect2 = _live_tree.bounds
	var chosen := Vector2.INF
	var best := INF
	var first := _chunks.world_to_cell(bounds.position)
	var last := _chunks.world_to_cell(bounds.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			if not _chunks.is_cell_walkable(cell): continue
			var point := _chunks.cell_to_world_center(cell)
			var muzzle := point + point.direction_to(_player.global_position) * 14.0
			if _target_strength(_live_tree, muzzle, muzzle.y) < 0.65: continue
			var distance := point.distance_squared_to(_player.global_position)
			if distance < best:
				best = distance
				chosen = point
	if chosen == Vector2.INF:
		_fail("No walkable actual tree cover point for live shooter")
		return
	var covered := _spawn_actor("Spitter", chosen)
	_live_staging.append({"kind":"ordinary live Spitter", "world":str(covered.global_position), "source_cover":_target_strength(_live_tree, covered.global_position, covered.global_position.y), "frozen":false})
	var exposed := _spawn_actor("Spitter", _player.global_position + Vector2(-224, 96))
	_live_staging.append({"kind":"ordinary exposed live Spitter", "world":str(exposed.global_position), "frozen":false})


func _stage_ordinary_pickup(desired: Vector2) -> void:
	var data := Global.get_item_data("ring_crusher")
	if data == null:
		_fail("Missing real ordinary ring item")
		return
	var pickup := ITEM_SCENE.instantiate() as ItemPickup
	_live_pickup_instance = ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.25, false)
	pickup.item_instance = _live_pickup_instance
	pickup.position = _free_spawn_position(desired)
	_game.add_child(pickup)
	_live_pickup = weakref(pickup)
	_live_pickup_state = {"item_id":data.id, "world":str(pickup.global_position), "instance_id":_live_pickup_instance.get_instance_id(), "ground_serial":pickup.ground_serial, "delay":pickup.pickup_delay, "exploration":pickup.is_exploration_loot, "persistent":pickup.persistent_world_drop, "choice_group":pickup.choice_group, "picked":false}
	pickup.tree_exiting.connect(func() -> void:
		_live_pickup_state["picked"] = pickup._picked
		_live_pickup_state["collection_player_world"] = str(_player.global_position)
		_live_pickup_state["collection_distance"] = pickup.global_position.distance_to(_player.global_position)
		_live_pickup_state["collection_simulation_time"] = _combat_time
	)


func _inventory_has_staged_instance() -> bool:
	for slot in range(Inventory.SLOT_COUNT):
		if Global.run_inventory.get_at(slot) == _live_pickup_instance: return true
	for instance: ItemInstance in Global.run_bag.slots:
		if instance == _live_pickup_instance: return true
	return false


func _on_live_spawn(source: StringName, _outcome: StringName, count: int, _data: Dictionary) -> void:
	if not _live_recording: return
	_live_spawn_requests += 1
	_live_spawns[String(source)] = int(_live_spawns.get(String(source), 0)) + count


func _live_wait(seconds: float) -> void:
	var until := _combat_time + seconds
	while _combat_time < until:
		await get_tree().physics_frame
		if get_tree().paused:
			_fail("Unexpected modal paused ordinary moving route")
			return


func _physics_process(delta: float) -> void:
	if not _live_recording: return
	_combat_time += delta
	_live_distance += _player.global_position.distance_to(_live_last_player)
	_live_last_player = _player.global_position
	var aim := _aim_at_live_enemy()
	_set_axis(&"aim_left", &"aim_right", aim.x)
	_set_axis(&"aim_up", &"aim_down", aim.y)
	if _combat_time > 2.5: Input.action_press(&"attack")
	_max_projectiles = maxi(_max_projectiles, ProjectileManager.active_count())


func _process(_delta: float) -> void:
	if _camera != null and is_instance_valid(_camera) and _player != null:
		_camera.global_position = _player.global_position + Vector2(140, -160)
		_camera.rotation = 0.0
	if not _live_recording: return
	if _combat_time - _live_last_sample >= 0.1:
		_live_last_sample = _combat_time
		_sample_live_depth()
	if not _live_grabbing and Time.get_ticks_usec() >= _next_usec:
		_live_grabbing = true
		_grab_live.call_deferred()


func _sample_live_depth() -> void:
	var center := str(_chunks._current_center)
	if _live_centers.is_empty() or _live_centers.back() != center: _live_centers.append(center)
	var builder := get_tree().get_first_node_in_group(&"segment_proc_builder")
	var spawner := _game.get_node("Spawner")
	_live_flags_ok = _live_flags_ok and _chunks.is_processing() and EnemySimulationScheduler.is_physics_processing() and spawner.process_mode != Node.PROCESS_MODE_DISABLED and builder != null and builder.is_processing()
	var points: PackedVector2Array = ProjectileManager.get("_positions")
	for index in range(mini(ProjectileManager.active_count(), 16)):
		var point := points[index]
		if not get_viewport().get_visible_rect().has_point(get_viewport().get_canvas_transform() * point): continue
		var strength := float(_evidence_cover.call("strength_at", point, point.y))
		if strength > 0.5:
			_live_projectile_covered += 1
			if _live_projectile_covered == 1:
				_next_usec = 0
				_live_first_crossings.append({"kind":"visible projectile", "world":str(point), "strength":strength, "tree_source_strength":_target_strength(_live_tree,point,point.y), "simulation_time":_combat_time})
		elif strength < 0.01: _live_projectile_exposed += 1
	var checked := 0
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var actor := node as EnemyActor
		if actor == null or actor.dead or actor.global_position.distance_squared_to(_player.global_position) > 900.0 * 900.0: continue
		checked += 1
		var tell := actor.find_child("ShotWindup", true, false) as VFX_EnemyShotWindup
		if tell == null:
			for child: Node in actor.get_children():
				if child is VFX_EnemyShotWindup: tell = child as VFX_EnemyShotWindup
		if tell != null and tell.visible:
			var muzzle := tell.to_global(tell.get("_dir") * 14.0)
			if not get_viewport().get_visible_rect().has_point(get_viewport().get_canvas_transform() * muzzle): continue
			var strength := float(_evidence_cover.call("strength_at", muzzle, muzzle.y))
			if strength > 0.5:
				_live_tell_covered += 1
				if _live_tell_covered == 1:
					_next_usec = 0
					_live_first_crossings.append({"kind":"visible ordinary windup", "world":str(muzzle), "actor":str(actor.get_path()), "strength":strength, "tree_source_strength":_target_strength(_live_tree,muzzle,muzzle.y), "simulation_time":_combat_time})
			elif strength < 0.01: _live_tell_exposed += 1
		if checked >= 24: break


func _grab_live() -> void:
	await RenderingServer.frame_post_draw
	if _live_recording:
		var image := get_viewport().get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		_pixels.append(image)
		_capture_info.append({"simulation_time":_combat_time, "wall_time":float(Time.get_ticks_usec()-_live_start)/1000000.0, "phase":_phase, "player_world":str(_player.global_position), "camera_world":str(_camera.global_position), "chunk_center":str(_chunks._current_center), "loaded_chunks":_chunks.loaded_chunk_count(), "queued_chunks":_chunks.debug_chunk_queue().size(), "enemies":EnemyWorld.active_count(), "projectiles":ProjectileManager.active_count(), "covered_tell_observations":_live_tell_covered, "covered_projectile_observations":_live_projectile_covered, "ordinary_picked":bool(_live_pickup_state.get("picked", false))})
	_next_usec = Time.get_ticks_usec() + 250000
	_live_grabbing = false


func _walk_to(desired: Vector2, strict_perimeter: bool = false) -> void:
	# Route goals are walkable cell centers, not enemy-spawn reservations.
	# A shooter staged here earlier may already be hundreds of pixels away.
	var goal := _chunks.world_to_cell(desired)
	if not _chunks.is_cell_walkable(goal):
		var found := false
		for radius in range(1,7):
			for y in range(-radius,radius+1):
				for x in range(-radius,radius+1):
					if maxi(absi(x),absi(y)) != radius: continue
					var candidate := goal + Vector2i(x,y)
					if _chunks.is_cell_walkable(candidate):
						goal = candidate
						found = true
						break
				if found: break
			if found: break
		if not found:
			_fail("No walkable mandatory route destination near " + str(desired))
			return
	var resolved := _chunks.cell_to_world_center(goal)
	if strict_perimeter and resolved.distance_to(desired) > 64:
		_fail("Mandatory perimeter destination moved outside its intended cell")
		return
	var blocked: Dictionary = {}
	var reached := false
	var walked_cells := 0
	var retries: Array[Dictionary] = []
	for attempt in range(9):
		var start := _chunks.world_to_cell(_player.global_position)
		if _player.global_position.distance_to(resolved) < 8:
			reached = true
			break
		var path := _live_path(start,goal,blocked)
		if path.is_empty() and start != goal:
			retries.append({"attempt":attempt,"event":"no alternative grid path","world":str(_player.global_position)})
			if not await _live_sidestep(resolved,blocked): break
			continue
		if path.is_empty(): path.append(goal)
		var obstructed := false
		for cell: Vector2i in path:
			walked_cells += 1
			if await _live_step(_chunks.cell_to_world_center(cell)):
				continue
			var contacts: Array[Dictionary] = []
			for index in range(_player.get_slide_collision_count()):
				var collision := _player.get_slide_collision(index)
				var collider: Object = collision.get_collider()
				var identity := str(collider)
				if collider is Node and is_instance_valid(collider) and (collider as Node).is_inside_tree():
					identity = str((collider as Node).get_path())
				contacts.append({"collider":identity,"class":collider.get_class() if is_instance_valid(collider) else "freed", "position":str(collision.get_position()), "normal":str(collision.get_normal())})
			retries.append({"attempt":attempt,"event":"physical obstruction","cell":str(cell),"world":str(_player.global_position),"remaining":_player.global_position.distance_to(_chunks.cell_to_world_center(cell)),"contacts":contacts})
			# Replan around the actually obstructed cell. The final goal itself
			# remains mandatory and can be retried after an input-driven sidestep.
			if cell != goal: blocked[cell] = true
			obstructed = true
			break
		if not obstructed and _player.global_position.distance_to(resolved) < 8:
			reached = true
			break
		if not await _live_sidestep(resolved,blocked): break
	_release_inputs()
	_route_notes.append({"event":"walk","phase":_phase,"desired":str(desired),"resolved":str(resolved),"resolution_distance":resolved.distance_to(desired),"arrived":str(_player.global_position),"arrival_distance":_player.global_position.distance_to(resolved),"destination_reached":reached,"path_cells":walked_cells,"replans":retries})
	if not reached:
		_fail("Mandatory live route destination was not reached after bounded replanning: " + str(goal))


func _live_path(start: Vector2i, goal: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	var previous: Dictionary = {start:start}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size() and not previous.has(goal):
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next := cell + direction
			if previous.has(next) or blocked.has(next) or absi(next.x-start.x)>40 or absi(next.y-start.y)>40 or not _chunks.is_cell_walkable(next): continue
			previous[next] = cell
			queue.append(next)
	var path: Array[Vector2i] = []
	if not previous.has(goal): return path
	var cell := goal
	while cell != start:
		path.push_front(cell)
		cell = previous[cell]
	return path


func _live_step(target: Vector2) -> bool:
	var last_progress := _player.global_position
	var still_ticks := 0
	for tick in range(120):
		var movement := target - _player.global_position
		if movement.length() < 8: return true
		var axis := movement.normalized()
		_set_axis(&"move_left",&"move_right",axis.x)
		_set_axis(&"move_up",&"move_down",axis.y)
		await get_tree().physics_frame
		if get_tree().paused: return false
		if _player.global_position.distance_to(last_progress) < 1.0:
			still_ticks += 1
		else:
			still_ticks = 0
			last_progress = _player.global_position
		if still_ticks >= 30: return false
	return false


func _live_sidestep(goal: Vector2, blocked: Dictionary) -> bool:
	# Test the actual unchanged player capsule against current physical bodies;
	# select one clear nearby step, then perform it using production input.
	var current := _chunks.world_to_cell(_player.global_position)
	var best := Vector2.INF
	var best_score := INF
	for direction: Vector2i in [Vector2i.DOWN,Vector2i.UP,Vector2i.RIGHT,Vector2i.LEFT,Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
		var cell := current + direction
		if blocked.has(cell) or not _chunks.is_cell_walkable(cell): continue
		var point := _chunks.cell_to_world_center(cell)
		if _player.test_move(_player.global_transform,point-_player.global_position): continue
		var score := point.distance_to(goal)
		if score < best_score:
			best_score = score
			best = point
	if best == Vector2.INF:
		# Keep native aim/fire active briefly so live enemies can move/die. This
		# is a bounded retry, not collision suppression or an arrival shortcut.
		_set_axis(&"move_left",&"move_right",0)
		_set_axis(&"move_up",&"move_down",0)
		await _live_wait(0.5)
		return true
	await _live_step(best)
	return true
