extends SceneTree

## Breaks if follower feedback collapses back into a rounded multiline toast or
## changes the existing aggregation, copy, plurality, timing, or pointer rules.

var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var script := load("res://ui/controllers/FollowerFeedbackUI.gd") as Script
	var feedback := script.new() as CanvasLayer
	root.add_child(feedback)
	await process_frame

	feedback.call("_on_transaction", 10, 2, 12, &"combat_influence", {}, true, true)
	feedback.call("_process", 0.91)
	var panel := feedback.get_node_or_null("FollowerFeedback") as PanelContainer
	var eyebrow := feedback.get_node_or_null("FollowerFeedback/Margin/Row/Copy/Eyebrow") as Label
	var value := feedback.get_node_or_null("FollowerFeedback/Margin/Row/Copy/Value") as Label
	var body := feedback.get_node_or_null("FollowerFeedback/Margin/Row/Copy/Body") as Label
	var seal := feedback.get_node_or_null("FollowerFeedback/Margin/Row/Seal") as Label

	_check(panel != null, "follower notice creates its surface")
	_check(panel != null and panel.theme_type_variation == &"WitnessNotice", "notice uses the shared witness surface")
	_check(panel != null and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "notice remains non-blocking")
	_check(eyebrow != null and eyebrow.text == "WITNESS ACCOUNT // PATTERN FEED", "notice carries the archive classification")
	_check(value != null and value.text == "+2 FOLLOWERS", "aggregated gain has a separate signed value")
	_check(body != null and "containment line breaks" in body.text, "existing combat copy is preserved")
	_check(seal != null and seal.text == "+2", "the seal cell mirrors the signed change")

	feedback.call("_on_transaction", 12, -1, 11, &"trade", {}, true, false)
	_check(value != null and value.text == "-1 FOLLOWER", "singular negative trade uses the existing noun rule")
	_check(body != null and "Supplies and contacts secure the exchange." == body.text, "existing trade explanation is preserved")
	_check(seal != null and seal.text == "-1", "negative witness account updates its seal")

	feedback.call("_process", 3.61)
	_check(panel != null and not panel.visible, "notice retracts after the existing duration")
	feedback.queue_free()
	await process_frame
	print("FollowerFeedbackPresentationTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
