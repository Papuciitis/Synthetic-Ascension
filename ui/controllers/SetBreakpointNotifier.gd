extends Control
class_name SetBreakpointNotifier

var _inventory: Inventory = null
var _counts: Dictionary = {}
var _queue: Array[Dictionary] = []
var _showing: bool = false
var _panel: PanelContainer = null
var _title: Label = null
var _detail: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_build_ui()
	add_to_group(&"set_breakpoint_notifier")
	set_process(true)

func _process(_delta: float) -> void:
	var current: Inventory = Global.run_inventory if Global != null else null
	if current != _inventory:
		_bind_inventory(current)

func _bind_inventory(value: Inventory) -> void:
	if _inventory != null and _inventory.equipment_changed.is_connected(_on_equipment_changed):
		_inventory.equipment_changed.disconnect(_on_equipment_changed)
	_inventory = value
	_counts = _inventory.get_set_counts() if _inventory != null else {}
	if _inventory != null:
		_inventory.equipment_changed.connect(_on_equipment_changed)

func _on_equipment_changed(_slot: int, _inst: ItemInstance, _prev: ItemInstance, player_driven: bool) -> void:
	if _inventory == null:
		return
	var after: Dictionary = _inventory.get_set_counts()
	if player_driven:
		_collect_transitions(_counts, after)
	_counts = after

func _collect_transitions(before: Dictionary, after: Dictionary) -> void:
	var ids: Dictionary = {}
	for key: Variant in before.keys():
		ids[StringName(key)] = true
	for key: Variant in after.keys():
		ids[StringName(key)] = true
	for id_value: Variant in ids.keys():
		var set_id: StringName = StringName(id_value)
		var data: SetData = null
		if Global != null and Global.set_db != null:
			data = Global.set_db.get(set_id, null) as SetData
		if data == null:
			continue
		var old_count: int = int(before.get(set_id, 0))
		var new_count: int = int(after.get(set_id, 0))
		for tier: SetTier in data.sorted_tiers():
			if tier == null:
				continue
			if old_count < tier.required_count and new_count >= tier.required_count:
				_enqueue(true, data, tier, new_count)
			elif old_count >= tier.required_count and new_count < tier.required_count:
				_enqueue(false, data, tier, new_count)

func _enqueue(gained: bool, data: SetData, tier: SetTier, count: int) -> void:
	_queue.append({"gained": gained, "set": data, "tier": tier, "count": count})
	if not _showing:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty() or not is_inside_tree():
		_showing = false
		return
	_showing = true
	var message: Dictionary = _queue.pop_front()
	var gained: bool = bool(message.get("gained", false))
	var data: SetData = message.get("set", null) as SetData
	var tier: SetTier = message.get("tier", null) as SetTier
	if data == null or tier == null:
		_show_next()
		return
	_title.text = ("SET BREAKPOINT ACTIVE" if gained else "SET BREAKPOINT LOST")
	_detail.text = "%s · %dP %s\n%d / %d pieces" % [data.display_name, tier.required_count, tier.display_name, int(message.get("count", 0)), data.max_pieces()]
	_title.modulate = data.accent_color if gained else Color(0.78, 0.78, 0.78)
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(0.94, 0.94) if gained else Vector2.ONE
	_panel.visible = true
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.16)
	if gained:
		tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.8 if gained else 1.1)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.20)
	tween.finished.connect(func() -> void:
		_panel.visible = false
		_show_next()
	)

func debug_force_notification(set_id: StringName, required_count: int, gained: bool = true) -> void:
	if Global == null or Global.set_db == null:
		return
	var data: SetData = Global.set_db.get(set_id, null) as SetData
	if data == null:
		return
	for tier: SetTier in data.tiers:
		if tier != null and tier.required_count == required_count:
			_enqueue(gained, data, tier, required_count if gained else required_count - 1)
			return

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "SetBreakpointPanel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	_panel.offset_left = -220.0
	_panel.offset_top = 124.0
	_panel.offset_right = 220.0
	_panel.offset_bottom = 194.0
	_panel.pivot_offset = Vector2(220.0, 35.0)
	add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.04, 0.94)
	style.border_color = Color(0.75, 0.75, 0.75, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 14)
	box.add_child(_title)
	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_theme_font_size_override("font_size", 12)
	box.add_child(_detail)
