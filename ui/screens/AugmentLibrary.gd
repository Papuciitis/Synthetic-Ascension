extends CanvasLayer
class_name AugmentLibraryScreen

signal closed()

@export var entry_scene: PackedScene
@export var slot_scene: PackedScene

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Center/Panel
@onready var search: LineEdit = $Center/Panel/Margin/VBox/HBox/Left/Search
@onready var owned_label: Label = $Center/Panel/Margin/VBox/HBox/Left/Owned
@onready var list_box: VBoxContainer = $Center/Panel/Margin/VBox/HBox/Left/Scroll/Margin/List
@onready var slots_box: VBoxContainer = $Center/Panel/Margin/VBox/HBox/Right/Slots
@onready var hint: Label = $Center/Panel/Margin/VBox/HBox/Right/Hint
@onready var btn_close: Button = $Center/Panel/Margin/VBox/Header/BtnClose

var _filter_q: String = ""
var _slot_widgets: Array[AugmentEquipSlot] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 160
	if overlay:
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay.color = Color(0,0,0,0.55)

	if btn_close:
		btn_close.pressed.connect(_close)
	if overlay:
		overlay.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
				_close()
		)
	if search:
		search.text_changed.connect(func(t: String) -> void:
			_filter_q = t.strip_edges().to_lower()
			_rebuild_library()
		)

	_build_slots()
	_rebuild_library()
	_refresh_slots()

	# keep UI in sync if something changes elsewhere
	if Global != null and Global.has_signal("permanent_augments_changed"):
		if not Global.permanent_augments_changed.is_connected(_on_perm_changed):
			Global.permanent_augments_changed.connect(_on_perm_changed)

func _on_perm_changed(_arr: Array) -> void:
	_refresh_slots()

func open() -> void:
	visible = true

func _close() -> void:
	visible = false
	closed.emit()
	queue_free()

# ------------------------------------------------------------
# Slots
# ------------------------------------------------------------

func _build_slots() -> void:
	if slot_scene == null:
		push_warning("AugmentLibrary: slot_scene missing")
		return
	for c in slots_box.get_children():
		c.queue_free()
	_slot_widgets.clear()

	for i in range(3):
		var w := slot_scene.instantiate() as AugmentEquipSlot
		slots_box.add_child(w)
		w.slot_index = i
		w.key_text = str(i+1)
		w.drop_received.connect(_on_slot_drop)
		w.unequip_requested.connect(_on_slot_unequip)
		w.lock_toggled.connect(_on_slot_lock_toggled)
		_slot_widgets.append(w)

func _refresh_slots() -> void:
	if Global == null:
		return
	Global.init_permanent_augments()

	# Apply lock state
	for i in range(mini(3, _slot_widgets.size())):
		var locked := false
		if Global.has_method("is_augment_slot_locked"):
			locked = bool(Global.call("is_augment_slot_locked", i))
		_slot_widgets[i].set_locked(locked)

	# Apply content
	for i in range(mini(3, _slot_widgets.size())):
		var sid: StringName = Global.permanent_augment_ids[i]
		var ad: AugmentData = Global.augment_db.get(sid, null) as AugmentData
		_slot_widgets[i].set_data(ad)

func _on_slot_lock_toggled(slot: int, locked: bool) -> void:
	if Global == null:
		return
	if Global.has_method("set_augment_slot_locked"):
		Global.call("set_augment_slot_locked", slot, locked)
	_refresh_slots()

# ------------------------------------------------------------
# Library list
# ------------------------------------------------------------

func _rebuild_library() -> void:
	if list_box == null:
		return
	for c in list_box.get_children():
		c.queue_free()

	if Global == null:
		return

	Global.init_permanent_augments()
	if Global.has_method("init_owned_augments"):
		Global.init_owned_augments()

	var owned: Array = []
	if Global.has_method("get_owned_augment_ids"):
		owned = Global.get_owned_augment_ids()
	else:
		owned = Global.permanent_augment_ids.duplicate()

	# Use OWNED ORDER (so reordering matters)
	var shown := 0
	var total := 0

	for idx in range(owned.size()):
		var id: StringName = owned[idx]
		if id == StringName():
			continue
		total += 1

		var a2: AugmentData = Global.augment_db.get(id, null) as AugmentData
		if a2 == null:
			continue

		if _filter_q != "":
			var hay := (a2.display_name + " " + String(a2.id) + " " + a2.description + " " + a2.card_blurb + " " + a2.details).to_lower()
			if hay.find(_filter_q) == -1:
				continue

		var entry := entry_scene.instantiate() as AugmentLibraryEntry
		list_box.add_child(entry)

		# Reorder only when not filtering (keeps index math sane)
		entry.allow_reorder = (_filter_q == "")
		entry.owned_index = idx

		var tags := _compute_tags(a2)
		entry.set_data(a2, tags)
		entry.requested_equip.connect(_on_entry_quick_equip)
		entry.request_reorder.connect(_on_entry_reorder)
		shown += 1

	if owned_label:
		owned_label.text = "Owned augments: %d  (shown %d)" % [total, shown]

func _on_entry_reorder(from_i: int, to_i: int) -> void:
	if Global == null:
		return
	if _filter_q != "":
		return
	if Global.has_method("move_owned_augment"):
		Global.call("move_owned_augment", from_i, to_i)
	_rebuild_library()

# Stronger tagging: keyword scoring based on selected style + active detection.
func _compute_tags(a: AugmentData) -> PackedStringArray:
	var out := PackedStringArray()
	if a == null or Global == null:
		return out

	var style := String(Global.selected_style_id).to_lower()
	var txt := (String(a.id) + " " + a.display_name + " " + a.description + " " + a.card_blurb + " " + a.details).to_lower()

	var score := 0
	if style == "ranged":
		for k in ["ranged","projectile","missile","shot","aim","haste","speed","blink","dash","kite"]:
			if txt.find(k) != -1:
				score += 1
	elif style == "melee":
		for k in ["melee","slash","strike","blade","stamina","armor","lifesteal","block","parry","charge"]:
			if txt.find(k) != -1:
				score += 1
	elif style == "magic":
		for k in ["magic","spell","arcane","tesla","summon","orb","beam","hex","mana","sigil"]:
			if txt.find(k) != -1:
				score += 1

	# Extra: style-specific known anchors
	var idl := String(a.id).to_lower()
	if style == "ranged" and (idl.find("missile") != -1 or idl.find("blink") != -1):
		score += 2
	if style == "melee" and (idl.find("slash") != -1 or idl.find("stamina") != -1):
		score += 2
	if style == "magic" and (idl.find("tesla") != -1 or idl.find("summon") != -1 or idl.find("blink") != -1):
		score += 2

	if score >= 3:
		out.append("RECOMMENDED")
		out.append("STYLE " + style.to_upper())

	# Active marker (if any effect scene has exported active_action)
	var active := false
	for scn in a.effect_scenes:
		if scn == null:
			continue
		var inst := scn.instantiate()
		if inst != null and inst.get("active_action") != null:
			active = true
		inst.free()
		if active:
			break
	if active:
		out.append("ACTIVE")

	return out

# ------------------------------------------------------------
# Equip / drop behavior
# ------------------------------------------------------------

func _on_entry_quick_equip(id: StringName) -> void:
	# Double-click / click: equip into first EMPTY + UNLOCKED slot.
	if Global == null:
		return
	Global.init_permanent_augments()

	# One slot per augment id. The drag path resolves duplicates by swapping;
	# quick-equip has no target slot, so re-clicking an equipped augment is a
	# no-op (a free repeatable level-up here would be an exploit).
	if Global.permanent_augment_ids.find(id) != -1:
		return

	var chosen := -1
	for i in range(3):
		var is_locked := false
		if Global.has_method("is_augment_slot_locked"):
			is_locked = bool(Global.call("is_augment_slot_locked", i))
		if is_locked:
			continue
		if Global.permanent_augment_ids[i] == StringName():
			chosen = i
			break

	# If no empty unlocked slot, overwrite first unlocked slot (usually slot 0)
	if chosen == -1:
		for j in range(3):
			var is_locked2 := false
			if Global.has_method("is_augment_slot_locked"):
				is_locked2 = bool(Global.call("is_augment_slot_locked", j))
			if not is_locked2:
				chosen = j
				break

	if chosen == -1:
		# all locked; do nothing
		return

	_equip_to_slot(chosen, id)

func _on_slot_unequip(slot: int) -> void:
	if Global == null:
		return
	Global.set_permanent_augment(slot, StringName())
	_refresh_slots()

func _on_slot_drop(slot: int, data: Dictionary) -> void:
	if Global == null:
		return
	if not data.has("augment_id"):
		return
	var id: StringName = data["augment_id"]
	if id == StringName():
		return

	# Locked slots reject drops at widget-level, but keep a safe guard.
	if Global.has_method("is_augment_slot_locked") and bool(Global.call("is_augment_slot_locked", slot)):
		return

	# If dragging from another slot, swap.
	var src: StringName = data.get("source", &"")
	if src == &"slot":
		var src_slot: int = int(data.get("slot", -1))
		if src_slot == slot:
			return
		_swap_slots(src_slot, slot)
		return

	# From library: if already equipped somewhere else, swap positions; else equip directly.
	Global.init_permanent_augments()
	var already: int = Global.permanent_augment_ids.find(id)
	if already != -1 and already != slot:
		_swap_slots(already, slot)
		return

	_equip_to_slot(slot, id)

func _equip_to_slot(slot: int, id: StringName) -> void:
	if Global == null:
		return
	# ensure owned list contains it
	if Global.has_method("add_owned_augment"):
		Global.add_owned_augment(id)
	Global.set_permanent_augment(slot, id)
	_refresh_slots()
	_rebuild_library()

func _swap_slots(a: int, b: int) -> void:
	if Global == null:
		return
	Global.init_permanent_augments()
	if a < 0 or b < 0 or a >= 3 or b >= 3:
		return

	# respect locks: can't move into/out of locked slots
	if Global.has_method("is_augment_slot_locked"):
		if bool(Global.call("is_augment_slot_locked", a)) or bool(Global.call("is_augment_slot_locked", b)):
			return

	var tmp: StringName = Global.permanent_augment_ids[a]
	Global.permanent_augment_ids[a] = Global.permanent_augment_ids[b]
	Global.permanent_augment_ids[b] = tmp

	if Global.has_signal("permanent_augments_changed"):
		Global.permanent_augments_changed.emit(Global.permanent_augment_ids)
	Global.request_autosave()
	_refresh_slots()
