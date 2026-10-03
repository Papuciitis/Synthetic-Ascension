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
## The hover dossier: the item tooltip's panel, with the imprinter's content.
const ITEM_TOOLTIP := preload("res://ui/widgets/ItemTooltip.tscn")
const ImprintDossier := preload("res://ui/widgets/ImprintDossier.gd")
const BODY_DIM := Color(0.72, 0.67, 0.58)
const STATUS := Color(1.0, 0.86, 0.62)
const GOLD_BRIGHT := Color(0.99, 0.84, 0.58)
## The dossier's width before ItemTooltip widens a tall one to fit the screen.
const DOSSIER_WIDTH := 440.0
## The keys and pad directions that move focus.
const NAV_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]

var _root: Control = null
var _imprint_list: VBoxContainer = null
var _item_list: VBoxContainer = null
var _status: Label = null
var _wallet: Label = null
var _selected: StringName = &""
## What a held imprint adds, or what applying it to an item changes, beside
## the row under the pointer or holding keyboard focus. Shown and placed only
## on those events; nothing here runs per frame.
var _dossier: ItemTooltip = null
var _dossier_row: Control = null


func _ready() -> void:
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_refresh()
	# A pad or keyboard needs somewhere to start. Hidden, so a pointer user
	# does not open the screen onto a dossier; the first move shows it.
	var first := _imprint_list.find_child("Pick", true, false) as Button
	if first != null:
		first.grab_focus(true)


func close() -> void:
	visible = false
	closed.emit()
	queue_free()


## The first key or pad press after the pointer (or the hidden start) shows
## focus where it is instead of moving it past that control, so the first
## imprint is not skipped and its dossier comes with it. Only on input events.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	var navigates := false
	for action in NAV_ACTIONS:
		if event.is_action(action, true):
			navigates = true
			break
	if not navigates:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or not _root.is_ancestor_of(focus_owner) or focus_owner.has_focus(true):
		return
	focus_owner.release_focus()
	focus_owner.grab_focus()
	get_viewport().set_input_as_handled()


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
	left_scroll.follow_focus = true
	left_scroll.get_v_scroll_bar().value_changed.connect(_on_list_scrolled)
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
	right_scroll.follow_focus = true
	right_scroll.get_v_scroll_bar().value_changed.connect(_on_list_scrolled)
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
	# Over the panel and mouse-transparent: ItemTooltip makes its whole
	# subtree ignore the pointer, so it never takes a hover from a row.
	_dossier = ITEM_TOOLTIP.instantiate() as ItemTooltip
	_dossier.name = "Dossier"
	_root.add_child(_dossier)


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
	# A press rebuilds both lists and frees the button that held focus, so
	# remember where focus was and put it back on the rebuilt twin.
	var refocus := _focus_record()
	_hide_dossier()
	# Out of the tree now, not at the end of the frame, so the rebuilt rows
	# get their names back and focus can find its twin by name.
	for list: Control in [_imprint_list, _item_list]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	if Global == null:
		return
	_fill_lists()
	_restore_focus(refocus)


func _fill_lists() -> void:
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
		pick.name = "Pick"
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
		discard.name = "Discard"
		discard.theme_type_variation = &"ArcaneDangerButton"
		discard.text = "Discard"
		# No native tooltip: the row's dossier is already beside it, and a
		# second box at the pointer would sit on top of it.
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
		_watch(row, [head, pick, discard], func() -> Dictionary:
			return ImprintDossier.held(imprint_id)
		)
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
		apply.name = "Apply"
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
		var imprint_id := _selected
		_watch(line, [apply], func() -> Dictionary:
			return ImprintDossier.preview(imprint_id, candidate, _dossier)
		)


# ------------------------------------------------------------------ the dossier

## Shows `content` (an ImprintDossier dictionary) beside `row` while the
## pointer is over the row or one of `controls`, or while one of the buttons
## among them holds keyboard or pad focus. A Button stops the pointer, so the
## row alone never hears it enter one; each control reports for its row.
func _watch(row: Control, controls: Array, content: Callable) -> void:
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.set_meta(&"dossier", content)
	row.mouse_entered.connect(_on_row_entered.bind(row))
	row.mouse_exited.connect(_on_row_exited.bind(row))
	for value in controls:
		var control := value as Control
		if control is Container:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
		control.mouse_entered.connect(_on_row_entered.bind(row))
		control.mouse_exited.connect(_on_row_exited.bind(row))
		if control is BaseButton:
			control.focus_entered.connect(_on_row_focused.bind(row, control))
			control.focus_exited.connect(_on_row_unfocused.bind(row))


func _on_row_entered(row: Control) -> void:
	if row != _dossier_row or not _dossier.visible:
		_show_dossier(row)


## Leaving the row for one of its own buttons is not leaving it; the check
## waits for the control being entered to report first.
func _on_row_exited(row: Control) -> void:
	_recheck.call_deferred(row)


## Focus from the pointer is hidden (Control.has_focus(true) is false for it)
## and the hover already shows the row; only a visible focus, a pad's or a
## keyboard's, shows a dossier of its own.
func _on_row_focused(row: Control, control: Control) -> void:
	if control.has_focus(true):
		_show_dossier(row)


func _on_row_unfocused(row: Control) -> void:
	_recheck.call_deferred(row)


## After the pointer or focus left `row`: keep its dossier if the pointer is
## still over the row, else show the row a visible focus is in, else hide.
## Untyped: a rebuild may have freed the row by the time this runs.
func _recheck(row: Variant) -> void:
	if not is_instance_valid(row) or row != _dossier_row:
		return
	if _row_hovered(row as Control):
		return
	var focused := _focused_row()
	if focused != null:
		if focused != row:
			_show_dossier(focused)
		return
	_hide_dossier()


func _row_hovered(row: Control) -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and (hovered == row or row.is_ancestor_of(hovered))


## The row whose button holds a visible focus, if any.
func _focused_row() -> Control:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or not focus_owner.has_focus(true) or not _root.is_ancestor_of(focus_owner):
		return null
	var node: Node = focus_owner
	while node != null and node != _root:
		if node.has_meta(&"dossier"):
			return node as Control
		node = node.get_parent()
	return null


func _show_dossier(row: Control) -> void:
	if _dossier == null or not is_instance_valid(row) or not row.is_inside_tree() or row.is_queued_for_deletion():
		return
	var make: Callable = row.get_meta(&"dossier")
	var content: Dictionary = make.call()
	if content.is_empty():
		_hide_dossier()
		return
	_dossier_row = row
	var lines: Array[String] = content["lines"]
	_dossier.show_lines(
		String(content["title"]),
		String(content["meta"]),
		content["meta_colour"],
		String(content["kicker"]),
		lines,
		content.get("icon", null) as Texture2D,
		int(content.get("rarity", 0)),
		DOSSIER_WIDTH
	)
	_place_dossier()


## Beside the row, never over it: right of it, or left where the right edge
## has no room, held on screen top and bottom (ItemTooltip.place_beside()).
## ItemTooltip already widens a tall dossier; one still taller than the
## screen at twice its width is drawn smaller rather than cut off.
func _place_dossier() -> void:
	if _dossier == null or not _dossier.visible or not is_instance_valid(_dossier_row):
		return
	var screen := get_viewport().get_visible_rect()
	var room := screen.size.y - 2.0 * ItemTooltip.SCREEN_MARGIN
	var shrink := minf(1.0, room / maxf(1.0, _dossier.size.y))
	_dossier.scale = Vector2(shrink, shrink)
	_dossier.place_beside(_dossier_row.get_global_rect(), screen)


## A scrolled list moves the row under its dossier; follow it once the list
## has re-sorted (the sort is deferred, so this is too).
func _on_list_scrolled(_value: float) -> void:
	_place_dossier.call_deferred()


func _hide_dossier() -> void:
	_dossier_row = null
	if _dossier != null:
		_dossier.hide_tooltip()


## Where focus is inside the lists, by the names a rebuild gives back:
## {row, control, visible}, or {} when it is elsewhere.
func _focus_record() -> Dictionary:
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focus_owner == null or not (_imprint_list.is_ancestor_of(focus_owner) or _item_list.is_ancestor_of(focus_owner)):
		return {}
	var node: Node = focus_owner
	while node != null and not node.has_meta(&"dossier"):
		node = node.get_parent()
	if node == null:
		return {}
	return {"row": String(node.name), "control": String(focus_owner.name), "visible": focus_owner.has_focus(true)}


## Puts focus back on the rebuilt twin of the control that held it, or on
## the chosen imprint's button when that control is gone (an applied item's
## row, a discarded imprint). Visible again only if it was visible before.
func _restore_focus(record: Dictionary) -> void:
	if record.is_empty():
		return
	var target: Button = null
	for list: Control in [_imprint_list, _item_list]:
		var row := list.get_node_or_null(String(record["row"])) as Control
		if row != null and not row.is_queued_for_deletion():
			target = row.find_child(String(record["control"]), true, false) as Button
			break
	if target == null or target.disabled:
		var chosen := _imprint_list.get_node_or_null("Imprint_%s" % String(_selected))
		target = chosen.find_child("Pick", true, false) as Button if chosen != null else null
	if target != null:
		target.grab_focus(not bool(record["visible"]))


func _slot_names(slots: Array) -> String:
	var names := PackedStringArray()
	for slot in slots:
		var key: Variant = ItemData.EquipSlot.find_key(int(slot))
		names.append(String(key).capitalize() if key != null else str(slot))
	return ", ".join(names)
