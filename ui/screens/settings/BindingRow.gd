extends HBoxContainer
class_name SettingsBindingRow

signal binding_requested(action: StringName, family: StringName, slot: int, label: String)

var _settings_source: Node
var _entry: Dictionary
var _buttons: Dictionary = {}


func configure(settings_source: Node, entry: Dictionary) -> void:
	_settings_source = settings_source
	_entry = entry
	add_to_group(&"settings_binding_row")
	_build_ui()
	refresh()


func refresh() -> void:
	if _settings_source == null:
		return
	var action := StringName(_entry[&"action"])
	for family in [&"keyboard_mouse", &"controller"]:
		var events: Array = _settings_source.call("input_events", action, family) as Array
		for slot in range(2):
			var button := _buttons.get("%s_%d" % [family, slot]) as Button
			if button != null:
				button.text = _event_text(events[slot]) if slot < events.size() else "Unbound"


func _build_ui() -> void:
	custom_minimum_size = Vector2(0, 72)
	add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = String(_entry[&"label"])
	label.custom_minimum_size = Vector2(190, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	for family in [&"keyboard_mouse", &"controller"]:
		for slot in range(2):
			var cell := VBoxContainer.new()
			cell.custom_minimum_size = Vector2(150, 0)
			add_child(cell)
			var button := Button.new()
			button.custom_minimum_size = Vector2(145, 38)
			button.pressed.connect(_request.bind(family, slot))
			cell.add_child(button)
			_buttons["%s_%d" % [family, slot]] = button
			var clear := Button.new()
			clear.text = "Clear"
			clear.flat = true
			clear.pressed.connect(_clear.bind(family, slot))
			cell.add_child(clear)


func _request(family: StringName, slot: int) -> void:
	binding_requested.emit(StringName(_entry[&"action"]), family, slot, String(_entry[&"label"]))


func _clear(family: StringName, slot: int) -> void:
	_settings_source.call("clear_input_slot", StringName(_entry[&"action"]), family, slot)
	refresh()


func _event_text(event: InputEvent) -> String:
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return "Axis %d %s" % [motion.axis, "−" if motion.axis_value < 0.0 else "+"]
	return event.as_text().trim_suffix(" (Physical)")
