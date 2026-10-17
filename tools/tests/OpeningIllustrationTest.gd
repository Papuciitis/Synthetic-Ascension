extends Node
## Actual presentation boundary: stale art, offscreen choices, reveal input
## reaching pause, and dialogue accidentally disabled in an intentionally paused hub.
const SCREEN := preload("res://ui/screens/opening/OpeningPresentation.tscn")
var _passes := 0
var _failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _settle() -> void:
	for i in range(5):
		await get_tree().process_frame

func _run() -> void:
	SaveManager.current_save = null
	Global.debug_disable_autosave = true
	var previous_speed: Variant = SettingsManager.get_value(&"accessibility", &"typewriter_speed", &"normal")
	var previous_motion: Variant = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	SettingsManager.set_value(&"accessibility", &"typewriter_speed", &"instant", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	var view := SubViewport.new()
	view.size = Vector2i(640, 480)
	add_child(view)
	var screen := SCREEN.instantiate()
	view.add_child(screen)
	_check(screen.has_method("show_illustration") and screen.has_method("clear_illustration"), "story cards can select and release optional illustrations")
	if not screen.has_method("show_illustration"):
		view.free()
		_finish(previous_speed, previous_motion)
		return
	for id: StringName in [&"city", &"admission", &"synthesis", &"records"]:
		_check(bool(screen.call("show_illustration", id)), "%s illustration is usable" % id)
	await screen.call("clear_illustration", 0.0)
	_check(bool(screen.call("show_illustration", &"city")), "city image can be shown again after cleanup")
	var image := screen.get("_illustration") as TextureRect
	var first_texture := image.texture
	screen.call("show_prompt", "Follow the gold trail")
	screen.call("present_card", 0, "", "A PROHIBITED EXPERIMENT", "Magic may be inherited.\nMagic may be granted.\nMagic may be borrowed.\nIt may not be manufactured.\n\nOn this night, Mara intended to prove otherwise.", [], "Begin")
	await _settle()
	_check(not (screen.get("_prompt") as Label).visible, "blocking story card hides the world guidance prompt")
	var panel := screen.get("_panel") as Control
	_check(panel.get_global_rect().position.x >= 0 and panel.get_global_rect().end.x <= 640.5 and panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= 480.5, "historical card fits a 640 by 480 viewport without shrinking text")
	screen.call("advance")
	screen.call("present_card", 1, "BREN", "LATTICE SPECIALIST", "A second card shares the still.", [], "Continue")
	await _settle()
	_check(image.visible and image.texture == first_texture, "consecutive cards retain their illustration without reloading")
	screen.call("advance")
	screen.call("clear_illustration", 0.1)
	screen.call("show_illustration", &"city")
	await get_tree().create_timer(0.15, true, false, true).timeout
	_check(image.visible and image.texture != null and image.modulate.a > 0.9 and is_equal_approx(float((image.material as ShaderMaterial).get_shader_parameter(&"reveal")), 1.0), "showing the same still supersedes a pending clear")
	screen.call("clear_illustration", 0.1)
	screen.call("show_illustration", &"admission")
	await get_tree().create_timer(0.15, true, false, true).timeout
	_check(image.visible and image.texture != null, "an old clear cannot remove a different newly selected still")
	await screen.call("clear_illustration", 0.0)
	_check(not image.visible and image.texture == null, "clearing a story group releases art before world play resumes")
	_check(not bool(screen.call("show_illustration", &"missing_optional_art")), "unknown art quietly falls back to text")
	screen.call("present_card", 1, "BREN", "A CHOICE", "Read this before choosing.\n".repeat(15), [{"label": "Analytical"}, {"label": "Decisive"}, {"label": "Protective"}, {"label": "Remain silent"}], "Continue")
	await _settle()
	var scroll := screen.get("_scroll") as ScrollContainer
	var choices := screen.get("_choices") as VBoxContainer
	_check(not image.visible and (screen.get("_body") as Label).text.begins_with("Read this"), "missing image preserves usable dialogue")
	_check(panel.get_global_rect().end.y <= 480.5 and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "long choice card scrolls inside the small viewport")
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	view.push_input(down, true)
	down.pressed = false
	view.push_input(down, true)
	await _settle()
	_check(scroll.has_focus() and scroll.scroll_vertical > 0 and scroll.scroll_vertical < scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page, "Down reads the next part of a long card without jumping to its choices")
	var up := InputEventKey.new()
	up.keycode = KEY_UP
	up.pressed = true
	view.push_input(up, true)
	up.pressed = false
	view.push_input(up, true)
	await _settle()
	_check(scroll.has_focus() and scroll.scroll_vertical == 0, "Up returns to the beginning while keeping reading focus")
	var last_choice := choices.get_child(3) as Button
	last_choice.grab_focus()
	await _settle()
	_check(last_choice.get_global_rect().position.y >= panel.get_global_rect().position.y and last_choice.get_global_rect().end.y <= panel.get_global_rect().end.y, "focusing the fourth response brings it fully into view")
	last_choice.pressed.emit()
	await _settle()
	SettingsManager.set_value(&"accessibility", &"typewriter_speed", &"slow", false)
	screen.call("present_card", 1, "BREN", "TEST", "This line should reveal before it can be dismissed.", [], "Continue")
	var advanced := [0]
	screen.advanced.connect(func() -> void: advanced[0] += 1)
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	view.push_input(accept, true)
	_check((screen.get("_body") as Label).visible_characters == -1 and advanced[0] == 0, "first confirmation reveals without advancing")
	_check(view.is_input_handled(), "opening reveal consumes its confirmation input")
	var pause := (load("res://ui/screens/PauseMenu.tscn") as PackedScene).instantiate()
	view.add_child(pause)
	pause.call("open")
	await _settle()
	screen.call("advance")
	_check(advanced[0] == 0, "an open shared pause menu prevents underlying story advancement")
	pause.call("resume")
	pause.free()
	get_tree().paused = true
	screen.call("advance")
	_check(advanced[0] == 1, "intentionally paused hub dialogue still advances without a pause menu")
	get_tree().paused = false
	view.free()
	await _test_transitions()
	_finish(previous_speed, previous_motion)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## The painted transitions, with motion on: a still paints in over the world,
## the next paints over it (the first stays beneath until covered), clearing
## washes out the way it came, and a slow push-in runs only with motion.
func _test_transitions() -> void:
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(960, 540)
	add_child(view)
	var screen := SCREEN.instantiate()
	view.add_child(screen)
	await _settle()
	var front := screen.get("_illustration") as TextureRect
	var back := screen.get("_illustration_back") as TextureRect
	var reveal := func(layer: TextureRect) -> float: return float((layer.material as ShaderMaterial).get_shader_parameter(&"reveal"))
	_check(front.material is ShaderMaterial and back.material is ShaderMaterial, "both still layers paint through the stroke shader")
	_check((front.material as ShaderMaterial).get_shader_parameter(&"strokes") == null, "the stroke pattern is not made until a still is shown")
	screen.call("show_illustration", &"city")
	_check((front.material as ShaderMaterial).get_shader_parameter(&"strokes") != null and (front.material as ShaderMaterial).get_shader_parameter(&"strokes") == (back.material as ShaderMaterial).get_shader_parameter(&"strokes"), "then both layers paint with it")
	_check(is_zero_approx(reveal.call(front)), "a new still starts unpainted")
	await _wait(OpeningPresentation.STILL_REVEAL * 0.5)
	var midway: float = reveal.call(front)
	_check(midway > 0.1 and midway < 0.9, "and paints in over time (%.2f halfway)" % midway)
	await _wait(OpeningPresentation.STILL_REVEAL * 0.6 + 0.05)
	_check(is_equal_approx(reveal.call(front), 1.0) and not back.visible, "until the plain painting shows")
	var city_texture := front.texture
	screen.call("show_illustration", &"admission")
	_check(back.visible and back.texture == city_texture and is_equal_approx(reveal.call(back), 1.0) and is_zero_approx(reveal.call(front)), "the next still paints over the previous one, which stays beneath as it was")
	await _wait(OpeningPresentation.STILL_CROSSFADE * 0.5)
	var crossing: float = reveal.call(front)
	_check(back.visible and crossing > 0.1 and crossing < 0.9, "both show mid-crossfade, never a dip to the world (%.2f)" % crossing)
	await _wait(OpeningPresentation.STILL_CROSSFADE * 0.6 + 0.05)
	_check(not back.visible and back.texture == null and is_equal_approx(reveal.call(front), 1.0), "once covered, the previous still is released")
	_check(front.scale.x > 1.0 and front.scale.x < OpeningPresentation.STILL_DRIFT_SCALE, "the still drifts in slowly while it is read (scale %.4f)" % front.scale.x)
	# Reduced Motion turned on while a still is read stops its push-in there.
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	var held := front.scale.x
	await _wait(0.3)
	_check(is_equal_approx(front.scale.x, held), "turning Reduced Motion on stops the push-in where it is")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	# A third still mid-crossfade: the fully painted still stays underneath,
	# never the half-painted one, so the world cannot show through.
	var admission_texture := front.texture
	screen.call("show_illustration", &"synthesis")
	await _wait(0.2)
	screen.call("show_illustration", &"records")
	_check(back.visible and back.texture == admission_texture and is_equal_approx(reveal.call(back), 1.0) and is_zero_approx(reveal.call(front)), "a third still mid-crossfade keeps the painted still beneath, not the half-painted one")
	await _wait(OpeningPresentation.STILL_CROSSFADE + 0.1)
	_check(not back.visible and is_equal_approx(reveal.call(front), 1.0), "and the third still paints over it as usual")
	var clear_done := [false]
	var clearing := func() -> void:
		await screen.call("clear_illustration")
		clear_done[0] = true
	clearing.call()
	await _wait(OpeningPresentation.STILL_CLEAR * 0.5)
	var washing: float = reveal.call(front)
	_check(not clear_done[0] and washing > 0.05 and washing < 0.95, "clearing washes the painting out over time while the caller waits (%.2f)" % washing)
	await _wait(OpeningPresentation.STILL_CLEAR * 0.6 + 0.05)
	_check(clear_done[0] and not front.visible and front.texture == null and is_equal_approx(front.scale.x, 1.0), "then releases it, unscaled, before world play resumes")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	screen.call("show_illustration", &"synthesis")
	await _settle()
	_check(is_equal_approx(reveal.call(front), 1.0) and is_equal_approx(front.scale.x, 1.0), "Reduced Motion: the still is simply there, with no push-in")
	await screen.call("clear_illustration")
	_check(not front.visible and front.texture == null, "and leaves at once")
	view.free()

func _finish(previous_speed: Variant, previous_motion: Variant) -> void:
	SettingsManager.set_value(&"accessibility", &"typewriter_speed", previous_speed, false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", previous_motion, false)
	get_tree().paused = false
	print("OpeningIllustrationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
