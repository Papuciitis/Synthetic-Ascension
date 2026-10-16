extends Node
## Real UI pixels only, isolated state, offscreen window. No gameplay launch.
const SCREEN := preload("res://ui/screens/opening/OpeningPresentation.tscn")
const OUTPUT := "res://docs/art/reference/2026-10-16-painted-opening/"
var _failures := 0

func _enter_tree() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().position = Vector2i(-10000, -10000)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)

func _ready() -> void:
	call_deferred(&"_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Opening preview requires a rendering driver")
		get_tree().quit(1)
		return
	SaveManager.current_save = null
	Global.debug_disable_autosave = true
	SettingsManager.set_value(&"accessibility", &"typewriter_speed", &"instant", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _capture(&"city", 0, "", OpeningSequenceData.HISTORICAL_PREFACE, Vector2i(1280, 720), "city")
	await _capture(&"admission", 2, OpeningSequenceData.ADMISSION_DESK_TITLE, OpeningSequenceData.admission_desk_body("Mara", "human"), Vector2i(1280, 720), "admission")
	await _capture(&"synthesis", 3, OpeningSequenceData.SYNTHESIS_TITLE, OpeningSequenceData.SYNTHESIS_BODY, Vector2i(1280, 720), "synthesis")
	await _capture(&"records", 4, OpeningSequenceData.FOLLOWER_TITLE, OpeningSequenceData.FOLLOWER_BODY, Vector2i(1280, 720), "records")
	await _capture(&"city", 0, "A PROHIBITED EXPERIMENT", OpeningSequenceData.historical_body("Mara"), Vector2i(640, 480), "small-historical")
	await _capture(&"records", 4, OpeningSequenceData.FOLLOWER_TITLE, OpeningSequenceData.FOLLOWER_BODY, Vector2i(640, 480), "small-follower")
	await _capture(&"", 1, "BREN", OpeningSequenceData.BREN_OPENING, Vector2i(640, 480), "small-choices", OpeningSequenceData.RESPONSE_CHOICES)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	await _capture(&"synthesis", 3, OpeningSequenceData.SYNTHESIS_TITLE, OpeningSequenceData.SHORT_SYNTHESIS_BODY, Vector2i(960, 540), "short-reduced", [], Rect2(0.12, 0.25, 0.76, 0.65))
	print("OpeningIllustrationPreview: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _capture(id: StringName, style: int, title: String, body: String, dimensions: Vector2i, stem: String, choices: Array = [], crop: Rect2 = Rect2()) -> void:
	var view := SubViewport.new()
	view.size = dimensions
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var screen := SCREEN.instantiate()
	view.add_child(screen)
	if not id.is_empty():
		screen.call("show_illustration", id, crop)
	match style:
		0:
			screen.call("present_historical", "Mara")
			if not title.is_empty():
				screen.call("advance")
		1:
			screen.call("present_dialogue", "BREN", OpeningSequenceData.BREN_ROLE, body, choices)
		2:
			screen.call("show_prompt", "Follow the gold trail to the laboratory")
			screen.call("present_announcement", title, body)
		3:
			screen.call("present_synthetic", title, body)
		4:
			screen.call("present_follower", body)
	await get_tree().create_timer(0.5, true, false, true).timeout
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(view, stem)
	var panel := screen.get("_panel") as Control
	if panel.get_global_rect().position.x < 0 or panel.get_global_rect().end.x > dimensions.x + 0.5 or panel.get_global_rect().end.y > dimensions.y + 0.5:
		_failures += 1
		push_error("Opening preview: card outside viewport at " + stem)
	var scroll := screen.get("_scroll") as ScrollContainer
	if scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save(view, stem + "-actions")
	await screen.call("clear_illustration", 0.0)
	view.queue_free()
	await get_tree().process_frame

func _save(view: SubViewport, stem: String) -> void:
	var result := view.get_texture().get_image().save_png(OUTPUT + stem + ".png")
	if result != OK:
		_failures += 1
		push_error("Opening capture failed: " + error_string(result))
	else:
		print("Opening preview: ", stem)
