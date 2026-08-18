extends Control
class_name InputCaptureOverlay

signal captured(event: InputEvent)
signal cancelled

var _family := &"keyboard_mouse"
var _armed := false
var _prompt: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()


func begin(family: StringName) -> void:
	_family = family
	_prompt.text = "Press a keyboard key or mouse button" if family == &"keyboard_mouse" else "Press a controller button or move an axis"
	show()
	_armed = false
	call_deferred("_arm")


func cancel() -> void:
	if not visible:
		return
	hide()
	_armed = false
	cancelled.emit()


func _arm() -> void:
	_armed = true


func _input(event: InputEvent) -> void:
	if not visible or not _armed:
		return
	if event.is_action_pressed(&"ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
		return
	var accepted: InputEvent = null
	if _family == &"keyboard_mouse":
		if event is InputEventKey and event.pressed and not event.echo:
			accepted = event
		elif event is InputEventMouseButton and event.pressed:
			accepted = event
	else:
		if event is InputEventJoypadButton and event.pressed:
			accepted = event
		elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.65:
			var normalized := InputEventJoypadMotion.new()
			normalized.axis = event.axis
			normalized.axis_value = -1.0 if event.axis_value < 0.0 else 1.0
			accepted = normalized
	if accepted == null:
		return
	hide()
	_armed = false
	captured.emit(accepted)
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 190)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = "ASSIGN INPUT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_prompt)
	var hint := Label.new()
	hint.text = "Esc / Controller Back — Cancel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.65)
	box.add_child(hint)
