extends CanvasLayer

signal augment_chosen(augment: AugmentData)

@export var card_scene: PackedScene

@onready var overlay: ColorRect = $Overlay
@onready var center: CenterContainer = $Center
@onready var cards_box: HBoxContainer = $Center/VBox/CardsPanel/CardsMargin/Cards

var _open_tw: Tween = null
var _is_open: bool = false
var _pending_open: bool = false
var _locked: bool = false

# Hover tooltip (flavor-first cards; numbers/details on hover)
var _tip_panel: PanelContainer = null
var _tip_title: Label = null
var _tip_flavor: Label = null
var _tip_numbers: Label = null
var _tip_tw: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	if card_scene == null:
		push_error("AugmentSelect: card_scene not assigned in AugmentSelect.tscn")
		return

	# IMPORTANT: don't blindly hide if open was requested before ready
	if not _pending_open:
		visible = false

	if overlay:
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay.color = Color(0, 0, 0, 0.45)
		overlay.modulate = Color(1, 1, 1, 1)

	if center:
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		center.modulate = Color(1, 1, 1, 1)

	if _pending_open:
		_pending_open = false
		call_deferred("_do_open_choose_3")

	_ensure_tooltip_ui()

func open_choose_3() -> void:
	# If called before ready, queue it properly
	if not is_node_ready():
		_pending_open = true
		return

	_do_open_choose_3()

func _do_open_choose_3() -> void:
	if _is_open:
		return

	_is_open = true
	_locked = false
	visible = true

	# If your game "pauses" using time_scale=0, tweens never advance.
	# In that case, DO NOT fade from alpha 0.
	var can_fade: bool = Engine.time_scale > 0.0

	if can_fade:
		_play_open_fade()
	else:
		# hard force visible so it can't get stuck invisible
		if overlay: overlay.modulate = Color(1, 1, 1, 1)
		if center: center.modulate = Color(1, 1, 1, 1)

	var options: Array[AugmentData] = []
	if Global != null and Global.has_method("get"):
		# safer than "in" checks for strict projects
		var db: Variant = Global.get("augment_db")
		if db is Dictionary:
			var d: Dictionary = db
			for v in d.values():
				if v is AugmentData:
					options.append(v)

	if OS.is_debug_build():
		print("Augments loaded:", options.size())

	if options.size() < 3:
		push_warning("Not enough augments in Global.augment_db")
		return

	options.shuffle()
	_spawn_cards(_build_offers(options))

func _build_offers(options: Array[AugmentData]) -> Array[AugmentData]:
	# While a slot is free, prefer augments the player does not own; pad with
	# owned ones (they level up on pick). With all three slots full, every
	# offer is an owned augment upgrade — never a silent slot-0 overwrite.
	Global.init_permanent_augments()
	var fresh: Array[AugmentData] = []
	var owned: Array[AugmentData] = []
	for a in options:
		if Global.permanent_augment_ids.has(a.id):
			owned.append(a)
		else:
			fresh.append(a)
	var has_empty_slot: bool = Global.permanent_augment_ids.find(StringName()) != -1
	var primary: Array[AugmentData] = fresh if has_empty_slot else owned
	var filler: Array[AugmentData] = owned if has_empty_slot else fresh
	var offers: Array[AugmentData] = primary.duplicate()
	for a in filler:
		if offers.size() >= 3:
			break
		offers.append(a)
	return offers.slice(0, 3)

func _spawn_cards(list: Array[AugmentData]) -> void:
	if cards_box == null:
		push_warning("[AugmentSelect] Cards box path is wrong (cards_box is null).")
		return

	for c in cards_box.get_children():
		c.queue_free()

	for a in list:
		var card := card_scene.instantiate()
		cards_box.add_child(card)

		if card.has_method("set_data"):
			card.call("set_data", a)

		if card.has_signal("picked"):
			card.connect("picked", Callable(self, "_on_card_picked"))
		if card.has_signal("hovered"):
			card.connect("hovered", Callable(self, "_on_card_hovered"))
		if card.has_signal("unhovered"):
			card.connect("unhovered", Callable(self, "_on_card_unhovered"))
		else:
			push_warning("AugmentCard has no signal 'picked'")

func _set_cards_locked(lock_it: bool) -> void:
	_locked = lock_it
	if cards_box == null:
		return

	for n in cards_box.get_children():
		var bb := n as BaseButton
		if bb != null:
			bb.disabled = lock_it

func _choose_slot_for_pick() -> int:
	# apply into permanent slots (so Player stats update)
	Global.init_permanent_augments()

	# find first empty slot (StringName() == empty)
	var slot: int = Global.permanent_augment_ids.find(StringName())
	if slot == -1:
		slot = 0 # all full -> overwrite slot 0 (change if you want)

	return slot

func _on_card_picked(a: AugmentData, card_node: Control) -> void:
	if _locked:
		return

	_set_cards_locked(true)

	if OS.is_debug_build():
		print("AUGMENT PICKED:", a.id)

	# Picking an augment you already own levels it up in place.
	var owned_slot: int = Global.permanent_augment_ids.find(a.id)
	var slot: int = owned_slot if owned_slot != -1 else _choose_slot_for_pick()

	var vfx_node := get_tree().get_first_node_in_group("augment_fly_vfx")
	var vfx := vfx_node as AugmentFlyVfx

	if vfx != null and card_node != null:
		await vfx.fly_card_to_slot(card_node, slot)
		if is_instance_valid(card_node):
			card_node.modulate = Color(1, 1, 1, 0)

	if owned_slot != -1:
		Global.level_up_permanent_augment(a.id)
	else:
		Global.set_permanent_augment(slot, a.id)
	augment_chosen.emit(a)
	_close()

func _close() -> void:
	_hide_tooltip()

	_is_open = false
	_locked = false
	visible = false

	if cards_box:
		for c in cards_box.get_children():
			c.queue_free()

func _play_open_fade() -> void:
	if overlay == null or center == null:
		return

	if _open_tw != null:
		_open_tw.kill()
		_open_tw = null

	overlay.modulate = Color(1, 1, 1, 0)
	center.modulate = Color(1, 1, 1, 0)

	_open_tw = create_tween()
	_open_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_tw.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.12)
	_open_tw.parallel().tween_property(center, "modulate", Color(1, 1, 1, 1), 0.12)


# ----------------------------
# Hover tooltip
# ----------------------------

func _ensure_tooltip_ui() -> void:
	if _tip_panel != null:
		return

	_tip_panel = PanelContainer.new()
	_tip_panel.name = "AugmentTooltip"
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tip_panel)
	_tip_panel.visible = false

	# Give it an explicit style so it's never "invisible" under theme changes.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.70)
	sb.border_color = Color(0.12, 0.12, 0.12, 1.0)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 8)
	_tip_panel.add_theme_stylebox_override("panel", sb)

	# A sane default size; we clamp position so it never goes offscreen.
	_tip_panel.custom_minimum_size = Vector2(360, 0)

	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_child(m)
	m.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)

	_tip_title = Label.new()
	_tip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_title.add_theme_font_size_override("font_size", 22)
	_tip_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))
	_tip_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.90))
	_tip_title.add_theme_constant_override("outline_size", 6)
	v.add_child(_tip_title)

	_tip_flavor = Label.new()
	_tip_flavor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_flavor.add_theme_font_size_override("font_size", 16)
	_tip_flavor.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_tip_flavor.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.90))
	_tip_flavor.add_theme_constant_override("outline_size", 5)
	v.add_child(_tip_flavor)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)

	_tip_numbers = Label.new()
	_tip_numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_numbers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_numbers.add_theme_font_size_override("font_size", 14)
	_tip_numbers.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 0.95))
	_tip_numbers.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	_tip_numbers.add_theme_constant_override("outline_size", 4)
	v.add_child(_tip_numbers)

func _hide_tooltip() -> void:
	if _tip_tw != null:
		_tip_tw.kill()
		_tip_tw = null
	if _tip_panel != null:
		_tip_panel.visible = false

func _on_card_hovered(a: AugmentData, card_node: Control) -> void:
	if _locked:
		return
	_ensure_tooltip_ui()
	if _tip_panel == null:
		return

	# Force a sane width BEFORE setting text and sizing.
	# This prevents the first tooltip from getting a zero-width wrap and exploding vertically.
	_tip_panel.custom_minimum_size = Vector2(360, 0)
	_tip_panel.size = Vector2(360, 0)

	_tip_title.text = a.display_name
	var flavor := a.description.strip_edges()
	if flavor == "":
		flavor = a.card_blurb.strip_edges()
	_tip_flavor.text = flavor
	_tip_numbers.text = _build_numbers_text(a)

	_tip_panel.visible = true
	# NOTE: The game pauses AugmentSelect with Engine.time_scale = 0.
	# Tweens won't advance in that state, so never rely on fade-in.
	_tip_panel.modulate.a = 1.0
	# Now size based on content.
	_tip_panel.reset_size()

	# Position near the hovered card.
	var vp := get_viewport().get_visible_rect().size
	var r := card_node.get_global_rect()
	var x := r.position.x + r.size.x + 14.0
	var y := r.position.y

	# If we'd go off the right side, place it on the left.
	_tip_panel.position = Vector2(x, y)
	_tip_panel.reset_size()
	var tip_size := _tip_panel.size
	if x + tip_size.x > vp.x - 8.0:
		x = r.position.x - tip_size.x - 14.0
	_tip_panel.position = Vector2(x, y)

	# Clamp vertically
	_tip_panel.position.y = clampf(_tip_panel.position.y, 8.0, vp.y - tip_size.y - 8.0)
	_tip_panel.position.x = clampf(_tip_panel.position.x, 8.0, vp.x - tip_size.x - 8.0)

	# Quick fade-in ONLY when time is running.
	if Engine.time_scale > 0.0:
		_tip_panel.modulate.a = 0.0
		if _tip_tw != null:
			_tip_tw.kill()
		_tip_tw = create_tween()
		_tip_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tip_tw.tween_property(_tip_panel, "modulate:a", 1.0, 0.08)

func _on_card_unhovered(_card_node: Control) -> void:
	_hide_tooltip()

func _build_numbers_text(a: AugmentData) -> String:
	var lines: Array[String] = []

	var det := a.details
	if det.strip_edges() == "" and a.has_method("get"):
		var v: Variant = a.get("details")
		if v != null:
			det = str(v)

	if det.strip_edges() != "":
		lines.append(det.strip_edges())

	if a.mods != null:
		var mods := _format_stat_mods(a.mods)
		if mods.size() > 0:
			lines.append("Stats:\n" + "\n".join(mods))

	if lines.size() == 0:
		return "(No numeric details yet)"
	return "\n\n".join(lines)
	
func _format_stat_mods(m: StatDelta) -> Array[String]:
	var out: Array[String] = []
	if m == null:
		return out

	const EPS := 0.0001

	# Fixed, readable order
	if absf(m.max_hp) > EPS:
		out.append("%+d Max HP" % int(round(m.max_hp)))

	if absf(m.armor) > EPS:
		out.append("%+d Armor" % int(round(m.armor)))

	if absf(m.move_speed) > EPS:
		out.append("%+d Move Speed" % int(round(m.move_speed)))

	# Stats.gd defines these as percents (0.20 = +20%)
	if absf(m.power) > EPS:
		out.append("%+d%% Power" % int(round(m.power * 100.0)))

	if absf(m.haste) > EPS:
		out.append("%+d%% Haste" % int(round(m.haste * 100.0)))

	if absf(m.luck) > EPS:
		out.append("%+d Luck" % int(round(m.luck)))

	return out
