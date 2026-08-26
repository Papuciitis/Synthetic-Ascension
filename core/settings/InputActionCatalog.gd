extends RefCounted
class_name InputActionCatalog


static func entries() -> Array[Dictionary]:
	return [
		_entry(&"move_left", "Movement", "Move Left"),
		_entry(&"move_right", "Movement", "Move Right"),
		_entry(&"move_up", "Movement", "Move Up"),
		_entry(&"move_down", "Movement", "Move Down"),
		_entry(&"dash", "Movement", "Dash"),
		_entry(&"aim_left", "Aim", "Aim Left"),
		_entry(&"aim_right", "Aim", "Aim Right"),
		_entry(&"aim_up", "Aim", "Aim Up"),
		_entry(&"aim_down", "Aim", "Aim Down"),
		_entry(&"attack", "Combat", "Primary Attack"),
		_entry(&"alt_attack", "Combat", "Secondary Attack"),
		_entry(&"interact", "Interaction", "Interact"),
		_entry(&"bag_toggle", "Interaction", "Inventory"),
		_entry(&"hud_details", "Interaction", "Inspect HUD Details"),
		_entry(&"set_active", "Interaction", "Activate Set"),
		_entry(&"augment_active", "Augments", "Augment Action"),
		_entry(&"augment_active_1", "Augments", "Augment Slot 1"),
		_entry(&"augment_active_2", "Augments", "Augment Slot 2"),
		_entry(&"augment_active_3", "Augments", "Augment Slot 3"),
		_entry(&"augment_detonate", "Augments", "Detonate"),
	]


static func action_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in entries():
		result.append(entry[&"action"] as StringName)
	return result


static func default_bindings() -> Dictionary:
	return {
		&"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1)],
		&"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1)],
		&"move_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1)],
		&"move_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1)],
		# NOT Space and NOT JOY_BUTTON_B: those are Godot's ui_accept and
		# ui_cancel defaults, and every ability here polls Input rather than
		# consuming events, so a focused Button would fire both at once.
		&"dash": [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_SHOULDER)],
		&"aim_left": [_axis(JOY_AXIS_RIGHT_X, -1)],
		&"aim_right": [_axis(JOY_AXIS_RIGHT_X, 1)],
		&"aim_up": [_axis(JOY_AXIS_RIGHT_Y, -1)],
		&"aim_down": [_axis(JOY_AXIS_RIGHT_Y, 1)],
		&"attack": [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1)],
		&"alt_attack": [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_LEFT, 1)],
		&"interact": [_key(KEY_E), _key(KEY_ENTER), _button(JOY_BUTTON_A)],
		&"bag_toggle": [_key(KEY_TAB), _key(KEY_I), _button(JOY_BUTTON_BACK)],
		&"hud_details": [_key(KEY_H), _button(JOY_BUTTON_DPAD_DOWN)],
		&"set_active": [_key(KEY_R), _button(JOY_BUTTON_Y)],
		&"augment_active": [_key(KEY_F), _button(JOY_BUTTON_RIGHT_SHOULDER)],
		&"augment_active_1": [_key(KEY_1), _button(JOY_BUTTON_DPAD_LEFT)],
		&"augment_active_2": [_key(KEY_2), _button(JOY_BUTTON_DPAD_UP)],
		&"augment_active_3": [_key(KEY_3), _button(JOY_BUTTON_DPAD_RIGHT)],
		&"augment_detonate": [_key(KEY_G), _mouse(MOUSE_BUTTON_MIDDLE), _button(JOY_BUTTON_X)],
	}


static func _entry(action: StringName, category: String, label: String) -> Dictionary:
	return {&"action": action, &"category": category, &"label": label}


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _mouse(index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	return event


static func _button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	return event


static func _axis(index: JoyAxis, direction: int) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = -1.0 if direction < 0 else 1.0
	return event
