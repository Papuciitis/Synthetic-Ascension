extends Control

# HUD is intentionally "thin": it binds player/inventory and delegates specialized
# overlay behaviour (tutorial tips, gate arrow/popup) to dedicated controllers.

@onready var top_left: PanelContainer = get_node_or_null("TopLeft") as PanelContainer
@onready var fly_vfx: UiFlyVfx = get_node_or_null("FlyVfx") as UiFlyVfx

# Controllers (placed in HUD.tscn)
@onready var bag_ctl: HudBagController = get_node_or_null("BagController") as HudBagController
@onready var tip_ctl: HudTooltipController = get_node_or_null("TooltipController") as HudTooltipController
@onready var gate_overlay_ctl: HudGateOverlayController = get_node_or_null("GateOverlayController") as HudGateOverlayController
@onready var tutorial_tip_ctl: HudTutorialTipController = get_node_or_null("TutorialTipController") as HudTutorialTipController

# Ability HUDs (Conduit set ability in the middle)
@onready var ability_hud_r: Node = get_node_or_null("ActiveAbilityHud_R")

# Augments panel
@onready var aug_panel: Node = get_node_or_null("TopLeft/Margin/VBox/BodyRow/AugmentsPanel")

# HP
@onready var hp_bar: ProgressBar = get_node_or_null("TopLeft/Margin/VBox/TopRow/HPRow/HPBar") as ProgressBar
@onready var hp_value: Label = get_node_or_null("TopLeft/Margin/VBox/TopRow/HPRow/HPBar/HPValue") as Label
@onready var hp_percent: Label = get_node_or_null("TopLeft/Margin/VBox/TopRow/HPRow/HPPercent") as Label

# Followers
@onready var followers_label: Label = get_node_or_null("TopLeft/Margin/VBox/Row2/FollowersPill/Margin/FollowersRow/FollowersValue") as Label
@onready var followers_pill: Control = get_node_or_null("TopLeft/Margin/VBox/Row2/FollowersPill") as Control

# Inventory bar instance
@onready var inv_bar: InventoryBar = get_node_or_null("TopLeft/Margin/VBox/BodyRow/InventoryBar") as InventoryBar

@export var manage_toggle_action: StringName = &"bag_toggle"
@onready var run_sheet: Control = get_node_or_null("RunSheetHUD") as Control

@export var augment_badge_scene: PackedScene

var _rs_tick: float = 0.0
var _sb_top_left: StyleBoxFlat = null

# Augments fallback: slots in group "augment_slot"
var _augment_slots: Array[Control] = []

var _router: InventoryRouter = null
var _bound_inv: Inventory = null
var _bound_bag: BagInventory = null
var _bound_player: Node = null


func _enter_tree() -> void:
	_hook_run_events()


func _ready() -> void:
	_router = get_node_or_null("/root/InvRouter") as InventoryRouter
	if _router == null:
		push_warning("[HUD] InvRouter autoload not found at /root/InvRouter")

	_force_fly_vfx_on_top()

	# Give InventoryBar the FlyVfx reference directly (prevents timing/group issues)
	if inv_bar != null and fly_vfx != null and inv_bar.has_method("set_fly_vfx"):
		inv_bar.call("set_fly_vfx", fly_vfx)

	if hp_bar != null:
		hp_bar.show_percentage = false
	_style_hp_bar()

	_apply_top_left_style()

	# BagController -> HUD
	if bag_ctl != null:
		if not bag_ctl.management_mode_changed.is_connected(_on_management_mode_changed):
			bag_ctl.management_mode_changed.connect(_on_management_mode_changed)
	else:
		push_warning("[HUD] BagController missing (HudBagController)")

	if tip_ctl == null:
		push_warning("[HUD] TooltipController missing (HudTooltipController)")

	if gate_overlay_ctl == null:
		push_warning("[HUD] GateOverlayController missing. Gate arrow/popup may not work.")
	if tutorial_tip_ctl == null:
		push_warning("[HUD] TutorialTipController missing. Tutorial tips may not work.")

	if ability_hud_r == null:
		push_warning("[HUD] ActiveAbilityHud_R node missing (conduit abilities may not work).")

	if run_sheet != null:
		run_sheet.visible = false
		call_deferred("_position_run_sheet_under_top_left")

	call_deferred("_cache_augment_slots")
	set_process(true)


func _hook_run_events() -> void:
	# Keep HUD-level signals minimal; other overlay behaviour lives in controllers.
	if RunEvents != null and RunEvents.has_signal("pickup_fly_to_equip"):
		var cb := Callable(self, "_on_pickup_fly_to_equip")
		if not RunEvents.pickup_fly_to_equip.is_connected(cb):
			RunEvents.pickup_fly_to_equip.connect(cb)


func _force_fly_vfx_on_top() -> void:
	if fly_vfx == null:
		return
	if fly_vfx.get_parent() == self:
		move_child(fly_vfx, get_child_count() - 1)
	fly_vfx.z_index = 999
	fly_vfx.z_as_relative = false


func _style_hp_bar() -> void:
	if hp_bar == null:
		return

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.30)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	hp_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.55, 0.20, 0.95)
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	hp_bar.add_theme_stylebox_override("fill", fill)
	hp_bar.add_theme_stylebox_override("fg", fill)


func _process(delta: float) -> void:
	_rs_tick += delta
	if _rs_tick >= 0.10:
		_rs_tick = 0.0
		_refresh_run_sheet()
	# Gate arrow/popup are handled by HudGateOverlayController.


func _refresh_run_sheet() -> void:
	if run_sheet == null:
		return
	var p := get_tree().get_first_node_in_group("player")
	if run_sheet.has_method("refresh"):
		run_sheet.call("refresh", p, Global.run_inventory as Inventory)


func _position_run_sheet_under_top_left() -> void:
	if run_sheet == null or top_left == null:
		return
	run_sheet.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	var r: Rect2 = top_left.get_global_rect()
	run_sheet.position = Vector2(r.position.x, r.position.y + r.size.y + 8.0)


# ----------------------------
# Bindings
# ----------------------------

func bind_player(player: Node) -> void:
	_bound_player = player
	if player == null:
		return

	if player.has_signal("hp_changed"):
		if not player.hp_changed.is_connected(_on_hp_changed):
			player.hp_changed.connect(_on_hp_changed)

	var cur: Variant = player.get("hp")
	var mx: Variant = player.get("max_hp")
	if (cur is float or cur is int) and (mx is float or mx is int):
		_on_hp_changed(float(cur), float(mx))

	# Augments UI sync (persist across death)
	if Global != null and Global.has_signal("permanent_augments_changed"):
		var cb := Callable(self, "_on_permanent_augments_changed")
		if not Global.permanent_augments_changed.is_connected(cb):
			Global.permanent_augments_changed.connect(cb)

	# initial paint
	_on_permanent_augments_changed(Global.permanent_augment_ids)

	_bind_ability_huds_player(player)


func bind_inventory(inv: Inventory) -> void:
	# If we were previously bound, unhook signals to avoid duplicates
	if _bound_inv != null and is_instance_valid(_bound_inv):
		if _bound_inv.changed.is_connected(_refresh_run_sheet):
			_bound_inv.changed.disconnect(_refresh_run_sheet)
		if _bound_inv.changed.is_connected(_on_inventory_changed):
			_bound_inv.changed.disconnect(_on_inventory_changed)

	_bound_inv = inv

	if inv_bar != null:
		inv_bar.bind_inventory(inv)

	if bag_ctl != null:
		bag_ctl.bind_core_inventory(inv)

	if inv != null and run_sheet != null:
		if not inv.changed.is_connected(_refresh_run_sheet):
			inv.changed.connect(_refresh_run_sheet)

	if inv != null:
		if not inv.changed.is_connected(_on_inventory_changed):
			inv.changed.connect(_on_inventory_changed)
		_on_inventory_changed()

	_bind_ability_huds_inventory(inv)
	_try_bind_router()


func bind_bag(bag: BagInventory) -> void:
	_bound_bag = bag

	if bag_ctl != null:
		bag_ctl.bind_bag(bag)
	else:
		push_warning("[HUD] bind_bag(): BagController missing.")

	_try_bind_router()


func _try_bind_router() -> void:
	if _router == null:
		return
	if _bound_inv != null:
		_router.bind_equipped(_bound_inv)
	if _bound_bag != null:
		_router.bind_bag(_bound_bag)


func _on_inventory_changed() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return

	var sr := p.get_node_or_null("SetRunner")
	if sr != null and sr.has_method("refresh_effects"):
		sr.call("refresh_effects", _bound_inv)

	var ar := p.get_node_or_null("AugmentRunner")
	if ar != null and ar.has_method("refresh"):
		ar.call("refresh")


# ----------------------------
# Input
# ----------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(manage_toggle_action):
		if bag_ctl != null:
			bag_ctl.toggle_bag_open()
		get_viewport().set_input_as_handled()


# ----------------------------
# BagController event
# ----------------------------

func _on_management_mode_changed(is_open: bool) -> void:
	if run_sheet != null:
		run_sheet.visible = is_open
		if is_open:
			_position_run_sheet_under_top_left()

	if tip_ctl != null and tip_ctl.has_method("set_management_mode"):
		tip_ctl.call("set_management_mode", is_open)

	_set_ability_huds_enabled(not is_open)


func _set_ability_huds_enabled(enabled: bool) -> void:
	var arr: Array[Node] = [ability_hud_r]
	for n: Node in arr:
		if n == null:
			continue
		if n.has_method("set_enabled"):
			n.call("set_enabled", enabled)
		elif n.has_method("set_active"):
			n.call("set_active", enabled)


# ----------------------------
# Pickup fly-to-equip
# ----------------------------

func _on_pickup_fly_to_equip(start_global: Vector2, equip_slot: int, inst: ItemInstance, upgraded: bool, _extra: Variant = null) -> void:
	if fly_vfx == null or inst == null:
		return

	var target: Control = null
	if inv_bar != null and inv_bar.has_method("get_slot_control"):
		target = inv_bar.call("get_slot_control", equip_slot) as Control
	if target == null and inv_bar is Control:
		target = inv_bar as Control

	if target != null:
		fly_vfx.fly_to(target, inst, start_global, upgraded)


# -----------------------------
# Ability HUD binding
# -----------------------------

func _bind_ability_huds_player(player: Node) -> void:
	var arr: Array[Node] = [ability_hud_r]
	for n: Node in arr:
		if n == null:
			continue
		if n.has_method("bind_player"):
			n.call("bind_player", player)
		elif n.has_method("set_player"):
			n.call("set_player", player)


func _bind_ability_huds_inventory(inv: Inventory) -> void:
	var arr: Array[Node] = [ability_hud_r]
	for n: Node in arr:
		if n == null:
			continue
		if n.has_method("bind_inventory"):
			n.call("bind_inventory", inv)
		elif n.has_method("set_inventory"):
			n.call("set_inventory", inv)
		elif n.has_method("bind"):
			n.call("bind", inv)


# -----------------------------
# Augments
# -----------------------------

func _on_permanent_augments_changed(ids: Array) -> void:
	if aug_panel == null or not aug_panel.has_method("set_augments"):
		return

	var out: Array = []
	for i in range(3):
		var id := StringName()
		if i < ids.size():
			id = ids[i] as StringName

		if id == StringName() or String(id) == "":
			out.append(null)
		else:
			var a = Global.augment_db.get(id, null)
			out.append(a)

	aug_panel.call("set_augments", out)


func _cache_augment_slots() -> void:
	_augment_slots.clear()

	var nodes: Array[Node] = get_tree().get_nodes_in_group("augment_slot")
	for n: Node in nodes:
		var c: Control = n as Control
		if c != null:
			_augment_slots.append(c)

	_augment_slots.sort_custom(func(a: Control, b: Control) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)


func add_augment_to_next_slot(a: AugmentData) -> void:
	if a == null:
		return

	# Prevent duplicates: AugmentSelect already writes into Global.permanent_augment_ids; HUD will refresh from Global.
	if Global != null:
		for id in Global.permanent_augment_ids:
			if id == a.id:
				return


	if aug_panel != null and aug_panel.has_method("get_first_empty_slot") and aug_panel.has_method("set_slot"):
		var idx: int = int(aug_panel.call("get_first_empty_slot"))
		if idx == -1:
			# All full -> mirror AugmentSelect behavior: overwrite slot 0.
			idx = 0
		aug_panel.call("set_slot", idx, a)
		return

	if _augment_slots.is_empty():
		_cache_augment_slots()

	var slot: Control = null
	for s: Control in _augment_slots:
		var existing: String = String(s.get_meta("augment_id", ""))
		if existing == "":
			slot = s
			break

	if slot == null:
		# All full -> overwrite first slot (mirrors AugmentSelect).
		if _augment_slots.size() > 0:
			slot = _augment_slots[0]
		else:
			return

	_set_slot_augment(slot, a)

func _set_slot_augment(slot: Control, a: AugmentData) -> void:
	slot.set_meta("augment_id", a.id)

	if slot.has_method("set_augment"):
		slot.call("set_augment", a)
		return
	if slot.has_method("set_data"):
		slot.call("set_data", a)
		return

	var texrect: TextureRect = slot as TextureRect
	if texrect != null:
		texrect.texture = a.icon
		return

	var icon_rect: TextureRect = slot.find_child("Icon", true, false) as TextureRect
	if icon_rect != null:
		icon_rect.texture = a.icon

	slot.tooltip_text = a.display_name


# ----------------------------
# Top-left styling
# ----------------------------

func _apply_top_left_style() -> void:
	if top_left == null:
		return

	_sb_top_left = StyleBoxFlat.new()
	_sb_top_left.bg_color = Color(0, 0, 0, 0.35)
	_sb_top_left.border_color = Color(0.12, 0.12, 0.12, 1.0)
	_sb_top_left.set_border_width_all(2)
	_sb_top_left.corner_radius_top_left = 14
	_sb_top_left.corner_radius_top_right = 14
	_sb_top_left.corner_radius_bottom_left = 14
	_sb_top_left.corner_radius_bottom_right = 14
	_sb_top_left.shadow_size = 8
	_sb_top_left.shadow_offset = Vector2(0, 6)
	_sb_top_left.shadow_color = Color(0, 0, 0, 0.30)

	top_left.add_theme_stylebox_override("panel", _sb_top_left)


# ----------------------------
# HP / followers
# ----------------------------

func _on_hp_changed(current: float, max_hp: float) -> void:
	if hp_bar != null:
		hp_bar.max_value = max_hp
		hp_bar.value = current

	if hp_value != null:
		hp_value.text = "%d / %d" % [int(round(current)), int(round(max_hp))]

	if hp_percent != null:
		var pct: int = 0
		if max_hp > 0.0:
			pct = int(round((current / max_hp) * 100.0))
		hp_percent.text = "%d%%" % pct


func set_followers(value: int) -> void:
	if followers_label != null:
		followers_label.text = str(value)
	if followers_pill != null and Global != null:
		followers_pill.tooltip_text = "People committed to preserving the Pattern.\nNext reconstruction cost: %d Followers" % Global.compute_respawn_cost()
