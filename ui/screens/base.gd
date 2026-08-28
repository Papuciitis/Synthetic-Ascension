extends Control

@export var race_card_scene: PackedScene
@export var style_card_scene: PackedScene

@onready var races_grid: GridContainer = find_child("RacesGrid", true, false) as GridContainer
@onready var styles_box: HBoxContainer = find_child("StylesGrid", true, false) as HBoxContainer
@onready var back_btn: Button = find_child("BackToSaves", true, false) as Button
@onready var start_btn: Button = find_child("StartRun", true, false) as Button
@onready var mortal_name_edit: LineEdit = find_child("MortalName", true, false) as LineEdit
@onready var replay_opening_toggle: CheckButton = find_child("ReplayOpening", true, false) as CheckButton

var race_group := ButtonGroup.new()
var style_group := ButtonGroup.new()

var selected_race: RaceData
var selected_style: StyleData

# --- tiny UI feel tuning ---
const BTN_HOVER_SCALE := Vector2(1.03, 1.03)
const BTN_PRESS_SCALE := Vector2(0.98, 0.98)

func _ready() -> void:
	if races_grid == null:
		push_error("RacesGrid not found. Check base.tscn node name.")
		return
	if styles_box == null:
		push_error("StylesGrid not found OR not an HBoxContainer. Check base.tscn node name/type.")
		return

	if race_card_scene == null:
		push_error("race_card_scene is not assigned on base.tscn")
		return
	if style_card_scene == null:
		push_error("style_card_scene is not assigned on base.tscn")
		return

	race_group.allow_unpress = false
	style_group.allow_unpress = false

	# Buttons: tactile + cursor
	_setup_button_fx(back_btn)
	_setup_button_fx(start_btn)
	if mortal_name_edit != null:
		mortal_name_edit.text = Global.mortal_name
		mortal_name_edit.text_changed.connect(func(_value: String) -> void: _update_start_state())
	if replay_opening_toggle != null:
		replay_opening_toggle.button_pressed = Global != null and Global.opening_replay_full_next_run
		replay_opening_toggle.visible = Global != null and Global.opening_full_intro_seen
		replay_opening_toggle.toggled.connect(_on_replay_opening_toggled)

	_populate_races(race_card_scene)
	_populate_styles(style_card_scene)

	if back_btn != null and not back_btn.pressed.is_connected(_on_back_to_saves_pressed):
		back_btn.pressed.connect(_on_back_to_saves_pressed)

	if start_btn != null and not start_btn.pressed.is_connected(_on_start_run_pressed):
		start_btn.pressed.connect(_on_start_run_pressed)

	_update_start_state()


# ============================================================
# Populate
# ============================================================

func _populate_races(race_scene: PackedScene) -> void:
	_clear_children(races_grid)

	var keys: Array = Global.race_db.keys()
	keys.sort()

	for k in keys:
		var id: String = String(k)
		var rd: RaceData = Global.race_db.get(id, null) as RaceData
		if rd == null:
			continue

		var card: Button = race_scene.instantiate() as Button
		card.toggle_mode = true
		card.button_group = race_group

		var display_name: String = _get_display_name(rd, id)

		races_grid.add_child(card)

		# Don’t trust set_data; still call it if present, but ALSO force labels from here.
		_apply_card_data(card, display_name, rd)

		var rd_local: RaceData = rd
		var name_local: String = display_name
		card.pressed.connect(func() -> void:
			card.button_pressed = true
			selected_race = rd_local
			print("Selected race:", name_local)
			_commit_selection()
		)

	# auto-select first
	if races_grid.get_child_count() > 0:
		(races_grid.get_child(0) as Button).emit_signal("pressed")


func _populate_styles(style_scene: PackedScene) -> void:
	_clear_children(styles_box)

	var keys: Array = Global.style_db.keys()
	keys.sort()

	for k in keys:
		var id: String = String(k)
		var sd: StyleData = Global.style_db.get(id, null) as StyleData
		if sd == null:
			continue

		var display_name: String = _get_display_name(sd, id)

		# Wrapper (playstyle name above its card)
		var wrapper := VBoxContainer.new()
		wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
		wrapper.add_theme_constant_override("separation", 6)

		var card: Button = style_scene.instantiate() as Button
		card.toggle_mode = true
		card.button_group = style_group
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		wrapper.add_child(label)
		wrapper.add_child(card)
		styles_box.add_child(wrapper)

		# Keep the inside title as “Base stats” vibe, but stats come from StyleData.
		_apply_card_data(card, "Base stats", sd)

		var sd_local: StyleData = sd
		var name_local: String = display_name
		card.pressed.connect(func() -> void:
			card.button_pressed = true
			selected_style = sd_local
			print("Selected style:", name_local)
			_commit_selection()
		)

	# auto-select first
	if styles_box.get_child_count() > 0:
		var first_wrapper := styles_box.get_child(0) as VBoxContainer
		var first_card := first_wrapper.get_child(1) as Button
		first_card.emit_signal("pressed")


# ============================================================
# Selection / Start
# ============================================================

func _commit_selection() -> void:
	if selected_race != null:
		Global.selected_race_id = selected_race.id
	if selected_style != null:
		Global.selected_style_id = selected_style.id
		Global.selected_weapon_id = selected_style.id

	# Optional: store in tree meta so Global.sync_run_selection_from_tree_meta can pull it too
	var tree := get_tree()
	tree.set_meta("run_race_id", Global.selected_race_id)
	tree.set_meta("run_style_id", Global.selected_style_id)

	print("COMMIT -> Global race:", Global.selected_race_id, " style:", Global.selected_style_id, " weapon:", Global.selected_weapon_id)
	_update_start_state()


func _update_start_state() -> void:
	if start_btn == null:
		return
	var has_name: bool = mortal_name_edit != null and mortal_name_edit.text.strip_edges() != ""
	var ok: bool = (selected_race != null and selected_style != null and has_name)
	start_btn.disabled = not ok
	start_btn.modulate = Color(1, 1, 1, 1.0 if ok else 0.55)


# ============================================================
# Card data (no hard paths; RaceCard.gd / PlaystyleCard.gd own the card scripts)
# ============================================================

func _apply_card_data(card: Button, title: String, data: Resource) -> void:
	if card == null:
		return

	# If the card script has set_data, call it (nice if it also sets images later).
	if card.has_method("set_data"):
		# (title, resource) matches how you were calling it before
		card.call_deferred("set_data", title, data)

	# Force the text/values anyway (fixes your “all +0 / all Human” symptom)
	_set_label_text(card, "%NameLabel", title)

	# Some resources store stats directly; some store them in a "mods" subresource (like SetTier -> StatDelta)
	var src: Object = data
	if data != null and _has_prop(data, &"mods"):
		var mods_v: Variant = data.get("mods")
		var mods_res: Resource = mods_v as Resource
		if mods_res != null:
			src = mods_res

	# Grab values using common property name variants
	var hp: float = _get_first_number(src, PackedStringArray(["hp_add", "hp", "health_add", "health"]))
	var arm: float = _get_first_number(src, PackedStringArray(["armor_add", "arm_add", "armor", "armour_add"]))
	var spd: float = _get_first_number(src, PackedStringArray(["speed_add", "move_speed", "spd_add", "speed"]))

	var pow_v: float = _get_first_number(src, PackedStringArray(["pow_add", "power_add", "power", "pow"]))
	var hst_v: float = _get_first_number(src, PackedStringArray(["haste_add", "haste", "attack_speed", "atk_speed"]))
	var lck_v: float = _get_first_number(src, PackedStringArray(["luck_add", "luck", "lck_add", "lck"]))

	_set_label_text(card, "%HPValue", _fmt_signed_int(hp))
	_set_label_text(card, "%ARMValue", _fmt_signed_int(arm))
	_set_label_text(card, "%SPDValue", _fmt_signed_int(spd))

	_set_label_text(card, "%POWValue", _fmt_signed_percent(pow_v))
	_set_label_text(card, "%HSTValue", _fmt_signed_percent(hst_v))
	_set_label_text(card, "%LCKValue", _fmt_signed_percent(lck_v))


func _set_label_text(root: Node, path: String, text: String) -> void:
	var n: Node = root.get_node_or_null(path)
	var l: Label = n as Label
	if l != null:
		l.text = text


func _get_first_number(obj: Object, names: PackedStringArray) -> float:
	if obj == null:
		return 0.0

	for prop_name in names:
		var prop: StringName = StringName(prop_name)
		if _has_prop(obj, prop):
			var v: Variant = obj.get(prop)
			if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
				return float(v)

	return 0.0

func _fmt_signed_int(v: float) -> String:
	var i: int = int(round(v))
	return ("%+d" % i)


func _fmt_signed_percent(v: float) -> String:
	# If you store as fraction (0.13), show 13%. If you store as 13, show 13%.
	var pct: float = v
	if absf(pct) <= 2.0:
		pct *= 100.0
	var i: int = int(round(pct))
	return ("%+d%%" % i)


# ============================================================
# Button tactile feel
# ============================================================

func _setup_button_fx(btn: Button) -> void:
	if btn == null:
		return

	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE

	# Set pivot after layout so scaling feels “centered”
	call_deferred("_set_btn_pivot_center", btn)

	if not btn.mouse_entered.is_connected(func() -> void: _btn_fx_hover(btn, true)):
		btn.mouse_entered.connect(func() -> void: _btn_fx_hover(btn, true))
	if not btn.mouse_exited.is_connected(func() -> void: _btn_fx_hover(btn, false)):
		btn.mouse_exited.connect(func() -> void: _btn_fx_hover(btn, false))

	if not btn.button_down.is_connected(func() -> void: _btn_fx_press(btn, true)):
		btn.button_down.connect(func() -> void: _btn_fx_press(btn, true))
	if not btn.button_up.is_connected(func() -> void: _btn_fx_press(btn, false)):
		btn.button_up.connect(func() -> void: _btn_fx_press(btn, false))


func _set_btn_pivot_center(btn: Control) -> void:
	if btn == null:
		return
	btn.pivot_offset = btn.size * 0.5



func _btn_fx_hover(btn: Control, on: bool) -> void:
	if btn == null:
		return
	if btn is BaseButton and (btn as BaseButton).disabled:
		return
	_btn_kill_tween(btn)
	var t := create_tween()
	btn.set_meta("_fx_tween", t)
	t.tween_property(btn, "scale", BTN_HOVER_SCALE if on else Vector2.ONE, 0.08)


func _btn_fx_press(btn: Control, down: bool) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	if btn is BaseButton and (btn as BaseButton).disabled:
		return
	if not btn.is_inside_tree():
		return
	if btn.get_viewport() == null:
		return

	_btn_kill_tween(btn)

	var t := create_tween()
	btn.set_meta("_fx_tween", t)
	t.set_trans(Tween.TRANS_QUAD)
	t.set_ease(Tween.EASE_OUT)

	var target: Vector2

	if down:
		target = BTN_PRESS_SCALE
	else:
		var local := btn.get_local_mouse_position()
		var inside := Rect2(Vector2.ZERO, btn.size).has_point(local)
		target = (BTN_HOVER_SCALE if inside else Vector2.ONE)

	t.tween_property(btn, "scale", target, 0.06)


func _btn_kill_tween(btn: Control) -> void:
	if btn.has_meta("_fx_tween"):
		var tw: Tween = btn.get_meta("_fx_tween") as Tween
		if tw != null:
			tw.kill()
		btn.set_meta("_fx_tween", null)


# ============================================================
# Misc helpers
# ============================================================

func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


func _get_display_name(res: Resource, fallback: String) -> String:
	if res != null and _has_prop(res, &"display_name"):
		var v: Variant = res.get("display_name")
		if typeof(v) == TYPE_STRING and String(v) != "":
			return String(v)
	return fallback


func _has_prop(obj: Object, prop: StringName) -> bool:
	for p in obj.get_property_list():
		if p.name == prop:
			return true
	return false


# ============================================================
# Buttons
# ============================================================

func _on_back_to_saves_pressed() -> void:
	Global.goto_save_select()


func _on_start_run_pressed() -> void:
	_commit_selection()
	if mortal_name_edit == null or mortal_name_edit.text.strip_edges() == "":
		return
	Global.mortal_name = mortal_name_edit.text.strip_edges()

	# Starting a new campaign attempt. (Die-die is the only thing that resets this.)
	if Global != null:
		Global.start_new_attempt()

	Global.goto_game()


func _on_replay_opening_toggled(enabled: bool) -> void:
	if Global == null:
		return
	Global.opening_replay_full_next_run = enabled
	Global.save_current_profile()
