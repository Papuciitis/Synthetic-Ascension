extends "res://tools/dev/S10BossTelegraphPreview.gd"
## Frozen actual S2 architecture, not a human playtest or new world layout.
var _cm: ChunkManager
var _builder: SegmentProcBuilder
var _scene_notes: Array[Dictionary] = []

func _enter_tree() -> void:
	super._enter_tree()
	_out = "res://docs/art/concepts/2026-10-18-city-directions/current-game-captures/"
	SaveManager.save_dir = "user://tests/city_concept_capture_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"

func _run() -> void:
	get_tree().create_timer(145.0).timeout.connect(func() -> void:
		_fail("bounded city capture timeout")
		get_tree().quit(1))
	if DisplayServer.get_name() == "headless":
		_fail("native renderer required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	SettingsManager.set_value(&"accessibility", &"combat_flash", "off", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	AudioServer.set_bus_mute(0, true)
	StoryDirector.cards_override = 0
	Global.apply_save(SaveData.new())
	Global.debug_dev_mode = true
	Global.debug_dev_segment = false
	Global.debug_player_god_mode = true
	Global.debug_encounter_beats = false
	Global.selected_style_id = "ranged"
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.attempt_world_seed = WORLD_SEED
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	get_window().title = "Synthetic Ascension — frozen current S2 city architecture"
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = PROJECT_VIEWPORT
	get_window().content_scale_factor = 1.0
	get_window().size = Vector2i(1280, 720)
	Engine.max_fps = 60
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as Node2D
	_player.set("collision_layer", 0)
	_player.set("collision_mask", 0)
	_camera = _player.get_node("Camera2D") as Camera2D
	_cm = _game.get_node("ChunkManager") as ChunkManager
	await _settle()
	_quiet_tutorials()
	get_tree().paused = false
	_builder = get_tree().get_first_node_in_group(&"segment_proc_builder") as SegmentProcBuilder
	if _builder == null:
		_fail("S2 production builder missing")
		get_tree().quit(1)
		return
	_builder.set_process(false)
	for group: StringName in [&"primary_objective", &"secondary_objective", &"wardstones", &"exit_rite"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			node.process_mode = Node.PROCESS_MODE_DISABLED
	for singleton: String in ["EnemySimulationScheduler", "EnemyIndex", "ThreatDirector", "EnemyWorld", "EnemyCombat", "EnemyStatus", "ProjectileManager", "HitFeel"]:
		var service := get_node_or_null("/root/" + singleton)
		if service != null:
			service.set_process(false)
			service.set_physics_process(false)
	await _visit(Vector2(3072, 19456))
	var street := _choose_street(Vector2(3072, 19456))
	_player.global_position = street
	_aim(street)
	await _settle()
	_cm.set_process(false)
	var visible_roofs := _roof_count(street)
	if visible_roofs < 2:
		_fail("street frame has fewer than two actual building roofs")
	await _shot_pair("city-street-junction", "Actual generated street near planned S2 cache; camera selected among existing walkable cells to frame multiple buildings", {"visible_roofs": visible_roofs})
	var requested_id := 0
	var building_world := Vector2(544, 18944)
	for info: Dictionary in _builder.get("_secondary_objectives"):
		if String(info.get("type", "")) == "searchable_reward_building":
			requested_id = int(info.get("id", 0))
			building_world = info.get("world", building_world)
			break
	await _visit(building_world)
	var target: IndoorVolume
	for volume: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if requested_id > 0 and int(volume.get("secondary_objective_id")) == requested_id:
			target = volume as IndoorVolume
			break
	if target == null:
		_fail("actual planned searchable building IndoorVolume missing")
	else:
		var center := target.global_position
		var doorway: Vector2 = target.to_global(target.get("_presentation_entry"))
		var outward: Vector2 = target.get("_presentation_outward")
		var approach := _nearest_walkable(doorway + outward * 128.0)
		_player.global_position = approach
		_aim(center)
		await _settle()
		_cm.set_process(false)
		var metadata := {"building_id": target.building_id, "secondary_objective_id": target.secondary_objective_id, "building_center": str(center), "doorway_world": str(doorway), "outward": str(outward), "size_cells": str(target.size_cells)}
		await _shot_pair("searchable-building-exterior", "Actual generated searchable parcel, roof outside state, real doorway approach; no authored replacement geometry", metadata)
		_player.global_position = _nearest_walkable(center, target)
		_aim(center)
		target.body_entered.emit(_player)
		await _frames(35)
		for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
			_freeze(enemy)
		var roof_states: Array[Dictionary] = []
		for connection: Dictionary in target.body_entered.get_connections():
			var callback: Callable = connection["callable"]
			var owner := callback.get_object()
			if owner is RoofOverlay:
				var roof := owner as RoofOverlay
				var alpha := float((roof.get_node("RoofPoly") as Polygon2D).modulate.a)
				roof_states.append({"inside_count": int(roof.get("_inside_count")), "alpha": alpha})
				if alpha > 0.01:
					_fail("actual building roof did not finish fading")
		if roof_states.is_empty():
			_fail("searchable building has no connected production roof")
		metadata["roof_states"] = roof_states
		metadata["actual_local_encounter_nodes"] = (target.get("_encounter_enemy_ids") as Array).size()
		await _shot_pair("searchable-building-interior", "Same actual parcel and camera center; production body_entered signal starts real local security and fades actual roof, then frozen; no human-played combat", metadata)
	var writes := SaveManager.debug_save_writes - _save_writes_before
	if writes != 0 or SaveManager.current_save != null:
		_fail("unexpected profile write or selection")
	var manifest := {"scene": "res://scenes/game.tscn", "capture_scene": get_scene_file_path(), "presentation": "FROZEN CURRENT GAME; controlled camera/player placement in actual generated S2; not human-played", "world_seed": WORLD_SEED, "segment": 2, "viewport": str(PROJECT_VIEWPORT), "camera_zoom": str(_camera.zoom), "camera_rotation": _camera.rotation, "reduced_motion": true, "combat_flash": "off", "appdata": OS.get_environment("APPDATA"), "localappdata": OS.get_environment("LOCALAPPDATA"), "save_directory": SaveManager.save_dir, "save_writes": writes, "failures": _failures, "captures": _captures, "notes": _scene_notes}
	var file := FileAccess.open(_out.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		_fail("could not save capture manifest")
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	print("CityConceptCapture: captures=%d failures=%d save_writes=%d" % [_captures.size(), _failures, writes])
	get_tree().current_scene = null
	_game.queue_free()
	await _frames(5)
	get_tree().quit(1 if _failures > 0 else 0)

func _settle() -> void:
	for frame in range(360):
		await get_tree().process_frame
		if frame >= 25 and _cm.debug_chunk_queue().is_empty() and _cm.pending_blocker_stage_count() == 0:
			return
	_fail("world streaming did not settle")

func _visit(at: Vector2) -> void:
	_cm.set_process(true)
	_player.global_position = at + Vector2(0, 700)
	_aim(at)
	await _settle()
	await _frames(12)
	_quiet_tutorials()
	get_tree().paused = false
	for volume: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if volume is Area2D:
			(volume as Area2D).monitoring = false
	for pickup: Node in get_tree().get_nodes_in_group(GroundLootCap.ITEM_GROUP):
		pickup.process_mode = Node.PROCESS_MODE_DISABLED

func _aim(at: Vector2) -> void:
	_camera.position = at - _player.global_position
	_camera.rotation = 0.0
	_camera.reset_smoothing()
	_camera.force_update_scroll()

func _nearest_walkable(at: Vector2, within: IndoorVolume = null) -> Vector2:
	var base := _cm.world_to_cell(at)
	for ring in range(14):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if ring > 0 and absi(dx) != ring and absi(dy) != ring:
					continue
				var cell := base + Vector2i(dx, dy)
				var point: Vector2 = _cm.cell_to_world_center(cell)
				if _cm.is_cell_walkable(cell) and (within == null or within.contains_world_point(point)):
					return point
	_fail("no loaded walkable capture position near " + str(at))
	return at

func _roof_boxes() -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	for node: Node in _game.find_children("*", "", true, false):
		var roof := node as RoofOverlay
		if roof == null or roof.footprint_outline_px.is_empty():
			continue
		var outline := roof.footprint_outline_px
		var rect := Rect2(roof.to_global(outline[0]), Vector2.ZERO)
		for point: Vector2 in outline:
			rect = rect.expand(roof.to_global(point))
		boxes.append(rect)
	return boxes

func _roof_count(at: Vector2) -> int:
	var count := 0
	var view := Rect2(at - Vector2(840, 430), Vector2(1680, 860))
	for rect: Rect2 in _roof_boxes():
		if view.intersection(rect).get_area() > 12000.0:
			count += 1
	return count

func _choose_street(near: Vector2) -> Vector2:
	var best := _nearest_walkable(near)
	var best_score := -INF
	for dy in [-512, -256, 0, 256, 512]:
		for dx in [-512, -256, 0, 256, 512]:
			var candidate := _nearest_walkable(near + Vector2(dx, dy))
			var score := float(_roof_count(candidate)) * 100.0 - candidate.distance_to(near) * 0.01
			if score > best_score:
				best = candidate
				best_score = score
	return best

func _shot_pair(key: String, note: String, metadata: Dictionary) -> void:
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = dimensions
		_camera.force_update_scroll()
		var proxy := get_tree().get_first_node_in_group(&"enemy_proxy_root")
		var drawn := 0
		if proxy != null and proxy.get("renderer") != null:
			drawn = int(proxy.get("renderer").call("publish"))
		await _frames(6)
		await RenderingServer.frame_post_draw
		var filename := "%s-%dx%d.png" % [key, dimensions.x, dimensions.y]
		var pixels := get_viewport().get_texture().get_image()
		if pixels.get_size() != dimensions or pixels.save_png(_out.path_join(filename)) != OK:
			_fail("native capture failed " + filename)
		_captures.append({"file": filename, "panel": key, "window": str(dimensions), "camera_center": str(_camera.global_position), "player_position": str(_player.global_position), "proxy_published_instances": drawn, "note": note, "metadata": metadata.duplicate(true)})
		print("CITY_CAPTURE ", filename, " camera=", _camera.global_position, " player=", _player.global_position)
