extends CanvasLayer
class_name OpeningPresentation
## The opening's story cards in the front end's register. Five voices keep
## their own look: the HISTORICAL account floats unboxed in Cinzel Decorative
## and Garamond italic; DIALOGUE is a warm card in a gold double rule;
## the INSTITUTIONAL announcement is ruled in danger red; the SYNTHETIC
## response keeps a cold teal on its rule and caption only; the FOLLOWER's
## commitment glows gold. Text types out at the accessibility speed on real
## time (the opening slows Engine.time_scale under some cards), choices are
## ledger rows, and each card eases up into place (only fades under Reduced
## Motion).

signal advanced
signal choice_selected(index: int)

enum Style { HISTORICAL, DIALOGUE, INSTITUTIONAL, SYNTHETIC, FOLLOWER }

const Accessibility := preload("res://core/settings/AccessibilityPresentation.gd")
const CARD_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")
const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const ArcaneRuleScript := preload("res://ui/components/ArcaneRule.gd")
const STILL_SHADER := preload("res://ui/screens/opening/opening_still.gdshader")
## Seconds a still takes to paint in over the world, to paint over the still
## before it, and to wash away again. Reduced Motion makes each immediate.
const STILL_REVEAL := 0.75
const STILL_CROSSFADE := 0.95
const STILL_CLEAR := 0.55
## While it is read, each still drifts slowly in toward its focal point.
const STILL_DRIFT_SECONDS := 20.0
const STILL_DRIFT_SCALE := 1.04
## Where each painting's eye goes (normalised); unknown stills use the centre.
const STILL_FOCUS := {
	&"city": Vector2(0.42, 0.42),
	&"admission": Vector2(0.36, 0.33),
	&"synthesis": Vector2(0.52, 0.56),
	&"records": Vector2(0.45, 0.42),
}

const PANEL_WIDTH := 800.0
## The card's top edge, below the centre so the scene above stays readable;
## a taller card rises so its foot stays on screen. The unboxed historical
## account sits higher, nearer the middle of its darker shade.
const PANEL_TOP := 650.0
const HISTORICAL_TOP := 300.0
const BOTTOM_MARGIN := 30.0

static var _looks: Dictionary = {}

var _shade: ColorRect
var _illustration: TextureRect
## The previous still, held exactly as it was while the next paints over it.
var _illustration_back: TextureRect
var _illustration_drift: Tween
## The stroke pattern, shared by every presentation and made the first time a
## still is shown (a hub letter card, which shows none, never pays for it).
static var _shared_strokes: Texture2D
var _illustration_id: StringName = &""
var _illustration_crop := Rect2()
var _illustration_version := 0
var _illustration_tween: Tween
var _stage: Control
var _panel: PanelContainer
var _scroll: ScrollContainer
var _column: VBoxContainer
var _frame: Control
var _eyebrow: Label
var _title: Label
var _rule: Control
var _body: Label
var _choices: VBoxContainer
var _continue_button: Button
var _prompt: Label
var _waiting: bool = false
var _revealing := false
var _reveal_progress := 0.0
var _has_choices := false
var _style := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 220
	_build_ui()
	hide_card()
	_shade.visible = false
	if SettingsManager != null:
		SettingsManager.settings_changed.connect(_on_settings_changed)


## Reduced Motion turned on while a still is read: its push-in stops where
## it is.
func _on_settings_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"accessibility" and key == &"reduced_motion" and bool(value):
		_stop_drift()


func _process(delta: float) -> void:
	if not _revealing or _pause_owns_input():
		return
	var characters_per_second := Accessibility.current_typewriter_characters_per_second()
	if is_inf(characters_per_second):
		_complete_reveal()
		return
	_reveal_progress += OverlayKit.real_delta(delta) * characters_per_second
	var total := _body.get_total_character_count()
	_body.visible_characters = mini(total, int(_reveal_progress))
	if _body.visible_characters >= total:
		_complete_reveal()


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting or not _panel.visible or event.is_echo() or _pause_owns_input():
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		if _revealing or not _has_choices:
			advance()
			get_viewport().set_input_as_handled()


## Optional art belongs to a card group, not a saved phase or a gameplay lock.
## Crop is a normalised source region; AtlasTexture avoids copying pixels.
func show_illustration(id: StringName, crop: Rect2 = Rect2()) -> bool:
	_illustration_version += 1
	if _illustration_tween != null:
		_illustration_tween.kill()
	if id == _illustration_id and crop == _illustration_crop and _illustration.texture != null:
		# The same still again (a pending clear superseded): finish painting it.
		_illustration.visible = true
		_illustration.modulate.a = 1.0
		var shown := _reveal_of(_illustration)
		_paint_front(shown, STILL_REVEAL * (1.0 - shown))
		return true
	var path := String(OpeningSequenceData.ILLUSTRATIONS.get(id, ""))
	var texture: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		texture = load(path) as Texture2D
	elif not path.is_empty() and FileAccess.file_exists(path):
		# Source fallback also supports a fresh checkout before PNG import.
		var source := Image.load_from_file(path)
		if source != null and not source.is_empty():
			texture = ImageTexture.create_from_image(source)
	if texture == null:
		_release_illustration()
		return false
	if crop.has_area():
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(crop.position * texture.get_size(), crop.size * texture.get_size())
		texture = atlas
	_ensure_strokes()
	# A still already showing stays underneath, exactly as it was, while the
	# new one paints over it: a true crossfade, never a dip back to the world.
	# Mid-crossfade, the more painted of the two is the one kept underneath.
	var front_shown := _reveal_of(_illustration) if _illustration.visible and _illustration.texture != null else 0.0
	var back_shown := _reveal_of(_illustration_back) if _illustration_back.visible and _illustration_back.texture != null else 0.0
	var over_still := front_shown > 0.0 or back_shown > 0.0
	if front_shown >= back_shown:
		_drop_back_layer()
		if front_shown > 0.0:
			_illustration_back.texture = _illustration.texture
			_illustration_back.scale = _illustration.scale
			_illustration_back.set_meta(&"focus", _illustration.get_meta(&"focus", Vector2(0.5, 0.5)))
			_fit_still_layer(_illustration_back)
			_set_reveal(front_shown, _illustration_back)
			_illustration_back.visible = true
	_illustration_id = id
	_illustration_crop = crop
	_illustration.texture = texture
	_illustration.visible = true
	_illustration.modulate.a = 1.0
	_set_reveal(0.0, _illustration)
	_start_drift(id)
	_paint_front(0.0, STILL_CROSSFADE if over_still else STILL_REVEAL)
	_update_shade()
	return true


func clear_illustration(duration: float = STILL_CLEAR) -> void:
	_illustration_version += 1
	var version := _illustration_version
	if _illustration_tween != null:
		_illustration_tween.kill()
	if _illustration.texture != null and duration > 0.0:
		var hold := Accessibility.current_motion_duration(duration)
		# The painting washes back out the way it came, from where it stands;
		# a still still under a crossfade leaves with it.
		_illustration_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
		_illustration_tween.tween_method(_set_reveal.bind(_illustration), _reveal_of(_illustration), 0.0, hold).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if _illustration_back.visible:
			_illustration_tween.tween_method(_set_reveal.bind(_illustration_back), _reveal_of(_illustration_back), 0.0, hold).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# A cancelled tween never emits finished. A bounded timer lets an old
		# clear return harmlessly even if a new illustration supersedes it.
		await get_tree().create_timer(hold, true, false, true).timeout
	if version == _illustration_version:
		_release_illustration()


func _release_illustration() -> void:
	_stop_drift()
	_drop_back_layer()
	_illustration.texture = null
	_illustration.visible = false
	_illustration.scale = Vector2.ONE
	_set_reveal(1.0, _illustration)
	_illustration_id = &""
	_illustration_crop = Rect2()
	_update_shade()


## How much of a still layer is painted in: 0 none, 1 the plain painting.
func _reveal_of(layer: TextureRect) -> float:
	return float((layer.material as ShaderMaterial).get_shader_parameter(&"reveal"))


func _set_reveal(value: float, layer: TextureRect = null) -> void:
	var target := layer if layer != null else _illustration
	(target.material as ShaderMaterial).set_shader_parameter(&"reveal", clampf(value, 0.0, 1.0))


func _paint_front(from: float, seconds: float) -> void:
	_illustration_tween = create_tween().set_ignore_time_scale(true)
	_illustration_tween.tween_method(_set_reveal, from, 1.0, Accessibility.current_motion_duration(maxf(seconds, 0.0))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Once the new still covers it, the one beneath is let go.
	_illustration_tween.tween_callback(_drop_back_layer)


func _drop_back_layer() -> void:
	_illustration_back.texture = null
	_illustration_back.visible = false
	_illustration_back.scale = Vector2.ONE
	_set_reveal(1.0, _illustration_back)


## A slow push-in toward the still's focal point while it is read; none
## under Reduced Motion.
func _start_drift(id: StringName) -> void:
	_stop_drift()
	_illustration.scale = Vector2.ONE
	_illustration.set_meta(&"focus", STILL_FOCUS.get(id, Vector2(0.5, 0.5)))
	_fit_still_layer(_illustration)
	if _reduced_motion():
		return
	_illustration_drift = create_tween().set_ignore_time_scale(true)
	_illustration_drift.tween_property(_illustration, "scale", Vector2.ONE * STILL_DRIFT_SCALE, STILL_DRIFT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _stop_drift() -> void:
	if _illustration_drift != null:
		_illustration_drift.kill()
	_illustration_drift = null


func _reduced_motion() -> bool:
	return SettingsManager != null and bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))


## Keeps the reveal pattern in the rect's own pixels and the push-in centred
## on the still's focal point as the window resizes.
func _fit_still_layer(layer: TextureRect) -> void:
	(layer.material as ShaderMaterial).set_shader_parameter(&"rect_size", layer.size)
	layer.pivot_offset = layer.size * (layer.get_meta(&"focus", Vector2(0.5, 0.5)) as Vector2)


func _make_still_layer(label: String) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = label
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.visible = false
	var material := ShaderMaterial.new()
	material.shader = STILL_SHADER
	material.set_shader_parameter(&"reveal", 1.0)
	layer.material = material
	layer.resized.connect(_fit_still_layer.bind(layer))
	return layer


## The stroke pattern the stills paint in with: seamless smooth noise (no
## art asset), made once per run.
static func _stroke_texture() -> Texture2D:
	if _shared_strokes == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.seed = 1016
		noise.frequency = 0.014
		noise.fractal_octaves = 3
		_shared_strokes = ImageTexture.create_from_image(noise.get_seamless_image(256, 256))
	return _shared_strokes


func _ensure_strokes() -> void:
	for still in [_illustration, _illustration_back]:
		var material := (still as TextureRect).material as ShaderMaterial
		if material.get_shader_parameter(&"strokes") == null:
			material.set_shader_parameter(&"strokes", _stroke_texture())


func _update_shade() -> void:
	if _style < 0:
		return
	var colour: Color = _look(_style)["shade"]
	if _illustration.visible:
		colour.a = minf(colour.a, 0.24)
	_shade.color = colour


func _pause_owns_input() -> bool:
	# Asked every frame of a reveal and on every input: a group lookup, never
	# a recursive search of the whole scene.
	var pause := get_tree().get_first_node_in_group(&"pause_menu")
	return pause != null and (bool(pause.get("is_open")) or bool(pause.get("_leaving")))

func present_historical(mortal_name: String) -> void:
	await present_card(
		Style.HISTORICAL,
		"",
		"",
		OpeningSequenceData.HISTORICAL_PREFACE,
		[],
		"Continue"
	)
	await present_card(
		Style.HISTORICAL,
		OpeningSequenceData.HISTORICAL_EYEBROW,
		"A PROHIBITED EXPERIMENT",
		OpeningSequenceData.historical_body(mortal_name),
		[],
		"Begin"
	)

func present_dialogue(speaker: String, role: String, text_value: String, choices: Array = []) -> int:
	return await present_card(Style.DIALOGUE, role, speaker, text_value, choices, "Continue")

func present_announcement(title_value: String, body_value: String, button_text: String = "Acknowledge") -> void:
	if SfxManager != null:
		SfxManager.play_ui(&"ui_error", -2.0)
	await present_card(Style.INSTITUTIONAL, "FACILITY ANNOUNCEMENT", title_value, body_value, [], button_text)

func present_synthetic(title_value: String, body_value: String) -> void:
	await present_card(Style.SYNTHETIC, "SYNTHETIC RESPONSE", title_value, body_value, [], "Stabilise")

func present_follower(body_value: String) -> void:
	await present_card(Style.FOLLOWER, "HUMAN COMMITMENT", OpeningSequenceData.FOLLOWER_TITLE, body_value, [], "Continue")

func present_card(style: int, eyebrow_value: String, title_value: String, body_value: String, choices: Array = [], button_text: String = "Continue") -> int:
	hide_prompt()
	_clear_choices()
	_apply_style(style)
	_eyebrow.text = eyebrow_value
	_eyebrow.visible = eyebrow_value != ""
	_title.text = title_value
	_title.visible = title_value != ""
	_rule.visible = title_value != "" or eyebrow_value != ""
	_body.text = body_value
	_body.visible_characters = 0
	_reveal_progress = 0.0
	_revealing = _body.get_total_character_count() > 0
	_has_choices = not choices.is_empty()
	# The shade outlives a card by a frame, so a run of cards never flickers.
	var was_showing := _shade.visible
	_panel.visible = true
	_shade.visible = true
	_waiting = true
	_continue_button.text = button_text
	_scroll.scroll_vertical = 0
	_choices.visible = false
	_continue_button.visible = _revealing or not _has_choices
	if _has_choices:
		for index in range(choices.size()):
			var entry: Dictionary = choices[index] as Dictionary
			var button := Button.new()
			button.text = String(entry.get("label", "Continue"))
			button.focus_mode = Control.FOCUS_ALL
			button.custom_minimum_size = Vector2(0.0, 38.0)
			OverlayKit.style_choice(button)
			button.pressed.connect(_select_choice.bind(index))
			_choices.add_child(button)
	_refit_panel()
	# Once the new words are laid out, fit the card to them (a shorter card
	# after a long one would otherwise keep the long one's height).
	_refit_panel.call_deferred()
	_play_arrival(was_showing)
	if _revealing and is_inf(Accessibility.current_typewriter_characters_per_second()):
		_complete_reveal()
	elif _revealing or not _has_choices:
		_focus_card.call_deferred()
	else:
		_complete_reveal()
	var result := -1
	if choices.is_empty():
		await advanced
	else:
		result = await choice_selected
	_waiting = false
	hide_card()
	return result


## Each card eases up into place; the shade fades in only when the first card
## of a run of cards arrives over the world.
func _play_arrival(was_showing: bool) -> void:
	if not was_showing:
		OverlayKit.fade_in(_shade, 0.28)
	OverlayKit.arrive(_stage, 14.0, 0.38, 0.02)


func _refit_panel() -> void:
	if _panel == null or _column == null or not _panel.visible:
		return
	var view_size := get_viewport().get_visible_rect().size
	var width := minf(PANEL_WIDTH, maxf(1.0, view_size.x - 32.0))
	var content_width := maxf(1.0, width - 98.0)
	_title.custom_minimum_size.x = content_width
	_body.custom_minimum_size.x = content_width
	_rule.custom_minimum_size.x = minf(380.0, content_width)
	_panel.custom_minimum_size.x = width
	_panel.size.x = width
	_scroll.custom_minimum_size.y = minf(_column.get_combined_minimum_size().y, maxf(1.0, view_size.y - 86.0))
	_panel.reset_size()
	_place_panel()


## Keeps the card at its voice's height unless that would run its foot off
## the screen (a long account, or choices unfolding under the text).
func _place_panel() -> void:
	if _panel == null:
		return
	var view_size := get_viewport().get_visible_rect().size
	var top := HISTORICAL_TOP if _style == Style.HISTORICAL else PANEL_TOP
	if _illustration.visible:
		top = view_size.y * 0.62
	_panel.position = Vector2((view_size.x - _panel.size.x) * 0.5, maxf(16.0, minf(top, view_size.y - 16.0 - _panel.size.y)))

func advance() -> void:
	if not _waiting or _pause_owns_input():
		return
	if _revealing:
		_complete_reveal()
		return
	if _has_choices:
		return
	advanced.emit()


func _complete_reveal() -> void:
	_revealing = false
	_body.visible_characters = -1
	_reveal_progress = float(_body.get_total_character_count())
	_choices.visible = _has_choices
	_continue_button.visible = not _has_choices
	_refit_panel.call_deferred()
	_focus_card.call_deferred()


func _focus_card() -> void:
	if not _waiting or not _panel.visible or _pause_owns_input():
		return
	if _scroll.get_v_scroll_bar().max_value > _scroll.get_v_scroll_bar().page:
		_scroll.grab_focus()
	elif _has_choices and not _revealing and _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()
	else:
		_continue_button.grab_focus()


func _reading_input(event: InputEvent) -> void:
	if not _scroll.has_focus() or _revealing or _pause_owns_input():
		return
	if event.is_action_pressed(&"ui_up"):
		_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical - 40)
		_scroll.accept_event()
		return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var direction := -1 if event.keycode == KEY_PAGEUP else 1
		_scroll.scroll_vertical += direction * int(_scroll.size.y * 0.8)
		_scroll.accept_event()
		return
	if event.is_action_pressed(&"ui_down"):
		var end := _scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page
		if _scroll.scroll_vertical < end:
			_scroll.scroll_vertical += 40
			_scroll.accept_event()
			return
	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_focus_next"):
		if _has_choices and _choices.get_child_count() > 0:
			(_choices.get_child(0) as Button).grab_focus()
		else:
			_continue_button.grab_focus()
		_scroll.accept_event()

func show_prompt(text_value: String) -> void:
	var was_visible := _prompt.visible
	_prompt.text = text_value
	_prompt.visible = text_value != ""
	if _prompt.visible and not was_visible:
		_prompt.modulate.a = 0.0
		OverlayKit.tween(_prompt).tween_property(_prompt, "modulate:a", 1.0, 0.24)

func hide_prompt() -> void:
	_prompt.visible = false


func is_prompt_visible() -> bool:
	return _prompt != null and _prompt.visible

func hide_card() -> void:
	_revealing = false
	if _panel != null:
		_panel.visible = false
	_hide_shade_after_frame()


## The next card usually follows in the same frame; only a shade still unused
## a frame later goes.
func _hide_shade_after_frame() -> void:
	if _shade == null or not is_inside_tree():
		if _shade != null:
			_shade.visible = false
		return
	await get_tree().process_frame
	if _shade != null and _panel != null and not _panel.visible:
		_shade.visible = false

func _select_choice(index: int) -> void:
	if _waiting and not _pause_owns_input():
		choice_selected.emit(index)

func _clear_choices() -> void:
	if _choices == null:
		return
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


## One voice's look, built once and shared by every card in that voice.
static func _look(style: int) -> Dictionary:
	if _looks.has(style):
		return _looks[style]
	var look := {
		"panel": OverlayKit.shared(&"card"),
		"frame": true,
		"frame_colour": Color(0.58, 0.44, 0.27, 0.85),
		"glow": 0.0,
		"eyebrow": Color(0.78, 0.6, 0.38),
		"title": OverlayKit.GOLD_BRIGHT,
		"title_font": &"heading",
		"title_size": 29,
		"rule": Color(0.66, 0.5, 0.31, 0.75),
		"body_font": &"body",
		"body_size": 22,
		"body": OverlayKit.PARCHMENT,
		"align": HORIZONTAL_ALIGNMENT_LEFT,
		"shade": Color(0.008, 0.006, 0.005, 0.66),
	}
	match style:
		Style.HISTORICAL:
			look["panel"] = OverlayKit.shared(&"empty")
			look["frame"] = false
			look["eyebrow"] = Color(0.72, 0.58, 0.4)
			look["title"] = OverlayKit.PARCHMENT
			look["title_font"] = &"title"
			look["title_size"] = 40
			look["body_font"] = &"italic"
			look["body_size"] = 25
			look["body"] = Color(0.88, 0.83, 0.74)
			look["align"] = HORIZONTAL_ALIGNMENT_CENTER
			look["shade"] = Color(0.006, 0.005, 0.004, 0.84)
		Style.INSTITUTIONAL:
			var notice := OverlayKit.box(Color(0.05, 0.024, 0.02, 0.97), Color(0, 0, 0, 0), 0, 0.0, 28)
			notice.shadow_color = Color(0, 0, 0, 0.62)
			look["panel"] = notice
			look["frame_colour"] = Color(0.74, 0.32, 0.24, 0.9)
			look["eyebrow"] = Color(0.92, 0.45, 0.34)
			look["title"] = OverlayKit.PARCHMENT
			look["title_size"] = 26
			look["rule"] = Color(0.78, 0.36, 0.26, 0.8)
		Style.SYNTHETIC:
			var cold := OverlayKit.box(Color(0.02, 0.028, 0.03, 0.97), Color(0, 0, 0, 0), 0, 0.0, 28)
			cold.shadow_color = Color(0, 0, 0, 0.62)
			look["panel"] = cold
			look["frame_colour"] = Color(0.34, 0.6, 0.62, 0.8)
			look["eyebrow"] = OverlayKit.TEAL
			look["title"] = Color(0.88, 0.9, 0.86)
			look["rule"] = Color(0.42, 0.76, 0.78, 0.7)
		Style.FOLLOWER:
			var warm := OverlayKit.box(Color(0.05, 0.036, 0.024, 0.97), Color(0, 0, 0, 0), 0, 0.0, 30)
			warm.shadow_color = Color(0.5, 0.28, 0.08, 0.3)
			look["panel"] = warm
			look["frame_colour"] = Color(0.86, 0.66, 0.4, 0.95)
			look["glow"] = 0.35
			look["eyebrow"] = OverlayKit.GOLD
			look["title"] = OverlayKit.GOLD_BRIGHT
			look["rule"] = Color(0.9, 0.7, 0.42, 0.85)
	_looks[style] = look
	return look


func _apply_style(style: int) -> void:
	if style == _style:
		return
	_style = style
	var look := _look(style)
	_panel.add_theme_stylebox_override("panel", look["panel"] as StyleBox)
	_frame.visible = bool(look["frame"])
	_frame.set("colour", look["frame_colour"])
	_frame.set("glow", float(look["glow"]))
	_update_shade()
	var align: HorizontalAlignment = int(look["align"]) as HorizontalAlignment
	OverlayKit.style_label(_eyebrow, &"caption", 14, look["eyebrow"] as Color)
	OverlayKit.style_label(_title, StringName(look["title_font"]), int(look["title_size"]), look["title"] as Color)
	OverlayKit.style_label(_body, StringName(look["body_font"]), int(look["body_size"]), look["body"] as Color)
	for label: Label in [_eyebrow, _title, _body]:
		label.horizontal_alignment = align
	_rule.set("colour", look["rule"])
	_rule.set("ornament_at", 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.035)
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if align == HORIZONTAL_ALIGNMENT_CENTER else Control.SIZE_FILL
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if align == HORIZONTAL_ALIGNMENT_CENTER else Control.SIZE_SHRINK_END

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = CARD_THEME
	add_child(root)
	# The previous still sits beneath the current one while it paints over.
	_illustration_back = _make_still_layer("IllustrationBehind")
	root.add_child(_illustration_back)
	_illustration = _make_still_layer("Illustration")
	root.add_child(_illustration)
	_shade = ColorRect.new()
	_shade.color = Color(0.008, 0.006, 0.005, 0.66)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shade)
	# The stage moves for the arrival; the card inside it keeps its place.
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stage)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(_panel)
	_panel.resized.connect(_place_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 26)
	_panel.add_child(margin)
	_frame = ArcaneFrameScript.new() as Control
	_frame.set("inset", 6.0)
	_panel.add_child(_frame)
	_scroll = ScrollContainer.new()
	_scroll.name = "Reading"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.focus_mode = Control.FOCUS_ALL
	_scroll.gui_input.connect(_reading_input)
	margin.add_child(_scroll)
	_column = VBoxContainer.new()
	var column := _column
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 9)
	_scroll.add_child(column)
	_eyebrow = Label.new()
	column.add_child(_eyebrow)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label measures its height at its width; give it the column's
	# from the start, or the first measurement stacks every word.
	_title.custom_minimum_size = Vector2(PANEL_WIDTH - 80.0, 0)
	column.add_child(_title)
	_rule = ArcaneRuleScript.new() as Control
	_rule.custom_minimum_size = Vector2(380, 12)
	column.add_child(_rule)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Shape the whole account before revealing it: the reading area is sized
	# when a card starts, and words must not jump lines as letters arrive.
	_body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_body.custom_minimum_size = Vector2(PANEL_WIDTH - 80.0, 0)
	_body.add_theme_constant_override("line_spacing", 2)
	column.add_child(_body)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 3)
	column.add_child(_choices)
	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(200, 44)
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_continue_button.pressed.connect(advance)
	column.add_child(_continue_button)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_left = -340.0
	_prompt.offset_right = 340.0
	_prompt.offset_top = -100.0
	_prompt.offset_bottom = -52.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	OverlayKit.style_label(_prompt, &"semi", 19, OverlayKit.GOLD_BRIGHT, 3)
	_prompt.add_theme_stylebox_override("normal", OverlayKit.shared(&"plate"))
	_prompt.visible = false
	root.add_child(_prompt)
	_stage.resized.connect(_refit_panel)
