extends CanvasLayer
## The Binding (docs/design/2026-10-03-bindings-and-theses.md §3): the
## augment pick after every segment. The cards are Global's persisted offer -
## NEW, RANK UP, SWAP or TRANSCEND, each graded Etched to Apocryphal - with a
## Recast (pay Followers for a new deal) and an Abstain (take Followers
## instead) from the second Binding on. A SWAP asks which seal to unbind.
## Opened with nothing pending (screenshot probes, tests) it deals a preview
## and a pick applies directly.

signal augment_chosen(augment: AugmentData)

const ARCANE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const ArcaneRuleScript := preload("res://ui/components/ArcaneRule.gd")
const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")

@export var card_scene: PackedScene

@onready var overlay: ColorRect = $Overlay
@onready var center: CenterContainer = $Center
@onready var cards_box: HBoxContainer = $Center/VBox/CardsPanel/CardsMargin/Cards

var _open_tw: Tween = null
var _is_open: bool = false
var _pending_open: bool = false
var _locked: bool = false
# Every card comes from the same card_scene, so a missing signal would repeat
# once per offer. One report per screen is enough.
var _warned_missing_card_signal: bool = false

# Hover tooltip (flavor-first cards; numbers/details on hover)
var _tip_panel: PanelContainer = null
var _tip_title: Label = null
var _tip_flavor: Label = null
var _tip_numbers: Label = null
var _tip_tw: Tween = null

# Recast / Abstain and the SWAP slot chooser, built in code under the cards.
var _subtitle: Label = null
var _footer: HBoxContainer = null
var _recast_button: Button = null
var _abstain_button: Button = null
var _abstain_armed: bool = false
var _wallet_label: Label = null
var _slot_row: VBoxContainer = null
var _pending_swap: Dictionary = {}


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
		overlay.modulate = Color(1, 1, 1, 1)

	if center:
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		center.modulate = Color(1, 1, 1, 1)

	if _pending_open:
		_pending_open = false
		call_deferred("_do_open_choose_3")

	_ensure_tooltip_ui()
	_ensure_binding_ui()

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

	if Global == null or Global.augment_db.size() < 3:
		push_warning("Not enough augments in Global.augment_db")
		return

	_deal()


## The pending Binding's persisted cards, or a preview deal when nothing is
## pending (a probe or a test opened the screen on its own).
func current_offer() -> Array:
	if Global.pending_augment_pick:
		return Global.binding_offer()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return AugmentBinding.build_offer(Global.binding_context(), rng)


func _deal() -> void:
	_close_slot_chooser()
	_abstain_armed = false
	_spawn_cards(current_offer())
	_refresh_binding_ui()


func _spawn_cards(list: Array) -> void:
	if cards_box == null:
		push_warning("[AugmentSelect] Cards box path is wrong (cards_box is null).")
		return

	for c in cards_box.get_children():
		cards_box.remove_child(c)
		c.queue_free()

	for entry_variant in list:
		var entry: Dictionary = entry_variant
		var a := Global.augment_db.get(StringName(str(entry.get("id", ""))), null) as AugmentData
		if a == null:
			continue
		var card := card_scene.instantiate()
		cards_box.add_child(card)

		if card.has_method("set_offer"):
			card.call("set_offer", a, entry)
		elif card.has_method("set_data"):
			card.call("set_data", a)

		if card.has_signal("picked"):
			card.connect("picked", Callable(self, "_on_card_picked"))
		if card.has_signal("hovered"):
			card.connect("hovered", Callable(self, "_on_card_hovered"))
		if card.has_signal("unhovered"):
			card.connect("unhovered", Callable(self, "_on_card_unhovered"))
		elif not _warned_missing_card_signal:
			_warned_missing_card_signal = true
			push_warning(
				"[AugmentSelect] offer card missing signal: signal=unhovered card=%s"
				% card_scene.resource_path
			)

func _set_cards_locked(lock_it: bool) -> void:
	_locked = lock_it
	if cards_box != null:
		for n in cards_box.get_children():
			var bb := n as BaseButton
			if bb != null:
				bb.disabled = lock_it
	_refresh_binding_ui()

func _choose_slot_for_pick() -> int:
	# apply into permanent slots (so Player stats update)
	Global.init_permanent_augments()

	# find first empty slot (StringName() == empty)
	var slot: int = Global.permanent_augment_ids.find(StringName())
	if slot == -1:
		slot = 0 # all full -> overwrite slot 0 (change if you want)

	return slot


static func _entry_of(card_node: Control) -> Dictionary:
	if card_node == null or not is_instance_valid(card_node):
		return {}
	var entry: Variant = card_node.get("card_entry")
	return (entry as Dictionary) if entry is Dictionary else {}


func _on_card_picked(a: AugmentData, card_node: Control) -> void:
	if _locked:
		return
	var entry := _entry_of(card_node)
	if AugmentBinding.needs_slot_choice(entry):
		_open_slot_chooser(a, card_node, entry)
		return
	await _commit(a, card_node, entry, -1)


## Applies the pick: through the Binding when one is pending, directly
## otherwise (a preview, or a caller handing an augment with no card).
func _commit(a: AugmentData, card_node: Control, entry: Dictionary, swap_slot: int) -> void:
	_set_cards_locked(true)

	if OS.is_debug_build():
		print("AUGMENT PICKED:", a.id, " ", entry)

	var owned_slot: int = Global.permanent_augment_ids.find(a.id)
	var slot: int = swap_slot if swap_slot >= 0 else (owned_slot if owned_slot != -1 else _choose_slot_for_pick())

	var vfx_node := get_tree().get_first_node_in_group("augment_fly_vfx")
	var vfx := vfx_node as AugmentFlyVfx

	if vfx != null and card_node != null:
		await vfx.fly_card_to_slot(card_node, slot)
		if is_instance_valid(card_node):
			card_node.modulate = Color(1, 1, 1, 0)

	var applied := false
	if not entry.is_empty() and Global.pending_augment_pick:
		applied = Global.apply_binding_card(entry, swap_slot)
	if not applied:
		_apply_direct(a, entry, swap_slot)
	augment_chosen.emit(a)
	_close()


## The pick without a pending Binding: a slotted augment rises by the card's
## grade in place, anything else is slotted at its stored level plus the
## grade (Etched keeps it).
func _apply_direct(a: AugmentData, entry: Dictionary, swap_slot: int) -> void:
	var owned_slot: int = Global.permanent_augment_ids.find(a.id)
	var grade := int(entry.get("grade", 0))
	var current := Global.get_augment_level(a.id)
	if owned_slot != -1:
		Global.set_augment_level(a.id, AugmentBinding.resulting_level({"kind": AugmentBinding.KIND_RANK, "grade": maxi(0, grade)}, current))
		Global.permanent_augments_changed.emit(Global.permanent_augment_ids)
		return
	var slot := swap_slot if swap_slot >= 0 else _choose_slot_for_pick()
	Global.set_permanent_augment(slot, a.id)
	Global.set_augment_level(a.id, AugmentBinding.resulting_level({"kind": AugmentBinding.KIND_NEW, "grade": maxi(0, grade)}, current))
	Global.permanent_augments_changed.emit(Global.permanent_augment_ids)


func _close() -> void:
	_hide_tooltip()
	_close_slot_chooser()

	_is_open = false
	_locked = false
	visible = false

	if cards_box:
		for c in cards_box.get_children():
			c.queue_free()


# ----------------------------
# Recast, Abstain, the SWAP chooser
# ----------------------------

func _ensure_binding_ui() -> void:
	if _footer != null:
		return
	_subtitle = get_node_or_null("Center/VBox/TitlePill/TitleMargin/TitleBox/Subtitle") as Label
	var vbox := get_node_or_null("Center/VBox") as VBoxContainer
	if vbox == null:
		return

	_slot_row = VBoxContainer.new()
	_slot_row.name = "SlotChooser"
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.add_theme_constant_override("separation", 10)
	_slot_row.visible = false
	vbox.add_child(_slot_row)

	_footer = HBoxContainer.new()
	_footer.name = "BindingFooter"
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("separation", 22)
	vbox.add_child(_footer)

	_recast_button = Button.new()
	_recast_button.name = "Recast"
	_recast_button.theme = ARCANE_THEME
	_recast_button.theme_type_variation = &"ArcaneSmallButton"
	_recast_button.custom_minimum_size = Vector2(250, 42)
	_recast_button.focus_mode = Control.FOCUS_NONE
	_recast_button.pressed.connect(_on_recast_pressed)
	_footer.add_child(_recast_button)

	_wallet_label = Label.new()
	_wallet_label.theme = ARCANE_THEME
	_wallet_label.theme_type_variation = &"ArcaneCaption"
	_wallet_label.add_theme_font_size_override("font_size", 14)
	_wallet_label.custom_minimum_size = Vector2(180, 0)
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer.add_child(_wallet_label)

	_abstain_button = Button.new()
	_abstain_button.name = "Abstain"
	_abstain_button.theme = ARCANE_THEME
	_abstain_button.theme_type_variation = &"ArcaneDangerButton"
	_abstain_button.custom_minimum_size = Vector2(250, 42)
	_abstain_button.focus_mode = Control.FOCUS_NONE
	_abstain_button.pressed.connect(_on_abstain_pressed)
	_footer.add_child(_abstain_button)
	_refresh_binding_ui()


func _refresh_binding_ui() -> void:
	if _subtitle != null and Global != null:
		if Global.pending_augment_pick and Global.binding_can_trade():
			_subtitle.text = "The Binding of segment %d. Every card is graded; a seal at Lv.%d with its catalyst can Transcend." % [Global.binding_segment(), Global.augment_transcend_level()]
		else:
			_subtitle.text = "Bind one to the Pattern. It stays with you between runs."
	if _footer == null or Global == null:
		return
	var trading := Global.pending_augment_pick and Global.binding_can_trade()
	_footer.visible = trading
	if not trading:
		return
	var cost := Global.binding_recast_cost()
	_recast_button.text = "RECAST  ·  FREE" if cost <= 0 else "RECAST  ·  %d FOLLOWERS" % cost
	_recast_button.disabled = _locked or Global.followers < cost
	var reward := Global.binding_abstain_reward()
	if _abstain_armed:
		_abstain_button.text = "CONFIRM  ·  TAKE %d" % reward
	else:
		_abstain_button.text = "ABSTAIN  ·  +%d FOLLOWERS" % reward
	_abstain_button.disabled = _locked
	_wallet_label.text = "%d FOLLOWERS" % Global.followers


func _on_recast_pressed() -> void:
	if _locked or not Global.binding_recast():
		return
	_hide_tooltip()
	_deal()


## Two presses: the first arms it, so a stray click never throws a pick away.
func _on_abstain_pressed() -> void:
	if _locked:
		return
	if not _abstain_armed:
		_abstain_armed = true
		_refresh_binding_ui()
		return
	if Global.binding_abstain() < 0:
		return
	_set_cards_locked(true)
	augment_chosen.emit(null)
	_close()


func _open_slot_chooser(a: AugmentData, card_node: Control, entry: Dictionary) -> void:
	if _slot_row == null:
		return
	_close_slot_chooser()
	_pending_swap = {"augment": a, "card": card_node, "entry": entry}
	var heading := Label.new()
	heading.theme = ARCANE_THEME
	heading.theme_type_variation = &"ArcaneCaption"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.text = "UNBIND WHICH SEAL FOR %s?" % a.display_name.to_upper()
	_slot_row.add_child(heading)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_slot_row.add_child(row)
	for slot in range(3):
		var id: StringName = Global.permanent_augment_ids[slot]
		var button := Button.new()
		button.theme = ARCANE_THEME
		button.theme_type_variation = &"ArcaneSmallButton"
		button.custom_minimum_size = Vector2(230, 42)
		button.focus_mode = Control.FOCUS_NONE
		var label := Global.augment_display_name(id) if id != StringName() else "empty"
		button.text = "%s  ·  %s  Lv.%d" % [["I", "II", "III"][slot], label.to_upper(), Global.get_augment_level(id)]
		button.disabled = Global.is_augment_slot_locked(slot)
		if button.disabled:
			button.tooltip_text = "Locked in the Hub's augment library."
		button.pressed.connect(_on_swap_slot_chosen.bind(slot))
		row.add_child(button)
	var back := Button.new()
	back.theme = ARCANE_THEME
	back.theme_type_variation = &"ArcaneSmallButton"
	back.custom_minimum_size = Vector2(120, 42)
	back.focus_mode = Control.FOCUS_NONE
	back.text = "BACK"
	back.pressed.connect(_close_slot_chooser)
	row.add_child(back)
	_slot_row.visible = true


func _close_slot_chooser() -> void:
	_pending_swap = {}
	if _slot_row == null:
		return
	for child in _slot_row.get_children():
		_slot_row.remove_child(child)
		child.queue_free()
	_slot_row.visible = false


func _on_swap_slot_chosen(slot: int) -> void:
	if _pending_swap.is_empty() or _locked:
		return
	var swap := _pending_swap
	_close_slot_chooser()
	await _commit(swap["augment"], swap["card"], swap["entry"], slot)

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

	# Give it an explicit style so it's never "invisible" under theme changes:
	# the front end's gold-ruled register, square-cornered.
	_tip_panel.theme = ARCANE_THEME
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.028, 0.024, 0.021, 0.96)
	sb.border_color = Color(0.62, 0.47, 0.29, 0.9)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 16
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
	_tip_title.theme_type_variation = &"ArcaneHeading"
	_tip_title.add_theme_font_size_override("font_size", 22)
	v.add_child(_tip_title)

	_tip_flavor = Label.new()
	_tip_flavor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_flavor.theme_type_variation = &"ArcaneItalic"
	_tip_flavor.add_theme_font_size_override("font_size", 18)
	v.add_child(_tip_flavor)

	var sep := ArcaneRuleScript.new() as Control
	sep.custom_minimum_size = Vector2(0, 14)
	v.add_child(sep)

	_tip_numbers = Label.new()
	_tip_numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_numbers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_numbers.theme_type_variation = &"ArcaneBody"
	_tip_numbers.add_theme_font_size_override("font_size", 16)
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
	var entry := _entry_of(card_node)
	_ensure_tooltip_ui()
	if _tip_panel == null:
		return

	# Force a sane width BEFORE setting text and sizing.
	# This prevents the first tooltip from getting a zero-width wrap and exploding vertically.
	_tip_panel.custom_minimum_size = Vector2(360, 0)
	_tip_panel.size = Vector2(360, 0)

	var transcend := String(entry.get("kind", "")) == AugmentBinding.KIND_TRANSCEND
	_tip_title.text = AugmentScaling.transcended_name(a.id) if transcend else Global.augment_display_name(a.id)
	var flavor := a.description.strip_edges()
	if flavor == "":
		flavor = a.card_blurb.strip_edges()
	_tip_flavor.text = flavor
	_tip_numbers.text = _build_numbers_text(a, entry)

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

func _build_numbers_text(a: AugmentData, entry: Dictionary = {}) -> String:
	var lines: Array[String] = []

	if not entry.is_empty():
		var current: int = Global.get_augment_level(a.id) if Global != null else 1
		var after := AugmentBinding.resulting_level(entry, current)
		var grade := int(entry.get("grade", -1))
		var head := ""
		match String(entry.get("kind", "")):
			AugmentBinding.KIND_TRANSCEND:
				head = "TRANSCEND  ·  Lv.%d → Lv.%d\n%s" % [current, after, AugmentScaling.transcend_rule(a.id)]
			AugmentBinding.KIND_RANK:
				head = "%s  ·  RANK UP  ·  Lv.%d → Lv.%d" % [AugmentScaling.grade_name(grade), current, after]
			AugmentBinding.KIND_SWAP:
				head = "%s  ·  SWAP IN AT Lv.%d (replaces a seal you choose)" % [AugmentScaling.grade_name(grade), after]
			_:
				head = "%s  ·  BINDS AT Lv.%d" % [AugmentScaling.grade_name(grade), after]
		lines.append(head)
		if a.effect_scenes.size() > 0:
			lines.append("Payload grows with your native hit (D) and +35% per level: x%.2f at Lv.%d." % [AugmentScaling.potency(after), after])
		if String(entry.get("kind", "")) != AugmentBinding.KIND_TRANSCEND and AugmentScaling.can_transcend(a.id) and not Global.is_augment_transcended(a.id):
			var held := Global.augment_catalyst_holds(a.id)
			lines.append("Transcends at Lv.%d into %s. Catalyst: %s%s." % [
				Global.augment_transcend_level(), AugmentScaling.transcended_name(a.id),
				AugmentScaling.catalyst_text(a.id), " (held)" if held else "",
			])

	var det := a.details
	if det.strip_edges() == "" and a.has_method("get"):
		var v: Variant = a.get("details")
		if v != null:
			det = str(v)

	if det.strip_edges() != "":
		lines.append(det.strip_edges())

	# Stats at the level the pick would give - a slotted augment levels up in
	# place (_on_card_picked), so its card is an upgrade, and the base `mods`
	# are stale from Lv.2 on for every augment with mods_scale_per_level.
	if a.mods != null:
		var lvl: int = _level_on_pick(a) if entry.is_empty() else AugmentBinding.resulting_level(entry, Global.get_augment_level(a.id))
		var mods := _format_stat_mods(_mods_at_level(a, lvl))
		if mods.size() > 0:
			lines.append(("Stats at Lv.%d:\n" % lvl) + "\n".join(mods))

	if lines.size() == 0:
		return "(No numeric details yet)"
	return "\n\n".join(lines)

## The level this card gives - the one the stat pass applies after the pick,
## Global.get_augment_level, which slotting never touches: a slotted augment
## levels up in place (_on_card_picked); anything else is only slotted and
## keeps its stored level - Lv.1 when never levelled, its real level when it
## was levelled and then unslotted.
func _level_on_pick(a: AugmentData) -> int:
	if Global == null:
		return 1
	var current: int = 1
	if Global.has_method("get_augment_level"):
		current = int(Global.get_augment_level(a.id))
	if Global.permanent_augment_ids.has(a.id):
		return current + 1
	return current

## The level-scaled delta, read back from AugmentData.apply_to_stats_at_level -
## the call the stat pass makes - applied to a default Stats and diffed
## against an untouched one, exactly as AugmentTooltip reads it, so neither
## surface can drift from the formula.
func _mods_at_level(a: AugmentData, level: int) -> StatDelta:
	var base := Stats.new()
	var scaled := Stats.new()
	a.apply_to_stats_at_level(scaled, level)
	var out := StatDelta.new()
	out.max_hp = scaled.max_hp - base.max_hp
	out.armor = scaled.armor - base.armor
	out.move_speed = scaled.move_speed - base.move_speed
	out.power = scaled.power - base.power
	out.haste = scaled.haste - base.haste
	out.luck = scaled.luck - base.luck
	return out

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
		# Luck is a fraction (0.5 = +50%) and every other surface prints it as
		# one - the sheet's LCK %, the item tooltip, the augment tooltip.
		out.append("%+d%% Luck" % int(round(m.luck * 100.0)))

	return out
