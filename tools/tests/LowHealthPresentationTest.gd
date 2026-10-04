extends Node

# Player hurt and low-health presentation (audit 2026-10-04, change 6): a hit
# tints the body red for 0.08 s, protective invulnerability blinks it (steady
# under Reduced Motion), and at or below 30% health the HUD's danger overlay
# pulses a red vignette (0.25-0.45 at 1.1 Hz) with a heartbeat per pulse,
# -14 dB at 30% rising to -8 dB at 15%.

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const OverlayScript = preload("res://ui/controllers/HudDangerOverlay.gd")
const STEP := 1.0 / 60.0

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
	var previous_reduced: Variant = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	await _test_body_feedback()
	await _test_danger_overlay()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", previous_reduced, false)
	print("LowHealthPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _step(player: Node, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		player.call("_process", minf(STEP, left))
		left -= STEP


func _test_body_feedback() -> void:
	var previous_luck: float = Global.run_luck
	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	# After the player's first stat pass, which writes its race's Luck: no
	# Lucky evasion may eat the fixture's hit.
	Global.run_luck = 0.0
	var visual := player.get_node("Visual") as CanvasItem
	_check(visual.modulate == Color.WHITE, "fixture: the body starts untinted")

	player.call("_take_damage", 5.0, null, &"contact_swarm")
	_step(player, STEP)
	_check(visual.modulate.r > 1.2 and visual.modulate.g < 0.8, "a hit tints the body red (%s)" % visual.modulate)
	_step(player, 0.1)
	_check(visual.modulate == Color.WHITE, "and the tint is gone after 0.08 s (%s)" % visual.modulate)

	# Respawn protection blinks for as long as it lasts.
	player.call("respawn")
	var alphas := {}
	var invuln: float = float(player.get("invulnerable_time"))
	_check(invuln > 0.0, "fixture: a respawn grants invulnerability (%.2fs)" % invuln)
	for i in range(30):
		_step(player, STEP)
		alphas[snappedf(visual.modulate.a, 0.01)] = true
	_check(alphas.has(1.0) and alphas.has(player.BLINK_ALPHA), "the protected body blinks between full and %.1f (%s)" % [player.BLINK_ALPHA, alphas.keys()])
	_step(player, invuln + 0.2)
	_check(visual.modulate == Color.WHITE, "and stops blinking when the protection ends (%s)" % visual.modulate)

	# A dash's own i-frames do not blink.
	player.call("grant_invulnerability", 0.5)
	_step(player, 0.1)
	_check(visual.modulate == Color.WHITE, "plain invulnerability (a dash) does not blink")
	_step(player, 0.5)

	# Reduced Motion: steady translucency instead of a blink.
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	player.call("_grant_visible_invulnerability", 0.5)
	var steady := true
	for i in range(12):
		_step(player, STEP)
		steady = steady and is_equal_approx(visual.modulate.a, player.BLINK_STEADY_ALPHA)
	_check(steady, "Reduced Motion holds the protected body at a steady %.2f" % player.BLINK_STEADY_ALPHA)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	player.queue_free()
	Global.run_luck = previous_luck
	await get_tree().process_frame
	await get_tree().process_frame


func _test_danger_overlay() -> void:
	SfxManager.debug_record = true
	SfxManager.debug_requests.clear()
	var fake := FakePlayer.new()
	fake.add_to_group(&"player")
	add_child(fake)
	var overlay: Control = OverlayScript.new()
	overlay.size = Vector2(1920, 1080)
	add_child(overlay)
	await get_tree().process_frame

	fake.hp = 50.0
	overlay.call("_process", 0.11)
	_check(not overlay.is_low_health_shown() and overlay.vignette_alpha() == 0.0, "at 50% health nothing shows")
	_check(_heartbeats().is_empty(), "and nothing beats")

	fake.hp = 25.0
	overlay.call("_process", 0.11)
	_check(overlay.is_low_health_shown(), "at 25% the danger vignette shows")
	var beats := _heartbeats()
	_check(beats.size() == 1 and beats[0]["kind"] == &"global", "the first heartbeat sounds at once, non-positional (%d)" % beats.size())
	if beats.size() == 1:
		_check(absf(float(beats[0]["vol_add_db"]) - 2.0) < 0.05, "at 25%% it is +2 dB over the -14 dB base (%.2f)" % float(beats[0]["vol_add_db"]))
	var lowest := 1.0
	var highest := 0.0
	for i in range(int(1.0 / (OverlayScript.PULSE_HZ * STEP)) + 5):
		overlay.call("_process", STEP)
		lowest = minf(lowest, overlay.vignette_alpha())
		highest = maxf(highest, overlay.vignette_alpha())
	_check(lowest >= OverlayScript.ALPHA_MIN - 0.001 and highest <= OverlayScript.ALPHA_MAX + 0.001, "the vignette pulses inside %.2f-%.2f (%.3f-%.3f)" % [OverlayScript.ALPHA_MIN, OverlayScript.ALPHA_MAX, lowest, highest])
	_check(highest - lowest > 0.15, "and visibly swells (%.3f)" % (highest - lowest))
	_check(_heartbeats().size() == 2, "one more heartbeat per 1/1.1 s pulse (%d)" % _heartbeats().size())

	fake.hp = 10.0
	SfxManager.debug_requests.clear()
	for i in range(int(1.0 / (OverlayScript.PULSE_HZ * STEP)) + 2):
		overlay.call("_process", STEP)
	beats = _heartbeats()
	_check(beats.size() >= 1 and absf(float(beats[-1]["vol_add_db"]) - 6.0) < 0.05, "at 10%% the heartbeat is at its loudest, +6 dB (-8 dB) (%s)" % [beats.map(func(b: Dictionary) -> float: return b["vol_add_db"])])

	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	var steady := true
	for i in range(30):
		overlay.call("_process", STEP)
		steady = steady and is_equal_approx(overlay.vignette_alpha(), OverlayScript.STEADY_ALPHA)
	_check(steady, "Reduced Motion holds the vignette steady at %.2f" % OverlayScript.STEADY_ALPHA)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)

	fake.is_dead = true
	overlay.call("_process", STEP)
	_check(not overlay.is_low_health_shown(), "a dead player (the reconstruction card) shows no vignette")
	fake.is_dead = false
	fake.hp = 80.0
	overlay.call("_process", 0.11)
	_check(not overlay.is_low_health_shown(), "healed above 30% it clears")
	_check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the overlay never takes the mouse")

	# The HUD carries one, under its panels.
	var hud := (load("res://ui/screens/HUD.tscn") as PackedScene).instantiate()
	var danger := hud.get_node_or_null("DangerOverlay")
	_check(danger is HudDangerOverlay, "HUD.tscn has the DangerOverlay")
	if danger != null:
		_check(danger.get_index() < hud.get_node("TopLeft").get_index(), "drawn beneath the HUD panels")
	hud.free()
	SfxManager.debug_record = false
	SfxManager.debug_requests.clear()
	overlay.queue_free()
	fake.queue_free()
	await get_tree().process_frame


func _heartbeats() -> Array:
	return SfxManager.debug_requests.filter(func(r: Dictionary) -> bool: return r["id"] == &"player_heartbeat")
