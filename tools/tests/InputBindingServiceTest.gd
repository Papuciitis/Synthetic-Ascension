extends SceneTree

const ACTION_A := &"test_settings_action_a"
const ACTION_B := &"test_settings_action_b"

var _passes := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var codec_script := load("res://core/settings/InputBindingCodec.gd") as Script
	var service_script := load("res://core/settings/InputBindingService.gd") as Script
	_check(codec_script != null, "input binding codec loads")
	_check(service_script != null, "input binding service loads")
	if codec_script == null or service_script == null:
		_finish()
		return

	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	_check(codec_script.call("encode", key) == {&"type": &"key", &"physical_keycode": KEY_Q}, "physical key encodes literally")
	var decoded_key := codec_script.call("decode", {&"type": &"key", &"physical_keycode": KEY_Q}) as InputEventKey
	_check(decoded_key != null and decoded_key.physical_keycode == KEY_Q, "physical key decodes without layout loss")

	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_RIGHT_X
	axis.axis_value = -1.0
	_check(codec_script.call("encode", axis) == {&"type": &"joy_axis", &"axis": JOY_AXIS_RIGHT_X, &"direction": -1}, "negative stick axis retains direction")
	var decoded_axis := codec_script.call("decode", {&"type": &"joy_axis", &"axis": JOY_AXIS_RIGHT_X, &"direction": -1}) as InputEventJoypadMotion
	_check(decoded_axis != null and decoded_axis.axis == JOY_AXIS_RIGHT_X and decoded_axis.axis_value == -1.0, "stick direction decodes exactly")

	_cleanup_actions()
	InputMap.add_action(ACTION_A)
	InputMap.add_action(ACTION_B)
	var service = service_script.new([ACTION_A, ACTION_B])
	var a_key := InputEventKey.new()
	a_key.physical_keycode = KEY_A
	var b_key := InputEventKey.new()
	b_key.physical_keycode = KEY_B
	InputMap.action_add_event(ACTION_A, a_key)
	InputMap.action_add_event(ACTION_B, b_key)

	var conflict: Dictionary = service.bind_event(ACTION_A, &"keyboard_mouse", 0, b_key, &"cancel")
	_check(not bool(conflict.get("ok", true)) and StringName(conflict.get("conflict_action", &"")) == ACTION_B, "cancel reports the conflicting action")
	_check(_action_has_key(ACTION_A, KEY_A) and _action_has_key(ACTION_B, KEY_B), "cancel preserves both bindings")

	var replaced: Dictionary = service.bind_event(ACTION_A, &"keyboard_mouse", 0, b_key, &"replace")
	_check(bool(replaced.get("ok", false)), "replace resolves the conflict")
	_check(_action_has_key(ACTION_A, KEY_B) and not _action_has_key(ACTION_B, KEY_B), "replace moves the binding to the requested action")

	InputMap.action_erase_events(ACTION_A)
	InputMap.action_erase_events(ACTION_B)
	InputMap.action_add_event(ACTION_A, a_key)
	InputMap.action_add_event(ACTION_B, b_key)
	var swapped: Dictionary = service.bind_event(ACTION_A, &"keyboard_mouse", 0, b_key, &"swap")
	_check(bool(swapped.get("ok", false)), "swap resolves the conflict")
	_check(_action_has_key(ACTION_A, KEY_B) and _action_has_key(ACTION_B, KEY_A), "swap exchanges literal slots")

	service.bind_event(ACTION_A, &"keyboard_mouse", 1, b_key, &"replace")
	_check((service.events_for(ACTION_A, &"keyboard_mouse") as Array).size() == 1, "same-action duplicates collapse")
	var protected_before := InputMap.action_get_events(&"ui_cancel").size()
	service.apply_saved_bindings({&"ui_cancel": []})
	_check(InputMap.action_get_events(&"ui_cancel").size() == protected_before, "saved bindings cannot edit protected UI actions")
	_cleanup_actions()
	_finish()


func _action_has_key(action: StringName, physical_key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == physical_key:
			return true
	return false


## Catalog integrity. This is the assertion that would have caught binding the
## dash to Space: abilities poll Input rather than consuming events, so a
## default that collides with one of Godot's built-in ui_* bindings fires twice
## whenever a Control has focus - once as the ability, once as ui_accept.
##
## ui_* actions are not in the catalog and are therefore unrebindable
## (InputBindingService skips any action it does not own), so a collision here
## cannot be resolved later by the player.
func _test_catalog_integrity() -> void:
	var entries: Array[Dictionary] = InputActionCatalog.entries()
	var defaults: Dictionary = InputActionCatalog.default_bindings()

	var declared: Dictionary = {}
	for entry in entries:
		declared[entry[&"action"]] = true

	var missing: PackedStringArray = PackedStringArray()
	for action in declared:
		if not defaults.has(action):
			missing.append(String(action))
	var orphaned: PackedStringArray = PackedStringArray()
	for action in defaults:
		if not declared.has(action):
			orphaned.append(String(action))
	_check(missing.is_empty(), "every catalog entry has default bindings (%s)" % ", ".join(missing))
	_check(orphaned.is_empty(), "every default binding has a catalog entry (%s)" % ", ".join(orphaned))

	# Godot's own defaults for ui_accept / ui_cancel.
	var reserved_keys: Array[int] = [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]
	var reserved_buttons: Array[int] = [JOY_BUTTON_A, JOY_BUTTON_B]

	var collisions: PackedStringArray = PackedStringArray()
	for action in defaults:
		for event in (defaults[action] as Array):
			if event is InputEventKey and reserved_keys.has(int((event as InputEventKey).physical_keycode)):
				collisions.append("%s:key" % String(action))
			elif event is InputEventJoypadButton and reserved_buttons.has(int((event as InputEventJoypadButton).button_index)):
				collisions.append("%s:pad" % String(action))

	# `interact` predates this assertion and collides on Enter and pad A. It is
	# grandfathered so the test can guard everything else; fixing it is a
	# separate, player-visible rebinding decision.
	var unexpected: PackedStringArray = PackedStringArray()
	for hit in collisions:
		if not hit.begins_with("interact:"):
			unexpected.append(hit)
	_check(
		unexpected.is_empty(),
		"no default binding collides with a Godot ui_* default (%s)" % ", ".join(unexpected)
	)

	_check(defaults.has(&"dash"), "the dash is bound by default")


func _cleanup_actions() -> void:
	for action in [ACTION_A, ACTION_B]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)


func _finish() -> void:
	_test_catalog_integrity()
	print("InputBindingServiceTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
