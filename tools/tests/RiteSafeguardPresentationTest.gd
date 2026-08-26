extends Node

const OVERLAY_SCENE: PackedScene = preload("res://ui/overlays/EvacOverlay.tscn")
const CONTROLLER_SCRIPT: Script = preload("res://ui/controllers/HudEvacOverlayController.gd")

var _passes: int = 0
var _failures: int = 0


func _ready() -> void:
	var overlay := OVERLAY_SCENE.instantiate() as Control
	add_child(overlay)
	var controller: Node = CONTROLLER_SCRIPT.new()
	add_child(controller)
	await get_tree().process_frame
	var prompt := overlay.get_node_or_null("SafeguardPrompt") as Label
	_check(prompt != null, "evacuation overlay owns a safeguard prompt")
	if prompt != null:
		_check(not prompt.visible, "safeguard prompt starts hidden")
		controller.call("set_safeguard_prompt", true, 2)
		_check(prompt.visible, "safeguard prompt appears in context")
		_check("2" in prompt.text and "Invoke safeguard" in prompt.text, "prompt states action and count")
		controller.call("set_safeguard_prompt", false, 0)
		_check(not prompt.visible, "safeguard prompt clears outside the Rite")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _finish() -> void:
	print("RiteSafeguardPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
