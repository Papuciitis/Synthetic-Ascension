extends "res://tools/dev/EliteCrowdFightPreview.gd"
## Cross-segment environment survey on the actual Game: one segment per run,
## frozen simulation, camera at deterministic generated places (start, main
## route chunks, first secondary objective). Each place gets a gameplay-zoom
## still and a zoomed-out street-fabric overview, so every theme can be judged
## against its concept plate with the same framing before and after a change.
## -- --segment=3 [--world-seed=16102026] [--theme=canal_services] --out=/abs/dir [--route-points=3] [--overview-zoom=0.5]
## --theme scans seeds upward from --world-seed until the picker selects it.

var _survey_segment := 2
var _survey_seed := 16102026
var _survey_theme := ""
var _route_points := 3
var _overview_zoom := 0.5
var _records: Array[Dictionary] = []

func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--segment="): _survey_segment = maxi(2, int(arg.trim_prefix("--segment=")))
		elif arg.begins_with("--world-seed="): _survey_seed = int(arg.trim_prefix("--world-seed="))
		elif arg.begins_with("--theme="): _survey_theme = arg.trim_prefix("--theme=")
		elif arg.begins_with("--route-points="): _route_points = clampi(int(arg.trim_prefix("--route-points=")), 0, 8)
		elif arg.begins_with("--overview-zoom="): _overview_zoom = clampf(float(arg.trim_prefix("--overview-zoom=")), 0.2, 1.0)
	if _out == "user://dev_previews/elite_crowd_fight":
		_out = "user://dev_previews/city_segment_survey"

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Native renderer is required")
		get_tree().quit(1)
		return
	if not _survey_theme.is_empty():
		var found := false
		for step: int in 400:
			if String(SegmentThemePicker.get_theme(_survey_segment, _survey_seed + step).id) == _survey_theme:
				_survey_seed += step
				found = true
				break
		if not found:
			_fail("No seed selects theme %s for segment %d" % [_survey_theme, _survey_segment])
			get_tree().quit(1)
			return
	var absolute_out := ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(absolute_out)
	_prepare_runtime()
	Global.attempt_segment = _survey_segment
	Global.attempt_world_seed = _survey_seed
	get_window().size = Vector2i(1280, 720)
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.top_level = true
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	await _settle_streaming()
	_dismiss_dossiers()
	var builder := get_tree().get_first_node_in_group(&"segment_proc_builder")
	if builder == null:
		_fail("Missing production segment builder")
		await _shutdown()
		return
	builder.set_process(false)
	var theme: SegmentThemeData = builder.get("_theme")
	var plan: Dictionary = builder.get("_plan")
	var points: Array[Dictionary] = [{"name": "start", "world": _player.global_position}]
	var route: Array = plan.get("main_route", [])
	for index: int in _route_points:
		if route.size() < 2: break
		var at := int(round(float(route.size()-1) * float(index+1) / float(_route_points+1)))
		var coord: Vector2i = route[at]
		points.append({"name": "route%d" % (index+1), "world": (Vector2(coord)+Vector2.ONE*0.5)*_chunks.chunk_size_px, "chunk": str(coord)})
	for info: Dictionary in builder.get("_secondary_objectives"):
		if info.has("world"):
			points.append({"name": "objective", "world": info.world, "type": String(info.get("type",""))})
			break
	for point: Dictionary in points:
		await _capture_point(point)
	var manifest := {
		"segment": _survey_segment, "world_seed": _survey_seed,
		"theme_id": String(theme.id) if theme != null else "", "theme_label": theme.label if theme != null else "",
		"base_terrain": theme.base_terrain if theme != null else "",
		"points": _records, "failures": _failures,
	}
	var file := FileAccess.open(_out.path_join("survey.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(manifest, "  ") + "\n")
	await _shutdown()

func _capture_point(point: Dictionary) -> void:
	var world: Vector2 = point.world
	# Stream the place first; the player is only staged once its cells exist.
	_player.global_position = world
	_camera.zoom = Vector2.ONE
	_camera.global_position = world
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	await _settle_streaming()
	_player.global_position = _open_cell_near(world)
	_dismiss_dossiers()
	await _frames(6)
	var stem := "%s-seg%d" % [point.name, _survey_segment]
	_save_image(get_viewport().get_texture().get_image(), _out.path_join(stem + "-play.png"))
	var buildings := 0
	for kit: Node in get_tree().get_nodes_in_group(&"city_block_building"):
		if kit is Node2D and (kit as Node2D).global_position.distance_to(world) < 2200.0: buildings += 1
	_camera.zoom = Vector2.ONE * _overview_zoom
	_camera.force_update_scroll()
	await _settle_streaming()
	await _frames(6)
	_save_image(get_viewport().get_texture().get_image(), _out.path_join(stem + "-overview.png"))
	_camera.zoom = Vector2.ONE
	var record := point.duplicate()
	record["world"] = [world.x, world.y]
	record["chunk_at"] = str(_chunks._world_to_chunk(world))
	record["kits_within_2200px"] = buildings
	_records.append(record)

func _open_cell_near(world: Vector2) -> Vector2:
	# Like _free_spawn_position, but a fully built place is not a failure.
	var center := _chunks.world_to_cell(world)
	for radius: int in 12:
		for y: int in range(-radius, radius+1):
			for x: int in range(-radius, radius+1):
				if maxi(absi(x), absi(y)) != radius: continue
				var cell := center+Vector2i(x, y)
				if _chunks.is_cell_walkable(cell): return _chunks.cell_to_world_center(cell)
	return world

func _settle_streaming() -> void:
	for frame in range(600):
		await get_tree().process_frame
		if frame >= 20 and _chunks.debug_chunk_queue().is_empty() and _chunks.pending_blocker_stage_count() == 0: return
	_fail("Streaming did not settle")

func _frames(count: int) -> void:
	for _i in count: await get_tree().process_frame
