extends Node

## Performance hygiene audit (2026-08-28) §2 #5, #8, #10 and the below-the-cut
## MagicMissile row.
##
## These are the pollers: HUD widgets and effect runners that re-asked a
## question every frame and got the same answer. Each one keeps exactly the
## readout it had; what is pinned here is that it stops re-asserting a settled
## one, and that it still wakes on every input that can change it.

const BADGE_SCENE: PackedScene = preload("res://ui/widgets/AugmentActiveBadge.tscn")
const ABILITY_HUD_SCENE: PackedScene = preload("res://ui/widgets/ActiveAbilityHUD.tscn")
const ABILITY_HUD_SCRIPT: Script = preload("res://ui/widgets/ActiveAbilityHUD.gd")
const EVAC_OVERLAY_SCENE: PackedScene = preload("res://ui/overlays/EvacOverlay.tscn")
const GATE_CONTROLLER_SCRIPT: Script = preload("res://ui/controllers/HudGateOverlayController.gd")
const EVAC_CONTROLLER_SCRIPT: Script = preload("res://ui/controllers/HudEvacOverlayController.gd")
const CHECKLIST_CONTROLLER_SCRIPT: Script = preload("res://ui/controllers/HudGateChecklistController.gd")
const MISSILE_SCRIPT: Script = preload("res://effects/augments/logic/MagicMissileEffect.gd")


class FakeDirector:
	extends Node
	var gate_unsealed: bool = false
	var evac_pressure: float = 0.0
	var evac_remaining_sec: float = 0.0


class FakeAbility:
	extends Node
	signal active_cd_changed(time_left: float, max_cd: float)
	signal active_failed(message: String)

	var hud_key_text: String = "R"
	var hud_title_text: String = "Fixture Rite"
	var hud_priority: int = 5
	var state: Dictionary = {
		"ready": true,
		"cooldown_left": 0.0,
		"cooldown_max": 6.0,
		"status_text": "READY",
		"combat_text": "",
	}

	func get_active_state() -> Dictionary:
		return state


class CountingMissile:
	extends MagicMissileEffect
	var scans: int = 0

	func _find_nearest_enemy(_center: Vector2, _radius: float) -> int:
		scans += 1
		return EnemyWorldTypes.INVALID_HANDLE


class ProbePlayer:
	extends Node2D
	pass


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


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _run() -> void:
	await _test_augment_badge()
	await _test_active_ability_hud()
	await _test_gate_arrow_sleeps()
	await _test_evac_overlay()
	await _test_checklist_prompt()
	await _test_magic_missile_seek()

	print("IdlePollGateTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# §2 #5: the augment cooldown badges
# ---------------------------------------------------------------------------

func _test_augment_badge() -> void:
	var badge := BADGE_SCENE.instantiate() as AugmentActiveBadge
	add_child(badge)
	await _frames(2)

	_check(badge.has_method("debug_blend_paint_count"), "the badge counts its ready-blend repaints")
	if not badge.has_method("debug_blend_paint_count"):
		badge.queue_free()
		return

	var paints := func() -> int: return int(badge.call("debug_blend_paint_count"))

	# Settled ready, nothing on cooldown: the state every badge is in for most
	# of a run.
	badge.set("_target_ready", true)
	badge.set("_ready_blend", 1.0)
	await _frames(3)
	var settled: int = paints.call()
	await _frames(20)
	_check(
		paints.call() == settled,
		"a settled badge writes no border colour for twenty frames (%d repaints)" % [paints.call() - settled]
	)

	# Going on cooldown has to move it again, and it has to stop again when the
	# blend lands.
	badge.set("_target_ready", false)
	await _frames(2)
	_check(paints.call() > settled, "starting a cooldown repaints the badge (%d)" % [paints.call() - settled])
	var blend: float = float(badge.get("_ready_blend"))
	var guard := 0
	while blend > 0.0 and guard < 600:
		await get_tree().process_frame
		blend = float(badge.get("_ready_blend"))
		guard += 1
	_check(blend == 0.0, "the blend reaches the cooldown end (%f)" % blend)
	var landed: int = paints.call()
	await _frames(20)
	_check(
		paints.call() == landed,
		"and settles there without further repaints (%d)" % [paints.call() - landed]
	)

	# _set_ready_visual writes the same three properties the blend owns, so the
	# blend must re-assert itself once afterwards exactly as it always did.
	badge.call("_set_ready_visual", true)
	await _frames(2)
	_check(paints.call() > landed, "a direct ready-visual write is re-asserted by the blend (%d)" % [paints.call() - landed])

	badge.queue_free()
	await _frames(1)


# ---------------------------------------------------------------------------
# §2 #8: the set-ability HUD
# ---------------------------------------------------------------------------

func _test_active_ability_hud() -> void:
	var hud := ABILITY_HUD_SCENE.instantiate() as ActiveAbilityHUD
	add_child(hud)
	await _frames(2)

	_check(hud.has_method("debug_poll_count"), "the ability HUD counts its state polls")
	if not hud.has_method("debug_poll_count"):
		hud.queue_free()
		return

	var polls := func() -> int: return int(hud.call("debug_poll_count"))
	# Read from the script so this suite still parses against a tree without the
	# constant - the check has to fail, not refuse to load.
	var interval: float = float(
		ABILITY_HUD_SCRIPT.get_script_constant_map().get("POLL_INTERVAL", 0.1)
	)

	var effect := FakeAbility.new()
	hud.call("_bind", effect)
	add_child(effect)

	var before: int = polls.call()
	var started := Time.get_ticks_msec()
	await _frames(30)
	var elapsed := Time.get_ticks_msec() - started
	var ceiling := int(elapsed / (interval * 1000.0)) + 2
	_check(
		polls.call() - before <= ceiling,
		"thirty frames poll the bound effect at 10 Hz, not per frame (%d polls in %d ms)"
			% [polls.call() - before, elapsed]
	)

	# The readout is still immediate, because the effect pushes it.
	effect.state = {
		"ready": false,
		"cooldown_left": 4.0,
		"cooldown_max": 6.0,
		"status_text": "4.0",
		"combat_text": "",
	}
	effect.active_cd_changed.emit(4.0, 6.0)
	_check(
		hud.time_label.text == "4.0",
		"a cooldown reported by the effect reaches the label without waiting for a poll (%s)" % hud.time_label.text
	)

	hud.call("_unbind")
	effect.queue_free()
	hud.queue_free()
	await _frames(1)


# ---------------------------------------------------------------------------
# §2 #10: the gate arrow sleeps while there is nothing to point at
# ---------------------------------------------------------------------------

func _test_gate_arrow_sleeps() -> void:
	var saved_objective: Vector2 = Global.objective_target_pos
	var saved_gate: Vector2 = Global.exit_gate_pos

	_check(
		Global.has_signal("hud_target_positions_changed"),
		"Global announces a change to the two positions the arrow points at"
	)

	var host := Control.new()
	host.name = "ArrowHost"
	add_child(host)
	var arrow := Control.new()
	arrow.name = "GateArrow"
	arrow.size = Vector2(24.0, 24.0)
	host.add_child(arrow)

	Global.objective_target_pos = Vector2.INF
	Global.exit_gate_pos = Vector2.INF

	var controller: Node = GATE_CONTROLLER_SCRIPT.new()
	controller.name = "GateController"
	controller.set("gate_arrow_path", NodePath("../GateArrow"))
	host.add_child(controller)
	await _frames(2)

	_check(not controller.is_processing(), "with neither target set the arrow controller sleeps")
	_check(not arrow.visible, "and the arrow is hidden while it sleeps")

	Global.objective_target_pos = Vector2(400.0, 0.0)
	_check(controller.is_processing(), "an objective position wakes it at once")

	Global.objective_target_pos = Vector2.INF
	_check(not controller.is_processing(), "clearing it puts it back to sleep")

	Global.exit_gate_pos = Vector2(900.0, 120.0)
	_check(controller.is_processing(), "a revealed exit gate wakes it too")

	# The Exit Rite rewrites its own position every frame; only a move counts.
	if Global.has_signal("hud_target_positions_changed"):
		var emits := {&"count": 0}
		Global.hud_target_positions_changed.connect(
			func() -> void: emits[&"count"] = int(emits[&"count"]) + 1
		)
		for _frame in range(10):
			Global.exit_gate_pos = Vector2(900.0, 120.0)
		_check(int(emits[&"count"]) == 0, "re-writing the same position announces nothing (%d)" % emits[&"count"])
		Global.exit_gate_pos = Vector2(901.0, 120.0)
		_check(int(emits[&"count"]) == 1, "moving it announces once (%d)" % emits[&"count"])

	Global.exit_gate_pos = Vector2.INF
	_check(not controller.is_processing(), "clearing both sleeps it again")

	host.queue_free()
	await _frames(1)
	Global.objective_target_pos = saved_objective
	Global.exit_gate_pos = saved_gate


# ---------------------------------------------------------------------------
# §2 #10 and logging §3 #4: the evac overlay
# ---------------------------------------------------------------------------

func _test_evac_overlay() -> void:
	var overlay := EVAC_OVERLAY_SCENE.instantiate() as Control
	overlay.name = "EvacOverlay"
	add_child(overlay)
	var controller: Node = EVAC_CONTROLLER_SCRIPT.new()
	controller.name = "EvacController"
	add_child(controller)
	await _frames(2)

	var director := FakeDirector.new()
	add_child(director)
	controller.set("_td", director)

	var label := overlay.get_node_or_null("EvacWarning") as Label
	_check(label != null, "the evac overlay owns its warning label")
	if label == null:
		overlay.queue_free()
		controller.queue_free()
		return

	# Sealed gate: the director pins pressure and remaining to zero, so every
	# value the controller writes is a constant.
	director.gate_unsealed = false
	controller.call("_process", 0.016)
	label.modulate.a = 0.42
	label.text = "SENTINEL"
	for _frame in range(20):
		controller.call("_process", 0.016)
	_check(
		is_equal_approx(label.modulate.a, 0.42) and label.text == "SENTINEL",
		"a sealed gate leaves the settled evac label alone (a=%f, %s)" % [label.modulate.a, label.text]
	)

	# Unsealing is a change, so it repaints.
	director.gate_unsealed = true
	director.evac_pressure = 0.3
	director.evac_remaining_sec = 30.0
	controller.call("_process", 0.016)
	_check(
		label.text.begins_with("GATE UNSEALED"),
		"unsealing the gate repaints the warning (%s)" % label.text
	)

	# ...and inside the blink window it keeps animating. The blink reads the wall
	# clock, so this has to run on real frames rather than back-to-back calls.
	director.evac_remaining_sec = 4.0
	await _frames(2)
	var blink_a: float = label.modulate.a
	var moved := false
	for _frame in range(30):
		await get_tree().process_frame
		if not is_equal_approx(label.modulate.a, blink_a):
			moved = true
	_check(moved, "the final seconds still blink (%f then %f)" % [blink_a, label.modulate.a])

	# (The missing-director warning is pinned where the two controllers live:
	# RiteSafeguardPresentationTest and HudThreatTooltipTest.)

	director.queue_free()
	overlay.queue_free()
	controller.queue_free()
	await _frames(1)


# ---------------------------------------------------------------------------
# §2 #10: the checklist's inspect prompt
# ---------------------------------------------------------------------------

func _test_checklist_prompt() -> void:
	var controller: Node = CHECKLIST_CONTROLLER_SCRIPT.new()
	add_child(controller)
	await _frames(1)

	_check(
		controller.has_method("_details_keycode"),
		"the checklist reads its binding as a keycode, without building a string"
	)
	if not controller.has_method("_details_keycode"):
		controller.queue_free()
		return

	var saved_events := InputMap.action_get_events(&"hud_details")
	var remapped := InputEventKey.new()
	remapped.physical_keycode = KEY_J
	InputMap.action_erase_events(&"hud_details")
	InputMap.action_add_event(&"hud_details", remapped)
	_check(int(controller.call("_details_keycode")) == KEY_J, "the keycode follows the binding")
	_check(String(controller.call("_details_prompt")) == "J", "and renders as the same prompt the header shows")
	InputMap.action_erase_events(&"hud_details")
	_check(int(controller.call("_details_keycode")) == 0, "an unbound action reads as no key")
	_check(String(controller.call("_details_prompt")) == "HOLD", "and prints HOLD")
	for saved_event in saved_events:
		InputMap.action_add_event(&"hud_details", saved_event)

	controller.queue_free()
	await _frames(1)


# ---------------------------------------------------------------------------
# Below the cut: Magic Missile's empty-radius scan
# ---------------------------------------------------------------------------

func _test_magic_missile_seek() -> void:
	var player := ProbePlayer.new()
	add_child(player)
	var effect := CountingMissile.new()
	effect.missile_scene = PackedScene.new()
	add_child(effect)
	effect.call("setup", player)
	effect.set_process(false)

	var retry: float = float(MISSILE_SCRIPT.get_script_constant_map().get("SEEK_RETRY_SEC", 0.1))
	_check(retry > 0.0, "the augment names a retry interval for a scan that found nothing")

	var step := 0.016
	var steps := 30
	for _frame in range(steps):
		effect.call("_process", step)
	var expected := int(float(steps) * step / retry) + 2
	_check(
		effect.scans > 0 and effect.scans <= expected,
		"thirty empty frames scan a handful of times, not thirty (%d scans, ceiling %d)"
			% [effect.scans, expected]
	)

	# A target that walks in is still picked up on the next scan.
	effect.scans = 0
	for _frame in range(int(ceil(retry / step)) + 2):
		effect.call("_process", step)
	_check(effect.scans > 0, "the scan keeps retrying while nothing is in range (%d)" % effect.scans)

	effect.queue_free()
	player.queue_free()
	await _frames(1)
