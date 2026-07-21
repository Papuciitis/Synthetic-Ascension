extends Control

@onready var title: Label = $Root/HBox/Left/Margin/VBox/Title
@onready var info: Label = $Root/HBox/Left/Margin/VBox/Info
@onready var cart: Label = $Root/HBox/Left/Margin/VBox/Cart
@onready var hover: Label = $Root/HBox/Left/Margin/VBox/Hover

@onready var btn_mark_all_bag: Button = $Root/HBox/Left/Margin/VBox/ButtonsRow/MarkAllBag
@onready var btn_mark_neg: Button = $Root/HBox/Left/Margin/VBox/ButtonsRow/MarkNEG
@onready var btn_clear: Button = $Root/HBox/Left/Margin/VBox/ButtonsRow/Clear
@onready var btn_augments: Button = $Root/HBox/Left/Margin/VBox/Augments
@onready var btn_inventory: Button = $Root/HBox/Left/Margin/VBox/Inventory

@onready var chk_include_equipped: CheckBox = $Root/HBox/Left/Margin/VBox/IncludeEquipped
@onready var btn_barter: Button = $Root/HBox/Left/Margin/VBox/SellSelected
@onready var btn_continue: Button = $Root/HBox/Left/Margin/VBox/Continue
@onready var btn_menu: Button = $Root/HBox/Left/Margin/VBox/Menu

@onready var inv_bar: InventoryBar = $Root/HBox/Equipped/Margin/VBox/InventoryBar
@onready var bag_grid: ShopBagGrid = $Root/HBox/Backpack/Margin/VBox/BagGrid
@onready var vendor_grid: ShopBagGrid = $Root/HBox/Vendor/Margin/VBox/VendorGrid
@onready var btn_refresh_vendor: Button = $Root/HBox/Vendor/Margin/VBox/VendorHeader/RefreshVendor
@onready var btn_cat_all: Button = $Root/HBox/Vendor/Margin/VBox/VendorFilters/CatAll
@onready var btn_cat_equip: Button = $Root/HBox/Vendor/Margin/VBox/VendorFilters/CatEquip
@onready var btn_cat_bag: Button = $Root/HBox/Vendor/Margin/VBox/VendorFilters/CatBag
@onready var btn_cat_sets: Button = $Root/HBox/Vendor/Margin/VBox/VendorFilters/CatSets
@onready var vendor_search: LineEdit = $Root/HBox/Vendor/Margin/VBox/VendorFilters/Search


# Cart preview (interactive; click to remove)
@onready var offer_grid: ShopBagGrid = $Root/HBox/CartPanel/Margin/VBox/Grids/OfferBox/OfferGrid
@onready var demand_grid: ShopBagGrid = $Root/HBox/CartPanel/Margin/VBox/Grids/DemandBox/DemandGrid
@onready var cart_totals: Label = $Root/HBox/CartPanel/Margin/VBox/Totals
@onready var btn_clear_cart: Button = $Root/HBox/CartPanel/Margin/VBox/Buttons/BtnClearCart
@onready var btn_barter_cart: Button = $Root/HBox/CartPanel/Margin/VBox/Buttons/BtnBarter

@onready var confirm_trade: ConfirmationDialog = $ConfirmSell
@onready var tooltip: ItemTooltip = $Tooltip
@onready var fly_vfx: UiFlyVfx = $FlyVfx

@export var mark_overlay_scene: PackedScene = preload("res://ui/widgets/SellMarkOverlay.tscn")
@export var major_choice_scene: PackedScene = preload("res://ui/screens/MajorChoice.tscn")
@export var augment_library_scene: PackedScene = preload("res://ui/screens/AugmentLibrary.tscn")

var _major_choice: MajorChoice = null
var _augment_library: AugmentLibraryScreen = null

# --- vendor stock ---
var _vendor_bag: BagInventory = null
var _vendor_seed: int = 0

# --- cart selections ---
var _sell_inv: Dictionary = {}    # int -> true
var _sell_bag: Dictionary = {}    # int -> true
var _buy_vendor: Dictionary = {}  # int -> true

# --- cart preview bags ---
var _offer_bag: BagInventory = null
var _demand_bag: BagInventory = null
var _offer_map: Dictionary = {}  # preview_slot -> {src:"bag"/"inv", slot:int}
var _demand_map: Dictionary = {} # preview_slot -> vendor_slot


# ---- live hover context (so tooltip updates when item changes under mouse, e.g. double-click moves) ----
var _hover_ctx_kind: String = ""  # inv|bag|vendor|offer|demand
var _hover_ctx_slot: int = -1
var _hover_ctx_inst_id: int = 0
# --- overlays ---
var _inv_ov: Array[SellMarkOverlay] = []
var _bag_ov: Array[SellMarkOverlay] = []
var _vendor_ov: Array[SellMarkOverlay] = []
var _offer_ov: Array[SellMarkOverlay] = []
var _demand_ov: Array[SellMarkOverlay] = []
var _bag_overlay_rebuild_pending: bool = false

const REFRESH_BASE_COST: int = 3
const REFRESH_GROWTH: float = 1.75  # exponential-ish growth per refresh
const REFRESH_MAX_COST: int = 999

enum VendorCategory { ALL, EQUIP, BAG, SETS }
var _vendor_category: int = VendorCategory.ALL
var _vendor_search_q: String = ""

func _get_refresh_cost() -> int:
	var n: int = 0
	if Global != null:
		n = maxi(0, int(Global.attempt_vendor_refreshes))
	var cost_f: float = float(REFRESH_BASE_COST) * pow(REFRESH_GROWTH, float(n))
	var cost: int = int(round(cost_f))
	return clampi(cost, REFRESH_BASE_COST, REFRESH_MAX_COST)


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Mark resume target as Hub/Shop
	if SaveManager != null and SaveManager.current_save != null:
		SaveManager.current_save.attempt_resume_scene = Global.PATH_HUB_SHOP
	if Global != null:
		Global.save_current_profile()

	# Bind player data
	inv_bar.allow_double_click_eject_always = true
	inv_bar.set_management_mode(false)
	inv_bar.bind_inventory(Global.run_inventory)
	bag_grid.bind_bag(Global.run_bag)
	if Global.run_bag != null and not Global.run_bag.changed.is_connected(_on_run_bag_changed):
		Global.run_bag.changed.connect(_on_run_bag_changed)

	# Build/reuse vendor bag (persistent per segment to prevent reroll exploit)
	_init_or_reuse_vendor()

	vendor_grid.bind_bag(_vendor_bag)

	# Build preview bags + bind
	_offer_bag = _make_preview_bag()
	_demand_bag = _make_preview_bag()
	offer_grid.bind_bag(_offer_bag)
	demand_grid.bind_bag(_demand_bag)

	# Wire clicks (select in source grids)
	if not inv_bar.slot_clicked.is_connected(_on_inv_slot_clicked):
		inv_bar.slot_clicked.connect(_on_inv_slot_clicked)
	if not bag_grid.slot_clicked.is_connected(_on_bag_slot_clicked):
		bag_grid.slot_clicked.connect(_on_bag_slot_clicked)
	if not vendor_grid.slot_clicked.is_connected(_on_vendor_slot_clicked):
		vendor_grid.slot_clicked.connect(_on_vendor_slot_clicked)

	# Wire clicks (remove in cart preview)
	if not offer_grid.slot_clicked.is_connected(_on_offer_slot_clicked):
		offer_grid.slot_clicked.connect(_on_offer_slot_clicked)
	if not demand_grid.slot_clicked.is_connected(_on_demand_slot_clicked):
		demand_grid.slot_clicked.connect(_on_demand_slot_clicked)

	# Rebuild overlays after first frame to ensure slot controls exist
	await get_tree().process_frame
	_build_overlays()

	# Buttons
	btn_mark_all_bag.pressed.connect(_mark_all_bag)
	btn_mark_neg.pressed.connect(_mark_negatives)
	btn_clear.pressed.connect(_clear_selection)
	btn_barter.pressed.connect(_barter_pressed)
	btn_continue.pressed.connect(_start_next_segment)
	btn_menu.pressed.connect(_to_menu)
	if btn_augments != null:
		btn_augments.pressed.connect(_open_augments)
	btn_inventory.pressed.connect(_open_inventory)


	btn_clear_cart.pressed.connect(_clear_selection)
	btn_barter_cart.pressed.connect(_barter_pressed)

	btn_refresh_vendor.pressed.connect(_refresh_vendor_pressed)

	# Vendor filters
	_setup_vendor_filters()
	_apply_vendor_filters()

	confirm_trade.confirmed.connect(_perform_trade)

	# Major choice overlay (Segment 5 reward)
	if major_choice_scene != null:
		_major_choice = major_choice_scene.instantiate() as MajorChoice
		add_child(_major_choice)
		_major_choice.choice_committed.connect(func(_id: StringName) -> void:
			btn_continue.disabled = false
			_refresh_info()
		)

	if Global != null and Global.pending_big_choice:
		btn_continue.disabled = true
		if _major_choice != null:
			_major_choice.open()

	if tooltip != null:
		tooltip.hide_tooltip()

	_refresh_info()
	_refresh_cart()

func _process(_delta: float) -> void:
	# Keep tooltip near mouse when visible + refresh live hover (double-click/moves can change item under cursor).
	if tooltip != null and tooltip.visible:
		_refresh_hover_tooltip_live()
		var p := get_viewport().get_mouse_position() + Vector2(16, 16)
		tooltip.global_position = _clamp_tooltip_pos(p)

func _to_menu() -> void:
	if Global != null:
		Global.save_current_profile()
	Global.goto_main_menu()

func _refresh_info() -> void:
	var seg: int = (Global.attempt_segment if Global != null else 1)
	var fol: int = (Global.followers if Global != null else 0)

	var extra: String = ""
	if Global != null and Global.pending_augment_pick:
		extra += "\nReward: Augment pick available"
	if Global != null and Global.pending_big_choice:
		extra += "\nReward: Major choice pending"

	title.text = "Interlude"
	info.text = "Next Segment: %d\nFollowers: %d%s" % [seg, fol, extra]

	# Refresh button affordance
	if btn_refresh_vendor != null:
		var cost := _get_refresh_cost()
		btn_refresh_vendor.disabled = (Global == null or Global.followers < cost)
		btn_refresh_vendor.text = "Refresh (-%d)" % cost
		btn_refresh_vendor.tooltip_text = "%d Followers search the city's remaining exchange routes." % cost

func _setup_vendor_filters() -> void:
	# Defensive: scene might not have these nodes in older versions.
	if btn_cat_all == null or btn_cat_equip == null or btn_cat_bag == null or btn_cat_sets == null:
		return
	# Ensure buttons behave like a group
	btn_cat_all.pressed.connect(func() -> void: _set_vendor_category(VendorCategory.ALL))
	btn_cat_equip.pressed.connect(func() -> void: _set_vendor_category(VendorCategory.EQUIP))
	btn_cat_bag.pressed.connect(func() -> void: _set_vendor_category(VendorCategory.BAG))
	btn_cat_sets.pressed.connect(func() -> void: _set_vendor_category(VendorCategory.SETS))
	if vendor_search != null:
		vendor_search.text_changed.connect(func(t: String) -> void:
			_vendor_search_q = t
			_apply_vendor_filters()
		)
		vendor_search.text_submitted.connect(func(t: String) -> void:
			_vendor_search_q = t
			_apply_vendor_filters()
		)
	_sync_vendor_filter_buttons()

func _set_vendor_category(cat: int) -> void:
	_vendor_category = cat
	_sync_vendor_filter_buttons()
	_apply_vendor_filters()

func _sync_vendor_filter_buttons() -> void:
	# Use toggle state for clear readability.
	if btn_cat_all == null:
		return
	btn_cat_all.button_pressed = (_vendor_category == VendorCategory.ALL)
	btn_cat_equip.button_pressed = (_vendor_category == VendorCategory.EQUIP)
	btn_cat_bag.button_pressed = (_vendor_category == VendorCategory.BAG)
	btn_cat_sets.button_pressed = (_vendor_category == VendorCategory.SETS)

func _vendor_item_matches(inst: ItemInstance) -> bool:
	if inst == null or inst.data == null:
		return false
	# Category
	match _vendor_category:
		VendorCategory.EQUIP:
			if int(inst.data.equip_slot) == int(ItemData.EquipSlot.NONE):
				return false
		VendorCategory.BAG:
			if int(inst.data.equip_slot) != int(ItemData.EquipSlot.NONE):
				return false
		VendorCategory.SETS:
			if String(inst.data.set_id).strip_edges() == "":
				return false
		_:
			pass
	# Search
	var q := _vendor_search_q.strip_edges().to_lower()
	if q != "":
		var name_ok := String(inst.data.display_name).to_lower().find(q) != -1
		var id_ok := String(inst.data.id).to_lower().find(q) != -1
		var set_ok := String(inst.data.set_id).to_lower().find(q) != -1
		if (not name_ok) and (not id_ok) and (not set_ok):
			return false
	return true

func _apply_vendor_filters() -> void:
	if vendor_grid == null or _vendor_bag == null:
		return
	# Hide empty + non-matching slots to produce a filtered “list” view.
	for i in range(_vendor_bag.slots.size()):
		var c: Control = vendor_grid.get_slot_control(i)
		if c == null:
			continue
		var inst: ItemInstance = _vendor_bag.slots[i]
		c.visible = _vendor_item_matches(inst)
	vendor_grid.queue_sort()
	# If we hid the slot currently under the mouse, clear hover/tooltip.
	# Cheap approach: always clear when filters change; the next hover will repopulate.
	_on_hover_clear()

func _make_preview_bag() -> BagInventory:
	var b := BagInventory.new()
	b.slots = []
	for _i in range(BagInventory.SLOT_COUNT):
		b.slots.append(null)
	b.extra_slots = 0
	return b


func _init_or_reuse_vendor() -> void:
	if Global == null:
		_vendor_bag = BagInventory.new()
		_vendor_bag._ensure_size()
		return

	var seg: int = maxi(1, int(Global.attempt_segment))

	# Reuse if the vendor snapshot matches this segment.
	if Global.attempt_vendor_segment == seg and Global.attempt_vendor_bag != null:
		_vendor_bag = Global.attempt_vendor_bag
		_vendor_seed = int(Global.attempt_vendor_seed)
		# Ensure correct size
		if _vendor_bag.has_method("_ensure_size"):
			_vendor_bag._ensure_size()
		# If empty for any reason, regenerate using the stored seed.
		var any_item: bool = false
		for it in _vendor_bag.slots:
			if it != null:
				any_item = true
				break
		if not any_item:
			_generate_vendor_stock(false)
			Global.attempt_vendor_seed = _vendor_seed
			Global.attempt_vendor_bag = _vendor_bag
			Global.request_autosave()
		return

	# New segment vendor
	_vendor_bag = BagInventory.new()
	_vendor_bag.slots = []
	for _i in range(BagInventory.SLOT_COUNT):
		_vendor_bag.slots.append(null)
	_vendor_bag.extra_slots = 0

	_vendor_seed = 0
	_generate_vendor_stock(false)

	Global.attempt_vendor_segment = seg
	Global.attempt_vendor_refreshes = 0
	Global.attempt_vendor_seed = _vendor_seed
	Global.attempt_vendor_bag = _vendor_bag
	Global.request_autosave()
func _build_overlays() -> void:
	_inv_ov.clear()
	_bag_ov.clear()
	_vendor_ov.clear()
	_offer_ov.clear()
	_demand_ov.clear()

	# Inventory overlays
	for i in range(Inventory.SLOT_COUNT):
		var c: Control = inv_bar.get_slot_control(i)
		if c == null:
			_inv_ov.append(null)
			continue
		var ov: SellMarkOverlay = mark_overlay_scene.instantiate() as SellMarkOverlay
		c.add_child(ov)
		ov.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		ov.z_index = 50
		ov.z_as_relative = false
		ov.set_mode(SellMarkOverlay.Mode.SELL)
		_inv_ov.append(ov)

		# Hover preview
		var ent := Callable(self, "_on_hover_inv").bind(i)
		var ext := Callable(self, "_on_hover_clear")
		if not c.mouse_entered.is_connected(ent):
			c.mouse_entered.connect(ent)
		if not c.mouse_exited.is_connected(ext):
			c.mouse_exited.connect(ext)

	# Bag overlays are dynamic because Expanded Satchel can add slots in this scene.
	_rebuild_bag_overlays()

	# Vendor overlays
	for k in range(BagInventory.SLOT_COUNT):
		var cv: Control = vendor_grid.get_slot_control(k)
		if cv == null:
			_vendor_ov.append(null)
			continue
		var ovv: SellMarkOverlay = mark_overlay_scene.instantiate() as SellMarkOverlay
		cv.add_child(ovv)
		ovv.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		ovv.z_index = 50
		ovv.z_as_relative = false
		ovv.set_mode(SellMarkOverlay.Mode.BUY)
		_vendor_ov.append(ovv)

		var ent3 := Callable(self, "_on_hover_vendor").bind(k)
		var ext3 := Callable(self, "_on_hover_clear")
		if not cv.mouse_entered.is_connected(ent3):
			cv.mouse_entered.connect(ent3)
		if not cv.mouse_exited.is_connected(ext3):
			cv.mouse_exited.connect(ext3)

	# Offer overlays (always visible for items in the cart)
	for o in range(BagInventory.SLOT_COUNT):
		var co: Control = offer_grid.get_slot_control(o)
		if co == null:
			_offer_ov.append(null)
			continue
		var ovo: SellMarkOverlay = mark_overlay_scene.instantiate() as SellMarkOverlay
		co.add_child(ovo)
		ovo.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		ovo.z_index = 50
		ovo.z_as_relative = false
		ovo.set_mode(SellMarkOverlay.Mode.SELL)
		_offer_ov.append(ovo)

		var ent4 := Callable(self, "_on_hover_offer").bind(o)
		var ext4 := Callable(self, "_on_hover_clear")
		if not co.mouse_entered.is_connected(ent4):
			co.mouse_entered.connect(ent4)
		if not co.mouse_exited.is_connected(ext4):
			co.mouse_exited.connect(ext4)

	# Demand overlays
	for d in range(BagInventory.SLOT_COUNT):
		var cd: Control = demand_grid.get_slot_control(d)
		if cd == null:
			_demand_ov.append(null)
			continue
		var ovd: SellMarkOverlay = mark_overlay_scene.instantiate() as SellMarkOverlay
		cd.add_child(ovd)
		ovd.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		ovd.z_index = 50
		ovd.z_as_relative = false
		ovd.set_mode(SellMarkOverlay.Mode.BUY)
		_demand_ov.append(ovd)

		var ent5 := Callable(self, "_on_hover_demand").bind(d)
		var ext5 := Callable(self, "_on_hover_clear")
		if not cd.mouse_entered.is_connected(ent5):
			cd.mouse_entered.connect(ent5)
		if not cd.mouse_exited.is_connected(ext5):
			cd.mouse_exited.connect(ext5)

	_refresh_overlays()

func _on_run_bag_changed() -> void:
	if Global == null or Global.run_bag == null:
		return
	var desired: int = Global.run_bag.get_slot_count()
	if desired == _bag_ov.size() or _bag_overlay_rebuild_pending:
		return
	_bag_overlay_rebuild_pending = true
	call_deferred("_finish_bag_overlay_rebuild")

func _finish_bag_overlay_rebuild() -> void:
	_bag_overlay_rebuild_pending = false
	_rebuild_bag_overlays()
	_refresh_overlays()

func _rebuild_bag_overlays() -> void:
	for old_overlay in _bag_ov:
		if old_overlay != null and is_instance_valid(old_overlay):
			old_overlay.queue_free()
	_bag_ov.clear()

	var bag_slot_count: int = BagInventory.SLOT_COUNT
	if Global != null and Global.run_bag != null:
		bag_slot_count = Global.run_bag.get_slot_count()

	for j in range(bag_slot_count):
		var cb: Control = bag_grid.get_slot_control(j)
		if cb == null:
			_bag_ov.append(null)
			continue
		var ovb: SellMarkOverlay = mark_overlay_scene.instantiate() as SellMarkOverlay
		cb.add_child(ovb)
		ovb.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		ovb.z_index = 50
		ovb.z_as_relative = false
		ovb.set_mode(SellMarkOverlay.Mode.SELL)
		_bag_ov.append(ovb)

		var ent2 := Callable(self, "_on_hover_bag").bind(j)
		var ext2 := Callable(self, "_on_hover_clear")
		if not cb.mouse_entered.is_connected(ent2):
			cb.mouse_entered.connect(ent2)
		if not cb.mouse_exited.is_connected(ext2):
			cb.mouse_exited.connect(ext2)

func _sell_value(inst: ItemInstance) -> int:
	if Global == null or inst == null:
		return 0
	return Global.compute_sell_value(inst) if Global.has_method("compute_sell_value") else 0

func _buy_value(inst: ItemInstance) -> int:
	if Global == null or inst == null:
		return 0
	return Global.compute_buy_value(inst) if Global.has_method("compute_buy_value") else _sell_value(inst)

func _refresh_overlays() -> void:
	# Inventory
	for i in range(_inv_ov.size()):
		var ov: SellMarkOverlay = _inv_ov[i]
		if ov == null:
			continue
		var inst: ItemInstance = (Global.run_inventory.get_at(i) if Global.run_inventory != null else null)
		var selected: bool = _sell_inv.has(i)
		ov.set_selected(selected)
		ov.set_price(_sell_value(inst))

	# Bag
	for j in range(_bag_ov.size()):
		var ovb: SellMarkOverlay = _bag_ov[j]
		if ovb == null:
			continue
		var inst2: ItemInstance = (Global.run_bag.slots[j] if Global.run_bag != null and j < Global.run_bag.slots.size() else null)
		var selected2: bool = _sell_bag.has(j)
		ovb.set_selected(selected2)
		ovb.set_price(_sell_value(inst2))

	# Vendor
	for k in range(_vendor_ov.size()):
		var ovv: SellMarkOverlay = _vendor_ov[k]
		if ovv == null:
			continue
		var inst3: ItemInstance = (_vendor_bag.slots[k] if _vendor_bag != null and k < _vendor_bag.slots.size() else null)
		var selected3: bool = _buy_vendor.has(k)
		ovv.set_selected(selected3)
		ovv.set_price(_buy_value(inst3))

	# Offer preview: show for filled slots
	for o in range(_offer_ov.size()):
		var ovo: SellMarkOverlay = _offer_ov[o]
		if ovo == null:
			continue
		var inst4: ItemInstance = (_offer_bag.slots[o] if _offer_bag != null and o < _offer_bag.slots.size() else null)
		ovo.set_selected(inst4 != null)
		ovo.set_price(_sell_value(inst4))

	# Demand preview
	for d in range(_demand_ov.size()):
		var ovd: SellMarkOverlay = _demand_ov[d]
		if ovd == null:
			continue
		var inst5: ItemInstance = (_demand_bag.slots[d] if _demand_bag != null and d < _demand_bag.slots.size() else null)
		ovd.set_selected(inst5 != null)
		ovd.set_price(_buy_value(inst5))

func _clear_selection() -> void:
	_sell_inv.clear()
	_sell_bag.clear()
	_buy_vendor.clear()
	_refresh_cart()
	_refresh_overlays()
	_apply_hidden_slots()


func _mark_all_bag() -> void:
	if Global.run_bag == null:
		return
	_sell_bag.clear()
	for i in range(Global.run_bag.slots.size()):
		if Global.run_bag.slots[i] != null:
			_sell_bag[i] = true
	_refresh_cart()
	_refresh_overlays()

func _mark_negatives() -> void:
	if Global.run_bag == null:
		return
	_sell_bag.clear()
	for i in range(Global.run_bag.slots.size()):
		var inst: ItemInstance = Global.run_bag.slots[i]
		if inst != null and int(inst.polarity) == int(ItemInstance.Polarity.NEG):
			_sell_bag[i] = true
	_refresh_cart()
	_refresh_overlays()

func _on_inv_slot_clicked(slot: int, button: int, _double_click: bool, _shift: bool) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	if Global.run_inventory == null:
		return
	# Only allow selling equipped if checkbox is on.
	if chk_include_equipped != null and (not chk_include_equipped.button_pressed):
		return

	var inst: ItemInstance = Global.run_inventory.get_at(slot)
	if inst == null:
		return

	if _sell_inv.has(slot):
		_sell_inv.erase(slot)
	else:
		_sell_inv[slot] = true

	_refresh_cart()
	_refresh_overlays()

func _on_bag_slot_clicked(slot: int) -> void:
	if Global.run_bag == null or slot < 0 or slot >= Global.run_bag.slots.size():
		return
	var inst: ItemInstance = Global.run_bag.slots[slot]
	if inst == null:
		return

	var was_selected: bool = _sell_bag.has(slot)
	if was_selected:
		_sell_bag.erase(slot)
	else:
		_sell_bag[slot] = true

	# VFX: bag <-> offer
	if fly_vfx != null:
		var src_ctrl := bag_grid.get_slot_control(slot)
		if src_ctrl != null:
			var start := _ctrl_center(src_ctrl)
			if not was_selected:
				fly_vfx.fly_to(offer_grid, inst, start, false)
			else:
				fly_vfx.fly_to(src_ctrl, inst, _ctrl_center(offer_grid), false)

	_refresh_cart()
	_refresh_overlays()
func _on_vendor_slot_clicked(slot: int) -> void:
	if _vendor_bag == null or slot < 0 or slot >= _vendor_bag.slots.size():
		return
	var inst: ItemInstance = _vendor_bag.slots[slot]
	if inst == null:
		return

	var was_selected: bool = _buy_vendor.has(slot)
	if was_selected:
		_buy_vendor.erase(slot)
	else:
		_buy_vendor[slot] = true

	# VFX: vendor <-> demand
	if fly_vfx != null:
		var src_ctrl := vendor_grid.get_slot_control(slot)
		if src_ctrl != null:
			var start := _ctrl_center(src_ctrl)
			if not was_selected:
				fly_vfx.fly_to(demand_grid, inst, start, false)
			else:
				fly_vfx.fly_to(src_ctrl, inst, _ctrl_center(demand_grid), false)

	_refresh_cart()
	_refresh_overlays()
func _on_offer_slot_clicked(slot: int) -> void:
	# Click-to-remove in cart preview
	if not _offer_map.has(slot):
		return

	var inst_fx: ItemInstance = (_offer_bag.slots[slot] if _offer_bag != null and slot < _offer_bag.slots.size() else null)

	var d: Dictionary = _offer_map[slot]
	var src: String = String(d.get("src", ""))
	var s: int = int(d.get("slot", -1))

	var src_ctrl: Control = null
	if src == "bag":
		src_ctrl = bag_grid.get_slot_control(s)
	elif src == "inv":
		src_ctrl = inv_bar.get_slot_control(s)

	# VFX: offer -> source
	if fly_vfx != null and inst_fx != null and src_ctrl != null:
		var sc := offer_grid.get_slot_control(slot)
		if sc != null:
			fly_vfx.fly_to(src_ctrl, inst_fx, _ctrl_center(sc), false)

	if src == "bag":
		_sell_bag.erase(s)
	elif src == "inv":
		_sell_inv.erase(s)

	_refresh_cart()
	_refresh_overlays()
func _on_demand_slot_clicked(slot: int) -> void:
	if not _demand_map.has(slot):
		return
	var vs: int = int(_demand_map[slot])
	# VFX: demand -> vendor
	var inst_fx: ItemInstance = (_demand_bag.slots[slot] if _demand_bag != null and slot < _demand_bag.slots.size() else null)
	if fly_vfx != null and inst_fx != null:
		var vctrl := vendor_grid.get_slot_control(vs)
		var sc := demand_grid.get_slot_control(slot)
		if vctrl != null and sc != null:
			fly_vfx.fly_to(vctrl, inst_fx, _ctrl_center(sc), false)
	_buy_vendor.erase(vs)
	_refresh_cart()
	_refresh_overlays()

func _sell_total() -> int:
	var total: int = 0
	# inv
	if Global.run_inventory != null:
		for k in _sell_inv.keys():
			var slot: int = int(k)
			var inst: ItemInstance = Global.run_inventory.get_at(slot)
			if inst != null:
				total += _sell_value(inst)
	# bag
	if Global.run_bag != null:
		for k2 in _sell_bag.keys():
			var slot2: int = int(k2)
			if slot2 >= 0 and slot2 < Global.run_bag.slots.size():
				var inst2: ItemInstance = Global.run_bag.slots[slot2]
				if inst2 != null:
					total += _sell_value(inst2)
	return total

func _buy_total() -> int:
	var total: int = 0
	if _vendor_bag == null:
		return total
	for k in _buy_vendor.keys():
		var slot: int = int(k)
		if slot >= 0 and slot < _vendor_bag.slots.size():
			var inst: ItemInstance = _vendor_bag.slots[slot]
			if inst != null:
				total += _buy_value(inst)
	return total


func _apply_hidden_slots() -> void:
	# Visual-only: hide items that are already placed in the offer/demand preview so the source grid doesn't look duplicated.
	# This does NOT change inventory data; it only changes how the grids render.
	
	# Equipped (only if selling equipped is enabled)
	if inv_bar != null and inv_bar.has_method("set_hidden_slots"):
		var m_inv: Dictionary = {}
		if chk_include_equipped != null and chk_include_equipped.button_pressed:
			m_inv = _sell_inv
		inv_bar.set_hidden_slots(m_inv)
	
	# Backpack + Vendor
	if bag_grid != null and bag_grid.has_method("set_hidden_slots"):
		bag_grid.set_hidden_slots(_sell_bag)
	if vendor_grid != null and vendor_grid.has_method("set_hidden_slots"):
		vendor_grid.set_hidden_slots(_buy_vendor)

func _refresh_cart() -> void:
	_rebuild_cart_previews()

	var sell_v: int = _sell_total()
	var buy_v: int = _buy_total()
	var net: int = buy_v - sell_v
	var fol: int = (Global.followers if Global != null else 0)
	var after: int = fol - net

	var net_txt: String
	if net > 0:
		net_txt = "Net Cost: %d" % net
	elif net < 0:
		net_txt = "Net Gain: %d" % (-net)
	else:
		net_txt = "Net: 0"

	var s_count: int = _sell_inv.size() + _sell_bag.size()
	var b_count: int = _buy_vendor.size()

	# Left sidebar summary
	cart.text = "Sell(%d): %d\nBuy(%d): %d\n%s\nFollowers: %d" % [s_count, sell_v, b_count, buy_v, net_txt, fol]

	# Center panel summary
	if cart_totals != null:
		var after_txt := ("%d" % after)
		cart_totals.text = "Sell: %d    Buy: %d\n%s\nFollowers after: %s" % [sell_v, buy_v, net_txt, after_txt]
	_apply_hidden_slots()


func _rebuild_cart_previews() -> void:
	_offer_map.clear()
	_demand_map.clear()

	if _offer_bag != null:
		for i in range(_offer_bag.slots.size()):
			_offer_bag.slots[i] = null
	if _demand_bag != null:
		for j in range(_demand_bag.slots.size()):
			_demand_bag.slots[j] = null

	# Offer items (sell) — stable order: bag first, then inventory
	var idx: int = 0
	if Global.run_bag != null and _offer_bag != null:
		var bag_slots: Array[int] = []
		for k in _sell_bag.keys():
			bag_slots.append(int(k))
		bag_slots.sort()
		for s in bag_slots:
			if idx >= _offer_bag.slots.size():
				break
			var inst: ItemInstance = Global.run_bag.slots[s] as ItemInstance
			if inst == null:
				continue
			_offer_bag.slots[idx] = inst
			_offer_map[idx] = {"src": "bag", "slot": s}
			idx += 1

	if Global.run_inventory != null and _offer_bag != null:
		var inv_slots: Array[int] = []
		for k2 in _sell_inv.keys():
			inv_slots.append(int(k2))
		inv_slots.sort()
		for s2 in inv_slots:
			if idx >= _offer_bag.slots.size():
				break
			var inst2: ItemInstance = Global.run_inventory.get_at(s2) as ItemInstance
			if inst2 == null:
				continue
			_offer_bag.slots[idx] = inst2
			_offer_map[idx] = {"src": "inv", "slot": s2}
			idx += 1

	# Demand items (buy) — stable order by vendor slot
	var didx: int = 0
	if _vendor_bag != null and _demand_bag != null:
		var vslots: Array[int] = []
		for k3 in _buy_vendor.keys():
			vslots.append(int(k3))
		vslots.sort()
		for vs in vslots:
			if didx >= _demand_bag.slots.size():
				break
			var inst3 := _vendor_bag.slots[vs]
			if inst3 == null:
				continue
			_demand_bag.slots[didx] = inst3
			_demand_map[didx] = vs
			didx += 1

	# notify grids
	if _offer_bag != null:
		_offer_bag.emit_changed()
	if _demand_bag != null:
		_demand_bag.emit_changed()

func _barter_pressed() -> void:
	if _sell_inv.is_empty() and _sell_bag.is_empty() and _buy_vendor.is_empty():
		return

	var sell_v: int = _sell_total()
	var buy_v: int = _buy_total()
	var net: int = buy_v - sell_v

	var fol: int = (Global.followers if Global != null else 0)
	var after: int = fol - net

	# capacity check for buys
	var need_slots: int = _estimate_needed_bag_slots_for_buys()
	if need_slots > _bag_empty_slots():
		hover.text = "Backpack full: need %d free slots." % need_slots
		return

	if after < 0:
		hover.text = "Not enough committed support: %d more Followers are needed for supplies, contacts and safe passage." % (-after)
		return

	var commitment_line := "Followers recover supplies from this exchange."
	if net > 0:
		commitment_line = "%d Followers commit supplies, contacts and personal risk to secure this equipment." % net
	confirm_trade.dialog_text = "Confirm exchange?\n\n%s\n\nSell: %d\nBuy: %d\nNet: %s\nFollowers after: %d" % [
		commitment_line,
		sell_v,
		buy_v,
		("-%d" % net if net > 0 else "+%d" % (-net) if net < 0 else "0"),
		after
	]
	confirm_trade.popup_centered()

func _perform_trade() -> void:
	var sell_v: int = _sell_total()
	var buy_v: int = _buy_total()
	var net: int = buy_v - sell_v

	var fol: int = (Global.followers if Global != null else 0)
	var after: int = fol - net
	if after < 0:
		return

	# capacity re-check
	var need_slots: int = _estimate_needed_bag_slots_for_buys()
	if need_slots > _bag_empty_slots():
		return

	# --- SELL (remove items) ---
	if Global.run_inventory != null:
		for k in _sell_inv.keys():
			var slot: int = int(k)
			Global.run_inventory.remove_at(slot)

	if Global.run_bag != null:
		for k2 in _sell_bag.keys():
			var slot2: int = int(k2)
			Global.run_bag.remove_at(slot2)

	# --- BUY (add items) ---
	if Global.run_bag != null and _vendor_bag != null:
		# sort vendor slots for stable removal
		var buy_slots: Array[int] = []
		for k3 in _buy_vendor.keys():
			buy_slots.append(int(k3))
		buy_slots.sort()

		for vs in buy_slots:
			if vs < 0 or vs >= _vendor_bag.slots.size():
				continue
			var inst: ItemInstance = _vendor_bag.slots[vs]
			if inst == null:
				continue

			# Remove from vendor first to avoid duplication exploits.
			# VFX: vendor -> backpack on buy
			if fly_vfx != null:
				var src_ctrl := vendor_grid.get_slot_control(vs)
				var start := _ctrl_center(src_ctrl) if src_ctrl != null else _ctrl_center(demand_grid)
				fly_vfx.fly_to(bag_grid, inst, start, false)

			# Remove from vendor first to avoid duplication exploits.
			_vendor_bag.remove_at(vs)

			# Add to player bag
			Global.run_bag.add_instance(inst)

	# Apply through the central transaction ledger. Positive net is a cost;
	# negative net is influence/resources returned to the movement.
	if Global != null:
		Global.transaction_followers(-net, &"trade", {"buy_value": buy_v, "sell_value": sell_v}, true, false)
		Global.save_current_profile()

	_clear_selection()
	_refresh_info()

func _refresh_vendor_pressed() -> void:
	if Global == null:
		return

	var cost: int = _get_refresh_cost()
	if Global.followers < cost:
		return

	Global.transaction_followers(-cost, &"vendor_refresh", {"refresh_index": int(Global.attempt_vendor_refreshes) + 1}, true, false)
	# bump refresh counter BEFORE regenerating so cost/UI reflects it immediately
	Global.attempt_vendor_refreshes = maxi(0, int(Global.attempt_vendor_refreshes)) + 1
	Global.save_current_profile()

	_generate_vendor_stock(true)
	vendor_grid.bind_bag(_vendor_bag)
	_apply_vendor_filters()

	# Persist vendor state
	Global.attempt_vendor_segment = maxi(1, int(Global.attempt_segment))
	Global.attempt_vendor_seed = _vendor_seed
	Global.attempt_vendor_bag = _vendor_bag
	Global.request_autosave()

	_clear_selection()
	_refresh_info()

func _first_empty_vendor_slot() -> int:
	if _vendor_bag == null:
		return -1
	for i in range(_vendor_bag.slots.size()):
		if _vendor_bag.slots[i] == null:
			return i
	return -1

func _generate_vendor_stock(force: bool) -> void:
	if Global == null or Global.item_db.is_empty() or _vendor_bag == null:
		return

	var seg: int = maxi(1, int(Global.attempt_segment))

	# Pull persisted seed if present (prevents reroll on reopen)
	if _vendor_seed == 0 and int(Global.attempt_vendor_seed) != 0:
		_vendor_seed = int(Global.attempt_vendor_seed)

	# Stable base seed per segment; refresh bumps it.
	if _vendor_seed == 0:
		var seed_base: int = int(Global.attempt_world_seed)
		_vendor_seed = int(_mix_seed(seed_base, seg * 1337, 7777))
	if force:
		_vendor_seed = int(_mix_seed(_vendor_seed, 991, 31337))

	var rng := RandomNumberGenerator.new()
	rng.seed = _vendor_seed

	# wipe
	for i in range(_vendor_bag.slots.size()):
		_vendor_bag.slots[i] = null

	var keys: Array = Global.item_db.keys()
	if keys.is_empty():
		return

	# Rarity range grows with segment, but stays sane.
	var r_lo: int = clampi(1 + int(floor(float(seg - 1) / 2.0)), 1, 8)
	var r_hi: int = clampi(r_lo + 3, r_lo, 10)

	# Fill ~10 slots
	var want: int = 10
	for _i2 in range(want):
		var slot_idx: int = _first_empty_vendor_slot()
		if slot_idx == -1:
			break

		var item_id: String = str(keys[rng.randi_range(0, keys.size() - 1)])
		var data: ItemData = Global.get_item_data(item_id)
		if data == null:
			continue

		var rarity: int = rng.randi_range(r_lo, r_hi)
		var roll_pct: float = _roll_percent_rng(rng, Global.run_luck, data.pct_min, data.pct_max)

		var pol: int = ItemInstance.Polarity.POS
		if roll_pct < 0.0:
			pol = ItemInstance.Polarity.NEG
		roll_pct = absf(roll_pct) * (1.0 if pol == ItemInstance.Polarity.POS else -1.0)

		var inst: ItemInstance = ItemInstance.from_roll(data, rarity, pol, roll_pct)
		_vendor_bag.slots[slot_idx] = inst

	_vendor_bag.emit_changed()

	# Persist seed so reopening the hub cannot reroll via Global._rng
	if Global != null:
		Global.attempt_vendor_seed = _vendor_seed

func _ctrl_center(c: Control) -> Vector2:
	if c == null:
		return Vector2.ZERO
	var r: Rect2 = c.get_global_rect()
	return r.position + r.size * 0.5

func _roll_standard_unit_rng(rng: RandomNumberGenerator) -> float:
	var x: float = 0.0
	for _i in range(6):
		x += rng.randf()
	x = (x - 3.0) / 3.0
	return clampf(x, -1.0, 1.0)

func _roll_percent_rng(rng: RandomNumberGenerator, luck: float, min_pct: float, max_pct: float) -> float:
	var x: float = _roll_standard_unit_rng(rng)
	var shape: float = exp(-luck * 1.25)
	shape = clampf(shape, 0.25, 4.0)
	var y: float = signf(x) * pow(absf(x), shape)
	var t: float = (y + 1.0) * 0.5
	var pct: float = lerpf(min_pct, max_pct, t)
	return clampf(pct, -0.9999, 0.9999)

func _mix_seed(a: int, b: int, c: int) -> int:
	var h: int = int((a ^ (b * 0x9E3779B9) ^ (c * 0x7F4A7C15)) & 0x7FFFFFFF)
	h = int((h * 1103515245 + 12345) & 0x7FFFFFFF)
	return h

# ---- Tooltip / hover ----

func _set_hover_context(kind: String, slot: int, inst: ItemInstance) -> void:
	_hover_ctx_kind = kind
	_hover_ctx_slot = slot
	_hover_ctx_inst_id = (int(inst.get_instance_id()) if (inst is Object and inst != null) else 0)

func _refresh_hover_tooltip_live() -> void:
	if _hover_ctx_kind == "":
		return
	var inst: ItemInstance = null
	match _hover_ctx_kind:
		"inv":
			inst = (Global.run_inventory.get_at(_hover_ctx_slot) if Global != null and Global.run_inventory != null else null) as ItemInstance
		"bag":
			inst = (Global.run_bag.slots[_hover_ctx_slot] if Global != null and Global.run_bag != null and _hover_ctx_slot >= 0 and _hover_ctx_slot < Global.run_bag.slots.size() else null) as ItemInstance
		"vendor":
			inst = (_vendor_bag.slots[_hover_ctx_slot] if _vendor_bag != null and _hover_ctx_slot >= 0 and _hover_ctx_slot < _vendor_bag.slots.size() else null) as ItemInstance
		"offer":
			inst = (_offer_bag.slots[_hover_ctx_slot] if _offer_bag != null and _hover_ctx_slot >= 0 and _hover_ctx_slot < _offer_bag.slots.size() else null) as ItemInstance
		"demand":
			inst = (_demand_bag.slots[_hover_ctx_slot] if _demand_bag != null and _hover_ctx_slot >= 0 and _hover_ctx_slot < _demand_bag.slots.size() else null) as ItemInstance
		_:
			inst = null
	var iid: int = (int(inst.get_instance_id()) if (inst is Object and inst != null) else 0)
	if iid != _hover_ctx_inst_id:
		_hover_ctx_inst_id = iid
		_set_hover_from_item(inst)
func _on_hover_inv(slot: int) -> void:
	if Global == null or Global.run_inventory == null:
		return
	var inst: ItemInstance = Global.run_inventory.get_at(slot)
	_set_hover_context("inv", slot, inst)
	_set_hover_from_item(inst)

func _on_hover_bag(slot: int) -> void:
	if Global == null or Global.run_bag == null or slot < 0 or slot >= Global.run_bag.slots.size():
		return
	var inst: ItemInstance = Global.run_bag.slots[slot]
	_set_hover_context("bag", slot, inst)
	_set_hover_from_item(inst)

func _on_hover_vendor(slot: int) -> void:
	if _vendor_bag == null or slot < 0 or slot >= _vendor_bag.slots.size():
		return
	var inst: ItemInstance = _vendor_bag.slots[slot]
	_set_hover_context("vendor", slot, inst)
	_set_hover_from_item(inst)

func _on_hover_offer(slot: int) -> void:
	if _offer_bag == null or slot < 0 or slot >= _offer_bag.slots.size():
		return
	var inst: ItemInstance = _offer_bag.slots[slot]
	_set_hover_context("offer", slot, inst)
	_set_hover_from_item(inst)

func _on_hover_demand(slot: int) -> void:
	if _demand_bag == null or slot < 0 or slot >= _demand_bag.slots.size():
		return
	var inst: ItemInstance = _demand_bag.slots[slot]
	_set_hover_context("demand", slot, inst)
	_set_hover_from_item(inst)

func _set_hover_from_item(inst: ItemInstance) -> void:
	if inst == null or inst.data == null:
		hover.text = ""
		if tooltip != null:
			tooltip.hide_tooltip()
		return

	var sell_v: int = _sell_value(inst)
	var buy_v: int = _buy_value(inst)
	var pol: String = ("NEG" if int(inst.polarity) == int(ItemInstance.Polarity.NEG) else "POS")
	hover.text = "%s  (R%d %s)\nSell: %d   Buy: %d" % [inst.data.display_name, int(inst.rarity), pol, sell_v, buy_v]

	if tooltip != null:
		tooltip.show_item(inst)
		var p := get_viewport().get_mouse_position() + Vector2(16, 16)
		tooltip.global_position = _clamp_tooltip_pos(p)

func _on_hover_clear() -> void:
	_hover_ctx_kind = ""
	_hover_ctx_slot = -1
	_hover_ctx_inst_id = 0
	hover.text = ""
	if tooltip != null:
		tooltip.hide_tooltip()

func _clamp_tooltip_pos(p: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	var tip_size := (tooltip.size if tooltip != null else Vector2(260, 200))
	var out := p
	out.x = clampf(out.x, 8.0, maxf(8.0, vp.x - tip_size.x - 8.0))
	out.y = clampf(out.y, 8.0, maxf(8.0, vp.y - tip_size.y - 8.0))
	return out

# ---- Capacity helpers ----
func _bag_empty_slots() -> int:
	if Global == null or Global.run_bag == null:
		return 0
	var empty: int = 0
	for s in Global.run_bag.slots:
		if s == null:
			empty += 1
	return empty

func _bag_stack_key(inst: ItemInstance) -> String:
	if inst == null or inst.data == null:
		return ""
	var p: String = ("pos" if int(inst.polarity) >= 0 else "neg")
	return "%s|%s" % [String(inst.data.id), p]

func _estimate_needed_bag_slots_for_buys() -> int:
	# BagInventory merges by item_id + polarity (rarity ignored).
	# Estimate how many *new* stack keys we'd add.
	if Global == null or Global.run_bag == null or _vendor_bag == null:
		return 0

	var keys: Dictionary = {}
	for s in Global.run_bag.slots:
		var inst: ItemInstance = s
		if inst == null:
			continue
		var k := _bag_stack_key(inst)
		if k != "":
			keys[k] = true

	var needed: int = 0
	for v in _buy_vendor.keys():
		var slot: int = int(v)
		if slot < 0 or slot >= _vendor_bag.slots.size():
			continue
		var inst2: ItemInstance = _vendor_bag.slots[slot]
		if inst2 == null:
			continue
		var k2 := _bag_stack_key(inst2)
		if k2 == "":
			continue
		if not keys.has(k2):
			keys[k2] = true
			needed += 1

	return needed



func _open_inventory() -> void:
	var scn: PackedScene = preload("res://ui/screens/InventoryStash.tscn")
	var inv := scn.instantiate() as InventoryStash
	if inv == null:
		return
	add_child(inv)
	inv.closed.connect(func() -> void:
		_refresh_overlays()
		_refresh_cart()
		if Global != null:
			Global.save_current_profile()
	)

func _open_augments() -> void:
	if augment_library_scene == null:
		return
	if _augment_library != null and is_instance_valid(_augment_library):
		return
	var inst := augment_library_scene.instantiate() as AugmentLibraryScreen
	if inst == null:
		return
	add_child(inst)
	_augment_library = inst
	btn_continue.disabled = true
	btn_barter.disabled = true
	btn_augments.disabled = true
	inst.closed.connect(func() -> void:
		btn_continue.disabled = false if (Global == null or not Global.pending_big_choice) else true
		btn_barter.disabled = false
		btn_augments.disabled = false
		_augment_library = null
	)

func _start_next_segment() -> void:
	if Global != null and Global.pending_big_choice:
		btn_continue.disabled = true
		if _major_choice != null:
			_major_choice.open()
		return

	Global.attempt_deaths_this_segment = 0
	Global.attempt_checkpoint_pos = Vector2.INF

	if SaveManager != null and SaveManager.current_save != null:
		SaveManager.current_save.attempt_resume_scene = Global.PATH_GAME

	Global.save_current_profile()
	Global.goto_game()
