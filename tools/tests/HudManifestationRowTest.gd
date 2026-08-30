extends Node

# Observability audit 2026-08-30 §5 #11: the HUD noun row shows the fuller of
# a two-channel noun's channels - a planted Anchor Rite reads "STABILITY 100%",
# not "MOMENTUM 0%". Drives the real HudManifestationController against a
# fixture runner and a real ManifestationState.
#
# Run: <godot> --headless --path . res://tools/tests/HudManifestationRowTest.tscn

const ControllerScript = preload("res://ui/controllers/HudManifestationController.gd")


class RunnerFixture:
	extends Node

	@warning_ignore("unused_signal")
	signal manifestations_changed

	var state: Node = null
	var counts: Dictionary = {}

	func get_noun_counts() -> Dictionary:
		return counts

	func active_count() -> int:
		return 1


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
	# A player carrying a runner, the way _bind_runner looks for one.
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("player")
	add_child(player)
	var runner := RunnerFixture.new()
	runner.name = "ManifestationRunner"
	player.add_child(runner)
	var state := ManifestationState.new()
	runner.add_child(state)
	# Values are set by hand below; the state's own decay must not move them.
	state.set_process(false)
	runner.state = state

	var hud := Control.new()
	hud.name = "Hud"
	add_child(hud)
	var row := HFlowContainer.new()
	row.name = "ManifestationRow"
	hud.add_child(row)
	var controller: Node = ControllerScript.new()
	controller.name = "ManifestationController"
	controller.set("row_path", NodePath("../ManifestationRow"))
	hud.add_child(controller)

	var momentum := row.get_node("Noun_momentum") as Label
	_check(momentum != null, "the row builds one label per noun")

	# --- §5 #11: fuller channel wins ---
	runner.counts = {&"momentum": 1}
	state.momentum = 0.0
	state.stability = 1.0
	controller.call("_on_manifestations_changed")
	_check(momentum.visible, "a claimed noun shows its label")
	_check(momentum.text == "STABILITY ◆◇ 100%", "a planted Anchor Rite reads its full Stability, not an empty Momentum (%s)" % momentum.text)

	state.momentum = 0.6
	state.stability = 0.2
	controller.call("_refresh_values", false)
	_check(momentum.text == "MOMENTUM ◆◇ 60%", "the headline channel returns once it is the fuller one (%s)" % momentum.text)

	state.momentum = 0.5
	state.stability = 0.5
	controller.call("_refresh_values", false)
	_check(momentum.text == "MOMENTUM ◆◇ 50%", "the headline keeps ties (%s)" % momentum.text)

	# Same number, other channel: the key must include the channel or the label
	# keeps the wrong name.
	state.momentum = 0.0
	state.stability = 0.5
	controller.call("_refresh_values", false)
	_check(momentum.text == "STABILITY ◆◇ 50%", "swapping channel at an equal value rewrites the label (%s)" % momentum.text)

	runner.counts = {&"momentum": 2}
	controller.call("_on_manifestations_changed")
	_check(momentum.text == "STABILITY ◆◆ 50%", "the pips still count the noun's claimers (%s)" % momentum.text)

	# A single-channel noun is untouched by the rule.
	runner.counts = {&"ward": 1}
	state.time_since_hit = 3.0
	controller.call("_on_manifestations_changed")
	var ward := row.get_node("Noun_ward") as Label
	_check(not momentum.visible and ward.visible, "unclaimed nouns hide, claimed ones show")
	_check(ward.text == "WARD ◆◇ 3.0s", "a one-channel noun reads as before (%s)" % ward.text)

	hud.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("HudManifestationRowTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
