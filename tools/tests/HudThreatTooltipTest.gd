extends Node

# Run Sheet audit 2026-08-28 §4 #5 and #6: the Threat tooltip must say which
# district phase the director is in, how much elite chance it is adding, that
# the Exit Rite is being resisted while it is channelled, and - the vision's
# "these guys nearly killed me earlier" beat - that enemy scaling is being
# held after a power threshold, for how long, with a tip the moment it opens.
# Drives the real HudThreatController against the ThreatDirector autoload.
#
# Run: <godot> --headless --path . res://tools/tests/HudThreatTooltipTest.tscn

const ControllerScript = preload("res://ui/controllers/HudThreatController.gd")

var _passes := 0
var _failures := 0
var _tips: PackedStringArray = PackedStringArray()


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _on_tip(text: String, _duration: float) -> void:
	_tips.append(text)


func _run() -> void:
	var previous_segment: int = Global.attempt_segment
	var previous_lag: float = float(ThreatDirector.power_contrast_lag_sec)
	Global.attempt_segment = 2
	ThreatDirector.call("reset_run_state")
	ThreatDirector.call("set_segment_phase", &"disturbance")
	ThreatDirector.call("_on_resonance_changed", 0.5)
	ThreatDirector.set("power_contrast_lag_sec", 20.0)
	RunEvents.tutorial_tip.connect(_on_tip)

	# The row the HUD scene gives the controller, reduced to the nodes it reads.
	var hud := Control.new()
	hud.name = "Hud"
	add_child(hud)
	var value := Label.new()
	value.name = "ThreatValue"
	hud.add_child(value)
	var bar := ProgressBar.new()
	bar.name = "ThreatBar"
	hud.add_child(bar)
	var row := Control.new()
	row.name = "ThreatRow"
	hud.add_child(row)
	var controller: Node = ControllerScript.new()
	controller.name = "ThreatController"
	controller.set("value_label_path", NodePath("../ThreatValue"))
	controller.set("bar_path", NodePath("../ThreatBar"))
	controller.set("tooltip_target_path", NodePath("../ThreatRow"))
	hud.add_child(controller)

	# --- #6: phase, elite chance, rite channel ---
	var tip := String(controller.get("_tip_text"))
	_check(tip.contains("District phase: DISTURBANCE"), "the tooltip names the segment phase (%s)" % tip.replace("\n", " | "))
	_check(tip.contains("Elite chance +%d%%" % int(round(float(ThreatDirector.elite_bonus) * 100.0))), "the tooltip prints the elite chance the director is adding")
	_check(not tip.contains("Exit Rite"), "no rite line while nothing is channelled")
	_check(not tip.contains("Enemy scaling held"), "no held-scaling line before any power threshold")

	ThreatDirector.call("set_rite_channel_active", true)
	tip = String(controller.get("_tip_text"))
	_check(tip.contains("Exit Rite channelling"), "channelling the rite adds its line")
	_check(tip.contains("×%.2f" % float(ThreatDirector.rite_spawn_factor)) and tip.contains("elites +%d%%" % int(round(float(ThreatDirector.rite_elite_add) * 100.0))), "with the spawn factor and elite add the director applies")
	ThreatDirector.call("set_rite_channel_active", false)
	tip = String(controller.get("_tip_text"))
	_check(not tip.contains("Exit Rite"), "and leaving the rite removes it")

	# --- #5: the power-contrast window is announced and counted down ---
	ThreatDirector.call("note_power_threshold", &"hud_tooltip_probe", "3 Manifestations active")
	_check(_tips.size() == 1 and _tips[0].contains("3 Manifestations active"), "crossing a threshold fires a tip carrying the director's label (%s)" % [_tips])
	_check(_tips.size() == 1 and _tips[0].contains("enemy scaling held for 20s"), "and says how long scaling holds")
	tip = String(controller.get("_tip_text"))
	_check(tip.contains("Enemy scaling held — 20s"), "the tooltip shows the window while it is open (%s)" % tip.replace("\n", " | "))

	# The countdown moves while no multiplier does; the controller's own tick
	# has to notice.
	ThreatDirector.call("_process", 5.0)
	controller.call("_process", 0.016)
	tip = String(controller.get("_tip_text"))
	_check(tip.contains("Enemy scaling held — 15s"), "the held line counts down on the controller's tick (%s)" % tip.replace("\n", " | "))
	ThreatDirector.call("_process", 16.0)
	controller.call("_process", 0.016)
	tip = String(controller.get("_tip_text"))
	_check(not tip.contains("Enemy scaling held"), "and disappears once the window closes")

	# The hover path renders the same text into the ThreatTooltip scene.
	controller.call("_on_hover_entered")
	var tooltip := controller.get("_tooltip") as Control
	_check(tooltip != null and tooltip.visible, "hovering the row shows the tooltip")
	if tooltip != null:
		var label := tooltip.get_node_or_null("Margin/Label") as Label
		_check(label != null and label.text == String(controller.get("_tip_text")), "and the tooltip label carries the built text")

	# A threshold that arrives with no label still reads as words.
	ThreatDirector.call("note_power_threshold", &"five_manifestations")
	_check(_tips.size() == 2 and _tips[1].begins_with("Five Manifestations"), "an unlabelled threshold falls back to its id (%s)" % [_tips])

	RunEvents.tutorial_tip.disconnect(_on_tip)
	ThreatDirector.set("power_contrast_lag_sec", previous_lag)
	ThreatDirector.call("reset_run_state")
	Global.attempt_segment = previous_segment
	hud.queue_free()
	await get_tree().process_frame
	print("HudThreatTooltipTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
