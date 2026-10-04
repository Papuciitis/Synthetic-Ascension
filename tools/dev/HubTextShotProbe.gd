extends Node
## Renders the hub square's text to PNGs (needs a display, not --headless):
## the station signs from the arrival, each prompt in range, staff and crowd
## speech, Beka's pet prompt, purr and sleep, the gate's pending-choice cue
## and a passing notice. Every shot also saves a 2x crop around the subject
## (<name>_zoom.png), since the text is small at gameplay zoom.
## Run: <godot> --path . res://tools/dev/HubTextShotProbe.tscn -- --out=/abs/dir [--reduced]
## (--reduced turns Reduced Motion on for this run only; nothing is saved).

const HUB_WORLD := preload("res://scenes/hub/HubWorld.tscn")

var _out := "/tmp"
var _hub: HubWorld = null


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--reduced":
			SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	DirAccess.make_dir_recursive_absolute(_out)
	if not Global.attempt_active:
		Global.start_new_attempt()
	SaveManager.current_save = null
	# No story card may stop an unattended run (StoryDirector.cards_allowed).
	StoryDirector.cards_override = 0
	Global.followers = 6000
	Global.pending_big_choice = false
	_hub = HUB_WORLD.instantiate()
	_hub.crowd_seed = 7
	_hub.departure_scene_change_enabled = false
	add_child(_hub)
	var camera := _hub._player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.position_smoothing_enabled = false
	await _frames(30)
	await _shot("text_arrival", _feet())
	await _shot("text_idle_sign", HubWorld.STATION_CELLS["ascension"] * HubWorld.CELL + Vector2(0, -40))

	# The Merchant: feet on the medallion, the Exchanger greets the player.
	_stand(HubWorld.STATION_CELLS["merchant"] * HubWorld.CELL + Vector2(0, 10))
	await _frames(4)
	await _shot("text_merchant_fading", _feet() + Vector2(0, -60))
	await _frames(40)
	await _shot("text_merchant", _feet() + Vector2(0, -60))

	_stand(HubWorld.STATION_CELLS["ascension"] * HubWorld.CELL + Vector2(0, 12))
	await _frames(40)
	await _shot("text_ascension", _feet() + Vector2(0, -60))

	_stand(HubWorld.STATION_CELLS["gear"] * HubWorld.CELL + Vector2(0, 12))
	await _frames(40)
	await _shot("text_gear", _feet() + Vector2(0, -60))

	# A believer's line, close to the player in the open square.
	_stand(_hub._cell(12.5, 9.0))
	await _frames(10)
	var crowd: Node = _hub.crowd
	var believer: Node2D = (crowd.believers[0] as Dictionary)["p"]
	believer.position = _hub._cell(13.6, 9.0)
	crowd.say(believer, "Containment is still counting heads.", 6.0)
	var long_speaker: Node2D = (crowd.believers[1] as Dictionary)["p"]
	long_speaker.position = _hub._cell(10.6, 8.6)
	crowd.say(long_speaker, "They said it couldn't be made, and then the Registry came to count the rest of us.", 6.0)
	await _frames(30)
	await _shot("text_crowd", _feet() + Vector2(0, -60))

	# The gate while a required choice waits: the ember cue under the ring,
	# the prompt, and the notice the gate gives.
	Global.pending_big_choice = true
	_hub._update_pending_cue()
	_stand(HubWorld.STATION_CELLS["exit"] * HubWorld.CELL + Vector2(0, 40))
	await _frames(40)
	_hub._notice.show_line(_hub._exit_station.global_position + Vector2(0, HubStation.PROMPT_Y - 40.0), "A decision waits before the road.", Color(1.0, 0.62, 0.30), 4.0)
	await _frames(20)
	await _shot("text_gate", _feet() + Vector2(0, -80))
	Global.pending_big_choice = false
	_hub._update_pending_cue()

	# Beka asleep on her bed, the player beside her: the pet prompt and z's.
	var beka: Node2D = crowd.beka
	beka.position = beka.bed
	beka._enter(beka.State.SLEEP)
	_stand(beka.bed + Vector2(40.0, -26.0))
	await _frames(40)
	await _shot("text_beka_sleep", beka.bed + Vector2(0, -20))
	beka.pet()
	await _frames(14)
	await _shot("text_beka_pet", beka.bed + Vector2(0, -20))
	# The Quiet Alcove's own line, used from its ring.
	_stand(HubWorld.STATION_CELLS["alcove"] * HubWorld.CELL)
	await _frames(30)
	_hub._rest_a_moment()
	await _frames(16)
	await _shot("text_alcove_notice", HubWorld.STATION_CELLS["alcove"] * HubWorld.CELL + Vector2(-40, -10))
	get_tree().quit(0)


func _feet() -> Vector2:
	return _hub._player.global_position + Vector2(0.0, HubWorld.FEET)


func _stand(feet: Vector2) -> void:
	_hub._player.global_position = feet - Vector2(0.0, HubWorld.FEET)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## Saves the window and a 2x crop centred on `world` (a world point).
func _shot(file_name: String, world: Vector2) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, file_name])
	var screen := get_viewport().get_screen_transform() * get_viewport().get_canvas_transform() * world
	var crop_size := Vector2i(560, 315)
	var origin := Vector2i(screen) - Vector2i(280, 157)
	origin.x = clampi(origin.x, 0, image.get_width() - crop_size.x)
	origin.y = clampi(origin.y, 0, image.get_height() - crop_size.y)
	var crop := image.get_region(Rect2i(origin, crop_size))
	crop.resize(crop_size.x * 2, crop_size.y * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/%s_zoom.png" % [_out, file_name])
	print("HubTextShotProbe -> ", file_name)
