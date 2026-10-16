extends Node
## Captures the real optional papers panel with isolated state and no saves.
## Parent owns launching this fixture under the shared engine test slot.

const SCREEN := preload("res://ui/screens/CityLorePapers.gd")
const OUTPUT := "res://docs/art/reference/2026-10-16-city-lore/"
var _failures := 0


func _enter_tree() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().position = Vector2i(-10000, -10000)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("City lore preview requires a real rendering driver")
		get_tree().quit(1)
		return
	SaveManager.current_save = null
	SaveManager.save_dir = "user://city_lore_preview_%d/" % Time.get_ticks_usec()
	Global.debug_disable_autosave = true
	Global.meta_pending_peep.clear()
	Global.start_new_attempt()
	Global.grimoire_entries.clear()
	Global.library_read_entries.clear()
	StoryDirector.load_state({"v": 1, "best": 10, "flags": ["area:1"]})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var writes_before := SaveManager.debug_save_writes
	await _capture(Vector2i(1280, 720), "full-1280x720", false)
	await _capture(Vector2i(640, 480), "small-640x480", false)
	await _capture(Vector2i(640, 480), "reduced-640x480", true)
	if SaveManager.debug_save_writes != writes_before:
		_failures += 1
		push_error("City lore preview unexpectedly wrote a profile")
	print("CityLorePapersPreview: %d failures; isolated fixture, zero profile writes" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _capture(dimensions: Vector2i, stem: String, reduced: bool) -> void:
	Global.grimoire_entries.clear()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", reduced, false)
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var screen: CanvasLayer = SCREEN.new()
	viewport.add_child(screen)
	await _frames(5)
	await _save(viewport, stem + "-list")
	var scroll := screen.get("_scroll") as ScrollContainer
	if scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _frames(3)
		await _save(viewport, stem + "-list-end")
	screen.call("inspect_document", "city_blank_destination")
	await _frames(4)
	await _save(viewport, stem + "-excerpt")
	_check_bounds(screen.get("_panel") as Control, dimensions, stem + " panel")
	_check_bounds(screen.get("_keep_button") as Control, dimensions, stem + " Keep a copy")
	_check_bounds(screen.get("_leave_button") as Control, dimensions, stem + " Leave")
	screen.call("keep_copy")
	await _frames(3)
	await _save(viewport, stem + "-copied")
	screen.call("_close")
	viewport.queue_free()
	await _frames(2)


func _check_bounds(control: Control, dimensions: Vector2i, context: String) -> void:
	var rect := control.get_global_rect()
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > dimensions.x + 0.5 or rect.end.y > dimensions.y + 0.5 or rect.size.y < 1:
		_failures += 1
		push_error("City lore preview clips " + context)


func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame


func _save(viewport: SubViewport, stem: String) -> void:
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png(OUTPUT + stem + ".png")
	if result != OK:
		_failures += 1
		push_error("City lore preview capture failed: " + error_string(result))
	else:
		print("City lore preview: " + OUTPUT + stem + ".png")
