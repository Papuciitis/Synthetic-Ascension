extends Node
## Real UI pixels of the opening stills' painted transitions, frozen at set
## points: a still painting in over the world, one painting over another, and
## a still washing out. Isolated state, offscreen window, no gameplay launch.
## <godot> --path . res://tools/dev/OpeningTransitionPreview.tscn [-- --out=/folder]
const SCREEN := preload("res://ui/screens/opening/OpeningPresentation.tscn")
var _out := "res://docs/art/reference/2026-10-17-opening-transitions/"
var _failures := 0
var _saved: Array[String] = []


func _enter_tree() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().position = Vector2i(-10000, -10000)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")


func _ready() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Opening transition preview requires a rendering driver")
		get_tree().quit(1)
		return
	SaveManager.current_save = null
	Global.debug_disable_autosave = true
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	# A stand-in for the world behind the stills: the game's dark ground tone.
	var world := ColorRect.new()
	world.color = Color(0.11, 0.12, 0.10)
	world.size = Vector2(1280, 720)
	view.add_child(world)
	var screen := SCREEN.instantiate()
	view.add_child(screen)
	await _frames(3)
	screen.call("show_illustration", &"city")
	for point in [0.3, 0.6]:
		await _hold(screen, view, point, "city-paint-in-%02d" % int(point * 100))
	await _hold(screen, view, 1.0, "city-painted")
	screen.call("show_illustration", &"admission")
	for point in [0.25, 0.5, 0.75]:
		await _hold(screen, view, point, "city-to-admission-%02d" % int(point * 100))
	await _hold(screen, view, 1.0, "admission-painted")
	screen.call("show_illustration", &"synthesis")
	await _hold(screen, view, 1.0, "synthesis-painted")
	screen.call("show_illustration", &"records")
	await _hold(screen, view, 0.5, "synthesis-to-records-50")
	await _hold(screen, view, 1.0, "records-painted")
	# The wash-out runs the paint-in backwards. Freezing a running clear would
	# race its release timer (a capture blocks the frame), so the same state
	# is shown on a still that is not being cleared.
	screen.call("_drop_back_layer")
	await _hold(screen, view, 0.5, "records-washing-out-50")
	await screen.call("clear_illustration", 0.0)
	view.queue_free()
	print("OpeningTransitionPreview: %d frames, %d failures" % [_saved.size(), _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## Freezes the current transition at `point` (the front still's reveal) and
## saves the frame. The drift is held too, so frames compare like for like.
func _hold(screen: Node, view: SubViewport, point: float, stem: String) -> void:
	var tween := screen.get("_illustration_tween") as Tween
	if tween != null:
		tween.kill()
	var drift := screen.get("_illustration_drift") as Tween
	if drift != null:
		drift.kill()
	screen.call("_set_reveal", point)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var result := view.get_texture().get_image().save_png(ProjectSettings.globalize_path(_out).path_join(stem + ".png"))
	if result != OK:
		_failures += 1
		push_error("Opening transition capture failed: " + error_string(result))
	else:
		_saved.append(stem)
		print("Opening transition: ", stem)


func _frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame
