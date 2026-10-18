extends Node
## Observing a frozen objective must tell the truth without advancing its hold,
## durable ledger, rewards or encounter. The normal gameplay suites own costs.
const WARD := preload("res://scenes/world/wardstones/Wardstone.tscn")
const RITE := preload("res://scenes/world/gates/ExitRite.tscn")
var _passes := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	var saved_rules: Dictionary = Global.attempt_doctrine_rules.duplicate(true)
	var saved_hold_mul: float = Global.attempt_exit_hold_mul
	var saved_radius_mul: float = Global.attempt_wardstone_radius_mul
	Global.attempt_doctrine_rules = {}
	Global.attempt_exit_hold_mul = 1.0
	Global.attempt_wardstone_radius_mul = 1.25
	_test_wardstone()
	_test_rite()
	Global.attempt_doctrine_rules = saved_rules
	Global.attempt_exit_hold_mul = saved_hold_mul
	Global.attempt_wardstone_radius_mul = saved_radius_mul
	await get_tree().process_frame
	print("WardstoneRitePresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)


func _test_wardstone() -> void:
	var ward := WARD.instantiate() as Wardstone
	add_child(ward)
	ward.set_process(false)
	_check(is_equal_approx(ward.capture_shape.shape.radius, 56.0), "Wardstone keeps the real capture edge")
	_check(is_equal_approx(ward.stability_shape.shape.radius, 275.0), "Wardstone sanctuary reflects the attempt radius modifier")
	var ward_ground := ward.get_node_or_null("GroundDetails") as Node2D
	_check(ward_ground != null and ward_ground.z_index < -7, "Wardstone base hardware sits below actor shadows and feet")
	_check(ward.has_method("presentation_state"), "Wardstone exposes the same static identity used by its physical base")
	if ward.has_method("presentation_state"):
		_check(ward.call("presentation_state") == "dormant", "uncaptured Wardstone base is disengaged")
		ward.set("_player_inside", true)
		ward.set("_capture", 0.8)
		_check(ward.call("presentation_state") == "working", "partial Wardstone capture engages the base")
		ward.set("_player_inside", false)
		ward.call("_process", 0.0)
		_check(is_zero_approx(float(ward.get("_capture"))), "stepping out still resets Wardstone capture")
		_check(ward.call("presentation_state") == "dormant", "reset capture leaves no banked base state")
	var popups_before: int = int(BattleText.get("_count"))
	var effects_before: int = ward.vfx_root.get_child_count()
	var activation_count := [0]
	ward.activated.connect(func(_stone: Wardstone) -> void: activation_count[0] += 1)
	ward.restore_active()
	_check(ward.obelisk.get("_state") == "complete", "restore immediately engages the completed obelisk")
	if ward.has_method("presentation_state"):
		_check(ward.call("presentation_state") == "complete", "restored Wardstone prioritizes the sanctuary identity")
	_check(activation_count[0] == 0 and ward.vfx_root.get_child_count() == effects_before, "restore never repeats the activation or defensive pulse")
	_check(int(BattleText.get("_count")) == popups_before, "restore never repeats reward callouts")
	ward.queue_free()


func _test_rite() -> void:
	var rite := RITE.instantiate() as ExitRite
	add_child(rite)
	rite.set_process(false)
	_check(is_equal_approx(rite.shape.shape.radius, 168.0), "Rite channel remains the full circular siege zone")
	var rite_ground := rite.get_node_or_null("GroundDetails") as Node2D
	_check(rite_ground != null and rite_ground.z_index < -7 and rite.gate_art.z_index < 0, "Rite pad and low threshold cannot cover combat silhouettes")
	_check(rite.has_method("presentation_state"), "Rite has static locked, ready, channel, grace, drain and completed identities")
	if not rite.has_method("presentation_state"):
		rite.queue_free()
		return
	_check(rite.call("presentation_state") == "locked", "locked Rite cannot resemble a ready hold area")
	rite.set_locked(false)
	_check(rite.call("presentation_state") == "ready" and rite.gate_art.get("_state") == "ready", "unlock immediately opens the ready threshold")
	rite.set("_hold", 10.0)
	rite.set("_player_inside", true)
	_check(rite.call("presentation_state") == "working", "standing inside engages the threshold")
	rite.set("_player_inside", false)
	rite.set("_lapse", 1.5)
	_check(rite.call("presentation_state") == "grace", "the exact grace boundary still retains the channel")
	rite.set("_lapse", 1.6)
	_check(rite.call("presentation_state") == "draining", "outside beyond grace visibly releases the channel")
	rite.call("_refresh_world_art")
	_check(rite.gate_art.get("_state") == "draining", "a frozen draining channel updates its painted hardware immediately")
	rite.set("_recovery_drain_hold", 3.0)
	_check(rite.call("presentation_state") == "grace", "reconstruction protection never looks like an active drain")
	rite.set("_recovery_drain_hold", 0.0)
	rite.set("_death_taken", true)
	_check(rite.call("presentation_state") == "draining", "a past death flag cannot conceal an actual outside drain after recovery ends")
	rite.set("_death_taken", false)
	var ledger: RefCounted = rite.get("_progress_ledger")
	ledger.call("initialize_sealed", 2)
	rite.set("_hold", rite.hold_time * (2.0 / 3.0))
	_check(rite.call("presentation_state") == "ready", "a durable floor does not claim to be losing secured progress")
	rite.set("_lapse", 0.0)
	_check(rite.call("presentation_state") == "ready", "restored durable thirds do not invent a grace countdown")
	var before := rite.balance_snapshot()
	for index in range(3):
		rite.call("presentation_state")
		rite.call("_refresh_world_art")
		var _positions := rite.safeguard_pip_positions()
	_check(rite.balance_snapshot() == before, "frozen presentation observes without changing the hold, waves, seals or safeguards")
	rite.set("_safeguard_capacity", 5)
	rite.set("_safeguards", 0)
	var shields := rite.safeguard_pip_positions()
	_check(shields.size() == 5, "all five empty safeguard sockets remain visible")
	_check(shields[0].x > 0.0 and shields[4].x < 0.0 and shields[2].y > rite.radius, "safeguard shields occupy their separate near-side ledger")
	rite.set("_safeguards", 5)
	_check(rite.safeguard_pip_positions() == shields, "full safeguards keep the empty ledger geometry")
	rite.set("_completed", true)
	rite.call("_refresh_world_art")
	_check(rite.call("presentation_state") == "complete" and rite.gate_art.get("_state") == "complete", "restored completion appears without advancing the channel")
	rite.queue_free()
