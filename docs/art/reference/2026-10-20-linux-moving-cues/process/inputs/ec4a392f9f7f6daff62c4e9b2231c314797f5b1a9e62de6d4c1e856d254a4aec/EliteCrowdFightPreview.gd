extends Node
## Seeded, LIVE combat in the production Game scene for elite-readability review.
## <godot> --path . res://tools/dev/EliteCrowdFightPreview.tscn -- --out=C:/folder
## Optional: --visible, --seconds=10, --fps=15, --reduced-motion.
## Never run beside a human playtest. Only this process's inputs/settings change.

const GAME := preload("res://scenes/game.tscn")
const ENEMY := preload("res://core/actors/enemy/enemy.tscn")
const PROJECT_VIEWPORT := Vector2i(1920, 1080)
const WINDOW_SIZE := Vector2i(1280, 720)
const WORLD_SEED := 1610202607
const ORDINARY_COUNT := 38
const INPUT_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"aim_left", &"aim_right", &"aim_up", &"aim_down", &"attack",
]
const ORDINARY_SPECS: Array[String] = ["Grunt", "Grunt", "Brute", "Orbiter", "Spitter", "Charger", "Bomber"]
const ELITE_CASES: Array[Dictionary] = [
	{"spec": "Brute", "ids": [EliteModifiers.ARMOURED], "at": Vector2(-380, -130)},
	{"spec": "Spitter", "ids": [EliteModifiers.VAMPIRIC], "at": Vector2(340, -180)},
	{"spec": "Grunt", "ids": [EliteModifiers.SHIELDED], "at": Vector2(-120, 260)},
	{"spec": "Brute", "ids": [EliteModifiers.SPLITTING], "at": Vector2(360, 190)},
	{"spec": "Charger", "ids": [EliteModifiers.FAST], "at": Vector2(-480, 150)},
	{"spec": "Brute", "ids": [EliteModifiers.ARMOURED, EliteModifiers.VAMPIRIC], "at": Vector2(-80, -280)},
	{"spec": "Grunt", "ids": [EliteModifiers.SHIELDED, EliteModifiers.FAST], "at": Vector2(570, -30)},
	{"spec": "Orbiter", "ids": [EliteModifiers.VAMPIRIC, EliteModifiers.FAST], "at": Vector2(140, -330)},
	{"spec": "Brute", "ids": [EliteModifiers.ARMOURED, EliteModifiers.SPLITTING, EliteModifiers.FAST], "at": Vector2(530, 260)},
	{"spec": "Grunt", "ids": [], "at": Vector2(-570, -300)},
]

var _out := "user://dev_previews/elite_crowd_fight"
var _visible := false
var _seconds := 10.0
var _fps := 15
var _reduced_motion := false
var _game: Node2D
var _player: CharacterBody2D
var _camera: Camera2D
var _chunks: ChunkManager
var _origin := Vector2.ZERO
var _running := false
var _combat_time := 0.0
var _save_writes_before := 0
var _failures := 0
var _weapon_fires := 0
var _player_hits := 0
var _elite_hits := 0
var _deaths := 0
var _elite_deaths := 0
var _max_projectiles := 0
var _occupied: Array[Vector2] = []
var _elite_refs: Array[WeakRef] = []
var _initial_elites: Array[Dictionary] = []
var _capture_info: Array[Dictionary] = []
var _pixels: Array[Image] = []


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/elite_crowd_fight_preview_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	PerformanceFlightRecorder.set_enabled(false)
	PerformanceFlightRecorder.automatic_capture = false
	BalanceRecorder.set_enabled(false)
	_save_writes_before = SaveManager.debug_save_writes
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--visible":
			_visible = true
		elif arg == "--reduced-motion":
			_reduced_motion = true
		elif arg.begins_with("--seconds="):
			_seconds = clampf(arg.trim_prefix("--seconds=").to_float(), 1.0, 20.0)
		elif arg.begins_with("--fps="):
			_fps = clampi(arg.trim_prefix("--fps=").to_int(), 5, 24)
	if not _visible:
		get_window().position = Vector2i(-10000, -10000)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("A rendering driver is required for actual combat pixels.")
		get_tree().quit(1)
		return
	var absolute_out := ProjectSettings.globalize_path(_out)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_out.path_join("frames"))
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_fail("Cannot create output: " + error_string(dir_error))
		get_tree().quit(1)
		return
	_prepare_runtime()
	_game = GAME.instantiate() as Node2D
	# Install save isolation above BEFORE any production node enters the tree.
	# Only ambient population is controlled: combat services stay fully live.
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	# SceneTree.current_scene must be a direct child of its root. Keeping the
	# capture controller alongside Game also lets it finish after Game teardown.
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	var settled := false
	for frame in range(300):
		await get_tree().process_frame
		if frame >= 12 and _chunks.debug_chunk_queue().is_empty() and _chunks.pending_blocker_stage_count() == 0:
			settled = true
			break
	if not settled:
		_fail("Production world did not finish warm-up within 300 frames.")
		await _shutdown()
		return
	_dismiss_dossiers()
	_origin = _player.global_position
	_connect_evidence_events()
	seed(WORLD_SEED)
	Global._rng.seed = WORLD_SEED
	_spawn_encounter()
	# Promotion reenables enemy process state; do not freeze actor simulation.
	# Wait only two physics frames so the opening still catches readable tells.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_running = true
	Input.action_press(&"attack")
	var began_usec := Time.get_ticks_usec()
	var next_capture := 0.0
	while _combat_time < _seconds:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if get_tree().paused:
			_fail("An unexpected modal paused live combat.")
			break
		if _combat_time + 0.0001 < next_capture:
			continue
		var pixels := get_viewport().get_texture().get_image()
		pixels.convert(Image.FORMAT_RGB8)
		_pixels.append(pixels)
		_capture_info.append(_sample(float(Time.get_ticks_usec() - began_usec) / 1_000_000.0))
		next_capture = _combat_time + 1.0 / float(_fps)
	_running = false
	_release_inputs()
	get_tree().paused = true
	var wall_duration := float(Time.get_ticks_usec() - began_usec) / 1_000_000.0
	# Encode AFTER combat so disk/PNG compression never slows the recording.
	for index in range(_pixels.size()):
		_save_image(_pixels[index], absolute_out.path_join("frames/frame-%04d.png" % index))
		if index % 20 == 0:
			await get_tree().process_frame
	if not _pixels.is_empty():
		_save_image(_pixels[0], absolute_out.path_join("elite-crowd-opening.png"))
		_save_image(_pixels[floori(float(_pixels.size()) * 0.5)], absolute_out.path_join("elite-crowd-midfight.png"))
		_save_image(_pixels.back(), absolute_out.path_join("elite-crowd-ending.png"))
	var writes := SaveManager.debug_save_writes - _save_writes_before
	if writes != 0 or SaveManager.current_save != null:
		_fail("Unexpected profile selection or save write.")
	if _weapon_fires == 0 or _player_hits == 0:
		_fail("Live native player attacks did not land during the capture.")
	var info := {
		"scene": "res://scenes/game.tscn",
		"presentation": "LIVE seeded combat; production player, enemy AI, nav, projectiles, damage, deaths, batched renderer, terrain and HUD",
		"controlled_conditions": "Ambient spawner and encounter beats disabled; scripted controller movement/aim with held native attack; player god mode; no enemy stat changes. One triple-modifier example deliberately tests a combination beyond the normal two-modifier collapse roll.",
		"world_seed": WORLD_SEED,
		"segment": 2,
		"viewport": str(PROJECT_VIEWPORT),
		"image_size": str(WINDOW_SIZE),
		"camera_zoom": str(_camera.zoom),
		"world_px_to_image_px": float(WINDOW_SIZE.x) / float(PROJECT_VIEWPORT.x) * _camera.zoom.x,
		"reduced_motion": _reduced_motion,
		"initial_enemies": ORDINARY_COUNT + ELITE_CASES.size(),
		"initial_elites": _initial_elites,
		"requested_simulation_seconds": _seconds,
		"simulation_seconds": _combat_time,
		"wall_seconds": wall_duration,
		"target_capture_fps": _fps,
		"captured_frames": _pixels.size(),
		"weapon_fires": _weapon_fires,
		"player_hits": _player_hits,
		"elite_hits": _elite_hits,
		"enemy_deaths": _deaths,
		"elite_deaths": _elite_deaths,
		"max_managed_projectiles": _max_projectiles,
		"save_writes": writes,
		"failures": _failures,
		"frames": _capture_info,
	}
	var file := FileAccess.open(absolute_out.path_join("capture-info.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write capture-info.json")
	else:
		file.store_string(JSON.stringify(info, "\t"))
		file.close()
	print("EliteCrowdFightPreview -> ", absolute_out)
	print("EliteCrowdFightPreview: live sim=", _combat_time, "s wall=", wall_duration, "s frames=", _pixels.size(), " fires=", _weapon_fires, " hits=", _player_hits, " deaths=", _deaths, " save writes=", writes, " failures=", _failures)
	await _shutdown()


func _prepare_runtime() -> void:
	SettingsManager.set_value(&"accessibility", &"combat_flash", "full", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", _reduced_motion, false)
	SettingsManager.set_value(&"controls", &"hold_to_attack", true, false)
	StoryDirector.cards_override = 0
	Global.apply_save(SaveData.new())
	Global.debug_dev_mode = true
	Global.debug_dev_segment = false
	Global.debug_player_god_mode = true
	Global.debug_enemy_visual_batching = true
	Global.enemy_proxy_rollout = true
	Global.debug_encounter_beats = false
	Global.selected_style_id = "ranged"
	Global.selected_weapon_id = "ranged"
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.attempt_world_seed = WORLD_SEED
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	get_window().title = "Synthetic Ascension — live crowded elite fight"
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = PROJECT_VIEWPORT
	get_window().content_scale_factor = 1.0
	get_window().size = WINDOW_SIZE
	Engine.max_fps = 60
	Engine.time_scale = 1.0
	_release_inputs()


func _dismiss_dossiers() -> void:
	var tutorials: Node = _game.get("_tutorial_modals")
	if tutorials != null:
		if RunEvents.enemy_archetype_encountered.is_connected(tutorials._on_enemy_encountered):
			RunEvents.enemy_archetype_encountered.disconnect(tutorials._on_enemy_encountered)
		if RunEvents.blocking_info_requested.is_connected(tutorials._on_blocking_info_requested):
			RunEvents.blocking_info_requested.disconnect(tutorials._on_blocking_info_requested)
		tutorials.set("_queue", [])
	for child in _game.get_children():
		if child is TutorialCardOverlay:
			child.call("_dismiss")
	get_tree().paused = false


func _spawn_encounter() -> void:
	for index in range(ELITE_CASES.size()):
		var entry := ELITE_CASES[index]
		var actor := _spawn_actor(String(entry["spec"]), _origin + Vector2(entry["at"]))
		var ids: Array[StringName] = []
		ids.assign(entry["ids"])
		actor.apply_elite_modifiers(ids)
		_elite_refs.append(weakref(actor))
		var actual: Array[StringName] = actor.elite_modifier_ids()
		if actual != ids:
			_fail("Elite modifier fixture was filtered unexpectedly: " + str(ids) + " -> " + str(actual))
		_initial_elites.append({"index": index, "spec": entry["spec"], "modifiers": actual, "world": str(actor.global_position)})
	for index in range(ORDINARY_COUNT):
		var ring := index % 3
		var angle := float(index) * 2.399963229728653
		var offset := Vector2(cos(angle) * (265.0 + float(ring) * 150.0), sin(angle) * (145.0 + float(ring) * 110.0))
		_spawn_actor(ORDINARY_SPECS[index % ORDINARY_SPECS.size()], _origin + offset)


func _spawn_actor(spec_name: String, desired: Vector2) -> EnemyActor:
	var actor := ENEMY.instantiate() as EnemyActor
	actor.spec = load("res://core/actors/enemy/EnemySpec_%s.tres" % spec_name) as EnemySpec
	actor.position = _free_spawn_position(desired)
	_occupied.append(actor.position)
	_game.add_child(actor)
	actor.player = _player
	return actor


func _free_spawn_position(desired: Vector2) -> Vector2:
	var cell := _chunks.world_to_cell(desired)
	for radius in range(7):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var sample := cell + Vector2i(x, y)
				if not _chunks.is_cell_walkable(sample):
					continue
				var point := _chunks.cell_to_world_center(sample)
				var separated := true
				for previous in _occupied:
					if previous.distance_squared_to(point) < 44.0 * 44.0:
						separated = false
						break
				if separated:
					return point
	_fail("No collision-free spawn cell near " + str(desired))
	return desired


func _physics_process(delta: float) -> void:
	if not _running or _player == null:
		return
	_combat_time += delta
	# A modest circle-kite uses the production movement speed/collision path.
	var target := _origin + Vector2(sin(_combat_time * 0.72) * 145.0, cos(_combat_time * 0.72) * 95.0)
	var movement := (target - _player.global_position).limit_length(100.0) / 100.0
	_set_axis(&"move_left", &"move_right", movement.x)
	_set_axis(&"move_up", &"move_down", movement.y)
	var aim := _aim_at_live_enemy()
	_set_axis(&"aim_left", &"aim_right", aim.x)
	_set_axis(&"aim_up", &"aim_down", aim.y)
	_max_projectiles = maxi(_max_projectiles, ProjectileManager.active_count())


func _aim_at_live_enemy() -> Vector2:
	var nearest: Node2D = null
	var best := INF
	# Native controller aim. Target selection alternates through the crowd,
	# paying real projectile travel, cooldowns, collisions and armour.
	var sweep := Vector2.RIGHT.rotated(_combat_time * 0.48)
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var actor := node as EnemyActor
		if actor == null or actor.dead:
			continue
		var offset := actor.global_position - _player.global_position
		var score := offset.length() + (1.0 - offset.normalized().dot(sweep)) * 220.0
		if score < best:
			best = score
			nearest = actor
	if nearest == null:
		return sweep
	return (_player.global_position.direction_to(nearest.global_position))


func _set_axis(negative: StringName, positive: StringName, value: float) -> void:
	Input.action_release(negative)
	Input.action_release(positive)
	if value > 0.0:
		Input.action_press(positive, value)
	elif value < 0.0:
		Input.action_press(negative, -value)


func _sample(wall_time: float) -> Dictionary:
	var elites: Array[Dictionary] = []
	for index in range(_elite_refs.size()):
		var actor := _elite_refs[index].get_ref() as EnemyActor
		if actor == null or actor.dead:
			elites.append({"index": index, "alive": false})
			continue
		var image_point := actor.get_global_transform_with_canvas().origin * (float(WINDOW_SIZE.x) / float(PROJECT_VIEWPORT.x))
		elites.append({"index": index, "alive": true, "hp": actor.hp, "max_hp": actor.max_hp, "world": str(actor.global_position), "image": str(image_point), "modifiers": actor.elite_modifier_ids()})
	return {"simulation_time": _combat_time, "wall_time": wall_time, "enemies": EnemyWorld.active_count(), "projectiles": ProjectileManager.active_count(), "weapon_fires": _weapon_fires, "player_hits": _player_hits, "enemy_deaths": _deaths, "player_world": str(_player.global_position), "elites": elites}


func _connect_evidence_events() -> void:
	RunEvents.weapon_fired.connect(func(_source: Node, _style: StringName, _from: Vector2, _to: Vector2, _power: float, _haste: float) -> void: _weapon_fires += 1)
	RunEvents.player_hit_landed.connect(func(_source: Node, _handle: int, _position: Vector2, _amount: float, _crit: bool, elite: bool) -> void:
		_player_hits += 1
		if elite:
			_elite_hits += 1
	)
	RunEvents.enemy_defeated.connect(func(context: RefCounted) -> void:
		_deaths += 1
		if bool(context.get("is_elite")):
			_elite_deaths += 1
	)


func _release_inputs() -> void:
	for action in INPUT_ACTIONS:
		Input.action_release(action)


func _save_image(pixels: Image, path: String) -> void:
	var result := pixels.save_png(path)
	if result != OK:
		_fail("Capture write failed: " + error_string(result))


func _fail(message: String) -> void:
	_failures += 1
	push_error("EliteCrowdFightPreview: " + message)


func _shutdown() -> void:
	_running = false
	_release_inputs()
	Engine.time_scale = 1.0
	Engine.max_fps = 0
	get_tree().paused = false
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _exit_tree() -> void:
	_release_inputs()
	Engine.time_scale = 1.0
