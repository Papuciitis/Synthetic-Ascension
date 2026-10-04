extends CanvasLayer
class_name AscensionScreen
## The advancement tree screen: the radial map as a living astrolabe, and a
## framed node panel floating over its right side with the authored rules,
## the price or the reason a purchase is refused, and the buttons for buying,
## refunding, equipping and toggling mutations. Opens from the Hub beside
## Augments and mid-run on the tree key, in the front end's arcane register
## (docs/design/2026-10-02-front-end-arcane-register.md).

signal closed()

const GATE_CORES: Array[String] = ["melee", "ranged", "magic"]
const ARCANE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const ArcaneRuleScript := preload("res://ui/components/ArcaneRule.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

const PANEL_WIDTH := 440.0
const PANEL_MARGIN := 26.0
const GOLD := Color(0.86, 0.64, 0.36)
const GOLD_DIM := Color(0.62, 0.47, 0.30)
const GOLD_BRIGHT := Color(0.99, 0.84, 0.58)
const PARCHMENT := Color(0.91, 0.86, 0.77)
const BODY := Color(0.82, 0.77, 0.68)
const MUTED := Color(0.58, 0.53, 0.46)

var view: AscensionTreeView = null
var _panel: VBoxContainer = null
var _header: Label = null
var _title: Label = null
var _meta: Label = null
var _rules: RichTextLabel = null
var _status: Label = null
var _buttons: HFlowContainer = null
var _gate_row: HFlowContainer = null
var _pause_on_close: bool = false
var _trigger_button: Button = null
var _trigger_row: HBoxContainer = null
var _details: VBoxContainer = null
var _shown_id: String = ""
var _pause_was: bool = false
var _selected: String = ""
var _root: Control = null
var _side: PanelContainer = null
var _frame: Control = null
var _wallet: Label = null
var _spent: Label = null
var _claims: Label = null
var _loadout: GridContainer = null
var _hint: Label = null
var _veil: ColorRect = null
var _shown_followers: int = -1
var _wallet_tween: Tween = null
var _glow_tween: Tween = null


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
	_play_opening()


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
	root.theme = ARCANE_THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_root = root
	# The tree view's own sky is opaque: it is the scrim.

	view = AscensionTreeView.new()
	view.name = "TreeView"
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.reserve_right = PANEL_WIDTH + PANEL_MARGIN * 2.0
	view.cover_right = PANEL_WIDTH + PANEL_MARGIN
	root.add_child(view)
	view.node_hovered.connect(_on_hovered)
	view.node_clicked.connect(_on_clicked)
	view.node_activated.connect(_on_activated)

	_build_legend(root)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.theme_type_variation = &"ArcaneCaption"
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(GOLD_DIM, 0.85))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_stylebox_override("normal", _backing())
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = PANEL_MARGIN
	_hint.offset_top = -PANEL_MARGIN - 26.0
	_hint.offset_bottom = -PANEL_MARGIN
	root.add_child(_hint)

	# The node panel floats over the right of the sky, framed like Settings.
	var side := PanelContainer.new()
	side.name = "Side"
	side.theme_type_variation = &"ArcanePanel"
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_bottom = 1.0
	side.offset_left = -(PANEL_WIDTH + PANEL_MARGIN)
	side.offset_right = -PANEL_MARGIN
	side.offset_top = PANEL_MARGIN
	side.offset_bottom = -PANEL_MARGIN
	# The register's panel, a touch more opaque: the lattice runs behind it.
	var panel_style := ARCANE_THEME.get_stylebox(&"panel", &"ArcanePanel")
	if panel_style is StyleBoxFlat:
		var denser := (panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		denser.bg_color.a = 0.965
		side.add_theme_stylebox_override("panel", denser)
	root.add_child(side)
	_side = side
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	side.add_child(margin)
	_frame = ArcaneFrameScript.new() as Control
	_frame.name = "Frame"
	side.add_child(_frame)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 9)
	margin.add_child(_panel)

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "ASCENSION"
	heading.theme_type_variation = &"ArcaneTitle"
	heading.add_theme_font_size_override("font_size", 38)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(heading)
	_header = Label.new()
	_header.name = "TreeVersion"
	_header.theme_type_variation = &"ArcaneCaption"
	_header.add_theme_font_size_override("font_size", 12)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_header)
	_panel.add_child(_rule(1, 16.0, 300.0))

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 0)
	_panel.add_child(stats)
	_wallet = _stat(stats, "FOLLOWERS", 28, GOLD_BRIGHT, 1.5)
	_spent = _stat(stats, "SPENT", 20, BODY, 1.0)
	_claims = _stat(stats, "CLAIMS", 20, BODY, 1.0)

	_loadout = GridContainer.new()
	_loadout.columns = 2
	_loadout.add_theme_constant_override("h_separation", 14)
	_loadout.add_theme_constant_override("v_separation", 2)
	_panel.add_child(_loadout)
	_panel.add_child(_rule(1, 16.0, 0.0))

	# The node's details, faded in afresh when the shown node changes.
	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 9)
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(_details)
	_title = Label.new()
	_title.theme_type_variation = &"ArcaneHeading"
	_title.add_theme_font_size_override("font_size", 24)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.text = "Select a node"
	_details.add_child(_title)
	_meta = Label.new()
	_meta.theme_type_variation = &"ArcaneCaption"
	_meta.add_theme_font_size_override("font_size", 12)
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta.text = "Hover a node to read it; double-click to buy."
	_details.add_child(_meta)
	_status = Label.new()
	_status.theme_type_variation = &"ArcaneBody"
	_status.add_theme_font_size_override("font_size", 17)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_child(_status)
	_gate_row = HFlowContainer.new()
	_gate_row.add_theme_constant_override("h_separation", 8)
	_gate_row.add_theme_constant_override("v_separation", 8)
	_details.add_child(_gate_row)
	_buttons = HFlowContainer.new()
	_buttons.add_theme_constant_override("h_separation", 8)
	_buttons.add_theme_constant_override("v_separation", 8)
	_details.add_child(_buttons)
	_details.add_child(_rule(1, 14.0, 0.0))
	# The details SCROLL below the actions (playtest finding: a long rules
	# text crammed the footer and hid what you could actually do).
	_rules = RichTextLabel.new()
	_rules.bbcode_enabled = false
	_rules.fit_content = false
	_rules.scroll_active = true
	_rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rules.custom_minimum_size = Vector2(0, 160)
	_rules.add_theme_color_override("default_color", BODY)
	_rules.add_theme_font_size_override("normal_font_size", 18)
	_rules.add_theme_constant_override("line_separation", 2)
	_details.add_child(_rules)
	# The Reaction trigger gets its own row once the slot opens.
	_trigger_row = HBoxContainer.new()
	_trigger_row.add_theme_constant_override("separation", 10)
	_trigger_row.visible = false
	_panel.add_child(_trigger_row)
	var trigger_caption := Label.new()
	trigger_caption.text = "REACTION TRIGGER"
	trigger_caption.theme_type_variation = &"ArcaneCaption"
	trigger_caption.add_theme_font_size_override("font_size", 11)
	trigger_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trigger_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trigger_row.add_child(trigger_caption)
	_trigger_button = Button.new()
	_trigger_button.text = "Reaction trigger"
	_trigger_button.theme_type_variation = &"ArcaneSmallButton"
	_trigger_button.custom_minimum_size = Vector2(190, 38)
	_trigger_button.focus_mode = Control.FOCUS_NONE
	_trigger_button.tooltip_text = "When the Reaction Q casts itself: a catastrophe begins, you lose 15% max HP within a second, or the first elite enters 2R."
	_trigger_button.pressed.connect(func() -> void:
		var ledger := _ledger()
		if ledger == null:
			return
		var options := AscensionLedger.REACTION_TRIGGERS
		var index := options.find(ledger.reaction_trigger())
		ledger.set_reaction_trigger(options[(index + 1) % options.size()])
		_after_change())
	_trigger_row.add_child(_trigger_button)
	_panel.add_child(_rule(0, 12.0, 0.0))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	_panel.add_child(footer)
	var fit_button := Button.new()
	fit_button.text = "Fit"
	fit_button.theme_type_variation = &"ArcaneSmallButton"
	fit_button.custom_minimum_size = Vector2(90, 40)
	fit_button.focus_mode = Control.FOCUS_NONE
	fit_button.pressed.connect(func() -> void: view.fit())
	footer.add_child(fit_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(120, 40)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	footer.add_child(close_button)

	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(0.005, 0.004, 0.003, 0.62)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false
	root.add_child(_veil)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Confirm purchase"
	_confirm.ok_button_text = "Buy"
	_confirm.exclusive = true
	_style_dialog(_confirm)
	var confirm_box := VBoxContainer.new()
	confirm_box.add_theme_constant_override("separation", 12)
	_confirm_text = Label.new()
	_confirm_text.theme_type_variation = &"ArcaneBody"
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.custom_minimum_size = Vector2(420, 0)
	confirm_box.add_child(_confirm_text)
	_confirm_core = OptionButton.new()
	_confirm_core.visible = false
	_confirm_core.custom_minimum_size = Vector2(0, 42)
	confirm_box.add_child(_confirm_core)
	_confirm.add_child(confirm_box)
	_confirm.confirmed.connect(_confirm_pending_purchase)
	_confirm.visibility_changed.connect(_on_confirm_visibility)
	root.add_child(_confirm)

	var layout := AscensionTreeLayout.new()
	var db := _db()
	layout.compute(db)
	view.setup(db, layout)
	view.call_deferred("fit")


func _rule(ornament: int, height: float, width: float) -> Control:
	var rule := ArcaneRuleScript.new() as Control
	rule.set("ornament", ornament)
	rule.custom_minimum_size = Vector2(width, height)
	if width > 0.0:
		rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rule


func _stat(row: HBoxContainer, caption: String, value_size: int, colour: Color, stretch: float) -> Label:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_stretch_ratio = stretch
	cell.add_theme_constant_override("separation", -2)
	row.add_child(cell)
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = &"ArcaneCaption"
	label.add_theme_font_size_override("font_size", 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(label)
	var value := Label.new()
	value.theme_type_variation = &"ArcaneHeading"
	value.add_theme_font_size_override("font_size", value_size)
	value.add_theme_color_override("font_color", colour)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.text = "0"
	cell.add_child(value)
	return value


## The legend for the node states, drawn with the tree's own glyphs.
func _build_legend(root: Control) -> void:
	var legend := Control.new()
	legend.name = "Legend"
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.position = Vector2(PANEL_MARGIN + 6.0, PANEL_MARGIN + 4.0)
	legend.custom_minimum_size = Vector2(720, 24)
	legend.size = legend.custom_minimum_size
	root.add_child(legend)
	var font := ARCANE_THEME.get_font(&"font", &"ArcaneCaption")
	var backing := _backing()
	legend.draw.connect(func() -> void:
		var entries := [
			["OWNED", AscensionTreeView.ST_OWNED], ["BUYABLE", AscensionTreeView.ST_BUYABLE],
			["NEEDS FOLLOWERS", AscensionTreeView.ST_REACHABLE], ["LOCKED", AscensionTreeView.ST_LOCKED],
			["SEALED", AscensionTreeView.ST_SEALED], ["EQUIPPED", -1],
		]
		var width := 8.0
		for entry in entries:
			width += 13.0 + font.get_string_size(String(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 22.0
		legend.draw_style_box(backing, Rect2(Vector2(-6.0, -3.0), Vector2(width - 8.0, 28.0)))
		var x := 8.0
		for entry in entries:
			var at := Vector2(x, 11.0)
			_legend_glyph(legend, at, int(entry[1]))
			legend.draw_string(font, Vector2(x + 13.0, 16.0), String(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(GOLD_DIM, 0.95))
			x += 13.0 + font.get_string_size(String(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 22.0)


## A soft dark backing so the legend and the hint read over the lattice.
static func _backing() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.018, 0.015, 0.013, 0.7)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	box.shadow_color = Color(0.018, 0.015, 0.013, 0.45)
	box.shadow_size = 10
	return box


func _legend_glyph(canvas: Control, at: Vector2, state: int) -> void:
	var r := 5.0
	match state:
		AscensionTreeView.ST_OWNED:
			canvas.draw_circle(at, r, Color(0.3, 0.2, 0.1))
			canvas.draw_circle(at, r * 0.65, Color(GOLD, 0.5))
			canvas.draw_arc(at, r, 0.0, TAU, 20, GOLD_BRIGHT, 1.4, true)
		AscensionTreeView.ST_BUYABLE:
			canvas.draw_circle(at, r, AscensionTreeView.INK.lerp(AscensionTreeView.EMBER, 0.2))
			canvas.draw_arc(at, r, 0.0, TAU, 20, AscensionTreeView.EMBER.lerp(GOLD_BRIGHT, 0.3), 1.6, true)
		AscensionTreeView.ST_REACHABLE:
			canvas.draw_circle(at, r, AscensionTreeView.INK)
			canvas.draw_arc(at, r, 0.0, TAU, 20, GOLD_DIM, 1.2, true)
		AscensionTreeView.ST_LOCKED:
			canvas.draw_circle(at, r, AscensionTreeView.INK)
			canvas.draw_arc(at, r, 0.0, TAU, 20, Color(AscensionTreeView.BRONZE, 0.8), 1.0, true)
		AscensionTreeView.ST_SEALED:
			canvas.draw_circle(at, r, AscensionTreeView.INK.lerp(AscensionTreeView.DANGER, 0.14))
			canvas.draw_arc(at, r, 0.0, TAU, 20, AscensionTreeView.DANGER.darkened(0.25), 1.2, true)
			canvas.draw_line(at + Vector2(-r, r) * 0.55, at + Vector2(r, -r) * 0.55, Color(AscensionTreeView.DANGER, 0.7), 1.2, true)
		_:
			canvas.draw_circle(at, r - 1.0, Color(0.3, 0.2, 0.1))
			canvas.draw_arc(at, r - 1.0, 0.0, TAU, 20, GOLD_BRIGHT, 1.2, true)
			canvas.draw_arc(at, r + 1.8, 0.0, TAU, 24, PARCHMENT, 1.0, true)


## The purchase confirmation wears the project theme's window chrome
## (ArcaneMenuTheme: the double gold rule, corner diamonds, Cinzel title and
## its rule, the gold close mark), the same as every other window.
func _style_dialog(dialog: ConfirmationDialog) -> void:
	dialog.theme = ARCANE_THEME
	# The window's own clear colour would show as a grey seam at the edge.
	dialog.transparent_bg = true


func _on_confirm_visibility() -> void:
	if _veil == null or _confirm == null:
		return
	if _confirm.visible:
		_veil.visible = true
		_veil.modulate.a = 0.0
		var tween := create_tween().set_ignore_time_scale(true)
		tween.tween_property(_veil, "modulate:a", 1.0, 0.16)
	else:
		_veil.visible = false


## The screen breathes in: the veil of the sky fades up while the tree
## unfurls from its core, and the panel slides in from the right.
func _play_opening() -> void:
	if _root == null or _side == null:
		return
	var still := ArcaneMotion.reduced()
	if view != null:
		view.replay_opening()
	_root.modulate.a = 0.0
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_root, "modulate:a", 1.0, 0.22 if not still else 0.3)
	_side.modulate.a = 0.0
	var side_tween := create_tween().set_ignore_time_scale(true)
	side_tween.tween_interval(0.08)
	side_tween.tween_property(_side, "modulate:a", 1.0, 0.4 if not still else 0.3)
	if not still:
		var home := _side.offset_left
		_side.offset_left = home + 40.0
		_side.offset_right = -PANEL_MARGIN + 40.0
		var slide := create_tween().set_ignore_time_scale(true).set_parallel(true)
		slide.tween_property(_side, "offset_left", home, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.08)
		slide.tween_property(_side, "offset_right", -PANEL_MARGIN, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.08)


## A purchase lands: the panel's frame warms and settles, the title flares.
func _celebrate_panel() -> void:
	if _frame == null:
		return
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween().set_ignore_time_scale(true)
	_frame.set("glow", 0.0)
	_glow_tween.tween_property(_frame, "glow", 0.85, 0.16)
	_glow_tween.tween_property(_frame, "glow", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _title != null:
		_title.modulate = Color(1.35, 1.2, 0.95)
		var flare := create_tween().set_ignore_time_scale(true)
		flare.tween_property(_title, "modulate", Color.WHITE, 0.7)


func _set_wallet(value: int) -> void:
	if _wallet == null:
		return
	if _shown_followers < 0 or ArcaneMotion.reduced() or not is_inside_tree():
		_shown_followers = value
		_wallet.text = _grouped(value)
		return
	if value == _shown_followers:
		return
	if _wallet_tween != null and _wallet_tween.is_valid():
		_wallet_tween.kill()
	var from := _shown_followers
	_shown_followers = value
	_wallet_tween = create_tween().set_ignore_time_scale(true)
	_wallet_tween.tween_method(func(v: float) -> void: _wallet.text = _grouped(int(round(v))), float(from), float(value), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func _grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


# ---------------------------------------------------------------- refresh

func _ledger() -> AscensionLedger:
	return Global.ascension_ledger() if Global != null else null


## The run's own tree data (V4 or the V5 prototype), never assumed V4.
func _db() -> AscensionTreeDB:
	var ledger := _ledger()
	return ledger.db if ledger != null else AscensionTreeDB.shared()


func _refresh_all() -> void:
	var ledger := _ledger()
	if ledger == null or view == null:
		return
	view.refresh(ledger, Global.followers)
	var cores := PackedStringArray()
	for core in ledger.cores():
		cores.append(String(core).to_upper())
	var claims := int(ledger.state.get("evolution_claims", 0))
	# The run's tree version is visible, always (playtest review finding 1):
	# V4 and V5 reuse node ids with different meanings, so the player must
	# never have to infer which tree they are buying into.
	var version_label := "TREE V5 (RANGED PROTOTYPE)" if ledger.is_v5() else "TREE V4"
	_header.text = "%s\nNATIVE %s   ·   CORES %s" % [version_label, ledger.native_core().to_upper(), " ".join(cores)]
	_set_wallet(Global.followers)
	_spent.text = _grouped(int(ledger.state.get("spent", 0)))
	_claims.text = str(claims)
	_fill_loadout(ledger)
	if _trigger_button != null:
		_trigger_button.text = ledger.reaction_trigger().capitalize()
		_trigger_button.visible = ledger.reaction_slot_open()
		_trigger_row.visible = _trigger_button.visible
	if _hint != null:
		var refund := Global != null and Global.ascension_refund_context_hub
		_hint.text = "WHEEL  ZOOM   ·   DRAG  PAN   ·   DOUBLE-CLICK  BUY%s   ·   ESC  CLOSE" % ("   ·   RIGHT-CLICK  REFUND" if refund else "")
	if not _selected.is_empty():
		_show(_selected)


## The equipped loadout as caption / name rows; empty slots read as a dash.
func _fill_loadout(ledger: AscensionLedger) -> void:
	if _loadout == null:
		return
	for child in _loadout.get_children():
		_loadout.remove_child(child)
		child.queue_free()
	var rows := [["Q", ledger.equipped("q"), ""], ["REACTION", ledger.equipped("reaction"), "on " + ledger.reaction_trigger()], ["V", ledger.equipped("v"), ""]]
	if not ledger.equipped("v2").is_empty():
		rows.append(["V2", ledger.equipped("v2"), ""])
	for row in rows:
		var caption := Label.new()
		caption.text = String(row[0])
		caption.theme_type_variation = &"ArcaneCaption"
		caption.add_theme_font_size_override("font_size", 11)
		caption.custom_minimum_size = Vector2(78, 0)
		_loadout.add_child(caption)
		var value := Label.new()
		var id := String(row[1])
		var note := String(row[2])
		value.text = (_name_of(id) if not id.is_empty() else "—") + (("   (" + note + ")") if not note.is_empty() else "")
		value.theme_type_variation = &"ArcaneBody"
		value.add_theme_font_size_override("font_size", 16)
		value.add_theme_color_override("font_color", PARCHMENT if not id.is_empty() else MUTED)
		value.clip_text = true
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_loadout.add_child(value)


func _name_of(id: String) -> String:
	if id.is_empty():
		return "-"
	return String(_db().node(id).get("name", id))


var _confirm: ConfirmationDialog = null
var _confirm_text: Label = null
var _confirm_core: OptionButton = null
var _pending_purchase: String = ""


func _on_hovered(id: String) -> void:
	if _selected.is_empty() and not id.is_empty():
		_show(id)


func _on_clicked(id: String, button: int) -> void:
	_selected = id
	_show(id)
	if button == MOUSE_BUTTON_RIGHT:
		_refund(id)


## Double-click is the purchase gesture: name, rank and the EXACT cost in a
## confirmation, a Core choice where the node is a Gate, and a fresh
## eligibility check at the moment of confirmation (playtest review).
func _on_activated(id: String) -> void:
	_selected = id
	_show(id)
	_request_purchase(id)


func _request_purchase(id: String) -> void:
	var ledger := _ledger()
	var db := _db()
	if ledger == null or _confirm == null or not db.has(id):
		return
	var kind := db.kind(id)
	_confirm_core.visible = false
	_confirm_core.clear()
	var verdict: Dictionary
	if kind == "gate" and not ledger.owns(id):
		# The Gate needs a Core decision; the dialog carries the choice.
		var any := false
		for core_id in GATE_CORES:
			var core_verdict := ledger.can_buy(id, Global.followers, core_id)
			if bool(core_verdict["ok"]):
				_confirm_core.add_item("%s  (%d Followers)" % [core_id.to_upper(), int(core_verdict["cost"])])
				_confirm_core.set_item_metadata(_confirm_core.item_count - 1, core_id)
				any = true
		if not any:
			_status.text = String(ledger.can_buy(id, Global.followers, _first_unopened(ledger))["reason"]).capitalize()
			return
		_confirm_core.visible = true
		_confirm_core.select(0)
		verdict = {"ok": true, "cost": -1}
	else:
		verdict = ledger.can_buy(id, Global.followers)
		if not bool(verdict["ok"]):
			_status.text = String(verdict["reason"]).capitalize()
			return
	_pending_purchase = id
	var name_text := _name_of(id)
	if bool(verdict.get("rank_up", false)):
		_confirm_text.text = "%s — Rank %s -> %s
Exact cost: %d Followers (you have %d)." % [
			name_text, _roman(ledger.rank(id)), _roman(int(verdict["next_rank"])), int(verdict["cost"]), Global.followers]
	elif kind == "gate":
		_confirm_text.text = "%s — opening a foreign Core.
Choose which Core this Gate opens." % name_text
	else:
		_confirm_text.text = "%s
Exact cost: %d Followers (you have %d)." % [name_text, int(verdict["cost"]), Global.followers]
	_confirm.reset_size()
	_confirm.popup_centered()


func _confirm_pending_purchase() -> void:
	var id := _pending_purchase
	_pending_purchase = ""
	if id.is_empty():
		return
	var ledger := _ledger()
	if ledger == null:
		return
	var chosen_core := ""
	if _confirm_core != null and _confirm_core.visible and _confirm_core.selected >= 0:
		chosen_core = String(_confirm_core.get_item_metadata(_confirm_core.selected))
	# Eligibility is rechecked NOW: the wallet, gates or ranks may have
	# moved while the dialog stood open. _buy routes through the ordinary
	# transaction and surfaces the ledger's reason on refusal.
	var verdict := ledger.can_buy(id, Global.followers, chosen_core)
	if not bool(verdict["ok"]):
		_status.text = String(verdict["reason"]).capitalize()
		return
	_buy(id, chosen_core)


func _show(id: String) -> void:
	var db := _db()
	var ledger := _ledger()
	if not db.has(id) or ledger == null:
		return
	var node := db.node(id)
	if id != _shown_id:
		_shown_id = id
		if _details != null and is_inside_tree() and not ArcaneMotion.reduced():
			_details.modulate.a = 0.45
			create_tween().set_ignore_time_scale(true).tween_property(_details, "modulate:a", 1.0, 0.16)
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
	var ranked := kind == "local" and db.max_rank(id) > 1
	if ledger.owns(id):
		if kind == "sink":
			lines.append("Rank %d owned. Next rank %d Followers." % [ledger.rank(id), ledger.price(id)])
		elif ranked:
			var current := ledger.rank(id)
			var top := db.max_rank(id)
			var paid_total := 0
			for receipt in ledger.rank_receipts(id):
				paid_total += int(receipt)
			lines.append("Rank %s of %d.  Paid so far: %d." % [_roman(current), top, paid_total])
			var now_effect := db.rank_effect(id, current)
			if not now_effect.is_empty():
				lines.append("Now: %s." % now_effect)
			if current < top:
				var next_effect := db.rank_effect(id, current + 1)
				lines.append("Next rank (%d Followers): %s." % [ledger.scaled_price(db.rank_cost(id, current + 1)), next_effect])
		else:
			lines.append("Owned." + (" Equipped." if ledger.is_equipped(id) else ""))
	if kind == "gate" and not ledger.owns(id):
		var any_core := false
		for core_id in GATE_CORES:
			var verdict := ledger.can_buy(id, Global.followers, core_id)
			if bool(verdict["ok"]):
				any_core = true
				var gate_button := _action_button("Open %s (%d)" % [core_id.to_upper(), int(verdict["cost"])], &"")
				gate_button.pressed.connect(func() -> void: _buy(id, core_id))
				_gate_row.add_child(gate_button)
		if not any_core:
			lines.append(String(ledger.can_buy(id, Global.followers, _first_unopened(ledger))["reason"]))
	elif not ledger.owns(id) or kind == "sink" or (ranked and ledger.rank(id) < db.max_rank(id)):
		var verdict := ledger.can_buy(id, Global.followers)
		if bool(verdict["ok"]):
			var buy_text := ""
			if bool(verdict.get("rank_up", false)):
				buy_text = "Rank %s for %d" % [_roman(int(verdict["next_rank"])), int(verdict["cost"])]
			else:
				buy_text = "Buy" if int(verdict["cost"]) == 0 else "Buy for %d" % int(verdict["cost"])
			var buy := _action_button(buy_text, &"")
			buy.custom_minimum_size = Vector2(170, 42)
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
				if ledger.owns("ASC"):
					_slot_button("v2", id, "Equip 2nd V", ledger)
			"keystone":
				_slot_button("keystones", id, "Equip Keystone", ledger)
			"axiom":
				_slot_button("axioms", id, "Equip Axiom", ledger)
			"mutation", "revelation_mutation":
				var disabled: bool = (ledger.state.get("disabled_mutations", []) as Array).has(id)
				var toggle := _action_button("Enable" if disabled else "Disable", &"ArcaneSmallButton")
				toggle.pressed.connect(func() -> void:
					ledger.set_mutation_enabled(id, disabled)
					_after_change())
				_buttons.add_child(toggle)
		if kind != "core" and kind != "gate" and kind != "choice":
			if Global != null and Global.ascension_refund_context_hub and Global.ascension_refunds_forfeit():
				lines.append("Tithe Ledger: every purchase is a vow; nothing refunds.")
			elif Global != null and Global.ascension_refund_context_hub:
				var share := AscensionLedger.refund_share(Global.attempt_segment)
				if ranked and ledger.rank(id) >= 2:
					var downgrade_preview := ledger.downgrade_preview(id, share)
					if bool(downgrade_preview["ok"]):
						var down := _action_button("Downgrade %d%% (+%d)" % [int(round(100.0 * share)), int(downgrade_preview["refund"])], &"ArcaneSmallButton")
						down.tooltip_text = "Remove the highest rank; the shown share of its recorded payment returns."
						down.pressed.connect(func() -> void: _downgrade(id))
						_buttons.add_child(down)
				var actual := ledger.refund_value(id, share)
				var refund := _action_button("Refund %d%% (+%d)" % [int(round(100.0 * share)), actual], &"ArcaneDangerButton")
				refund.tooltip_text = "Refund this node and everything that depended on it; the shown share of what they cost returns, and of any rank this forces off another node. Revelations, forks, Unions, Axioms and Catastrophes never refund."
				refund.pressed.connect(func() -> void: _refund(id))
				_buttons.add_child(refund)
	_status.text = "\n".join(lines)


func _action_button(text: String, variation: StringName) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, 40)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _first_unopened(ledger: AscensionLedger) -> String:
	for core_id in GATE_CORES:
		if not ledger.has_core(core_id):
			return core_id
	return "melee"


func _slot_button(slot: String, id: String, label: String, ledger: AscensionLedger) -> void:
	var equipped := ledger.equipped(slot) == id if slot in ["q", "v", "v2", "reaction"] else ledger.equipped_list(slot).has(id)
	var button := _action_button("Unequip" if equipped else label, &"ArcaneSmallButton")
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
	_celebrate_panel()
	_after_change()


const ROMAN := ["0", "I", "II", "III", "IV", "V"]


func _roman(rank: int) -> String:
	return ROMAN[rank] if rank >= 0 and rank < ROMAN.size() else str(rank)


func _downgrade(id: String) -> void:
	if Global == null:
		return
	if not Global.ascension_refund_context_hub:
		_status.text = "Downgrades are a Hub decision."
		return
	var back := Global.ascension_downgrade(id)
	if back > 0:
		_after_change()


func _refund(id: String) -> void:
	if Global == null:
		return
	if not Global.ascension_refund_context_hub:
		if _status != null:
			_status.text = "Refunds are a Hub decision."
		return
	var preview: Dictionary = _ledger().refund_preview(id)
	var blocked: Array = preview.get("blocked", [])
	if not blocked.is_empty():
		if _status != null:
			_status.text = "Sworn: %s never refund%s." % [", ".join(PackedStringArray(blocked)), "" if blocked.size() == 1 else ""]
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
