extends CanvasLayer

## The Reliquary, opened from the Hub
## (docs/design/2026-10-03-duos-facets-and-the-reliquary.md §4): four rites
## on tabs. Corruption gambles an equipped augment's levels, Transfusion
## pours an unequipped one into it, Vouchers sell run-long rules, and the
## Grimoire lists what the profile has ever reached. Global owns every rule;
## this screen only asks and shows.

signal closed

## The front-end register (docs/design/2026-10-02-front-end-arcane-register.md),
## built like ImprintScreen: an ornamented panel over a veil.
const ARCANE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const ArcaneRuleScript := preload("res://ui/components/ArcaneRule.gd")
const BODY_DIM := Color(0.72, 0.67, 0.58)
const STATUS := Color(1.0, 0.86, 0.62)
const GOLD_BRIGHT := Color(0.99, 0.84, 0.58)
const EMBER := Color(1.0, 0.62, 0.30)
const DANGER := Color(0.86, 0.32, 0.24)
## How far an undiscovered Grimoire entry is dimmed: the "???" and the hint
## already say it is unknown, the dimming lets a glance count the gaps.
const UNDISCOVERED_ALPHA := 0.5

const TAB_CORRUPTION := &"CORRUPTION"
const TAB_TRANSFUSION := &"TRANSFUSION"
const TAB_VOUCHERS := &"VOUCHERS"
const TAB_GRIMOIRE := &"GRIMOIRE"
const TABS: Array[StringName] = [TAB_CORRUPTION, TAB_TRANSFUSION, TAB_VOUCHERS, TAB_GRIMOIRE]
const TAB_BLURBS := {
	TAB_CORRUPTION: "Corrupt an equipped augment: free, irreversible, once per augment per run. Luck tilts the odds toward Exalted.",
	TAB_TRANSFUSION: "Pour an unequipped augment's run levels into an equipped one: it gains half the donor's level, rounded down, and the donor returns to Lv.1.",
	TAB_VOUCHERS: "Two Vouchers each Hub visit. Each is bought once per run and holds until the run ends.",
	TAB_GRIMOIRE: "Everything this profile has ever reached. It survives death; what is still unknown shows only where to look.",
}
const SECTION_TITLES := {
	"TRANSCENDENCE": "TRANSCENDENCES",
	"DUO": "DUOS",
	"FACET": "FACETS",
	"THESIS": "THESES",
	"CANON": "CANONS",
}
## Every wrapping label gets a fixed minimum width so it wraps inside the
## panel instead of widening it (an autowrapped Label's own minimum width
## is zero, which a container would squeeze to one word a line).
const WIDE_TEXT := 900.0
const ROW_TEXT := 640.0
const COLUMN_TEXT := 400.0

var _root: Control = null
var _scroll: ScrollContainer = null
var _page: VBoxContainer = null
var _blurb: Label = null
var _status: Label = null
var _wallet: Label = null
var _tab_buttons: Dictionary = {}
var _tab: StringName = TAB_CORRUPTION
## The augment whose CORRUPT was pressed once and now waits for CONFIRM.
var _armed: StringName = &""
var _recipient: StringName = &""
var _donor: StringName = &""


func _ready() -> void:
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_refresh()
	var first := _tab_buttons.get(_tab, null) as Button
	if first != null:
		first.grab_focus()


func close() -> void:
	visible = false
	closed.emit()
	queue_free()


func show_tab(tab: StringName) -> void:
	if not TABS.has(tab):
		return
	_tab = tab
	# Leaving a page disarms its confirm; the line asking for the second
	# press goes with it, or it would contradict the button on the way back.
	if _armed != &"":
		_armed = &""
		_status.text = ""
	_scroll.scroll_vertical = 0
	_refresh()


## Pixels a pad or arrow press moves the Grimoire; a page key moves a view.
const SCROLL_STEP := 120


## The Grimoire's pages by pad or keyboard while the scroll holds focus. Up
## at the top is left alone, so focus can climb back to the tab row.
func _on_scroll_input(event: InputEvent) -> void:
	var view := int(_scroll.size.y)
	var delta := 0
	if event.is_action_pressed(&"ui_down", true):
		delta = SCROLL_STEP
	elif event.is_action_pressed(&"ui_up", true):
		if _scroll.scroll_vertical <= 0:
			return
		delta = -SCROLL_STEP
	elif event.is_action_pressed(&"ui_page_down", true):
		delta = view
	elif event.is_action_pressed(&"ui_page_up", true):
		delta = -view
	else:
		return
	_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical + delta)
	_scroll.accept_event()


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
	panel.name = "Panel"
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
	title.text = "RELIQUARY"
	title.theme_type_variation = &"ArcaneTitle"
	title.add_theme_font_size_override("font_size", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_rule(2, 18.0, 420.0))
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 14)
	column.add_child(tabs)
	for tab in TABS:
		var button := Button.new()
		button.name = "Tab_%s" % String(tab)
		button.theme_type_variation = &"ArcaneKeyButton"
		button.text = String(tab)
		button.custom_minimum_size = Vector2(210, 38)
		button.add_theme_constant_override("h_separation", 10)
		button.pressed.connect(show_tab.bind(tab))
		tabs.add_child(button)
		_tab_buttons[tab] = button
	_blurb = Label.new()
	_blurb.name = "Blurb"
	_blurb.theme_type_variation = &"ArcaneItalic"
	_blurb.add_theme_font_size_override("font_size", 17)
	_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(WIDE_TEXT, 0)
	column.add_child(_blurb)
	_scroll = ScrollContainer.new()
	_scroll.name = "PageScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# A pad or keyboard user walks the rows with focus: the page follows it.
	# The Grimoire has no buttons to walk, so the scroll itself takes focus
	# there and pages with the pad (_on_scroll_input).
	_scroll.follow_focus = true
	_scroll.gui_input.connect(_on_scroll_input)
	column.add_child(_scroll)
	column.add_child(_rule(0, 10.0, 0.0))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	_wallet = Label.new()
	_wallet.name = "Wallet"
	_wallet.theme_type_variation = &"ArcaneHeading"
	_wallet.add_theme_font_size_override("font_size", 18)
	_wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_wallet)
	_status = Label.new()
	_status.name = "Status"
	_status.theme_type_variation = &"ArcaneItalic"
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", STATUS)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(560, 0)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_status)
	var close_button := Button.new()
	close_button.name = "Close"
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


func _body(text: String, width: float, variation: StringName = &"ArcaneBody") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", 17)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _rule(ornament: int, height: float, width: float) -> Control:
	var rule := ArcaneRuleScript.new() as Control
	rule.set("ornament", ornament)
	rule.custom_minimum_size = Vector2(width, height)
	if width > 0.0:
		rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rule


## Marks a chosen tab or pick the way ImprintScreen marks its chosen
## imprint: the filled diamond and the gold edge, never colour alone.
func _mark(button: Button, chosen: bool) -> void:
	if chosen:
		button.add_theme_stylebox_override("normal", ARCANE_THEME.get_stylebox(&"hover", &"ArcaneKeyButton"))
		button.add_theme_color_override("font_color", GOLD_BRIGHT)
	else:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_color_override("font_color")
	button.icon = ARCANE_THEME.get_icon(&"checked" if chosen else &"unchecked", &"CheckBox")


func _pick_button(button_name: String, text: String, chosen: bool) -> Button:
	var pick := Button.new()
	pick.name = button_name
	pick.theme_type_variation = &"ArcaneKeyButton"
	pick.text = text
	pick.add_theme_constant_override("h_separation", 10)
	pick.custom_minimum_size = Vector2(0, 36)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_mark(pick, chosen)
	return pick


## Every rite rebuilds the page. The old page is queued away and a fresh
## container takes its place, so the new rows keep their plain names
## (a queued sibling would push a same-named row to an @-name for a frame).
func _refresh() -> void:
	if _page != null:
		_page.visible = false
		_page.queue_free()
	_page = VBoxContainer.new()
	_page.name = "Page_%s" % String(_tab)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 10)
	_scroll.add_child(_page)
	for tab in TABS:
		_mark(_tab_buttons[tab] as Button, tab == _tab)
	_blurb.text = String(TAB_BLURBS.get(_tab, ""))
	# Only the Grimoire, which has nothing else to focus, lets the scroll
	# take focus; on the other tabs focus walks the rows.
	_scroll.focus_mode = Control.FOCUS_ALL if _tab == TAB_GRIMOIRE else Control.FOCUS_NONE
	if Global == null:
		return
	_wallet.text = "%d Followers" % int(Global.followers)
	match _tab:
		TAB_CORRUPTION:
			_build_corruption()
		TAB_TRANSFUSION:
			_build_transfusion()
		TAB_VOUCHERS:
			_build_vouchers()
		TAB_GRIMOIRE:
			_build_grimoire()


func _equipped() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in Global.permanent_augment_ids:
		if id != StringName():
			out.append(id)
	return out


func _level_text(id: StringName) -> String:
	return "%s  Lv.%d" % [Global.augment_display_name(id), Global.get_augment_level(id)]


func _outcome_colour(outcome: StringName) -> Color:
	match outcome:
		AugmentRites.EXALTED:
			return GOLD_BRIGHT
		AugmentRites.SCARRED:
			return EMBER
	return DANGER


# ---------------------------------------------------------------- Corruption


func _build_corruption() -> void:
	_page.add_child(_caption("THE ODDS"))
	var weights := AugmentRites.corruption_weights(Global.run_luck)
	var total := 0.0
	for w in weights:
		total += w
	var lines := PackedStringArray()
	for i in range(AugmentRites.OUTCOMES.size()):
		var outcome := AugmentRites.OUTCOMES[i]
		var share := weights[i] / total * 100.0 if total > 0.0 else 0.0
		lines.append("%s  %d%%   %s" % [AugmentRites.OUTCOME_NAMES[outcome], roundi(share), AugmentRites.OUTCOME_TEXT[outcome]])
	var odds := _body("\n".join(lines), WIDE_TEXT)
	odds.name = "Odds"
	odds.add_theme_color_override("font_color", BODY_DIM)
	_page.add_child(odds)
	_page.add_child(_rule(0, 10.0, 0.0))
	_page.add_child(_caption("EQUIPPED"))
	var equipped := _equipped()
	if equipped.is_empty():
		_page.add_child(_body("No augment is equipped. Only a worn augment can be corrupted.", WIDE_TEXT, &"ArcaneItalic"))
		return
	for id in equipped:
		var row := HBoxContainer.new()
		row.name = "Corrupt_%s" % String(id)
		row.add_theme_constant_override("separation", 12)
		_page.add_child(row)
		var label := _body(_level_text(id), ROW_TEXT)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		var fate := Global.augment_corruption(id)
		if fate != StringName():
			# A corrupted augment says what it became, in words as well as
			# colour, and the Scar's price stays in view while it is worn.
			var mark := Label.new()
			mark.name = "Corruption_%s" % String(id)
			mark.theme_type_variation = &"ArcaneHeading"
			mark.add_theme_font_size_override("font_size", 17)
			mark.add_theme_color_override("font_color", _outcome_colour(fate))
			mark.text = String(AugmentRites.OUTCOME_NAMES.get(fate, String(fate).to_upper()))
			mark.tooltip_text = String(AugmentRites.OUTCOME_TEXT.get(fate, ""))
			mark.mouse_filter = Control.MOUSE_FILTER_PASS
			mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mark)
			continue
		var corrupt := Button.new()
		corrupt.name = "CorruptButton_%s" % String(id)
		corrupt.theme_type_variation = &"ArcaneDangerButton"
		corrupt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		corrupt.custom_minimum_size = Vector2(250, 0)
		corrupt.text = "CONFIRM · IRREVERSIBLE" if id == _armed else "CORRUPT"
		corrupt.disabled = not Global.can_corrupt_augment(id)
		corrupt.pressed.connect(_on_corrupt_pressed.bind(id))
		row.add_child(corrupt)


## Two presses: the first arms the row, the second rolls the fate. Arming
## another row disarms the first, so one stray press can never corrupt.
func _on_corrupt_pressed(id: StringName) -> void:
	if _armed != id:
		_armed = id
		_status.text = "Corrupt %s? It cannot be undone; press again to confirm." % Global.augment_display_name(id)
		_refresh()
		_focus_page_control("CorruptButton_%s" % String(id))
		return
	_armed = &""
	var result := Global.corrupt_augment(id)
	if bool(result.get("ok", false)):
		var outcome := StringName(result["outcome"])
		_status.text = "%s is %s: Lv.%d → Lv.%d. %s" % [
			Global.augment_display_name(id), AugmentRites.OUTCOME_NAMES.get(outcome, String(outcome)),
			int(result["before"]), int(result["after"]), AugmentRites.OUTCOME_TEXT.get(outcome, ""),
		]
	else:
		_status.text = "%s cannot be corrupted." % Global.augment_display_name(id)
	_refresh()
	_focus_tab()


# ---------------------------------------------------------------- Transfusion


func _donors() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in Global.owned_augment_ids:
		if id != StringName() and not Global.permanent_augment_ids.has(id) and not out.has(id):
			out.append(id)
	return out


func _build_transfusion() -> void:
	var recipients := _equipped()
	var donors := _donors()
	if not recipients.has(_recipient):
		_recipient = recipients[0] if not recipients.is_empty() else &""
	if not donors.has(_donor):
		# The first donor that has something to give, else simply the first.
		_donor = &""
		for id in donors:
			if Global.get_augment_level(id) >= AugmentRites.TRANSFUSION_MIN_DONOR:
				_donor = id
				break
		if _donor == &"" and not donors.is_empty():
			_donor = donors[0]
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 26)
	_page.add_child(split)
	var left := VBoxContainer.new()
	left.name = "Recipients"
	left.custom_minimum_size = Vector2(COLUMN_TEXT, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)
	left.add_child(_caption("RECIPIENT · EQUIPPED"))
	if recipients.is_empty():
		left.add_child(_body("No augment is equipped.", COLUMN_TEXT, &"ArcaneItalic"))
	for id in recipients:
		var pick := _pick_button("Recipient_%s" % String(id), _level_text(id), id == _recipient)
		pick.pressed.connect(func() -> void:
			_recipient = id
			_refresh()
			_focus_page_control("Recipient_%s" % String(id))
		)
		left.add_child(pick)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(1, 0)
	divider.color = Color(0.62, 0.47, 0.3, 0.35)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_child(divider)
	var right := VBoxContainer.new()
	right.name = "Donors"
	right.custom_minimum_size = Vector2(COLUMN_TEXT, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)
	right.add_child(_caption("DONOR · IN THE LIBRARY"))
	if donors.is_empty():
		right.add_child(_body("Every owned augment is equipped. Swap cards leave levelled augments in the library; this is where they pay out.", COLUMN_TEXT, &"ArcaneItalic"))
	for id in donors:
		var pick := _pick_button("Donor_%s" % String(id), _level_text(id), id == _donor)
		pick.pressed.connect(func() -> void:
			_donor = id
			_refresh()
			_focus_page_control("Donor_%s" % String(id))
		)
		right.add_child(pick)
	_page.add_child(_rule(0, 10.0, 0.0))
	var preview := Global.transfusion_preview(_recipient, _donor)
	var ok := bool(preview.get("ok", false))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	_page.add_child(line)
	var summary := ""
	if ok:
		var gain := int(preview["gain"])
		var level := Global.get_augment_level(_recipient)
		summary = "%s Lv.%d → Lv.%d  ·  %s Lv.%d → Lv.1  ·  %d Followers (%d a level)" % [
			Global.augment_display_name(_recipient), level, AugmentScaling.clamp_level(level + gain),
			Global.augment_display_name(_donor), Global.get_augment_level(_donor),
			int(preview["cost"]), int(preview.get("per_level", AugmentRites.TRANSFUSION_COST_PER_LEVEL)),
		]
	elif _recipient == &"" or _donor == &"":
		summary = "Choose an equipped recipient and an unequipped donor."
	else:
		summary = "Cannot transfuse: %s." % String(preview.get("reason", ""))
	var shown := _body(summary, ROW_TEXT, &"ArcaneBody" if ok else &"ArcaneItalic")
	shown.name = "TransfusionPreview"
	shown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not ok:
		shown.add_theme_color_override("font_color", BODY_DIM)
	line.add_child(shown)
	var transfuse := Button.new()
	transfuse.name = "TransfuseButton"
	transfuse.theme_type_variation = &"ArcaneSmallButton"
	transfuse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	transfuse.custom_minimum_size = Vector2(220, 0)
	transfuse.text = "TRANSFUSE  −%d" % int(preview["cost"]) if ok else "TRANSFUSE"
	transfuse.disabled = not ok
	transfuse.pressed.connect(_on_transfuse_pressed)
	line.add_child(transfuse)


func _on_transfuse_pressed() -> void:
	var recipient := _recipient
	var donor := _donor
	var before := Global.get_augment_level(recipient)
	var result := Global.transfuse_augment(recipient, donor)
	if bool(result.get("ok", false)):
		_status.text = "%s drinks %s: Lv.%d → Lv.%d, for %d Followers." % [
			Global.augment_display_name(recipient), Global.augment_display_name(donor),
			before, Global.get_augment_level(recipient), int(result["cost"]),
		]
	else:
		_status.text = "Cannot transfuse: %s." % String(result.get("reason", ""))
	_refresh()
	if not _focus_page_control("TransfuseButton"):
		_focus_tab()


# ---------------------------------------------------------------- Vouchers


func _build_vouchers() -> void:
	var price := Global.voucher_price()
	_page.add_child(_caption("OFFERED THIS VISIT · %d FOLLOWERS EACH" % price))
	var offer := Global.voucher_offer()
	if offer.is_empty():
		_page.add_child(_body("Every Voucher is already yours this run.", WIDE_TEXT, &"ArcaneItalic"))
	for id_variant in offer:
		var id := StringName(id_variant)
		var row := HBoxContainer.new()
		row.name = "Voucher_%s" % String(id)
		row.add_theme_constant_override("separation", 12)
		_page.add_child(row)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 2)
		row.add_child(words)
		var heading := Label.new()
		heading.text = Vouchers.display_name(id)
		heading.theme_type_variation = &"ArcaneHeading"
		heading.add_theme_font_size_override("font_size", 18)
		words.add_child(heading)
		var rule := _body(Vouchers.text(id), ROW_TEXT)
		rule.add_theme_color_override("font_color", BODY_DIM)
		words.add_child(rule)
		var buy := Button.new()
		buy.name = "VoucherBuy_%s" % String(id)
		buy.theme_type_variation = &"ArcaneSmallButton"
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.custom_minimum_size = Vector2(200, 0)
		if Global.has_voucher(id):
			buy.text = "BOUGHT"
			buy.disabled = true
		else:
			buy.text = "BUY  −%d" % price
			buy.disabled = Global.followers < price
			if buy.disabled:
				buy.tooltip_text = "Needs %d Followers." % price
			buy.pressed.connect(_on_buy_pressed.bind(id))
		row.add_child(buy)
	_page.add_child(_rule(0, 10.0, 0.0))
	_page.add_child(_caption("HELD THIS RUN"))
	var held := VBoxContainer.new()
	held.name = "HeldVouchers"
	held.add_theme_constant_override("separation", 4)
	_page.add_child(held)
	if Global.attempt_vouchers.is_empty():
		held.add_child(_body("None yet.", WIDE_TEXT, &"ArcaneItalic"))
	for id_variant in Global.attempt_vouchers:
		var id := StringName(id_variant)
		held.add_child(_body("%s  ·  %s" % [Vouchers.display_name(id), Vouchers.text(id)], WIDE_TEXT))


func _on_buy_pressed(id: StringName) -> void:
	var price := Global.voucher_price()
	if Global.buy_voucher(id):
		_status.text = "%s bought for %d Followers." % [Vouchers.display_name(id), price]
	elif Global.followers < price:
		_status.text = "%s needs %d Followers." % [Vouchers.display_name(id), price]
	else:
		_status.text = "%s cannot be bought." % Vouchers.display_name(id)
	_refresh()
	_focus_tab()


# ---------------------------------------------------------------- Grimoire


func _build_grimoire() -> void:
	var entries := Grimoire.catalogue(Global.augment_db)
	var found := 0
	for entry in entries:
		if Global.grimoire_has(String(entry["key"])):
			found += 1
	var count := Label.new()
	count.name = "GrimoireCount"
	count.text = "DISCOVERED %d / %d" % [found, entries.size()]
	count.theme_type_variation = &"ArcaneHeading"
	count.add_theme_font_size_override("font_size", 18)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(count)
	for section in Grimoire.SECTIONS:
		var rows: Array = entries.filter(func(e: Dictionary) -> bool: return String(e["section"]) == section)
		if rows.is_empty():
			continue
		var known := rows.filter(func(e: Dictionary) -> bool: return Global.grimoire_has(String(e["key"]))).size()
		_page.add_child(_rule(0, 10.0, 0.0))
		var heading := _caption("%s  %d / %d" % [SECTION_TITLES.get(section, section), known, rows.size()])
		heading.name = "Section_%s" % section
		_page.add_child(heading)
		for entry in rows:
			_page.add_child(_grimoire_entry(entry))


func _grimoire_entry(entry: Dictionary) -> Control:
	var key := String(entry["key"])
	var discovered := Global.grimoire_has(key)
	var box := VBoxContainer.new()
	# A key carries ':' which a node name cannot.
	box.name = "Entry_%s" % key.replace(":", "_")
	box.add_theme_constant_override("separation", 0)
	box.set_meta(&"discovered", discovered)
	var heading := Label.new()
	heading.theme_type_variation = &"ArcaneHeading"
	heading.add_theme_font_size_override("font_size", 16)
	heading.text = String(entry["name"]) if discovered else "???"
	box.add_child(heading)
	var line := _body(String(entry["rule"]) if discovered else "Hint: %s." % String(entry["hint"]), WIDE_TEXT, &"ArcaneBody" if discovered else &"ArcaneItalic")
	line.add_theme_font_size_override("font_size", 16)
	if discovered:
		line.add_theme_color_override("font_color", BODY_DIM)
	box.add_child(line)
	if not discovered:
		box.modulate = Color(1, 1, 1, UNDISCOVERED_ALPHA)
	return box


## Puts focus back on a rebuilt control, so a pad or keyboard user is not
## dropped when a press rebuilds the page under them.
## Returns whether it found a control that can hold focus.
func _focus_page_control(control_name: String) -> bool:
	var control := _page.find_child(control_name, true, false) as Control
	if control == null or not control.is_inside_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	control.grab_focus()
	return true


## After a press that rebuilt the page and freed the pressed button, focus
## lands on the current tab, which always survives a refresh.
func _focus_tab() -> void:
	var tab_button := _tab_buttons.get(_tab, null) as Button
	if tab_button != null and tab_button.is_inside_tree():
		tab_button.grab_focus()

