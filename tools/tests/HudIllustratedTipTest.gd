extends Node

# Exercises the real tip queue, its ordinary two-argument signal, and the
# opt-in illustrated signal. It catches badges surviving onto unrelated
# tutorials and the row forcing long tips outside a narrow HUD.
const GATE_OVERLAY := preload("res://ui/overlays/GateOverlay.tscn")
const TIP_CONTROLLER := preload("res://ui/controllers/HudTutorialTipController.gd")
const HUD_THEME := preload("res://ui/theme/SyntheticHudTheme.tres")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	Global.debug_disable_autosave = true
	var overlay := GATE_OVERLAY.instantiate() as Control
	overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay.size = Vector2(800.0, 600.0)
	add_child(overlay)
	var panel := overlay.get_node("TutorialTip") as PanelContainer
	var label := panel.find_child("Label", true, false) as Label
	_check(label.get_theme_font(&"font") == HUD_THEME.get_font(&"font", &"HudCaption"), "top-centre alerts share the HUD's Cinzel caption face")
	var controller := TIP_CONTROLLER.new()
	controller.tutorial_panel_path = NodePath("../TutorialTip")
	controller.tutorial_label_path = NodePath("../TutorialTip/" + String(panel.get_path_to(label)))
	overlay.add_child(controller)
	controller.set("_running", true) # Hold the real queue until each entry is inspected.
	var illustrated := RunEvents.has_signal(&"illustrated_tutorial_tip")
	_check(illustrated, "illustrated tutorial events carry explicit modifier IDs alongside the existing tip channel")
	if illustrated:
		var ids: Array[StringName] = [&"vampiric"]
		RunEvents.emit_signal(&"illustrated_tutorial_tip", "VAMPIRIC - feeds on the enemies around it; cut it off from the pack", 4.0, ids)
		RunEvents.tutorial_tip.emit("Ordinary guidance follows", 2.0)
		var queue: Array = controller.get("_queue")
		_check(queue.size() == 2 and queue[0].get("icons", []) == [&"vampiric"] and queue[1].get("icons", []).is_empty(), "both signal types queue in order with separate icon metadata")
		controller.call("_show_now", queue[0].text, queue[0].icons)
		await get_tree().process_frame
		var icons := panel.find_child("StatusIcons", true, false) as HBoxContainer
		_check(icons != null and icons.visible and icons.get_child_count() == 1 and (icons.get_child(0) as TextureRect).texture != null, "illustrated tips display their real generated badge beside the text")
		_check(label.size.x < panel.size.x - 60.0 and label.get_line_count() > 1, "the badge leaves wrapping space for long guidance in a small HUD")
		controller.call("_show_now", "Ordinary guidance follows")
		_check(not icons.visible, "ordinary tips clear the previous modifier badges")
		var unknown_ids: Array[StringName] = [&"not_a_status"]
		controller.call("_show_now", "Unknown status stays readable", unknown_ids)
		_check(not icons.visible and label.text == "Unknown status stays readable", "unknown icon IDs leave a full-width readable tip")
	controller.queue_free()
	overlay.queue_free()
	await get_tree().process_frame
	print("HudIllustratedTipTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
