extends CanvasLayer
class_name MajorChoice

const Accessibility := preload("res://core/settings/AccessibilityPresentation.gd")

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
var _is_open := false
var _locked := false
var _focused_id: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_button.pressed.connect(confirm_focused_choice)
	back_button.pressed.connect(_clear_focus)
	confirm_button.disabled = true


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_locked = false
	visible = true
	_clear_focus()
	_update_stage_copy()
	_spawn_cards()
	_play_open_anim()


func _update_stage_copy() -> void:
	var stage_id: StringName = Global.pending_doctrine_stage() if Global != null else &""
	var descriptor := "METHOD // THE INSTRUMENT IS CHOSEN"
	match stage_id:
		&"doctrine": descriptor = "DOCTRINE // THE SYSTEM LEARNS TO WORSHIP"
		&"apotheosis": descriptor = "APOTHEOSIS // DIVINITY IS MADE REPEATABLE"
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
	confirm_button.disabled = false
	warning_label.text = "SEAL READY · THIS INSCRIPTION CANNOT BE REVISED"
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
	warning_label.text = "SELECT A THESIS PLATE TO EXAMINE ITS SEAL"
	for child in cards_box.get_children():
		if child is MajorChoiceCard:
			(child as MajorChoiceCard).set_plate_focused(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"ui_cancel") and _focused_id != StringName():
		_clear_focus()
		get_viewport().set_input_as_handled()


func _close() -> void:
	_is_open = false
	visible = false
	for child in cards_box.get_children():
		child.queue_free()


func _play_open_anim() -> void:
	if _open_tw != null:
		_open_tw.kill()
	overlay.modulate.a = 0.0
	window.modulate.a = 0.0
	_open_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tw.tween_property(overlay, "modulate:a", 1.0, Accessibility.current_motion_duration(0.10))
	_open_tw.parallel().tween_property(window, "modulate:a", 1.0, Accessibility.current_motion_duration(0.14))
