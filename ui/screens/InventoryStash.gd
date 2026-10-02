extends CanvasLayer
class_name InventoryStash

signal closed

var _bag_slots_built: int = 0
var _bag_check_t: float = 0.0

const SLOT_SCENE: PackedScene = preload("res://ui/widgets/HubItemSlot.tscn")
const ChamberKit := preload("res://ui/widgets/chambers/ChamberKit.gd")
## Slots here are larger than the HUD's; the look is set on these instances
## only (the shared HubItemSlot scene keeps its own).
const SLOT_PX: float = 84.0
const ICON_PX: float = 60.0
const TOOLTIP_MARGIN: float = 8.0
const TOOLTIP_OFFSET: Vector2 = Vector2(16.0, 16.0)

# Slot labels for equipped grid (matches ItemData.EquipSlot indices 0..7)
const EQUIP_HINTS = ["HP", "ARM", "MOVE", "POW", "HST", "LCK", "OFF", "RING"]

@onready var btn_close: Button = $Center/Panel/Margin/VBox/Header/BtnClose
@onready var eq_grid: GridContainer = $Center/Panel/Margin/VBox/Body/Left/EquippedGrid
@onready var bag_scroll: ScrollContainer = $Center/Panel/Margin/VBox/Body/Middle/BagScroll
@onready var bag_grid: GridContainer = $Center/Panel/Margin/VBox/Body/Middle/BagScroll/BagGrid
@onready var stash_scroll: ScrollContainer = $Center/Panel/Margin/VBox/Body/Right/StashScroll
@onready var stash_grid: GridContainer = $Center/Panel/Margin/VBox/Body/Right/StashScroll/StashGrid
@onready var tooltip: ItemTooltip = $Tooltip
@onready var action_footer: Label = $Center/Panel/Margin/VBox/ActionFooter
@onready var _eq_count: Label = get_node_or_null("Center/Panel/Margin/VBox/Body/Left/EqHead/Count") as Label
@onready var _bag_count: Label = get_node_or_null("Center/Panel/Margin/VBox/Body/Middle/BagHead/Count") as Label
@onready var _stash_count: Label = get_node_or_null("Center/Panel/Margin/VBox/Body/Right/StashHead/Count") as Label
var _footer_tw: Tween = null

# Live hover context (refresh tooltip when item changes under cursor).
var _hover_kind: int = -1
var _hover_idx: int = -1
var _hover_inst_id: int = 0

# Fly VFX must live inside this CanvasLayer. Reusing HubShop/HUD's group node
# renders it underneath this layer (135), which made the animation invisible.
@onready var _fly_vfx: UiFlyVfx = get_node_or_null("FlyVfx") as UiFlyVfx

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_close.pressed.connect(_close)
	_dress()
	_build()
	_apply_fixed_columns()
	_refresh()
	_hook_sources()
	_ensure_fly_vfx()
	_play_open()


# ---------------- Presentation (chamber register; no behaviour) ----------------

func _dress() -> void:
	var overlay := get_node_or_null("Overlay") as ColorRect
	var vignette := ChamberKit.vignette_rect()
	add_child(vignette)
	move_child(vignette, overlay.get_index() + 1 if overlay != null else 0)
	var line := Gradient.new()
	line.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	line.colors = PackedColorArray([Color(ChamberKit.GOLD_DIM, 0.0), Color(ChamberKit.GOLD_DIM, 0.6), Color(ChamberKit.GOLD_DIM, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = line
	tex.fill_to = Vector2(0, 1)
	tex.width = 1
	tex.height = 64
	for path in ["Center/Panel/Margin/VBox/Body/Divider", "Center/Panel/Margin/VBox/Body/Divider2"]:
		var divider := get_node_or_null(path) as TextureRect
		if divider != null:
			divider.texture = tex
	for count in [_eq_count, _bag_count, _stash_count]:
		if count != null:
			count.add_theme_color_override("font_color", ChamberKit.GOLD_DIM)
	if action_footer != null:
		action_footer.add_theme_color_override("font_color", ChamberKit.MUTED)
	# The shared item tooltip keeps its fonts and copy; only its box takes the
	# chamber's square gold rule here.
	if tooltip != null:
		# Above the slots' set emblems and lock badges (z 8-21).
		tooltip.z_index = 40
		tooltip.add_theme_stylebox_override("panel", ChamberKit.box(Color(0.03, 0.026, 0.023, 0.97), Color(ChamberKit.GOLD_DIM, 0.95), 1, 0.0, 16))
		var tip_icon := tooltip.get_node_or_null("Margin/VBox/Header/IconFrame") as PanelContainer
		if tip_icon != null:
			tip_icon.add_theme_stylebox_override("panel", ChamberKit.shared(&"art"))


func _play_open() -> void:
	var center := get_node_or_null("Center") as Control
	if center == null:
		return
	var backdrop: Array = []
	for n in [get_node_or_null("Overlay"), get_node_or_null("ChamberVignette")]:
		if n != null:
			backdrop.append(n)
	ChamberKit.open_panel(center, backdrop, 16.0)
	var slots: Array = []
	for grid in [eq_grid, bag_grid, stash_grid]:
		if grid != null:
			slots.append_array(grid.get_children())
	ChamberKit.stagger_in(self, slots, 0.14, 0.012, 40, 0.9)


## The chamber look for one HubItemSlot instance: a square well with a gold
## rule on hover, a larger icon, the small labels in the chamber type, a
## rarity edge and a faint diamond while empty.
func _dress_slot(s: HubItemSlot) -> void:
	if s == null:
		return
	s.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	s.add_theme_stylebox_override("normal", ChamberKit.shared(&"slot"))
	s.add_theme_stylebox_override("disabled", ChamberKit.shared(&"slot"))
	s.add_theme_stylebox_override("hover", ChamberKit.shared(&"slot_hover"))
	s.add_theme_stylebox_override("pressed", ChamberKit.shared(&"slot_pressed"))
	s.add_theme_stylebox_override("hover_pressed", ChamberKit.shared(&"slot_pressed"))
	s.add_theme_stylebox_override("focus", ChamberKit.shared(&"empty"))
	var frame := s.get_node_or_null("IconFrame") as Control
	if frame != null:
		frame.add_theme_stylebox_override("panel", ChamberKit.shared(&"empty"))
		frame.offset_left = -ICON_PX * 0.5
		frame.offset_top = -ICON_PX * 0.5
		frame.offset_right = ICON_PX * 0.5
		frame.offset_bottom = ICON_PX * 0.5
	var hint := s.get_node_or_null("Hint") as Label
	if hint != null:
		ChamberKit.label(hint, &"ArcaneCaption", 10, Color(ChamberKit.GOLD_DIM, 0.85))
		hint.modulate = Color.WHITE
		hint.offset_left = 7.0
		hint.offset_top = 4.0
		hint.offset_right = 60.0
	var sell := s.get_node_or_null("SellBadge") as Label
	if sell != null:
		ChamberKit.label(sell, &"ArcaneCaption", 11, ChamberKit.EMBER)
	var lock_badge := s.get_node_or_null("LockBadge") as Label
	if lock_badge != null:
		ChamberKit.label(lock_badge, &"ArcaneCaption", 10, ChamberKit.GOLD_BRIGHT)
		lock_badge.offset_left = -50.0
		lock_badge.offset_top = 4.0
		lock_badge.offset_right = -6.0
		lock_badge.offset_bottom = 20.0
	var lock_border := s.get_node_or_null("LockBorder") as Panel
	if lock_border != null:
		lock_border.add_theme_stylebox_override("panel", ChamberKit.shared(&"slot_lock"))
	var glow := TextureRect.new()
	glow.name = "ChamberGlow"
	glow.texture = ChamberKit.glow()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = 6.0
	glow.offset_top = 6.0
	glow.offset_right = -6.0
	glow.offset_bottom = -6.0
	glow.visible = false
	s.add_child(glow)
	s.move_child(glow, 0)
	var edge := ColorRect.new()
	edge.name = "ChamberRarity"
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.anchor_left = 0.0
	edge.anchor_top = 1.0
	edge.anchor_right = 1.0
	edge.anchor_bottom = 1.0
	edge.offset_left = 1.0
	edge.offset_top = -3.0
	edge.offset_right = -1.0
	edge.offset_bottom = -1.0
	edge.visible = false
	s.add_child(edge)
	var mark := Control.new()
	mark.name = "ChamberEmpty"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.draw.connect(func() -> void:
		var c := mark.size * 0.5
		var col := Color(ChamberKit.GOLD_DIM, 0.3)
		var r := 6.0
		mark.draw_polyline(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)]), col, 1.0, true)
	)
	s.add_child(mark)
	s.move_child(mark, 1)


## Rarity edge, glow and the empty mark follow the item in the slot.
func _mark_slot(s: HubItemSlot, inst: ItemInstance) -> void:
	if s == null:
		return
	var has_item := inst != null and inst.data != null
	var mark := s.get_node_or_null("ChamberEmpty") as Control
	if mark != null:
		mark.visible = not has_item
	var edge := s.get_node_or_null("ChamberRarity") as ColorRect
	var glow := s.get_node_or_null("ChamberGlow") as TextureRect
	var tint := ChamberKit.rarity_colour(int(inst.rarity)) if has_item else Color(0, 0, 0, 0)
	if has_item and inst.polarity == ItemInstance.Polarity.NEG:
		tint = ChamberKit.DANGER
	var shown := has_item and tint.a > 0.0
	if edge != null:
		edge.visible = shown
		edge.color = Color(tint, 0.85)
	if glow != null:
		glow.visible = shown
		glow.modulate = Color(tint, 0.16)


func _update_counts() -> void:
	if _eq_count != null:
		_eq_count.text = "%d / %d" % [_filled(eq_grid, HubItemSlot.Kind.EQUIPPED), eq_grid.get_child_count()]
	if _bag_count != null:
		_bag_count.text = "%d / %d" % [_filled(bag_grid, HubItemSlot.Kind.BAG), bag_grid.get_child_count()]
	if _stash_count != null:
		_stash_count.text = "%d / %d" % [_filled(stash_grid, HubItemSlot.Kind.STASH), stash_grid.get_child_count()]


func _filled(grid: Control, kind: int) -> int:
	var n := 0
	if grid == null:
		return 0
	for i in range(grid.get_child_count()):
		var inst := get_item_at(kind, i)
		if inst != null and inst.data != null:
			n += 1
	return n



func _ensure_fly_vfx() -> void:
	if _fly_vfx != null and is_instance_valid(_fly_vfx):
		return
	_fly_vfx = get_node_or_null("FlyVfx") as UiFlyVfx
	if _fly_vfx != null:
		return
	# Legacy-scene fallback: keep the VFX in this CanvasLayer, never borrow a
	# lower-layer group member from HubShop/HUD.
	_fly_vfx = UiFlyVfx.new()
	_fly_vfx.name = "FlyVfx"
	add_child(_fly_vfx)

func _ctrl_center(c: Control) -> Vector2:
	if c == null:
		return get_viewport().get_mouse_position()
	var r: Rect2 = c.get_global_rect()
	return r.position + r.size * 0.5

func _slot_ctrl(kind: int, idx: int) -> Control:
	if idx < 0:
		return null
	match kind:
		HubItemSlot.Kind.EQUIPPED:
			return (eq_grid.get_child(idx) as Control) if eq_grid != null and idx < eq_grid.get_child_count() else null
		HubItemSlot.Kind.BAG:
			return (bag_grid.get_child(idx) as Control) if bag_grid != null and idx < bag_grid.get_child_count() else null
		HubItemSlot.Kind.STASH:
			return (stash_grid.get_child(idx) as Control) if stash_grid != null and idx < stash_grid.get_child_count() else null
		_:
			return null

func _refresh_hover_live() -> void:
	if tooltip == null or not tooltip.visible:
		return
	if _hover_kind < 0 or _hover_idx < 0:
		return
	var inst := get_item_at(_hover_kind, _hover_idx)
	var iid: int = (int(inst.get_instance_id()) if (inst is Object and inst != null) else 0)
	if iid != _hover_inst_id:
		_hover_inst_id = iid
		_show_tip(_hover_kind, _hover_idx)

func _hook_sources() -> void:
	# Refresh/rebuild if bag size changes (major choices add extra slots).
	if Global != null and Global.run_bag != null:
		if Global.run_bag.has_signal("changed"):
			# Prevent double-connect
			if not Global.run_bag.changed.is_connected(Callable(self, "_on_bag_changed")):
				Global.run_bag.changed.connect(Callable(self, "_on_bag_changed"))
	# Keep stash changes visible
	if Global != null and Global.meta_stash != null:
		if Global.meta_stash.has_signal("changed"):
			if not Global.meta_stash.changed.is_connected(Callable(self, "_on_stash_changed")):
				Global.meta_stash.changed.connect(Callable(self, "_on_stash_changed"))

func _process(delta: float) -> void:
	# Keep tooltip near mouse when visible + refresh if item changed under cursor (double-click/moves).
	_refresh_hover_live()
	if tooltip != null and tooltip.visible:
		_position_tooltip_near_mouse()
	# Bag size can change via major choices; rebuild grid if needed
	_bag_check_t = maxf(_bag_check_t - delta, 0.0)
	if _bag_check_t <= 0.0:
		_bag_check_t = 0.45
		_rebuild_bag_if_needed()

func _apply_fixed_columns() -> void:
	# Fixed layout: bag=4 columns, stash=6 columns. Slot count can still grow; scroll handles overflow.
	if bag_grid != null:
		bag_grid.columns = 4
	if stash_grid != null:
		stash_grid.columns = 6


func _close() -> void:
	closed.emit()
	queue_free()

func _clear_grid(g: Control) -> void:
	for c in g.get_children():
		c.queue_free()

func _build() -> void:
	_clear_grid(eq_grid)
	_clear_grid(bag_grid)
	_clear_grid(stash_grid)

	if Global == null:
		return

	if Global.meta_stash == null:
		Global.meta_stash = StashInventory.new()

	# Equipped: fixed slot count
	if Global.run_inventory != null:
		for i in range(Inventory.SLOT_COUNT):
			var s := SLOT_SCENE.instantiate() as HubItemSlot
			var slot_i: int = i
			s.mouse_entered.connect(func() -> void: _show_tip(HubItemSlot.Kind.EQUIPPED, slot_i))
			s.mouse_exited.connect(_hide_tip)
			eq_grid.add_child(s)
			var hint_txt: String = (String(EQUIP_HINTS[i]) if i >= 0 and i < EQUIP_HINTS.size() else str(i))
			s.setup(self, HubItemSlot.Kind.EQUIPPED, i, hint_txt)
			_dress_slot(s)

	# Bag: dynamic slot count (base + extra)
	if Global.run_bag != null and Global.run_bag.has_method("get_slot_count"):
		var n: int = int(Global.run_bag.call("get_slot_count"))
		for i in range(n):
			var s2 := SLOT_SCENE.instantiate() as HubItemSlot
			var slot_i: int = i
			s2.mouse_entered.connect(func() -> void: _show_tip(HubItemSlot.Kind.BAG, slot_i))
			s2.mouse_exited.connect(_hide_tip)
			bag_grid.add_child(s2)
			s2.setup(self, HubItemSlot.Kind.BAG, i)
			_dress_slot(s2)
		_bag_slots_built = n

	# Stash: persistent fixed count
	for i in range(Global.meta_stash.slot_count):
		var s3 := SLOT_SCENE.instantiate() as HubItemSlot
		var slot_i: int = i
		s3.mouse_entered.connect(func() -> void: _show_tip(HubItemSlot.Kind.STASH, slot_i))
		s3.mouse_exited.connect(_hide_tip)
		stash_grid.add_child(s3)
		s3.setup(self, HubItemSlot.Kind.STASH, i)
		_dress_slot(s3)


func _refresh() -> void:
	if Global == null:
		return

	# Equipped
	for i in range(eq_grid.get_child_count()):
		var b := eq_grid.get_child(i) as HubItemSlot
		var inst := get_item_at(HubItemSlot.Kind.EQUIPPED, i)
		b.set_item(inst, false)
		_mark_slot(b, inst)

	# Bag
	for i in range(bag_grid.get_child_count()):
		var b2 := bag_grid.get_child(i) as HubItemSlot
		var inst2 := get_item_at(HubItemSlot.Kind.BAG, i)
		var marked: bool = Global.is_hub_sell_marked(&"bag", i)
		b2.set_item(inst2, marked)
		_mark_slot(b2, inst2)

	# Stash
	for i in range(stash_grid.get_child_count()):
		var b3 := stash_grid.get_child(i) as HubItemSlot
		var inst3 := get_item_at(HubItemSlot.Kind.STASH, i)
		var marked3: bool = Global.is_hub_sell_marked(&"stash", i)
		b3.set_item(inst3, marked3)
		_mark_slot(b3, inst3)

	_update_counts()

# ---------------- Host API for HubItemSlot ----------------

func get_item_at(kind: int, idx: int) -> ItemInstance:
	if Global == null:
		return null
	if kind == HubItemSlot.Kind.EQUIPPED:
		return Global.run_inventory.get_at(idx) if Global.run_inventory != null else null
	if kind == HubItemSlot.Kind.BAG:
		return Global.run_bag.get_at(idx) if Global.run_bag != null else null
	if kind == HubItemSlot.Kind.STASH:
		return Global.meta_stash.get_at(idx) if Global.meta_stash != null else null
	return null

func _set_action_status(message: String) -> void:
	if action_footer != null:
		action_footer.text = message
		# The footer answers each action with a brief warm flash.
		if _footer_tw != null and _footer_tw.is_running():
			_footer_tw.kill()
		if ChamberKit.reduced() or not is_inside_tree():
			return
		action_footer.modulate = Color(1.35, 1.2, 0.95, 1.0)
		_footer_tw = ChamberKit.tween(action_footer)
		_footer_tw.tween_property(action_footer, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)

func toggle_item_lock(kind: int, idx: int) -> void:
	var inst: ItemInstance = get_item_at(kind, idx)
	if inst == null:
		return
	inst.toggle_locked()
	if inst.locked and Global != null:
		if kind == HubItemSlot.Kind.BAG:
			Global.hub_sell_marks_bag.erase(idx)
		elif kind == HubItemSlot.Kind.STASH:
			Global.hub_sell_marks_stash.erase(idx)
	_set_action_status("LOCKED · Protected from trade, movement, replacement and duplicate cleanup." if inst.locked else "UNLOCKED · Item actions restored.")
	_refresh()
	Global.save_current_profile()

func toggle_sale_mark(kind: int, idx: int) -> void:
	if Global == null:
		return
	var inst: ItemInstance = get_item_at(kind, idx)
	if inst == null:
		return
	if inst.locked:
		_set_action_status("ITEM LOCKED · Ctrl-click to unlock before trading.")
		return
	if kind == HubItemSlot.Kind.BAG:
		Global.toggle_hub_sell_mark(&"bag", idx)
	elif kind == HubItemSlot.Kind.STASH:
		Global.toggle_hub_sell_mark(&"stash", idx)
	else:
		_set_action_status("Equipped items are traded from the main exchange screen.")
		return
	_set_action_status("Shift-click Trade · Ctrl-click Lock · Right-click Move · Double-click Equip")
	_refresh()

func on_slot_rightclick(kind: int, idx: int) -> void:
	match kind:
		HubItemSlot.Kind.EQUIPPED:
			_move_to_first_empty(kind, idx, HubItemSlot.Kind.BAG)
		HubItemSlot.Kind.BAG:
			_move_to_first_empty(kind, idx, HubItemSlot.Kind.STASH)
		HubItemSlot.Kind.STASH:
			_move_to_first_empty(kind, idx, HubItemSlot.Kind.BAG)

func _move_to_first_empty(src_kind: int, src_idx: int, dst_kind: int) -> bool:
	if Global == null or InvRouter == null:
		return false
	var inst: ItemInstance = get_item_at(src_kind, src_idx)
	if inst == null:
		return false
	if inst.locked:
		_set_action_status("ITEM LOCKED · Ctrl-click to unlock before moving it.")
		return false
	var src_inv: Object = _inv_for_kind(src_kind)
	var dst_inv: Object = _inv_for_kind(dst_kind)
	if src_inv == null or dst_inv == null or not dst_inv.has_method("first_empty_slot"):
		return false
	var dst_idx: int = int(dst_inv.call("first_empty_slot"))
	if dst_idx < 0:
		_set_action_status("NO EMPTY DESTINATION SLOT")
		return false
	var src_ctrl := _slot_ctrl(src_kind, src_idx)
	var dst_ctrl := _slot_ctrl(dst_kind, dst_idx)
	_ensure_fly_vfx()
	if _fly_vfx != null and src_ctrl != null and dst_ctrl != null:
		_fly_vfx.fly_to(dst_ctrl, inst, _ctrl_center(src_ctrl), false)
	var moved: bool = InvRouter.move_between(src_inv, src_idx, dst_inv, dst_idx, null)
	if moved:
		_set_action_status("ITEM MOVED")
		_refresh()
		_refresh_hover_live()
		Global.save_current_profile()
	return moved

func can_drop_item(data: Dictionary, dst_kind: int, dst_idx: int) -> bool:
	if not data.has("kind") or not data.has("idx"):
		return false
	var src_kind: int = int(data["kind"])
	var src_idx: int = int(data["idx"])
	# forbid dropping onto itself
	if src_kind == dst_kind and src_idx == dst_idx:
		return false

	var inst: ItemInstance = get_item_at(src_kind, src_idx)
	if inst == null or inst.data == null or inst.locked:
		return false
	var dst_inst: ItemInstance = get_item_at(dst_kind, dst_idx)
	if dst_inst != null and dst_inst.locked:
		return false

	# Equipped: allow dropping FROM bag/stash onto ANY equipped slot.
	# We'll auto-route to the item's correct equip slot on drop.
	if dst_kind == HubItemSlot.Kind.EQUIPPED:
		# Don't allow dragging between equipped slots.
		if src_kind == HubItemSlot.Kind.EQUIPPED:
			return false
		return int(inst.data.equip_slot) >= 0

	# Bag/Stash accept anything.
	return true

func handle_drop_item(data: Dictionary, dst_kind: int, dst_idx: int) -> void:
	if Global == null:
		return
	if not data.has("kind") or not data.has("idx"):
		return

	var src_kind: int = int(data["kind"])
	var src_idx: int = int(data["idx"])

	# If dropping onto Equipped, always route to the item's own equip slot.
	if dst_kind == HubItemSlot.Kind.EQUIPPED:
		var inst0: ItemInstance = get_item_at(src_kind, src_idx)
		if inst0 == null or inst0.data == null:
			return
		var es0: int = int(inst0.data.equip_slot)
		if es0 < 0:
			return
		dst_idx = es0

	# Extra safety: validate equip-slot
	if dst_kind == HubItemSlot.Kind.EQUIPPED:
		var inst_chk: ItemInstance = get_item_at(src_kind, src_idx)
		if inst_chk == null or inst_chk.data == null:
			return
		if int(inst_chk.data.equip_slot) != dst_idx:
			return

	var src_inv: Object = _inv_for_kind(src_kind)
	var dst_inv: Object = _inv_for_kind(dst_kind)
	if src_inv == null or dst_inv == null:
		return

	# VFX: fly dragged item from source slot -> destination slot
	_ensure_fly_vfx()
	var inst_fx: ItemInstance = get_item_at(src_kind, src_idx)
	var src_ctrl := _slot_ctrl(src_kind, src_idx)
	var dst_ctrl := _slot_ctrl(dst_kind, dst_idx)
	if _fly_vfx != null and inst_fx != null and src_ctrl != null and dst_ctrl != null:
		_fly_vfx.fly_to(dst_ctrl, inst_fx, _ctrl_center(src_ctrl), false)

	# Use InventoryRouter for consistent swap behavior.
	if InvRouter != null and InvRouter.has_method("move_between"):
		InvRouter.move_between(src_inv, src_idx, dst_inv, dst_idx, null)
	else:
		# Fallback swap
		var a: ItemInstance = get_item_at(src_kind, src_idx)
		var b: ItemInstance = get_item_at(dst_kind, dst_idx)
		_set_item(dst_kind, dst_idx, a)
		_remove_at(src_kind, src_idx)
		if b != null:
			_set_item(src_kind, src_idx, b)

	_refresh()
	_refresh_hover_live()
	Global.save_current_profile()

func _inv_for_kind(kind: int) -> Object:
	if Global == null:
		return null
	if kind == HubItemSlot.Kind.EQUIPPED:
		return Global.run_inventory
	if kind == HubItemSlot.Kind.BAG:
		return Global.run_bag
	if kind == HubItemSlot.Kind.STASH:
		return Global.meta_stash
	return null

func _set_item(kind: int, idx: int, inst: ItemInstance) -> void:
	if Global == null:
		return
	if kind == HubItemSlot.Kind.EQUIPPED:
		if Global.run_inventory != null:
			Global.run_inventory.set_item(idx, inst, {"player_driven": true})
	elif kind == HubItemSlot.Kind.BAG:
		if Global.run_bag != null:
			Global.run_bag.set_item(idx, inst)
	elif kind == HubItemSlot.Kind.STASH:
		if Global.meta_stash == null:
			Global.meta_stash = StashInventory.new()
		Global.meta_stash.set_item(idx, inst, null)

func _remove_at(kind: int, idx: int) -> void:
	if Global == null:
		return
	if kind == HubItemSlot.Kind.EQUIPPED:
		if Global.run_inventory != null:
			Global.run_inventory.remove_at(idx, {"player_driven": true})
	elif kind == HubItemSlot.Kind.BAG:
		if Global.run_bag != null:
			Global.run_bag.remove_at(idx)
	elif kind == HubItemSlot.Kind.STASH:
		if Global.meta_stash != null:
			Global.meta_stash.remove_at(idx)

# ---------------- Tooltip ----------------

func _position_tooltip_near_mouse() -> void:
	if tooltip == null or not tooltip.visible:
		return

	# Establish the wrapped layout before measuring it. The tooltip keeps its
	# normal font size; only its position changes when an edge would clip it.
	var width: float = maxf(460.0, tooltip.custom_minimum_size.x)
	tooltip.size = Vector2(width, 0.0)
	tooltip.reset_size()
	var minimum: Vector2 = tooltip.get_combined_minimum_size()
	if minimum.x > 0.0 and minimum.y > 0.0:
		tooltip.size = Vector2(maxf(width, minimum.x), minimum.y)

	var mouse: Vector2 = get_viewport().get_mouse_position()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var out: Vector2 = mouse + TOOLTIP_OFFSET

	# Prefer the opposite side of the cursor before clamping to the screen.
	if out.x + tooltip.size.x > screen.x - TOOLTIP_MARGIN:
		out.x = mouse.x - tooltip.size.x - TOOLTIP_OFFSET.x
	if out.y + tooltip.size.y > screen.y - TOOLTIP_MARGIN:
		out.y = mouse.y - tooltip.size.y - TOOLTIP_OFFSET.y

	out.x = clampf(out.x, TOOLTIP_MARGIN, maxf(TOOLTIP_MARGIN, screen.x - tooltip.size.x - TOOLTIP_MARGIN))
	out.y = clampf(out.y, TOOLTIP_MARGIN, maxf(TOOLTIP_MARGIN, screen.y - tooltip.size.y - TOOLTIP_MARGIN))
	tooltip.global_position = out

func _show_tip(kind: int, idx: int) -> void:
	_hover_kind = kind
	_hover_idx = idx
	if tooltip == null:
		return
	var inst := get_item_at(kind, idx)
	if inst == null or inst.data == null:
		_hover_inst_id = 0
		tooltip.hide_tooltip()
		return
	_hover_inst_id = (int(inst.get_instance_id()) if (inst is Object) else 0)
	tooltip.show_item(inst)
	tooltip.visible = true
	call_deferred("_position_tooltip_near_mouse")

func _hide_tip() -> void:
	_hover_kind = -1
	_hover_idx = -1
	_hover_inst_id = 0
	if tooltip != null:
		tooltip.hide_tooltip()

func _on_bag_changed() -> void:
	_rebuild_bag_if_needed()
	_refresh()

func _on_stash_changed() -> void:
	_refresh()

func _rebuild_bag_if_needed() -> void:
	if Global == null or Global.run_bag == null:
		return
	if not Global.run_bag.has_method("get_slot_count"):
		return
	var want: int = int(Global.run_bag.call("get_slot_count"))
	if want == _bag_slots_built and bag_grid.get_child_count() == want:
		return

	# rebuild bag grid (supports extra slots)
	_clear_grid(bag_grid)
	for i in range(want):
		var s2 := SLOT_SCENE.instantiate() as HubItemSlot
		var slot_i: int = i
		s2.mouse_entered.connect(func() -> void: _show_tip(HubItemSlot.Kind.BAG, slot_i))
		s2.mouse_exited.connect(_hide_tip)
		bag_grid.add_child(s2)
		s2.setup(self, HubItemSlot.Kind.BAG, i)
		_dress_slot(s2)
	_bag_slots_built = want

func on_slot_doubleclick(kind: int, idx: int) -> void:
	if Global == null:
		return
	if InvRouter == null:
		return
	var clicked_inst: ItemInstance = get_item_at(kind, idx)
	if clicked_inst == null:
		return
	if clicked_inst.locked:
		_set_action_status("ITEM LOCKED · Ctrl-click to unlock before equipping or unequipping.")
		return

	_ensure_fly_vfx()

	# Equipped -> Bag (first empty)
	if kind == HubItemSlot.Kind.EQUIPPED:
		if Global.run_bag == null or not Global.run_bag.has_method("first_empty_slot"):
			return
		var inst_e: ItemInstance = Global.run_inventory.get_at(idx) if Global.run_inventory != null else null
		var dst_i: int = int(Global.run_bag.call("first_empty_slot"))
		if inst_e == null or dst_i < 0:
			return
		var src_ctrl := _slot_ctrl(kind, idx)
		var dst_ctrl := _slot_ctrl(HubItemSlot.Kind.BAG, dst_i)
		if _fly_vfx != null and src_ctrl != null and dst_ctrl != null:
			_fly_vfx.fly_to(dst_ctrl, inst_e, _ctrl_center(src_ctrl), false)
		if InvRouter.move_between(Global.run_inventory, idx, Global.run_bag, dst_i, null):
			_set_action_status("ITEM MOVED TO BACKPACK")
			_refresh()
			_refresh_hover_live()
			Global.save_current_profile()
		return

	# Stash -> Bag (first empty)
	if kind == HubItemSlot.Kind.STASH:
		if Global.run_bag == null or not Global.run_bag.has_method("first_empty_slot"):
			return
		var inst_s: ItemInstance = Global.meta_stash.get_at(idx) if Global.meta_stash != null else null
		var dst_s: int = int(Global.run_bag.call("first_empty_slot"))
		if inst_s == null or dst_s < 0:
			return
		var src_ctrl2 := _slot_ctrl(kind, idx)
		var dst_ctrl2 := _slot_ctrl(HubItemSlot.Kind.BAG, dst_s)
		if _fly_vfx != null and src_ctrl2 != null and dst_ctrl2 != null:
			_fly_vfx.fly_to(dst_ctrl2, inst_s, _ctrl_center(src_ctrl2), false)
		if InvRouter.move_between(Global.meta_stash, idx, Global.run_bag, dst_s, null):
			_set_action_status("ITEM MOVED TO BACKPACK")
			_refresh()
			_refresh_hover_live()
			Global.save_current_profile()
		return

	# Bag -> Equipped (equip slot)
	if kind == HubItemSlot.Kind.BAG:
		if Global.run_bag == null:
			return
		var inst_b: ItemInstance = Global.run_bag.get_at(idx)
		if inst_b == null or inst_b.data == null:
			return
		var es: int = int(inst_b.data.equip_slot)
		if es < 0:
			return
		var equipped_now: ItemInstance = Global.run_inventory.get_at(es) if Global.run_inventory != null else null
		if equipped_now != null and equipped_now.locked:
			_set_action_status("EQUIPPED ITEM LOCKED · Unlock it before replacement.")
			return
		var src_ctrl3 := _slot_ctrl(kind, idx)
		var dst_ctrl3 := _slot_ctrl(HubItemSlot.Kind.EQUIPPED, es)
		if _fly_vfx != null and src_ctrl3 != null and dst_ctrl3 != null:
			_fly_vfx.fly_to(dst_ctrl3, inst_b, _ctrl_center(src_ctrl3), false)
		if InvRouter.move_between(Global.run_bag, idx, Global.run_inventory, es, null):
			_set_action_status("ITEM EQUIPPED")
			_refresh()
			_refresh_hover_live()
			Global.save_current_profile()
		return
