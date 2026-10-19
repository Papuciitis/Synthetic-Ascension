extends "res://tools/dev/EliteCrowdFightPreview.gd"
## Isolated actual-Game first-block traversal and live fight. No profile writes.
## -- --review=normal|small|reduced|before [--segment=2] [--world-seed=16102026] [--visible] [--playable]

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
var _review := "normal"
var _city_world_seed := 16102026
var _city_segment := 2
var _playable := false
var _district_common_base := false
var _hide_district_details := false
var _still_only := false
var _entry_only := false
var _target_building_id := 0
var _target_chunk := Vector2i.ZERO
var _has_target_chunk := false
var _phase := "loading"
var _recording := false
var _grabbing := false
var _next_usec := 0
var _began_usec := 0
var _volume: IndoorVolume
var _roof: RoofOverlay
var _route_notes: Array[Dictionary] = []
var _frame_times: Array[float] = []
var _initial_population := 0
var _clearing_interior := false
var _interior_fight_time := 0.0

func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--review="): _review = arg.trim_prefix("--review=")
		if arg.begins_with("--world-seed="): _city_world_seed = int(arg.trim_prefix("--world-seed="))
		if arg.begins_with("--seed="): _city_world_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--segment="): _city_segment = maxi(2, int(arg.trim_prefix("--segment=")))
		if arg == "--playable": _playable = true
		if arg == "--district-common-base": _district_common_base = true
		if arg == "--hide-district-details": _hide_district_details = true
		if arg == "--still-only": _still_only = true
		if arg == "--entry-only": _entry_only = true
		if arg.begins_with("--target-building-id="): _target_building_id = int(arg.trim_prefix("--target-building-id="))
		if arg.begins_with("--target-chunk="):
			var parts := arg.trim_prefix("--target-chunk=").split(",")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				_target_chunk = Vector2i(int(parts[0]),int(parts[1]))
				_has_target_chunk = true
	if _out == "user://dev_previews/elite_crowd_fight":
		_out = "res://docs/art/reference/2026-10-18-city-block/" + _review
	KIT.preview_original_materials = _review == "before"

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Native renderer is required")
		get_tree().quit(1)
		return
	_prepare_runtime()
	Global.attempt_segment = _city_segment
	Global.attempt_world_seed = _city_world_seed
	Global.debug_player_god_mode = not _playable
	_reduced_motion = _review == "reduced"
	SettingsManager.set_value(&"accessibility", &"reduced_motion", _reduced_motion, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", "off" if _reduced_motion else "full", false)
	get_window().size = Vector2i(960, 540) if _review in ["small", "reduced"] else Vector2i(1280, 720)
	_game = GAME.instantiate() as Node2D
	(_game.get_node("ChunkManager") as ChunkManager).district_common_base_preview = _district_common_base
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.top_level = true
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	await _settle()
	_dismiss_dossiers()
	var builder := get_tree().get_first_node_in_group(&"segment_proc_builder")
	if builder == null:
		_fail("Missing production segment builder")
		await _shutdown()
		return
	builder.set_process(false)
	var building_id := 0
	var destination := Vector2(544, 18944)
	if _target_building_id > 0:
		if not _has_target_chunk:
			_fail("Explicit building sample requires its actual chunk")
			await _shutdown()
			return
		destination = (Vector2(_target_chunk)+Vector2.ONE*0.5)*_chunks.chunk_size_px
	else:
		for info: Dictionary in builder.get("_secondary_objectives"):
			if String(info.get("type")) == "searchable_reward_building":
				building_id = int(info.id)
				destination = info.world
				break
	# Initial staging only. All recorded traversal uses production input,
	# CharacterBody2D collision, and the actual Area2D entry/exit signals.
	_player.global_position = destination + Vector2(0, 600)
	await _settle()
	_dismiss_dossiers()
	for candidate: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if candidate is IndoorVolume and _matches_volume(candidate as IndoorVolume,building_id):
			_volume = candidate
			break
	if _volume == null:
		_fail("Searchable building was not streamed")
		await _shutdown()
		return
	await _reload_check(building_id)
	_hide_optional_district_details()
	if _volume == null:
		await _shutdown()
		return
	for connection: Dictionary in _volume.body_entered.get_connections():
		var owner: Object = (connection.callable as Callable).get_object()
		if owner is RoofOverlay: _roof = owner
	if _roof == null:
		_fail("Missing production roof")
		await _shutdown()
		return
	if _city_segment == 3 and not _district_common_base and _district_evidence().get("profile","") != "checkpoint_guard_loggia":
		_fail("Native S3 sample did not select the actual guard-office family")
		await _shutdown()
		return
	var door := _volume.to_global(_volume.get("_presentation_entry"))
	var outward: Vector2 = _volume.get("_presentation_outward")
	_player.global_position = _free_spawn_position(door + outward * 160.0)
	_origin = door + outward * 270.0
	_camera.global_position = _player.global_position + Vector2(140, -160)
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	_chunks.set_process(false)
	_connect_evidence_events()
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	if _playable:
		_camera.top_level = false
		_camera.position = Vector2.ZERO
		_chunks.set_process(true)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out.path_join("frames")))
	if _entry_only:
		if _volume.local_encounter_enabled:
			_fail("Entry-only review is for ambient parcels; guarded rewards require the full security run")
			await _shutdown()
			return
		await _frames(8)
		await _still("exterior")
		await _walk_to(door+outward*96)
		await _walk_to(door-outward*float(_chunks.cell_size_px))
		await _frames(30)
		var inside_alpha := (_roof.get_node("RoofPoly") as Polygon2D).modulate.a
		if _roof._inside_count <= 0 or inside_alpha > 0.01: _fail("Ambient physical entry did not fade its actual roof owner")
		await _still("interior")
		await _walk_to(door+outward*96)
		await _frames(30)
		var outside_alpha := (_roof.get_node("RoofPoly") as Polygon2D).modulate.a
		if _roof._inside_count != 0 or outside_alpha < 0.99: _fail("Ambient physical exit did not restore its actual roof owner")
		await _still("restored-exterior")
		var entry_info := _district_evidence()
		entry_info.merge({"attempt_seed":_city_world_seed,"segment":_city_segment,"native_entry_only":true,"local_security":false,"inside_alpha":inside_alpha,"outside_alpha":outside_alpha,"streamed_reload":_route_notes,"save_writes":SaveManager.debug_save_writes-_save_writes_before,"failures":_failures},true)
		var entry_file := FileAccess.open(_out.path_join("entry-info.json"),FileAccess.WRITE)
		entry_file.store_string(JSON.stringify(entry_info,"\t"))
		entry_file.close()
		print("CityBlockEntryPreview: segment=%d building=%d inside=%.2f outside=%.2f failures=%d" % [_city_segment,_volume.building_id,inside_alpha,outside_alpha,_failures])
		await _shutdown()
		return
	if _still_only:
		var building_bounds := Rect2(_roof.footprint_outline_px[0],Vector2.ZERO)
		for point: Vector2 in _roof.footprint_outline_px: building_bounds = building_bounds.expand(point)
		await _wait_for_temporary_tips()
		_camera.global_position = _roof.to_global(building_bounds.get_center())-Vector2(0,40)
		_camera.reset_smoothing()
		_camera.force_update_scroll()
		await _frames(4)
		await _still("exterior")
		var still_info := {"segment":_city_segment,"attempt_seed":_city_world_seed,"theme":String(_chunks.district_family),"common_base":_district_common_base,"hide_optional_details":_hide_district_details,"native_still_only":true,"save_writes":SaveManager.debug_save_writes-_save_writes_before,"failures":_failures}
		still_info.merge(_district_evidence(),true)
		var still_file := FileAccess.open(_out.path_join("still-info.json"),FileAccess.WRITE)
		still_file.store_string(JSON.stringify(still_info,"\t"))
		still_file.close()
		print("CityBlockStillPreview: segment=%d common_base=%s details_hidden=%s failures=%d" % [_city_segment,_district_common_base,_hide_district_details,_failures])
		await _shutdown()
		return
	await _frames(12)
	await _still("exterior")
	_began_usec = Time.get_ticks_usec()
	_recording = true
	_phase = "traversal"
	var outline := _roof.footprint_outline_px
	var box := Rect2(_roof.to_global(outline[0]), Vector2.ZERO)
	for point: Vector2 in outline: box = box.expand(_roof.to_global(point))
	# Traverse west, north, east/service alley and front, then the real door.
	for target: Vector2 in [Vector2(box.position.x - 40, box.end.y + 90), box.position - Vector2(40, 40), Vector2(box.end.x + 40, box.position.y - 40), box.end + Vector2(40, 90), door + outward * 96]:
		await _walk_to(target, true)
	# Prove entry just past the real threshold. Walking to the room centre
	# before fighting can legitimately be blocked by its live security bodies.
	await _walk_to(door-outward*float(_chunks.cell_size_px))
	await _frames(30)
	var alpha := (_roof.get_node("RoofPoly") as Polygon2D).modulate.a
	if int(_roof.get("_inside_count")) == 0 or alpha > 0.01:
		_fail("Physical entry did not fade the roof")
	_route_notes.append({"event": "entered", "alpha": alpha, "inside_count": _roof.get("_inside_count"), "security": _volume.get("_encounter_remaining")})
	await _still("interior")
	# Local security has real colliding bodies. Clear it with the native
	# weapon before testing the return route, rather than treating a crowd
	# blocking the door as an architectural collision or bypassing bodies.
	_phase = "interior_fight"
	_clearing_interior = true
	Input.action_press(&"attack")
	while int(_volume.get("_encounter_remaining")) > 0 and _interior_fight_time < 20.0:
		await get_tree().physics_frame
	_clearing_interior = false
	_release_inputs()
	if int(_volume.get("_encounter_remaining")) > 0: _fail("Native interior attacks did not clear local security within the bounded review")
	_phase = "traversal"
	await _walk_to(door + outward * 160)
	await _frames(30)
	alpha = (_roof.get_node("RoofPoly") as Polygon2D).modulate.a
	if int(_roof.get("_inside_count")) != 0 or alpha < 0.99:
		_fail("Physical exit did not restore the roof")
	_route_notes.append({"event": "exited", "alpha": alpha, "inside_count": _roof.get("_inside_count")})
	await _still("restored-exterior")
	await _walk_to(_origin)
	_spawn_encounter()
	_initial_population = EnemyWorld.active_count()
	_phase = "fight"
	_running = true
	Input.action_press(&"attack")
	while _combat_time < 12.0:
		await get_tree().process_frame
		if get_tree().paused:
			_fail("A modal paused the moving fight")
			break
	_running = false
	_recording = false
	var wall_seconds := float(Time.get_ticks_usec()-_began_usec)/1_000_000
	_release_inputs()
	await _frames(2)
	await _still("fight-ending")
	get_tree().paused = true
	for index in _pixels.size():
		_save_image(_pixels[index], ProjectSettings.globalize_path(_out.path_join("frames/frame-%04d.png" % index)))
		if index % 20 == 0: await get_tree().process_frame
	var writes := SaveManager.debug_save_writes - _save_writes_before
	if writes != 0 or SaveManager.current_save != null: _fail("Unexpected profile write or selection")
	if _weapon_fires == 0 or _player_hits == 0 or _max_projectiles == 0: _fail("Moving fight did not exercise attacks, hits and projectiles")
	_frame_times.sort()
	var info := {"review": _review, "scene": "res://scenes/game.tscn", "seed": _city_world_seed, "segment": _city_segment, "theme": String(SegmentThemePicker.get_theme(_city_segment,_city_world_seed).id), "player_god_mode": true, "scripted_input": true, "ambient_spawner": false, "image_size": str(get_window().size), "reduced_motion": _reduced_motion, "combat_flashes": "off" if _reduced_motion else "full", "initial_fight_population": _initial_population, "simulation_fight_seconds": _combat_time, "weapon_fires": _weapon_fires, "hits": _player_hits, "deaths": _deaths, "max_projectiles": _max_projectiles, "route": _route_notes, "frames": _capture_info, "save_writes": writes, "failures": _failures, "process_frame_ms_median": _frame_times[_frame_times.size()/2] if not _frame_times.is_empty() else 0.0, "process_frame_ms_p95": _frame_times[int(_frame_times.size()*0.95)] if not _frame_times.is_empty() else 0.0, "limits": "Visual/traversal fixture on Intel UHD Compatibility; GPU readback during recording affects timing. Not a benchmark or balance test. Security encounter is production-triggered; outside crowd is controlled."}
	info.merge(_district_evidence(),true)
	var file := FileAccess.open(_out.path_join("capture-info.json"), FileAccess.WRITE)
	info["wall_seconds"] = wall_seconds
	info["captured_frames"] = _pixels.size()
	info["interior_fight_seconds"] = _interior_fight_time
	file.store_string(JSON.stringify(info, "\t"))
	file.close()
	print("CityBlockPlayablePreview: review=%s frames=%d fires=%d hits=%d deaths=%d save_writes=%d failures=%d" % [_review, _pixels.size(), _weapon_fires, _player_hits, _deaths, writes, _failures])
	await _shutdown()

func _matches_volume(volume: IndoorVolume, secondary_id: int) -> bool:
	if _target_building_id > 0:
		return volume.building_id == _target_building_id and float(volume.get("_presentation_width")) > 0.0
	return volume.secondary_objective_id == secondary_id

func _district_evidence() -> Dictionary:
	if _roof == null or _volume == null: return {}
	var coord := _chunks._world_to_chunk(_volume.global_position)
	var result := {"plan_seed":_chunks.world_seed,"building_id":_volume.building_id,"coord":str(coord),"role":String(_chunks.get_chunk_role(coord)),"doors":str(_roof._doors),"footprint":str(_roof.footprint_outline_px),"district_family":String(_chunks.district_family)}
	for kit: Node in _chunks.find_children("*","",true,false):
		if not kit.is_in_group(&"city_block_building") or kit.get("_roof") != _roof: continue
		result["profile"] = String(kit.get_meta(&"district_visual_profile",&"missing"))
		result["irregular"] = bool(kit.get("_irregular"))
		break
	var form_plan: Dictionary = _roof.get_meta(&"district_form_plan",{})
	result["has_watch"] = bool(form_plan.get("has_watch",false))
	result["watch_fallback"] = String(form_plan.get("fallback_reason",&"base"))
	result["closed_arch_bays"] = (form_plan.get("arch_bays",[]) as Array).size()
	return result

func _hide_optional_district_details() -> void:
	if not _hide_district_details: return
	for child: Node in _chunks.find_children("*","",true,false):
		if child is CanvasItem and (child.get_meta(&"district_optional_detail",false) or child.name in [&"PaintedEntryLantern",&"CardinalEntryLantern",&"PaintedDomesticAwning",&"PaintedCornerPlanter",&"CityTemperateTree",&"CityFoliageShadow",&"CivicRecordsBoard"]):
			(child as CanvasItem).visible = false

func _reload_check(secondary_id: int) -> void:
	var coord := _chunks._world_to_chunk(_volume.global_position)
	var before := _signature(coord)
	_chunks.set_process(false)
	_chunks._current_center = coord + Vector2i(32, 0)
	_chunks._update_streaming()
	await _frames(2)
	if _chunks._chunks.has(coord): _fail("Actual streaming did not unload the first block")
	var empty_stats := _chunks.get_block_batch_stats()
	if int(empty_stats.instances) != 0: _fail("Unloaded block left rendered wall instances")
	_chunks._current_center = coord
	_chunks._update_streaming()
	_chunks.set_process(true)
	await _settle()
	_chunks.set_process(false)
	var after := _signature(coord)
	if before != after: _fail("Actual chunk reload changed blockers, material variants, floor stamps or building IDs")
	_volume = null
	for candidate: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		if candidate is IndoorVolume and _matches_volume(candidate as IndoorVolume,secondary_id):
			_volume = candidate
			break
	if _volume == null: _fail("Actual chunk reload lost the searchable interior")
	_route_notes.append({"event": "streamed_reload", "equal": before == after, "unloaded_visual_instances": int(empty_stats.instances), "restored_visual_instances": _chunks.get_block_batch_stats().instances})

func _signature(coord: Vector2i) -> Dictionary:
	var data := _chunks.get_chunk_build_data(coord)
	var ids: Array[int] = []
	var roles: Array[StringName] = []
	var family_forms: Array = []
	for child: Node in (_chunks._chunks[coord] as Node).get_children():
		if child is IndoorVolume: ids.append(child.building_id)
		if child.is_in_group(&"city_block_building"):
			roles.append(child.get_meta(&"city_role"))
			var roof := child.get("_roof") as RoofOverlay
			family_forms.append([child.get_meta(&"district_visual_profile",&""),str(roof.get_meta(&"district_form_plan",{}))])
	return {"kinds": data.blocker_kind_code.duplicate(), "masks": data.blocker_mask.duplicate(), "variants": data.blocker_variant.duplicate(), "floors": data.floor_rect_and_style.duplicate(),"floor_alpha":data.floor_alpha.duplicate(), "ids": ids, "roles": roles,"family_forms":family_forms}

func _settle() -> void:
	for frame in range(480):
		await get_tree().process_frame
		if frame >= 25 and _chunks.debug_chunk_queue().is_empty() and _chunks.pending_blocker_stage_count() == 0: return
	_fail("Streaming did not settle")

func _frames(count: int) -> void:
	for _i in count: await get_tree().process_frame

func _wait_for_temporary_tips() -> void:
	# Architecture-only review waits for the real HUD queue to finish; do not
	# hide it or alter live game settings to manufacture an unobstructed image.
	for _step: int in 300:
		var busy := false
		for controller: Node in _game.find_children("TutorialTipController","",true,false):
			busy = busy or bool(controller.get("_running"))
		if not busy: return
		await get_tree().create_timer(0.1).timeout
	_fail("Temporary HUD tip queue did not clear for whole-building review")

func _still(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_save_image(get_viewport().get_texture().get_image(), _out.path_join(name + ".png"))

func _walk_to(desired: Vector2, strict_perimeter: bool = false) -> void:
	var goal := _chunks.world_to_cell(_free_spawn_position(desired))
	var resolved := _chunks.cell_to_world_center(goal)
	if strict_perimeter and resolved.distance_to(desired) > 64.0:
		_fail("Exterior waypoint moved beyond its intended one-cell perimeter: " + str(desired) + " -> " + str(resolved))
		return
	var start := _chunks.world_to_cell(_player.global_position)
	var previous: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size() and not previous.has(goal):
		var at := queue[cursor]
		cursor += 1
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = at + direction
			if previous.has(next) or absi(next.x-start.x) > 40 or absi(next.y-start.y) > 40 or not _chunks.is_cell_walkable(next): continue
			previous[next] = at
			queue.append(next)
	if not previous.has(goal):
		_fail("No walkable route to " + str(desired))
		return
	var path: Array[Vector2i] = []
	var at := goal
	while at != start:
		path.push_front(at)
		at = previous[at]
	for cell in path:
		var target := _chunks.cell_to_world_center(cell)
		var arrived := false
		for tick in range(180):
			var delta := target - _player.global_position
			if delta.length() < 8:
				arrived = true
				break
			var axis := delta.normalized()
			_set_axis(&"move_left", &"move_right", axis.x)
			_set_axis(&"move_up", &"move_down", axis.y)
			await get_tree().physics_frame
		if not arrived:
			_fail("Physical collision prevented route at " + str(cell))
			break
	_release_inputs()
	_route_notes.append({"event": "walk", "desired": str(desired), "resolved": str(resolved), "resolution_distance": resolved.distance_to(desired), "strict_perimeter": strict_perimeter, "arrived": str(_player.global_position), "path_cells": path.size()})

func _spawn_encounter() -> void:
	seed(16102026)
	Global._rng.seed = 16102026
	for index in range(26):
		var angle := index * 2.39996323
		var radius := 230.0 + (index % 3) * 100.0
		_spawn_actor(ORDINARY_SPECS[index % ORDINARY_SPECS.size()], _origin + Vector2(cos(angle)*radius, sin(angle)*radius*0.65))

func _physics_process(delta: float) -> void:
	if _clearing_interior:
		_interior_fight_time += delta
		var interior_aim := _aim_at_live_enemy()
		_set_axis(&"aim_left", &"aim_right", interior_aim.x)
		_set_axis(&"aim_up", &"aim_down", interior_aim.y)
		_max_projectiles = maxi(_max_projectiles, ProjectileManager.active_count())
	if not _running: return
	_combat_time += delta
	var target := _origin + Vector2(sin(_combat_time*0.8)*170, 80 + cos(_combat_time*0.8)*65)
	var movement := (target-_player.global_position).normalized()
	_set_axis(&"move_left", &"move_right", movement.x)
	_set_axis(&"move_up", &"move_down", movement.y)
	var aim := _aim_at_live_enemy()
	_set_axis(&"aim_left", &"aim_right", aim.x)
	_set_axis(&"aim_up", &"aim_down", aim.y)
	_max_projectiles = maxi(_max_projectiles, ProjectileManager.active_count())

func _process(delta: float) -> void:
	if _player != null and not _playable:
		_camera.global_position = _player.global_position + Vector2(140, -160)
		_camera.rotation = 0.0
	if not _recording: return
	_frame_times.append(delta*1000)
	if not _grabbing and Time.get_ticks_usec() >= _next_usec:
		_grabbing = true
		_grab.call_deferred()

func _grab() -> void:
	await RenderingServer.frame_post_draw
	if _recording:
		var pixels := get_viewport().get_texture().get_image()
		pixels.convert(Image.FORMAT_RGB8)
		_pixels.append(pixels)
		_capture_info.append({"wall_time": float(Time.get_ticks_usec()-_began_usec)/1_000_000, "simulation_time": _combat_time, "phase": _phase, "player": str(_player.global_position), "enemies": EnemyWorld.active_count(), "projectiles": ProjectileManager.active_count()})
	_next_usec = Time.get_ticks_usec() + (125000 if _phase.contains("fight") else 500000)
	_grabbing = false
