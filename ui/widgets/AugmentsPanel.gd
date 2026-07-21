extends VBoxContainer
class_name AugmentsPanel

@export var slot_count: int = 3

func _ready() -> void:
	# Clamp to what exists in the scene (Aug1/Aug2/Aug3)
	slot_count = min(slot_count, get_child_count())

	# Optional: clear placeholder labels on boot
	for i in range(slot_count):
		set_slot(i, null)

func set_slot(slot: int, augment: Variant) -> void:
	var slot_node: PanelContainer = _get_slot_node(slot)
	if slot_node == null:
		return

	var icon_rect: TextureRect = slot_node.get_node_or_null("Content/Icon") as TextureRect
	var name_label: Label = slot_node.get_node_or_null("Content/NameStrip/Name") as Label

	if icon_rect == null or name_label == null:
		push_warning("AugmentsPanel: Slot node missing Icon or Name label: " + slot_node.name)
		return

	# Empty
	if augment == null:
		icon_rect.texture = null
		name_label.text = ""
		slot_node.set_meta("augment_id", "")
		slot_node.set_meta("augment_data", null)
		return

	var tex: Texture2D = null
	var nm: String = ""
	var aid: StringName = StringName()

	# Try to pull icon + name from common shapes:
	# - Texture2D directly
	# - Dictionary with keys: icon, name, display_name
	# - Object/Resource with properties: icon, name, display_name
	if augment is Texture2D:
		tex = augment
		nm = "AUGMENT"
	elif augment is Dictionary:
		var d: Dictionary = augment
		if d.has("id") and str(d["id"]) != "":
			aid = StringName(str(d["id"]))
		if d.has("icon") and d["icon"] is Texture2D:
			tex = d["icon"] as Texture2D
		if d.has("display_name") and str(d["display_name"]) != "":
			nm = str(d["display_name"])
		elif d.has("name") and str(d["name"]) != "":
			nm = str(d["name"])
	elif augment is Object:
		var o: Object = augment as Object
		var v_id: Variant = o.get("id")
		if v_id != null and str(v_id) != "":
			aid = StringName(str(v_id))

		var v_icon: Variant = o.get("icon")
		if v_icon is Texture2D:
			tex = v_icon as Texture2D

		var v_dn: Variant = o.get("display_name")
		var v_n: Variant = o.get("name")
		if v_dn != null and str(v_dn) != "":
			nm = str(v_dn)
		elif v_n != null and str(v_n) != "":
			nm = str(v_n)

	icon_rect.texture = tex
	name_label.text = nm

	# Store meta so tooltip controllers can resolve details.
	if aid != StringName():
		slot_node.set_meta("augment_id", String(aid))
	else:
		slot_node.set_meta("augment_id", "")
	if augment is AugmentData:
		slot_node.set_meta("augment_data", augment)
	else:
		slot_node.set_meta("augment_data", null)

func set_augments(arr: Array) -> void:
	for i in range(slot_count):
		var a: Variant = (arr[i] if i < arr.size() else null)
		set_slot(i, a)

func get_first_empty_slot() -> int:
	for i in range(slot_count):
		var slot_node: PanelContainer = _get_slot_node(i)
		if slot_node == null:
			continue

		var icon_rect: TextureRect = slot_node.get_node_or_null("Content/Icon") as TextureRect
		var name_label: Label = slot_node.get_node_or_null("Content/NameStrip/Name") as Label
		if icon_rect == null or name_label == null:
			continue

		var empty_icon: bool = (icon_rect.texture == null)
		var empty_name: bool = (name_label.text.strip_edges() == "")
		if empty_icon and empty_name:
			return i

	return -1

func _get_slot_node(slot: int) -> PanelContainer:
	var idx: int = slot + 1
	var n: Node = get_node_or_null("Aug%d" % idx)
	return n as PanelContainer
