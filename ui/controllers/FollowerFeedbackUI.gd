extends CanvasLayer

## Cross-scene follower feedback. Small combat gains are coalesced; meaningful
## commitments, drains and victories are explained immediately.

var _panel: PanelContainer
var _label: Label
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

func _on_transaction(_old: int, change: int, _new: int, reason: StringName, _context: Dictionary, show_feedback: bool, allow_aggregate: bool) -> void:
	if not show_feedback or change == 0:
		return
	if change > 0 and allow_aggregate and (reason == &"combat_influence" or reason == &"legacy"):
		_pending_gain += change
		_aggregate_left = 0.9
		return
	var text := ""
	match reason:
		&"trade":
			text = _format_feed("Supplies and contacts secure the exchange." if change < 0 else "The exchange strengthens the movement.", change)
		&"vendor_refresh":
			text = _format_feed("Supporters search the city's remaining exchange routes.", change)
		&"enemy_drain":
			text = _format_feed("The institution disrupts the Pattern.", change)
		&"boss_victory", &"miniboss_victory":
			text = _format_feed("The institution's account is losing credibility.", change)
		&"assistant_commitment":
			text = _format_feed("The assistant commits to preserve the Pattern.", change)
		_:
			text = _format_feed("The movement grows." if change > 0 else "Support is committed elsewhere.", change)
	_show(text)

func _format_feed(headline: String, change: int) -> String:
	var delta_text: String = "%+d" % change
	var noun: String = "FOLLOWER" if absi(change) == 1 else "FOLLOWERS"
	return "PATTERN FEED  •  %s %s\n%s" % [delta_text, noun, headline]

func _show(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	_panel.visible = true
	_visible_left = 3.6

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "FollowerFeedback"
	_panel.anchor_left = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -490.0
	_panel.offset_top = -126.0
	_panel.offset_right = -8.0
	_panel.offset_bottom = -62.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.028, 0.035, 0.92)
	style.border_color = Color(1.0, 0.55, 0.2, 0.78)
	style.set_border_width_all(1)
	style.border_width_left = 5
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 14)
	margin.add_child(_label)
	_panel.visible = false
