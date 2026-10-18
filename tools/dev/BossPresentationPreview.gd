extends Node
## Representative renderer using production actors, player and boss HUD.
## Not a human playtest, encounter simulation or animation quality verdict.
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const PLAYER := preload("res://core/actors/player/player.tscn")
const BAR := preload("res://ui/widgets/BossBarHUD.tscn")
const PROJECT_VIEWPORT := Vector2i(1920, 1080)
var _out := "res://.superpowers/sdd/2026-10-18-finish-boss-delivery/presentation/captures/"
var _save_writes_before := 0
var _failures := 0
var _game: Node2D
var _stage: Node2D
var _player: Node2D
var _origin := Vector2.ZERO
var _captures: Array[Dictionary] = []
var _teaching_bar: BossBarHUD

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://boss_presentation_preview_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	PerformanceFlightRecorder.set_enabled(false)
	PerformanceFlightRecorder.automatic_capture = false
	BalanceRecorder.set_enabled(false)
	_save_writes_before = SaveManager.debug_save_writes
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	get_window().position = Vector2i(-10000, -10000)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("presentation preview requires rendering")
		get_tree().quit(1)
		return
	var absolute_out := ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(absolute_out)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	AudioServer.set_bus_mute(0, true)
	Global.apply_save(SaveData.new())
	Global.debug_dev_mode = true
	Global.debug_player_god_mode = true
	Global.attempt_segment = 10
	get_window().title = "Synthetic Ascension — representative boss equipment and acting"
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = PROJECT_VIEWPORT
	get_window().content_scale_factor = 1.0
	get_window().size = Vector2i(1280, 720)
	Engine.max_fps = 60
	RenderingServer.set_default_clear_color(Color("171b1e"))
	_game = Node2D.new()
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = PLAYER.instantiate() as Node2D
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_game.add_child(_player)
	_player.get_node("Camera2D").set("enabled", false)
	var camera := Camera2D.new()
	_game.add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	_game.add_child(layer)
	var hud := Control.new()
	hud.size = Vector2(PROJECT_VIEWPORT)
	layer.add_child(hud)
	var bar := BAR.instantiate()
	bar.name = "BossBarHUD"
	hud.add_child(bar)
	_teaching_bar = BAR.instantiate() as BossBarHUD
	_teaching_bar.offset_top = 104.0
	_teaching_bar.offset_bottom = 178.0
	hud.add_child(_teaching_bar)
	var controller := HudBossController.new()
	controller.boss_bar_path = NodePath("../BossBarHUD")
	hud.add_child(controller)
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
		for role: String in ["bulldozer", "arcanist"]:
			for reduced: bool in [false, true]:
				if is_instance_valid(_stage):
					_stage.queue_free()
					await _frames(2)
				SettingsManager.set_value(&"accessibility", &"reduced_motion", reduced, false)
				_build_presentation(role, reduced)
				await _frames(4)
				await RenderingServer.frame_post_draw
				var filename := "%s-%s-%dx%d.png" % [role, "reduced" if reduced else "normal", dimensions.x, dimensions.y]
				var pixels := get_viewport().get_texture().get_image()
				if pixels.get_size() != dimensions or pixels.save_png(absolute_out.path_join(filename)) != OK:
					_fail("failed capture " + filename)
				var phase_pixels := _equipment_pixel_changes(pixels, dimensions)
				if phase_pixels < 4:
					_fail("equipment phase changes did not reach rendered body pixels: " + filename)
				_captures.append({"file": filename, "role": role, "reduced_motion": reduced, "window": str(dimensions), "equipment_phase_changed_pixels": phase_pixels})
	if SaveManager.debug_save_writes != _save_writes_before or SaveManager.current_save != null:
		_fail("unexpected profile writes or selection")
	var file := FileAccess.open(absolute_out.path_join("capture-info.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"scene": "res://tools/dev/BossPresentationPreview.tscn", "presentation": "Representative production actors/player/boss HUD at the project viewport and zoom1. Top row phase 1/2/3; bottom row real attack windup/release/recovery. Plain background; not the actual Game world, fight, timing test or human art approval.", "captures": _captures, "save_writes": SaveManager.debug_save_writes - _save_writes_before, "failures": _failures}, "\t"))
	else:
		_fail("cannot write capture metadata")
	print("BossPresentationPreview: %d captures; failures=%d" % [_captures.size(), _failures])
	get_tree().quit(1 if _failures else 0)

func _build_presentation(role: String, reduced: bool) -> void:
	var before := _game.get_children()
	_stage = _new_stage()
	var packed := TANK if role == "bulldozer" else MAGE
	var bar_boss: EnemyActor
	for phase in range(3):
		var actor := _add_boss(packed, Vector2(-390 + phase * 390, -190), Vector2(-290 + phase * 390, -190))
		var brain := actor.get_node("BossBrain")
		brain.set("_boss_phase", phase)
		actor.get_node("BossActing").call("_physics_process", 0.2)
		_label(Vector2(-535 + phase * 390, -90), Vector2(290, 40), "PHASE %d / EQUIPMENT" % (phase + 1), 21)
		bar_boss = actor
	for state in range(3):
		var actor := _add_boss(packed, Vector2(-390 + state * 390, 170), Vector2(-290 + state * 390, 170))
		var brain := actor.get_node("BossBrain")
		brain.set("_boss_phase", 2)
		var acting := actor.get_node("BossActing")
		if role == "bulldozer":
			brain.call("_do_slam")
		else:
			brain.call("_ensure_teaching")
			brain.call("_start_teaching_fan")
		acting.call("_physics_process", 0.2)
		if state > 0:
			if role == "bulldozer":
				brain.call("_tick_cast", 1.31)
			else:
				brain.call("_process_teaching", 0.96)
			acting.call("_physics_process", 0.02)
			if state == 2:
				acting.call("_physics_process", 0.3)
		_label(Vector2(-535 + state * 390, 280), Vector2(290, 40), ["WINDUP", "RELEASE", "RECOVERY"][state], 22)
	_adopt(before)
	# This board evaluates body poses. The real attack helpers ran above, but
	# their foreground impact sprites would cover the recovery body's feet.
	for child in _stage.get_children():
		if child is EnemyActor:
			for cue in child.get_children():
				if cue is CanvasItem and cue.get_script() == preload("res://scenes/world/bosses/BossWindupSprites.gd"):
					cue.hide()
		elif child is CanvasItem and child is not Label:
			child.hide()
	_show_bar(bar_boss, "Boss: The " + role.capitalize(), 2)
	_label(Vector2(-730, -300), Vector2(1460, 50), "S10 %s / REPRESENTATIVE RENDERER / %s" % [role.to_upper(), "REDUCED MOTION" if reduced else "PHASE EQUIPMENT + ACTING"], 25)
	_label(Vector2(-600, 355), Vector2(1200, 60), "Production poses and original footprints; cues hidden for body inspection. Human motion/readability review remains separate.", 19)
	_freeze(_stage)

func _new_stage() -> Node2D:
	var stage := Node2D.new()
	_game.add_child(stage)
	return stage

func _add_boss(packed: PackedScene, offset: Vector2, aim_offset: Vector2) -> EnemyActor:
	var actor := packed.instantiate() as EnemyActor
	actor.set_meta(&"boss_visual_tier", 1)
	actor.add_to_group(&"boss")
	actor.add_to_group(&"boss_like")
	actor.position = offset
	actor.collision_layer = 0
	actor.collision_mask = 0
	_stage.add_child(actor)
	var target := Node2D.new()
	target.position = aim_offset
	_stage.add_child(target)
	actor.player = target
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.get_node("BossBrain").set_process(false)
	actor.get_node("BossBrain").set_physics_process(false)
	return actor

func _show_bar(actor: EnemyActor, title: String, phase: int) -> void:
	actor.hp = actor.max_hp * 0.24
	RunEvents.boss_spawned.emit(actor, 1, null, title)
	RunEvents.boss_phase_changed.emit(actor, phase)
	var front := _game.find_child("BossBarHUD", true, false).get_node("Panel/HBox/VBox/HpBar/HpFrame")
	front.set("_mark_flash", 0.0)
	front.queue_redraw()
	_teaching_bar.show_boss("S5 portrait: " + actor.spec.display_name, preload("res://scenes/world/bosses/BossAppearance.gd").portrait_for(actor, 0), actor.max_hp, actor.max_hp)

func _adopt(before: Array) -> void:
	for child in _game.get_children():
		if child != _stage and not before.has(child):
			child.reparent(_stage, true)

func _label(offset: Vector2, bounds: Vector2, value: String, font_size: int) -> void:
	var label := Label.new()
	label.position = offset
	label.size = bounds
	label.text = value
	label.z_index = 4096
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eee9d8"))
	_stage.add_child(label)

func _freeze(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_freeze(child)

func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().process_frame

func _fail(message: String) -> void:
	_failures += 1
	push_error("BossPresentationPreview: " + message)

func _equipment_pixel_changes(pixels: Image, dimensions: Vector2i) -> int:
	# Identical production form/pose, exactly 780 world pixels apart. Compare
	# only the bodies (no labels/HUD) to catch a shader that ignores phase.
	var factor := float(dimensions.x) / 1920.0
	var region := Rect2i(Vector2i(Vector2(dimensions) * 0.5 + Vector2(-445, -250) * factor), Vector2i(Vector2(120, 130) * factor))
	var first := pixels.get_region(region)
	region.position.x += roundi(780.0 * factor)
	var third := pixels.get_region(region)
	var changed := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			var a := first.get_pixel(x, y)
			var b := third.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.03:
				changed += 1
	return changed
