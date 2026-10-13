extends RefCounted


static func action(action_name: StringName) -> String:
	if not InputMap.has_action(action_name):
		return String(action_name).capitalize()
	var events := InputMap.action_get_events(action_name)
	for event in events:
		if event is InputEventKey or event is InputEventMouseButton:
			return event.as_text().trim_suffix(" (Physical)").trim_suffix(" - Physical")
	return events[0].as_text() if not events.is_empty() else "Unbound"


static func movement() -> String:
	return "%s / %s / %s / %s" % [action(&"move_up"), action(&"move_left"), action(&"move_down"), action(&"move_right")]
