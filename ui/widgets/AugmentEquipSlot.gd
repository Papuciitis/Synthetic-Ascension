extends Button
class_name AugmentEquipSlot

signal drop_received(slot_index: int, data: Dictionary)
signal unequip_requested(slot_index: int)
signal lock_toggled(slot_index: int, locked: bool)

@export var slot_index: int = 0
@export var key_text: String = "1"

@onready var key_label: Label = $Margin/VBox/Header/Key
@onready var name_label: Label = $Margin/VBox/Header/Name
@onready var btn_lock: Button = $Margin/VBox/Header/BtnLock
@onready var icon_rect: TextureRect = $Margin/VBox/IconFrame/Icon
@onready var hint_label: Label = $Margin/VBox/Hint

var augment_id: StringName = &""
var locked: bool = false
var _data: AugmentData = null

func set_locked(v: bool) -> void:
	locked = v
	if btn_lock != null:
		btn_lock.button_pressed = locked
		btn_lock.text = ("UNLOCK" if locked else "LOCK")
		btn_lock.modulate = (Color(1, 0.55, 0.20, 0.95) if locked else Color(1, 1, 1, 0.55))

func set_data(a: AugmentData) -> void:
	_data = a
	augment_id = (a.id if a != null else &"")
	if key_label != null:
		key_label.text = "KEY " + key_text
	if name_label != null:
		name_label.text = (a.display_name if a != null else "Empty Slot")
	if icon_rect != null:
		icon_rect.texture = (a.icon if a != null else null)
	if hint_label != null:
		if locked:
			hint_label.text = "Locked (unlock to modify)"
			hint_label.modulate = Color(1, 1, 1, 0.45)
		else:
			hint_label.text = ("Right-click to unequip" if a != null else "Drop an augment here")
			hint_label.modulate = Color(1,1,1, 0.65 if a != null else 0.55)

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	if btn_lock != null:
		btn_lock.focus_mode = Control.FOCUS_NONE
		btn_lock.toggled.connect(func(v: bool) -> void:
			set_locked(v)
			lock_toggled.emit(slot_index, v)
		)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if augment_id != StringName() and not locked:
				unequip_requested.emit(slot_index)

# ------------------------------------------------------------
# Drag & drop (Godot 4 virtuals: _get/_can/_drop)
# ------------------------------------------------------------

# Drag from slot -> another slot
func _get_drag_data(_at_position: Vector2) -> Variant:
	if augment_id == StringName() or locked:
		return null
	var d := {
		"type": &"augment",
		"augment_id": augment_id,
		"source": &"slot",
		"slot": slot_index
	}
	var p := duplicate() as Control
	if p != null:
		p.custom_minimum_size = Vector2(240, 150)
		p.modulate = Color(1, 1, 1, 0.92)
		set_drag_preview(p)
	return d

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if locked:
		return false
	if not (data is Dictionary):
		return false
	var d: Dictionary = data
	if d.get("type", &"") != &"augment":
		return false
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if locked:
		return
	if data is Dictionary:
		drop_received.emit(slot_index, data)
