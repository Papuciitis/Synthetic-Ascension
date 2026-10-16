extends Node2D
## Isolated, rendered comparison of the real EnemyActor / batched renderer.
## <godot> --path . res://tools/dev/EliteSheenPreview.tscn -- --out=C:/absolute/dir
## Default (or --capture): one still and 60 ordered PNG frames, then exit.
## --interactive: keep this preview open; Escape exits. No game scene is started.

const ENEMY_SCENE := preload("res://core/actors/enemy/enemy.tscn")
const RENDERER_SCRIPT := preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")
const WORLD_SCRIPT := preload("res://core/systems/enemy_world/EnemyWorld.gd")
const TITLE_FONT := preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
const BODY_FONT := preload("res://assets/fonts/eb_garamond/EBGaramond-Variable.ttf")
const SCREEN_SIZE := Vector2i(1280, 960)
const CAPTURE_FRAMES := 60
const CAPTURE_FPS := 24
const STILL_FRAME := 24
const GOLD := Color("d6bf86")
const IVORY := Color("eee5cf")
const MUTED := Color("9da89b")
const SPECS: Array[String] = ["Grunt", "Spitter", "Brute"]

class PreviewProxyRoot:
	extends Node2D
	var renderer: Node = null

var _out := "user://dev_previews/elite_sheen"
var _interactive := false
var _renderer: EnemyProxyRenderer = null
var _actors: Array[EnemyActor] = []
var _dummy_player: Node2D = null
var _failures := 0
var _built := false
var _save_writes_before := 0


func _enter_tree() -> void:
	# These are runtime-only flags. No profile is loaded, and this fixture
	# never writes a profile or settings file.
	Global.debug_disable_autosave = true
	Global.debug_enemy_visual_batching = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/elite_sheen_preview_%d/" % Time.get_ticks_usec()
	_save_writes_before = SaveManager.debug_save_writes
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--interactive":
			_interactive = true
	if not _interactive:
		get_window().position = Vector2i(-10000, -10000)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)


func _ready() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("EliteSheenPreview needs a rendering driver; headless cannot capture pixels.")
		get_tree().quit(1)
		return
	_prepare_runtime()
	_build_layout()
	_build_renderer()
	_build_comparison()
	_build_modifier_examples()
	_built = true
	for _frame in range(8):
		await get_tree().process_frame
	if _renderer.registered_actor_count() != _actors.size():
		_failures += 1
		push_error("EliteSheenPreview: an actor did not register with the real renderer")
	if _interactive:
		print("EliteSheenPreview: interactive preview; Escape closes it. Save writes: ", SaveManager.debug_save_writes - _save_writes_before)
		return
	var absolute_out := ProjectSettings.globalize_path(_out)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_out.path_join("frames"))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("EliteSheenPreview cannot create output: " + error_string(directory_error))
		get_tree().quit(1)
		return
	var started := Time.get_ticks_usec()
	var captured_images: Array[Image] = []
	var frame_timestamps: Array[float] = []
	for frame in range(CAPTURE_FRAMES):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		frame_timestamps.append(float(Time.get_ticks_usec() - started) / 1_000_000.0)
		captured_images.append(get_viewport().get_texture().get_image())
	var elapsed := float(Time.get_ticks_usec() - started) / 1_000_000.0
	var sampled_span := frame_timestamps[-1] - frame_timestamps[0]
	var actual_sample_fps := float(CAPTURE_FRAMES - 1) / maxf(sampled_span, 0.000001)
	# PNG encoding is deliberately outside the timed sampling interval. The
	# raw Images cost about 282 MiB for this 60-frame, 1280x960 fixture.
	var export_started := Time.get_ticks_usec()
	for frame in range(captured_images.size()):
		_save_image(captured_images[frame], absolute_out.path_join("frames/elite_%03d.png" % frame))
	_save_image(captured_images[STILL_FRAME], absolute_out.path_join("elite-sheen-preview.png"))
	var export_elapsed := float(Time.get_ticks_usec() - export_started) / 1_000_000.0
	captured_images.clear()
	var save_writes := SaveManager.debug_save_writes - _save_writes_before
	if save_writes != 0:
		_failures += 1
		push_error("EliteSheenPreview: unexpected save writes to isolated fixture directory")
	var report := {
		"scene": "res://tools/dev/EliteSheenPreview.tscn",
		"resolution": [SCREEN_SIZE.x, SCREEN_SIZE.y],
		"frames": CAPTURE_FRAMES,
		"target_capture_fps": CAPTURE_FPS,
		"target_frame_interval_seconds": 1.0 / CAPTURE_FPS,
		"capture_elapsed_seconds": elapsed,
		"actual_sample_span_seconds": sampled_span,
		"actual_sample_fps": actual_sample_fps,
		"frame_timestamps_seconds": frame_timestamps,
		"png_export_elapsed_seconds": export_elapsed,
		"still_frame": STILL_FRAME,
		"still_timestamp_seconds": frame_timestamps[STILL_FRAME],
		"actors": _actors.size(),
		"registered_actors": _renderer.registered_actor_count(),
		"visible_instances": _renderer.visible_count(),
		"batch_count": _renderer.batch_count(),
		"save_writes": save_writes,
		"failures": _failures,
		"comparison": "Actual EnemyActor sprites in EnemyProxyRenderer: ordinary, former elite_tint on non-elite actor, real apply_elite_modifiers promotion.",
	}
	var report_file := FileAccess.open(absolute_out.path_join("capture-info.json"), FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t") + "\n")
	else:
		_failures += 1
		push_error("EliteSheenPreview cannot write capture-info.json")
	print("EliteSheenPreview -> ", absolute_out, " | ", CAPTURE_FRAMES, " frames | target=", CAPTURE_FPS, " fps | actual=", actual_sample_fps, " fps | sampled span=", sampled_span, "s | PNG export=", export_elapsed, "s | failures=", _failures)
	# Actors release their real registry entries and modifier marks normally.
	_built = false
	set_process(false)
	for actor in _actors:
		actor.queue_free()
	_actors.clear()
	await get_tree().process_frame
	SaveManager.current_save = null
	get_tree().quit(0 if _failures == 0 else 1)


func _prepare_runtime() -> void:
	# Deferred _run happens after every autoload's _ready. SettingsManager
	# cannot accept values earlier: its loaded schema does not exist yet.
	# The saved accessibility preference remains intact on disk.
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	for singleton: String in ["EnemySimulationScheduler", "EnemyIndex", "ThreatDirector", "EnemyWorld", "EnemyCombat", "EnemyStatus", "ProjectileManager", "HitFeel"]:
		var service := get_node_or_null("/root/" + singleton)
		if service != null:
			service.set_process(false)
			service.set_physics_process(false)
	# Retain the actual promotion path while hiding its teaching callouts.
	BattleText.visible = false
	get_window().title = "Synthetic Ascension — Elite Surface Preview"
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
	if _interactive and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()


func _build_renderer() -> void:
	var world := WORLD_SCRIPT.new() as EnemyWorldService
	world.name = "PreviewEnemyWorld"
	add_child(world)
	var proxy_root := PreviewProxyRoot.new()
	proxy_root.name = "PreviewProxyRoot"
	# Match EnemyProxyRoot's production canvas depth so the comparison also
	# exposes modifier marks that accidentally sit behind batched bodies.
	proxy_root.z_index = 10
	proxy_root.add_to_group(&"enemy_proxy_root")
	_renderer = RENDERER_SCRIPT.new() as EnemyProxyRenderer
	_renderer.setup(world)
	proxy_root.renderer = _renderer
	proxy_root.add_child(_renderer)
	add_child(proxy_root)
	_dummy_player = Node2D.new()
	_dummy_player.name = "PreviewPlayerAnchor"
	_dummy_player.position = Vector2(640, 500)
	_dummy_player.add_to_group(&"player")
	add_child(_dummy_player)


func _build_layout() -> void:
	_rect(Rect2(Vector2.ZERO, Vector2(SCREEN_SIZE)), Color("0e1311"), -1000)
	_rect(Rect2(0, 0, 1280, 110), Color("131913"), -999)
	_label(Rect2(40, 23, 1150, 40), "ELITE SURFACE PREVIEW", 29, GOLD, TITLE_FONT)
	_label(Rect2(40, 66, 1190, 30), "Real enemy art and rendering  ·  Native scale + 2× detail  ·  Live diagonal glint", 20, MUTED)
	_rect(Rect2(40, 109, 1200, 1), Color("6f6140"), -90)
	var headings: Array[String] = ["ORDINARY", "FORMER ELITE", "NEW ELITE"]
	var subheadings: Array[String] = ["Original colors", "Flat gold tint", "Gold / ivory edge + glint"]
	for column in range(3):
		var x := 164.0 + column * 354.0
		_label(Rect2(x, 121, 342, 27), headings[column], 18, GOLD if column == 2 else IVORY, TITLE_FONT, true)
		_label(Rect2(x, 148, 342, 24), subheadings[column], 18, MUTED, BODY_FONT, true)
	for row in range(3):
		var y := 176.0 + row * 146.0
		_label(Rect2(40, y + 44, 120, 28), SPECS[row].to_upper(), 17, IVORY, TITLE_FONT)
		_label(Rect2(40, y + 74, 120, 24), "Painted art" if row == 2 else "Animated sheet", 16, MUTED)
		for column in range(3):
			var x := 164.0 + column * 354.0
			_panel(Rect2(x, y, 342, 138), column == 2)
			_label(Rect2(x + 30, y + 110, 100, 23), "Native", 16, MUTED, BODY_FONT, true)
			_label(Rect2(x + 301, y + 110, 35, 23), "2×", 16, MUTED, BODY_FONT, true)
	_label(Rect2(40, 633, 1200, 31), "MODIFIER TELLS", 21, GOLD, TITLE_FONT)
	_label(Rect2(40, 665, 1200, 25), "The same elite surface with the real modifier marks  ·  1.8× detail", 19, MUTED)
	var modifier_titles: Array[String] = ["ARMOURED + FAST", "VAMPIRIC", "SPLITTING"]
	var modifier_captions: Array[String] = ["Brute · plates + movement streak", "Spitter · blood pulse", "Brute · seam across the body"]
	for column in range(3):
		var x := 40.0 + column * 404.0
		_panel(Rect2(x, 704, 392, 192), false)
		_label(Rect2(x + 10, 714, 372, 26), modifier_titles[column], 18, IVORY, TITLE_FONT, true)
		_label(Rect2(x + 10, 863, 372, 25), modifier_captions[column], 18, MUTED, BODY_FONT, true)
	_rect(Rect2(40, 918, 1200, 1), Color("454735"), -90)
	_label(Rect2(40, 926, 1200, 26), "Inside the silhouette: warm gold / ivory highlights.  Modifier shapes keep their own colors.", 19, MUTED)


func _build_comparison() -> void:
	for row in range(SPECS.size()):
		for column in range(3):
			var x := 164.0 + column * 354.0
			var y := 176.0 + row * 146.0 + 69.0
			_spawn_actor(SPECS[row], Vector2(x + 80, y), 1.0, column)
			_spawn_actor(SPECS[row], Vector2(x + 229, y), 2.0, column)


func _build_modifier_examples() -> void:
	_spawn_actor("Brute", Vector2(236, 802), 1.8, 2, [EliteModifiers.ARMOURED, EliteModifiers.FAST], Vector2(170, 0))
	_spawn_actor("Spitter", Vector2(640, 802), 1.8, 2, [EliteModifiers.VAMPIRIC])
	_spawn_actor("Brute", Vector2(1044, 802), 1.8, 2, [EliteModifiers.SPLITTING])


func _spawn_actor(spec_name: String, at: Vector2, preview_scale: float, appearance: int, modifiers: Array[StringName] = [], display_velocity: Vector2 = Vector2.ZERO) -> void:
	var actor := ENEMY_SCENE.instantiate() as EnemyActor
	actor.spec = load("res://core/actors/enemy/EnemySpec_%s.tres" % spec_name) as EnemySpec
	actor.name = "%s_%s_%s" % [spec_name, appearance, _actors.size()]
	actor.position = at
	actor.scale = Vector2.ONE * preview_scale
	# The real setup and visuals still run, while AI and collisions remain
	# frozen. Child marks continue to process and the renderer publishes them.
	actor.set_physics_process(false)
	actor.collision_layer = 0
	actor.collision_mask = 0
	add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.player = _dummy_player
	actor.velocity = display_velocity
	var hitbox := actor.get_node("Hitbox") as Area2D
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	var sprite := actor.get_node("Sprite2D") as Sprite2D
	if actor.animator != null:
		# Same animation frame for all three appearances of each role.
		actor.animator.set("_phase_ms", 0)
	if appearance == 1:
		# Deliberately a non-elite actor: this reproduces the former gold
		# multiply without accidentally activating the new elite material.
		sprite.modulate = actor.spec.elite_tint
	elif appearance == 2:
		actor.apply_elite_modifiers(modifiers)
	# Elite promotion chooses the full simulation tier and can re-enable
	# physics. Freeze only after all real spawn / promotion setup is finished.
	actor.set_physics_process(false)
	actor.set_process(false)
	if sprite.visible:
		_failures += 1
		push_error("EliteSheenPreview actor bypassed batched rendering: " + actor.name)
	_actors.append(actor)


func _panel(rect: Rect2, highlight: bool) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.z_index = -100
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a2118") if highlight else Color("161e19")
	style.border_color = Color("8b7748") if highlight else Color("394337")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)


func _rect(rect: Rect2, color: Color, layer: int) -> void:
	var fill := ColorRect.new()
	fill.position = rect.position
	fill.size = rect.size
	fill.color = color
	fill.z_index = layer
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)


func _label(rect: Rect2, text: String, font_size: int, color: Color, font: Font = BODY_FONT, centered: bool = false) -> void:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.z_index = 50
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _save_image(pixels: Image, path: String) -> void:
	var error := pixels.save_png(path)
	if error != OK:
		_failures += 1
		push_error("EliteSheenPreview cannot save " + path + ": " + error_string(error))
