extends Button
class_name HubItemSlot

enum Kind { EQUIPPED, BAG, STASH }

@export var kind: int = Kind.BAG
@export var slot_index: int = 0

# NOTE: Button already has a built-in `icon` property, so don't name a member `icon`.
@onready var icon_rect: TextureRect = get_node_or_null("IconFrame/Icon") as TextureRect
@onready var badge: Label = get_node_or_null("SellBadge") as Label
@onready var icon_frame: Control = get_node_or_null("IconFrame") as Control
@onready var hint_label: Label = get_node_or_null("Hint") as Label
@onready var lock_badge: Label = get_node_or_null("LockBadge") as Label
@onready var lock_border: Panel = get_node_or_null("LockBorder") as Panel

var _host: Node = null
var _set_emblem: SetEmblem = null
var _manifest_badge: ManifestBadge = null

# --- Drag helpers (ScrollContainer-safe) ---
var _drag_armed: bool = false
var _drag_start: Vector2 = Vector2.ZERO
const _DRAG_THRESHOLD_PX: float = 6.0

func _ready() -> void:
	_set_emblem = get_node_or_null("SetEmblem") as SetEmblem
	if _set_emblem == null:
		_set_emblem = SetEmblem.new()
		_set_emblem.name = "SetEmblem"
		add_child(_set_emblem)
	_set_emblem.z_index = 8
	_set_emblem.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	_set_emblem.offset_left = -20.0
	_set_emblem.offset_top = -20.0
	_set_emblem.offset_right = -4.0
	_set_emblem.offset_bottom = -4.0
	_set_emblem.configure(&"")

	# Vendor stock rolls Manifestations like any other drop, so the shop grid
	# has to say which rings are the interesting ones before you buy.
	_manifest_badge = ManifestBadge.attach(self, Control.PRESET_BOTTOM_LEFT, Rect2(4, -20, 16, 16), 9)

	# Force UI-friendly filtering and prevent atlas-looking pixel blocks.
	if icon_rect != null:
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# Ensure we scale DOWN to fit the frame (do not request the texture's native size).
		# This is the key fix for "only a quarter of the image shows".
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Ensure child visuals never eat clicks/drags
	if icon_rect != null:
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_frame != null:
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Ensure hint label never eats clicks/drags
	if hint_label != null:
		hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lock_badge != null:
		lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lock_border != null:
		lock_border.mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(host: Node, k: int, idx: int, hint_text: String = "") -> void:
	# Called by InventoryStash while building grids.
	_host = host
	kind = k
	slot_index = idx
	if hint_label != null:
		hint_label.text = hint_text
	# setup can be called before ready in some flows; keep it safe.

func set_item(inst: ItemInstance, marked_for_sale: bool) -> void:
	if badge != null:
		badge.text = "SELL" if marked_for_sale else ""

	var is_locked: bool = inst != null and inst.locked
	if lock_badge != null:
		lock_badge.visible = is_locked
	if lock_border != null:
		lock_border.visible = is_locked

	if inst == null or inst.data == null:
		if icon_rect != null:
			icon_rect.texture = null
		if _set_emblem != null:
			_set_emblem.configure(&"")
		if _manifest_badge != null:
			_manifest_badge.visible = false
		return

	if _manifest_badge != null:
		_manifest_badge.show_for_item(inst)

	if icon_rect != null:
		# ItemData.icon is a Texture2D in this project.
		icon_rect.texture = inst.data.icon
	if _set_emblem != null:
		_set_emblem.configure(StringName(inst.data.set_id))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.ctrl_pressed:
					_drag_armed = false
					if _host != null and _host.has_method("toggle_item_lock"):
						_host.call("toggle_item_lock", kind, slot_index)
					accept_event()
					return
				if mb.shift_pressed:
					_drag_armed = false
					if _host != null and _host.has_method("toggle_sale_mark"):
						_host.call("toggle_sale_mark", kind, slot_index)
					accept_event()
					return
				if mb.double_click:
					_drag_armed = false
					if _host != null and _host.has_method("on_slot_doubleclick"):
						_host.call("on_slot_doubleclick", kind, slot_index)
					accept_event()
					return
				_drag_armed = true
				_drag_start = mb.position
				accept_event()
				return
			_drag_armed = false
			return
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_drag_armed = false
			if _host != null and _host.has_method("on_slot_rightclick"):
				_host.call("on_slot_rightclick", kind, slot_index)
			accept_event()
			return

	if event is InputEventMouseMotion and _drag_armed:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_drag_armed = false
			return
		if _drag_start.distance_to(mm.position) < _DRAG_THRESHOLD_PX:
			return
		_drag_armed = false

		if _host == null or not _host.has_method("get_item_at"):
			return
		var inst: ItemInstance = _host.call("get_item_at", kind, slot_index)
		if inst == null or inst.data == null or inst.locked:
			return

		var payload: Dictionary = {"kind": kind, "idx": slot_index}
		var pv: Control = null
		if icon_rect != null and icon_rect.texture != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture = icon_rect.texture
			tex_rect.custom_minimum_size = Vector2(48, 48)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			pv = tex_rect

		force_drag(payload, pv)
		accept_event()

# Godot 4 drag/drop virtuals:
func _get_drag_data(_pos: Vector2) -> Variant:
	if _host == null or not _host.has_method("get_item_at"):
		return null
	var inst: ItemInstance = _host.call("get_item_at", kind, slot_index)
	if inst == null or inst.data == null or inst.locked:
		return null

	var payload: Dictionary = {"kind": kind, "idx": slot_index}

	# Drag preview
	if icon_rect != null and icon_rect.texture != null:
		var pv := TextureRect.new()
		pv.texture = icon_rect.texture
		pv.custom_minimum_size = Vector2(48, 48)
		pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pv.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		set_drag_preview(pv)

	return payload

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if _host == null or not (data is Dictionary):
		return false
	if _host.has_method("can_drop_item"):
		return bool(_host.call("can_drop_item", data, kind, slot_index))
	return true

func _drop_data(_pos: Vector2, data: Variant) -> void:
	if _host == null or not (data is Dictionary):
		return
	if _host.has_method("handle_drop_item"):
		_host.call("handle_drop_item", data, kind, slot_index)
