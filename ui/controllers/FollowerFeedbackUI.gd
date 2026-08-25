extends CanvasLayer

## Cross-scene follower feedback. Small combat gains are coalesced; meaningful
## commitments, drains and victories are explained immediately.

const SHARED_THEME := preload("res://ui/theme/SyntheticHudTheme.tres")

var _panel: PanelContainer
var _seal: Label
var _value: Label
var _body: Label
var _pending_gain: int = 0
var _aggregate_left: float = 0.0
var _visible_left: float = 0.0


func _ready() -> void:
	layer = 180
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if Global != null and not Global.followers_transaction.is_connected(_on_transaction):
		Global.followers_transaction.connect(_on_transaction)


func _process(delta: float) -> void:
	if _aggregate_left > 0.0:
		_aggregate_left = maxf(0.0, _aggregate_left - delta)
		if _aggregate_left <= 0.0 and _pending_gain > 0:
			_show(_format_feed("Witnesses rally as the containment line breaks.", _pending_gain))
			_pending_gain = 0
	if _visible_left > 0.0:
		_visible_left = maxf(0.0, _visible_left - delta)
		if _visible_left <= 0.0 and _panel != null:
			_panel.visible = false


func _on_transaction(
	_old: int,
	change: int,
	_new: int,
	reason: StringName,
	_context: Dictionary,
	show_feedback: bool,
	allow_aggregate: bool
) -> void:
	if not show_feedback or change == 0:
		return
	if change > 0 and allow_aggregate and (reason == &"combat_influence" or reason == &"legacy"):
		_pending_gain += change
		_aggregate_left = 0.9
		return
	var text := ""
	match reason:
		&"trade":
			text = "Supplies and contacts secure the exchange." if change < 0 else "The exchange strengthens the movement."
		&"vendor_refresh":
			text = "Supporters search the city's remaining exchange routes."
		&"enemy_drain":
			text = "The institution disrupts the Pattern."
		&"boss_victory", &"miniboss_victory":
			text = "The institution's account is losing credibility."
		&"assistant_commitment":
			text = "The assistant commits to preserve the Pattern."
		_:
			text = "The movement grows." if change > 0 else "Support is committed elsewhere."
	_show(_format_feed(text, change))


func _format_feed(body: String, change: int) -> Dictionary:
	var delta_text := "%+d" % change
	return {
		"seal": delta_text,
		"value": "%s %s" % [delta_text, "FOLLOWER" if absi(change) == 1 else "FOLLOWERS"],
		"body": body,
	}


func _show(feed: Dictionary) -> void:
	if _panel == null:
		return
	_seal.text = String(feed.get("seal", ""))
	_value.text = String(feed.get("value", ""))
	_body.text = String(feed.get("body", ""))
	_panel.visible = true
	_visible_left = 3.6


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "FollowerFeedback"
	_panel.anchor_left = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -456.0
	_panel.offset_top = -158.0
	_panel.offset_right = -18.0
	_panel.offset_bottom = -62.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.theme = SHARED_THEME
	_panel.theme_type_variation = &"WitnessNotice"
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	_seal = Label.new()
	_seal.name = "Seal"
	_seal.custom_minimum_size = Vector2(58, 58)
	_seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_seal.theme_type_variation = &"BodyStrong"
	_seal.add_theme_font_size_override("font_size", 17)
	_seal.add_theme_color_override("font_color", Color(1.0, 0.64, 0.30, 1.0))
	var seal_style := StyleBoxFlat.new()
	seal_style.bg_color = Color(0.12, 0.075, 0.04, 0.72)
	seal_style.border_color = Color(0.72, 0.42, 0.19, 0.82)
	seal_style.set_border_width_all(1)
	seal_style.corner_radius_top_left = 0
	seal_style.corner_radius_top_right = 0
	seal_style.corner_radius_bottom_right = 0
	seal_style.corner_radius_bottom_left = 0
	_seal.add_theme_stylebox_override("normal", seal_style)
	row.add_child(_seal)

	var copy := VBoxContainer.new()
	copy.name = "Copy"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)

	var eyebrow := Label.new()
	eyebrow.name = "Eyebrow"
	eyebrow.text = "WITNESS ACCOUNT // PATTERN FEED"
	eyebrow.theme_type_variation = &"InstitutionalHeading"
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", Color(0.82, 0.50, 0.24, 1.0))
	copy.add_child(eyebrow)

	_value = Label.new()
	_value.name = "Value"
	_value.theme_type_variation = &"BodyStrong"
	_value.add_theme_font_size_override("font_size", 15)
	_value.add_theme_color_override("font_color", Color(0.95, 0.91, 0.84, 1.0))
	copy.add_child(_value)

	_body = Label.new()
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 12)
	_body.add_theme_color_override("font_color", Color(0.76, 0.74, 0.70, 1.0))
	copy.add_child(_body)

	_panel.visible = false
