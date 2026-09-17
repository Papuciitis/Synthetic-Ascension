extends Control

const SLOT_COUNT: int = 3

@onready var title: Label = find_child("Title", true, false) as Label
@onready var grid: GridContainer = find_child("GridContainer", true, false) as GridContainer
@onready var back: Button = find_child("Back", true, false) as Button

var selected_slot: int = 0

var _sm: Node = null

var _rename_slot: int = 0
var _rename_dialog: ConfirmationDialog = null
var _rename_input: LineEdit = null


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if title != null:
		title.text = "SELECT SAVE"

	if back != null:
		back.focus_mode = Control.FOCUS_NONE
		back.pressed.connect(func() -> void:
			Global.goto_main_menu()
		)

	_sm = get_node_or_null("/root/SaveManager") as Node
	if _sm == null:
		push_warning("SaveManager autoload not found at /root/SaveManager. Rename won't persist until you add one.")

	_ensure_rename_dialog()
	_wire_cards()
	_refresh_ui()

	selected_slot = _pick_default_slot()
	_apply_selection_visuals()


func _pick_default_slot() -> int:
	for slot in range(1, SLOT_COUNT + 1):
		if _load_slot(slot) != null:
			return slot
	return 1


func _card(slot: int) -> Control:
	if grid == null:
		return null
	return grid.get_child(slot - 1) as Control


func _wire_cards() -> void:
	if grid == null:
		push_error("GridContainer not found. Check SaveSelect.tscn node name.")
		return

	for slot in range(1, SLOT_COUNT + 1):
		var card: Control = _card(slot)
		if card == null:
			continue

		if card.has_signal("pressed"):
			card.connect("pressed", Callable(self, "_on_card_pressed").bind(slot))

		if card.has_signal("delete_requested"):
			card.connect("delete_requested", Callable(self, "_on_delete_pressed").bind(slot))

		if card.has_signal("rename_requested"):
			card.connect("rename_requested", Callable(self, "_on_rename_pressed").bind(slot))


func _on_card_pressed(slot: int) -> void:
	if selected_slot == slot:
		_on_slot_pressed(slot)
		return

	selected_slot = slot
	_apply_selection_visuals()


func _apply_selection_visuals() -> void:
	for slot in range(1, SLOT_COUNT + 1):
		var card: Control = _card(slot)
		if card != null and card.has_method("set_selected"):
			card.call("set_selected", slot == selected_slot)


func _refresh_ui() -> void:
	for slot in range(1, SLOT_COUNT + 1):
		var s: SaveData = _load_slot(slot)
		var card: Control = _card(slot)
		if card != null and card.has_method("set_slot_data"):
			card.call("set_slot_data", slot, s, s == null and _has_save(slot))


func _on_slot_pressed(slot: int) -> void:
	var s: SaveData = _load_slot(slot)
	if s == null and _has_save(slot):
		# The files exist but cannot be read. Creating a profile here would
		# overwrite them; deleting the slot is the player's deliberate choice.
		push_warning("Save slot %d exists but could not be read; not overwriting it." % slot)
		return
	if s == null:
		s = _create_slot(slot, "Profile %d" % slot)

	_set_current(slot, s)
	Global.goto_resume()


func _on_delete_pressed(slot: int) -> void:
	_delete_slot(slot)
	_refresh_ui()

	if selected_slot == slot:
		selected_slot = _pick_default_slot()
	_apply_selection_visuals()


func _ensure_rename_dialog() -> void:
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Rename Character"
	_rename_dialog.ok_button_text = "Rename"
	_rename_dialog.cancel_button_text = "Cancel"
	add_child(_rename_dialog)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_rename_dialog.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var hint: Label = Label.new()
	hint.text = "Enter the character name shown on this save:"
	vbox.add_child(hint)

	_rename_input = LineEdit.new()
	_rename_input.placeholder_text = "e.g. The Goblin Accountant"
	_rename_input.custom_minimum_size = Vector2(360, 32)
	vbox.add_child(_rename_input)

	_rename_dialog.confirmed.connect(_on_rename_confirmed)

	_rename_input.text_submitted.connect(func(_t: String) -> void:
		var ok_btn: Button = _rename_dialog.get_ok_button()
		if ok_btn != null:
			ok_btn.emit_signal("pressed")
	)


func _on_rename_pressed(slot: int) -> void:
	var s: SaveData = _load_slot(slot)
	if s == null:
		return

	_rename_slot = slot
	_rename_input.text = s.mortal_name if s.mortal_name.strip_edges() != "" else s.profile_name
	_rename_dialog.popup_centered()

	await get_tree().process_frame
	_rename_input.grab_focus()
	_rename_input.select_all()


func _on_rename_confirmed() -> void:
	if _rename_slot <= 0:
		return

	var new_name: String = _rename_input.text.strip_edges()
	if new_name == "":
		return

	var s: SaveData = _load_slot(_rename_slot)
	if s == null:
		return

	s.mortal_name = new_name
	# Keep the legacy profile field in sync for older screens and recovered saves.
	s.profile_name = new_name
	_save_slot(s)

	_refresh_ui()
	_apply_selection_visuals()


func _has_save(slot: int) -> bool:
	if _sm != null and _sm.has_method("has_save"):
		return bool(_sm.call("has_save", slot))
	return false


func _load_slot(slot: int) -> SaveData:
	if _sm != null and _sm.has_method("load_slot"):
		var v: Variant = _sm.call("load_slot", slot)
		return v as SaveData
	return null


func _save_slot(s: SaveData) -> void:
	if _sm != null and _sm.has_method("save_slot"):
		_sm.call("save_slot", s)


func _create_slot(slot: int, profile_name: String) -> SaveData:
	if _sm != null and _sm.has_method("create_slot"):
		var v: Variant = _sm.call("create_slot", slot, profile_name)
		return v as SaveData
	return null


func _delete_slot(slot: int) -> void:
	if _sm != null and _sm.has_method("delete_slot"):
		_sm.call("delete_slot", slot)


func _set_current(slot: int, s: SaveData) -> void:
	if _sm != null and _sm.has_method("set_current"):
		_sm.call("set_current", slot, s)
