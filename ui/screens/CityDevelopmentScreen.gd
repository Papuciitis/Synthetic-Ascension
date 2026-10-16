extends CanvasLayer
## One retained choice per Research. Global owns every cost and gameplay rule.
signal closed

const ARCANE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const GOLD := Color(0.93, 0.82, 0.59)
const DIM := Color(0.72, 0.67, 0.58)

var _root: Control
var _panel: PanelContainer
var _margin: MarginContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _wallet: Label
var _status: Label
var _next_summary: Label
var _active_summary: Label
var _close_button: Button
var _options: Array[Dictionary] = []
var _rows: Dictionary = {}
var _selectors: Dictionary = {}
var _target_choices: Dictionary = {}
var _summary: Dictionary = {}
var _closing := false
var _fit_queued := false

func _ready() -> void:
	layer = 170
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.minimum_size_changed.connect(_queue_fit_panel)
	refresh()
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()
	_queue_fit_panel()
	_focus_arrival.call_deferred()

func close() -> void:
	if _closing:
		return
	_closing = true
	SfxManager.play_ui(&"ui_back")
	visible = false
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	for selector: OptionButton in _selectors.values():
		if selector.get_popup().visible:
			return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = ARCANE_THEME
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(0.008, 0.006, 0.005, 0.94)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(veil)
	_panel = PanelContainer.new()
	_panel.name = "DevelopmentPanel"
	_panel.theme_type_variation = &"ArcanePanel"
	_root.add_child(_panel)
	_margin = MarginContainer.new()
	_panel.add_child(_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var title := _label("DevelopmentTitle", "Choose one improvement", 30, &"ArcaneHeading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close_button = Button.new()
	_close_button.name = "CloseDevelopment"
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(88, 42)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)
	_wallet = _label("ResearchWallet", "", 21, &"ArcaneHeading")
	_wallet.add_theme_color_override("font_color", GOLD)
	column.add_child(_wallet)
	_scroll = ScrollContainer.new()
	_scroll.name = "DevelopmentScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	_scroll.add_child(_list)
	_list.add_child(_label("DevelopmentContinuity", "Your previous choices remain. Each improvement costs 1 Research and applies from your next attempt.", 21))
	_list.add_child(_label("ResearchSource", "Earn 1 Research the first time this profile clears each city segment (1–10). Each Research buys one chosen improvement. Repeating a cleared segment or dying grants no Research.", 19))
	_next_summary = _label("NextAttemptSummary", "", 20)
	_next_summary.add_theme_color_override("font_color", GOLD)
	_list.add_child(_next_summary)
	_active_summary = _label("ActiveAttemptSummary", "", 19)
	_active_summary.add_theme_color_override("font_color", DIM)
	_list.add_child(_active_summary)
	_status = _label("DevelopmentStatus", "", 19)
	_status.add_theme_color_override("font_color", GOLD)
	_list.add_child(_status)
	var frame := ArcaneFrameScript.new() as Control
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set("inset", 5.0)
	frame.set("crown", false)
	_panel.add_child(frame)

func _label(node_name: String, text: String, font_size: int, variation: StringName = &"ArcaneBody") -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _profile_available() -> bool:
	return SaveManager != null and SaveManager.current_save != null

func _read_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if Global == null or not Global.has_method("get_city_development_options"):
		return result
	var entries: Variant = Global.call("get_city_development_options")
	if entries is Array:
		for entry: Variant in entries:
			if entry is Dictionary and not String((entry as Dictionary).get("id", "")).is_empty():
				result.append(entry as Dictionary)
	return result

func _create_option(option: Dictionary) -> void:
	var id := String(option.get("id", ""))
	var card := PanelContainer.new()
	card.name = "Option_" + id
	card.theme_type_variation = &"ArcanePanel"
	_list.add_child(card)
	var padding := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 14)
	card.add_child(padding)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	padding.add_child(column)
	column.add_child(_label("OptionTitle_" + id, String(option.get("name", id)), 24, &"ArcaneHeading"))
	var description := _label("OptionDescription_" + id, String(option.get("description", "")), 19)
	column.add_child(description)
	var gain := _label("OptionGain_" + id, "", 20)
	gain.add_theme_color_override("font_color", GOLD)
	column.add_child(gain)
	if bool(option.get("owned_target_required", false)):
		var selector := OptionButton.new()
		selector.name = "TrainedAugment" if id == "augment" else "Target_" + id
		selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		selector.custom_minimum_size = Vector2(0, 42)
		selector.add_theme_font_size_override("font_size", 19)
		column.add_child(selector)
		selector.item_selected.connect(_on_target_selected.bind(id))
		_selectors[id] = selector
		column.add_child(_label("TargetHelp_" + id, "Choose an owned augment before investing. Selecting a target alone grants no improvement. Once training is purchased, changing its target is free and applies next attempt.", 18))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	var rank := _label("OptionRank_" + id, "", 18, &"ArcaneCaption")
	rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(rank)
	var buy := Button.new()
	buy.name = "Invest_" + id
	buy.custom_minimum_size = Vector2(170, 42)
	buy.add_theme_font_size_override("font_size", 18)
	buy.pressed.connect(_purchase.bind(id))
	footer.add_child(buy)
	_rows[id] = {"rank": rank, "gain": gain, "description": description, "buy": buy}

func refresh() -> void:
	var previous_owner := get_viewport().gui_get_focus_owner()
	var focus_was_inside := previous_owner != null and _root.is_ancestor_of(previous_owner)
	var available := _profile_available()
	_summary = (Global.call("get_city_development_summary") as Dictionary) if available and Global.has_method("get_city_development_summary") else {}
	_options = _read_options()
	var points := maxi(0, int(_summary.get("points", 0)))
	var earned := maxi(0, int(_summary.get("earned", 0)))
	var invested := maxi(0, earned - points)
	_wallet.text = "%d CHOICE%s AVAILABLE · %d RESEARCH INVESTED" % [points, "" if points == 1 else "S", invested]
	if not available:
		_status.text = "Select or create a profile in the Archives before choosing an improvement."
	elif _options.is_empty():
		_status.text = "Development choices are not available for this profile yet."
	elif points <= 0:
		_status.text = "All 10 city Research have been earned and invested. Your previous choices remain." if earned >= 10 else "No choices remain. Your previous choices remain; a new first city clear can earn another Research."
	else:
		_status.text = "Choose one improvement below. Each choice spends exactly 1 Research."
	for option: Dictionary in _options:
		var id := String(option.get("id", ""))
		if not _rows.has(id):
			_create_option(option)
		var row := _rows[id] as Dictionary
		var rank := int(option.get("rank", 0)) if available else 0
		var cap := maxi(1, int(option.get("cap", 1)))
		(row["rank"] as Label).text = "RANK %d / %d" % [rank, cap]
		(row["gain"] as Label).text = "%s\nRetained: %s" % [String(option.get("next_gain_text", "")), String(option.get("total_gain_text", "")) if available else "select a profile"]
		var target_ok := true
		if _selectors.has(id):
			target_ok = _refresh_selector(id, available)
		var buy := row["buy"] as Button
		var cost := maxi(1, int(option.get("cost", 1)))
		buy.text = "MAXED" if rank >= cap else "CHOOSE · %d RESEARCH" % cost
		buy.disabled = not available or points < cost or rank >= cap or not target_ok
		buy.tooltip_text = "Choose one improvement for your next attempt. Earlier choices remain."
		if not available:
			buy.tooltip_text = "Select a profile first."
		elif not target_ok:
			buy.tooltip_text = "Own an augment before investing in its training."
		elif rank >= cap:
			buy.tooltip_text = "This improvement has reached its permanent rank cap."
		elif points < cost:
			buy.tooltip_text = "A first city-segment clear earns the Research for another choice."
	_refresh_summaries(available)
	_update_focus_ring()
	if focus_was_inside and get_viewport().gui_get_focus_owner() == null:
		_focus_first()

func _refresh_selector(id: String, available: bool) -> bool:
	var selector := _selectors[id] as OptionButton
	selector.clear()
	var owned: Array = Global.call("get_owned_augment_ids") if available else []
	var chosen := String(_summary.get("augment_id", "")) if id == "augment" else ""
	if chosen.is_empty():
		chosen = String(_target_choices.get(id, ""))
	var selected := -1
	var seen: Dictionary = {}
	for value: Variant in owned:
		var augment_id := StringName(String(value))
		var definition := Global.augment_db.get(augment_id, null) as AugmentData
		if augment_id == StringName() or definition == null or seen.has(augment_id):
			continue
		seen[augment_id] = true
		var index := selector.item_count
		selector.add_item(definition.display_name)
		selector.set_item_metadata(index, String(augment_id))
		selector.get_popup().set_item_tooltip(index, definition.display_name)
		if String(augment_id) == chosen:
			selected = index
	selector.disabled = not available or selector.item_count == 0
	if selector.item_count == 0:
		_target_choices.erase(id)
		selector.tooltip_text = "No owned augment is available. Discover an augment before choosing training."
		return false
	selected = 0 if selected < 0 else selected
	selector.select(selected)
	_target_choices[id] = String(selector.get_item_metadata(selected))
	selector.tooltip_text = "Choose the one owned augment to train for later attempts."
	return true

func _on_target_selected(index: int, id: String) -> void:
	var selector := _selectors.get(id, null) as OptionButton
	if selector == null or index < 0 or index >= selector.item_count:
		return
	var target := StringName(String(selector.get_item_metadata(index)))
	_target_choices[id] = String(target)
	var ranks := _summary.get("ranks", {}) as Dictionary
	if id == "augment" and int(ranks.get(id, 0)) > 0:
		Global.call("select_trained_augment", target)
	refresh()

func _purchase(id: String) -> void:
	var row := _rows.get(id, {}) as Dictionary
	var buy := row.get("buy", null) as Button
	if buy == null or buy.disabled or not _profile_available():
		return
	var target := StringName(String(_target_choices.get(id, "")))
	var purchased := bool(Global.call("purchase_city_development", StringName(id), target))
	refresh()
	if purchased:
		_status.text = "One improvement chosen. Your previous choices remain. It applies from your next attempt."
	else:
		_status.text = "This improvement could not be chosen. Check the Research, rank cap and owned augment target."

func _refresh_summaries(available: bool) -> void:
	if not available:
		_next_summary.text = "Next attempt: choose a profile to view its retained improvements."
		_active_summary.text = "This attempt: no profile selected."
		return
	var totals := PackedStringArray()
	for option: Dictionary in _options:
		if int(option.get("rank", 0)) > 0:
			totals.append(String(option.get("total_gain_text", "")))
	var trained := String(_summary.get("augment_id", ""))
	var definition := Global.augment_db.get(StringName(trained), null) as AugmentData
	if definition != null and int((_summary.get("ranks", {}) as Dictionary).get("augment", 0)) > 0:
		totals.append("%s starts at Lv.2" % definition.display_name)
	_next_summary.text = "Next attempt: " + (" · ".join(totals) if not totals.is_empty() else "no improvements chosen yet.")
	if not Global.attempt_active:
		_active_summary.text = "This attempt: none in progress. Your retained choices apply when the next attempt begins."
		return
	var active := _summary.get("active_bonuses", {}) as Dictionary
	var active_parts := _bonus_parts(active)
	_active_summary.text = "This attempt began with: " + (" · ".join(active_parts) if not active_parts.is_empty() else "no retained improvements") + ". New choices leave this attempt unchanged."

func _bonus_parts(bonuses: Dictionary) -> PackedStringArray:
	var parts := PackedStringArray()
	for entry: Array in [["hp", "HP"], ["armor", "armor"], ["bag_slots", "bag slot(s)"], ["speed", "world px/s movement"]]:
		var amount := float(bonuses.get(entry[0], 0.0))
		if not is_zero_approx(amount):
			parts.append("+%s %s" % [String.num(amount, 0), String(entry[1])])
	for entry: Array in [["haste", "Haste"], ["power", "Power"]]:
		var amount := float(bonuses.get(entry[0], 0.0))
		if not is_zero_approx(amount):
			parts.append("+%s%% %s" % [String.num(amount * 100.0, 0), String(entry[1])])
	if not is_zero_approx(float(bonuses.get("luck", 0.0))):
		parts.append("+%.2f Luck" % float(bonuses["luck"]))
	for entry: Array in [["range_multiplier", "native attack reach"], ["size_multiplier", "native attack size"]]:
		var multiplier := float(bonuses.get(entry[0], 1.0))
		if not is_equal_approx(multiplier, 1.0):
			parts.append("+%s%% %s" % [String.num((multiplier - 1.0) * 100.0, 0), String(entry[1])])
	var target := StringName(String(bonuses.get("augment_id", "")))
	var augment := Global.augment_db.get(target, null) as AugmentData
	if augment != null:
		parts.append("%s starts at Lv.2" % augment.display_name)
	if bool(bonuses.get("binding_echo", false)):
		parts.append("Binding Echo: two rewards after the fifth city Rite")
	return parts

func _update_focus_ring() -> void:
	var targets: Array[Control] = []
	for option: Dictionary in _options:
		var id := String(option.get("id", ""))
		var selector := _selectors.get(id, null) as OptionButton
		if selector != null and not selector.disabled:
			targets.append(selector)
		var row := _rows.get(id, {}) as Dictionary
		var buy := row.get("buy", null) as Button
		if buy != null and not buy.disabled:
			targets.append(buy)
	targets.append(_close_button)
	for index in range(targets.size()):
		var control := targets[index]
		var previous := targets[(index - 1 + targets.size()) % targets.size()]
		var next := targets[(index + 1) % targets.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_neighbor_left = control.get_path_to(previous)
		control.focus_neighbor_right = control.get_path_to(next)
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and _root.is_ancestor_of(owner) and not targets.has(owner):
		targets[0].grab_focus()

func _focus_arrival() -> void:
	# Begin at the retained-choice explanation. Tab/Down from Close reaches
	# the first available improvement without an initial focus scroll jump.
	_close_button.grab_focus()
	_scroll.scroll_vertical = 0

func _focus_first() -> void:
	for option: Dictionary in _options:
		var row := _rows.get(String(option.get("id", "")), {}) as Dictionary
		var buy := row.get("buy", null) as Button
		if buy != null and not buy.disabled:
			buy.grab_focus()
			return
	_close_button.grab_focus()

func _queue_fit_panel() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	_finish_panel_fit.call_deferred()

func _finish_panel_fit() -> void:
	_fit_queued = false
	# Wrapping labels initially measure before their final width exists. Refit
	# after the container's minimum settles, including when it shrinks again.
	_fit_panel()

func _fit_panel() -> void:
	if _panel == null:
		return
	var area := get_viewport().get_visible_rect().size
	var gap := 14.0 if area.x < 800.0 else 28.0
	var wanted := Vector2(minf(1100.0, area.x - gap * 2.0), minf(930.0, area.y - gap * 2.0))
	_panel.size = wanted
	_panel.position = (area - wanted) * 0.5
	var padding := 16 if area.x < 800.0 else 28
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, padding)
