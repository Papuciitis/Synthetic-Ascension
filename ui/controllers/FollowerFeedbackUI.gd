extends CanvasLayer

## Cross-scene follower feedback. Small combat gains are coalesced; meaningful
## commitments, drains and victories are explained immediately.
##
## Presentation (the front end's register): the HUD's witness surface with a
## seal of the signed change, a Cinzel caption and value and a Garamond line.
## In combat it rests bottom-right. While a full-screen panel is open (the
## Exchange, the Ascension tree, Gear & Stash, the library...) that corner is
## the panel's footer, so the notice lifts into the band above the panel's
## frame, where none of its controls live. It eases in and fades out on real
## time, so hit-stop and the augment pick's stopped clock never strand it.

const SHARED_THEME := preload("res://ui/theme/SyntheticHudTheme.tres")
const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")

const HOLD_SECONDS := 3.6
const ARRIVE_SECONDS := 0.24
const FADE_SECONDS := 0.32
const ARRIVE_DISTANCE := 10.0
## The resting corner in combat: 438 x 96 above the bottom-right margin.
const COMBAT_RECT := Rect2(-456.0, -158.0, 438.0, 96.0)
## The lifted notice, in the band above a full-screen panel's frame.
const LIFTED_WIDTH := 410.0
const LIFTED_TOP := 10.0
const CENTRED := -1.0
const NOT_LIFTED := -2.0
## Screens that cover the view with controls of their own, by script file:
## how far from the canvas's right edge the lifted notice ends (or CENTRED)
## and its top. Over the Exchange it sits left of the follower count; over the
## Ascension tree it covers the side panel's title plate for its moment, so
## the pannable canvas and the follower figures stay clear.
const COVERING_SCREENS := {
	"HubShop.gd": Vector2(262.0, LIFTED_TOP),
	"AscensionScreen.gd": Vector2(41.0, 29.0),
	"InventoryStash.gd": Vector2(CENTRED, LIFTED_TOP),
	"AugmentLibrary.gd": Vector2(CENTRED, LIFTED_TOP),
	"MajorChoice.gd": Vector2(CENTRED, LIFTED_TOP),
	"GameOverUI.gd": Vector2(CENTRED, LIFTED_TOP),
	"AugmentSelect.gd": Vector2(CENTRED, LIFTED_TOP),
}
const IN_COMBAT := Vector2(NOT_LIFTED, 0.0)
## How often a visible notice re-checks for a panel opening or closing.
const PLACEMENT_RECHECK := 0.3

var _panel: PanelContainer
var _seal: Label
var _value: Label
var _body: Label
var _pending_gain: int = 0
var _aggregate_left: float = 0.0
var _visible_left: float = 0.0
var _shown_for: float = 0.0
## Where the notice was last placed; nothing yet, so the first placement applies.
var _placement := Vector2(-1000.0, 0.0)
var _recheck_left: float = 0.0
var _seal_loss: bool = false
var _alpha: float = -1.0


func _ready() -> void:
	layer = 180
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if Global != null and not Global.followers_transaction.is_connected(_on_transaction):
		Global.followers_transaction.connect(_on_transaction)


func _process(delta: float) -> void:
	var step := OverlayKit.real_delta(delta)
	if _aggregate_left > 0.0:
		_aggregate_left = maxf(0.0, _aggregate_left - step)
		if _aggregate_left <= 0.0 and _pending_gain > 0:
			_show(_format_feed("Witnesses rally as the containment line breaks.", _pending_gain))
			_pending_gain = 0
	if _visible_left > 0.0:
		_visible_left = maxf(0.0, _visible_left - step)
		_shown_for += step
		if _visible_left <= 0.0 and _panel != null:
			_panel.visible = false
			offset = Vector2.ZERO
			return
		_recheck_left -= step
		if _recheck_left <= 0.0:
			_recheck_left = PLACEMENT_RECHECK
			_apply_placement(_covering_placement())
		_animate()


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
	var seal_text := String(feed.get("seal", ""))
	_seal.text = seal_text
	_value.text = String(feed.get("value", ""))
	_body.text = String(feed.get("body", ""))
	_apply_seal(seal_text.begins_with("-"))
	_apply_placement(_covering_placement())
	_recheck_left = PLACEMENT_RECHECK
	if not _panel.visible:
		# A fresh arrival; a notice already up just takes the new words.
		_shown_for = 0.0
		_alpha = -1.0
	_panel.visible = true
	_visible_left = HOLD_SECONDS
	_animate()


## The seal reads its sign: gold for support gained, ember for support spent.
func _apply_seal(loss: bool) -> void:
	if loss == _seal_loss:
		return
	_seal_loss = loss
	_seal.add_theme_stylebox_override(&"normal", OverlayKit.shared(&"seal_loss" if loss else &"seal"))
	_seal.add_theme_color_override(&"font_color", OverlayKit.CURSE if loss else OverlayKit.GOLD_BRIGHT)


## Arrival (a fade and a short travel toward its corner) and the closing fade,
## both on the notice's own clock. Writes only while either is running.
func _animate() -> void:
	var alpha := 1.0
	var travel := 0.0
	if _shown_for < ARRIVE_SECONDS:
		var t := clampf(_shown_for / ARRIVE_SECONDS, 0.0, 1.0)
		alpha = t
		if not OverlayKit.reduced():
			travel = pow(1.0 - t, 3.0) * ARRIVE_DISTANCE
	elif _visible_left < FADE_SECONDS:
		alpha = clampf(_visible_left / FADE_SECONDS, 0.0, 1.0)
	if is_equal_approx(alpha, _alpha) and travel == 0.0 and offset == Vector2.ZERO:
		return
	_alpha = alpha
	_panel.modulate.a = alpha
	# In combat it rises into its corner; lifted, it drops into the band.
	offset = Vector2(0.0, travel if _placement == IN_COMBAT else -travel)


## IN_COMBAT, or the lifted placement (right inset or CENTRED, top) for the
## top-most covering screen that is showing.
func _covering_placement() -> Vector2:
	var tree := get_tree()
	if tree == null:
		return IN_COMBAT
	# In a run every covering screen pauses the tree, so an unpaused run has
	# none to find; skip the walk, which costs about 1 ms over a busy district.
	if not tree.paused and tree.current_scene != null and Global != null \
			and tree.current_scene.scene_file_path == Global.PATH_GAME:
		return IN_COMBAT
	var found := IN_COMBAT
	var found_layer := -100000
	var stack: Array = []
	for child in tree.root.get_children():
		if child != self:
			stack.append([child, 1])
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var depth: int = entry[1]
		var node_script := node.get_script() as Script
		if node_script != null:
			var file := node_script.resource_path.get_file()
			if COVERING_SCREENS.has(file) and _is_showing(node):
				var on_layer := _layer_of(node)
				if on_layer > found_layer:
					found_layer = on_layer
					found = COVERING_SCREENS[file] as Vector2
		if depth >= 4:
			continue
		# Screens hang off the root, the current scene and their UI layers;
		# the world's own Node2D trees are never searched.
		if node is Node2D and node != tree.current_scene:
			continue
		if node is CanvasLayer or node is Control or node == tree.current_scene or depth == 1:
			for child in node.get_children():
				stack.append([child, depth + 1])
	return found


func _is_showing(node: Node) -> bool:
	if node is CanvasLayer:
		return (node as CanvasLayer).visible
	if node is CanvasItem:
		return (node as CanvasItem).is_visible_in_tree()
	return true


func _layer_of(node: Node) -> int:
	var cursor: Node = node
	while cursor != null:
		if cursor is CanvasLayer:
			return (cursor as CanvasLayer).layer
		cursor = cursor.get_parent()
	return 0


func _apply_placement(placement: Vector2) -> void:
	if _panel == null or placement.is_equal_approx(_placement):
		return
	_placement = placement
	var inset := placement.x
	if placement == IN_COMBAT:
		_panel.anchor_left = 1.0
		_panel.anchor_right = 1.0
		_panel.anchor_top = 1.0
		_panel.anchor_bottom = 1.0
		_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_panel.offset_left = COMBAT_RECT.position.x
		_panel.offset_right = COMBAT_RECT.end.x
		_panel.offset_top = COMBAT_RECT.position.y
		_panel.offset_bottom = COMBAT_RECT.end.y
		return
	var anchor := 0.5 if inset == CENTRED else 1.0
	var right := LIFTED_WIDTH * 0.5 if inset == CENTRED else -inset
	_panel.anchor_left = anchor
	_panel.anchor_right = anchor
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.offset_left = right - LIFTED_WIDTH
	_panel.offset_right = right
	_panel.offset_top = placement.y
	_panel.offset_bottom = placement.y + 80.0


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "FollowerFeedback"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.theme = SHARED_THEME
	_panel.theme_type_variation = &"WitnessNotice"
	add_child(_panel)
	_apply_placement(IN_COMBAT)
	_panel.draw.connect(func() -> void:
		OverlayKit.draw_corner_marks(_panel, Rect2(Vector2(1, 1), _panel.size - Vector2(2, 2)), Color(OverlayKit.GOLD_DIM, 0.95), 3.0))

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	_seal = Label.new()
	_seal.name = "Seal"
	_seal.custom_minimum_size = Vector2(64, 58)
	_seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_seal.theme_type_variation = &"BodyStrong"
	OverlayKit.style_label(_seal, &"figure", 18, OverlayKit.GOLD_BRIGHT)
	_seal.add_theme_stylebox_override(&"normal", OverlayKit.shared(&"seal"))
	row.add_child(_seal)

	var copy := VBoxContainer.new()
	copy.name = "Copy"
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)

	var eyebrow := Label.new()
	eyebrow.name = "Eyebrow"
	eyebrow.text = "WITNESS ACCOUNT // PATTERN FEED"
	eyebrow.theme_type_variation = &"InstitutionalHeading"
	OverlayKit.style_label(eyebrow, &"caption", 11, Color(0.86, 0.6, 0.34))
	copy.add_child(eyebrow)

	_value = Label.new()
	_value.name = "Value"
	_value.theme_type_variation = &"BodyStrong"
	OverlayKit.style_label(_value, &"heading", 16, OverlayKit.PARCHMENT)
	copy.add_child(_value)

	_body = Label.new()
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	OverlayKit.style_label(_body, &"italic", 16, OverlayKit.BODY)
	copy.add_child(_body)

	_panel.visible = false
