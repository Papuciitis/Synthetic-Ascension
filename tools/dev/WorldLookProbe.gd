extends Node
## Renders the in-run world at gameplay zoom so art passes can be judged
## without a playtest (needs a display, not --headless).
##   <godot> --path . res://tools/dev/WorldLookProbe.tscn -- --out=/abs/dir [--segment=1|2..] [--seed=n] [--enemies=n]
## Segment 1 stops are authored cells; procedural segments visit the start,
## a plaza and the primary objective from the district plan.

const SEG1_STOPS: Array = [
	["lab_corridor", Vector2i(15, 25)],
	["courtyard", Vector2i(0, -14)],
	["evidence_route", Vector2i(28, -10)],
	["service", Vector2i(36, -20)],
	["gate_plaza", Vector2i(20, -50)],
	["overlook", Vector2i(49, -45)],
]

var _dir := "/tmp"
var _segment := 1
var _seed := 424242
var _enemies := 24
var _splat := 1
var _max_stops := 99
var _is_worker := false
var _gpu_ms: Array[float] = []


func _ready() -> void:
	if _is_worker:
		get_tree().create_timer(240.0).timeout.connect(func() -> void:
			push_error("WorldLookProbe timed out")
			get_tree().quit(1)
		)
		_run.call_deferred()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--segment="):
			_segment = int(arg.trim_prefix("--segment="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--enemies="):
			_enemies = int(arg.trim_prefix("--enemies="))
		elif arg.begins_with("--stops="):
			_max_stops = int(arg.trim_prefix("--stops="))
		elif arg.begins_with("--splat="):
			_splat = int(arg.trim_prefix("--splat="))
	DirAccess.make_dir_recursive_absolute(_dir)
	# Must outlive goto_game()'s scene change.
	var worker := Node.new()
	worker.name = "WorldLookWorker"
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	worker.set_script(get_script())
	worker.set("_dir", _dir)
	worker.set("_segment", _segment)
	worker.set("_seed", _seed)
	worker.set("_enemies", _enemies)
	worker.set("_splat", _splat)
	worker.set("_max_stops", _max_stops)
	worker.set("_is_worker", true)
	get_tree().root.add_child.call_deferred(worker)


func _run() -> void:
	# The ground path is chosen when the chunk manager enters the tree.
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is ChunkManager:
			(node as ChunkManager).ground_splat_enabled = _splat != 0
	)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	Global.start_new_attempt()
	Global.attempt_segment = _segment
	Global.attempt_world_seed = _seed
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.tip_shown_intro_move = true
	Global.debug_dev_segment = false
	Global.debug_encounter_beats = false
	Global.debug_player_god_mode = true
	Global.goto_game()
	var player: Node2D = null
	for _wait in range(600):
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null:
			break
	if player == null:
		push_error("WorldLookProbe: no player")
		get_tree().quit(1)
		return
	await _settle(90)
	var stops: Array = []
	if _segment == 1:
		stops = SEG1_STOPS
		var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
		if spawner != null:
			spawner.call("set_segment1_stage", Segment1SpawnProfile.Stage.OUTER_APPROACH)
	else:
		stops = _proc_stops()
	var spawner_node := get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner_node != null and spawner_node.has_method("suspend_spawning"):
		spawner_node.call("suspend_spawning", 9999.0)
	var cm := get_tree().get_first_node_in_group(&"chunk_manager")
	stops = stops.slice(0, _max_stops)
	for stop in stops:
		var label := String(stop[0])
		var at: Vector2 = stop[1] if stop[1] is Vector2 else Vector2(stop[1] as Vector2i) * 64.0 + Vector2(32, 32)
		player.global_position = at
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.reset_smoothing()
		if cm != null and cm.has_method("process_chunk_generation_queue"):
			cm.call("process_chunk_generation_queue", 25)
		await _settle(60)
		if _enemies > 0 and spawner_node != null:
			spawner_node.call("debug_force_spawn", _enemies)
		await _settle(70)
		var gpu := 0.0
		var cpu := 0.0
		for _f in range(30):
			await RenderingServer.frame_post_draw
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
		_gpu_ms.append(gpu / 30.0)
		var path := "%s/seg%d_%s.png" % [_dir, _segment, label]
		get_viewport().get_texture().get_image().save_png(path)
		print("WorldLookProbe -> %s  gpu %.2f ms  cpu %.2f ms" % [path, gpu / 30.0, cpu / 30.0])
		_clear_enemies()
	var total := 0.0
	for v in _gpu_ms:
		total += v
	print("WorldLookProbe mean gpu %.2f ms (splat=%d)" % [total / maxf(1.0, float(_gpu_ms.size())), _splat])
	get_tree().quit(0)


func _proc_stops() -> Array:
	var out: Array = []
	var builder := get_tree().get_first_node_in_group(&"segment_proc_builder")
	var cm := get_tree().get_first_node_in_group(&"chunk_manager")
	var chunk_px := float(cm.get("chunk_size_px")) if cm != null else 2048.0
	var plan: Dictionary = (builder.get("_plan") as Dictionary) if builder != null else {}
	if plan.has("start_world"):
		out.append(["start", plan["start_world"] as Vector2])
	var archetypes: Dictionary = plan.get("archetype_by_chunk", {})
	var seen := {}
	for c in archetypes.keys():
		var kind := String(archetypes[c])
		if seen.has(kind) or kind == "district":
			continue
		seen[kind] = true
		out.append([kind, (Vector2(c as Vector2i) + Vector2(0.5, 0.5)) * chunk_px + Vector2(0, 180)])
	for c in archetypes.keys():
		if String(archetypes[c]) == "district":
			out.append(["district", (Vector2(c as Vector2i) + Vector2(0.5, 0.5)) * chunk_px + Vector2(260, 0)])
			break
	if plan.has("primary_world"):
		out.append(["primary", plan["primary_world"] as Vector2 + Vector2(0, 200)])
	return out


func _settle(frames: int) -> void:
	for _f in range(frames):
		await get_tree().process_frame
		if get_tree().paused:
			_unblock()


func _unblock() -> void:
	_strip(get_tree().root)
	get_tree().paused = false


func _strip(node: Node) -> void:
	var script: Variant = node.get_script()
	if script != null:
		var path := String(script.resource_path)
		if path.ends_with("TutorialModalController.gd"):
			node.queue_free()
			return
		if path.ends_with("TutorialCardOverlay.gd") and node.has_method("_dismiss"):
			node.call("_dismiss")
	if node.has_method("open_choose_3"):
		node.queue_free()
		return
	var button := node as Button
	if button != null and button.visible and button.text.strip_edges().to_lower() == "continue":
		button.emit_signal("pressed")
	for child in node.get_children():
		_strip(child)


func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy is Node and is_instance_valid(enemy):
			(enemy as Node).queue_free()
