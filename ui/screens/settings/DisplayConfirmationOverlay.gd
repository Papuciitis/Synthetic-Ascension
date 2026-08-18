extends Control
class_name DisplayConfirmationOverlay

signal finished(keep: bool)

var _seconds_left := 0.0
var _countdown: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()


func _process(delta: float) -> void:
	if not visible:
		return
	_seconds_left -= delta
	_countdown.text = "Reverting in %d seconds" % maxi(0, ceili(_seconds_left))
	if _seconds_left <= 0.0:
		_finish(false)


func start(seconds: float = 12.0) -> void:
	_seconds_left = maxf(seconds, 0.01)
	show()
	_countdown.text = "Reverting in %d seconds" % ceili(_seconds_left)
	(find_child("Keep", true, false) as Button).grab_focus()


func cancel() -> void:
	_finish(false)


func _finish(keep: bool) -> void:
	if not visible:
		return
	hide()
	finished.emit(keep)


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
	panel.custom_minimum_size = Vector2(520, 220)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "KEEP DISPLAY SETTINGS?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	box.add_child(title)
	_countdown = Label.new()
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_countdown)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	for data in [["Keep", true], ["Revert", false]]:
		var button := Button.new()
		button.name = data[0]
		button.text = data[0]
		button.custom_minimum_size = Vector2(150, 44)
		button.pressed.connect(_finish.bind(data[1]))
		buttons.add_child(button)
