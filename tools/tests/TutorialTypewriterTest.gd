extends SceneTree

var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var settings_manager := root.get_node("SettingsManager")
	var previous_typewriter_speed: Variant = settings_manager.get_value(&"accessibility", &"typewriter_speed", &"normal")
	settings_manager.set_value(&"accessibility", &"typewriter_speed", &"normal", false)
	var scene := load("res://ui/screens/TutorialCardOverlay.tscn") as PackedScene
	_check(scene != null, "tutorial card scene loads")
	if scene == null:
		_finish()
		return

	var overlay := scene.instantiate()
	root.add_child(overlay)
	await process_frame
	var dismissed := [false]
	overlay.dismissed.connect(func() -> void: dismissed[0] = true)
	overlay.call("present", "THE TEST", "Letters should arrive over time.", "TUTORIAL")
	await process_frame

	var body := overlay.get("_body") as Label
	var button := overlay.get("_button") as Button
	_check(
		body != null and body.visible_characters >= 0 and body.visible_characters < body.get_total_character_count(),
		"tutorial card begins with partially revealed body text"
	)
	var tutorial_characters_before_tick := body.visible_characters
	overlay.call("_process", 0.2)
	_check(
		body.visible_characters > tutorial_characters_before_tick and body.visible_characters < body.get_total_character_count(),
		"tutorial card reveals additional characters as paused time advances"
	)

	button.pressed.emit()
	await process_frame
	_check(body.visible_characters == -1, "first Continue press reveals the full tutorial text")
	_check(not bool(dismissed[0]), "first Continue press does not dismiss a revealing tutorial card")

	button.pressed.emit()
	await process_frame
	_check(bool(dismissed[0]), "second Continue press dismisses the completed tutorial card")
	overlay.queue_free()
	await process_frame

	var dossier_overlay := scene.instantiate()
	root.add_child(dossier_overlay)
	await process_frame
	var present_argument_count := 0
	for method: Dictionary in dossier_overlay.get_method_list():
		if StringName(method.get("name", &"")) == &"present":
			present_argument_count = (method.get("args", []) as Array).size()
			break
	_check(present_argument_count >= 5, "enemy dossiers can limit typewriter animation to their lore")
	if present_argument_count >= 5:
		var lore := "You cannot outrun containment."
		var dossier_body := lore + "\n\nRole: Fast interceptor\nCounter: Avoid straight lines."
		dossier_overlay.call("present", "RUNNER", dossier_body, "FIRST ENCOUNTER", null, lore.length())
		await process_frame
		var dossier_label := dossier_overlay.get("_body") as Label
		_check(
			dossier_label.visible_characters >= 0 and dossier_label.visible_characters < lore.length(),
			"enemy dossier begins by typing only its lore"
		)
		dossier_overlay.call("_process", float(lore.length()) / 58.0 + 0.01)
		_check(
			dossier_label.visible_characters == -1,
			"enemy dossier reveals all tactical details instantly when its lore finishes"
		)
	dossier_overlay.queue_free()
	await process_frame

	settings_manager.set_value(&"accessibility", &"typewriter_speed", &"instant", false)
	var instant_overlay := scene.instantiate()
	root.add_child(instant_overlay)
	await process_frame
	instant_overlay.call("present", "INSTANT", "This entire card should be readable immediately.", "ACCESSIBILITY")
	await process_frame
	var instant_body := instant_overlay.get("_body") as Label
	_check(instant_body.visible_characters == -1, "Instant accessibility setting skips timed tutorial reveal")
	instant_overlay.queue_free()
	await process_frame
	settings_manager.set_value(&"accessibility", &"typewriter_speed", &"normal", false)

	var opening_script := load("res://ui/screens/opening/OpeningPresentation.gd") as Script
	var opening: Node = opening_script.new()
	root.add_child(opening)
	await process_frame
	var advanced_count := [0]
	opening.advanced.connect(func() -> void: advanced_count[0] += 1)
	opening.call(
		"present_card",
		0,
		"ARCHIVE RECORD",
		"A NARRATIVE TEST",
		"Narrative cards should also reveal one character at a time.",
		[],
		"Continue"
	)
	await process_frame
	var opening_body := opening.get("_body") as Label
	var opening_button := opening.get("_continue_button") as Button
	_check(
		opening_body.visible_characters >= 0 and opening_body.visible_characters < opening_body.get_total_character_count(),
		"opening narrative begins with partially revealed body text"
	)
	var opening_characters_before_tick := opening_body.visible_characters
	opening.call("_process", 0.2)
	_check(
		opening_body.visible_characters > opening_characters_before_tick and opening_body.visible_characters < opening_body.get_total_character_count(),
		"opening narrative reveals additional characters as paused time advances"
	)
	opening_button.pressed.emit()
	await process_frame
	_check(opening_body.visible_characters == -1, "first opening Continue press reveals the full narrative")
	_check(int(advanced_count[0]) == 0, "first opening Continue press does not advance the narrative")
	opening_button.pressed.emit()
	await process_frame
	_check(int(advanced_count[0]) == 1, "second opening Continue press advances the narrative")

	opening.call(
		"present_card",
		1,
		"A CHOICE",
		"DECIDE",
		"Choices must wait until their context has been revealed.",
		[{"label": "Accept"}, {"label": "Refuse"}],
		"Continue"
	)
	await process_frame
	var choices := opening.get("_choices") as VBoxContainer
	_check(not choices.visible and opening_button.visible, "opening choices stay hidden while their text reveals")
	opening_button.pressed.emit()
	await process_frame
	_check(choices.visible and not opening_button.visible, "opening choices appear after the text is fully revealed")
	opening.queue_free()
	await process_frame
	settings_manager.set_value(&"accessibility", &"typewriter_speed", previous_typewriter_speed, false)
	_finish()


func _finish() -> void:
	print("TutorialTypewriterTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
