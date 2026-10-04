extends Node

# Roadmap Phase 2.1 mechanisms, on the 2026-10-04 feedback budget: hit-stop
# only on elite, boss and crit kills, camera punch only on the player being
# hurt and on elite or boss kills, never per pellet or per fodder kill, at most
# one stop per 600 ms, a 0.25 stop scale, and never clobbering another
# system's time_scale. Tuning is the human's; these pin the shapes.

const HitFeelScript = preload("res://autoload/HitFeel.gd")

class FakePlayer:
	extends Node2D
	var max_hp: float = 100.0

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


func _kill(handle: int, flags: int, position: Vector2) -> void:
	RunEvents.enemy_defeated.emit(EnemyDeathContext.new(handle, &"enemy_test", position, flags, null, {}))


func _wait_ms(ms: int) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _run() -> void:
	var previous_reduced: Variant = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	var previous_feel: Variant = SettingsManager.get_value(&"accessibility", &"hit_feel", true)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	SettingsManager.set_value(&"accessibility", &"hit_feel", true, false)
	Engine.time_scale = 1.0

	var defaults: Dictionary = SettingsSchema.defaults()
	_check(bool(defaults[&"accessibility"].get(&"hit_feel", false)), "the Hit-stop & camera punch setting defaults ON")

	# The registered HitFeel autoload listens to the same signals; silence its
	# effects so this test's own instance is the only one acting.
	var live := get_node_or_null("/root/HitFeel")
	_check(live != null and bool(live.get("hit_stop_enabled")) and bool(live.get("camera_punch_enabled")), "the live autoload ships with both effects enabled")
	_check(live != null and is_equal_approx(float(live.get("stop_scale")), 0.25), "a stop dips to a quarter speed, not the old 5%")
	_check(live != null and int(live.get("min_stop_interval_ms")) >= 600, "stops are at least 600 ms apart")
	if live != null:
		live.set("hit_stop_enabled", false)
		live.set("camera_punch_enabled", false)
	var feel := HitFeelScript.new()
	add_child(feel)
	var player := FakePlayer.new()
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	player.add_child(camera)
	player.position = Vector2(100.0, 100.0)
	player.add_to_group(&"player")
	add_child(player)

	# Per-hit feedback is gone: the per-pellet signal is not even listened to,
	# so EnemyCombatService's has_connections() guard can skip emitting it.
	_check(not RunEvents.player_hit_landed.is_connected(Callable(feel, "_on_crit_watch_hit")), "HitFeel does not listen to every pellet")
	RunEvents.player_hit_landed.emit(player, 1, Vector2(200.0, 100.0), 50.0, true, true)
	_check(is_equal_approx(Engine.time_scale, 1.0) and feel.punch_offset() == Vector2.ZERO, "a crit or elite HIT does nothing on its own")

	# A fodder kill never stops time or moves the camera.
	_kill(11, EnemyWorldTypes.Flags.NONE, Vector2(200.0, 100.0))
	_check(is_equal_approx(Engine.time_scale, 1.0), "a fodder kill does not stop time")
	_check(feel.punch_offset() == Vector2.ZERO, "and does not kick the camera")

	# An elite kill stops briefly and kicks toward the body.
	_kill(12, EnemyWorldTypes.Flags.ELITE, Vector2(100.0, 0.0))
	_check(is_equal_approx(Engine.time_scale, feel.stop_scale), "an elite kill dips time_scale to the stop scale (%.3f)" % Engine.time_scale)
	_check(feel.is_stopped(), "the stop is tracked")
	_check(feel.punch_offset().y < 0.0 and feel.punch_offset().length() <= 6.01, "and kicks the camera at most 6 px toward the body (%s)" % feel.punch_offset())
	_check(camera.offset == feel.punch_offset(), "the kick is applied to the camera offset")
	# Inside the window more triggers only extend, never past the cap.
	var cap_deadline: int = int(feel.get("_last_stop_msec")) + int(feel.max_stop_ms)
	_kill(13, EnemyWorldTypes.Flags.ELITE, Vector2(100.0, 0.0))
	_kill(14, EnemyWorldTypes.Flags.ELITE, Vector2(100.0, 0.0))
	_check(int(feel.get_debug_counters()["stops_applied"]) == 1, "a second elite kill inside the stop does not apply a second stop")
	_check(int(feel.get("_stop_until_msec")) <= cap_deadline, "and extensions never run past %d ms" % feel.max_stop_ms)
	var deadline := Time.get_ticks_msec() + 400
	while feel.is_stopped() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not feel.is_stopped() and is_equal_approx(Engine.time_scale, 1.0), "the stop releases on its own and restores time_scale")

	# The budget: the next elite kill inside 600 ms of the last stop is ignored.
	_kill(15, EnemyWorldTypes.Flags.ELITE, Vector2(100.0, 0.0))
	_check(is_equal_approx(Engine.time_scale, 1.0) and int(feel.get_debug_counters()["stops_applied"]) == 1, "stops are rate-limited to one per 600 ms")
	await _wait_ms(int(feel.min_stop_interval_ms) + 20)

	# A boss (CRITICAL without OBJECTIVE/TUTORIAL) counts like an elite.
	_kill(16, EnemyWorldTypes.Flags.CRITICAL | EnemyWorldTypes.Flags.NEVER_RETIRE, Vector2(200.0, 100.0))
	_check(feel.is_stopped(), "a boss kill stops time")
	await _wait_ms(int(feel.min_stop_interval_ms) + 20)
	_kill(17, EnemyWorldTypes.Flags.CRITICAL | EnemyWorldTypes.Flags.OBJECTIVE, Vector2(200.0, 100.0))
	_check(not feel.is_stopped(), "an objective target is not a boss")

	# Crit kills: only a Lucky Crit attack opens the watch, and only its own
	# crit hit's kill stops time.
	RunEvents.player_lucky_crit.emit(player, player.position, false)
	_check(not feel.is_watching_crits(), "a failed Lucky roll watches nothing")
	RunEvents.player_lucky_crit.emit(player, player.position, true)
	_check(feel.is_watching_crits(), "a Lucky Crit attack opens a short watch on its hits")
	RunEvents.player_hit_landed.emit(player, 21, Vector2(200.0, 100.0), 5.0, false, false)
	_kill(21, EnemyWorldTypes.Flags.NONE, Vector2(200.0, 100.0))
	_check(not feel.is_stopped(), "a non-crit kill during the watch does not stop time")
	RunEvents.player_hit_landed.emit(player, 22, Vector2(200.0, 100.0), 50.0, true, false)
	_kill(22, EnemyWorldTypes.Flags.NONE, Vector2(200.0, 100.0))
	_check(feel.is_stopped(), "the crit hit's own kill stops time")
	_check(feel.punch_offset() == Vector2.ZERO or feel.punch_offset().length() < 0.01, "a crit kill does not kick the camera")
	deadline = Time.get_ticks_msec() + feel.CRIT_WATCH_MS + 300
	while feel.is_watching_crits() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not feel.is_watching_crits(), "the watch closes on its own")

	# Taking damage kicks AWAY from the source, scaled and rate-limited.
	await _wait_ms(int(feel.min_stop_interval_ms) + 20)
	camera.offset = Vector2.ZERO
	feel.set("_punch_offset", Vector2.ZERO)
	RunEvents.player_damage_taken.emit(player, 30.0, Vector2(0.0, 100.0))
	var hurt_kick := feel.punch_offset()
	_check(hurt_kick.x > 0.0 and hurt_kick.length() <= 6.01, "a heavy hit kicks at most 6 px away from its source (%s)" % hurt_kick)
	var punches := int(feel.get_debug_counters()["punches"])
	RunEvents.player_damage_taken.emit(player, 30.0, Vector2(0.0, 100.0))
	_check(int(feel.get_debug_counters()["punches"]) == punches, "a second hit inside 250 ms does not kick again")
	await _wait_ms(int(feel.hurt_punch_interval_ms) + 20)
	feel.set("_punch_offset", Vector2.ZERO)
	RunEvents.player_damage_taken.emit(player, 1.0, Vector2(0.0, 100.0))
	_check(feel.punch_offset().length() < hurt_kick.length(), "a scratch kicks less than a heavy hit (%s vs %s)" % [feel.punch_offset(), hurt_kick])
	_check(is_equal_approx(Engine.time_scale, 1.0), "being hurt never stops time")

	# Never clobber another system's time_scale, slower or faster.
	await _wait_ms(int(feel.min_stop_interval_ms) + 20)
	for foreign in [0.5, 0.35, 0.2]:
		Engine.time_scale = foreign
		_kill(30, EnemyWorldTypes.Flags.ELITE, Vector2(200.0, 100.0))
		_check(is_equal_approx(Engine.time_scale, foreign), "a stop never overrides a foreign time_scale of %.2f" % foreign)
	Engine.time_scale = 1.0
	# A slow-mo that starts DURING a stop keeps the time_scale when it ends.
	_kill(31, EnemyWorldTypes.Flags.ELITE, Vector2(200.0, 100.0))
	_check(feel.is_stopped(), "fixture: a stop is running")
	Engine.time_scale = 0.35
	deadline = Time.get_ticks_msec() + 400
	while feel.is_stopped() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 0.35), "releasing a stop leaves a slow-mo that took over alone (%.2f)" % Engine.time_scale)
	Engine.time_scale = 1.0

	# Reduced motion, and the toggle itself: no stop, no kick.
	await _wait_ms(int(feel.min_stop_interval_ms) + 20)
	for gate in [&"reduced_motion", &"hit_feel"]:
		SettingsManager.set_value(&"accessibility", &"reduced_motion", gate == &"reduced_motion", false)
		SettingsManager.set_value(&"accessibility", &"hit_feel", gate != &"hit_feel", false)
		var punches_before := int(feel.get_debug_counters()["punches"])
		_kill(40, EnemyWorldTypes.Flags.ELITE, Vector2(200.0, 100.0))
		feel.set("_last_hurt_punch_msec", -100000)
		RunEvents.player_damage_taken.emit(player, 30.0, Vector2(0.0, 100.0))
		_check(is_equal_approx(Engine.time_scale, 1.0), "%s disables hit-stop" % gate)
		_check(int(feel.get_debug_counters()["punches"]) == punches_before, "%s disables the camera kick" % gate)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	SettingsManager.set_value(&"accessibility", &"hit_feel", true, false)

	# Leaving the tree mid-stop restores time.
	_kill(41, EnemyWorldTypes.Flags.ELITE, Vector2(200.0, 100.0))
	_check(feel.is_stopped(), "fixture: a stop is running before the free")
	feel.queue_free()
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "freeing HitFeel mid-stop restores time_scale")

	# Controlled A/B: the same elite kill is sent through every combination.
	# This keeps a positional camera kick distinct from a temporal world
	# slowdown, so a report that one feels like lag can be diagnosed.
	var both := await _run_comparison_arm(player, camera, true, true)
	var stop_only := await _run_comparison_arm(player, camera, true, false)
	var punch_only := await _run_comparison_arm(player, camera, false, true)
	var neither := await _run_comparison_arm(player, camera, false, false)
	_check(bool(both["temporal"]) and bool(both["positional"]), "A/B both arm contains temporal slowdown and positional punch")
	_check(bool(stop_only["temporal"]) and not bool(stop_only["positional"]), "A/B hit-stop-only arm changes time without moving the camera")
	_check(not bool(punch_only["temporal"]) and bool(punch_only["positional"]), "A/B camera-only arm moves the camera without slowing time")
	_check(not bool(neither["temporal"]) and not bool(neither["positional"]), "A/B disabled arm changes neither time nor camera")
	_check(
		await _camera_punch_has_decay_tail(player, camera),
		"an elite-kill punch eases over more than one reference frame instead of snapping like a hitch"
	)

	await _test_settings_row()

	SettingsManager.set_value(&"accessibility", &"reduced_motion", previous_reduced, false)
	SettingsManager.set_value(&"accessibility", &"hit_feel", previous_feel, false)
	if live != null:
		live.set("hit_stop_enabled", true)
		live.set("camera_punch_enabled", true)
	player.queue_free()
	await get_tree().process_frame
	print("HitFeelTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## The Accessibility page builds the row and shows the live value. Never
## toggled here: the screen persists what it changes.
func _test_settings_row() -> void:
	var screen := (load("res://ui/screens/settings/SettingsScreen.tscn") as PackedScene).instantiate()
	screen.call("configure", SettingsManager)
	add_child(screen)
	await get_tree().process_frame
	screen.call("open")
	await get_tree().process_frame
	(screen.find_child("AccessibilityTab", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var row: CheckBox = null
	for node in screen.find_children("", "CheckBox", true, false):
		if (node as CheckBox).text == "Brief hit-stop and camera punch on big moments":
			row = node as CheckBox
	_check(row != null, "Accessibility builds the Hit-stop & Camera Punch checkbox")
	if row != null:
		_check(row.button_pressed == bool(SettingsManager.get_value(&"accessibility", &"hit_feel", true)), "and it shows the live setting")
	screen.call("close")
	screen.queue_free()
	await get_tree().process_frame


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
	add_child(feel)
	_kill(50, EnemyWorldTypes.Flags.ELITE, Vector2(180.0, 100.0))
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
	_kill(51, EnemyWorldTypes.Flags.ELITE, Vector2(180.0, 100.0))
	var before := camera.offset.length()
	feel._process(1.0 / 60.0)
	var after := camera.offset.length()
	feel.queue_free()
	await get_tree().process_frame
	camera.offset = Vector2.ZERO
	return before > 0.0 and after > 0.0 and after < before
