extends Node

## A loop attached to an objective must emit from its origin, including when
## the objective lives under a transformed world. Assigning world coordinates
## before parenting the emitter applies that world transform twice.
## Run with --headless --audio-driver Dummy; the real audio nodes stay silent.

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _emitters(owner: Node2D) -> Array[AudioStreamPlayer2D]:
	var out: Array[AudioStreamPlayer2D] = []
	for child in owner.get_children():
		if child is AudioStreamPlayer2D:
			out.append(child)
	return out


func _run() -> void:
	Global.debug_disable_autosave = true
	var world := Node2D.new()
	add_child(world)
	var owner := Node2D.new()
	world.add_child(owner)
	owner.position = Vector2(1200.0, 600.0)
	SfxManager.ensure_loop_2d(owner, &"capture", &"wardstone_loop")
	var emitters := _emitters(owner)
	_check(emitters.size() == 1, "starting objective capture creates one attached emitter")
	if emitters.is_empty():
		world.free()
		_finish()
		return
	var capture: AudioStreamPlayer2D = emitters[0]
	_check(capture.global_position.is_equal_approx(Vector2(1200.0, 600.0)), "a translated objective emits at (1200, 600), not twice that offset (%s)" % capture.global_position)
	var base_volume := capture.volume_db
	SfxManager.ensure_loop_2d(owner, &"capture", &"wardstone_loop", -3.0)
	_check(_emitters(owner).size() == 1 and _emitters(owner)[0] == capture, "ensuring the same owner/tag reuses its existing loop")
	_check(is_equal_approx(capture.volume_db, base_volume - 3.0), "ensuring an existing loop still updates its gain")
	SfxManager.stop_loop(owner, &"capture")
	await get_tree().process_frame
	_check(_emitters(owner).is_empty(), "stopping an objective loop removes its emitter")

	world.position = Vector2(1000.0, 2000.0)
	world.rotation = PI * 0.5
	world.scale = Vector2(2.0, 3.0)
	owner.position = Vector2(100.0, 50.0)
	SfxManager.ensure_loop_2d(owner, &"channel", &"exit_channel_loop")
	emitters = _emitters(owner)
	_check(emitters.size() == 1, "a stopped owner can start a new tagged objective loop")
	if not emitters.is_empty():
		var channel: AudioStreamPlayer2D = emitters[0]
		_check(channel.global_position.is_equal_approx(Vector2(850.0, 2200.0)), "rotation and nonuniform scale leave the emitter at the objective origin (%s)" % channel.global_position)
		world.position += Vector2(350.0, -600.0)
		_check(channel.global_position.is_equal_approx(Vector2(1200.0, 1600.0)), "an active loop follows its moving world without restarting (%s)" % channel.global_position)
		owner.position = Vector2(-40.0, 60.0)
		_check(channel.global_position.is_equal_approx(Vector2(1170.0, 1320.0)), "an active loop follows its moving owner within that world (%s)" % channel.global_position)
		SfxManager.ensure_loop_2d(owner, &"capture", &"wardstone_loop")
		_check(_emitters(owner).size() == 2, "different tags retain independent loops on one owner")
		SfxManager.stop_loop(owner, &"capture")
		await get_tree().process_frame
		_check(_emitters(owner).size() == 1 and _emitters(owner)[0] == channel, "stopping one tag preserves the other loop")
	world.free()
	_finish()


func _finish() -> void:
	print("PositionalLoopAudioTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
