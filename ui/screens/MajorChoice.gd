extends CanvasLayer
class_name MajorChoice
## The Ascension Doctrine: three thesis plates laid on a dark table, held and
## turned like the augment pick's cards (MajorChoiceCard). Pressing a plate
## examines its seal; Inscribe applies it. On inscription the chosen plate
## blazes and the others sink before the chamber fades; the Doctrine itself is
## applied and announced at once, exactly as before.
##
## Motion runs on real time (the hub may stop the world under it) and honours
## Reduced Motion.

const ChamberKit := preload("res://ui/widgets/chambers/ChamberKit.gd")
const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")

signal choice_committed(choice_id: StringName)

@export var card_scene: PackedScene

@onready var overlay: ColorRect = $Overlay
@onready var window: PanelContainer = $Center/Window
@onready var stage_label: Label = $Center/Window/Margin/VBox/Stage
@onready var cards_box: HBoxContainer = $Center/Window/Margin/VBox/Cards
@onready var warning_label: Label = $Center/Window/Margin/VBox/Warning
@onready var confirm_button: Button = $Center/Window/Margin/VBox/Actions/Confirm
@onready var back_button: Button = $Center/Window/Margin/VBox/Actions/Back

var _open_tw: Tween
var _close_tw: Tween
var _warn_tw: Tween
var _is_open := false
var _locked := false
var _focused_id: StringName = &""
var _vignette: TextureRect = null
var _pool: TextureRect = null
var _dust: CPUParticles2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_button.pressed.connect(confirm_focused_choice)
	back_button.pressed.connect(_clear_focus)
	confirm_button.disabled = true
	_dress()


func open() -> void:
	if _is_open:
		return
	_finish_close()
	_is_open = true
	_locked = false
	visible = true
	_clear_focus()
	_update_stage_copy()
	_spawn_cards()
	_play_open_anim()


func _update_stage_copy() -> void:
	var stage_id: StringName = Global.pending_doctrine_stage() if Global != null else &""
	var descriptor := "METHOD  ·  THE INSTRUMENT IS CHOSEN"
	match stage_id:
		&"doctrine": descriptor = "DOCTRINE  ·  THE SYSTEM LEARNS TO WORSHIP"
		&"apotheosis": descriptor = "APOTHEOSIS  ·  DIVINITY IS MADE REPEATABLE"
	if Global != null and Global.is_apocrypha_stage(stage_id):
		descriptor = "APOCRYPHA  ·  WHAT THE FIRST PASS REFUSED"
	stage_label.text = descriptor


func _spawn_cards() -> void:
	for child in cards_box.get_children():
		child.queue_free()
	var offer: Array = Global.get_major_choice_offer(3) if Global != null else []
	var seal_index := 1
	for candidate in offer:
		var definition := candidate as MajorChoiceDef
		if definition == null or not definition.is_doctrine_complete():
			continue
		var card := card_scene.instantiate() as MajorChoiceCard
		cards_box.add_child(card)
		card.set_def(definition, definition.preview_lines(Global), seal_index)
		card.focused.connect(_on_card_focused)
		seal_index += 1
	if cards_box.get_child_count() > 0:
		(cards_box.get_child(0) as Control).grab_focus()


func _on_card_focused(card: MajorChoiceCard) -> void:
	if _locked or card == null:
		return
	_focused_id = card.choice_id
	for child in cards_box.get_children():
		if child is MajorChoiceCard:
			(child as MajorChoiceCard).set_plate_focused(child == card)
			(child as MajorChoiceCard).set_quieted(child != card)
	confirm_button.disabled = false
	# What the family would awaken goes here, where a full line fits.
	var awakening := ""
	if card.def_ref != null and Global != null:
		awakening = DoctrineFamilies.awakening_line(card.def_ref.family_id, Global.doctrine_family_count(card.def_ref.family_id))
	_set_warning("SEAL READY  ·  " + (awakening if awakening != "" else "THIS INSCRIPTION CANNOT BE REVISED"), true)
	confirm_button.grab_focus()


func focus_choice(definition: MajorChoiceDef) -> void:
	if definition == null:
		return
	for child in cards_box.get_children():
		if child is MajorChoiceCard and (child as MajorChoiceCard).choice_id == definition.id:
			_on_card_focused(child)
			return


func confirm_focused_choice() -> bool:
	if _locked or _focused_id == StringName() or Global == null:
		return false
	_locked = true
	var applied := bool(Global.apply_major_choice(_focused_id))
	if not applied:
		_locked = false
		return false
	choice_committed.emit(_focused_id)
	_close()
	return true


func _clear_focus() -> void:
	_focused_id = &""
	confirm_button.disabled = true
	_set_warning("SELECT A THESIS PLATE TO EXAMINE ITS SEAL", false)
	for child in cards_box.get_children():
		if child is MajorChoiceCard:
			(child as MajorChoiceCard).set_plate_focused(false)
			(child as MajorChoiceCard).set_quieted(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"ui_cancel") and _focused_id != StringName():
		_clear_focus()
		get_viewport().set_input_as_handled()


## Closed at once in every way that matters (input, `_is_open`); the chamber
## then lets the inscription land before it fades.
func _close() -> void:
	_is_open = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in cards_box.get_children():
		if child is MajorChoiceCard:
			var card := child as MajorChoiceCard
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.focus_mode = Control.FOCUS_NONE
			if card.choice_id == _focused_id:
				card.play_inscribe()
			else:
				card.play_dismiss()
	confirm_button.disabled = true
	# Nothing in the window may act while the inscription fades out.
	back_button.disabled = true
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focus_owner := window.get_viewport().gui_get_focus_owner()
	if focus_owner != null and window.is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	if _open_tw != null:
		_open_tw.kill()
	if _close_tw != null:
		_close_tw.kill()
	var center := get_node_or_null("Center") as Control
	var still := ChamberKit.reduced()
	_close_tw = ChamberKit.tween(self)
	_close_tw.tween_interval(0.12 if still else 0.6)
	_close_tw.set_parallel(true)
	var fade := 0.18 if still else 0.42
	_close_tw.chain().tween_property(overlay, "modulate:a", 0.0, fade)
	for n in [center, _vignette, _pool, _dust]:
		if n != null:
			_close_tw.parallel().tween_property(n, "modulate:a", 0.0, fade)
	_close_tw.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	if _close_tw != null and _close_tw.is_running():
		_close_tw.kill()
	_close_tw = null
	if _is_open:
		return
	visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	back_button.disabled = false
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in cards_box.get_children():
		child.queue_free()
	if _dust != null:
		_dust.queue_free()
		_dust = null


# ---------------------------------------------------------------------------
# Presentation (the chamber register; no behaviour lives here)
# ---------------------------------------------------------------------------

func _dress() -> void:
	overlay.color = Color(0.007, 0.006, 0.005, 0.86)
	_vignette = ChamberKit.vignette_rect()
	add_child(_vignette)
	move_child(_vignette, overlay.get_index() + 1)
	# Candle light pooled on the table the plates lie on.
	_pool = ChamberKit.light_pool(Vector2(960, 610), Vector2(980, 380), ChamberKit.EMBER, 0.28)
	add_child(_pool)
	move_child(_pool, _vignette.get_index() + 1)
	confirm_button.add_theme_stylebox_override("normal", ChamberKit.shared(&"primary"))
	confirm_button.add_theme_stylebox_override("hover", ChamberKit.shared(&"primary_hover"))
	confirm_button.add_theme_font_size_override("font_size", 17)
	confirm_button.add_theme_color_override("font_color", ChamberKit.GOLD_BRIGHT)
	back_button.add_theme_font_size_override("font_size", 15)
	var instruction := get_node_or_null("Center/Window/Margin/VBox/Instruction") as Label
	if instruction != null:
		instruction.add_theme_color_override("font_color", ChamberKit.BODY)
	stage_label.add_theme_color_override("font_color", ChamberKit.GOLD)


func _set_warning(text: String, sealed: bool) -> void:
	var changed := warning_label.text != text
	warning_label.text = text
	warning_label.add_theme_color_override("font_color", ChamberKit.GOLD_BRIGHT if sealed else ChamberKit.GOLD_DIM)
	if not changed or not visible or not is_inside_tree():
		return
	if _warn_tw != null and _warn_tw.is_running():
		_warn_tw.kill()
	warning_label.modulate.a = 0.0
	_warn_tw = ChamberKit.tween(warning_label)
	_warn_tw.tween_property(warning_label, "modulate:a", 1.0, 0.1 if ChamberKit.reduced() else 0.28)


func _play_open_anim() -> void:
	if _open_tw != null:
		_open_tw.kill()
	var center := get_node_or_null("Center") as Control
	var still := ChamberKit.reduced()
	if _dust == null:
		_dust = ArcaneParticles.dust()
		_dust.name = "Dust"
		_dust.position = Vector2(960, 560)
		_dust.emission_rect_extents = Vector2(900, 440)
		_dust.amount = 8 if still else 22
		add_child(_dust)
		move_child(_dust, _pool.get_index() + 1)
	for n in [overlay, _vignette, _pool, _dust, center]:
		if n != null:
			(n as CanvasItem).modulate.a = 0.0
	var header: Array = []
	for path in ["Title", "Stage", "Instruction", "TitleRule", "Warning", "Actions"]:
		var node := get_node_or_null("Center/Window/Margin/VBox/" + path) as Control
		if node != null:
			header.append(node)
			node.modulate.a = 0.0 if not still else 1.0
	if center != null:
		center.modulate.a = 1.0
	# Wait out the frame the plates are built in, so its long delta does not
	# swallow the opening.
	if not await ChamberKit.settle(self, 1) or not _is_open:
		return
	_open_tw = ChamberKit.tween(self).set_parallel(true)
	_open_tw.tween_property(overlay, "modulate:a", 1.0, 0.12 if still else 0.22)
	for n in [_vignette, _pool, _dust]:
		if n != null:
			_open_tw.tween_property(n, "modulate:a", 1.0, 0.2 if still else 0.5)
	if still:
		return
	# The title settles out of the dark first; the plates are dealt beneath
	# it (each plate deals itself) and the seal line and choices follow.
	var delays := {"Title": 0.02, "Stage": 0.12, "Instruction": 0.18, "TitleRule": 0.22, "Warning": 0.75, "Actions": 0.85}
	for node in header:
		var d: float = delays.get(String(node.name), 0.2)
		_open_tw.tween_property(node, "modulate:a", 1.0, 0.45).set_delay(d)
	var title := get_node_or_null("Center/Window/Margin/VBox/Title") as Control
	if title != null:
		title.pivot_offset = Vector2(title.size.x * 0.5 if title.size.x > 0.0 else 550.0, 30.0)
		title.scale = Vector2.ONE * 1.06
		_open_tw.tween_property(title, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var rule := get_node_or_null("Center/Window/Margin/VBox/TitleRule") as Control
	if rule != null:
		rule.pivot_offset = Vector2(280, 11)
		rule.scale = Vector2(0.2, 1.0)
		_open_tw.tween_property(rule, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.22)
