extends Node
## Actual Development UI, real profile rules, isolated slot directory.
## <godot> --path . res://tools/dev/CityDevelopmentPreview.tscn -- --out=C:/absolute/output
## --interactive keeps the normal preview open. Default captures and exits.
const MENU_SCENE := preload("res://ui/screens/MainMenu.tscn")
const MISSILE := &"augment_magic_missile"
const TESLA := &"augment_tesla_aura"
var _out := "user://dev_previews/city_development"
var _interactive := false
var _failures := 0
var _captures: Array[Dictionary] = []
var _menu: Control
var _screen: Node
var _profile_directory := ""

func _enter_tree() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	_profile_directory = "user://tests/city_development_preview_%d/" % Time.get_ticks_usec()
	SaveManager.save_dir = _profile_directory
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

func _frames(count: int = 4) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CityDevelopmentPreview requires actual rendering for its PNG captures.")
		get_tree().quit(1)
		return
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	var absolute_out := ProjectSettings.globalize_path(_out)
	var error := DirAccess.make_dir_recursive_absolute(absolute_out)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("CityDevelopmentPreview: cannot create output: " + error_string(error))
		get_tree().quit(1)
		return
	if not Global.has_method("get_city_development_options"):
		push_error("CityDevelopmentPreview: the development catalogue is unavailable.")
		get_tree().quit(1)
		return
	_fixture()
	_set_window(Vector2i(1280, 720), 1.0)
	_menu = MENU_SCENE.instantiate() as Control
	add_child(_menu)
	await _frames(20)
	# Let the production menu's own introduction finish before recording it.
	await get_tree().create_timer(1.2).timeout
	await _capture("main-menu-1280x720.png", absolute_out)
	_set_window(Vector2i(640, 480), 1.5)
	await _frames(8)
	await _capture("main-menu-window640x480-content640x360-ui150-keep.png", absolute_out)
	_set_window(Vector2i(1280, 720), 1.0)
	await _frames(8)
	var entry := _menu.find_child("Development", true, false) as Button
	if entry == null:
		push_error("CityDevelopmentPreview: the real MainMenu Development entry is missing.")
		get_tree().quit(1)
		return
	entry.pressed.emit()
	await _frames(8)
	_screen = _menu.find_child("CityDevelopmentScreen", true, false)
	if _screen == null:
		push_error("CityDevelopmentPreview: Development did not open.")
		get_tree().quit(1)
		return
	await _capture("development-1280x720.png", absolute_out)
	await _capture_option("augment", "development-1280x720-training.png", absolute_out)
	await _capture_bottom("development-1280x720-options.png", absolute_out)
	if _interactive:
		var scroll := _screen.find_child("DevelopmentScroll", true, false) as ScrollContainer
		scroll.scroll_vertical = 0
		print("CityDevelopmentPreview interactive; isolated profile: ", ProjectSettings.globalize_path(_profile_directory))
		return
	_set_window(Vector2i(960, 540), 1.5)
	await _frames(8)
	var small_scroll := _screen.find_child("DevelopmentScroll", true, false) as ScrollContainer
	small_scroll.scroll_vertical = 0
	await _frames()
	await _capture("development-960x540-ui150.png", absolute_out)
	await _capture_option("augment", "development-960x540-ui150-training.png", absolute_out)
	await _capture_bottom("development-960x540-ui150-options.png", absolute_out)
	_set_window(Vector2i(640, 480), 1.5)
	await _frames(8)
	small_scroll.scroll_vertical = 0
	await _frames()
	await _capture("development-window640x480-content640x360-ui150-keep.png", absolute_out)
	await _capture_bottom("development-window640x480-content640x360-ui150-keep-options.png", absolute_out)
	_set_window(Vector2i(640, 480), 1.5, Window.CONTENT_SCALE_ASPECT_EXPAND)
	await _frames(8)
	small_scroll.scroll_vertical = 0
	await _frames()
	await _capture("development-window640x480-content640x480-ui150-expand.png", absolute_out)
	await _capture_bottom("development-window640x480-content640x480-ui150-expand-options.png", absolute_out)
	Global.save_current_profile()
	var report := {
		"scene": "res://tools/dev/CityDevelopmentPreview.tscn",
		"profile_directory": ProjectSettings.globalize_path(_profile_directory),
		"profile_isolated": SaveManager.save_dir == _profile_directory,
		"summary": Global.call("get_city_development_summary"),
		"active_snapshot": Global.get("attempt_city_development"),
		"captures": _captures,
		"failures": _failures,
	}
	var report_file := FileAccess.open(absolute_out.path_join("capture-info.json"), FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t") + "\n")
	else:
		_failures += 1
		push_error("CityDevelopmentPreview: cannot write capture-info.json")
	print("CityDevelopmentPreview: ", _captures.size(), " actual UI captures; failures=", _failures, " -> ", absolute_out)
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	get_tree().quit(1 if _failures > 0 else 0)

func _fixture() -> void:
	var profile := SaveData.new()
	profile.slot_index = 1
	profile.profile_name = "Development Preview"
	SaveManager.current_save = profile
	SaveManager.current_slot = 1
	Global.apply_save(profile)
	Global.owned_augment_ids = [TESLA, MISSILE]
	Global.permanent_augment_ids = [MISSILE, TESLA, StringName()]
	Global.start_new_attempt()
	for segment in range(1, 9):
		Global.attempt_segment = segment
		Global.begin_segment_completion(segment)
		Global.finish_segment_completion(segment)
	Global.pending_big_choice = false
	Global.pending_augment_pick = false
	for id: StringName in [&"health", &"health", &"armor", &"bag", &"haste", &"power", &"augment"]:
		if not bool(Global.call("purchase_city_development", id, MISSILE if id == &"augment" else StringName())):
			_failures += 1
			push_error("CityDevelopmentPreview: fixture purchase failed: " + String(id))
	Global.call("select_trained_augment", TESLA)

func _set_window(dimensions: Vector2i, scale_factor: float, aspect: int = Window.CONTENT_SCALE_ASPECT_KEEP) -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = dimensions
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = aspect
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().content_scale_factor = scale_factor

func _capture_option(id: String, filename: String, directory: String) -> void:
	var scroll := _screen.find_child("DevelopmentScroll", true, false) as ScrollContainer
	var option := _screen.find_child("Option_" + id, true, false) as Control
	if option != null and scroll.is_ancestor_of(option):
		scroll.ensure_control_visible(option)
	await _frames(6)
	await _capture(filename, directory)

func _capture_bottom(filename: String, directory: String) -> void:
	var scroll := _screen.find_child("DevelopmentScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _frames(6)
	await _capture(filename, directory)

func _capture(filename: String, directory: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(directory.path_join(filename))
	if error != OK:
		_failures += 1
		push_error("CityDevelopmentPreview: " + error_string(error) + " saving " + filename)
	var entry: Dictionary = {
		"file": filename,
		"pixels": [image.get_width(), image.get_height()],
		"window_size": [get_window().size.x, get_window().size.y],
		"content_aspect": "KEEP" if get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP else "EXPAND",
		"logical_viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"ui_scale": get_window().content_scale_factor,
	}
	if _screen == null:
		var development := _menu.find_child("Development", true, false) as Control
		entry["development_entry_within_viewport"] = development != null and get_viewport().get_visible_rect().encloses(development.get_global_rect())
		if not bool(entry["development_entry_within_viewport"]):
			_failures += 1
			push_error("CityDevelopmentPreview: main-menu Development entry exceeds the logical viewport")
	if _screen != null:
		var panel := _screen.find_child("DevelopmentPanel", true, false) as Control
		entry["panel_rect"] = {"x": panel.position.x, "y": panel.position.y, "width": panel.size.x, "height": panel.size.y} if panel != null else {}
		entry["panel_minimum"] = [panel.get_combined_minimum_size().x, panel.get_combined_minimum_size().y] if panel != null else []
		entry["panel_within_viewport"] = panel != null and get_viewport().get_visible_rect().encloses(panel.get_global_rect())
		if not bool(entry["panel_within_viewport"]):
			_failures += 1
			push_error("CityDevelopmentPreview: panel exceeds the logical viewport")
	_captures.append(entry)
