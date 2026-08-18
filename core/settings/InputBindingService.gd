extends RefCounted
class_name InputBindingService

const Codec := preload("res://core/settings/InputBindingCodec.gd")
const Catalog := preload("res://core/settings/InputActionCatalog.gd")

var _actions: Array[StringName] = []


func _init(actions: Array = []) -> void:
	if actions.is_empty():
		_actions = Catalog.action_names()
	else:
		for action in actions:
			_actions.append(StringName(action))


func ensure_actions() -> void:
	for action: StringName in _actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)


func events_for(action: StringName, wanted_family: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if action not in _actions or not InputMap.has_action(action):
		return result
	for event: InputEvent in InputMap.action_get_events(action):
		if Codec.family(event) == wanted_family:
			result.append(event)
	return result


func bind_event(action: StringName, wanted_family: StringName, slot: int, event: InputEvent, resolution: StringName = &"cancel") -> Dictionary:
	if action not in _actions or Codec.family(event) != wanted_family or slot < 0 or slot > 1:
		return {&"ok": false}
	ensure_actions()
	var selected := events_for(action, wanted_family)
	for existing_index in range(selected.size()):
		if Codec.equivalent(selected[existing_index], event):
			return {&"ok": true}

	var conflict_action := &""
	var conflict_slot := -1
	for candidate: StringName in _actions:
		if candidate == action:
			continue
		var candidate_events := events_for(candidate, wanted_family)
		for index in range(candidate_events.size()):
			if Codec.equivalent(candidate_events[index], event):
				conflict_action = candidate
				conflict_slot = index
				break
		if conflict_action != &"":
			break

	if conflict_action != &"" and resolution not in [&"replace", &"swap"]:
		return {&"ok": false, &"conflict_action": conflict_action, &"conflict_slot": conflict_slot}

	var previous: InputEvent = selected[slot] if slot < selected.size() else null
	if conflict_action != &"":
		var conflict_events := events_for(conflict_action, wanted_family)
		conflict_events.remove_at(conflict_slot)
		_set_family_events(conflict_action, wanted_family, conflict_events)
	_set_slot(action, wanted_family, slot, event)
	if conflict_action != &"" and resolution == &"swap" and previous != null:
		_set_slot(conflict_action, wanted_family, conflict_slot, previous)
	return {&"ok": true}


func clear_slot(action: StringName, wanted_family: StringName, slot: int) -> bool:
	var family_events := events_for(action, wanted_family)
	if slot < 0 or slot >= family_events.size():
		return false
	family_events.remove_at(slot)
	_set_family_events(action, wanted_family, family_events)
	return true


func apply_saved_bindings(saved: Dictionary) -> void:
	ensure_actions()
	for action_variant in saved.keys():
		var action := StringName(action_variant)
		if action not in _actions:
			continue
		var decoded: Array[InputEvent] = []
		var encoded_events: Array = saved[action_variant] as Array
		for data_variant in encoded_events:
			if data_variant is Dictionary:
				var event := Codec.decode(data_variant as Dictionary)
				if event != null:
					decoded.append(event)
		if decoded.is_empty():
			continue
		InputMap.action_erase_events(action)
		for event in decoded:
			InputMap.action_add_event(action, event)


func serialize_bindings() -> Dictionary:
	var result: Dictionary = {}
	for action: StringName in _actions:
		var encoded: Array[Dictionary] = []
		if InputMap.has_action(action):
			for event: InputEvent in InputMap.action_get_events(action):
				var data: Dictionary = Codec.encode(event)
				if not data.is_empty() and data not in encoded:
					encoded.append(data)
		result[action] = encoded
	return result


func reset_defaults() -> void:
	ensure_actions()
	var defaults: Dictionary = Catalog.default_bindings()
	for action: StringName in _actions:
		InputMap.action_erase_events(action)
		for event: InputEvent in defaults.get(action, []):
			InputMap.action_add_event(action, event)


func set_controller_deadzone(value: float) -> void:
	for action: StringName in _actions:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, clampf(value, 0.1, 0.9))


func _set_slot(action: StringName, wanted_family: StringName, slot: int, event: InputEvent) -> void:
	var family_events := events_for(action, wanted_family)
	if slot < family_events.size():
		family_events[slot] = event
	else:
		family_events.append(event)
	var unique: Array[InputEvent] = []
	for candidate in family_events:
		if not _contains_event(unique, candidate):
			unique.append(candidate)
	_set_family_events(action, wanted_family, unique)


func _set_family_events(action: StringName, wanted_family: StringName, family_events: Array[InputEvent]) -> void:
	var preserved: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if Codec.family(event) != wanted_family:
			preserved.append(event)
	InputMap.action_erase_events(action)
	for event in preserved:
		InputMap.action_add_event(action, event)
	for event in family_events:
		InputMap.action_add_event(action, event)


func _contains_event(events: Array[InputEvent], wanted: InputEvent) -> bool:
	for event in events:
		if Codec.equivalent(event, wanted):
			return true
	return false
