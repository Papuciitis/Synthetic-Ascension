extends Control
## The Archives: three chronicle cards over the vigil painting.
##
## A card is selected by focus (click, arrows, controller); the selected card
## opens on a second click, Enter or accept. Opening an empty slot creates its
## profile; opening an unreadable one never does (see SaveCard). Rename and
## Erase go through ArcaneDialog, and Erase asks first. The world's mood
## follows the selected card.

const SLOT_COUNT: int = 3
const ArcaneDialogScript := preload("res://ui/components/ArcaneDialog.gd")

## Why the Archives were opened: &"new" (New Run) selects the first free slot,
## &"browse" (Archives, Continue with nothing to continue) the latest save.
## Read once on entry and reset, so other routes here default to browsing.
static var open_intent: StringName = &"browse"

@onready var title: Label = find_child("Title", true, false) as Label
@onready var subtitle: Label = find_child("Subtitle", true, false) as Label
@onready var grid: GridContainer = find_child("GridContainer", true, false) as GridContainer
@onready var back: Button = find_child("Back", true, false) as Button
@onready var backdrop: Control = get_node_or_null("Backdrop") as Control
@onready var curtain: ColorRect = get_node_or_null("Curtain") as ColorRect
@onready var margin: MarginContainer = get_node_or_null("Margin") as MarginContainer

var selected_slot: int = 0
var intent: StringName = &"browse"

var _sm: Node = null

var _rename_slot: int = 0
var _delete_slot_pending: int = 0
var _rename_dialog: Control = null
var _delete_dialog: Control = null


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	intent = open_intent
	open_intent = &"browse"

	if title != null:
		title.text = "NEW RUN" if intent == &"new" else "ARCHIVES"
	if subtitle != null:
		subtitle.text = "Choose where the new chronicle begins." if intent == &"new" else "Every chronicle the Pattern remembers."

	if back != null:
		back.pressed.connect(func() -> void:
			if not _dialog_open():
				Global.goto_main_menu()
		)
		# BACK takes focus on hover (every menu entry does); passing over it must
		# not leave Enter pointed at the exit instead of the chosen chronicle.
		back.mouse_exited.connect(func() -> void:
			if back.has_focus() and not _dialog_open():
				_refocus_selected()
		)

	_sm = get_node_or_null("/root/SaveManager") as Node
	if _sm == null:
		push_warning("SaveManager autoload not found at /root/SaveManager. Rename won't persist until you add one.")

	_ensure_dialogs()
	_wire_cards()
	_refresh_ui()

	selected_slot = _pick_default_slot()
	_apply_selection_visuals()
	_play_intro()
	resized.connect(_fit_to_viewport)
	_fit_to_viewport.call_deferred()


## At a large UI Scale the logical viewport shrinks below the three tall cards
## (1280 x 720 at 150 %); the whole Archives scale down to stay on screen.
func _fit_to_viewport() -> void:
	if margin == null:
		return
	var room := size
	var need := margin.get_combined_minimum_size()
	var k := minf(1.0, minf(room.x / maxf(need.x, 1.0), room.y / maxf(need.y, 1.0)))
	if k >= 0.999:
		margin.scale = Vector2.ONE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.scale = Vector2.ONE * k
	margin.position = Vector2.ZERO
	margin.size = room / k


func _pick_default_slot() -> int:
	if intent == &"new":
		for slot in range(1, SLOT_COUNT + 1):
			if not _has_save(slot):
				return slot
	var best := 0
	var best_time := -1
	for slot in range(1, SLOT_COUNT + 1):
		var s: SaveData = _load_slot(slot)
		if s == null:
			continue
		var written := s.updated_unix if s.updated_unix > 0 else _modified_time(slot)
		if written > best_time:
			best_time = written
			best = slot
	return best if best > 0 else 1


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

		if card.has_signal("focused"):
			card.connect("focused", Callable(self, "_on_card_focused").bind(slot))

		if card.has_signal("delete_requested"):
			card.connect("delete_requested", Callable(self, "_request_delete").bind(slot))

		if card.has_signal("rename_requested"):
			card.connect("rename_requested", Callable(self, "_on_rename_pressed").bind(slot))


func _on_card_focused(slot: int) -> void:
	# A card behind an open dialog must not open, create or re-aim a slot.
	if _dialog_open():
		return
	if selected_slot == slot:
		return
	selected_slot = slot
	_apply_selection_visuals()


func _on_card_pressed(slot: int) -> void:
	# A card behind an open dialog must not open, create or re-aim a slot.
	if _dialog_open():
		return
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
	# BACK leads back up to the chronicle that was chosen, not always to Card 1.
	var chosen := _card(selected_slot)
	if back != null and chosen != null:
		back.focus_neighbor_top = back.get_path_to(chosen)
		back.focus_neighbor_right = back.get_path_to(chosen)
	if backdrop != null and backdrop.has_method("set_mood"):
		var mood := &"arcane"
		if _load_slot(selected_slot) != null:
			mood = &"hearth"
		elif _has_save(selected_slot):
			mood = &"dusk"
		backdrop.call("set_mood", mood)


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


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _dialog_open():
		return
	get_viewport().set_input_as_handled()
	Global.goto_main_menu()


func _dialog_open() -> bool:
	return (_rename_dialog != null and _rename_dialog.visible) or (_delete_dialog != null and _delete_dialog.visible)


func _play_intro() -> void:
	var reduced := bool(backdrop.get("reduced_motion")) if backdrop != null else false
	if curtain != null:
		curtain.visible = true
		curtain.color.a = 1.0
		var fade := create_tween()
		fade.tween_property(curtain, "color:a", 0.0, 0.5 if reduced else 0.9).set_trans(Tween.TRANS_SINE)
		fade.tween_callback(func() -> void: curtain.visible = false)
	var delay := 0.25
	for slot in range(1, SLOT_COUNT + 1):
		var card := _card(slot)
		if card == null:
			continue
		card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(card, "modulate:a", 1.0, 0.4 if reduced else 0.55).set_trans(Tween.TRANS_SINE)
		delay += 0.0 if reduced else 0.12
	var focus := create_tween()
	focus.tween_interval(delay)
	focus.tween_callback(func() -> void:
		var card := _card(selected_slot)
		if card != null and get_viewport().gui_get_focus_owner() == null:
			card.grab_focus()
	)


# ---------------------------------------------------------------------------
# Rename / Erase
# ---------------------------------------------------------------------------

func _ensure_dialogs() -> void:
	_rename_dialog = ArcaneDialogScript.new()
	_rename_dialog.name = "RenameDialog"
	add_child(_rename_dialog)
	_rename_dialog.connect("confirmed", _on_rename_confirmed)
	_rename_dialog.connect("cancelled", _refocus_selected)
	_delete_dialog = ArcaneDialogScript.new()
	_delete_dialog.name = "EraseDialog"
	add_child(_delete_dialog)
	_delete_dialog.connect("confirmed", func(_text: String) -> void:
		if _delete_slot_pending > 0:
			_on_delete_pressed(_delete_slot_pending)
		_delete_slot_pending = 0
		_refocus_selected()
	)
	_delete_dialog.connect("cancelled", func() -> void:
		_delete_slot_pending = 0
		_refocus_selected()
	)


func _refocus_selected() -> void:
	var card := _card(selected_slot)
	if card != null:
		card.call_deferred("grab_focus")


func _request_delete(slot: int) -> void:
	# A card behind an open dialog must not open, create or re-aim a slot.
	if _dialog_open():
		return
	if not _has_save(slot):
		return
	_delete_slot_pending = slot
	var s: SaveData = _load_slot(slot)
	var who := "this chronicle"
	if s != null:
		var shown := s.mortal_name.strip_edges() if s.mortal_name.strip_edges() != "" else s.profile_name.strip_edges()
		if shown != "":
			who = shown
	_delete_dialog.call("present", "ERASE CHRONICLE", "Erase %s? Everything this chronicle carries is lost, and it cannot be undone." % who, "Erase", "Keep", true)


func _on_delete_pressed(slot: int) -> void:
	_delete_slot(slot)
	_refresh_ui()

	if selected_slot == slot:
		selected_slot = _pick_default_slot()
	_apply_selection_visuals()


func _on_rename_pressed(slot: int) -> void:
	# A card behind an open dialog must not open, create or re-aim a slot.
	if _dialog_open():
		return
	var s: SaveData = _load_slot(slot)
	if s == null:
		return

	_rename_slot = slot
	var current := s.mortal_name if s.mortal_name.strip_edges() != "" else s.profile_name
	_rename_dialog.call("present", "RENAME CHRONICLE", "The name this chronicle is remembered by.", "Rename", "Cancel", false, current)


func _on_rename_confirmed(new_name: String) -> void:
	if _rename_slot <= 0:
		return

	new_name = new_name.strip_edges()
	if new_name == "":
		return

	var s: SaveData = _load_slot(_rename_slot)
	if s == null:
		return

	s.mortal_name = new_name
	# Keep the legacy profile field in sync for older screens and recovered saves.
	s.profile_name = new_name
	# A rename is not play: Continue keeps resuming the chronicle last played.
	_save_slot(s, false)

	_refresh_ui()
	_apply_selection_visuals()
	_refocus_selected()


# ---------------------------------------------------------------------------
# SaveManager access
# ---------------------------------------------------------------------------

func _has_save(slot: int) -> bool:
	if _sm != null and _sm.has_method("has_save"):
		return bool(_sm.call("has_save", slot))
	return false


func _modified_time(slot: int) -> int:
	if _sm != null and _sm.has_method("slot_modified_time"):
		return int(_sm.call("slot_modified_time", slot))
	return 0


func _load_slot(slot: int) -> SaveData:
	if _sm != null and _sm.has_method("load_slot"):
		var v: Variant = _sm.call("load_slot", slot)
		return v as SaveData
	return null


func _save_slot(s: SaveData, stamp_time: bool = true) -> void:
	if _sm != null and _sm.has_method("save_slot"):
		_sm.call("save_slot", s, true, stamp_time)


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
