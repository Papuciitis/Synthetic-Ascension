extends Control
class_name SettingsScreen

signal closed

const BindingRowScene := preload("res://ui/screens/settings/BindingRow.tscn")
const CaptureScene := preload("res://ui/screens/settings/InputCaptureOverlay.tscn")
const ConflictScene := preload("res://ui/screens/settings/BindingConflictOverlay.tscn")
const DisplayConfirmScene := preload("res://ui/screens/settings/DisplayConfirmationOverlay.tscn")

const ACCENT := Color(1.0, 0.55, 0.2, 0.95)
const SECTIONS: Array[StringName] = [&"audio", &"video", &"controls", &"accessibility"]

var _settings_source: Node
var _active_section := &"audio"
var _content: VBoxContainer
var _scroll: ScrollContainer
var _tabs: Dictionary = {}
var _capture: Control
var _conflict: Control
var _display_confirm: Control
var _reset_confirm: ConfirmationDialog
var _pending_binding: Dictionary = {}
var _mode_option: OptionButton
var _resolution_option: OptionButton


func configure(settings_source: Node) -> void:
	_settings_source = settings_source


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _settings_source == null:
		_settings_source = SettingsManager
	_build_ui()
	_set_section(&"audio")
	hide()


func open() -> void:
	show()
	refresh_from_manager()
	var tab := _tabs.get(_active_section) as Button
	if tab != null:
		tab.call_deferred("grab_focus")


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func refresh_from_manager() -> void:
	_set_section(_active_section)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	if _capture.visible:
		_capture.call("cancel")
	elif _conflict.visible:
		_conflict.call("cancel")
	elif _display_confirm.visible:
		_display_confirm.call("cancel")
	elif _reset_confirm.visible:
		_reset_confirm.hide()
	else:
		close()
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.005, 0.005, 0.008, 0.96)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 730)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.035, 0.047, 0.99)
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	layout.add_child(title)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = ACCENT
	layout.add_child(rule)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	layout.add_child(body)
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size = Vector2(200, 0)
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	for section in SECTIONS:
		var tab := Button.new()
		tab.name = "%sTab" % String(section).capitalize().replace(" ", "")
		tab.text = String(section).to_upper()
		tab.custom_minimum_size = Vector2(190, 48)
		tab.pressed.connect(_set_section.bind(section))
		tabs.add_child(tab)
		_tabs[section] = tab

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	_scroll.add_child(_content)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)
	layout.add_child(footer)
	var reset := Button.new()
	reset.name = "ResetTab"
	reset.text = "Reset Tab"
	reset.custom_minimum_size = Vector2(150, 44)
	reset.pressed.connect(_request_reset)
	footer.add_child(reset)
	var back := Button.new()
	back.name = "Back"
	back.text = "Back"
	back.custom_minimum_size = Vector2(150, 44)
	back.pressed.connect(close)
	footer.add_child(back)

	_reset_confirm = ConfirmationDialog.new()
	_reset_confirm.title = "Reset Settings"
	_reset_confirm.dialog_text = "Restore defaults for this tab?"
	_reset_confirm.confirmed.connect(_confirm_reset)
	add_child(_reset_confirm)
	_capture = CaptureScene.instantiate() as Control
	_capture.connect("captured", _on_input_captured)
	_capture.connect("cancelled", func() -> void: _pending_binding.clear())
	add_child(_capture)
	_conflict = ConflictScene.instantiate() as Control
	_conflict.connect("resolved", _on_conflict_resolved)
	add_child(_conflict)
	_display_confirm = DisplayConfirmScene.instantiate() as Control
	_display_confirm.connect("finished", _on_display_confirmation)
	add_child(_display_confirm)


func _set_section(section: StringName) -> void:
	if section not in SECTIONS or _content == null:
		return
	_active_section = section
	for key in _tabs:
		(_tabs[key] as Button).button_pressed = key == section
	for child in _content.get_children():
		child.free()
	match section:
		&"audio": _build_audio()
		&"video": _build_video()
		&"controls": _build_controls()
		&"accessibility": _build_accessibility()
	_scroll.scroll_vertical = 0


func _build_audio() -> void:
	_add_heading("AUDIO")
	for data in [["Master", &"master"], ["Music", &"music"], ["Sound Effects", &"sfx"], ["Interface", &"ui"]]:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 54)
		_content.add_child(row)
		_add_row_label(row, data[0])
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var volume_key := StringName("%s_volume" % data[1])
		slider.value = float(_value(&"audio", volume_key, 1.0)) * 100.0
		slider.value_changed.connect(func(value: float) -> void: _settings_source.call("set_value", &"audio", volume_key, value / 100.0))
		row.add_child(slider)
		var mute := CheckBox.new()
		mute.text = "Mute"
		var mute_key := StringName("%s_muted" % data[1])
		mute.button_pressed = bool(_value(&"audio", mute_key, false))
		mute.toggled.connect(func(on: bool) -> void: _settings_source.call("set_value", &"audio", mute_key, on))
		row.add_child(mute)


func _build_video() -> void:
	_add_heading("VIDEO")
	_mode_option = _add_option_row("Window Mode", [["Windowed", &"windowed"], ["Borderless", &"borderless"], ["Fullscreen", &"fullscreen"]], _value(&"video", &"window_mode", &"borderless"))
	_resolution_option = OptionButton.new()
	var resolutions: Array = _settings_source.call("available_resolutions") as Array
	var current_resolution := _value(&"video", &"resolution", Vector2i(1920, 1080)) as Vector2i
	if current_resolution not in resolutions:
		resolutions.append(current_resolution)
	for resolution in resolutions:
		_resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
		_resolution_option.set_item_metadata(_resolution_option.item_count - 1, resolution)
		if resolution == current_resolution:
			_resolution_option.select(_resolution_option.item_count - 1)
	_add_control_row("Resolution", _resolution_option)
	_mode_option.item_selected.connect(func(_index: int) -> void: _begin_display_preview())
	_resolution_option.item_selected.connect(func(_index: int) -> void: _begin_display_preview())
	_add_option_setting("VSync", &"video", &"vsync", [["Off", &"off"], ["On", &"on"], ["Adaptive", &"adaptive"]])
	_add_option_setting("Frame Limit", &"video", &"frame_limit", [["Unlimited", 0], ["60", 60], ["90", 90], ["120", 120], ["144", 144], ["165", 165], ["240", 240], ["360", 360]])


func _build_controls() -> void:
	_add_heading("CONTROLS")
	var deadzone := HSlider.new()
	deadzone.min_value = 0.1
	deadzone.max_value = 0.9
	deadzone.step = 0.05
	deadzone.value = float(_value(&"controls", &"controller_deadzone", 0.2))
	deadzone.value_changed.connect(func(value: float) -> void: _settings_source.call("set_value", &"controls", &"controller_deadzone", value))
	_add_control_row("Controller Deadzone", deadzone)
	var header := HBoxContainer.new()
	_add_row_label(header, "Action")
	for text in ["Keyboard / Mouse 1", "Keyboard / Mouse 2", "Controller 1", "Controller 2"]:
		var label := Label.new()
		label.text = text
		label.custom_minimum_size = Vector2(150, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(label)
	_content.add_child(header)
	var last_category := ""
	for entry: Dictionary in _settings_source.call("input_entries"):
		var category := String(entry[&"category"])
		if category != last_category:
			var category_label := Label.new()
			category_label.text = category.to_upper()
			category_label.modulate = ACCENT
			category_label.add_theme_font_size_override("font_size", 17)
			_content.add_child(category_label)
			last_category = category
		var row := BindingRowScene.instantiate()
		row.call("configure", _settings_source, entry)
		row.connect("binding_requested", _request_binding)
		_content.add_child(row)


func _build_accessibility() -> void:
	_add_heading("ACCESSIBILITY")
	var scale_slider := HSlider.new()
	scale_slider.min_value = 80
	scale_slider.max_value = 150
	scale_slider.step = 5
	scale_slider.value = float(_value(&"accessibility", &"ui_scale", 1.0)) * 100.0
	scale_slider.value_changed.connect(func(value: float) -> void: _settings_source.call("set_value", &"accessibility", &"ui_scale", value / 100.0))
	_add_control_row("UI Scale", scale_slider)
	_add_option_setting("Typewriter Speed", &"accessibility", &"typewriter_speed", [["Instant", &"instant"], ["Slow", &"slow"], ["Normal", &"normal"], ["Fast", &"fast"]])
	var reduced := CheckBox.new()
	reduced.text = "Reduce nonessential camera and interface motion"
	reduced.button_pressed = bool(_value(&"accessibility", &"reduced_motion", false))
	reduced.toggled.connect(func(on: bool) -> void: _settings_source.call("set_value", &"accessibility", &"reduced_motion", on))
	_add_control_row("Reduced Motion", reduced)
	_add_option_setting("Combat Flashes", &"accessibility", &"combat_flash", [["Off", &"off"], ["Reduced", &"reduced"], ["Full", &"full"]])
	# Two rows, not one. Damage numbers are the per-hit stream; callouts are the
	# named lines an ability speaks, and for a Manifestation build they are the
	# only text there is - so switching the stream off must not silence them.
	var numbers := CheckBox.new()
	numbers.text = "Show floating damage numbers"
	numbers.button_pressed = bool(_value(&"accessibility", &"damage_numbers", true))
	numbers.toggled.connect(func(on: bool) -> void: _settings_source.call("set_value", &"accessibility", &"damage_numbers", on))
	_add_control_row("Damage Numbers", numbers)
	var callouts := CheckBox.new()
	callouts.text = "Show ability and Manifestation callouts"
	callouts.button_pressed = bool(_value(&"accessibility", &"ability_callouts", true))
	callouts.toggled.connect(func(on: bool) -> void: _settings_source.call("set_value", &"accessibility", &"ability_callouts", on))
	_add_control_row("Ability Callouts", callouts)


func _add_heading(text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.modulate = ACCENT
	heading.add_theme_font_size_override("font_size", 22)
	_content.add_child(heading)


func _add_row_label(row: HBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(220, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)


func _add_control_row(label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 50)
	_add_row_label(row, label_text)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	_content.add_child(row)


func _add_option_row(label_text: String, options: Array, selected_value: Variant) -> OptionButton:
	var option := OptionButton.new()
	for data in options:
		option.add_item(String(data[0]))
		option.set_item_metadata(option.item_count - 1, data[1])
		if data[1] == selected_value:
			option.select(option.item_count - 1)
	_add_control_row(label_text, option)
	return option


func _add_option_setting(label_text: String, section: StringName, key: StringName, options: Array) -> void:
	var option := _add_option_row(label_text, options, _value(section, key, options[0][1]))
	option.item_selected.connect(func(index: int) -> void: _settings_source.call("set_value", section, key, option.get_item_metadata(index)))


func _value(section: StringName, key: StringName, fallback: Variant) -> Variant:
	return _settings_source.call("get_value", section, key, fallback)


func _request_binding(action: StringName, family: StringName, slot: int, label: String) -> void:
	_pending_binding = {&"action": action, &"family": family, &"slot": slot, &"label": label}
	_capture.call("begin", family)


func _on_input_captured(event: InputEvent) -> void:
	_pending_binding[&"event"] = event
	var result: Dictionary = _settings_source.call("bind_input", _pending_binding[&"action"], _pending_binding[&"family"], _pending_binding[&"slot"], event, &"cancel")
	if bool(result.get(&"ok", false)):
		_pending_binding.clear()
		_set_section(&"controls")
		return
	_pending_binding[&"conflict_action"] = result.get(&"conflict_action", &"")
	_conflict.call("present", String(_pending_binding[&"label"]), String(result.get(&"conflict_action", &"another action")).replace("_", " ").capitalize())


func _on_conflict_resolved(choice: StringName) -> void:
	if choice != &"cancel" and not _pending_binding.is_empty():
		_settings_source.call("bind_input", _pending_binding[&"action"], _pending_binding[&"family"], _pending_binding[&"slot"], _pending_binding[&"event"], choice)
	_pending_binding.clear()
	_set_section(&"controls")


func _begin_display_preview() -> void:
	var changes := {
		&"window_mode": _mode_option.get_item_metadata(_mode_option.selected),
		&"resolution": _resolution_option.get_item_metadata(_resolution_option.selected),
	}
	if bool(_settings_source.call("begin_display_preview", changes)):
		_display_confirm.call("start", 12.0)


func _on_display_confirmation(keep: bool) -> void:
	if keep:
		_settings_source.call("confirm_display_preview")
	else:
		_settings_source.call("revert_display_preview")
	_set_section(&"video")


func _request_reset() -> void:
	_reset_confirm.popup_centered()


func _confirm_reset() -> void:
	if _active_section == &"controls":
		_settings_source.call("reset_controls")
	else:
		_settings_source.call("reset_section", _active_section)
	_set_section(_active_section)
