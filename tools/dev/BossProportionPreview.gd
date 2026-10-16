extends Node
## Staged proportion studies in the real Game world at the real camera zoom.
## This is a frozen art board, not an encounter or a fight-balance test.
## Run only when no human playtest is active. Never writes a user profile.

const GAME := preload("res://scenes/game.tscn")
const PLAYER := preload("res://core/actors/player/player.tscn")
const ENEMY := preload("res://core/actors/enemy/enemy.tscn")
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const APPEARANCE := preload("res://scenes/world/bosses/BossAppearance.gd")
const ARENA_SPACE := preload("res://core/systems/world/proc/BossArenaSpace.gd")
const VIEWPORT := Vector2i(1920, 1080)
const WORLD_SEED := 16102026

class MeasurementGuides extends Node2D:
	var entries: Array[Dictionary] = []
	var mode: StringName = &"art"

	func _draw() -> void:
		# Dev-only measurement guides; these are not gameplay effect graphics.
		draw_line(Vector2(-780, 0), Vector2(780, 0), Color(0.76, 0.68, 0.43, 0.65), 1.0)
		if mode != &"footprint":
			return
		for entry: Dictionary in entries:
			var actor := entry["actor"] as Node2D
			var origin := actor.position
			var gear: Rect2 = entry["gear"]
			var anatomy: Rect2 = entry["anatomy"]
			draw_rect(Rect2(origin + gear.position, gear.size), Color(0.9, 0.77, 0.4, 0.8), false, 1.0)
			draw_rect(Rect2(origin + anatomy.position, anatomy.size), Color(0.95, 0.95, 0.85, 0.9), false, 1.0)
			var contact: Vector2 = entry["contact_size"]
			draw_rect(Rect2(origin - contact * 0.5, contact), Color(1.0, 0.42, 0.38, 0.9), false, 1.5)
			var radius := float(entry["body_radius"])
			var capsule := float(entry.get("capsule_height", 0.0))
			if capsule > radius * 2.0:
				var half_segment := capsule * 0.5 - radius
				draw_arc(origin - Vector2(0, half_segment), radius, PI, TAU, 32, Color(0.35, 0.85, 1.0, 0.95), 1.5)
				draw_arc(origin + Vector2(0, half_segment), radius, 0, PI, 32, Color(0.35, 0.85, 1.0, 0.95), 1.5)
				draw_line(origin + Vector2(-radius, -half_segment), origin + Vector2(-radius, half_segment), Color(0.35, 0.85, 1.0, 0.95), 1.5)
				draw_line(origin + Vector2(radius, -half_segment), origin + Vector2(radius, half_segment), Color(0.35, 0.85, 1.0, 0.95), 1.5)
			else:
				draw_arc(origin, radius, 0, TAU, 64, Color(0.35, 0.85, 1.0, 0.95), 1.5)

var _out := "res://docs/art/reference/2026-10-16-boss-proportions/"
var _visible := false
var _save_writes := 0
var _failures := 0
var _game: Node2D
var _player: Node2D
var _camera: Camera2D
var _stage: Node2D
var _guides: MeasurementGuides
var _entries: Array[Dictionary] = []
var _captures: Array[Dictionary] = []
var _heading: Label
var _legend: Label
var _origin := Vector2.ZERO


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/boss_proportion_preview_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	PerformanceFlightRecorder.set_enabled(false)
	PerformanceFlightRecorder.automatic_capture = false
	BalanceRecorder.set_enabled(false)
	_save_writes = SaveManager.debug_save_writes
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
		push_error("BossProportionPreview requires a rendering driver.")
		get_tree().quit(1)
		return
	var absolute_out := ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(absolute_out)
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
	get_window().title = "Synthetic Ascension — boss proportion studies"
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = VIEWPORT
	get_window().content_scale_factor = 1.0
	get_window().size = Vector2i(1280, 720)
	Engine.max_fps = 60
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as Node2D
	_camera = _player.get_node("Camera2D") as Camera2D
	for child: Node in _game.find_children("*", "", true, false):
		if child is BossArena or child is MiniBossArena:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			# The live arena's entry marker is unrelated to this measurement board.
			(child as CanvasItem).hide()
	var chunks := _game.get_node("ChunkManager") as ChunkManager
	_origin = _player.global_position
	var builder := get_tree().get_first_node_in_group(&"segment_proc_builder")
	if builder != null:
		var plan: Dictionary = builder.get("_plan")
		_origin = ARENA_SPACE.anchor_world(plan.get("boss_world", _origin) as Vector2, chunks.chunk_size_px)
	_player.global_position = _origin
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	for frame in range(240):
		await get_tree().process_frame
		if chunks.debug_chunk_queue().is_empty() and chunks.pending_blocker_stage_count() == 0 and frame >= 15:
			break
	if not chunks.debug_chunk_queue().is_empty() or chunks.pending_blocker_stage_count() != 0:
		_failures += 1
		push_error("BossProportionPreview: court generation did not settle.")
	_dismiss_tutorials()
	get_tree().paused = false
	_freeze(_game)
	for singleton: String in ["EnemySimulationScheduler", "EnemyIndex", "ThreatDirector", "EnemyWorld", "EnemyCombat", "EnemyStatus", "ProjectileManager", "HitFeel"]:
		var service := get_node_or_null("/root/" + singleton)
		if service != null:
			service.set_process(false)
			service.set_physics_process(false)
	(_player.get_node("Visual") as Node2D).hide()
	# Retain the production camera and world, with the comparison labels in
	# place of the HUD so this remains readable at a small gameplay window.
	(_game.get_node("UI/HUD") as Control).hide()
	_build_stage()
	_build_heading()
	_freeze(_stage)
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = dimensions
		for mode: StringName in [&"art", &"silhouette", &"footprint"]:
			_set_view(mode)
			for frame in range(5):
				await get_tree().process_frame
			_publish()
			await RenderingServer.frame_post_draw
			var name_value := "boss-proportions-%s-%dx%d.png" % [mode, dimensions.x, dimensions.y]
			var pixels := get_viewport().get_texture().get_image()
			if pixels.get_size() != dimensions or pixels.save_png(absolute_out.path_join(name_value)) != OK:
				_failures += 1
				push_error("Boss proportion capture failed: " + name_value)
			else:
				print("BossProportionPreview -> ", absolute_out.path_join(name_value))
			_captures.append({"file": name_value, "window": str(dimensions), "view": mode, "world_px_to_image_px": float(dimensions.x) / float(VIEWPORT.x) * _camera.zoom.x})
	if SaveManager.debug_save_writes != _save_writes or SaveManager.current_save != null:
		_failures += 1
		push_error("BossProportionPreview unexpectedly wrote or selected a profile.")
	var measurements: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		var actor := entry["actor"] as Node2D
		var record := entry.duplicate()
		record.erase("actor")
		record["actor_root_scale"] = str(actor.scale)
		record["boss_appearance"] = actor.get_meta(&"boss_appearance", {})
		measurements.append(record)
	var info := {"scene": "res://scenes/game.tscn", "presentation": "Frozen rough proportion studies; final animation and human approval pending", "viewport": str(VIEWPORT), "camera_zoom": str(_camera.zoom), "world_seed": WORLD_SEED, "segment": 10, "court_center": str(_origin), "human_occupied_reference_px": 77, "anatomy_note": "Source annotations exclude equipment; human reference includes hair", "measurements": measurements, "captures": _captures, "save_writes": SaveManager.debug_save_writes - _save_writes, "failures": _failures}
	var file := FileAccess.open(absolute_out.path_join("capture-info.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "\t"))
	else:
		_failures += 1
		push_error("Cannot write boss proportion measurement record.")
	print("BossProportionPreview: six actual Game captures; failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _build_stage() -> void:
	_stage = Node2D.new()
	_stage.name = "BossProportionStudies"
	_game.add_child(_stage)
	_stage.global_position = _origin + Vector2(0, 80)
	var slot := 0
	for race: StringName in [&"human", &"elf", &"dragonborn", &"warforged"]:
		_add_race(race, -675 + slot * 150)
		slot += 1
	for role: String in ["Brute", "Herald"]:
		_add_ordinary(role, -675 + slot * 150)
		slot += 1
	for row: Dictionary in [{"scene": TANK, "tier": 0, "label": "S5 Bulldozer"}, {"scene": TANK, "tier": 1, "label": "S10 Bulldozer"}, {"scene": MAGE, "tier": 0, "label": "S5 Arcanist"}, {"scene": MAGE, "tier": 1, "label": "S10 Arcanist"}]:
		var actor := (row["scene"] as PackedScene).instantiate() as EnemyActor
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.position = Vector2(-675 + slot * 150, -PlayerVisualController.FEET_BELOW_ORIGIN)
		_stage.add_child(actor)
		APPEARANCE.apply(actor, int(row["tier"]))
		var notes: Dictionary = actor.get_meta(&"boss_appearance", {})
		if notes.is_empty():
			_failures += 1
			push_error("Missing boss appearance: " + String(row["label"]))
		var entry := {"actor": actor, "label": row["label"], "anatomy": notes.get("anatomy_bounds_world", Rect2()), "gear": notes.get("equipment_bounds_world", Rect2()), "body_radius": notes.get("physical_radius", 0.0), "contact_size": notes.get("contact_size", Vector2.ZERO)}
		_add_entry(entry, -675 + slot * 150, "Anatomy %d px" % roundi(float(notes.get("anatomy_height_world", 0.0))))
		slot += 1
	_guides = MeasurementGuides.new()
	_guides.name = "DevMeasurementGuides"
	_guides.z_index = 100
	_guides.entries = _entries
	_stage.add_child(_guides)


func _add_race(race: StringName, x: float) -> void:
	# Extract the real visual subtree before any player gameplay _ready runs.
	var donor := PLAYER.instantiate()
	var visual := donor.get_node("Visual") as PlayerVisualController
	donor.remove_child(visual)
	donor.free()
	var host := Node2D.new()
	host.name = String(race).capitalize()
	host.position = Vector2(x, -PlayerVisualController.FEET_BELOW_ORIGIN)
	_stage.add_child(host)
	host.add_child(visual)
	visual.set_race(race)
	visual.set_preview(PlayerVisualController.State.IDLE, &"down")
	visual.call("_apply")
	visual.body.frame = 0
	visual.head.frame = 0
	visual.breath.stop()
	visual.head.position = Vector2.ZERO
	var body_bounds := _animated_bounds(visual.body, host.global_transform.affine_inverse())
	var head_bounds := _animated_bounds(visual.head, host.global_transform.affine_inverse())
	var occupied := body_bounds.merge(head_bounds)
	var entry := {"actor": host, "label": String(race).capitalize(), "anatomy": occupied, "gear": occupied, "body_radius": 25.0, "capsule_height": 58.0, "contact_size": Vector2(70, 70)}
	_add_entry(entry, x, "Occupied %d px" % roundi(occupied.size.y))


func _add_ordinary(role: String, x: float) -> void:
	var actor := ENEMY.instantiate() as EnemyActor
	actor.spec = load("res://core/actors/enemy/EnemySpec_%s.tres" % role)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	_stage.add_child(actor)
	var sprite := actor.get_node("Sprite2D") as Sprite2D
	var bounds := _static_bounds(sprite)
	actor.position = Vector2(x, -bounds.end.y)
	var entry := {"actor": actor, "label": "Ordinary " + role, "anatomy": bounds, "gear": bounds, "body_radius": 17.0, "contact_size": Vector2(34, 34)}
	_add_entry(entry, x, "Occupied %.1f px" % bounds.size.y)


func _add_entry(entry: Dictionary, x: float, subtitle: String) -> void:
	_entries.append(entry)
	var label := Label.new()
	label.position = Vector2(x - 73, 62)
	label.size = Vector2(146, 86)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = String(entry["label"]).replace(" ", "\n") + "\n" + subtitle
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	label.add_theme_color_override("font_shadow_color", Color(0.06, 0.05, 0.05, 0.95))
	label.add_theme_constant_override("shadow_outline_size", 3)
	label.z_index = 100
	_stage.add_child(label)


func _build_heading() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_heading = Label.new()
	_heading.position = Vector2(80, 120)
	_heading.add_theme_font_size_override("font_size", 30)
	_heading.add_theme_color_override("font_shadow_color", Color.BLACK)
	_heading.add_theme_constant_override("shadow_outline_size", 5)
	layer.add_child(_heading)
	_legend = Label.new()
	_legend.position = Vector2(80, 900)
	_legend.add_theme_font_size_override("font_size", 21)
	_legend.add_theme_color_override("font_shadow_color", Color.BLACK)
	_legend.add_theme_constant_override("shadow_outline_size", 4)
	layer.add_child(_legend)


func _set_view(mode: StringName) -> void:
	_guides.mode = mode
	_guides.queue_redraw()
	for entry: Dictionary in _entries:
		var actor := entry["actor"] as Node2D
		actor.modulate = Color(0, 0, 0, 1) if mode == &"silhouette" else Color(1, 1, 1, 0.45 if mode == &"footprint" else 1.0)
	_heading.text = "ROUGH BOSS PROPORTION STUDIES — " + String(mode).to_upper() + "\nActual gameplay camera • shared ground baseline • final animation pending"
	_legend.text = "Human reference: 77 world px. Bulldozer anatomy: 88 px in both tiers. Arcanist: 82 / 86 px.\n" + ("Ivory: anatomy; gold: equipment; blue: walking shape; red: contact hitbox." if mode == &"footprint" else "Equipment creates presence; the boss root stays at unit scale. Frozen art board, not a fight test.")
	_publish()


func _static_bounds(sprite: Sprite2D) -> Rect2:
	var bounds := Rect2(sprite.texture.get_image().get_used_rect())
	if sprite.centered:
		bounds.position -= sprite.texture.get_size() * 0.5
	bounds.position += sprite.offset
	return _transformed_rect(sprite.transform, bounds)


func _animated_bounds(sprite: AnimatedSprite2D, inverse_host: Transform2D) -> Rect2:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var bounds := Rect2(texture.get_image().get_used_rect())
	if sprite.centered:
		bounds.position -= texture.get_size() * 0.5
	bounds.position += sprite.offset
	return _transformed_rect(inverse_host * sprite.global_transform, bounds)


func _transformed_rect(transform: Transform2D, rect: Rect2) -> Rect2:
	var result := Rect2(transform * rect.position, Vector2.ZERO)
	for point: Vector2 in [rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
		result = result.expand(transform * point)
	return result


func _dismiss_tutorials() -> void:
	var tutorials: Node = _game.get("_tutorial_modals")
	if tutorials != null:
		if RunEvents.enemy_archetype_encountered.is_connected(tutorials._on_enemy_encountered):
			RunEvents.enemy_archetype_encountered.disconnect(tutorials._on_enemy_encountered)
		tutorials.set("_queue", [])
	for child: Node in _game.get_children():
		if child is TutorialCardOverlay:
			child.call("_dismiss")


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
