extends Node
## Visual check: <godot> --path . res://tools/dev/HubLibraryShotProbe.tscn -- --out=/abs/dir

const HUB_WORLD := preload("res://scenes/hub/HubWorld.tscn")
var _out := "user://hub_library_shots"
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	SaveManager.save_dir = "user://saves_test_library_shots/"
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.pending_big_choice = false
	Global.followers = 6000
	Global.library_note("item:beka")
	var recipe_seeded := false
	for entry: Dictionary in Grimoire.catalogue(Global.augment_db):
		if entry["section"] == "RECORDS":
			Global.library_note(String(entry["key"]))
			break
		if not recipe_seeded:
			Global.library_note(String(entry["key"]))
			recipe_seeded = true
	for entry: Dictionary in preload("res://ui/screens/HubLibraryData.gd").build_entries():
		if entry["category"] == "Enemies":
			Global.library_note(String(entry["key"]))
	StoryDirector.cards_override = 0
	var window := get_tree().root
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1280, 720)
	window.content_scale_factor = 1.0
	var hub: HubWorld = HUB_WORLD.instantiate()
	hub.crowd_seed = 7
	hub.departure_scene_change_enabled = false
	add_child(hub)
	await _frames(15)
	_check_control_bounds(hub._zoom_controls)
	await _shot("hub_controls_1280.png")
	hub._toggle_beka_view()
	await _frames(15)
	_check_control_bounds(hub._zoom_controls)
	await _shot("beka_closeup_1280.png")
	hub._reset_hub_view()
	hub._open_library()
	await _frames(15)
	var library := hub._open_panel
	await _shot("library_shelves_1280.png")
	library.call("select_book", "Buildcraft")
	await _frames(45)
	await _shot("library_buildcraft_1280.png")
	_check_bounds(library)
	library.call("_turn_page", 1)
	# Freeze a real animated leaf halfway for reproducible visual inspection.
	var turn: Tween = library.get("_page_tween")
	if turn != null and turn.is_valid():
		turn.kill()
	var skin: Control = library.get("_open_book")
	skin.set("turn_progress", 0.35)
	await _frames(2)
	await _shot("library_page_turn_1280.png")
	skin.set("turn_progress", 1.0)
	await _frames(35)
	library.call("select_book", "Recipes")
	await _frames(45)
	await _shot("library_recipes_1280.png")
	library.call("select_book", "Chronicles")
	await _frames(45)
	await _shot("library_chronicles_1280.png")
	window.content_scale_factor = 1.5
	await _frames(35)
	await _shot("library_chronicles_scale150.png")
	_check_bounds(library)
	library.call("set_filter", "Pairs", "")
	await _frames(15)
	await _shot("library_sealed_scale150.png")
	_check_bounds(library)
	library.call("set_filter", "Items", "beka")
	await _frames(10)
	await _shot("library_beka_scale150.png")
	_check_bounds(library)
	library.call("set_filter", "Enemies", "wind-up")
	await _frames(10)
	await _shot("library_enemies_scale150.png")
	library.call("set_filter", "Items", "nothing matches this phrase")
	await _frames(10)
	await _shot("library_empty_scale150.png")
	_check_bounds(library)
	library.call("show_shelves")
	await _frames(35)
	await _shot("library_shelves_scale150.png")
	window.content_scale_factor = 1.0
	window.size = Vector2i(1920, 1080)
	await _frames(35)
	await _shot("library_shelves_1920.png")
	library.call("select_book", "Buildcraft")
	await _frames(45)
	await _shot("library_buildcraft_1920.png")
	_check_bounds(library)
	library.call("_close")
	await _frames(5)
	print("HubLibraryShotProbe: %d layout failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check_bounds(library: Node) -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	for control: Control in [library.get("_layout"), library.get("_list"), library.get("_title"), library.get("_body"), library.get("_search")]:
		if not control.is_visible_in_tree():
			continue
		if not viewport_rect.grow(1.0).encloses(control.get_global_rect()):
			_failures += 1
			push_error("HubLibraryShotProbe: %s exceeds %s: %s" % [control.name, viewport_rect, control.get_global_rect()])
		if control == library.get("_body") and control.size.y < 100.0:
			_failures += 1
			push_error("HubLibraryShotProbe: insufficient reading space")


func _check_control_bounds(control: Control) -> void:
	if not get_viewport().get_visible_rect().grow(1.0).encloses(control.get_global_rect()):
		_failures += 1
		push_error("HubLibraryShotProbe: courtyard controls extend outside viewport")


func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))
	print("HubLibraryShotProbe -> " + _out.path_join(file))
