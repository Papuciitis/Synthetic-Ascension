extends Control
class_name SetBreakpointNotifier
## Announces a set breakpoint gained or lost, one card at a time, in the front
## end's register: a dark card in a gold double rule, the set's accent on its
## Cinzel caption, a Garamond line. The card fades in with a small settle
## (only the fade under Reduced Motion) on real time, through a paused tree.

const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")
const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")

var _inventory: Inventory = null
var _counts: Dictionary = {}
var _queue: Array[Dictionary] = []
var _showing: bool = false
var _panel: PanelContainer = null
var _title: Label = null
var _detail: Label = null
var _frame: Control = null

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
	# The set's own accent, softened toward the gold so it sits in the register.
	_title.modulate = data.accent_color.lerp(OverlayKit.GOLD_BRIGHT, 0.35) if gained else Color(0.7, 0.66, 0.6)
	_frame.set("glow", 0.3 if gained else 0.0)
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.pivot_offset = _panel.size * 0.5
	var pop := gained and not OverlayKit.reduced()
	_panel.scale = Vector2(0.94, 0.94) if pop else Vector2.ONE
	_panel.visible = true
	var tween: Tween = OverlayKit.tween(self)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	if pop:
		tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	_panel.add_theme_stylebox_override("panel", OverlayKit.shared(&"card"))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 13)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)
	_frame = ArcaneFrameScript.new() as Control
	_frame.set("inset", 5.0)
	_panel.add_child(_frame)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	OverlayKit.style_label(_title, &"heading", 14, Color.WHITE)
	box.add_child(_title)
	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	OverlayKit.style_label(_detail, &"body", 16, OverlayKit.BODY)
	box.add_child(_detail)
