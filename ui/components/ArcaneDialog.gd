class_name ArcaneDialog
extends Control
## A modal in the front-end register: a veil over the living screen, an
## ornamented panel, a Cinzel title, a line of text, an optional name field and
## two choices. Enter confirms, Escape cancels. Built in code so any screen can
## add one; `confirmed` carries the field's text (empty without a field).

signal confirmed(text: String)
signal cancelled

const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const ArcaneRuleScript := preload("res://ui/components/ArcaneRule.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

var _panel: PanelContainer
var _title: Label
var _message: Label
var _input: LineEdit
var _confirm: Button
var _cancel: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.005, 0.004, 0.003, 0.72)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	# Unpadded, so the frame's outer rule is the panel's edge (as on the
	# Settings panel); the margin keeps the title and the buttons clear of
	# the inner rule and the crown.
	_panel.theme_type_variation = &"ArcanePanel"
	_panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	_panel.add_child(ArcaneFrameScript.new())
	_title = Label.new()
	_title.theme_type_variation = &"ArcaneHeading"
	_title.add_theme_font_size_override("font_size", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var rule := ArcaneRuleScript.new() as Control
	rule.custom_minimum_size = Vector2(300, 14)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	_message = Label.new()
	_message.theme_type_variation = &"ArcaneBody"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(480, 0)
	box.add_child(_message)
	_input = LineEdit.new()
	_input.custom_minimum_size = Vector2(420, 40)
	_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.max_length = 32
	_input.text_submitted.connect(func(_text: String) -> void: _on_confirm())
	box.add_child(_input)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_cancel = Button.new()
	_cancel.name = "Cancel"
	_cancel.custom_minimum_size = Vector2(170, 44)
	_cancel.pressed.connect(cancel)
	buttons.add_child(_cancel)
	_confirm = Button.new()
	_confirm.name = "Confirm"
	_confirm.custom_minimum_size = Vector2(170, 44)
	_confirm.pressed.connect(_on_confirm)
	buttons.add_child(_confirm)
	hide()
	# Keyboard and controller focus stay inside an open dialog: Tab or a d-pad
	# press that would reach a control behind the veil is brought back.
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _on_focus_changed(control: Control) -> void:
	if not visible or control == null or is_ancestor_of(control):
		return
	_default_focus().call_deferred("grab_focus")


## Arrows and Tab stay among the dialog's own controls; the focus trap above
## is only the backstop.
func _wire_neighbours() -> void:
	var order: Array[Control] = []
	if _input.visible:
		order.append(_input)
	order.append(_cancel)
	order.append(_confirm)
	for i in range(order.size()):
		var c := order[i]
		var prev := order[(i - 1 + order.size()) % order.size()]
		var next := order[(i + 1) % order.size()]
		c.focus_next = c.get_path_to(next)
		c.focus_previous = c.get_path_to(prev)
		c.focus_neighbor_top = c.get_path_to(_input if (_input.visible and c != _input) else c)
		c.focus_neighbor_bottom = c.get_path_to(_cancel if c == _input else c)
	_cancel.focus_neighbor_left = _cancel.get_path()
	_cancel.focus_neighbor_right = _cancel.get_path_to(_confirm)
	_confirm.focus_neighbor_left = _confirm.get_path_to(_cancel)
	_confirm.focus_neighbor_right = _confirm.get_path()
	_input.focus_neighbor_left = _input.get_path()
	_input.focus_neighbor_right = _input.get_path()


func _default_focus() -> Control:
	if _input.visible:
		return _input
	return _cancel if _confirm.theme_type_variation == &"ArcaneDangerButton" else _confirm


## Shows the dialog. With `field` non-null a name field is offered,
## pre-filled with it; `danger` paints the confirm button as destructive.
func present(title: String, message: String, confirm_text: String, cancel_text: String, danger: bool = false, field: Variant = null) -> void:
	_title.text = title
	_message.text = message
	_message.visible = message != ""
	_confirm.text = confirm_text
	_cancel.text = cancel_text
	_confirm.theme_type_variation = &"ArcaneDangerButton" if danger else &""
	_input.visible = field != null
	if field != null:
		_input.text = String(field)
	_wire_neighbours()
	show()
	modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	var still := ArcaneMotion.reduced()
	_panel.scale = Vector2.ONE if still else Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.16)
	if not still:
		tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_default_focus().call_deferred("grab_focus")
	if _input.visible:
		_input.call_deferred("select_all")


func cancel() -> void:
	if not visible:
		return
	hide()
	cancelled.emit()


func _on_confirm() -> void:
	if not visible:
		return
	var text := _input.text.strip_edges() if _input.visible else ""
	if _input.visible and text == "":
		return
	hide()
	confirmed.emit(text)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
