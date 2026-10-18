extends Node
## Actual hub frames plus native-size samples of the hardware cursor assets.
## --out=/absolute/path [--small] [--stay] keeps a cursor test window open.

const HUB := preload("res://scenes/hub/HubWorld.tscn")
var _out := ""
var _small := false


func _ready() -> void:
	call_deferred(&"_run")


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out.path_join(name + ("-960x540.png" if _small else "-1280x720.png"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("HubCursorShotProbe: ", error, " ", path, " ", image.get_size())


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_small = OS.get_cmdline_user_args().has("--small")
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	var resolution := Vector2i(960, 540) if _small else Vector2i(1280, 720)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	DisplayServer.window_set_title("Synthetic Ascension — Hub and Cursor Readability")
	get_tree().root.content_scale_size = resolution
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	SaveManager.current_save = null
	StoryDirector.cards_override = 0
	Global.start_new_attempt()
	Global.followers = 4000
	var hub := HUB.instantiate() as HubWorld
	hub.departure_scene_change_enabled = false
	hub.crowd_seed = 7
	add_child(hub)
	hub._player.global_position = hub._cell(6.8, 12.9) - Vector2(0, HubWorld.FEET)
	await _frames(45)
	await _shot("hub-clean")
	var beka: Node2D = hub.crowd.beka
	beka.position = hub._player.global_position + Vector2(-38, HubWorld.FEET)
	beka._enter(beka.State.SIT)
	beka.pet()
	hub._focus_conversation(beka, 1.8)
	await get_tree().create_timer(0.65).timeout
	await _shot("beka-interaction")
	await get_tree().create_timer(2.2).timeout
	await _shot("beka-return")
	var layer := CanvasLayer.new()
	layer.layer = 160
	add_child(layer)
	var samples := CursorSamples.new()
	samples.position = Vector2(20, resolution.y - 156)
	samples.size = Vector2(resolution.x - 40, 136)
	layer.add_child(samples)
	await _frames(8)
	await _shot("cursor-native-size-samples")
	print("CURSOR_CAPTURE_READY")
	if not OS.get_cmdline_user_args().has("--stay"):
		get_tree().quit()


class CursorSamples extends Control:
	var assets: Array[Texture2D] = [preload("res://ui/cursor/arrow.svg"), preload("res://ui/cursor/point.svg"), preload("res://ui/cursor/cross.svg")]
	var font := ThemeDB.fallback_font

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var width := size.x / 3.0
		for sample in range(3):
			var left := sample * width
			if sample < 2:
				draw_rect(Rect2(left, 0, width, size.y), Color("f2e5ca") if sample == 0 else Color("100c0a"))
			else:
				draw_rect(Rect2(left, 0, width, size.y), Color(0.08, 0.05, 0.02, 0.24))
			draw_rect(Rect2(left, 0, width, size.y), Color("b58b4d"), false, 1)
			var text_color := Color("21170e") if sample == 0 else Color("fff1ce")
			draw_string(font, Vector2(left + 12, 24), ["Bright ground", "Dark ground", "Painted game ground"][sample], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)
			draw_string(font, Vector2(left + 12, 120), "Native-size cursor asset samples", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_color)
			for i in range(assets.size()):
				draw_texture(assets[i], Vector2(left + 28 + i * 64, 48))
