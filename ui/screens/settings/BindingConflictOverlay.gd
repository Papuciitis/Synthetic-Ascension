extends Control
class_name BindingConflictOverlay

signal resolved(choice: StringName)

var _message: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()


func present(selected_label: String, conflicting_label: String) -> void:
	_message.text = "%s is already assigned to %s." % [selected_label, conflicting_label]
	show()
	(find_child("Replace", true, false) as Button).grab_focus()


func cancel() -> void:
	_resolve(&"cancel")


func _resolve(choice: StringName) -> void:
	hide()
	resolved.emit(choice)


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
	panel.custom_minimum_size = Vector2(570, 230)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "INPUT CONFLICT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	for data in [["Replace", &"replace"], ["Swap", &"swap"], ["Cancel", &"cancel"]]:
		var button := Button.new()
		button.name = data[0]
		button.text = data[0]
		button.custom_minimum_size = Vector2(130, 44)
		button.pressed.connect(_resolve.bind(data[1]))
		buttons.add_child(button)
