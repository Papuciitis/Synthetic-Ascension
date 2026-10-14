extends Node
## Shared feedback for ordinary menu controls. Screens can set
## ui_sound_manual on a subtree to keep their own activation sounds.

const NAV_INTERVAL_MS := 80
const CUSTOM_ACTIVATIONS: Array[StringName] = [&"pressed", &"clicked", &"interaction_requested", &"requested_equip", &"unequip_requested", &"drop_received", &"request_reorder", &"rename_requested", &"delete_requested", &"node_clicked", &"node_activated"]
var _sound: Node
var _input_frame := -100
var _input_serial := 0
var _pending_id: StringName = &""
var _pending_priority := -1
var _pending_serial := 0
var _last_navigation_ms := -100000
var _flush_queued := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sound = get_parent()
	get_tree().node_added.connect(_on_node_added)
	_observe_branch(get_tree().root)

func _input(event: InputEvent) -> void:
	var meaningful := false
	if event is InputEventMouseMotion:
		meaningful = not event.relative.is_zero_approx()
	elif event is InputEventMouseButton:
		meaningful = true
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction:
		# Ordinary Buttons activate on release, including Enter and pad Accept.
		meaningful = true
	elif event is InputEventJoypadMotion:
		meaningful = absf(event.axis_value) > 0.5
	if meaningful:
		_input_frame = Engine.get_process_frames()
		_input_serial = int(_sound.get("ui_request_serial"))

func _on_node_added(node: Node) -> void:
	# Wire a scene's Buttons before its ready callbacks attach transitions;
	# removing the old scene must not swallow the click that opened the next.
	_observe(node)

func _observe_branch(node: Node) -> void:
	_observe(node)
	for child in node.get_children():
		_observe_branch(child)

func _observe(node: Node) -> void:
	if not is_instance_valid(node) or not node is Control or node.has_meta("ui_sound_observed"):
		return
	node.set_meta("ui_sound_observed", true)
	var control := node as Control
	if control is BaseButton or control is ItemList or control is TabBar or control is Slider or control.has_signal("pressed") or control.has_signal("node_clicked") or control.has_signal("clicked") or control.has_signal("requested_equip") or control.has_signal("focused"):
		control.mouse_entered.connect(_navigate.bind(control))
		control.focus_entered.connect(_navigate.bind(control))
	if control is BaseButton:
		control.pressed.connect(_button_activated.bind(control))
	if control is OptionButton:
		control.item_selected.connect(func(_index: int) -> void: _activate(control, &"ui_toggle"))
	elif control is ItemList:
		control.item_selected.connect(func(_index: int) -> void: _activate(control, &"ui_click"))
		control.item_activated.connect(func(_index: int) -> void: _activate(control, &"ui_click"))
	elif control is TabBar:
		control.tab_clicked.connect(func(_index: int) -> void: _activate(control, &"ui_toggle"))
		control.tab_changed.connect(func(_index: int) -> void: _activate(control, &"ui_toggle"))
	elif control is Slider:
		control.value_changed.connect(func(_value: float) -> void: _navigate(control))
	if control.has_signal("node_hovered"):
		control.connect("node_hovered", func(id: String) -> void:
			if not id.is_empty(): _navigate(control))
	# Custom controls do not share argument counts: BagSlot.clicked() and
	# InventorySlotView.clicked(slot,button,double,shift) are both valid.
	# Ignore the signal's own arguments, preserving only this control/id.
	for signal_info: Dictionary in control.get_signal_list():
		var signal_name := StringName(signal_info["name"])
		if signal_name in CUSTOM_ACTIVATIONS and not (control is BaseButton and signal_name == &"pressed"):
			var count: int = signal_info["args"].size()
			var feedback := _activate.bind(control, &"ui_click")
			control.connect(signal_name, feedback.unbind(count) if count > 0 else feedback)

func _user_input_now() -> bool:
	return Engine.get_process_frames() == _input_frame

func _usable(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and (not control is BaseButton or not control.disabled)

func _manual_activation(control: Control) -> bool:
	var node: Node = control
	while node != null:
		if bool(node.get_meta("ui_sound_manual", false)):
			return true
		node = node.get_parent()
	return false

func _navigate(control: Control) -> void:
	if not _user_input_now() or not _usable(control) or control.get_meta("ui_sound_quiet_focus", false):
		return
	# A hovering mouse must not cut a page, a failed action or other authored
	# feedback short on the single interface voice.
	if _authored_voice_playing():
		return
	if Time.get_ticks_msec() - _last_navigation_ms < NAV_INTERVAL_MS:
		return
	_schedule(&"ui_hover", 0)

func _activate(control: Control, id: StringName) -> void:
	if not _user_input_now() or not _usable(control) or _manual_activation(control):
		return
	_schedule(id, 1)

func _button_activated(button: BaseButton) -> void:
	# Choice tiles and other shared Buttons set toggle_mode in _ready,
	# after entering the tree. Read the final mode when the player acts.
	_activate(button, &"ui_toggle" if button.toggle_mode or button is OptionButton else &"ui_click")

func _authored_voice_playing() -> bool:
	var voice: AudioStreamPlayer = _sound.get("_ui")
	return voice != null and voice.playing and not _sound.get("_ui_current_id") in [&"ui_hover", &"ui_click", &"ui_toggle"]

func _schedule(id: StringName, priority: int) -> void:
	if priority >= _pending_priority:
		_pending_id = id
		_pending_priority = priority
		_pending_serial = _input_serial
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()

func _flush() -> void:
	_flush_queued = false
	var id := _pending_id
	var serial := _pending_serial
	_pending_id = &""
	_pending_priority = -1
	# Synchronous screen callbacks can play a result sound before OR after
	# our signal callback. Both cases win over this deferred generic click.
	if id == &"" or int(_sound.get("ui_request_serial")) != serial or _authored_voice_playing():
		return
	if id == &"ui_hover":
		_last_navigation_ms = Time.get_ticks_msec()
	_sound.call("play_ui", id)
