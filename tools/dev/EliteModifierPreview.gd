extends Node2D
## Real EnemyActor / EnemyProxyRenderer modifier comparison, isolated from saves.
## <godot> --path . res://tools/dev/EliteModifierPreview.tscn -- --out=C:/absolute/dir
## Default (or --capture): one still, 72 ordered PNGs and capture-info.json, then exit.
## --interactive keeps this fixture open; Escape closes it.
## --scale=1.0 (or --native) shows the original gameplay scale; default is 1.8.
## --still-only saves one warmed-up still and diagnostics without animation PNGs.

const ENEMY_SCENE := preload("res://core/actors/enemy/enemy.tscn")
const RENDERER_SCRIPT := preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")
const WORLD_SCRIPT := preload("res://core/systems/enemy_world/EnemyWorld.gd")
const TITLE_FONT := preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
const BODY_FONT := preload("res://assets/fonts/eb_garamond/EBGaramond-Variable.ttf")
const SCREEN_SIZE := Vector2i(1536, 1152)
const CARD_SIZE := Vector2(480.0, 468.0)
const CARD_STEP := Vector2(496.0, 486.0)
const CARD_ORIGIN := Vector2(32.0, 126.0)
const ACTOR_OFFSET := Vector2(240.0, 252.0)
const DETAIL_SCALE := 1.8
const CAPTURE_FRAMES := 72
const CAPTURE_FPS := 24
const STILL_FRAME := 36
const GOLD := Color("d6bf86")
const IVORY := Color("eee5cf")
const MUTED := Color("9da89b")

class PreviewProxyRoot:
	extends Node2D
	var renderer: Node = null

var _out := "user://dev_previews/elite_modifiers"
var _interactive := false
var _preview_scale := DETAIL_SCALE
var _still_only := false
var _renderer: EnemyProxyRenderer = null
var _actors: Array[EnemyActor] = []
var _dummy_player: Node2D = null
var _failures := 0
var _built := false
var _exiting := false
var _save_writes_before := 0
var _cards: Array[Dictionary] = [
	{
		"name": "ARMOURED", "spec": "Brute", "palette": "STEEL",
		"ids": [EliteModifiers.ARMOURED],
		"trait": "Steel plates  ·  Small hits reduced",
	},
	{
		"name": "VAMPIRIC", "spec": "Spitter", "palette": "RED",
		"ids": [EliteModifiers.VAMPIRIC],
		"trait": "Blood ring  ·  Drains nearby enemies",
	},
	{
		"name": "SHIELDED", "spec": "Grunt", "palette": "CYAN",
		"ids": [EliteModifiers.SHIELDED],
		"trait": "Wide ward  ·  Protects nearby enemies",
	},
	{
		"name": "SPLITTING", "spec": "Brute", "palette": "GREEN",
		"ids": [EliteModifiers.SPLITTING],
		"trait": "Fractured seam  ·  Divides on death",
	},
	{
		"name": "FAST", "spec": "Grunt", "palette": "YELLOW",
		"ids": [EliteModifiers.FAST],
		"trait": "Motion trails  ·  Faster and fragile",
		"velocity": Vector2(220.0, 0.0),
	},
	{
		"name": "ARMOURED + VAMPIRIC", "spec": "Brute", "palette": "STEEL",
		"palette_note": "STEEL SHEEN  ·  RED TELL",
		"ids": [EliteModifiers.ARMOURED, EliteModifiers.VAMPIRIC],
		"trait": "Steel sheen  ·  Blood ring stays red",
	},
]


func _enter_tree() -> void:
	# Isolation is installed before this fixture can create any game actors.
	# Runtime settings wait until deferred _run, after autoload _ready.
	Global.debug_disable_autosave = true
	Global.debug_enemy_visual_batching = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/elite_modifier_preview_%d/" % Time.get_ticks_usec()
	_save_writes_before = SaveManager.debug_save_writes
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--interactive":
			_interactive = true
		elif arg.begins_with("--scale="):
			var scale_text := arg.trim_prefix("--scale=")
			if scale_text.is_valid_float() and scale_text.to_float() > 0.0:
				_preview_scale = scale_text.to_float()
			else:
				_failures += 1
				push_error("EliteModifierPreview --scale requires a positive number")
		elif arg == "--native":
			_preview_scale = 1.0
		elif arg == "--still-only":
			_still_only = true
	if not _interactive:
		get_window().position = Vector2i(-10000, -10000)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)


func _ready() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("EliteModifierPreview needs a rendering driver; headless cannot capture pixels.")
		get_tree().quit(1)
		return
	_prepare_runtime()
	_build_layout()
	_build_renderer()
	_build_actors()
	_built = true
	for _frame in range(8):
		await get_tree().process_frame
	_verify_actors()
	if _interactive:
		print("EliteModifierPreview: interactive; Escape closes it. Save writes: ", SaveManager.debug_save_writes - _save_writes_before)
		return
	await _capture()
	await _shutdown(0 if _failures == 0 else 1)


func _prepare_runtime() -> void:
	# These values affect this process only; the user's settings are not saved.
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	for singleton: String in ["EnemySimulationScheduler", "EnemyIndex", "ThreatDirector", "EnemyWorld", "EnemyCombat", "EnemyStatus", "ProjectileManager", "HitFeel"]:
		var service := get_node_or_null("/root/" + singleton)
		if service != null:
			service.set_process(false)
			service.set_physics_process(false)
	BattleText.visible = false
	get_window().title = "Synthetic Ascension — Elite Modifier Preview"
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = SCREEN_SIZE
	get_window().content_scale_size = SCREEN_SIZE
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_factor = 1.0
	if not _interactive:
		get_window().position = Vector2i(-10000, -10000)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	Engine.max_fps = 60 if _interactive else CAPTURE_FPS


func _process(_delta: float) -> void:
	if not _built or _renderer == null:
		return
	for actor in _actors:
		if actor.animator != null:
			actor.animator.tick(actor.velocity)
	_renderer.publish()


func _unhandled_key_input(event: InputEvent) -> void:
	if _interactive and not _exiting and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_shutdown(0 if _failures == 0 else 1)


func _build_renderer() -> void:
	var world := WORLD_SCRIPT.new() as EnemyWorldService
	world.name = "PreviewEnemyWorld"
	add_child(world)
	var proxy_root := PreviewProxyRoot.new()
	proxy_root.name = "PreviewProxyRoot"
	# Match the production root so foreground tells must survive real depth.
	proxy_root.z_index = 10
	proxy_root.add_to_group(&"enemy_proxy_root")
	_renderer = RENDERER_SCRIPT.new() as EnemyProxyRenderer
	_renderer.setup(world)
	proxy_root.renderer = _renderer
	proxy_root.add_child(_renderer)
	add_child(proxy_root)
	_dummy_player = Node2D.new()
	_dummy_player.name = "PreviewPlayerAnchor"
	_dummy_player.position = Vector2(SCREEN_SIZE) * 0.5
	_dummy_player.add_to_group(&"player")
	add_child(_dummy_player)


func _build_layout() -> void:
	_rect(Rect2(Vector2.ZERO, Vector2(SCREEN_SIZE)), Color("0e1311"), -1000)
	_rect(Rect2(0, 0, SCREEN_SIZE.x, 109), Color("131913"), -999)
	_label(Rect2(32, 21, 1472, 42), "ELITE MODIFIERS", 32, GOLD, TITLE_FONT)
	var scale_label := "native scale (1.0×)" if is_equal_approx(_preview_scale, 1.0) else "%.1f×" % _preview_scale
	_label(Rect2(33, 67, 1470, 31), "Five tells, five palettes  ·  Sheen follows the first modifier  ·  Actual enemy rendering at " + scale_label, 22, MUTED)
	_rect(Rect2(32, 108, 1472, 1), Color("6f6140"), -90)
	for index in range(_cards.size()):
		var card := _cards[index]
		var origin := _card_origin(index)
		var ids: Array[StringName] = []
		ids.assign(card["ids"])
		var tint := EliteModifiers.tint(ids[0])
		_panel(Rect2(origin, CARD_SIZE), tint, index == 5)
		_rect(Rect2(origin + Vector2(21, 25), Vector2(7, 27)), tint, 50)
		_label(Rect2(origin + Vector2(41, 20), Vector2(418, 38)), card["name"], 22 if index == 5 else 25, IVORY, TITLE_FONT)
		_label(Rect2(origin + Vector2(23, 60), Vector2(300, 25)), card.get("palette_note", card["palette"] + " SHEEN"), 17, tint, TITLE_FONT)
		_label(Rect2(origin + Vector2(325, 60), Vector2(132, 25)), card["spec"], 19, MUTED, BODY_FONT, false, HORIZONTAL_ALIGNMENT_RIGHT)
		if ids.size() > 1:
			_rect(Rect2(origin + Vector2(386, 27), Vector2(10, 10)), tint, 50)
			_rect(Rect2(origin + Vector2(402, 27), Vector2(10, 10)), EliteModifiers.tint(ids[1]), 50)
		_rect(Rect2(origin + Vector2(22, 428), Vector2(436, 1)), Color("394337"), -90)
		_label(Rect2(origin + Vector2(20, 435), Vector2(440, 28)), card["trait"], 21, MUTED, BODY_FONT, true)
	_rect(Rect2(32, 1101, 1472, 1), Color("454735"), -90)
	_label(Rect2(32, 1113, 1472, 29), "Generated modifier art with live sheen  ·  Shield field retains its real 180 px radius  ·  Mixed marks keep their own colors", 21, MUTED)


func _card_origin(index: int) -> Vector2:
	return CARD_ORIGIN + Vector2(float(index % 3) * CARD_STEP.x, float(index / 3) * CARD_STEP.y)


func _build_actors() -> void:
	for index in range(_cards.size()):
		var card := _cards[index]
		var actor := ENEMY_SCENE.instantiate() as EnemyActor
		actor.spec = load("res://core/actors/enemy/EnemySpec_%s.tres" % card["spec"]) as EnemySpec
		actor.name = "Modifier_%d_%s" % [index, card["spec"]]
		actor.position = _card_origin(index) + ACTOR_OFFSET
		actor.scale = Vector2.ONE * _preview_scale
		actor.set_physics_process(false)
		actor.collision_layer = 0
		actor.collision_mask = 0
		add_child(actor)
		actor.player = _dummy_player
		actor.velocity = card.get("velocity", Vector2.ZERO)
		var hitbox := actor.get_node("Hitbox") as Area2D
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		if actor.animator != null:
			actor.animator.set("_phase_ms", 0)
		var ids: Array[StringName] = []
		ids.assign(card["ids"])
		# No fixture tint or substitute sprites: production promotion owns the
		# surface, modifier art, depths and the renderer's palette selection.
		actor.apply_elite_modifiers(ids)
		# Promotion re-enables the full simulation tier. Freeze AFTER it runs,
		# retaining child modifier animation and batched visual publication.
		actor.set_physics_process(false)
		actor.set_process(false)
		_actors.append(actor)


func _verify_actors() -> void:
	if _renderer.registered_actor_count() != _actors.size():
		_failures += 1
		push_error("EliteModifierPreview: an actor did not register with the real renderer")
	for actor in _actors:
		var sprite := actor.get_node("Sprite2D") as Sprite2D
		if sprite.visible or not actor.is_elite or actor.is_processing() or actor.is_physics_processing():
			_failures += 1
			push_error("EliteModifierPreview: actor promotion / batching / freeze failed: " + actor.name)


func _capture() -> void:
	var absolute_out := ProjectSettings.globalize_path(_out)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_out if _still_only else absolute_out.path_join("frames"))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_failures += 1
		push_error("EliteModifierPreview cannot create output: " + error_string(directory_error))
		return
	var captured_images: Array[Image] = []
	var frame_timestamps: Array[float] = []
	var frame_count := 1 if _still_only else CAPTURE_FRAMES
	var still_frame := 0 if _still_only else STILL_FRAME
	# Match the usual still's warm-up without collecting the animation.
	if _still_only:
		for _frame in range(STILL_FRAME):
			await get_tree().process_frame
	var started := Time.get_ticks_usec()
	for frame in range(frame_count):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		frame_timestamps.append(float(Time.get_ticks_usec() - started) / 1_000_000.0)
		captured_images.append(get_viewport().get_texture().get_image())
	var elapsed := float(Time.get_ticks_usec() - started) / 1_000_000.0
	var sampled_span := frame_timestamps[-1] - frame_timestamps[0]
	var actual_sample_fps := float(frame_count - 1) / maxf(sampled_span, 0.000001)
	# All raw Images and timestamps are acquired before PNG encoding. At this
	# resolution the 72-frame collection occupies about 486 MiB of raw pixels.
	var export_started := Time.get_ticks_usec()
	if not _still_only:
		for frame in range(captured_images.size()):
			_save_image(captured_images[frame], absolute_out.path_join("frames/modifier_%03d.png" % frame))
	_save_image(captured_images[still_frame], absolute_out.path_join("elite-modifier-preview.png"))
	var export_elapsed := float(Time.get_ticks_usec() - export_started) / 1_000_000.0
	captured_images.clear()
	var save_writes := SaveManager.debug_save_writes - _save_writes_before
	if save_writes != 0:
		_failures += 1
		push_error("EliteModifierPreview: unexpected save writes to isolated fixture directory")
	var examples: Array[Dictionary] = []
	for index in range(_actors.size()):
		var actor := _actors[index]
		var mark := actor.get("_elite_mark") as Node2D
		examples.append({
			"name": _cards[index]["name"],
			"spec": _cards[index]["spec"],
			"modifier_ids": actor.elite_modifier_ids(),
			"dominant_palette": _cards[index]["palette"],
			"position": [actor.position.x, actor.position.y],
			"scale": [actor.scale.x, actor.scale.y],
			"last_drawn_bits": int(mark.get("last_drawn_bits")) if is_instance_valid(mark) else 0,
		})
	var report := {
		"scene": "res://tools/dev/EliteModifierPreview.tscn",
		"resolution": [SCREEN_SIZE.x, SCREEN_SIZE.y],
		"frames": frame_count,
		"still_only": _still_only,
		"preview_scale": _preview_scale,
		"target_capture_fps": CAPTURE_FPS,
		"target_frame_interval_seconds": 1.0 / CAPTURE_FPS,
		"capture_elapsed_seconds": elapsed,
		"actual_sample_span_seconds": sampled_span,
		"actual_sample_fps": actual_sample_fps,
		"frame_timestamps_seconds": frame_timestamps,
		"png_export_elapsed_seconds": export_elapsed,
		"still_frame": still_frame,
		"still_timestamp_seconds": frame_timestamps[still_frame],
		"actors": _actors.size(),
		"registered_actors": _renderer.registered_actor_count(),
		"visible_instances": _renderer.visible_count(),
		"batch_count": _renderer.batch_count(),
		"save_writes": save_writes,
		"failures": _failures,
		"comparison": "Actual promoted EnemyActors with production modifier art and palette shader, drawn by EnemyProxyRenderer at production z=10.",
		"examples": examples,
	}
	var report_file := FileAccess.open(absolute_out.path_join("capture-info.json"), FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t") + "\n")
	else:
		_failures += 1
		push_error("EliteModifierPreview cannot write capture-info.json")
	print("EliteModifierPreview -> ", absolute_out, " | ", frame_count, " frames | scale=", _preview_scale, " | target=", CAPTURE_FPS, " fps | actual=", actual_sample_fps, " fps | PNG export=", export_elapsed, "s | save writes=", save_writes, " | failures=", _failures)


func _shutdown(exit_code: int) -> void:
	if _exiting:
		return
	_exiting = true
	# Stop publication before freeing actors; their real registry entries and
	# modifier marks then release through their ordinary exit-tree paths.
	_built = false
	set_process(false)
	for actor in _actors:
		actor.queue_free()
	_actors.clear()
	await get_tree().process_frame
	SaveManager.current_save = null
	get_tree().quit(exit_code)


func _panel(rect: Rect2, tint: Color, highlight: bool) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.z_index = -100
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192019") if highlight else Color("151d18")
	style.border_color = tint.darkened(0.58) if highlight else Color("394337")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)


func _rect(rect: Rect2, color: Color, layer: int) -> void:
	var fill := ColorRect.new()
	fill.position = rect.position
	fill.size = rect.size
	fill.color = color
	fill.z_index = layer
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)


func _label(rect: Rect2, text: String, font_size: int, color: Color, font: Font = BODY_FONT, centered: bool = false, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.z_index = 50
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _save_image(pixels: Image, path: String) -> void:
	var error := pixels.save_png(path)
	if error != OK:
		_failures += 1
		push_error("EliteModifierPreview cannot save " + path + ": " + error_string(error))
