extends RefCounted
class_name InputBindingCodec


static func encode(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		var result := {&"type": &"key", &"physical_keycode": key.physical_keycode}
		if key.alt_pressed:
			result[&"alt"] = true
		if key.shift_pressed:
			result[&"shift"] = true
		if key.ctrl_pressed:
			result[&"ctrl"] = true
		if key.meta_pressed:
			result[&"meta"] = true
		return result
	if event is InputEventMouseButton:
		return {&"type": &"mouse_button", &"button": (event as InputEventMouseButton).button_index}
	if event is InputEventJoypadButton:
		return {&"type": &"joy_button", &"button": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {&"type": &"joy_axis", &"axis": motion.axis, &"direction": -1 if motion.axis_value < 0.0 else 1}
	return {}


static func decode(data: Dictionary) -> InputEvent:
	match StringName(data.get(&"type", &"")):
		&"key":
			var code := int(data.get(&"physical_keycode", 0))
			if code == 0:
				return null
			var key := InputEventKey.new()
			key.physical_keycode = code
			key.alt_pressed = bool(data.get(&"alt", false))
			key.shift_pressed = bool(data.get(&"shift", false))
			key.ctrl_pressed = bool(data.get(&"ctrl", false))
			key.meta_pressed = bool(data.get(&"meta", false))
			return key
		&"mouse_button":
			var mouse_button := int(data.get(&"button", 0))
			if mouse_button <= 0:
				return null
			var mouse := InputEventMouseButton.new()
			mouse.button_index = mouse_button
			return mouse
		&"joy_button":
			var joy_button := int(data.get(&"button", -1))
			if joy_button < 0:
				return null
			var button := InputEventJoypadButton.new()
			button.button_index = joy_button
			return button
		&"joy_axis":
			var axis := int(data.get(&"axis", -1))
			var direction := int(data.get(&"direction", 0))
			if axis < 0 or direction == 0:
				return null
			var motion := InputEventJoypadMotion.new()
			motion.axis = axis
			motion.axis_value = -1.0 if direction < 0 else 1.0
			return motion
	return null


static func family(event: InputEvent) -> StringName:
	if event is InputEventKey or event is InputEventMouseButton:
		return &"keyboard_mouse"
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return &"controller"
	return &""


static func equivalent(a: InputEvent, b: InputEvent) -> bool:
	return not encode(a).is_empty() and encode(a) == encode(b)
