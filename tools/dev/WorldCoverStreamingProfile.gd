extends "res://tools/dev/EliteCrowdFightPreview.gd"
## Native actual Game movement/streaming timing. No viewport/image readback,
## frame encoding, per-frame logging, or hot-path WorldCover modification.
## Ambient spawner, director, scheduling, chunk streaming and draw owners live.

const COVER_SERVICE := preload("res://core/systems/world/visibility/WorldCover.gd")
var _profile_review := "small"
var _profile_seed := 16102026
var _profile_segment := 2
var _profile_label := "baseline"
var _profile_start := Vector2(608,7392)
var _profile_goals: Array[Vector2] = [Vector2(2208,7392),Vector2(608,7392)]
var _profile_warmup := 6.0
var _profile_timeout := 75.0
var _profile_cap := 0
var _profile_cover: Node
var _profile_spawner: EnemySpawner
var _profile_samples: Array[Dictionary] = []
var _profile_path := PackedVector2Array()
var _profile_cells: Array[Vector2i] = []
var _profile_waypoints: Array[Dictionary] = []
var _profile_stream_samples: Array[Dictionary] = []
var _profile_at := 0
var _profile_sampling := false
var _profile_moving := false
var _profile_wall_begin := 0
var _profile_previous_frame := 0
var _profile_previous_generation := 0
var _profile_next_stream_usec := 0
var _profile_simulation := 0.0
var _profile_distance := 0.0
var _profile_previous_position := Vector2.ZERO
var _profile_start_stream := 0
var _profile_start_cover: Dictionary = {}
var _profile_start_chunks: Array = []
var _profile_seen_chunks: Dictionary = {}
var _profile_start_rng := 0
var _profile_initial_footways := 0
var _profile_max_queue := 0
var _profile_previous_alpha := RID()
var _profile_alpha_rebuild_observations := 0
var _profile_requested_movement := Vector2.ZERO
var _profile_force_uploads := false


func _enter_tree() -> void:
	super._enter_tree()
	process_priority = 1000
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--review="): _profile_review = arg.trim_prefix("--review=")
		if arg.begins_with("--world-seed="): _profile_seed = int(arg.trim_prefix("--world-seed="))
		if arg.begins_with("--segment="): _profile_segment = int(arg.trim_prefix("--segment="))
		if arg.begins_with("--profile-label="): _profile_label = arg.trim_prefix("--profile-label=")
		if arg.begins_with("--warmup="): _profile_warmup = clampf(float(arg.trim_prefix("--warmup=")),3.0,20.0)
		if arg.begins_with("--route-timeout="): _profile_timeout = clampf(float(arg.trim_prefix("--route-timeout=")),10.0,120.0)
		if arg.begins_with("--fps-cap="): _profile_cap = maxi(0,int(arg.trim_prefix("--fps-cap=")))
		if arg == "--cover-force-upload": _profile_force_uploads = true
		if arg.begins_with("--start="): _profile_start = _profile_point(arg.trim_prefix("--start="))
		if arg.begins_with("--waypoints="):
			_profile_goals.clear()
			for point: String in arg.trim_prefix("--waypoints=").split(":"):
				_profile_goals.append(_profile_point(point))
	if _out == "user://dev_previews/elite_crowd_fight":
		_out = "user://dev_previews/world_cover_streaming_profile"


func _profile_point(text: String) -> Vector2:
	var parts := text.split(",")
	if parts.size() != 2 or not parts[0].is_valid_float() or not parts[1].is_valid_float():
		_fail("Profile point requires two world coordinates: "+text)
		return Vector2.ZERO
	return Vector2(float(parts[0]),float(parts[1]))


func _run() -> void:
	if DisplayServer.get_name() == "headless" or _profile_review not in ["small","normal"] or _profile_segment != 2 or _profile_goals.is_empty() or _failures > 0:
		_fail("Native small/normal S2 route with explicit waypoints is required")
		await _shutdown()
		return
	_prepare_runtime()
	Global.attempt_segment = _profile_segment
	Global.attempt_world_seed = _profile_seed
	# The real procedural builder honors this transient checkpoint before its
	# first streamed centre; no save or second-world construction is involved.
	Global.attempt_checkpoint_pos = _profile_start
	Global.debug_encounter_beats = true
	seed(_profile_seed)
	Global._rng.seed = _profile_seed
	Engine.max_fps = _profile_cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().size = Vector2i(960,540) if _profile_review == "small" else Vector2i(1280,720)
	get_window().title = "Synthetic Ascension — no-readback streaming profile"
	_game = GAME.instantiate() as Node2D
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	_profile_spawner = _game.get_node("Spawner") as EnemySpawner
	_player.global_position = _profile_start
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	var settled := false
	for frame: int in range(900):
		await get_tree().process_frame
		if frame >= 30 and _chunks.streaming_started and _chunks.debug_chunk_queue().is_empty() and _chunks.pending_blocker_stage_count() == 0:
			settled = true
			break
	if not settled:
		_fail("Streaming profile initial real world did not settle")
		await _shutdown()
		return
	_dismiss_dossiers()
	_player.global_position = _free_spawn_position(_profile_start)
	_profile_start = _player.global_position
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_profile_cover = COVER_SERVICE.get_for(_player)
	_profile_cover.set_meta(COVER_SERVICE.FORCE_UPLOAD_META,_profile_force_uploads)
	_connect_evidence_events()
	Input.action_press(&"attack")
	# No actors are staged or frozen. Let the actual ambient timer populate the
	# scene and pool warm-up finish, using ordinary simulation time.
	_profile_simulation = 0.0
	_profile_moving = true
	while _profile_simulation < _profile_warmup:
		await get_tree().process_frame
		if get_tree().paused:
			_fail("A modal paused profile warm-up")
			break
	_profile_moving = false
	if not _profile_build_route():
		await _shutdown()
		return
	_profile_cover = COVER_SERVICE.get_for(_player)
	_profile_start_cover = _profile_cover.call("snapshot_stats") as Dictionary
	_profile_previous_generation = int(_profile_start_cover.generation)
	_profile_start_stream = int(_chunks.get("_stream_activations_total"))
	_profile_start_chunks = (_chunks.get("_chunks") as Dictionary).keys()
	_profile_initial_footways = _profile_count_footways()
	_profile_start_rng = Global._rng.state
	_profile_previous_position = _player.global_position
	_profile_wall_begin = Time.get_ticks_usec()
	_profile_previous_frame = _profile_wall_begin
	_profile_next_stream_usec = _profile_wall_begin
	_profile_simulation = 0.0
	_profile_sampling = true
	_profile_moving = true
	while _profile_at < _profile_path.size() and float(Time.get_ticks_usec()-_profile_wall_begin)/1_000_000.0 < _profile_timeout:
		await get_tree().process_frame
		if get_tree().paused:
			_fail("A modal paused the live movement/streaming profile")
			break
	_profile_sampling = false
	_profile_moving = false
	_release_inputs()
	if _profile_at < _profile_path.size(): _fail("Live profile failed to complete its physically walked route")
	var wall := float(Time.get_ticks_usec()-_profile_wall_begin)/1_000_000.0
	var stream_delta := int(_chunks.get("_stream_activations_total"))-_profile_start_stream
	if _profile_samples.size() < 30: _fail("Too few real rendered process frames for a profile")
	var occupied_frames := 0
	for row: Dictionary in _profile_samples:
		if int(row.enemies) > 0: occupied_frames += 1
	if occupied_frames < _profile_samples.size()/2: _fail("Ordinary ambient population did not occupy most of the real route")
	if _profile_initial_footways == 0: _fail("Actual S2 scene has no active footway material")
	if _profile_seen_chunks.size() < 2 or stream_delta <= 0: _fail("Route did not exercise real chunk crossing and live activation")
	if _weapon_fires <= 0 or _max_projectiles <= 0: _fail("Ordinary occupied profile did not exercise real weapon/projectile work")
	var writes := SaveManager.debug_save_writes-_save_writes_before
	if writes != 0 or SaveManager.current_save != null: _fail("Profile wrote or selected a save")
	_profile_write(wall,stream_delta,writes)
	await _shutdown()


func _profile_build_route() -> bool:
	var previous_goal := _chunks.world_to_cell(_player.global_position)
	for desired: Vector2 in _profile_goals:
		var goal := _chunks.world_to_cell(_free_spawn_position(desired))
		var previous: Dictionary = {previous_goal:previous_goal}
		var queue: Array[Vector2i] = [previous_goal]
		var cursor := 0
		while cursor < queue.size() and not previous.has(goal):
			var at := queue[cursor]
			cursor += 1
			for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
				var next := at+direction
				if previous.has(next) or absi(next.x-previous_goal.x) > 60 or absi(next.y-previous_goal.y) > 60 or not _chunks.is_cell_walkable(next): continue
				previous[next] = at
				queue.append(next)
		if not previous.has(goal):
			_fail("No real walkable profile route to "+str(desired))
			return false
		var cells: Array[Vector2i] = []
		var at := goal
		while at != previous_goal:
			cells.push_front(at)
			at = previous[at]
		for cell: Vector2i in cells:
			_profile_cells.append(cell)
			_profile_path.append(_chunks.cell_to_world_center(cell))
		_profile_waypoints.append({"requested":desired,"resolved":_chunks.cell_to_world_center(goal),"path_end_index":_profile_path.size()-1})
		previous_goal = goal
	return not _profile_path.is_empty()


func _physics_process(delta: float) -> void:
	if not _profile_moving or _player == null: return
	_profile_simulation += delta
	_combat_time += delta
	var movement := Vector2.ZERO
	if _profile_sampling and _profile_at < _profile_path.size():
		var target := _profile_path[_profile_at]
		if _player.global_position.distance_to(target) < 8.0:
			_profile_at += 1
			if _profile_at < _profile_path.size(): target = _profile_path[_profile_at]
		# Native movement actions use a0.2 deadzone. Scaling by remaining
		# distance stopped at16px, outside the8px arrival radius. A held
		# full-strength action follows the production speed/collision path.
		if _profile_at < _profile_path.size(): movement = (target-_player.global_position).normalized()
	_profile_requested_movement = movement
	_set_axis(&"move_left",&"move_right",movement.x)
	_set_axis(&"move_up",&"move_down",movement.y)
	var aim := _aim_at_live_enemy()
	_set_axis(&"aim_left",&"aim_right",aim.x)
	_set_axis(&"aim_up",&"aim_down",aim.y)
	_max_projectiles = maxi(_max_projectiles,ProjectileManager.active_count())


func _process(_delta: float) -> void:
	if not _profile_sampling: return
	var began := Time.get_ticks_usec()
	var cover := _profile_cover.call("snapshot_stats") as Dictionary
	var generation_delta := int(cover.generation)-_profile_previous_generation
	_profile_previous_generation = int(cover.generation)
	var frame_ms := float(began-_profile_previous_frame)/1000.0
	_profile_previous_frame = began
	var chunk := _chunks._world_to_chunk(_player.global_position)
	_profile_seen_chunks[chunk] = true
	_profile_distance += _player.global_position.distance_to(_profile_previous_position)
	_profile_previous_position = _player.global_position
	var queue_count := (_chunks.get("_chunk_generation_queue") as Array).size()
	_profile_max_queue = maxi(_profile_max_queue,queue_count)
	var alpha := _profile_cover.get("_alpha") as Texture2DArray
	if alpha != null and alpha.get_rid() != _profile_previous_alpha:
		if _profile_previous_alpha.is_valid(): _profile_alpha_rebuild_observations += 1
		_profile_previous_alpha = alpha.get_rid()
	var row := {"wall_seconds":float(began-_profile_wall_begin)/1_000_000.0,"simulation_seconds":_profile_simulation,
		"frame_wall_ms":frame_ms,"engine_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
		"engine_physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"player_world":_player.global_position,"chunk":chunk,"path_index":_profile_at,
		"requested_move":_profile_requested_movement,"native_move_input":Input.get_vector("move_left","move_right","move_up","move_down"),
		"enemies":EnemyWorld.active_count(),"projectiles":ProjectileManager.active_count(),
		"loaded_chunks":_chunks.loaded_chunk_count(),"queued_chunks":queue_count,
		"stream_activations_total":int(_chunks.get("_stream_activations_total")),
		"cover":cover,"cover_generation_delta":generation_delta,
		"cover_refresh_ms":float(cover.refresh_usec)/1000.0 if generation_delta > 0 else 0.0,
		"baseline_inferred_data_uploads":generation_delta*3 if not cover.has("data_uploads") else -1,
		"instrumentation_usec":0}
	if began >= _profile_next_stream_usec:
		_profile_stream_samples.append({"wall_seconds":row.wall_seconds,"stream":_chunks.get_chunk_stream_debug_stats(),"spawner":_profile_spawner.balance_snapshot()})
		_profile_next_stream_usec = began+500_000
	row["instrumentation_usec"] = Time.get_ticks_usec()-began
	_profile_samples.append(row)


func _profile_count_footways() -> int:
	var count := 0
	for node: Node in _chunks.find_children("*","Polygon2D",true,false):
		var material := (node as Polygon2D).material as ShaderMaterial
		if material != null and material.shader != null and material.shader.resource_path == "res://scenes/world/buildings/city_footway.gdshader": count += 1
	return count


func _profile_distribution(key: String) -> Dictionary:
	var values: Array[float] = []
	for row: Dictionary in _profile_samples: values.append(float(row[key]))
	values.sort()
	if values.is_empty(): return {}
	var total := 0.0
	for value: float in values: total += value
	return {"count":values.size(),"min":values.front(),"p50":values[mini(values.size()-1,ceili(values.size()*0.50)-1)],
		"p95":values[mini(values.size()-1,ceili(values.size()*0.95)-1)],"p99":values[mini(values.size()-1,ceili(values.size()*0.99)-1)],"max":values.back(),"mean":total/values.size()}


func _profile_write(wall: float, activations: int, writes: int) -> void:
	var distributions := {}
	for key: String in ["frame_wall_ms","engine_process_ms","engine_physics_ms","cover_refresh_ms","enemies","projectiles","draw_calls","primitives","instrumentation_usec"]:
		distributions[key] = _profile_distribution(key)
	var snapshots := 0
	for row: Dictionary in _profile_samples: snapshots += int(row.cover_generation_delta)
	var report := {"tool":"res://tools/dev/WorldCoverStreamingProfile.tscn","scene":"res://scenes/game.tscn",
		"profile_label":_profile_label,"args":OS.get_cmdline_user_args(),"seed":_profile_seed,"segment":_profile_segment,"actual_theme":String(_chunks.district_family),
		"route":{"start":_profile_start,"waypoints":_profile_waypoints,"cells":str(_profile_cells),"cells_sha256":str(_profile_cells).sha256_text(),"completed":_profile_at >= _profile_path.size(),"completed_cells":_profile_at,"planned_cells":_profile_path.size(),"distance_walked_px":_profile_distance,"chunks_visited":str(_profile_seen_chunks.keys())},
		"wall_seconds":wall,"simulation_seconds":_profile_simulation,"warmup_simulation_seconds":_profile_warmup,"distributions":distributions,
		"streaming":{"enabled":_chunks.is_processing() and _chunks.streaming_started,"activations_during_route":activations,"max_queue":_profile_max_queue,"initial_chunks":str(_profile_start_chunks),"final_loaded_chunks":_chunks.loaded_chunk_count(),"samples":_profile_stream_samples},
		"cover":{"initial":_profile_start_cover,"final":_profile_cover.call("snapshot_stats"),"observed_generations":snapshots,
			"baseline_inferred_data_uploads":snapshots*3 if not _profile_start_cover.has("data_uploads") else -1,"alpha_array_rebuild_observations":_profile_alpha_rebuild_observations,
			"force_uploads":_profile_force_uploads,
			"upload_qualifier":"Original unmodified baseline count is source-derived3xgeneration. Instrumented snapshots carry actual CPU upload-call/requested-byte counters in initial/final/per-frame cover records; -1 means the baseline inference is unused. These are not GPU transfer/stall timings. Forced-upload control preserves live collection while forcing each packed snapshot/material rebind on the same candidate source."},
		"footways":{"initial_live_shader_polygons":_profile_initial_footways,"final_live_shader_polygons":_profile_count_footways()},
		"combat":{"weapon_fires":_weapon_fires,"hits":_player_hits,"deaths":_deaths,"max_projectiles":_max_projectiles,"ambient_spawner_active":_profile_spawner.is_processing() and _profile_spawner.spawning_enabled,"spawner":_profile_spawner.balance_snapshot(),"encounter_beats":Global.debug_encounter_beats},
		"fixture":{"god_mode":true,"opening_completed":true,"scripted_input":true,"initial_staging_only":true,"controlled_enemies":0,"streaming_frozen":false,"scheduler_frozen":false,"capture_readbacks":0,"per_frame_file_writes":0,"normal_hud":true,"telemetry_recorders_disabled":true,"user_data_profile_selected":false},
		"render":{"native_window":str(get_window().size),"logical_viewport":str(get_viewport().get_visible_rect().size),"fps_cap":Engine.max_fps,"vsync_mode":DisplayServer.window_get_vsync_mode(),"backend":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name()},
		"rng_start":_profile_start_rng,"rng_end":Global._rng.state,"save_writes":writes,"failures":_failures,"samples":_profile_samples,
		"limits":"Scripted actual Game route with live ordinary ambient spawning/director/AI/streaming and god mode. No viewport readback or PNG/encoding. Wall-frame and engine process/physics observations are CPU-facing; no GPU timer or attribution for footway fragment cost. Population and route must be compared before any candidate claim. Historical capture timings are not a matched pre-feature baseline. Startup/warm-up and path planning excluded; half-second diagnostics are included and instrumentation cost recorded."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var file := FileAccess.open(_out.path_join("profile-info.json"),FileAccess.WRITE)
	if file == null:
		_fail("Cannot write no-readback profile report")
	else:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("WorldCoverStreamingProfile: samples=%d route=%d/%d activations=%d frame_p95=%.3fms cover_p95=%.3fms failures=%d saves=%d" % [_profile_samples.size(),_profile_at,_profile_path.size(),activations,float(distributions.get("frame_wall_ms",{}).get("p95",0.0)),float(distributions.get("cover_refresh_ms",{}).get("p95",0.0)),_failures,writes])
