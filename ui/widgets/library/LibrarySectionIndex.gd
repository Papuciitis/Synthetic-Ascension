extends Control
## Cloth sewn into the current volume. Browsing the fan never changes the account.
signal account_requested(key: String)

const Kit := preload("res://ui/widgets/chambers/ChamberKit.gd")
const FONT := preload("res://assets/fonts/eb_garamond/EBGaramond-Variable.ttf")
const CLOTH := preload("res://assets/ui/library/bookmark_cloth_pixel.png")
const MAX_TABS := 7
const MIN_TAB_HEIGHT := 54.0
const TWO_LINE_ROW_HEIGHT := 68.0
const NAV_HEIGHT := 44.0
const SHORT_GUIDES := {
	"guide:equipment_identity": "Equipment",
	"guide:nouns_and_pairs": "Pairs",
	"guide:merges_and_imprints": "Imprints",
	"guide:augment_growth": "Augments",
	"guide:doctrine_families": "Doctrines",
}

class SectionTail extends Button:
	var index_owner: Control
	var slot := 0
	var active := false
	var root_texture: Texture2D
	var middle_texture: Texture2D
	var tip_texture: Texture2D
	var _pull := 0.0:
		set(value):
			_pull = value
			if is_instance_valid(caption):
				caption.position.x = 31.0 + _pull
			queue_redraw()
	var _pull_tween: Tween
	var caption: Label

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_meta("ui_sound_manual", true)
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		caption = Label.new()
		caption.name = "Caption"
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.max_lines_visible = 2
		caption.clip_text = true
		caption.add_theme_color_override("font_color", Color(1.0, 0.92, 0.73))
		caption.add_theme_color_override("font_shadow_color", Color(0.12, 0.045, 0.02, 0.8))
		caption.add_theme_constant_override("shadow_offset_y", 1)
		# Garamond's generous font box otherwise puts two lines over the braid.
		# A 22 px face retains a 22 px baseline step and a 52 px two-line box.
		caption.add_theme_constant_override("line_spacing", -8)
		add_child(caption)
		pressed.connect(func() -> void: index_owner._request_slot(slot))
		button_down.connect(func() -> void: _animate_pull(5.0, 0.09))
		button_up.connect(func() -> void: _animate_pull(0.0, 0.18))
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _process(_delta: float) -> void:
		if (disabled or not is_visible_in_tree() or Kit.reduced()) and (_pull > 0.0 or _pull_tween != null):
			if is_instance_valid(_pull_tween):
				_pull_tween.kill()
			_pull_tween = null
			_pull = 0.0

	func _animate_pull(amount: float, duration: float) -> void:
		if is_instance_valid(_pull_tween):
			_pull_tween.kill()
		if disabled or Kit.reduced():
			_pull_tween = null
			_pull = 0.0
			return
		_pull_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
		_pull_tween.tween_property(self, "_pull", amount, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	func cloth_geometry() -> Dictionary:
		var extension := 8.0 if active else 0.0
		if not disabled and not Kit.reduced() and (is_hovered() or has_focus()):
			extension += 2.0
		return {"root": Rect2(-28.0, 0.0, 36.0, size.y), "tail": Rect2(0.0, 0.0, size.x - 14.0 + extension + _pull, size.y)}

	func _draw_horizontal(texture: Texture2D, rectangle: Rect2, tint: Color) -> void:
		# The original vertical cloth's downward tip points out of the fore-edge.
		draw_set_transform(Vector2(rectangle.position.x, rectangle.end.y), -PI * 0.5)
		draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2(rectangle.size.y, rectangle.size.x)), false, tint)
		draw_set_transform(Vector2.ZERO)

	func _draw() -> void:
		if middle_texture == null or tip_texture == null:
			return
		var shape := cloth_geometry()
		var tail: Rect2 = shape.tail
		var tint := Color.WHITE.lightened(0.1) if active else Color(0.91, 0.87, 0.83)
		if not disabled and (is_hovered() or has_focus()):
			tint = Color.WHITE
		var tip_width := size.y * 0.625
		_draw_horizontal(middle_texture, Rect2(0.0, 0.0, tail.size.x - tip_width, size.y), tint)
		_draw_horizontal(tip_texture, Rect2(tail.end.x - tip_width, 0.0, tip_width, size.y), tint)
		_draw_horizontal(root_texture, shape.root, tint)
		if has_focus() and not disabled:
			draw_line(Vector2(31.0, size.y - 8.0), Vector2(tail.end.x - tip_width - 5.0, size.y - 8.0), Color(1.0, 0.9, 0.62), 1.0)

	func _gui_input(event: InputEvent) -> void:
		if disabled:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			index_owner._gui_input(event)
			accept_event()
		elif event.is_action_pressed(&"ui_down"):
			index_owner._focus_account(index_owner._window_start + slot + 1)
			accept_event()
		elif event.is_action_pressed(&"ui_up"):
			index_owner._focus_account(index_owner._window_start + slot - 1)
			accept_event()

var _entries: Array[Dictionary] = []
var _selected_key := ""
var _window_start := 0
var _capacity := 3
var _reading_enabled := false
var _open_progress := 1.0
var _tails: Array[SectionTail] = []
var _earlier: Button
var _later: Button
var _font: FontVariation
var _unmapped_accept_held := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_meta("ui_sound_manual", true)
	_font = FontVariation.new()
	_font.base_font = FONT
	_font.variation_opentype = {"wght": 580.0}
	var root := _atlas(Rect2(194, 101, 405, 183))
	var middle := _atlas(Rect2(194, 1330, 405, 300))
	var tip := _atlas(Rect2(194, 1630, 405, 253))
	for slot: int in MAX_TABS:
		var tail := SectionTail.new()
		tail.name = "Tail%d" % slot
		tail.index_owner = self
		tail.slot = slot
		tail.root_texture = root
		tail.middle_texture = middle
		tail.tip_texture = tip
		add_child(tail)
		tail.caption.add_theme_font_override("font", _font)
		tail.caption.add_theme_font_size_override("font_size", 22)
		_tails.append(tail)
	_earlier = _make_navigation("EarlierSections", "↑ Earlier sections", -1)
	_later = _make_navigation("LaterSections", "Later sections ↓", 1)
	resized.connect(_relayout)
	_relayout()

func _atlas(rectangle: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = CLOTH
	atlas.region = rectangle
	atlas.filter_clip = true
	return atlas

func _make_navigation(node_name: String, caption: String, direction: int) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("ui_sound_manual", true)
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 22)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Kit.PARCHMENT)
	button.add_theme_color_override("font_hover_color", Kit.GOLD_BRIGHT)
	button.add_theme_color_override("font_focus_color", Kit.GOLD_BRIGHT)
	button.add_theme_color_override("font_disabled_color", Kit.MUTED)
	button.pressed.connect(func() -> void: _scroll_window(direction, true, maxi(1, _capacity - 1)))
	add_child(button)
	return button

func set_entries(entries: Array[Dictionary], selected_key: String) -> void:
	var changed := selected_key != _selected_key or _entries.is_empty()
	_entries.clear()
	for entry: Dictionary in entries:
		var known := bool(entry.get("discovered", false))
		var key := String(entry.get("key", ""))
		if key.is_empty():
			continue
		var ordinal := int(entry.get("folio", _entries.size() + 1))
		var title := _clean_text(String(entry.get("title", ""))) if known else "Sealed · %02d" % ordinal
		var ink := String(SHORT_GUIDES.get(key, title)) if known else title
		var tooltip := title if known else "Sealed account · %02d\n%s" % [ordinal, _clean_text(String(entry.get("hint", "Seek this account in play.")))]
		_entries.append({"key": key, "label": ink, "tooltip": tooltip})
	_selected_key = selected_key
	_relayout(changed)

func _clean_text(value: String) -> String:
	return " ".join(value.replace("\n", " ").replace("\r", " ").replace("\t", " ").split(" ", false)).strip_edges()

func select_key(key: String, reveal: bool = true) -> void:
	var changed := key != _selected_key
	_selected_key = key
	if reveal and changed:
		_reveal_key(key)
	_refresh()

func visible_entries() -> Array[Dictionary]:
	var visible_rows: Array[Dictionary] = []
	for index: int in range(_window_start, mini(_window_start + _capacity, _entries.size())):
		var row: Dictionary = _entries[index].duplicate()
		row["selected"] = row.key == _selected_key
		visible_rows.append(row)
	return visible_rows

func set_reading_enabled(enabled: bool) -> void:
	_reading_enabled = enabled
	_update_enabled()

func set_book_open_progress(progress: float, _book_width: float) -> void:
	# Right-side markers stay sewn to this fixed fore-edge throughout the hinge.
	_open_progress = clampf(progress, 0.0, 1.0)
	_update_enabled()

func _relayout(reveal: bool = true) -> void:
	if _earlier == null:
		return
	var row_minimum := MIN_TAB_HEIGHT
	for entry: Dictionary in _entries:
		if not String(entry.key).begins_with("guide:"):
			row_minimum = TWO_LINE_ROW_HEIGHT
			break
	var needs_navigation := _entries.size() > mini(MAX_TABS, maxi(3, floori(size.y / row_minimum)))
	var nav_space := NAV_HEIGHT * 2.0 if needs_navigation else 0.0
	_capacity = clampi(floori((size.y - nav_space) / row_minimum), 3, MAX_TABS)
	if _entries.size() > _capacity and not needs_navigation:
		needs_navigation = true
		nav_space = NAV_HEIGHT * 2.0
		_capacity = clampi(floori((size.y - nav_space) / row_minimum), 3, MAX_TABS)
	_window_start = clampi(_window_start, 0, maxi(0, _entries.size() - _capacity))
	if reveal:
		_reveal_key(_selected_key)
	var row_count := mini(_capacity, _entries.size())
	var height := clampf((size.y - nav_space) / maxf(1.0, row_count), row_minimum, TWO_LINE_ROW_HEIGHT)
	var top := NAV_HEIGHT if needs_navigation else maxf(0.0, (size.y - height * row_count) * 0.5)
	for slot: int in _tails.size():
		var tail := _tails[slot]
		tail.position = Vector2(0.0, top + slot * height)
		tail.size = Vector2(size.x, height - 2.0 if height >= 56.0 else height)
		tail.caption.position = Vector2(31.0 + tail._pull, 6.0)
		tail.caption.size = Vector2(maxf(1.0, size.x - 31.0 - 14.0 - height * 0.625 - 7.0), tail.size.y - 12.0)
	_earlier.position = Vector2(31.0, 0.0)
	_earlier.size = Vector2(maxf(1.0, size.x - 31.0), NAV_HEIGHT)
	_later.position = Vector2(31.0, size.y - NAV_HEIGHT)
	_later.size = Vector2(maxf(1.0, size.x - 31.0), NAV_HEIGHT)
	_earlier.visible = needs_navigation
	_later.visible = needs_navigation
	_refresh()

func _refresh() -> void:
	if _earlier == null:
		return
	for slot: int in _tails.size():
		var tail := _tails[slot]
		var ordinal := _window_start + slot
		tail.visible = slot < _capacity and ordinal < _entries.size()
		if not tail.visible:
			continue
		var entry: Dictionary = _entries[ordinal]
		tail.active = entry.key == _selected_key
		tail.tooltip_text = entry.tooltip
		tail.set_meta("account_key", entry.key)
		tail.caption.text = _wrap_caption(entry.label, tail.caption.size.x)
		tail.queue_redraw()
	_update_enabled()

func _wrap_caption(value: String, width: float) -> String:
	var lines := PackedStringArray()
	var line := ""
	for word: String in value.split(" ", false):
		var candidate := word if line.is_empty() else line + " " + word
		if _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x <= width:
			line = candidate
		else:
			if not line.is_empty():
				lines.append(line)
			line = word
	if not line.is_empty():
		lines.append(line)
	if lines.is_empty():
		return ""
	if lines.size() > 2:
		lines.resize(2)
		lines[1] = _ellipsize(lines[1], width, true)
	for index: int in lines.size():
		if _font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > width:
			lines[index] = _ellipsize(lines[index], width, true)
	return "\n".join(lines)

func _ellipsize(value: String, width: float, ellipsis: bool) -> String:
	var result := value
	var suffix := "…" if ellipsis else ""
	while not result.is_empty() and _font.get_string_size(result + suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > width:
		var break_at := result.rfind(" ")
		result = result.substr(0, break_at) if break_at > 0 else result.left(-1)
	return result + suffix

func _reveal_key(key: String) -> void:
	for index: int in _entries.size():
		if _entries[index].key != key:
			continue
		if index < _window_start:
			_window_start = index
		elif index >= _window_start + _capacity:
			_window_start = index - _capacity + 1
		break
	_window_start = clampi(_window_start, 0, maxi(0, _entries.size() - _capacity))

func _update_enabled() -> void:
	if _earlier == null:
		return
	var enabled := _reading_enabled and _open_progress >= 0.999
	for tail: SectionTail in _tails:
		tail.disabled = not enabled
	_earlier.disabled = not enabled or _window_start == 0
	_later.disabled = not enabled or _window_start + _capacity >= _entries.size()

func _request_slot(slot: int) -> void:
	if not _reading_enabled or _open_progress < 0.999:
		return
	var index := _window_start + slot
	if index >= 0 and index < _entries.size():
		account_requested.emit(String(_entries[index].key))

func _scroll_window(direction: int, audible: bool, step: int = 1) -> void:
	if not _reading_enabled or _open_progress < 0.999:
		return
	var next := clampi(_window_start + signi(direction) * maxi(1, step), 0, maxi(0, _entries.size() - _capacity))
	if next == _window_start:
		return
	_window_start = next
	_refresh()
	if audible:
		SfxManager.play_ui(&"library_bookmark")

func _focus_account(index: int) -> void:
	if index < 0 or index >= _entries.size() or not _reading_enabled or _open_progress < 0.999:
		return
	var previous_window := _window_start
	_reveal_key(String(_entries[index].key))
	_refresh()
	_tails[index - _window_start].grab_focus()
	if previous_window != _window_start:
		SfxManager.play_ui(&"library_bookmark")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_window(-1, true)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_window(1, true)
			accept_event()

func _input(event: InputEvent) -> void:
	# The game's ui_accept map is keyboard-only. Keep this local to a focused
	# ribbon, while preserving native Button handling for player-mapped A.
	if not event is InputEventJoypadButton or event.button_index != JOY_BUTTON_A or event.is_action(&"ui_accept"):
		return
	var focused := get_viewport().gui_get_focus_owner() as Button
	var owns_focus := focused != null and is_ancestor_of(focused) and focused.is_visible_in_tree() and not focused.disabled
	if not owns_focus and not _unmapped_accept_held:
		return
	get_viewport().set_input_as_handled()
	if event.pressed:
		if not _unmapped_accept_held and owns_focus:
			_unmapped_accept_held = true
			focused.pressed.emit()
	else:
		_unmapped_accept_held = false
