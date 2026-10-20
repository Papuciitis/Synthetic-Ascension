extends Node
## Exercise the actual review controller without entering its Game/save lifecycle.

var _passed := 0
var _failed := 0

func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		push_error(message)

func _ready() -> void:
	var preview := preload("res://tools/dev/CityBlockPlayablePreview.gd").new()
	var player := CharacterBody2D.new()
	var camera := Camera2D.new()
	player.position = Vector2(400, 600)
	preview.set("_player", player)
	preview.set("_camera", camera)
	preview.set("_still_only", true)
	camera.position = Vector2(700, 800)
	preview.call("_process", 0.016)
	_check(camera.position == Vector2(700, 800), "Whole-building still framing must survive a render frame")
	preview.set("_still_only", false)
	preview.call("_process", 0.016)
	_check(camera.position == Vector2(540, 440), "Moving review must retain the production preview's actor follow camera")
	preview.set("_playable", true)
	camera.position = Vector2(20, 30)
	preview.call("_process", 0.016)
	_check(camera.position == Vector2(20, 30), "Human playable mode must keep its own camera control")
	preview.free()
	camera.free()
	player.free()
	print("CityBlockPreviewCameraTest: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed else 0)
