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
const ENEMY := preload("res://core/actors/enemy/enemy.tscn")
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const WINDUP := preload("res://scenes/world/bosses/BossWindupSprites.gd")
const IMPACT := preload("res://scenes/world/bosses/BossImpactSprites.gd")
const SLAM_OFFSET := Vector2(-450, -180)
const SHOCK_OFFSET := Vector2(-170, -180)
const MINE_OFFSET := Vector2(170, -180)
const PROJECT_VIEWPORT := Vector2i(1920, 1080)
const WORLD_SEED := 16102026

var _out := "res://docs/art/reference/2026-10-16-boss-step2-vfx/"
var _visible := false
var _failures := 0
var _save_writes_before := 0
var _game: Node2D
var _player: Node2D
var _camera: Camera2D
var _stage: Node2D
var _beam: BossBeamSweep
var _scope: Node
var _tank: EnemyActor
var _mage: EnemyActor
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
	# Incidental tutorial messages are not part of this staged gallery and can
	# obscure its title. Retain the production HUD's actual combat/status UI.
	var tip_controller := _game.get_node_or_null("UI/HUD/TutorialTipController")
	if tip_controller != null:
		var tip_callback := Callable(tip_controller, "_on_tutorial_tip")
		if RunEvents.tutorial_tip.is_connected(tip_callback):
			RunEvents.tutorial_tip.disconnect(tip_callback)
		var illustrated_callback := Callable(tip_controller, "_on_illustrated_tutorial_tip")
		if RunEvents.illustrated_tutorial_tip.is_connected(illustrated_callback):
			RunEvents.illustrated_tutorial_tip.disconnect(illustrated_callback)
		tip_controller.call("_abort_queue")
		tip_controller.call("_hide_now")
	get_tree().paused = false
	_freeze(_game)
	for singleton: String in ["EnemySimulationScheduler", "EnemyIndex", "ThreatDirector", "EnemyWorld", "EnemyCombat", "EnemyStatus", "ProjectileManager", "HitFeel"]:
		var service := get_node_or_null("/root/" + singleton)
		if service != null:
			service.set_process(false)
			service.set_physics_process(false)
	_origin = _player.global_position
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = dimensions
		# Deliberately retain PROJECT_VIEWPORT. Changing it to dimensions would
		# make art bigger than actual gameplay at this window size.
		for active: bool in [false, true]:
			if is_instance_valid(_stage):
				_stage.queue_free()
				await _frames(1)
			_build_stage(active)
			var proxy := _game.get_node_or_null("EnemyProxyRoot")
			if proxy != null and proxy.get("renderer") != null:
				proxy.get("renderer").call("publish")
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
			_captures.append({"file": name_value, "image_size": str(pixels.get_size()), "window_size": str(dimensions), "radial_phase": "impact at 0.035 seconds" if active else "60 percent windup / mine half fuse", "beam_phase": phase, "boss_pose": "production charge and fan anticipation sampled at half windup; actors stationary", "world_px_to_image_px": float(dimensions.x) / float(PROJECT_VIEWPORT.x) * _camera.zoom.x})
	if SaveManager.debug_save_writes != _save_writes_before or SaveManager.current_save != null:
		_failures += 1
		push_error("BossVfxGamePreview unexpectedly wrote/selected a profile.")
	var info := {"scene": "res://scenes/game.tscn", "presentation": "STAGED / frozen actual Game production VFX, not an encounter or playability test", "viewport": str(PROJECT_VIEWPORT), "stretch": "canvas_items", "camera_zoom": str(_camera.zoom), "world_seed": WORLD_SEED, "segment": 2, "player_position": str(_origin), "selected_world_positions": _selected, "captures": _captures, "save_writes": SaveManager.debug_save_writes - _save_writes_before, "failures": _failures, "boss_forms": {"tank": _tank.get_meta(&"boss_appearance", {}), "mage": _mage.get_meta(&"boss_appearance", {})}, "asset_sources": {"slam": "res://scenes/world/bosses/art/vfx/slam_fracture_v1.png", "shock": "res://scenes/world/bosses/art/vfx/shock_crackle_v1.png", "mine": "res://scenes/world/bosses/art/vfx/mine_sigil_v1.png", "beam": "res://scenes/world/bosses/art/vfx/arcane_beam_body.tres", "beam_atlas": "res://scenes/world/bosses/art/vfx/arcane_beam_v2.png", "charge": "res://scenes/world/bosses/art/vfx/charge_windup_v1.png", "pulse": "res://assets/textures/vfx/encounters/pulse_ripple_v1.png", "bomber_perimeter": "res://assets/textures/vfx/encounters/bomber_perimeter_v1.png", "bomber_fuse": "res://assets/textures/vfx/encounters/bomber_blast_v1.png"}}
	var file := FileAccess.open(absolute_out.path_join("capture-info.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "\t"))
	else:
		_failures += 1
		push_error("Cannot write capture-info.json")
	print("BossVfxGamePreview: four staged actual Game captures; failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _build_stage(active: bool) -> void:
	var previous_children := _game.get_children()
	_stage = Node2D.new()
	_stage.name = "StagedProductionVfxForArtComparison"
	_game.add_child(_stage)
	var source := Node2D.new()
	_stage.add_child(source)
	_scope = SCOPE.new()
	source.add_child(_scope)
	_scope.call("setup", source)
	# The bosses use their actual spec/body profiles and unchanged unit roots.
	# At this distance the tank's real charge brain naturally accepts the cast.
	_tank = _add_boss(TANK, "Bulldozer charge", Vector2(-300, 60))
	_mage = _add_boss(MAGE, "Arcanist fan", Vector2(490, 100))
	var tank_direction := _player.global_position - _tank.global_position
	_tank._charge.brain(tank_direction, tank_direction.length())
	_advance_windups(_tank, _tank.spec.charge_windup * 0.5)
	var mage_brain := _mage.get_node("BossBrain")
	mage_brain.call("_fan_shot")
	_advance_windups(_mage, float(mage_brain.get("fan_telegraph")) * 0.5)
	var fan_warning: Node = mage_brain.get("_fan_warning")
	if fan_warning != null:
		fan_warning.call("_process", float(mage_brain.get("fan_telegraph")) * 0.5)
	if active:
		# Same production spawn helpers used by the actual tank casts. Their
		# separate damage footprints stay frozen before any physics callback.
		var tank_brain := _tank.get_node("BossBrain")
		for radial: Dictionary in [{"name": "Slam", "offset": SLAM_OFFSET, "radius": 135.0, "kind": &"slam"}, {"name": "Shock", "offset": SHOCK_OFFSET, "radius": 85.0, "kind": &"shock"}]:
			var at := _at(String(radial["name"]), radial["offset"])
			tank_brain.call("_spawn_wave", at, float(radial["radius"]), radial["kind"])
			tank_brain.call("_spawn_damage_circle", at, float(radial["radius"]), 0.0, 0.18, radial["kind"])
	else:
		_add_warning("Slam", SLAM_OFFSET, 135.0, source, &"slam")
		_add_warning("Shock", SHOCK_OFFSET, 85.0, source, &"shock")
	# Separate the Bomber's full 105 px perimeter from the staged fan cone
	# above and the beam's right-hand edge to the left.
	var bomber := _add_actor("Bomber", Vector2(300, 260))
	if active:
		# A lit fuse is shown without advancing the Bomber brain or detonating it.
		bomber._bomber._fuse_left = EnemyBomber.FUSE_TIME * 0.5
	for child in bomber.get_children():
		if child is VFX_BomberHazardRing:
			child.call("_process", 0.0)
	var mine := MINE.instantiate() as BossMine
	mine.setup(_at("Mine", MINE_OFFSET), source, 1.05, 95.0, 14.0)
	SCOPE.bind(mine, source)
	_stage.add_child(mine)
	mine._process(mine.fuse + 0.001 if active else mine.fuse * 0.5)
	var pylon := PYLON.instantiate() as BossPylon
	pylon.setup(_at("Pylon", Vector2(500, -160)), source, 12.0)
	_stage.add_child(pylon)
	pylon._cd = 0.0
	pylon._process(0.0)
	pylon._process(pylon.shot_windup * 0.5)
	_beam = BEAM.instantiate() as BossBeamSweep
	_beam.setup(_at("Beam origin", Vector2(-520, 300)), deg_to_rad(-8.0), deg_to_rad(102.0), source)
	SCOPE.bind(_beam, source)
	_stage.add_child(_beam)
	var pulse := PULSE.instantiate() as PulseRing
	# Keep the ripple left of the generated wall staircase as well as clear
	# of the Bomber's full perimeter at this frozen pulse phase.
	pulse.setup(_at("Current pulse ripple", Vector2(540, 300)), 120.0)
	_stage.add_child(pulse)
	pulse._process(pulse.duration * 0.22)
	_set_beam_phase(active)
	# Production cast helpers append to current_scene. Adopt those exact nodes
	# for ownership/cleanup; their world transforms and artwork remain intact.
	for child in _game.get_children():
		if child == _stage or previous_children.has(child):
			continue
		child.reparent(_stage, true)
		if child.get_script() == IMPACT:
			child.call("_process", 0.035)
	var phase := "IMPACT SAMPLES" if active else "WINDUP SAMPLES"
	_label(Vector2(-665, -385), Vector2(1360, 44), "BOSS VFX / " + phase + " / STAGED IN ACTUAL GAME", 27)
	_label(Vector2(-665, -345), Vector2(1360, 36), "Real player + terrain + HUD / normal camera / bosses remain in frozen anticipation", 21)
	_label(Vector2(-590, -28), Vector2(280, 34), "SLAM / stone fracture / R135", 21)
	_label(Vector2(-290, -65), Vector2(240, 34), "SHOCK / crackle / R85", 21)
	_label(Vector2(50, -65), Vector2(240, 34), "MINE / occult sigil / R95", 21)
	_label(Vector2(400, -80), Vector2(240, 34), "PYLON / visible shot cue", 20)
	_label(Vector2(-585, 155), Vector2(390, 52), "BULLDOZER / charge anticipation\nFull 280.8 world px committed lane", 20)
	_label(Vector2(560, 110), Vector2(230, 60), "ARCANIST / fan\nActual cast windup", 20)
	_label(Vector2(185, 390), Vector2(230, 40), "BOMBER / " + ("lit fuse" if active else "perimeter"), 20)
	_label(Vector2(-500, 345), Vector2(680, 52), "BEAM / 680 x 34 world px\n" + ("Active sweep sample" if active else "Anticipation sample"), 21)
	_label(Vector2(380, 455), Vector2(320, 34), "CURRENT PULSE / authored ripple", 20)
	_label(Vector2(-55, 100), Vector2(160, 34), "REAL PLAYER", 20)
	_freeze(_stage)


func _add_actor(spec_name: String, offset: Vector2) -> EnemyActor:
	var actor := ENEMY.instantiate() as EnemyActor
	actor.spec = load("res://core/actors/enemy/EnemySpec_%s.tres" % spec_name) as EnemySpec
	actor.position = _at("Enemy " + spec_name, offset)
	actor.collision_layer = 0
	actor.collision_mask = 0
	_stage.add_child(actor)
	actor.player = _player
	if actor.animator != null:
		actor.animator.tick(Vector2.ZERO)
	_freeze(actor)
	return actor


func _add_boss(scene: PackedScene, label: String, offset: Vector2) -> EnemyActor:
	var actor := scene.instantiate() as EnemyActor
	actor.set_meta(&"boss_visual_tier", 1)
	actor.add_to_group(&"boss")
	actor.position = _at(label, offset)
	actor.collision_layer = 0
	actor.collision_mask = 0
	_stage.add_child(actor)
	actor.player = _player
	_freeze(actor)
	return actor


func _advance_windups(actor: EnemyActor, seconds: float) -> void:
	for child in actor.get_children():
		if child.get_script() == WINDUP:
			child.call("_process", seconds)


func _add_warning(label: String, offset: Vector2, radius: float, source: Node, style: StringName) -> void:
	var warning := WARNING.new()
	warning.set_attack_style(style)
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
