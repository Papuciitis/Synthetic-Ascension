extends Button
class_name MajorChoiceCard

signal picked(choice_id: StringName, card: MajorChoiceCard)
signal hovered(card: MajorChoiceCard)
signal unhovered(card: MajorChoiceCard)

@export var base_bg := Color(0.10, 0.10, 0.10, 0.86)
@export var base_border := Color(0.12, 0.12, 0.12, 1.0)
@export var hover_border := Color(1.0, 0.55, 0.20, 1.0)
@export var pressed_border := Color(1.0, 0.35, 0.00, 1.0)
@export var corner_radius := 16
@export var border_width := 2

# Cards are meant to be scannable. Full details live in the bottom inspect panel.
const CARD_BULLETS_MAX: int = 2

var choice_id: StringName = &""
var def_ref: MajorChoiceDef = null

var _detail_blurb: String = ""
var _detail_bullets: Array[String] = []

var _hovered: bool = false
var _pressed: bool = false
var _style: StyleBoxFlat
var _tw: Tween = null

@onready var icon_rect: TextureRect = $Margin/VBox/Header/IconFrame/Icon
@onready var glyph_label: Label = $Margin/VBox/Header/IconFrame/Glyph
@onready var title_label: Label = $Margin/VBox/Header/TitleBox/Title
@onready var blurb_label: Label = $Margin/VBox/Header/TitleBox/Blurb
@onready var bullets_box: VBoxContainer = $Margin/VBox/Bullets
@onready var tag_extra: PanelContainer = $Margin/VBox/Tags/TagExtra
@onready var tag_extra_text: Label = $Margin/VBox/Tags/TagExtra/Text

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_NONE
	flat = false

	_build_style()
	_update_style()
	call_deferred("_init_pivot")

	mouse_entered.connect(func():
		_hovered = true
		_update_style()
		_hover_fx(true)
		hovered.emit(self)
	)

	mouse_exited.connect(func():
		_hovered = false
		_pressed = false
		_update_style()
		_hover_fx(false)
		unhovered.emit(self)
	)

	button_down.connect(func():
		_pressed = true
		_update_style()
		_press_fx(true)
	)

	button_up.connect(func():
		_pressed = false
		_update_style()
		_press_fx(false)
	)

	pressed.connect(func() -> void:
		picked.emit(choice_id, self)
	)

func _init_pivot() -> void:
	pivot_offset = size * 0.5

func set_def(d: MajorChoiceDef, preview: PackedStringArray) -> void:
	def_ref = d
	choice_id = (d.id if d != null else &"")
	if title_label:
		title_label.text = (d.title if d != null else "Major Choice")

	# Icon / glyph
	var tex: Texture2D = (d.icon if d != null else null)
	if icon_rect:
		icon_rect.texture = tex
	if glyph_label:
		glyph_label.visible = (tex == null)
		glyph_label.text = _glyph_for(d)

	# Blurb + bullet extraction
	var desc: String = (d.description if d != null else "")
	var blurb := _pick_blurb(desc)
	if blurb_label:
		blurb_label.text = blurb
	_detail_blurb = blurb

	var bullets: Array[String] = []
	# Prefer effect previews (clear + structured)
	for l in preview:
		var s := String(l).strip_edges()
		if s == "":
			continue
		# Keep bullets uniform (we add our own leading dot)
		if s.begins_with("•"):
			s = s.substr(1).strip_edges()
		bullets.append(s)

	# Merge: keep effect previews AND any explicit bullet lines authored in the description.
	var desc_bullets := _bullets_from_desc(desc)
	for b in desc_bullets:
		if not bullets.has(b):
			bullets.append(b)

	if bullets.is_empty():
		bullets = desc_bullets

	_detail_bullets = bullets.duplicate()
	_set_bullets(bullets)

	# Tag: style requirement / unique
	if tag_extra != null and tag_extra_text != null and d != null:
		var tag := ""
		if d.requires_style_id != StringName():
			tag = "STYLE: %s" % String(d.requires_style_id).to_upper()
		elif d.unique_per_attempt:
			tag = "UNIQUE"
		tag_extra.visible = (tag != "")
		tag_extra_text.text = tag

func _pick_blurb(desc: String) -> String:
	var lines := desc.split("\n", false)
	for raw in lines:
		var s := String(raw).strip_edges()
		if s == "":
			continue
		if s.begins_with("•") or s.begins_with("-"):
			continue
		return s
	return "Choose a path modifier."

func _bullets_from_desc(desc: String) -> Array[String]:
	var out: Array[String] = []
	var lines := desc.split("\n", false)
	for raw in lines:
		var s := String(raw).strip_edges()
		if s == "":
			continue
		if s.begins_with("•"):
			s = s.substr(1).strip_edges()
		elif s.begins_with("-"):
			s = s.substr(1).strip_edges()
		else:
			continue
		out.append(s)
	return out

func _set_bullets(lines: Array[String]) -> void:
	if bullets_box == null:
		return
	for c in bullets_box.get_children():
		c.queue_free()

	var shown_lines := lines
	if shown_lines.size() > CARD_BULLETS_MAX:
		shown_lines = shown_lines.slice(0, CARD_BULLETS_MAX)

	for s in shown_lines:
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 13)
		l.modulate = Color(1, 1, 1, 0.82)
		l.text = "• " + String(s)
		bullets_box.add_child(l)



func get_detail_text(max_bullets: int = 999) -> String:
	var parts: Array[String] = []
	var title := (def_ref.title if def_ref != null else (title_label.text if title_label != null else "Major Choice"))
	parts.append(String(title))
	if _detail_blurb.strip_edges() != "":
		parts.append(_detail_blurb.strip_edges())
	if not _detail_bullets.is_empty():
		parts.append("")
		var n := mini(max_bullets, _detail_bullets.size())
		for i in range(n):
			parts.append("• " + _detail_bullets[i])
	return "\n".join(parts)

func _glyph_for(d: MajorChoiceDef) -> String:
	if d == null:
		return "◆"
	var id := String(d.id)
	# Light “iconography” without actual textures
	if id.find("augment") != -1:
		return "⬡"
	if id.find("satchel") != -1 or id.find("bag") != -1:
		return "▣"
	if id.find("ritual") != -1 or id.find("sanct") != -1:
		return "✦"
	if id.find("melee") != -1:
		return "⚔"
	if id.find("ranged") != -1:
		return "➶"
	if id.find("magic") != -1:
		return "✺"
	return "◆"

func _build_style() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = base_bg
	_style.set_border_width_all(border_width)
	_style.border_color = base_border
	_style.corner_radius_top_left = corner_radius
	_style.corner_radius_top_right = corner_radius
	_style.corner_radius_bottom_left = corner_radius
	_style.corner_radius_bottom_right = corner_radius
	_style.shadow_size = 14
	_style.shadow_offset = Vector2(0, 8)
	_style.shadow_color = Color(0, 0, 0, 0.55)

	add_theme_stylebox_override("normal", _style)
	add_theme_stylebox_override("hover", _style)
	add_theme_stylebox_override("pressed", _style)
	add_theme_stylebox_override("focus", _style)

func _update_style() -> void:
	if _style == null:
		return
	_style.bg_color = base_bg
	_style.border_color = pressed_border if _pressed else (hover_border if _hovered else base_border)

func _hover_fx(on: bool) -> void:
	if _tw != null:
		_tw.kill()
		_tw = null
	_tw = create_tween()
	_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target := (Vector2(1.03, 1.03) if on else Vector2.ONE)
	_tw.tween_property(self, "scale", target, 0.12)

func _press_fx(on: bool) -> void:
	# quick micro feedback
	if _tw != null and _tw.is_running():
		return
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if on:
		t.tween_property(self, "scale", Vector2(0.99, 0.99), 0.05)
	else:
		t.tween_property(self, "scale", Vector2.ONE if not _hovered else Vector2(1.03, 1.03), 0.07)
