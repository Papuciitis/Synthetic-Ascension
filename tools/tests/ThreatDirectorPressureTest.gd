extends Node

# Roadmap Phase 2.6 (power contrast) and 2.8 (Exit Rite climax): the
# ThreatDirector must (a) hold enemy scaling still for a while after the player
# crosses a power threshold, so old threats visibly crumble before the next
# arrives, and (b) keep the exit encounter's pressure in the authored
# formations: since 2026-10-04 (plan 2026-09-17 §6.3) channelling no longer
# stacks ambient spawn speed or elite chance, and Overtime's additions clamp
# while the encounter is live.
#
# 2026-10-04 audit also pinned here: a threshold crossed outside live combat
# waits for the next disturbance phase; thresholds are remembered for the run,
# not re-armed every segment; Overtime starts after a travel grace scaled to
# the distance to the rite, ignores formation kills and kills inside the exit
# encounter, and EVAC IN counts the real grace seconds.

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
	_check(is_equal_approx(float(director.get("spawn_interval_mul")), calm_spawn), "channelling no longer stacks ambient spawn speed (%.2f -> %.2f)" % [calm_spawn, float(director.get("spawn_interval_mul"))])
	_check(is_equal_approx(float(director.get("elite_bonus")), calm_elite), "nor the elite chance (%.2f -> %.2f)" % [calm_elite, float(director.get("elite_bonus"))])
	director.call("set_rite_channel_active", false)
	_check(is_equal_approx(float(director.get("spawn_interval_mul")), calm_spawn), "leaving the rite restores spawn pacing")
	_check(is_equal_approx(float(director.get("elite_bonus")), calm_elite), "and the elite chance")
	director.queue_free()

	# --- 2.6: power-contrast lag (in live combat: a spawner exists and the
	# segment is past recon) ---
	var spawner_stub := Node.new()
	spawner_stub.add_to_group(&"enemy_spawner")
	add_child(spawner_stub)
	director = _make()
	director.set("power_contrast_lag_sec", 20.0)
	director.call("_on_resonance_changed", 0.3)
	var hp_before := float(director.get("enemy_hp_mul"))
	_check(is_zero_approx(float(director.call("power_contrast_seconds_left"))), "no window means no seconds left to show")
	director.call("note_power_threshold", &"three_manifestations")
	_check(bool(director.get("power_contrast_active")), "a power threshold starts the contrast window")
	_check(is_equal_approx(float(director.call("power_contrast_seconds_left")), 20.0), "the HUD can read the whole window at its start (%.1fs)" % float(director.call("power_contrast_seconds_left")))
	director.call("_on_resonance_changed", 0.9)
	_check(is_equal_approx(float(director.get("enemy_hp_mul")), hp_before), "enemy HP scaling holds still during the window (%.3f)" % float(director.get("enemy_hp_mul")))
	_check(float(director.get("enemy_damage_mul")) <= float(director.get("_contrast_damage_mul")) + 0.0001, "enemy damage scaling holds still too")
	director.call("_process", 10.0)
	_check(bool(director.get("power_contrast_active")), "the window is still open halfway through")
	var halfway := float(director.call("power_contrast_seconds_left"))
	_check(halfway > 0.0 and halfway < 20.0, "and the seconds left decay with it (%.1fs)" % halfway)
	director.call("_process", 11.0)
	_check(not bool(director.get("power_contrast_active")), "the window closes after the lag")
	_check(is_zero_approx(float(director.call("power_contrast_seconds_left"))), "a closed window reads 0 seconds, never a negative remainder")
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

	_run_deferred_contrast(spawner_stub)
	spawner_stub.queue_free()
	await get_tree().process_frame
	_run_overtime()

	Global.attempt_segment = previous_segment
	await get_tree().process_frame
	print("ThreatDirectorPressureTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## A threshold crossed outside live combat waits; the run remembers it.
func _run_deferred_contrast(spawner_stub: Node) -> void:
	var director := _make()
	director.set("power_contrast_lag_sec", 20.0)
	director.call("set_segment_phase", &"recon")
	director.call("note_power_threshold", &"set_six")
	_check(not bool(director.get("power_contrast_active")), "a threshold in recon does not open the window yet")
	director.call("set_segment_phase", &"disturbance")
	_check(bool(director.get("power_contrast_active")), "it opens when the disturbance phase begins")
	# A new segment closes the window but keeps the memory of the threshold.
	director.call("_on_segment_changed", 3)
	_check(not bool(director.get("power_contrast_active")), "a new segment closes the window")
	director.call("set_segment_phase", &"disturbance")
	director.call("note_power_threshold", &"set_six")
	_check(not bool(director.get("power_contrast_active")), "the same threshold does not re-open it in the next segment")
	# No spawner (the Hub): pending until combat.
	spawner_stub.remove_from_group(&"enemy_spawner")
	director.call("note_power_threshold", &"transcend_storm")
	_check(not bool(director.get("power_contrast_active")), "a threshold crossed in the Hub waits")
	spawner_stub.add_to_group(&"enemy_spawner")
	director.call("set_segment_phase", &"ascension")
	_check(bool(director.get("power_contrast_active")), "and opens at the next combat phase")
	# An attempt boundary forgets everything.
	director.call("_on_attempt_boundary", &"test")
	_check(int(director.get("power_thresholds_crossed")) == 0, "an attempt boundary clears the run's thresholds")
	director.queue_free()


func _run_overtime() -> void:
	# No rite in the scene: the grace is the minimum.
	var director := _make()
	director.call("_on_resonance_changed", 1.0)
	_check(bool(director.get("gate_unsealed")), "full resonance unseals the gate")
	director.call("_process", 3.0)
	var grace := float(director.call("balance_snapshot")["travel_grace_seconds"])
	_check(is_equal_approx(grace, float(director.get("overtime_grace_min_sec"))), "without a rite the travel grace is the minimum (%.1fs)" % grace)
	_check(is_equal_approx(float(director.get("evac_remaining_sec")), grace - 3.0), "EVAC IN counts the real grace seconds (%.1f)" % float(director.get("evac_remaining_sec")))
	director.call("_process", 50.0)
	_check(is_zero_approx(float(director.get("overtime"))), "no Overtime from time inside the grace (%.3f)" % float(director.get("overtime")))
	director.call("_process", 17.0)
	var expected := 10.0 * float(director.get("overtime_time_rate"))
	_check(absf(float(director.get("overtime")) - expected) < 0.001, "the time term runs past the grace (%.3f vs %.3f)" % [float(director.get("overtime")), expected])
	# Formation kills and kills inside the exit encounter do not count.
	var before := int(director.get("_kills_since_unseal"))
	var beat_ctx := EnemyDeathContext.new(1, &"grunt", Vector2.ZERO, 0, null, {"special_spawn_kind": &"beat"})
	director.call("_on_enemy_defeated", beat_ctx)
	_check(int(director.get("_kills_since_unseal")) == before, "a formation kill does not advance Overtime")
	var plain_ctx := EnemyDeathContext.new(2, &"grunt", Vector2.ZERO, 0, null, {})
	director.call("_on_enemy_defeated", plain_ctx)
	_check(int(director.get("_kills_since_unseal")) == before + 1, "an ambient kill does")
	director.call("set_rite_channel_active", true)
	director.call("_on_enemy_defeated", plain_ctx)
	_check(int(director.get("_kills_since_unseal")) == before + 1, "a kill inside the exit encounter does not")
	# Exit encounter: Overtime additions clamp (plan §6.3).
	director.set("_unseal_time", 2000.0)
	director.set("overtime", float(director.call("_compute_overtime")))
	director.call("_recompute", true)
	var carry := float(director.get("carry"))
	var heat := float(director.get("heat"))
	var base_dmg := 1.0 + carry * float(director.get("dmg_from_carry")) + heat * float(director.get("dmg_from_heat"))
	_check(float(director.get("enemy_damage_mul")) <= base_dmg + float(director.get("exit_ot_damage_add_cap")) + 0.001, "inside the exit encounter Overtime adds at most +%.1f damage (%.2f)" % [float(director.get("exit_ot_damage_add_cap")), float(director.get("enemy_damage_mul"))])
	director.call("set_rite_channel_active", false)
	_check(float(director.get("enemy_damage_mul")) > base_dmg + float(director.get("exit_ot_damage_add_cap")), "leaving it restores the full evaluation without resetting history")
	director.queue_free()

	# A rite 18,000 px away: grace = 18000 / 180 = 100 s.
	var rite := Node2D.new()
	rite.add_to_group(&"exit_rite")
	add_child(rite)
	var walker := Node2D.new()
	walker.add_to_group(&"player")
	walker.position = Vector2(18000.0, 0.0)
	add_child(walker)
	director = _make()
	director.call("_on_resonance_changed", 1.0)
	grace = float(director.call("balance_snapshot")["travel_grace_seconds"])
	_check(is_equal_approx(grace, 100.0), "the grace follows the walk to the rite (%.1fs)" % grace)
	walker.position = Vector2(90000.0, 0.0)
	director.call("_on_segment_changed", 2)
	director.call("_on_resonance_changed", 1.0)
	grace = float(director.call("balance_snapshot")["travel_grace_seconds"])
	_check(is_equal_approx(grace, float(director.get("overtime_grace_max_sec"))), "and is clamped to the maximum (%.1fs)" % grace)
	director.queue_free()
	rite.queue_free()
	walker.queue_free()
