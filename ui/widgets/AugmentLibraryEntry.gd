extends Button
class_name AugmentLibraryEntry

signal requested_equip(augment_id: StringName)
signal request_reorder(from_index: int, to_index: int)

@onready var icon_rect: TextureRect = $Margin/HBox/IconFrame/Icon
@onready var name_label: Label = $Margin/HBox/VBox/Name
@onready var tag_label: Label = $Margin/HBox/VBox/Tags

var augment_id: StringName = &""
var owned_index: int = -1
var allow_reorder: bool = true
var _data: AugmentData = null

func set_data(a: AugmentData, tags: PackedStringArray = PackedStringArray()) -> void:
	_data = a
	augment_id = (a.id if a != null else &"")
	if icon_rect != null:
		icon_rect.texture = (a.icon if a != null else null)
	if name_label != null:
		name_label.text = (a.display_name if a != null else "Unknown")
	if tag_label != null:
		if tags.size() > 0:
			tag_label.text = "  ".join(tags)
			tag_label.visible = true
		else:
			tag_label.text = ""
			tag_label.visible = false
	# The library used to show only the name — hovering now answers
	# "yes I have this, but what does it DO?"
	tooltip_text = _compose_tooltip(a)


func _compose_tooltip(a: AugmentData) -> String:
	if a == null:
		return ""
	var parts: PackedStringArray = []
	if a.card_blurb.strip_edges() != "":
		parts.append(a.card_blurb.strip_edges())
	elif a.description.strip_edges() != "":
		parts.append(a.description.strip_edges())
	if a.details.strip_edges() != "":
		parts.append(a.details.strip_edges())
	var level: int = Global.get_augment_level(a.id) if Global != null and Global.has_method("get_augment_level") else 1
	if level > 1:
		parts.append("Level %d" % level)
	return "\n\n".join(parts)

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func() -> void:
		# Single click: quick-equip (kept for convenience)
		if augment_id != StringName():
			requested_equip.emit(augment_id)
	)

func _gui_input(event: InputEvent) -> void:
	# Double-click also equips (nice UX + avoids “Button pressed swallowed” edge cases)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click and mb.pressed:
			if augment_id != StringName():
				requested_equip.emit(augment_id)

# ------------------------------------------------------------
# Drag & drop
# Godot 4 uses _get/_can/_drop overrides (not get_drag_data)
# ------------------------------------------------------------

# Drag from library -> slot, OR reorder within library.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if augment_id == StringName():
		return null

	var d := {
		"type": &"augment",
		"augment_id": augment_id,
		"source": &"library",
		"owned_index": owned_index
	}

	# Preview (small copy of this button)
	var p := duplicate() as Control
	if p != null:
		p.custom_minimum_size = Vector2(220, 64)
		p.modulate = Color(1, 1, 1, 0.92)
		set_drag_preview(p)
	return d

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not allow_reorder:
		return false
	if not (data is Dictionary):
		return false
	var d: Dictionary = data
	if d.get("type", &"") != &"augment":
		return false
	# Only reorder library items onto other library items.
	if d.get("source", &"") != &"library":
		return false
	if not d.has("owned_index"):
		return false
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var d: Dictionary = data
	var from_i: int = int(d.get("owned_index", -1))
	var to_i: int = owned_index
	if from_i < 0 or to_i < 0 or from_i == to_i:
		return
	request_reorder.emit(from_i, to_i)
