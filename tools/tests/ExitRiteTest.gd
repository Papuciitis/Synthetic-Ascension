extends Node

## The Rite is the one fight the player cannot walk away from, so its failure
## behaviour has to be exactly as forgiving as it claims and no more.

const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")
const RITE_PROGRESS_LEDGER_SCRIPT: Script = preload("res://core/systems/world/rite/RiteProgressLedger.gd")

var _passes: int = 0
var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _ready() -> void:
	_test_progress_ledger()

	var rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	_check(rite != null, "the Exit Rite scene instantiates")
	if rite == null:
		_finish()
		return
	add_child(rite)
	await get_tree().process_frame

	_check(rite.hold_time >= 10.0, "the rite is a siege, not a button (%.0fs)" % rite.hold_time)
	_check(
		rite.death_progress_kept > 0.0 and rite.death_progress_kept < 1.0,
		"a death costs something but not everything (%.2f)" % rite.death_progress_kept
	)
	_check(rite.lapse_drain_rate > 0.0, "stepping out costs progress")
	_check(
		rite.lapse_drain_rate < 1.0,
		"stepping out costs LESS than standing in it gains - otherwise dodging is never worth it"
	)
	_check(rite.lapse_grace > 0.0, "a moment out of the circle is free")
	_check(
		rite.channel_regen_per_sec > 0.0 or rite.channel_regen_max_hp_pct > 0.0,
		"holding the circle mends you"
	)
	_check(rite.grant_safeguard(&"wardstone:1") == 1, "first exploration source grants one safeguard")
	_check(rite.grant_safeguard(&"wardstone:1") == 0, "duplicate exploration source grants nothing")
	rite.grant_safeguard(&"secondary:10", 2)
	rite.grant_safeguard(&"secondary:11", 2)
	_check(rite.safeguard_count() == 3, "safeguards clamp to the default capacity")

	rite.set_locked(false)
	rite.set("_hold", rite.hold_time * 0.34)
	rite.call("_update_rite_progress")
	rite.set("_hold", rite.hold_time * 0.10)
	rite.call("_apply_progress_loss", rite.get("_hold"))
	_check(is_equal_approx(float(rite.get("_hold")), rite.hold_time / 3.0), "progress loss stops at the first seal")
	rite.set("_burst_stage", 5)
	rite.call("_apply_progress_loss", rite.hold_time * 0.05)
	_check(int(rite.get("_burst_stage")) == 5, "progress loss never rewinds scripted wave history")

	var pulses: Array = ExitRite.AUTOMATIC_PULSES
	_check(pulses.size() == 3, "the Rite defines three automatic pulses")
	_check(float(pulses[0].get("heal", 0.0)) == 0.15, "first seal heals 15 percent of missing HP")
	_check(float(pulses[1].get("force", 0.0)) == 850.0, "second seal uses stronger knockback")
	_check(float(pulses[2].get("invuln", 0.0)) == 5.0, "final seal grants the admission window")
	rite.call("_apply_pulse", ExitRite.MANUAL_PULSE)
	_check(rite.get_node("Vfx").find_child("RitePulseVFX*", false, false) != null, "a Rite pulse creates readable ritual-ring feedback")

	# The stages themselves must escalate and be spread across the whole rite,
	# not stacked at the end where nothing can reach the player in time.
	var stages: Array = ExitRite.BURST_STAGES
	_check(stages.size() >= 4, "the rite has several waves (%d)" % stages.size())
	_check(float(stages[0].x) <= 0.25, "the first wave arrives early (%.2f)" % float(stages[0].x))
	for index in range(1, stages.size()):
		_check(float(stages[index].x) > float(stages[index - 1].x), "wave %d is later" % index)
		_check(float(stages[index].y) >= float(stages[index - 1].y), "wave %d is no smaller" % index)

	rite.queue_free()
	await _test_doctrine_configuration()
	_finish()


func _test_progress_ledger() -> void:
	var ledger: RefCounted = RITE_PROGRESS_LEDGER_SCRIPT.new()
	_check(ledger.call("update_fraction", 0.34) == PackedInt32Array([1]), "crossing one third seals stage 1")
	_check(is_equal_approx(float(ledger.call("clamp_loss_fraction", 0.10)), 1.0 / 3.0), "loss stops at first seal")
	_check(ledger.call("update_fraction", 0.80) == PackedInt32Array([2]), "crossing two thirds seals stage 2")
	_check(is_equal_approx(float(ledger.call("clamp_loss_fraction", 0.40)), 2.0 / 3.0), "loss stops at second seal")
	_check(bool(ledger.call("mark_wave_spent", 0)), "an unspent wave may fire")
	_check(not bool(ledger.call("mark_wave_spent", 0)), "a spent wave never re-arms")
	_check(int(ledger.call("spent_wave_count")) == 1, "wave history is monotonic")
	var initialized: RefCounted = RITE_PROGRESS_LEDGER_SCRIPT.new()
	initialized.call("initialize_sealed", 1)
	_check(is_equal_approx(float(initialized.call("floor_fraction")), 1.0 / 3.0), "an initial seal creates a floor")
	_check(initialized.call("update_fraction", 1.0 / 3.0) == PackedInt32Array(), "initial seals do not replay")


func _test_doctrine_configuration() -> void:
	var saved_rules: Dictionary = Global.attempt_doctrine_rules.duplicate(true)
	var saved_hold_mul: float = Global.attempt_exit_hold_mul
	Global.attempt_doctrine_rules = {
		"rite_initial_seals": 1,
		"rite_burst_count_mul": 1.5,
		"rite_safeguard_capacity": 5,
		"rite_safeguard_source_multiplier": 2,
		"rite_stun_bonus_seconds": 0.1,
	}
	Global.attempt_exit_hold_mul = 1.0
	var rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	add_child(rite)
	await get_tree().process_frame
	_check(rite.safeguard_capacity() == 5, "Pilgrim Engine raises Rite safeguard capacity")
	_check(rite.has_method("safeguard_pip_positions"), "Rite exposes independent safeguard geometry")
	if rite.has_method("safeguard_pip_positions"):
		_check((rite.call("safeguard_pip_positions") as PackedVector2Array).size() == 5, "Pilgrim Engine renders all five safeguard pips")
	_check(rite.grant_safeguard(&"wardstone:test") == 2, "Pilgrim Engine doubles source charges")
	_check(is_equal_approx(float(rite.get("_hold")), rite.hold_time / 3.0), "Law of Admission begins at one sealed third")
	_check(int(rite.get("_burst_stage")) == 2, "Law archives burst stages below the initial seal")
	_check(int(rite.call("_burst_spawn_count", 3)) == 5, "Law rounds enlarged burst counts up")
	var profile: Dictionary = rite.call("_automatic_pulse_profile", 0)
	_check(is_equal_approx(float(profile.get("stun", 0.0)), 0.25), "Vessel adds stun to automatic seal pulses")
	rite.queue_free()
	Global.attempt_doctrine_rules = saved_rules
	Global.attempt_exit_hold_mul = saved_hold_mul


func _finish() -> void:
	print("ExitRiteTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
