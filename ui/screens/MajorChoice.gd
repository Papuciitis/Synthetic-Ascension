extends CanvasLayer
class_name MajorChoice

const Accessibility := preload("res://core/settings/AccessibilityPresentation.gd")

signal choice_committed(choice_id: StringName)

@export var card_scene: PackedScene

@onready var overlay: ColorRect = $Overlay
@onready var window: PanelContainer = $Center/Window
@onready var cards_box: HBoxContainer = $Center/Window/Margin/VBox/Cards
@onready var details_panel: PanelContainer = $Center/Window/Margin/VBox/DetailsPanel
@onready var details_label: Label = $Center/Window/Margin/VBox/DetailsPanel/Margin/Details
@onready var foot: Label = $Center/Window/Margin/VBox/Foot

var _open_tw: Tween = null
var _is_open: bool = false
var _locked: bool = false

var _default_foot_text: String = ""
var _default_details_text: String = ""
var _hovered_card: MajorChoiceCard = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	visible = false

	if overlay:
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay.color = Color(0, 0, 0, 0.55)

	if card_scene == null:
		push_error("MajorChoice: card_scene not assigned.")
		return

	# Keep clicks from leaking behind the overlay.
	if window != null:
		window.mouse_filter = Control.MOUSE_FILTER_STOP

	# Defaults / hover preview area
	if foot != null:
		_default_foot_text = foot.text

	if details_label != null:
		_default_details_text = "Hover a card to view full details. Cards only show top highlights."
		details_label.text = _default_details_text

	if details_panel != null:
		details_panel.visible = true


func open() -> void:

	if _is_open:
		return
	_is_open = true
	_locked = false
	visible = true
	_hovered_card = null
	if details_panel != null:
		details_panel.visible = true
	if details_label != null:
		details_label.text = _default_details_text
	if foot != null:
		foot.text = _default_foot_text
	_spawn_cards()
	_play_open_anim()

func _spawn_cards() -> void:
	if cards_box == null:
		return
	for c in cards_box.get_children():
		c.queue_free()

	var offer: Array = []
	if Global != null and Global.has_method("get_major_choice_offer"):
		offer = Global.get_major_choice_offer(3)

	if offer.is_empty():
		push_warning("MajorChoice: offer is empty (no defs found).")
		return

	for def in offer:
		var d := def as MajorChoiceDef
		if d == null:
			continue

		var card := card_scene.instantiate() as MajorChoiceCard
		if card == null:
			continue
		cards_box.add_child(card)

		var preview: PackedStringArray = d.preview_lines(Global)
		card.set_def(d, preview)
		card.picked.connect(_on_card_picked)
		if card.has_signal("hovered"):
			card.hovered.connect(_on_card_hovered)
		if card.has_signal("unhovered"):
			card.unhovered.connect(_on_card_unhovered)

func _on_card_picked(id: StringName, _card: MajorChoiceCard) -> void:
	if _locked:
		return
	_locked = true

	if Global != null and Global.has_method("apply_major_choice"):
		Global.apply_major_choice(id)

	choice_committed.emit(id)
	_close()



func _on_card_hovered(card: MajorChoiceCard) -> void:
	_hovered_card = card
	if details_label != null and card != null and card.has_method("get_detail_text"):
		details_label.text = card.get_detail_text(999)
	if details_panel != null:
		details_panel.visible = true
	if foot != null:
		foot.text = "Click a card to choose. Your choice locks in immediately."

func _on_card_unhovered(card: MajorChoiceCard) -> void:
	if _hovered_card != card:
		return
	_hovered_card = null
	if details_label != null:
		details_label.text = _default_details_text
	if details_panel != null:
		details_panel.visible = true
	if foot != null:
		foot.text = _default_foot_text

func _close() -> void:
	_is_open = false
	_locked = false
	visible = false
	if details_panel != null:
		details_panel.visible = true
	if details_label != null:
		details_label.text = _default_details_text
	if foot != null:
		foot.text = _default_foot_text
	if cards_box:
		for c in cards_box.get_children():
			c.queue_free()

func _play_open_anim() -> void:
	if overlay == null:
		return
	if _open_tw != null:
		_open_tw.kill()
		_open_tw = null

	overlay.modulate = Color(1, 1, 1, 0)
	if window != null:
		window.modulate = Color(1, 1, 1, 0)
		window.scale = Vector2(0.985, 0.985)

	_open_tw = create_tween()
	_open_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_tw.tween_property(overlay, "modulate", Color(1, 1, 1, 1), Accessibility.current_motion_duration(0.12))

	if window != null:
		_open_tw.parallel().tween_property(window, "modulate", Color(1, 1, 1, 1), Accessibility.current_motion_duration(0.12))
		_open_tw.parallel().tween_property(window, "scale", Vector2(1, 1), Accessibility.current_motion_duration(0.16)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
