extends Node

# Adaptive music (2026-10-04 feel pass): the Music bus low-pass follows the
# segment - recon ~3.5 kHz, disturbance ~6 kHz, ascension ~10 kHz, collapse
# and a live exit encounter open - stays open in menus and the hub, closes to
# ~1.2 kHz with a small duck at or below 30% health, and eases over ~2 s.
# Headless runs skip the audio itself; the decisions are read directly.

class FakePlayer extends Node2D:
	var hp: float = 100.0
	var max_hp: float = 100.0
	var is_dead: bool = false

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


func _run() -> void:
	var music := get_node("/root/AudioManager")
	var script: Script = music.get_script()
	# The shape of the curve.
	_check(is_equal_approx(script.intensity_cutoff(false, &"collapse", false, true), script.CUTOFF_OPEN_HZ), "outside combat (menus, the hub) the music is open")
	_check(is_equal_approx(script.intensity_cutoff(true, &"recon", false, false), 3500.0), "recon is muffled to 3.5 kHz")
	_check(is_equal_approx(script.intensity_cutoff(true, &"disturbance", false, false), 6000.0), "disturbance warms to 6 kHz")
	_check(is_equal_approx(script.intensity_cutoff(true, &"ascension", false, false), 10000.0), "ascension reaches 10 kHz")
	_check(is_equal_approx(script.intensity_cutoff(true, &"collapse", false, false), script.CUTOFF_OPEN_HZ), "collapse is fully open")
	_check(is_equal_approx(script.intensity_cutoff(true, &"recon", true, false), script.CUTOFF_OPEN_HZ), "a live exit encounter opens it in any phase")
	_check(is_equal_approx(script.intensity_cutoff(true, &"collapse", true, true), 1200.0), "and low health closes it to 1.2 kHz over everything")

	# The live reading: context, spawner, phase and the player's health.
	var previous_key: StringName = music.get("_current_key")
	var previous_phase: StringName = ThreatDirector.segment_phase
	music.set("_current_key", &"game")
	var spawner := Node.new()
	spawner.add_to_group(&"enemy_spawner")
	add_child(spawner)
	var player := FakePlayer.new()
	player.add_to_group(&"player")
	add_child(player)
	ThreatDirector.set_segment_phase(&"disturbance")
	var target: Dictionary = music.intensity_target()
	_check(is_equal_approx(float(target["cutoff_hz"]), 6000.0) and is_zero_approx(float(target["duck_db"])), "a combat segment in disturbance reads 6 kHz, no duck (%s)" % target)
	player.hp = 25.0
	target = music.intensity_target()
	_check(is_equal_approx(float(target["cutoff_hz"]), 1200.0) and float(target["duck_db"]) < 0.0, "at 25%% health it muffles to 1.2 kHz and ducks (%s)" % target)
	player.is_dead = true
	target = music.intensity_target()
	_check(is_equal_approx(float(target["cutoff_hz"]), 6000.0), "a dead player (the reconstruction card) is not muffled")
	player.is_dead = false
	player.hp = 90.0
	spawner.remove_from_group(&"enemy_spawner")
	target = music.intensity_target()
	_check(is_equal_approx(float(target["cutoff_hz"]), script.CUTOFF_OPEN_HZ), "with no spawner (the hub, the Base) the music is open")
	music.set("_current_key", &"menu")
	spawner.add_to_group(&"enemy_spawner")
	target = music.intensity_target()
	_check(is_equal_approx(float(target["cutoff_hz"]), script.CUTOFF_OPEN_HZ), "and in the menu context")

	# Easing: about two seconds to settle, never a jump.
	music.set("_current_key", &"game")
	music.set("_cutoff_hz", script.CUTOFF_OPEN_HZ)
	music.set("_poll_left", 0.0)
	player.hp = 20.0
	music.call("_process", 0.1)
	var after_tenth := float(music.call("current_cutoff_hz"))
	_check(after_tenth < script.CUTOFF_OPEN_HZ and after_tenth > 6000.0, "a tenth of a second in, the cutoff has only begun to fall (%.0f Hz)" % after_tenth)
	for i in range(19):
		music.call("_process", 0.1)
	var after_two := float(music.call("current_cutoff_hz"))
	_check(after_two < 1200.0 * 1.25, "after two seconds it has settled near 1.2 kHz (%.0f Hz)" % after_two)

	music.set("_current_key", previous_key)
	music.set("_cutoff_hz", script.CUTOFF_OPEN_HZ)
	music.set("_duck_db", 0.0)
	ThreatDirector.set_segment_phase(previous_phase)
	spawner.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("AdaptiveMusicTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
