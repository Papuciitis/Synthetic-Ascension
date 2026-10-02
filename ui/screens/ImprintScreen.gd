extends CanvasLayer
class_name ImprintScreen

## The imprinter, opened from the Hub: held imprints on the left, the items
## each could go onto on the right, one press to apply for Followers.

signal closed

## The front-end register (docs/design/2026-10-02-front-end-arcane-register.md):
## an ornamented panel over a veil, a Cinzel title, diamonds for selection.
const ARCANE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const ArcaneRuleScript := preload("res://ui/components/ArcaneRule.gd")
const BODY_DIM := Color(0.72, 0.67, 0.58)
const STATUS := Color(1.0, 0.86, 0.62)
const GOLD_BRIGHT := Color(0.99, 0.84, 0.58)

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
	_root.theme = ARCANE_THEME
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var scrim := ColorRect.new()
	scrim.color = Color(0.008, 0.006, 0.005, 0.86)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ArcanePanel"
	panel.custom_minimum_size = Vector2(1100, 640)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)
	panel.add_child(ArcaneFrameScript.new())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "IMPRINTER"
	title.theme_type_variation = &"ArcaneTitle"
	title.add_theme_font_size_override("font_size", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_rule(2, 18.0, 420.0))
	var blurb := Label.new()
	blurb.text = "Rules dissolved by merges are held here. Put one onto an item of a slot it allows; the rule the item carried is kept in turn."
	blurb.theme_type_variation = &"ArcaneItalic"
	blurb.add_theme_font_size_override("font_size", 17)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(blurb)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 26)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(480, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)
	left.add_child(_caption("HELD IMPRINTS"))
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(left_scroll)
	_imprint_list = VBoxContainer.new()
	_imprint_list.name = "ImprintList"
	_imprint_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_imprint_list.add_theme_constant_override("separation", 10)
	left_scroll.add_child(_imprint_list)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(1, 0)
	divider.color = Color(0.62, 0.47, 0.3, 0.35)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_child(divider)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(480, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)
	right.add_child(_caption("APPLY TO"))
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(right_scroll)
	_item_list = VBoxContainer.new()
	_item_list.name = "ItemList"
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 8)
	right_scroll.add_child(_item_list)
	column.add_child(_rule(0, 10.0, 0.0))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	_wallet = Label.new()
	_wallet.theme_type_variation = &"ArcaneHeading"
	_wallet.add_theme_font_size_override("font_size", 18)
	_wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_wallet)
	_status = Label.new()
	_status.theme_type_variation = &"ArcaneItalic"
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", STATUS)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_status)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(150, 42)
	close_button.pressed.connect(close)
	footer.add_child(close_button)


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"ArcaneCaption"
	label.add_theme_font_size_override("font_size", 15)
	return label


func _rule(ornament: int, height: float, width: float) -> Control:
	var rule := ArcaneRuleScript.new() as Control
	rule.set("ornament", ornament)
	rule.custom_minimum_size = Vector2(width, height)
	if width > 0.0:
		rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rule


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
		none.theme_type_variation = &"ArcaneItalic"
		none.add_theme_font_size_override("font_size", 17)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		head.add_theme_constant_override("separation", 8)
		row.add_child(head)
		# The chosen imprint is marked by a filled diamond and the gold edge,
		# not by colour alone.
		var pick := Button.new()
		pick.theme_type_variation = &"ArcaneKeyButton"
		if imprint_id == _selected:
			pick.add_theme_stylebox_override("normal", ARCANE_THEME.get_stylebox(&"hover", &"ArcaneKeyButton"))
			pick.add_theme_color_override("font_color", GOLD_BRIGHT)
		pick.text = def.display_name
		pick.icon = ARCANE_THEME.get_icon(&"checked" if imprint_id == _selected else &"unchecked", &"CheckBox")
		pick.add_theme_constant_override("h_separation", 10)
		pick.custom_minimum_size = Vector2(0, 36)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.pressed.connect(func() -> void:
			_selected = imprint_id
			_refresh()
		)
		head.add_child(pick)
		var discard := Button.new()
		discard.theme_type_variation = &"ArcaneDangerButton"
		discard.text = "Discard"
		discard.tooltip_text = "Forget this imprint."
		discard.pressed.connect(func() -> void:
			ImprintService.discard(imprint_id)
			_status.text = "%s forgotten." % def.display_name
			_refresh()
		)
		head.add_child(discard)
		var rule := Label.new()
		rule.text = "%s  ·  slots: %s" % [def.rule, _slot_names(def.slots)]
		rule.theme_type_variation = &"ArcaneBody"
		rule.add_theme_font_size_override("font_size", 16)
		rule.add_theme_color_override("font_color", BODY_DIM)
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(rule)
	if _selected.is_empty():
		return
	var selected_def := ManifestationCatalog.get_def(_selected)
	for candidate in ImprintService.candidates(_selected):
		var inst: ItemInstance = candidate["inst"]
		var line := HBoxContainer.new()
		line.name = "Candidate_%s_%d" % [String(candidate["where"]), int(candidate["slot"])]
		line.add_theme_constant_override("separation", 12)
		_item_list.add_child(line)
		var label := Label.new()
		var current := ManifestationCatalog.get_def(inst.manifestation_id)
		label.text = "%s (R%d, %s)  now: %s" % [inst.data.display_name, int(inst.rarity), String(candidate["where"]), current.display_name if current != null else "no rule"]
		label.theme_type_variation = &"ArcaneBody"
		label.add_theme_font_size_override("font_size", 17)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(label)
		var apply := Button.new()
		apply.theme_type_variation = &"ArcaneSmallButton"
		apply.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
