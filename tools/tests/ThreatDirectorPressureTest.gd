extends Node

# Roadmap Phase 2.6 (power contrast) and 2.8 (Exit Rite climax): the
# ThreatDirector must (a) hold enemy scaling still for a while after the player
# crosses a power threshold, so old threats visibly crumble before the next
# arrives, and (b) push spawn and elite pressure up while the Exit Rite is
# being channelled, so the world resists departure.

const DirectorScript = preload("res://autoload/ThreatDirector.gd")

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


func _make() -> Node:
	var director := DirectorScript.new()
	director.set_process(false)
	add_child(director)
	director.call("reset_run_state")
	director.call("set_segment_phase", &"disturbance")
	return director


func _run() -> void:
	var previous_segment: int = Global.attempt_segment
	Global.attempt_segment = 2

	# --- 2.8: rite channel pressure ---
	var director := _make()
	director.call("_on_resonance_changed", 0.5)
	var calm_spawn := float(director.get("spawn_interval_mul"))
	var calm_elite := float(director.get("elite_bonus"))
	director.call("set_rite_channel_active", true)
	_check(bool(director.get("rite_channel_active")), "the director knows the rite is being channelled")
	_check(float(director.get("spawn_interval_mul")) < calm_spawn * 0.85, "channelling the rite speeds spawning (%.2f -> %.2f)" % [calm_spawn, float(director.get("spawn_interval_mul"))])
	_check(float(director.get("elite_bonus")) > calm_elite + 0.05, "and raises the elite chance (%.2f -> %.2f)" % [calm_elite, float(director.get("elite_bonus"))])
	director.call("set_rite_channel_active", false)
	_check(is_equal_approx(float(director.get("spawn_interval_mul")), calm_spawn), "leaving the rite restores spawn pacing")
	_check(is_equal_approx(float(director.get("elite_bonus")), calm_elite), "and the elite chance")
	director.queue_free()

	# --- 2.6: power-contrast lag ---
	director = _make()
	director.set("power_contrast_lag_sec", 20.0)
	director.call("_on_resonance_changed", 0.3)
	var hp_before := float(director.get("enemy_hp_mul"))
	director.call("note_power_threshold", &"three_manifestations")
	_check(bool(director.get("power_contrast_active")), "a power threshold starts the contrast window")
	director.call("_on_resonance_changed", 0.9)
	_check(is_equal_approx(float(director.get("enemy_hp_mul")), hp_before), "enemy HP scaling holds still during the window (%.3f)" % float(director.get("enemy_hp_mul")))
	_check(float(director.get("enemy_damage_mul")) <= float(director.get("_contrast_damage_mul")) + 0.0001, "enemy damage scaling holds still too")
	director.call("_process", 10.0)
	_check(bool(director.get("power_contrast_active")), "the window is still open halfway through")
	director.call("_process", 11.0)
	_check(not bool(director.get("power_contrast_active")), "the window closes after the lag")
	director.call("_on_resonance_changed", 0.91)
	_check(float(director.get("enemy_hp_mul")) > hp_before, "scaling resumes once the window closes (%.3f > %.3f)" % [float(director.get("enemy_hp_mul")), hp_before])
	_check(int(director.get("power_thresholds_crossed")) == 1, "thresholds are counted for the run sheet")
	# The same threshold never re-arms the window.
	director.call("note_power_threshold", &"three_manifestations")
	_check(not bool(director.get("power_contrast_active")), "a repeated threshold does not re-open the window")
	director.call("note_power_threshold", &"five_manifestations")
	_check(bool(director.get("power_contrast_active")), "a new threshold does")

	# The director listens for the run event, so thresholds detected by the
	# manifestation runner reach it without a direct reference.
	director.call("reset_run_state")
	director.call("set_segment_phase", &"disturbance")
	_check(RunEvents.has_signal("power_threshold_crossed"), "RunEvents carries power_threshold_crossed")
	if RunEvents.has_signal("power_threshold_crossed"):
		RunEvents.emit_signal("power_threshold_crossed", &"first_set_bonus", "Gravemarch 2/4")
		_check(bool(director.get("power_contrast_active")), "the run event opens the window")
	director.queue_free()

	Global.attempt_segment = previous_segment
	await get_tree().process_frame
	print("ThreatDirectorPressureTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
