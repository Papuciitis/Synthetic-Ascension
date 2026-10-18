extends "res://tools/dev/S10BossTelegraphPreview.gd"
## Staged current production presentation in the actual generated Game/HUD.
## Frozen samples, immortal player, no live-profile writes; not a fight test.
const WARD := preload("res://scenes/world/wardstones/Wardstone.tscn")
const RITE := preload("res://scenes/world/gates/ExitRite.tscn")
const RELAY := preload("res://core/systems/world/objectives/DistrictRelayObjective.gd")
const VIGIL := preload("res://core/systems/world/objectives/WardVigilObjective.gd")
const BREACH := preload("res://core/systems/world/objectives/BreachSealObjective.gd")
const WAGER := preload("res://core/systems/world/objectives/WagerShrineObjective.gd")
var _runner: AscensionRunner
var _precision: PrecisionEngine
var _only_panel := ""

func _enter_tree() -> void:
	_out = "res://.superpowers/sdd/2026-10-18-objective-visual-rework/breach-final-captures/"
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only_panel = arg.trim_prefix("--only=")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("native renderer required")
		get_tree().quit(1)
		return
	var absolute_out := ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(absolute_out)
	AudioServer.set_bus_mute(0, true)
	StoryDirector.cards_override = 0
	Global.apply_save(SaveData.new())
	Global.debug_dev_mode = true
	Global.debug_dev_segment = false
	Global.debug_player_god_mode = true
	Global.debug_encounter_beats = false
	Global.selected_style_id = "ranged"
	Global.start_new_attempt()
	Global.attempt_segment = 3
	Global.attempt_world_seed = WORLD_SEED
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	get_window().title = "Synthetic Ascension — staged abilities and objectives in actual Game"
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
	_camera = _player.get_node("Camera2D") as Camera2D
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	var chunks := _game.get_node("ChunkManager") as ChunkManager
	for frame in range(360):
		await get_tree().process_frame
		if chunks.debug_chunk_queue().is_empty() and chunks.pending_blocker_stage_count() == 0 and frame >= 20:
			break
	if not chunks.debug_chunk_queue().is_empty() or chunks.pending_blocker_stage_count() != 0:
		_fail("world generation did not settle")
	_quiet_tutorials()
	get_tree().paused = false
	_freeze(_game)
	for singleton: String in ["EnemySimulationScheduler", "EnemyIndex", "ThreatDirector", "EnemyWorld", "EnemyCombat", "EnemyStatus", "ProjectileManager", "HitFeel"]:
		var service := get_node_or_null("/root/" + singleton)
		if service != null:
			service.set_process(false)
			service.set_physics_process(false)
	for group in [&"primary_objective", &"secondary_objective", &"wardstones", &"exit_rite"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is CanvasItem:
				node.visible = false
	_origin = _player.global_position
	for mode: Dictionary in [
		{"size": Vector2i(1280, 720), "reduced": false, "suffix": "normal"},
		{"size": Vector2i(960, 540), "reduced": false, "suffix": "small"},
		{"size": Vector2i(960, 540), "reduced": true, "suffix": "reduced"},
	]:
		get_window().size = mode["size"]
		SettingsManager.set_value(&"accessibility", &"reduced_motion", mode["reduced"], false)
		SettingsManager.set_value(&"accessibility", &"combat_flash", &"off" if mode["reduced"] else &"full", false)
		for panel: String in ["breach-open", "breach-sealing", "breach-decaying", "breach-sealed", "breach-context", "breach-spawn"]:
			if not _only_panel.is_empty() and panel != _only_panel:
				continue
			if is_instance_valid(_stage):
				_stage.queue_free()
				await _frames(2)
			_stage = _new_stage()
			_reset_precision()
			_player.global_position = _origin + Vector2(-370, 160)
			_camera.position = Vector2(370, -160)
			_camera.reset_smoothing()
			_camera.force_update_scroll()
			_clear_staged_enemies()
			_build_panel(panel)
			_label(Vector2(-770, -457), Vector2(1540, 40), "STAGED IN ACTUAL GAME / " + panel.to_upper().replace("-", " ") + (" / REDUCED MOTION + FLASHES OFF" if mode["reduced"] else ""), 24)
			_freeze(_stage)
			await _frames(4)
			_publish_enemies()
			await RenderingServer.frame_post_draw
			var filename := "%s-%s.png" % [panel, mode["suffix"]]
			var pixels := get_viewport().get_texture().get_image()
			if pixels.get_size() != mode["size"] or pixels.save_png(absolute_out.path_join(filename)) != OK:
				_fail("capture failed " + filename)
			_captures.append({"file": filename, "panel": panel, "window": str(mode["size"]), "reduced_motion": mode["reduced"], "combat_flash": "off" if mode["reduced"] else "full"})
			print("AbilityObjectiveGamePreview -> ", filename)
	if SaveManager.debug_save_writes != _save_writes_before or SaveManager.current_save != null:
		_fail("unexpected profile write")
	var info := {"scene": "res://scenes/game.tscn", "presentation": "STAGED FROZEN samples in actual generated Game terrain and HUD; immortal player; no human pacing/readability claim", "world_seed": WORLD_SEED, "segment": 3, "viewport": str(PROJECT_VIEWPORT), "zoom": str(_camera.zoom), "captures": _captures, "save_writes": SaveManager.debug_save_writes - _save_writes_before, "failures": _failures}
	var file := FileAccess.open(absolute_out.path_join("capture-info.json" if _only_panel.is_empty() else "capture-info-%s.json" % _only_panel), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "\t"))
	Engine.time_scale = 1.0
	print("AbilityObjectiveGamePreview: %d staged captures; failures=%d" % [_captures.size(), _failures])
	_clear_staged_enemies()
	if is_instance_valid(_game):
		_game.queue_free()
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_tree().quit(1 if _failures else 0)

func _reset_precision() -> void:
	var old := _runner.get_node_or_null("PrecisionPresentation")
	if old != null:
		old.free()
	_runner.end_time_slow()
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged")
	var ledger := Global.ascension_ledger()
	ledger.note_segment_completed(9)
	ledger.record_purchase("PRQ", 100)
	ledger.record_purchase("PRV", 100)
	ledger.equip("q", "PRQ")
	ledger.equip("v", "PRV")
	_runner.refresh()
	_precision = _runner.engine_of_discipline("PR") as PrecisionEngine
	_runner.aim_override = _origin + Vector2(700, -120)

func _add_objective(script: Script, at: Vector2 = Vector2.ZERO) -> Node2D:
	var objective: Node2D = script.new()
	objective.position = _origin + at
	if objective.has_method("configure"):
		objective.call("configure", 87139)
	_stage.add_child(objective)
	return objective

func _build_panel(panel: String) -> void:
	RunEvents.objective_changed.emit("", "")
	RunEvents.secondary_objective_changed.emit("", "")
	var objective := BREACH.new()
	objective.configure(87139)
	objective.position = _origin
	# Controlled review placement only; production layout/geometry are untouched.
	var sites: Array[Vector2] = [Vector2.ZERO, Vector2(2600, 0), Vector2(-2600, 0)]
	if panel == "breach-context":
		sites = [Vector2(-380, -180), Vector2(380, -180), Vector2(0, 180)]
	objective.set("_positions", sites)
	_stage.add_child(objective)
	objective.player = _player
	_player.global_position = _origin + Vector2(-250, 160)
	_camera.position = _origin - _player.global_position
	var progress := PackedFloat32Array([0.0, 0.0, 0.0])
	var seals := PackedByteArray([0, 0, 0])
	if panel in ["breach-sealing", "breach-decaying"]:
		progress[0] = objective.seal_seconds * 0.6
	if panel == "breach-sealing":
		_player.global_position = _origin + Vector2(0, 12)
	if panel == "breach-sealed":
		seals[0] = 1
		progress[0] = objective.seal_seconds
		_player.global_position = _origin + Vector2(0, -65)
	if panel == "breach-context":
		seals[1] = 1
		progress[1] = objective.seal_seconds
		progress[2] = objective.seal_seconds * 0.6
		_player.global_position = _origin + sites[2] + Vector2(0, 42)
	objective.set("_sealed", seals)
	objective.set("_progress", progress)
	objective.update_presentation()
	objective.queue_redraw()
	if panel == "breach-spawn":
		var cooldowns: PackedFloat32Array = objective.get("_spawn_cd")
		cooldowns[0] = 0.0
		objective.set("_spawn_cd", cooldowns)
		objective.call("_tick_breach_spawn", 0, _origin, 0.0)
		var poured: Array = objective.get("_spawned")[0]
		if poured.size() != 3:
			_fail("expected actual three-enemy source pour, got " + str(poured.size()))
	_camera.position = _origin - _player.global_position
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	RunEvents.objective_changed.emit(objective.objective_title(), objective.objective_detail())
	_label(Vector2(-700, 365), Vector2(1400, 60), "CONTROLLED CURRENT GAME  /  " + panel.to_upper().replace("-", " ") + "  /  UNCHANGED 132 PX SEAL RADIUS", 21)

func _publish_enemies() -> void:
	var proxy := get_tree().get_first_node_in_group(&"enemy_proxy_root")
	if proxy != null and proxy.get("renderer") != null:
		var drawn := int(proxy.get("renderer").call("publish"))
		if _captures.size() % 6 == 5 and drawn < 3:
			_fail("source pour actors must actually render, drawn=" + str(drawn))

func _clear_staged_enemies() -> void:
	# Expire only a prior panel's cosmetic transaction card; never advance Game.
	FollowerFeedbackUI._process(10.0)
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	EnemyWorld.clear_world()
