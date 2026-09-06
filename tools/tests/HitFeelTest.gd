extends Node

# Roadmap Phase 2.1 mechanisms: hit-stop and camera punch driven by the
# combat signals, budgeted, accessibility-aware, and never clobbering another
# system's time_scale. Tuning is the human's; these pin the shapes.

const HitFeelScript = preload("res://autoload/HitFeel.gd")

class FakePlayer:
	extends Node2D

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
	var previous_reduced: Variant = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	Engine.time_scale = 1.0

	# The registered HitFeel autoload listens to the same signals; silence its
	# effects so this test's own instance is the only one acting.
	var live := get_node_or_null("/root/HitFeel")
	if live != null:
		live.set("hit_stop_enabled", false)
		live.set("camera_punch_enabled", false)
	var feel := HitFeelScript.new()
	feel.min_stop_interval_ms = 120
	feel.stop_ms = {"crit": 40, "elite": 30, "kill": 60, "melee": 35}
	add_child(feel)
	var player := FakePlayer.new()
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	player.add_child(camera)
	player.position = Vector2(100.0, 100.0)
	add_child(player)
	var previous_style: String = String(Global.selected_style_id)
	Global.selected_style_id = "ranged"

	# An ordinary pellet: no stop, only a light kick toward the hit.
	RunEvents.player_hit_landed.emit(player, 1, Vector2(200.0, 100.0), 5.0, false, false)
	_check(is_equal_approx(Engine.time_scale, 1.0), "an ordinary pellet hit does not stop time")
	_check(feel.punch_offset().x > 0.0 and absf(feel.punch_offset().y) < 0.001, "the camera kicks toward the hit (%s)" % feel.punch_offset())
	_check(camera.offset == feel.punch_offset(), "the kick is applied to the camera offset")

	# A crit stops time briefly, then restores it.
	RunEvents.player_hit_landed.emit(player, 1, Vector2(200.0, 100.0), 50.0, true, false)
	_check(is_equal_approx(Engine.time_scale, feel.stop_scale), "a crit dips time_scale to the stop scale (%.3f)" % Engine.time_scale)
	_check(feel.is_stopped(), "the stop is tracked")
	# Inside the budget window a second crit extends instead of restarting.
	RunEvents.player_hit_landed.emit(player, 2, Vector2(200.0, 100.0), 50.0, true, false)
	_check(int(feel.get_debug_counters()["stops_applied"]) == 1, "a second crit inside the window does not apply a second stop")
	var deadline := Time.get_ticks_msec() + 400
	while feel.is_stopped() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not feel.is_stopped() and is_equal_approx(Engine.time_scale, 1.0), "the stop releases on its own and restores time_scale")

	# The budget: a crit right after a release is ignored until the interval passes.
	RunEvents.player_hit_landed.emit(player, 3, Vector2(200.0, 100.0), 50.0, true, false)
	_check(is_equal_approx(Engine.time_scale, 1.0) and int(feel.get_debug_counters()["stops_applied"]) == 1, "stops are rate-limited to one per interval")
	deadline = Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	# Kills stop and kick toward the corpse.
	RunEvents.enemy_killed.emit(player, null, Vector2(100.0, 0.0))
	_check(feel.is_stopped(), "a kill stops time")
	_check(feel.punch_offset().y < 0.0, "a kill kicks toward the corpse (%s)" % feel.punch_offset())
	deadline = Time.get_ticks_msec() + 400
	while feel.is_stopped() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	# The punch decays back to rest.
	deadline = Time.get_ticks_msec() + 800
	while feel.punch_offset() != Vector2.ZERO and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(feel.punch_offset() == Vector2.ZERO and camera.offset == Vector2.ZERO, "the kick decays back to rest")

	# Taking damage kicks AWAY from the source.
	RunEvents.player_damage_taken.emit(player, 10.0, Vector2(0.0, 100.0))
	_check(feel.punch_offset().x > 0.0, "damage taken kicks away from its source (%s)" % feel.punch_offset())

	# Never clobber another system's time_scale.
	deadline = Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	Engine.time_scale = 0.5
	RunEvents.player_hit_landed.emit(player, 4, Vector2(200.0, 100.0), 50.0, true, false)
	_check(is_equal_approx(Engine.time_scale, 0.5), "a stop never overrides a foreign time_scale")
	Engine.time_scale = 1.0

	# Reduced motion: no stop, no kick.
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	deadline = Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var punches_before := int(feel.get_debug_counters()["punches"])
	RunEvents.player_hit_landed.emit(player, 5, Vector2(200.0, 100.0), 50.0, true, true)
	_check(is_equal_approx(Engine.time_scale, 1.0), "reduced motion disables hit-stop")
	_check(int(feel.get_debug_counters()["punches"]) == punches_before, "reduced motion disables the camera kick")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)

	# Leaving the tree mid-stop restores time.
	RunEvents.player_hit_landed.emit(player, 6, Vector2(200.0, 100.0), 50.0, true, false)
	deadline = Time.get_ticks_msec() + 200
	while not feel.is_stopped() and Time.get_ticks_msec() < deadline:
		RunEvents.player_hit_landed.emit(player, 6, Vector2(200.0, 100.0), 50.0, true, false)
		await get_tree().process_frame
	feel.queue_free()
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "freeing HitFeel mid-stop restores time_scale")

	# Controlled A/B: the same kill is sent through every combination. This
	# keeps a positional camera kick distinct from a temporal world slowdown,
	# so a report that one feels like lag can be diagnosed without guessing.
	var both := await _run_comparison_arm(player, camera, true, true)
	var stop_only := await _run_comparison_arm(player, camera, true, false)
	var punch_only := await _run_comparison_arm(player, camera, false, true)
	var neither := await _run_comparison_arm(player, camera, false, false)
	_check(
		bool(both["temporal"]) and bool(both["positional"]),
		"A/B both arm contains temporal slowdown and positional punch"
	)
	_check(
		bool(stop_only["temporal"]) and not bool(stop_only["positional"]),
		"A/B hit-stop-only arm changes time without moving the camera"
	)
	_check(
		not bool(punch_only["temporal"]) and bool(punch_only["positional"]),
		"A/B camera-only arm moves the camera without slowing time"
	)
	_check(
		not bool(neither["temporal"]) and not bool(neither["positional"]),
		"A/B disabled arm changes neither time nor camera"
	)
	_check(
		await _camera_punch_has_decay_tail(player, camera),
		"a kill punch eases over more than one reference frame instead of snapping like a hitch"
	)

	Global.selected_style_id = previous_style
	SettingsManager.set_value(&"accessibility", &"reduced_motion", previous_reduced, false)
	if live != null:
		live.set("hit_stop_enabled", true)
		live.set("camera_punch_enabled", true)
	player.queue_free()
	await get_tree().process_frame
	print("HitFeelTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _run_comparison_arm(
	player: Node2D,
	camera: Camera2D,
	hit_stop: bool,
	camera_punch: bool,
) -> Dictionary:
	Engine.time_scale = 1.0
	camera.offset = Vector2.ZERO
	var feel := HitFeelScript.new()
	feel.hit_stop_enabled = hit_stop
	feel.camera_punch_enabled = camera_punch
	feel.min_stop_interval_ms = 120
	feel.stop_ms = {"crit": 40, "elite": 30, "kill": 60, "melee": 35}
	add_child(feel)
	RunEvents.enemy_killed.emit(player, null, Vector2(180.0, 100.0))
	var result := {
		"temporal": not is_equal_approx(Engine.time_scale, 1.0),
		"positional": camera.offset != Vector2.ZERO,
	}
	# Stop listening before cleanup so only one comparison arm receives the
	# next shared signal. _exit_tree also restores a stop it owns.
	feel.queue_free()
	await get_tree().process_frame
	Engine.time_scale = 1.0
	camera.offset = Vector2.ZERO
	return result


func _camera_punch_has_decay_tail(player: Node2D, camera: Camera2D) -> bool:
	Engine.time_scale = 1.0
	camera.offset = Vector2.ZERO
	var feel := HitFeelScript.new()
	feel.hit_stop_enabled = false
	feel.camera_punch_enabled = true
	add_child(feel)
	RunEvents.enemy_killed.emit(player, null, Vector2(180.0, 100.0))
	var before := camera.offset.length()
	feel._process(1.0 / 60.0)
	var after := camera.offset.length()
	feel.queue_free()
	await get_tree().process_frame
	camera.offset = Vector2.ZERO
	return before > 0.0 and after > 0.0 and after < before
