extends Node
## Isolated rendered inspection of real bindings, covers, leaves and account flow.
const HUB_WORLD := preload("res://scenes/hub/HubWorld.tscn")
var _out := "user://hub_library_shots"
var _failures := 0
var _library: Node
var _motion := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		_motion = _motion or arg == "--motion"
	DirAccess.make_dir_recursive_absolute(_out)
	SaveManager.save_dir = "user://saves_test_library_shots/"
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.pending_big_choice = false
	Global.library_read_entries.clear()
	Global.followers = 6000
	Global.library_note("item:beka")
	Global.library_note("record:accounts")
	var recipe_seeded := false
	for entry: Dictionary in Grimoire.catalogue(Global.augment_db):
		if entry["section"] != "RECORDS" and not recipe_seeded:
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
	hub._open_library()
	await _frames(10)
	_library = hub._open_panel
	await _shot("library_shelves_1280.png")
	_check_spines()
	await _transfer_trip(false)
	await _shot("library_buildcraft_1280.png")
	_check_bounds()
	var ribbons: Array = _library.get("_ribbons")
	var marker: Button = ribbons[0]
	marker.button_down.emit()
	await get_tree().create_timer(0.12, true).timeout
	await _shot("library_ribbon_pulled.png")
	marker.button_up.emit()
	await get_tree().create_timer(0.22, true).timeout
	await _shot("library_ribbon_released.png")
	var skin: Control = _library.get("_open_book")
	_library.call("_turn_page", 1)
	await _frames(3)
	_freeze_turn()
	for phase: float in [0.0, 0.18, 0.35, 0.5, 0.65, 0.82, 0.99]:
		skin.set("turn_progress", phase)
		await _frames(3)
		await _shot("library_forward_%02d.png" % roundi(phase * 100))
	skin.set("turn_progress", 1.0)
	_library.call("_finish_turn")
	await _frames(3)
	await _shot("library_continuation_1280.png")
	_check_bounds()
	_library.call("_turn_page", -1)
	await _frames(3)
	_freeze_turn()
	skin.set("turn_progress", 0.65)
	await _frames(3)
	await _shot("library_backward_65.png")
	skin.set("turn_progress", 1.0)
	_library.call("_finish_turn")
	for phase: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		skin.set("open_progress", phase)
		await _frames(3)
		await _shot("library_cover_%02d.png" % roundi(phase * 100))
	skin.set("open_progress", 1.0)
	if _motion:
		await _motion_frames()
	await _transfer_trip(true)
	await _read("Recipes")
	await _shot("library_recipes_1280.png")
	await _read("Chronicles")
	await _shot("library_chronicles_1280.png")
	await _read("Pairs")
	_library.call("_toggle_research_target")
	await _frames(4)
	await _shot("library_research_1280.png")
	_library.call("show_shelves")
	await get_tree().create_timer(0.75, true).timeout
	await _shot("library_research_shelves_1280.png")
	window.content_scale_factor = 1.5
	await _frames(20)
	await _shot("library_shelves_scale150.png")
	_check_spines()
	for category: String in ["Buildcraft", "Pairs", "Chronicles"]:
		await _read(category)
		await _shot("library_%s_scale150.png" % category.to_lower())
		_check_bounds()
		if category == "Buildcraft":
			_library.call("_turn_page", 1)
			await get_tree().create_timer(0.65, true).timeout
			await _shot("library_continuation_scale150.png")
			_check_bounds()
	_library.call("set_filter", "Items", "beka")
	await _frames(5)
	await _shot("library_beka_scale150.png")
	_check_bounds()
	_library.call("set_filter", "Items", "nothing matches this phrase")
	await _frames(5)
	await _shot("library_empty_scale150.png")
	_check_bounds()
	window.content_scale_factor = 1.0
	window.size = Vector2i(1920, 1080)
	await _frames(20)
	_library.call("show_shelves", false)
	await _frames(5)
	await _shot("library_shelves_1920.png")
	_check_spines()
	await _read("Buildcraft")
	await _shot("library_buildcraft_1920.png")
	_check_bounds()
	_library.call("_close")
	await get_tree().create_timer(0.75, true).timeout
	await _frames(3)
	print("HubLibraryShotProbe: %d layout failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _read(category: String) -> void:
	_library.call("select_book", category)
	await get_tree().create_timer(1.6, true).timeout
	await _frames(4)

func _freeze_turn() -> void:
	var tween: Tween = _library.get("_page_tween")
	if tween != null and tween.is_valid():
		tween.kill()

func _transfer_trip(returning: bool) -> void:
	if returning:
		_library.call("show_shelves")
	else:
		_library.call("select_book", "Buildcraft")
	var ghost: TextureRect
	for frame: int in range(100):
		await get_tree().process_frame
		ghost = _library.get("_transfer") as TextureRect
		if is_instance_valid(ghost):
			break
	if not is_instance_valid(ghost):
		_failures += 1
		push_error("HubLibraryShotProbe: volume transfer never appeared")
		return
	var tween: Tween = _library.get("_transfer_tween")
	if tween != null and tween.is_valid():
		tween.kill()
	_library.set("_transfer_tween", null)
	var skin: Control = _library.get("_open_book")
	var index: int = preload("res://ui/screens/HubLibraryData.gd").CATEGORIES.find(_library.get("_active_category"))
	var books: Array = _library.get("_book_buttons")
	var shelf: Rect2 = books[index].get_global_rect()
	var open_center := skin.global_position + skin.size * Vector2(0.725, 0.5)
	var small := minf(shelf.size.x / ghost.size.x, shelf.size.y / ghost.size.y)
	for progress: float in [0.0, 0.5, 1.0]:
		var amount := 1.0 - progress if returning else progress
		ghost.position = shelf.get_center().lerp(open_center, amount) - ghost.size * 0.5
		ghost.scale = Vector2.ONE * lerpf(small, 1.0, amount)
		ghost.rotation = lerpf(-0.14, 0.0, amount)
		ghost.modulate.a = 1.0 - maxf(0.0, (progress - 0.65) / 0.35) if returning else 1.0
		await _frames(3)
		await _shot("library_%s_%02d.png" % ["return" if returning else "pickup", roundi(progress * 100)])
	ghost.queue_free()
	_library.set("_transfer", null)
	if returning:
		_library.call("_reveal_shelves")
	else:
		_library.call("_begin_cover_open")
		await get_tree().create_timer(0.65, true).timeout
	await _frames(3)

func _check_spines() -> void:
	for book: Button in _library.get("_book_buttons"):
		var layout: Dictionary = book.call("title_layout")
		var bounds: Rect2 = layout["bounds"]
		for width: float in layout["line_widths"]:
			if width > bounds.size.x + 0.1:
				_failures += 1
				push_error("HubLibraryShotProbe: binding title exceeds its lettering region")
		if layout["line_height"] * layout["lines"].size() > bounds.size.y + 0.1:
			_failures += 1
			push_error("HubLibraryShotProbe: binding title exceeds its height")

func _check_bounds() -> void:
	var visible := get_viewport().get_visible_rect()
	var book: Control = _library.get("_open_book")
	for control: Control in [_library.get("_title"), _library.get("_body"), _library.get("_plate_body"), _library.get("_continuation")]:
		if not control.is_visible_in_tree():
			continue
		if not visible.grow(1).encloses(control.get_global_rect()):
			_failures += 1
			push_error("HubLibraryShotProbe: %s exceeds the viewport" % control.name)
		var side := 1 if control == _library.get("_body") else 0
		var paper: Rect2 = book.call("paper_rect", side)
		var local_rect := Rect2(control.global_position - book.global_position, control.size)
		if not paper.grow(1).encloses(local_rect):
			_failures += 1
			push_error("HubLibraryShotProbe: %s exceeds its paper" % control.name)
		if control is RichTextLabel and control.get_content_height() > control.size.y + 2:
			_failures += 1
			push_error("HubLibraryShotProbe: %s clips its printed account (%s > %s)" % [control.name, control.get_content_height(), control.size.y])

func _motion_frames() -> void:
	var skin: Control = _library.get("_open_book")
	var frame := 0
	DirAccess.make_dir_recursive_absolute(_out.path_join("motion"))
	for index: int in range(25):
		skin.set("open_progress", float(index) / 24.0)
		await _frames(2)
		await _shot("motion/frame_%03d.png" % frame)
		frame += 1
	skin.set("open_progress", 1.0)
	for direction: int in [1, -1]:
		_library.call("_turn_page", direction)
		await _frames(3)
		_freeze_turn()
		for index: int in range(25):
			skin.set("turn_progress", float(index) / 24.0)
			await _frames(2)
			await _shot("motion/frame_%03d.png" % frame)
			frame += 1
		_library.call("_finish_turn")
	skin.set("turn_progress", 1.0)

func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))
	print("HubLibraryShotProbe -> " + file)
