extends Node

## Missing hooks must fail these checks: an accepted dash sounds once, and
## actual HP loss sounds quietly without treating a shield/evade as injury.
## Requests are observed before SfxManager's headless playback guard.

const PLAYER_SCENE := preload("res://core/actors/player/player.tscn")

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


func _requests(id: StringName) -> Array:
	return SfxManager.debug_requests.filter(func(request: Dictionary) -> bool: return request["id"] == id)


func _wait_ms(milliseconds: int) -> void:
	var deadline := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _run() -> void:
	# D-18: a real Player must never inherit the regular profile or recorder
	# destinations, even if its setup gains new persistence hooks later.
	SaveManager.current_save = null
	SaveManager.save_dir = "user://player_action_audio_test_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	SfxManager.debug_record = true
	SfxManager.debug_requests.clear()
	_test_assets()
	_test_dash_events()
	await _test_resolved_damage()
	await _test_real_player()
	SfxManager.debug_record = false
	SfxManager.debug_requests.clear()
	print("PlayerActionAudioTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_assets() -> void:
	var definitions: Dictionary = SfxManager.get("_defs")
	for id: StringName in [&"player_dash", &"player_hurt"]:
		var definition: Variant = definitions.get(id)
		_check(definition != null, "%s resolves through the sound manifest" % id)
		if definition == null:
			continue
		var stream: AudioStream = definition.stream
		_check(stream is AudioStreamWAV and stream.get_length() > 0.0, "%s loads a nonempty PCM WAV" % id)
		_check(definition.bus == &"SFX", "%s follows the existing Sound Effects volume/mute bus" % id)
		_check(not definition.loop, "%s is a one-shot" % id)
		_check(float(definition.vol_db) <= -8.0, "%s starts below the main weapon recordings" % id)


func _test_dash_events() -> void:
	SfxManager.debug_requests.clear()
	var player := Node2D.new()
	add_child(player)
	var origin := Vector2(120.0, 340.0)
	RunEvents.player_dashed.emit(player, origin, Vector2.RIGHT)
	var requests := _requests(&"player_dash")
	_check(requests.size() == 1, "one accepted dash emits one dash cue")
	if requests.size() == 1:
		_check(requests[0]["kind"] == &"2d" and requests[0]["position"] == origin, "the dash leaves its sound at the departure point")
	RunEvents.player_dashed.emit(player, Vector2(200.0, 340.0), Vector2.LEFT)
	_check(_requests(&"player_dash").size() == 2, "a second accepted dash is not swallowed by the hurt throttle")
	player.free()


func _test_resolved_damage() -> void:
	SfxManager.debug_requests.clear()
	var player := Node2D.new()
	add_child(player)
	# Every row is a real documented player_damage_resolved outcome with no
	# HP removed; after_defenses can still be positive for an absorbed hit.
	for outcome: StringName in [&"god_mode", &"invulnerable", &"evaded", &"missed", &"absorbed", &"intercepted"]:
		RunEvents.player_damage_resolved.emit(player, 20.0, 12.0, 0.0, null, &"contact_swarm", outcome)
	_check(_requests(&"player_hurt").is_empty(), "blocked, evaded, shielded and zero-loss intercepted hits stay silent")
	RunEvents.player_damage_resolved.emit(player, 20.0, 12.0, 3.0, null, &"contact_swarm", &"hit")
	var requests := _requests(&"player_hurt")
	_check(requests.size() == 1, "positive HP loss emits one injury cue")
	if requests.size() == 1:
		_check(requests[0]["kind"] == &"global", "injury feedback is non-positional")
	RunEvents.player_damage_resolved.emit(player, 20.0, 12.0, 3.0, null, &"contact_swarm", &"hit")
	_check(_requests(&"player_hurt").size() == 1, "simultaneous swarm hits share one injury cue")
	await _wait_ms(160)
	RunEvents.player_damage_resolved.emit(player, 20.0, 12.0, 3.0, null, &"contact_swarm", &"hit")
	_check(_requests(&"player_hurt").size() == 1, "a further hit inside the injury cooldown stays quiet")
	await _wait_ms(100)
	RunEvents.player_damage_resolved.emit(player, 20.0, 12.0, 3.0, null, &"contact_swarm", &"intercepted")
	_check(_requests(&"player_hurt").size() == 2, "an intercepted lethal hit with actual HP loss sounds after recovery")
	player.free()


func _test_real_player() -> void:
	await _wait_ms(260)
	var previous_luck: float = Global.run_luck
	var previous_god_mode: bool = Global.debug_player_god_mode
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	player.set_physics_process(false)
	Global.run_luck = 0.0
	Global.debug_player_god_mode = false
	SfxManager.debug_requests.clear()
	_check(not bool(player.call("dash_toward", Vector2.ZERO, 120.0)), "fixture: a directionless dash is rejected")
	_check(_requests(&"player_dash").is_empty(), "a rejected dash stays silent")
	_check(bool(player.call("dash_toward", Vector2.RIGHT, 120.0)), "fixture: the real directed dash is accepted")
	_check(_requests(&"player_dash").size() == 1, "the real accepted dash reaches audio exactly once")
	var dash_state: RefCounted = player.get("_dash")
	dash_state.call("request")
	player.call("_tick_dash", 0.01)
	_check(_requests(&"player_dash").size() == 1, "a buffered request during dash recovery adds no cue")
	player.call("cancel_dash")
	player.set("invulnerable_time", 0.0)
	SfxManager.debug_requests.clear()
	var health_before := float(player.get("hp"))
	player.call("_take_damage", 3.0, null, &"contact_swarm")
	_check(float(player.get("hp")) < health_before, "fixture: a real incoming hit removes HP")
	_check(_requests(&"player_hurt").size() == 1, "the player's real HP damage path reaches injury audio once")
	await _wait_ms(260)
	SfxManager.debug_requests.clear()
	player.call("grant_invulnerability", 0.5)
	player.call("_take_damage", 3.0, null, &"contact_swarm")
	_check(_requests(&"player_hurt").is_empty(), "a real invulnerable hit produces no false injury audio")
	player.set("invulnerable_time", 0.0)
	Global.debug_player_god_mode = true
	player.call("_take_damage", 3.0, null, &"contact_swarm")
	_check(_requests(&"player_hurt").is_empty(), "god-mode damage produces no false injury audio")
	Global.debug_player_god_mode = false
	var paid := float(player.call("pay_health", 1.0, &"ascension", false))
	_check(paid > 0.0 and _requests(&"player_hurt").is_empty(), "an intentional HP payment is distinct from injury")
	Global.debug_player_god_mode = previous_god_mode
	Global.run_luck = previous_luck
	player.queue_free()
	await get_tree().process_frame
