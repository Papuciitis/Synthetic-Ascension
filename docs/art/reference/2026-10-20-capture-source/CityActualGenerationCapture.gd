extends "res://.superpowers/sdd/2026-10-18-city-concept-captures/CityConceptCapture.gd"

func _run() -> void:
	_out = "res://docs/art/reference/2026-10-19-city-generation/before/"
	var seed_value := 16102026
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): _out = argument.trim_prefix("--out=")
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	SettingsManager.set_value(&"accessibility", &"combat_flash", "off", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	StoryDirector.cards_override = 0
	Global.apply_save(SaveData.new())
	Global.debug_dev_mode = true
	Global.debug_dev_segment = false
	Global.debug_player_god_mode = true
	Global.debug_encounter_beats = false
	Global.selected_style_id = "ranged"
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.attempt_world_seed = seed_value
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = PROJECT_VIEWPORT
	get_window().size = Vector2i(1280,720)
	Engine.max_fps = 60
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as Node2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_cm = _game.get_node("ChunkManager") as ChunkManager
	await _settle()
	_quiet_tutorials()
	_builder = get_tree().get_first_node_in_group(&"segment_proc_builder") as SegmentProcBuilder
	_builder.set_process(false)
	var roles: Dictionary = _cm.get("_chunk_role")
	var seen: Dictionary = {}
	for coord: Vector2i in roles:
		var role := String(roles[coord])
		if role not in ["secondary_reward_building","secondary_route","service_lane","district_fill","dangerous_alley","main_route"]: continue
		if int(seen.get(role,0)) >= (2 if role == "secondary_reward_building" else 1): continue
		seen[role] = int(seen.get(role,0))+1
		var at := (Vector2(coord)+Vector2(0.5,0.5))*float(_cm.chunk_size_px)
		await _visit(at)
		_cm.set_process(false)
		await _shot_pair("%s-%d" % [role,seen[role]], "Actual Game planned chunk; production topology, parcels and neighboring streaming unchanged", {"coord":str(coord),"role":role,"organic":_cm.organic_shapes_enabled})
		if role == "secondary_reward_building":
			var target_chunk: Node = _cm._chunks.get(coord)
			if target_chunk != null:
				for volume: Node in target_chunk.get_children():
					if volume is IndoorVolume and volume.secondary_objective_id > 0:
						_aim(volume.global_position+Vector2(0,160))
						await _shot_pair("required-building-close", "Actual required reward building at generated location; frozen outside state", {"building_id":volume.building_id,"secondary_id":volume.secondary_objective_id,"entry":str(volume.to_global(volume.get("_presentation_entry")))})
			await _visit(at+Vector2(1024,0))
			_cm.set_process(false)
			await _shot_pair("kit-east-boundary", "Actual boundary between selected kit and neighboring production chunk", {"coord":str(coord),"role":role})
	var file := FileAccess.open(_out.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":seed_value,"segment":2,"captures":_captures,"failures":_failures,"save_writes":SaveManager.debug_save_writes-_save_writes_before,"frozen":true},"\t"))
	file.close()
	print("CityActualGenerationCapture: captures=%d failures=%d save_writes=%d" % [_captures.size(),_failures,SaveManager.debug_save_writes-_save_writes_before])
	get_tree().current_scene = null
	_game.queue_free()
	await _frames(5)
	get_tree().quit(1 if _failures else 0)
