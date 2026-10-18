extends Node
## Staged Segment 10 main-boss telegraphs in the ACTUAL Game scene at
## segment 10 (its terrain and HUD), not a fight: the Bulldozer's Sweeping
## Cleave, Breach Sequence, Fault Line follow-up and phase beat; the
## Arcanist's Split Fan, rebuilt Arc Sweep (start and end lanes), Pylon Pair,
## phase cast and phase 3 mine arc; the boss bar's phase marks. Every cue is
## made by the production brain entry points, then frozen mid-tell.
## Rendered run: <godot> --path . res://tools/dev/S10BossTelegraphPreview.tscn
## User args: -- --out=/absolute/folder [--visible]
## Never run beside a human playtest. No profile or settings writes are allowed.

const GAME := preload("res://scenes/game.tscn")
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const WINDUP := preload("res://scenes/world/bosses/BossWindupSprites.gd")
const MAGE_BRAIN := preload("res://scenes/world/bosses/BossArcanistBrain.gd")
const TANK_BRAIN := preload("res://scenes/world/bosses/BossBulldozerBrain.gd")
const PROJECT_VIEWPORT := Vector2i(1920, 1080)
const WORLD_SEED := 16102026
## Each cue is frozen at this fraction of its tell.
const TELL_PROGRESS := 0.6

var _out := "res://docs/art/reference/2026-10-17-s10-boss-telegraphs/"
var _visible := false
var _failures := 0
var _save_writes_before := 0
var _game: Node2D
var _player: Node2D
var _camera: Camera2D
var _stage: Node2D
var _origin := Vector2.ZERO
var _captures: Array[Dictionary] = []


func _enter_tree() -> void:
	# All isolation is installed before any production Game/player/world
	# _ready() is allowed to execute.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/s10_boss_telegraph_preview_%d/" % Time.get_ticks_usec()
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
		push_error("S10BossTelegraphPreview requires a rendering driver.")
		get_tree().quit(1)
		return
	var absolute_out := ProjectSettings.globalize_path(_out)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_out)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_error("S10BossTelegraphPreview output: " + error_string(dir_error))
		get_tree().quit(1)
		return
	# Runtime-only settings; SettingsManager's persistent store is untouched.
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
	Global.attempt_segment = 10
	Global.attempt_world_seed = WORLD_SEED
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	get_window().title = "Synthetic Ascension — staged S10 boss telegraphs in actual Game"
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
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as Node2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	var chunks := _game.get_node("ChunkManager") as ChunkManager
	for frame in range(180):
		await get_tree().process_frame
		if chunks.debug_chunk_queue().is_empty() and chunks.pending_blocker_stage_count() == 0 and frame >= 12:
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
	_origin = _player.global_position
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = dimensions
		for panel: String in ["bulldozer", "arcanist", "arcanist-arc"]:
			if is_instance_valid(_stage):
				# The next panel's boss_spawned replaces the bar's boss; no
				# boss_cleared, which would also reach the story ledger.
				_stage.queue_free()
				await _frames(2)
			if panel == "bulldozer":
				_build_bulldozer()
			elif panel == "arcanist":
				_build_arcanist()
			else:
				_build_arcanist_arc()
			var proxy := _game.get_node_or_null("EnemyProxyRoot")
			if proxy != null and proxy.get("renderer") != null:
				proxy.get("renderer").call("publish")
			await _frames(5)
			await RenderingServer.frame_post_draw
			var name_value := "s10-%s-telegraphs-%dx%d.png" % [panel, dimensions.x, dimensions.y]
			var pixels := get_viewport().get_texture().get_image()
			if pixels.get_size() != dimensions:
				_fail("unexpected capture dimensions " + str(pixels.get_size()))
			var save_error := pixels.save_png(absolute_out.path_join(name_value))
			if save_error != OK:
				_fail("capture failed: " + error_string(save_error))
			else:
				print("S10BossTelegraphPreview -> ", absolute_out.path_join(name_value))
			_captures.append({"file": name_value, "panel": panel, "window_size": str(dimensions), "tell_progress": TELL_PROGRESS, "world_px_to_image_px": float(dimensions.x) / float(PROJECT_VIEWPORT.x) * _camera.zoom.x})
	if SaveManager.debug_save_writes != _save_writes_before or SaveManager.current_save != null:
		_fail("unexpectedly wrote or selected a profile")
	var info := {"scene": "res://scenes/game.tscn", "presentation": "STAGED / frozen actual Game: production S10 brain entry points frozen mid-tell; not an encounter, playability or timing test", "viewport": str(PROJECT_VIEWPORT), "stretch": "canvas_items", "camera_zoom": str(_camera.zoom), "world_seed": WORLD_SEED, "player_position": str(_origin), "captures": _captures, "save_writes": SaveManager.debug_save_writes - _save_writes_before, "failures": _failures}
	var file := FileAccess.open(absolute_out.path_join("capture-info.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "\t"))
	else:
		_fail("cannot write capture-info.json")
	print("S10BossTelegraphPreview: %d staged captures; failures=%d" % [_captures.size(), _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _build_bulldozer() -> void:
	var before := _game.get_children()
	_stage = _new_stage()
	# Sweeping Cleave (phase 2): the sector shown on the ground, 75 degrees
	# either side of the facing, 125 px.
	var cleave := _add_boss(TANK, Vector2(-560, -170), Vector2(-470, -150))
	var brain := cleave.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	brain.call("_do_cleave")
	_hold(brain, TANK_BRAIN.CLEAVE_TELL)
	# Breach Sequence (phase 3): the committed lane and the impact waiting at
	# its end, both from the tell's first frame.
	var breach := _add_boss(TANK, Vector2(-430, 230), Vector2(-100, 230))
	brain = breach.get_node("BossBrain")
	brain.set("_boss_phase", 2)
	brain.call("_do_breach")
	_hold(brain, TANK_BRAIN.BREACH_RUSH_TELL)
	# Fault Line with its phase 3 follow-up: all six nodes previewed.
	var fault := _add_boss(TANK, Vector2(170, -330), Vector2(570, -330))
	brain = fault.get_node("BossBrain")
	brain.set("_boss_phase", 2)
	brain.set("_followup_dir", Vector2.RIGHT.rotated(TANK_BRAIN.FOLLOWUP_TURN))
	brain.call("_do_shockwave")
	_hold(brain, float(brain.get("shockwave_windup")))
	# The phase beat into phase 3: the boss braces in place, damageable.
	var brace := _add_boss(TANK, Vector2(470, 230), Vector2.ZERO)
	brain = brace.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	brain.call("_begin_phase_shift", 2)
	_hold(brain, TANK_BRAIN.PHASE_SHIFT_SECONDS)
	_adopt(before)
	_show_bar(fault, "Boss: The Bulldozer", 2)
	_label(Vector2(-665, -438), Vector2(1360, 40), "S10 BULLDOZER / STAGED IN ACTUAL GAME / tells frozen at 60%", 26)
	_label(Vector2(-760, -60), Vector2(420, 34), "SWEEPING CLEAVE / 150 deg x R125", 20)
	_label(Vector2(-560, 310), Vector2(520, 34), "BREACH / lane, then the impact at its end", 20)
	_label(Vector2(160, -230), Vector2(560, 34), "FAULT LINE + FOLLOW-UP / six nodes previewed", 20)
	_label(Vector2(290, 320), Vector2(360, 34), "PHASE BEAT / braced, damageable", 20)
	_label(Vector2(-55, 60), Vector2(160, 34), "REAL PLAYER", 20)
	_freeze(_stage)


func _build_arcanist() -> void:
	var before := _game.get_children()
	_stage = _new_stage()
	# Split Fan (phase 2): every bolt lane drawn, the gap left open.
	var split := _add_boss(MAGE, Vector2(-640, 200), Vector2(-340, 200))
	var brain := split.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	brain.call("_ensure_teaching")
	var aim := Vector2.RIGHT
	brain.call("_start_split", aim, 1.0, &"split", MAGE_BRAIN.SPLIT_TELL)
	_hold_teaching(brain, MAGE_BRAIN.SPLIT_TELL)
	# Arc Sweep (phase 2): the start lane and the announced end lane.
	var sweep := _add_boss(MAGE, Vector2(120, -330), Vector2(420, -330))
	brain = sweep.get_node("BossBrain")
	brain.set("_boss_phase", 1)
	brain.call("_ensure_teaching")
	brain.call("_start_sweep", -MAGE_BRAIN.SWEEP_HALF_ARC, MAGE_BRAIN.SWEEP_HALF_ARC, MAGE_BRAIN.SWEEP_TELL, &"sweep", MAGE_BRAIN.SWEEP_TELL + MAGE_BRAIN.SWEEP_TIME)
	_hold_teaching(brain, MAGE_BRAIN.SWEEP_TELL)
	var beam := brain.get("_channel") as BossBeamSweep
	if beam == null:
		_fail("the sweep did not channel")
	else:
		beam.call("_advance", MAGE_BRAIN.SWEEP_TELL * TELL_PROGRESS)
	# Phase cast and the Pylon Pair it raises around the real player.
	var pair := _add_boss(MAGE, Vector2(430, 200), Vector2.ZERO)
	brain = pair.get_node("BossBrain")
	brain.call("_ensure_teaching")
	brain.call("_show_windup", &"phase_cast", MAGE_BRAIN.PHASE_SHIFT_SECONDS, Vector2.LEFT)
	_advance_windups(pair, MAGE_BRAIN.PHASE_SHIFT_SECONDS * TELL_PROGRESS)
	brain.set("_boss_phase", 1)
	brain.call("_spawn_main_pylons")
	_adopt(before)
	var pylons := 0
	for child in _stage.get_children():
		if child is BossPylon:
			pylons += 1
			child._cd = 0.0
			child._process(0.0)
			child._process(child.shot_windup * TELL_PROGRESS)
	if pylons != 2:
		_fail("the phase raised %d pylons, not a pair" % pylons)
	_show_bar(pair, "Boss: The Arcanist", 1)
	_label(Vector2(-665, -438), Vector2(1360, 40), "S10 ARCANIST / STAGED IN ACTUAL GAME / tells frozen at 60%", 26)
	_label(Vector2(-800, 300), Vector2(560, 34), "SPLIT FAN / ten lanes, one 32 deg gap", 20)
	_label(Vector2(80, -230), Vector2(560, 34), "ARC SWEEP / start lane + announced end lane", 20)
	_label(Vector2(330, 280), Vector2(420, 34), "PHASE CAST + PYLON PAIR", 20)
	_label(Vector2(-55, 60), Vector2(160, 34), "REAL PLAYER", 20)
	_freeze(_stage)


func _build_arcanist_arc() -> void:
	var before := _game.get_children()
	_stage = _new_stage()
	# Mine arc (phase 3): four nodes around the real player; the escape
	# corridor kept clear of walls, other mines and the boss's body.
	var arc := _add_boss(MAGE, Vector2(-300, 60), Vector2.ZERO)
	var brain := arc.get_node("BossBrain")
	brain.set("_boss_phase", 2)
	brain.call("_ensure_teaching")
	if not bool(brain.call("_start_teaching_mines", 4)):
		_fail("the mine arc found no clear placement")
	else:
		for marker in brain.get("_teaching_markers"):
			marker.call("set_progress", TELL_PROGRESS)
		_advance_windups(arc, 0.6 * TELL_PROGRESS)
	_adopt(before)
	_show_bar(arc, "Boss: The Arcanist", 2)
	_label(Vector2(-665, -438), Vector2(1360, 40), "S10 ARCANIST PHASE 3 / STAGED IN ACTUAL GAME / tell frozen at 60%", 26)
	_label(Vector2(-200, 290), Vector2(400, 34), "MINE ARC / four nodes, corridor kept", 20)
	_label(Vector2(-55, 60), Vector2(160, 34), "REAL PLAYER", 20)
	_freeze(_stage)


func _new_stage() -> Node2D:
	var stage := Node2D.new()
	stage.name = "StagedS10TelegraphsForReview"
	_game.add_child(stage)
	return stage


## A main-tier boss at `offset` from the player, aimed at `aim_offset` (the
## real player when ZERO).
func _add_boss(scene: PackedScene, offset: Vector2, aim_offset: Vector2) -> EnemyActor:
	var actor := scene.instantiate() as EnemyActor
	actor.set_meta(&"boss_visual_tier", 1)
	actor.add_to_group(&"boss")
	actor.add_to_group(&"boss_like")
	actor.position = _origin + offset
	actor.collision_layer = 0
	actor.collision_mask = 0
	_stage.add_child(actor)
	var target := Node2D.new()
	target.name = "AimTarget"
	target.position = _origin + aim_offset
	_stage.add_child(target)
	actor.player = target if aim_offset != Vector2.ZERO else _player
	actor.set_process(false)
	actor.set_physics_process(false)
	var brain := actor.get_node("BossBrain")
	brain.set_process(false)
	brain.set_physics_process(false)
	return actor


## Bulldozer: the controller's own anticipation update at TELL_PROGRESS.
func _hold(brain: Node, tell: float) -> void:
	if StringName(brain.get("_cast")) == &"":
		_fail("a Bulldozer cast did not begin")
		return
	brain.set("_cast_elapsed", tell * TELL_PROGRESS)
	brain.call("_update_teaching_anticipation")


## Arcanist: its markers' progress at TELL_PROGRESS, as the controller sets it.
func _hold_teaching(brain: Node, tell: float) -> void:
	if StringName(brain.get("_teaching_state")) == &"idle":
		_fail("an Arcanist pattern did not begin")
		return
	var actor := brain.get_parent() as EnemyActor
	_advance_windups(actor, tell * TELL_PROGRESS)


func _advance_windups(actor: Node, seconds: float) -> void:
	for child in actor.get_children():
		if child.get_script() == WINDUP:
			if bool(child.get("externally_driven")):
				continue
			child.call("_process", seconds)


func _show_bar(boss: EnemyActor, title: String, phase: int) -> void:
	boss.hp = boss.max_hp * (0.55 if phase == 1 else 0.24)
	RunEvents.boss_spawned.emit(boss, 1, null, title)
	RunEvents.boss_phase_changed.emit(boss, phase)
	var bar := _game.find_child("BossBarHUD", true, false)
	var front := bar.get_node_or_null("Panel/HBox/VBox/HpBar/HpFrame") if bar != null else null
	if front == null:
		_fail("the boss bar has no front ornament")
		return
	# The settled look: the pass flash is a moment, not the state.
	front.set("_mark_flash", 0.0)
	front.queue_redraw()


## Production cast helpers add to current_scene; adopt those exact nodes.
func _adopt(before: Array) -> void:
	for child in _game.get_children():
		if child == _stage or before.has(child):
			continue
		child.reparent(_stage, true)


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


func _quiet_tutorials() -> void:
	var tutorials: Node = _game.get("_tutorial_modals")
	if tutorials != null:
		if RunEvents.enemy_archetype_encountered.is_connected(tutorials._on_enemy_encountered):
			RunEvents.enemy_archetype_encountered.disconnect(tutorials._on_enemy_encountered)
		tutorials.set("_queue", [])
	for child in _game.get_children():
		if child is TutorialCardOverlay:
			child.call("_dismiss")
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


func _fail(message: String) -> void:
	_failures += 1
	push_error("S10BossTelegraphPreview: " + message)


func _frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame
