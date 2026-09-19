extends CanvasLayer
class_name ImprintScreen

## The imprinter, opened from the Hub: held imprints on the left, the items
## each could go onto on the right, one press to apply for Followers.

signal closed

var _root: Control = null
var _imprint_list: VBoxContainer = null
var _item_list: VBoxContainer = null
var _status: Label = null
var _wallet: Label = null
var _selected: StringName = &""


func _ready() -> void:
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_refresh()


func close() -> void:
	visible = false
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.025, 0.02, 0.94)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(scrim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1100, 640)
	panel.position = Vector2(-550, -320)
	_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "IMPRINTER"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var blurb := Label.new()
	blurb.text = "Rules dissolved by merges are held here. Put one onto an item of a slot it allows; the rule the item carried is kept in turn."
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.modulate = Color(1, 1, 1, 0.7)
	column.add_child(blurb)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(480, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	var left_title := Label.new()
	left_title.text = "HELD IMPRINTS"
	left.add_child(left_title)
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(left_scroll)
	_imprint_list = VBoxContainer.new()
	_imprint_list.name = "ImprintList"
	_imprint_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_imprint_list)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(480, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var right_title := Label.new()
	right_title.text = "APPLY TO"
	right.add_child(right_title)
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(right_scroll)
	_item_list = VBoxContainer.new()
	_item_list.name = "ItemList"
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_item_list)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	_wallet = Label.new()
	footer.add_child(_wallet)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.modulate = Color(1, 0.9, 0.7, 0.9)
	footer.add_child(_status)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	footer.add_child(close_button)


func _refresh() -> void:
	for child in _imprint_list.get_children():
		child.queue_free()
	for child in _item_list.get_children():
		child.queue_free()
	if Global == null:
		return
	_wallet.text = "%d Followers" % int(Global.followers)
	var held: Array = Global.attempt_imprints.duplicate()
	if held.is_empty():
		var none := Label.new()
		none.text = "Nothing held. Merging a duplicate that carried a different rule keeps that rule here."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.modulate = Color(1, 1, 1, 0.6)
		_imprint_list.add_child(none)
	if not _selected.is_empty() and not held.has(_selected):
		_selected = &""
	if _selected.is_empty() and not held.is_empty():
		_selected = StringName(held[0])
	for imprint_variant in held:
		var imprint_id := StringName(imprint_variant)
		var def := ManifestationCatalog.get_def(imprint_id)
		if def == null:
			continue
		var row := VBoxContainer.new()
		row.name = "Imprint_%s" % String(imprint_id)
		_imprint_list.add_child(row)
		var head := HBoxContainer.new()
		row.add_child(head)
		var pick := Button.new()
		pick.text = ("▸ " if imprint_id == _selected else "  ") + def.display_name
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.pressed.connect(func() -> void:
			_selected = imprint_id
			_refresh()
		)
		head.add_child(pick)
		var discard := Button.new()
		discard.text = "Discard"
		discard.tooltip_text = "Forget this imprint."
		discard.pressed.connect(func() -> void:
			ImprintService.discard(imprint_id)
			_status.text = "%s forgotten." % def.display_name
			_refresh()
		)
		head.add_child(discard)
		var rule := Label.new()
		rule.text = "%s  •  slots: %s" % [def.rule, _slot_names(def.slots)]
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule.modulate = Color(1, 1, 1, 0.66)
		row.add_child(rule)
	if _selected.is_empty():
		return
	var selected_def := ManifestationCatalog.get_def(_selected)
	for candidate in ImprintService.candidates(_selected):
		var inst: ItemInstance = candidate["inst"]
		var line := HBoxContainer.new()
		line.name = "Candidate_%s_%d" % [String(candidate["where"]), int(candidate["slot"])]
		_item_list.add_child(line)
		var label := Label.new()
		var current := ManifestationCatalog.get_def(inst.manifestation_id)
		label.text = "%s (R%d, %s)  now: %s" % [inst.data.display_name, int(inst.rarity), String(candidate["where"]), current.display_name if current != null else "no rule"]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(label)
		var apply := Button.new()
		if bool(candidate["ok"]):
			apply.text = "Apply  −%d" % int(candidate["price"])
			apply.pressed.connect(func() -> void:
				var result := ImprintService.apply(_selected, inst)
				if bool(result.get("ok", false)):
					var replaced_def := ManifestationCatalog.get_def(StringName(result.get("replaced", &"")))
					_status.text = "%s now carries %s%s." % [inst.data.display_name, selected_def.display_name if selected_def != null else String(_selected), (", %s kept" % replaced_def.display_name) if replaced_def != null else ""]
				else:
					_status.text = String(result.get("reason", ""))
				_refresh()
			)
		else:
			apply.text = String(candidate["reason"])
			apply.disabled = true
		line.add_child(apply)


func _slot_names(slots: Array) -> String:
	var names := PackedStringArray()
	for slot in slots:
		var key: Variant = ItemData.EquipSlot.find_key(int(slot))
		names.append(String(key).capitalize() if key != null else str(slot))
	return ", ".join(names)
