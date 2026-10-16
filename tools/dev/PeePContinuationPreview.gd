extends Node
## Reproducible render fixture: all pending facts come from the real backend,
## in a new SaveData and unique throwaway save directory. No profile is loaded.
const SCREEN := preload("res://ui/screens/PeePContinuation.tscn")
const OUTPUT := "res://docs/art/reference/2026-10-16-peep-continuation/"
var _failures := 0

func _enter_tree() -> void:
	# The root window stays offscreen; only SubViewport pixels are captured.
	get_window().mode = Window.MODE_WINDOWED
	get_window().position = Vector2i(-10000, -10000)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)

func _ready() -> void:
	call_deferred(&"_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("PeeP preview requires a real rendering driver")
		get_tree().quit(1)
		return
	SaveManager.current_save = null
	SaveManager.save_dir = "user://peep_preview_%d/" % Time.get_ticks_usec()
	Global.debug_disable_autosave = true
	SaveManager.current_save = SaveData.new()
	Global.apply_save(SaveManager.current_save)
	Global.start_new_attempt()
	Global.mortal_name = "Mara"
	Global.attempt_segment = 7
	Global.set_followers(0)
	Global.begin_peep_continuation()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _capture(Vector2i(1280, 720), "normal-1280x720", false)
	await _capture(Vector2i(640, 480), "small-640x480", false)
	await _capture(Vector2i(960, 540), "reduced-960x540", true)
	SaveManager.current_save = null
	print("PeePContinuationPreview: captures complete; only isolated save fixtures used")
	get_tree().quit(1 if _failures > 0 else 0)

func _capture(dimensions: Vector2i, stem: String, reduced: bool) -> void:
	SettingsManager.set_value(&"accessibility", &"reduced_motion", reduced, false)
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var screen := SCREEN.instantiate() as Control
	viewport.add_child(screen)
	for i in range(5):
		await get_tree().process_frame
	var scroll := screen.find_child("Scroll", true, false) as ScrollContainer
	await RenderingServer.frame_post_draw
	_save(viewport, stem + ".png")
	if scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save(viewport, stem + "-actions.png")
		var quit := screen.find_child("Quit", true, false) as Button
		if quit.get_global_rect().end.y > dimensions.y:
			_failures += 1
			push_error("PeeP preview: small-window quit action clipped after scrolling")
	viewport.queue_free()
	await get_tree().process_frame

func _save(viewport: SubViewport, filename: String) -> void:
	var result := viewport.get_texture().get_image().save_png(OUTPUT + filename)
	if result != OK:
		_failures += 1
		push_error("PeeP preview capture failed: " + error_string(result))
	else:
		print("PeeP preview: ", OUTPUT + filename)
