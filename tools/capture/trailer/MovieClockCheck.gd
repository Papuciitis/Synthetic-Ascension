extends Node2D
## Checks the movieclock.so shim under Movie Maker: per-frame clock steps of
## 1/fps, and the stand-in pointer reaching Viewport.get_mouse_position().

var _ticks: Array[int] = []
var _real: Array[float] = []
var _pointer_seen := Vector2.INF
var _box := ColorRect.new()


func _ready() -> void:
	process_priority = -1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("MOVIE_CLOCK_READY")
	get_window().position = Vector2i(-10000, -10000)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	if OS.get_cmdline_user_args().has("--force-fullscreen"):
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if OS.get_cmdline_user_args().has("--exclusive") else Window.MODE_FULLSCREEN
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([Vector2(-4, -4), Vector2(-3, -4), Vector2(-3, -3)]))
	_box.size = Vector2(64, 64)
	_box.color = Color(0.9, 0.5, 0.2)
	add_child(_box)


func _process(_delta: float) -> void:
	OS.get_environment("SA_MOVIE_CLOCK_TICK")
	_ticks.append(Time.get_ticks_usec())
	_real.append(Time.get_unix_time_from_system())
	var frame := _ticks.size()
	# Wall-clock driven motion: smooth only if the clock follows the frames.
	_box.position = Vector2(fmod(Time.get_ticks_msec() * 0.4, 1800.0), 500)
	if frame == 30:
		OS.get_environment("SA_MOVIE_POINTER:%d,%d" % [get_window().position.x + 123, get_window().position.y + 456])
	if frame == 40:
		_pointer_seen = get_viewport().get_mouse_position()
	if frame % 30 == 0:
		print("MovieClockCheck frame %d window=%s mode=%d pos=%s screen=%s" % [frame, str(get_window().size), get_window().mode, str(get_window().position), str(DisplayServer.screen_get_size())])
	if frame == 120:
		var steps: Array[int] = []
		for i in range(2, _ticks.size()):
			steps.append(_ticks[i] - _ticks[i - 1])
		steps.sort()
		var real_ms: Array[int] = []
		for i in range(2, _real.size()):
			real_ms.append(int((_real[i] - _real[i - 1]) * 1000.0))
		real_ms.sort()
		print("MovieClockCheck real frame ms: min=%d median=%d p90=%d max=%d" % [real_ms[0], real_ms[real_ms.size() / 2], real_ms[int(real_ms.size() * 0.9)], real_ms[-1]])
		print("MovieClockCheck: window=%s steps_min=%d steps_median=%d steps_max=%d pointer=%s state=%s movie=%s" % [
			str(get_window().size), steps[0], steps[steps.size() / 2], steps[-1], str(_pointer_seen),
			OS.get_environment("SA_MOVIE_STATE"), Engine.get_write_movie_path()])
		get_tree().quit()
