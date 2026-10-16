extends Node
## Staged production hazards in the ACTUAL Game scene, not a fight/playtest.
## Keeps project 1920x1080 canvas_items scaling and the actual player camera.
## Rendered run: <godot> --path . res://tools/dev/BossVfxGamePreview.tscn
## User args: -- --out=C:/absolute/folder [--visible]
## Never run beside a human playtest. No profile or settings writes are allowed.

const GAME := preload("res://scenes/game.tscn")
const WARNING := preload("res://scenes/world/bosses/BossGroundWarning.gd")
const SCOPE := preload("res://scenes/world/bosses/BossAttackScope.gd")
const MINE := preload("res://scenes/world/bosses/BossMine.tscn")
const BEAM := preload("res://scenes/world/bosses/BossBeamSweep.tscn")
const PYLON := preload("res://scenes/world/bosses/BossPylon.tscn")
const PULSE := preload("res://assets/vfx/world/sets/conduit/VFX_PulseRing.tscn")
const SLASH := preload("res://assets/vfx/world/augments/VFX_SpiritSlash.tscn")
const ENEMY := preload("res://core/actors/enemy/enemy.tscn")
const PROJECT_VIEWPORT := Vector2i(1920, 1080)
const WORLD_SEED := 16102026

var _out := "res://docs/art/reference/2026-10-16-boss-vfx-game/"
var _visible := false
var _failures := 0
var _save_writes_before := 0
var _game: Node2D
var _player: Node2D
var _camera: Camera2D
var _stage: Node2D
var _beam: BossBeamSweep
var _scope: Node
var _origin := Vector2.ZERO
var _selected: Dictionary = {}
var _captures: Array[Dictionary] = []


func _enter_tree() -> void:
	# The fixture has no Game child in its tscn: all isolation is installed
	# before any production Game/player/world _ready() is allowed to execute.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/boss_vfx_game_preview_%d/" % Time.get_ticks_usec()
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
	if not _visible:
		get_window().position = Vector2i(-10000, -10000)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("BossVfxGamePreview requires a rendering driver.")
		get_tree().quit(1)
		return
	var absolute_out := ProjectSettings.globalize_path(_out)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_out)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_error("BossVfxGamePreview output: " + error_string(dir_error))
		get_tree().quit(1)
		return
	# All changes are runtime-only. SettingsManager's persistent store is untouched.
	SettingsManager.set_value(&"accessibility", &"combat_flash", "full", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	AudioServer.set_bus_mute(0, true)
	StoryDirector.cards_override = 0
	Global.apply_save(SaveData.new())
	Global.debug_dev_mode = true
	Global.debug_dev_segment = false
	Global.debug_player_god_mode = true
	Global.debug_encounter_beats = false
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.attempt_world_seed = WORLD_SEED
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	get_window().title = "Synthetic Ascension — staged VFX in actual Game"
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = PROJECT_VIEWPORT
	get_window().content_scale_factor = 1.0
	get_window().size = Vector2i(1280, 720)
	Engine.max_fps = 60
	_game = GAME.instantiate() as Node2D
	# No ambient spawning or player attacks during the world warm-up. The
	# production _ready() still builds character art, camera, world and HUD.
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	# SceneTree.current_scene requires a direct child of root. The driver
	# remains its sibling and survives while the actual Game is current.
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as Node2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	var chunks := _game.get_node("ChunkManager") as ChunkManager
	for _frame in range(180):
		await get_tree().process_frame
		if chunks.debug_chunk_queue().is_empty() and chunks.pending_blocker_stage_count() == 0 and _frame >= 12:
			break
	if not chunks.debug_chunk_queue().is_empty() or chunks.pending_blocker_stage_count() != 0:
		_failures += 1
		push_error("BossVfxGamePreview: world generation did not settle.")
	# Dismiss incidental first-enemy dossiers while retaining the actual HUD.
	var tutorials: Node = _game.get("_tutorial_modals")
	if tutorials != null:
		if RunEvents.enemy_archetype_encountered.is_connected(tutorials._on_enemy_encountered):
			RunEvents.enemy_archetype_encountered.disconnect(tutorials._on_enemy_encountered)
		tutorials.set("_queue", [])
	for child in _game.get_children():
		if child is TutorialCardOverlay:
			child.call("_dismiss")
	get_tree().paused = false
	_freeze(_game)
	for singleton: String in ["EnemySimulationScheduler", "EnemyIndex", "ThreatDirector", "EnemyWorld", "EnemyCombat", "EnemyStatus", "ProjectileManager", "HitFeel"]:
		var service := get_node_or_null("/root/" + singleton)
		if service != null:
			service.set_process(false)
			service.set_physics_process(false)
	_origin = _player.global_position
	_build_stage()
	_freeze(_stage)
	var proxy := _game.get_node_or_null("EnemyProxyRoot")
	if proxy != null and proxy.get("renderer") != null:
		proxy.get("renderer").call("publish")
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = dimensions
		# Deliberately retain PROJECT_VIEWPORT. Changing it to dimensions would
		# make art bigger than actual gameplay at this window size.
		for active: bool in [false, true]:
			_set_beam_phase(active)
			await _frames(5)
			await RenderingServer.frame_post_draw
			var phase := "active" if active else "warning"
			var name_value := "actual-game-staged-vfx-%s-%dx%d.png" % [phase, dimensions.x, dimensions.y]
			var pixels := get_viewport().get_texture().get_image()
			if pixels.get_size() != dimensions:
				_failures += 1
				push_error("Unexpected capture dimensions: " + str(pixels.get_size()))
			var save_error := pixels.save_png(absolute_out.path_join(name_value))
			if save_error != OK:
				_failures += 1
				push_error("Capture failed: " + error_string(save_error))
			else:
				print("BossVfxGamePreview -> ", absolute_out.path_join(name_value))
			_captures.append({"file": name_value, "image_size": str(pixels.get_size()), "window_size": str(dimensions), "beam_phase": phase, "world_px_to_image_px": float(dimensions.x) / float(PROJECT_VIEWPORT.x) * _camera.zoom.x})
	if SaveManager.debug_save_writes != _save_writes_before or SaveManager.current_save != null:
		_failures += 1
		push_error("BossVfxGamePreview unexpectedly wrote/selected a profile.")
	var info := {"scene": "res://scenes/game.tscn", "presentation": "STAGED / frozen actual Game, not an encounter or playability test", "viewport": str(PROJECT_VIEWPORT), "stretch": "canvas_items", "camera_zoom": str(_camera.zoom), "world_seed": WORLD_SEED, "segment": 2, "player_position": str(_origin), "selected_world_positions": _selected, "captures": _captures, "save_writes": SaveManager.debug_save_writes - _save_writes_before, "failures": _failures, "kit_sources": {"ring_large": "256px, content radius121.5", "disc": "64px, content radius30", "streak": "64x16px, content height8"}}
	var file := FileAccess.open(absolute_out.path_join("capture-info.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "\t"))
	else:
		_failures += 1
		push_error("Cannot write capture-info.json")
	print("BossVfxGamePreview: four staged actual Game captures; failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _build_stage() -> void:
	_stage = Node2D.new()
	_stage.name = "StagedProductionVfxForArtComparison"
	_game.add_child(_stage)
	var source := Node2D.new()
	_stage.add_child(source)
	_scope = SCOPE.new()
	source.add_child(_scope)
	_scope.call("setup", source)
	_add_warning("Slam", Vector2(-500, -150), 135.0, source)
	_add_warning("Shock", Vector2(-150, -200), 85.0, source)
	_add_actor("Grunt", Vector2(-500, -150))
	_add_actor("Brute", Vector2(-150, -200))
	_add_actor("Bomber", Vector2(200, 35))
	_add_actor("Grunt", Vector2(650, 195), true)
	var mine := MINE.instantiate() as BossMine
	mine.setup(_at("Mine", Vector2(180, -200)), source, 1.05, 95.0, 14.0)
	SCOPE.bind(mine, source)
	_stage.add_child(mine)
	mine._process(mine.fuse * 0.5)
	for child in mine.get_children():
		if child.name != &"BlastWarning":
			child.queue_free()
	var pylon := PYLON.instantiate() as BossPylon
	pylon.setup(_at("Pylon", Vector2(500, -160)), source, 12.0)
	_stage.add_child(pylon)
	pylon._cd = 0.0
	pylon._process(0.0)
	pylon._process(pylon.shot_windup * 0.5)
	_beam = BEAM.instantiate() as BossBeamSweep
	_beam.setup(_at("Beam origin", Vector2(-500, 190)), deg_to_rad(-8.0), deg_to_rad(102.0), source)
	SCOPE.bind(_beam, source)
	_stage.add_child(_beam)
	var pulse := PULSE.instantiate() as PulseRing
	pulse.setup(_at("Existing pulse ring", Vector2(390, 240)), 120.0)
	_stage.add_child(pulse)
	pulse._process(pulse.duration * 0.22)
	var slash := SLASH.instantiate() as VFX_SpiritSlash
	var slash_pos := _at("Existing spirit slash", Vector2(60, -60))
	slash.setup(slash_pos - Vector2(70, 0), slash_pos)
	_stage.add_child(slash)
	slash._process(slash.duration * 0.35)
	_label(Vector2(-665, -365), Vector2(1360, 44), "STAGED VFX IN ACTUAL GAME / frozen production scenes", 28)
	_label(Vector2(-665, -323), Vector2(1360, 40), "Real terrain + player + enemies + HUD / original 1920 x 1080 viewport / normal camera zoom", 21)
	_label(Vector2(-640, -5), Vector2(280, 52), "BOSS SLAM / R135\nActual Grunt inside", 21)
	_label(Vector2(-275, -90), Vector2(250, 52), "BOSS SHOCK / R85\nActual Brute inside", 21)
	_label(Vector2(50, -80), Vector2(260, 40), "MINE / mid fuse / R95", 21)
	_label(Vector2(400, -95), Vector2(240, 40), "PYLON / windup", 21)
	_label(Vector2(-500, 225), Vector2(680, 52), "BOSS BEAM / 680 x 34 world px\nWarning and active samples / frozen", 21)
	_label(Vector2(80, 140), Vector2(270, 40), "EXISTING bomber ring", 20)
	_label(Vector2(240, 360), Vector2(300, 40), "EXISTING pulse / R120", 20)
	_label(Vector2(520, 300), Vector2(270, 52), "EXISTING elite FAST\nGenerated ribbon art", 20)
	_label(Vector2(-185, 72), Vector2(270, 52), "REAL PLAYER\nExisting Spirit Slash above", 20)


func _add_actor(spec_name: String, offset: Vector2, elite: bool = false) -> void:
	var actor := ENEMY.instantiate() as EnemyActor
	actor.spec = load("res://core/actors/enemy/EnemySpec_%s.tres" % spec_name) as EnemySpec
	actor.position = _at("Enemy " + spec_name + (" FAST" if elite else ""), offset)
	actor.collision_layer = 0
	actor.collision_mask = 0
	_stage.add_child(actor)
	actor.player = _player
	if elite:
		var modifiers: Array[StringName] = [EliteModifiers.FAST]
		actor.apply_elite_modifiers(modifiers)
	if actor.animator != null:
		actor.animator.tick(Vector2.ZERO)
	_freeze(actor)


func _add_warning(label: String, offset: Vector2, radius: float, source: Node) -> void:
	var warning := WARNING.new()
	warning.setup(_at(label, offset), radius, 0.65)
	SCOPE.bind(warning, source)
	_stage.add_child(warning)
	warning.set_progress(0.60)


func _at(label: String, offset: Vector2) -> Vector2:
	var result := _origin + offset
	_selected[label] = {"world": str(result), "offset_from_player": str(offset), "expected_1280x720_center": str((Vector2(PROJECT_VIEWPORT) * 0.5 + offset * _camera.zoom) * (1280.0 / 1920.0))}
	return result


func _set_beam_phase(active: bool) -> void:
	# Drive the real attack through its production phase code, then freeze it.
	_beam._t = 0.0
	_beam._phase = 0
	_beam._tick = 0.0
	_beam.rotation = deg_to_rad(-8.0)
	var seconds := _beam.telegraph_time * 0.5
	if active:
		seconds = _beam.telegraph_time + _beam.sweep_time * (8.0 / 110.0)
	_beam._process(seconds)
	_freeze(_beam)


func _label(offset: Vector2, bounds: Vector2, text_value: String, font_size: int) -> void:
	var label := Label.new()
	label.position = _origin + offset
	label.size = bounds
	label.text = text_value
	label.z_as_relative = false
	label.z_index = 4096
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eee9d8"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_y", 2)
	_stage.add_child(label)


func _freeze(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	if node is Area2D:
		node.collision_layer = 0
		node.collision_mask = 0
		node.monitoring = false
		node.monitorable = false
	for child in node.get_children():
		_freeze(child)


func _frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame
