extends Node
## Frozen court evidence in the actual Game scene and production district.
## Run with a rendering driver, only when no human playtest is active.
## User args: -- --segment=5|10 [--out=C:/folder] [--visible]

const GAME := preload("res://scenes/game.tscn")
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const APPEARANCE := preload("res://scenes/world/bosses/BossAppearance.gd")
const ARENA_SPACE := preload("res://core/systems/world/proc/BossArenaSpace.gd")
const VIEWPORT := Vector2i(1920, 1080)
const WINDOW_SIZE := Vector2i(960, 540)
const WORLD_SEED := 16102026

var _segment := 5
var _out := "res://docs/art/reference/2026-10-16-boss-arena-courts/"
var _visible := false
var _save_writes := 0
var _failures := 0
var _game: Node2D
var _player: Node2D
var _camera: Camera2D
var _chunks: ChunkManager
var _arena: Node2D
var _boss: EnemyActor
var _plan: Dictionary = {}
var _coord := Vector2i.ZERO
var _origin := Vector2.ZERO


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Install isolation before any Game/player/world _ready can execute.
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/boss_arena_court_preview_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	PerformanceFlightRecorder.set_enabled(false)
	PerformanceFlightRecorder.automatic_capture = false
	BalanceRecorder.set_enabled(false)
	_save_writes = SaveManager.debug_save_writes
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--segment="):
			_segment = int(arg.trim_prefix("--segment="))
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--visible":
			_visible = true
	if not _visible:
		get_window().position = Vector2i(-10000, -10000)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless" or _segment not in [5, 10]:
		push_error("BossArenaCourtPreview needs rendering and --segment=5 or --segment=10.")
		get_tree().quit(1)
		return
	var absolute_out := ProjectSettings.globalize_path(_out)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_out)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("Boss arena output directory: " + error_string(directory_error))
		get_tree().quit(1)
		return
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
	Global.attempt_segment = _segment
	Global.attempt_world_seed = WORLD_SEED
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	get_window().title = "Synthetic Ascension — frozen boss court evidence"
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = VIEWPORT
	get_window().content_scale_factor = 1.0
	get_window().size = WINDOW_SIZE
	Engine.max_fps = 60
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as Node2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	var builder := get_tree().get_first_node_in_group(&"segment_proc_builder") as SegmentProcBuilder
	if builder == null:
		push_error("Boss arena preview has no production SegmentProcBuilder.")
		get_tree().quit(1)
		return
	_plan = builder._plan.duplicate(true)
	_coord = _plan.get("miniboss_chunk" if _segment == 5 else "boss_chunk", DistrictPlan.INVALID_CHUNK) as Vector2i
	if _coord == DistrictPlan.INVALID_CHUNK:
		push_error("Boss arena preview plan lacks its milestone court.")
		get_tree().quit(1)
		return
	var planned_origin: Vector2 = _plan.get("miniboss_world" if _segment == 5 else "boss_world", Vector2.ZERO)
	_origin = ARENA_SPACE.anchor_world(planned_origin, _chunks.chunk_size_px)
	for child: Node in _game.find_children("*", "", true, false):
		if child is BossArena or child is MiniBossArena:
			_hold_arena(child)
			if (_segment == 5 and child is MiniBossArena) or (_segment == 10 and child is BossArena):
				_arena = child as Node2D
	if _arena == null or not _arena.global_position.is_equal_approx(_origin):
		push_error("Boss arena root does not match the protected court anchor.")
		get_tree().quit(1)
		return
	_player.global_position = _origin + Vector2(0, 320)
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	var settled := false
	for frame in range(300):
		await get_tree().process_frame
		if frame >= 15 and _chunks._chunks.has(_coord) and _chunks.debug_chunk_queue().is_empty() and _chunks.pending_blocker_stage_count() == 0:
			settled = true
			break
	if not settled:
		_failures += 1
		push_error("BossArenaCourtPreview: production court streaming did not settle.")
	_dismiss_tutorials()
	get_tree().paused = false
	_freeze(_game)
	for singleton: String in ["EnemySimulationScheduler", "EnemyIndex", "ThreatDirector", "EnemyWorld", "EnemyCombat", "EnemyStatus", "ProjectileManager", "HitFeel"]:
		var service := get_node_or_null("/root/" + singleton)
		if service != null:
			service.set_process(false)
			service.set_physics_process(false)
	_stage_boss()
	_dismiss_tutorials()
	_freeze(_game)
	_make_caption()
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	_publish()
	for frame in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var capture_name := "actual-game-boss-court-s%d-960x540.png" % _segment
	var pixels := get_viewport().get_texture().get_image()
	if pixels.get_size() != WINDOW_SIZE or pixels.save_png(absolute_out.path_join(capture_name)) != OK:
		_failures += 1
		push_error("Boss arena capture failed: " + capture_name)
	else:
		print("BossArenaCourtPreview -> ", absolute_out.path_join(capture_name))
	if SaveManager.debug_save_writes != _save_writes or SaveManager.current_save != null or SaveManager.current_slot != -1:
		_failures += 1
		push_error("BossArenaCourtPreview unexpectedly wrote or selected a profile.")
	_write_metadata(absolute_out, capture_name)
	print("BossArenaCourtPreview: segment=", _segment, " actual Game capture; failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _hold_arena(arena: Node) -> void:
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var trigger := arena.get_node_or_null("Trigger") as Area2D
	if trigger != null:
		trigger.monitoring = false
		trigger.monitorable = false
	var shape := arena.get_node_or_null("Trigger/CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.disabled = true


func _stage_boss() -> void:
	# Invoke the actual tier rules and spawned-event/HUD path, choosing one
	# deterministic visual sample. This is a frozen scene, not a fight run.
	if _segment == 5:
		(_arena as MiniBossArena).tank_boss_scenes = [TANK]
		(_arena as MiniBossArena).mage_boss_scenes = []
	else:
		(_arena as BossArena).tank_boss_scenes = []
		(_arena as BossArena).mage_boss_scenes = [MAGE]
	_arena.call("_spawn")
	_boss = _arena.get("_enemy" if _segment == 5 else "_boss") as EnemyActor
	if _boss == null:
		_failures += 1
		push_error("BossArenaCourtPreview could not stage the production boss.")
		return
	APPEARANCE.apply(_boss, 0 if _segment == 5 else 1)
	_boss.player = _player
	_freeze(_boss)
	var expected_home := _origin + Vector2(0, -80 if _segment == 5 else -90)
	if not _boss.global_position.is_equal_approx(expected_home):
		_failures += 1
		push_error("Staged boss does not occupy the production tier spawn offset.")


func _make_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var caption := Label.new()
	caption.position = Vector2(60, 846)
	caption.size = Vector2(1300, 84)
	caption.text = "STAGED S%d COURT / actual district, player, boss and camera\n" % _segment
	caption.text += "Normal zoom at 960×540. Frozen actors; no attack or balance test.\n"
	caption.text += "Protected court: %d×%d world px; streets remain open." % [1280 if _segment == 5 else 1792, 1280 if _segment == 5 else 1792]
	caption.add_theme_font_size_override("font_size", 23)
	caption.add_theme_color_override("font_color", Color("eee9d8"))
	caption.add_theme_color_override("font_shadow_color", Color(0.04, 0.03, 0.03, 1))
	caption.add_theme_constant_override("shadow_outline_size", 4)
	layer.add_child(caption)


func _write_metadata(absolute_out: String, capture_name: String) -> void:
	var role: StringName = &"miniboss_arena" if _segment == 5 else &"boss_arena"
	var local_rect: Rect2i = ARENA_SPACE.clear_rect(role, _chunks._cells_per_chunk())
	var world_rect := Rect2(Vector2(_coord) * float(_chunks.chunk_size_px) + Vector2(local_rect.position) * float(_chunks.cell_size_px), Vector2(local_rect.size) * float(_chunks.cell_size_px))
	var chunk := _chunks._chunks.get(_coord) as Node2D
	var reservations_match: bool = chunk != null and chunk.get_meta(&"_boss_arena_clear_rect", Rect2i()) == local_rect
	if not reservations_match:
		_failures += 1
		push_error("Rendered chunk lacks the expected protected boss court.")
	var gen: ChunkGenImpl = _chunks._content_gen
	var cx := gen._lane_center_for_col(_coord.x, _chunks._cells_per_chunk())
	var cy := gen._lane_center_for_row(_coord.y, _chunks._cells_per_chunk())
	var mask := _chunks.get_chunk_connectors(_coord)
	var sockets: Array[Dictionary] = []
	for direction: Dictionary in [{"bit": 1, "name": "north", "cell": Vector2i(cx, 0)}, {"bit": 2, "name": "east", "cell": Vector2i(31, cy)}, {"bit": 4, "name": "south", "cell": Vector2i(cx, 31)}, {"bit": 8, "name": "west", "cell": Vector2i(0, cy)}]:
		if mask & int(direction["bit"]):
			var cell: Vector2i = direction["cell"]
			var world_position := Vector2(_coord) * float(_chunks.chunk_size_px) + (Vector2(cell) + Vector2(0.5, 0.5)) * float(_chunks.cell_size_px)
			sockets.append({"direction": direction["name"], "local_cell": str(cell), "world_position": str(world_position)})
	var visible_world := Rect2(_camera.get_screen_center_position() - Vector2(VIEWPORT) * 0.5 / _camera.zoom, Vector2(VIEWPORT) / _camera.zoom)
	var info := {"scene": "res://scenes/game.tscn", "presentation": "Frozen production arena, fixed archetype sample; final art/animation and human playtest remain pending", "segment": _segment, "world_seed": WORLD_SEED, "plan_seed": _plan.get("seed"), "plan_generation_attempt": _plan.get("generation_attempt"), "theme_id": _plan.get("theme_id"), "arena_role": role, "arena_chunk": str(_coord), "court_local_cells": str(local_rect), "court_world_rect": str(world_rect), "court_reservations_match": reservations_match, "arena_world_position": str(_arena.global_position), "boss_world_position": str(_boss.global_position) if _boss != null else "missing", "boss_appearance": _boss.get_meta(&"boss_appearance", {}) if _boss != null else {}, "player_world_position": str(_player.global_position), "player_offset_from_court": str(_player.global_position - _origin), "connector_mask": mask, "connected_street_sockets": sockets, "viewport": str(VIEWPORT), "window": str(WINDOW_SIZE), "camera_zoom": str(_camera.zoom), "visible_world_rect": str(visible_world), "world_px_to_image_px": 0.5 * _camera.zoom.x, "note": "Normal camera shows part of the court; full-court clearance and lanes are verified separately across procedural seeds.", "capture": capture_name, "save_writes": SaveManager.debug_save_writes - _save_writes, "current_slot": SaveManager.current_slot, "failures": _failures}
	var file := FileAccess.open(absolute_out.path_join("court-s%d-capture-info.json" % _segment), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "\t"))
	else:
		_failures += 1
		push_error("Cannot write boss court capture metadata.")


func _dismiss_tutorials() -> void:
	var tutorials: Node = _game.get("_tutorial_modals")
	if tutorials != null:
		if RunEvents.enemy_archetype_encountered.is_connected(tutorials._on_enemy_encountered):
			RunEvents.enemy_archetype_encountered.disconnect(tutorials._on_enemy_encountered)
		tutorials.set("_queue", [])
	for child: Node in _game.get_children():
		if child is TutorialCardOverlay:
			child.call("_dismiss")
	# Keep incidental movement and encounter tips out of this frozen court
	# capture while preserving the actual combat/status HUD and boss bar.
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


func _publish() -> void:
	var proxy := _game.get_node_or_null("EnemyProxyRoot")
	if proxy != null and proxy.get("renderer") != null:
		proxy.get("renderer").call("publish")


func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is AnimatedSprite2D:
		(node as AnimatedSprite2D).pause()
	elif node is AnimationPlayer:
		(node as AnimationPlayer).pause()
	for child: Node in node.get_children():
		_freeze(child)
