extends CanvasLayer
class_name AscensionScreen
## The advancement tree screen: the radial map on the left, a node panel on
## the right with the authored rules, the price or the reason a purchase is
## refused, and the buttons for buying, refunding, equipping and toggling
## mutations. Opens from the Hub beside Augments and mid-run on the tree key.

signal closed()

const GATE_CORES: Array[String] = ["melee", "ranged", "magic"]

var view: AscensionTreeView = null
var _panel: VBoxContainer = null
var _header: Label = null
var _title: Label = null
var _meta: Label = null
var _rules: RichTextLabel = null
var _status: Label = null
var _buttons: HBoxContainer = null
var _gate_row: HBoxContainer = null
var _pause_on_close: bool = false
var _pause_was: bool = false
var _selected: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 165
	_build()
	_refresh_all()
	if Global != null and Global.has_signal("followers_changed"):
		Global.followers_changed.connect(func(_value: int) -> void: _refresh_all())


func open(pause_tree: bool = false) -> void:
	visible = true
	_pause_on_close = pause_tree
	if pause_tree and get_tree() != null:
		_pause_was = get_tree().paused
		get_tree().paused = true
	_refresh_all()


func close() -> void:
	if _pause_on_close and get_tree() != null:
		get_tree().paused = _pause_was
	visible = false
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"ascension_open"):
		close()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- build

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.025, 0.02, 0.96)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)
	var split := HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 0)
	root.add_child(split)

	view = AscensionTreeView.new()
	view.name = "TreeView"
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(view)
	view.node_hovered.connect(_on_hovered)
	view.node_clicked.connect(_on_clicked)

	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(360, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(side)
	var margin := MarginContainer.new()
	for edge in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(edge, 14)
	side.add_child(margin)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 8)
	margin.add_child(_panel)

	_header = Label.new()
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.add_theme_font_size_override("font_size", 12)
	_panel.add_child(_header)
	_panel.add_child(HSeparator.new())
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.text = "Select a node"
	_panel.add_child(_title)
	_meta = Label.new()
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta.add_theme_font_size_override("font_size", 11)
	_meta.modulate = Color(1, 1, 1, 0.7)
	_panel.add_child(_meta)
	_rules = RichTextLabel.new()
	_rules.bbcode_enabled = false
	_rules.fit_content = false
	_rules.scroll_active = true
	_rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rules.custom_minimum_size = Vector2(0, 160)
	_panel.add_child(_rules)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	_panel.add_child(_status)
	_gate_row = HBoxContainer.new()
	_panel.add_child(_gate_row)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	_panel.add_child(_buttons)
	_panel.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	_panel.add_child(footer)
	var fit_button := Button.new()
	fit_button.text = "Fit"
	fit_button.focus_mode = Control.FOCUS_NONE
	fit_button.pressed.connect(func() -> void: view.fit())
	footer.add_child(fit_button)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	footer.add_child(close_button)

	var layout := AscensionTreeLayout.new()
	layout.compute(AscensionTreeDB.shared())
	view.setup(AscensionTreeDB.shared(), layout)
	view.call_deferred("fit")


# ---------------------------------------------------------------- refresh

func _ledger() -> AscensionLedger:
	return Global.ascension_ledger() if Global != null else null


func _refresh_all() -> void:
	var ledger := _ledger()
	if ledger == null or view == null:
		return
	view.refresh(ledger, Global.followers)
	var cores := PackedStringArray()
	for core in ledger.cores():
		cores.append(String(core).to_upper())
	_header.text = "FOLLOWERS %d   ·   SPENT %d\nNATIVE %s   ·   CORES %s\nQ %s   ·   REACTION %s   ·   V %s" % [
		Global.followers, int(ledger.state.get("spent", 0)), ledger.native_core().to_upper(), " ".join(cores),
		_name_of(ledger.equipped("q")), _name_of(ledger.equipped("reaction")), _name_of(ledger.equipped("v"))]
	if not _selected.is_empty():
		_show(_selected)


func _name_of(id: String) -> String:
	if id.is_empty():
		return "-"
	return String(AscensionTreeDB.shared().node(id).get("name", id))


func _on_hovered(id: String) -> void:
	if _selected.is_empty() and not id.is_empty():
		_show(id)


func _on_clicked(id: String, button: int) -> void:
	_selected = id
	_show(id)
	if button == MOUSE_BUTTON_RIGHT:
		_refund(id)


func _show(id: String) -> void:
	var db := AscensionTreeDB.shared()
	var ledger := _ledger()
	if not db.has(id) or ledger == null:
		return
	var node := db.node(id)
	_title.text = String(node.get("name", id))
	var kind := db.kind(id)
	var discipline := db.discipline_of(id)
	var core := db.core_of(id)
	var parts := PackedStringArray([kind.replace("_", " ").to_upper()])
	if not discipline.is_empty():
		parts.append(discipline)
	if not core.is_empty():
		parts.append(core.to_upper())
	parts.append("ring %d" % db.ring_of(id))
	parts.append(id)
	_meta.text = "   ·   ".join(parts)
	_rules.text = String(node.get("rules", node.get("tooltip", "")))
	for child in _buttons.get_children():
		child.queue_free()
	for child in _gate_row.get_children():
		child.queue_free()
	var lines := PackedStringArray()
	if ledger.owns(id):
		if kind == "sink":
			lines.append("Rank %d owned. Next rank %d Followers." % [ledger.rank(id), ledger.price(id)])
		else:
			lines.append("Owned." + (" Equipped." if ledger.is_equipped(id) else ""))
	if kind == "gate" and not ledger.owns(id):
		var any_core := false
		for core_id in GATE_CORES:
			var verdict := ledger.can_buy(id, Global.followers, core_id)
			if bool(verdict["ok"]):
				any_core = true
				var gate_button := Button.new()
				gate_button.text = "Open %s (%d)" % [core_id.to_upper(), int(verdict["cost"])]
				gate_button.focus_mode = Control.FOCUS_NONE
				gate_button.pressed.connect(func() -> void: _buy(id, core_id))
				_gate_row.add_child(gate_button)
		if not any_core:
			lines.append(String(ledger.can_buy(id, Global.followers, _first_unopened(ledger))["reason"]))
	elif not ledger.owns(id) or kind == "sink":
		var verdict := ledger.can_buy(id, Global.followers)
		if bool(verdict["ok"]):
			var buy := Button.new()
			buy.text = "Buy" if int(verdict["cost"]) == 0 else "Buy for %d" % int(verdict["cost"])
			buy.focus_mode = Control.FOCUS_NONE
			buy.pressed.connect(func() -> void: _buy(id, ""))
			_buttons.add_child(buy)
		else:
			lines.append(String(verdict["reason"]).capitalize())
			if int(verdict["cost"]) == 0 and db.base_cost(id) > 0:
				lines.append("Price %d." % ledger.price(id))
	if ledger.owns(id):
		match kind:
			"active":
				_slot_button("q", id, "Equip Q", ledger)
				_slot_button("reaction", id, "Equip Reaction", ledger)
			"revelation":
				_slot_button("v", id, "Equip V", ledger)
			"keystone":
				_slot_button("keystones", id, "Equip Keystone", ledger)
			"axiom":
				_slot_button("axioms", id, "Equip Axiom", ledger)
			"mutation", "revelation_mutation":
				var disabled: bool = (ledger.state.get("disabled_mutations", []) as Array).has(id)
				var toggle := Button.new()
				toggle.text = "Enable" if disabled else "Disable"
				toggle.focus_mode = Control.FOCUS_NONE
				toggle.pressed.connect(func() -> void:
					ledger.set_mutation_enabled(id, disabled)
					_after_change())
				_buttons.add_child(toggle)
		if kind != "core" and kind != "gate" and kind != "choice":
			var refund := Button.new()
			refund.text = "Refund"
			refund.focus_mode = Control.FOCUS_NONE
			refund.tooltip_text = "Right-click a node to refund it and everything that depended on it."
			refund.pressed.connect(func() -> void: _refund(id))
			_buttons.add_child(refund)
	_status.text = "\n".join(lines)


func _first_unopened(ledger: AscensionLedger) -> String:
	for core_id in GATE_CORES:
		if not ledger.has_core(core_id):
			return core_id
	return "melee"


func _slot_button(slot: String, id: String, label: String, ledger: AscensionLedger) -> void:
	var button := Button.new()
	var equipped := ledger.equipped(slot) == id if slot in ["q", "v", "reaction"] else ledger.equipped_list(slot).has(id)
	button.text = "Unequip" if equipped else label
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not equipped and not ledger.can_equip(slot, id)
	button.pressed.connect(func() -> void:
		if equipped:
			ledger.unequip(slot, id)
		else:
			ledger.equip(slot, id)
		_after_change())
	_buttons.add_child(button)


func _buy(id: String, chosen_core: String) -> void:
	if Global == null:
		return
	var verdict := Global.ascension_buy(id, chosen_core)
	if not bool(verdict["ok"]):
		_status.text = String(verdict["reason"]).capitalize()
		return
	_after_change()


func _refund(id: String) -> void:
	if Global == null:
		return
	var back := Global.ascension_refund(id)
	if back > 0 or not _ledger().owns(id):
		_after_change()


func _after_change() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method("refresh_run_state"):
		player.call("refresh_run_state")
	if Global != null:
		Global.request_autosave()
	_refresh_all()
