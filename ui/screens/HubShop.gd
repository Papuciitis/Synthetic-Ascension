extends Control

@onready var title: Label = $Root/HBox/Left/Margin/VBox/Title
@onready var info: Label = $Root/HBox/Left/Margin/VBox/Info
@onready var hover: Label = $Root/HBox/Left/Margin/VBox/Hover

## Embedded mode (the walkable hub): the screen is a focused trade panel
## inside HubWorld — it never writes the resume target, never opens the
## Major Choice itself, and swaps Continue/Menu for a Close that emits
## embedded_closed. All economy behaviour is identical.
signal embedded_closed
var embedded: bool = false

@onready var btn_mark_all_bag: Button = $Root/HBox/CartPanel/Margin/VBox/TradeTools/MarkAllBag
@onready var btn_mark_neg: Button = $Root/HBox/CartPanel/Margin/VBox/TradeTools/MarkNEG
@onready var btn_augments: Button = $Root/HBox/Left/Margin/VBox/Augments
@onready var btn_inventory: Button = $Root/HBox/Left/Margin/VBox/Inventory

@onready var chk_include_equipped: CheckBox = $Root/HBox/CartPanel/Margin/VBox/TradeTools/IncludeEquipped
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
@onready var btn_affordable: Button = $Root/HBox/Vendor/Margin/VBox/VendorTools/Affordable
@onready var vendor_search: LineEdit = $Root/HBox/Vendor/Margin/VBox/VendorTools/Search


# Cart preview (interactive; click to remove)
@onready var offer_grid: ShopBagGrid = $Root/HBox/CartPanel/Margin/VBox/Grids/OfferBox/OfferGrid
@onready var demand_grid: ShopBagGrid = $Root/HBox/CartPanel/Margin/VBox/Grids/DemandBox/DemandGrid
@onready var cart_totals: Label = $Root/HBox/CartPanel/Margin/VBox/Totals
@onready var trade_status: Label = $Root/HBox/CartPanel/Margin/VBox/TradeStatus
@onready var btn_clear_cart: Button = $Root/HBox/CartPanel/Margin/VBox/Buttons/BtnClearCart
@onready var btn_barter_cart: Button = $Root/HBox/CartPanel/Margin/VBox/Buttons/BtnBarter

@onready var confirm_trade: TradeConfirmPopup = $ConfirmSell
@onready var tooltip: ItemTooltip = $Tooltip
@onready var fly_vfx: UiFlyVfx = $FlyVfx

@export var mark_overlay_scene: PackedScene = preload("res://ui/widgets/SellMarkOverlay.tscn")
@export var major_choice_scene: PackedScene = preload("res://ui/screens/MajorChoice.tscn")
@export var augment_library_scene: PackedScene = preload("res://ui/screens/AugmentLibrary.tscn")

var _major_choice: MajorChoice = null
var _augment_library: AugmentLibraryScreen = null
const ASCENSION_SCREEN := preload("res://ui/screens/AscensionScreen.tscn")
var _ascension_screen: AscensionScreen = null
var _btn_ascension: Button = null

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
var _vendor_overlay_rebuild_pending: bool = false

const REFRESH_BASE_COST: int = 3
const REFRESH_GROWTH: float = 1.75  # exponential-ish growth per refresh
const REFRESH_MAX_COST: int = 999

## The item tooltip's own canvas layer: over the Followers notice (180), which
## a trade or restock raises over the Exchange for 3.6 s, under the tutorial
## cards (230) and the loading scrim (250).
const TOOLTIP_LAYER: int = 190
## The tooltip sits this far right of and below the cursor (left of it past
## the right edge), and this far inside the screen.
const TOOLTIP_OFFSET := Vector2(16, 16)
const TOOLTIP_MARGIN: float = 8.0

enum VendorCategory { ALL, EQUIP, BAG, SETS }
var _vendor_category: int = VendorCategory.ALL
var _vendor_search_q: String = ""
var _vendor_affordable_only: bool = false

# Session-only vendor UI memory. It survives inventory refreshes and screen overlays,
# but is reset when the player actually leaves the HUB for the next segment/menu.
static var _remembered_vendor_category: int = VendorCategory.ALL
static var _remembered_vendor_search: String = ""
static var _remembered_vendor_affordable: bool = false

var _undo_trade: Dictionary = {}
var _btn_undo_trade: Button = null
var _quick_actions_footer: Label = null

# --- presentation (the front-end register; see the end of this file) ---
const ExchangeStyle := preload("res://ui/widgets/exchange/ExchangeStyle.gd")
const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

@onready var _bg: Control = get_node_or_null("BG") as Control
@onready var _layout: Container = get_node_or_null("Root/HBox") as Container
@onready var _scale: Control = get_node_or_null("Root/HBox/CartPanel/Margin/VBox/Scale") as Control
@onready var _grids_box: Control = get_node_or_null("Root/HBox/CartPanel/Margin/VBox/Grids") as Control
@onready var _divider: Control = get_node_or_null("Root/HBox/CartPanel/Margin/VBox/Grids/Divider") as Control
@onready var _reckon_now: Label = get_node_or_null("Root/HBox/CartPanel/Margin/VBox/Reckoning/Figures/Now") as Label
@onready var _reckon_after: Label = get_node_or_null("Root/HBox/CartPanel/Margin/VBox/Reckoning/Figures/After") as Label
@onready var _reckon_net: Label = get_node_or_null("Root/HBox/CartPanel/Margin/VBox/Reckoning/Net") as Label
@onready var _purse: Label = get_node_or_null("Purse/PurseValue") as Label
@onready var _respite: Label = get_node_or_null("Respite") as Label
@onready var _report: Label = get_node_or_null("Root/HBox/Left/Margin/VBox/Report") as Label
@onready var _ledger: VBoxContainer = get_node_or_null("Root/HBox/Left/Margin/VBox/Ledger") as VBoxContainer
@onready var _notices: VBoxContainer = get_node_or_null("Root/HBox/Left/Margin/VBox/Notices") as VBoxContainer
@onready var _equipped_count_label: Label = get_node_or_null("Root/HBox/Equipped/Margin/VBox/EquippedHeader/EquippedCount") as Label
@onready var _backpack_count_label: Label = get_node_or_null("Root/HBox/Backpack/Margin/VBox/BackpackHeader/BackpackCount") as Label
@onready var _bag_worth: Label = get_node_or_null("Root/HBox/Backpack/Margin/VBox/BagWorth") as Label
@onready var _stock_count: Label = get_node_or_null("Root/HBox/Vendor/Margin/VBox/Identity/Words/StockCount") as Label
@onready var _portrait: Control = get_node_or_null("Root/HBox/Vendor/Margin/VBox/Identity/Portrait") as Control
@onready var _flare: Control = get_node_or_null("Flare") as Control
var _panel_frames: Dictionary = {}  # panel name -> ArcaneFrame
var _gear_hover: int = -1
var _gear_styled: Array[int] = []
var _fit_pending: bool = false
var _ledger_rows: Dictionary = {}  # caption -> value Label

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

	# Mark resume target as Hub/Shop. Unvalidated: the segment-complete save one
	# frame earlier already ran the full read-back check, and stacking three
	# validated writes on the transition frame was part of its 144 ms hitch.
	if not embedded:
		if SaveManager != null and SaveManager.current_save != null:
			SaveManager.current_save.attempt_resume_scene = Global.PATH_HUB_SHOP
		if Global != null:
			Global.save_current_profile(false)

	# Bind player data
	# HubShop owns double-click actions so it can invalidate Undo before any
	# equipment mutation. Letting InventoryBar eject first bypasses that guard.
	inv_bar.allow_double_click_eject_always = false
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

	_apply_exchange_look()

	# Rebuild overlays after first frame to ensure slot controls exist
	await get_tree().process_frame
	_build_overlays()

	# Buttons
	btn_mark_all_bag.pressed.connect(_mark_all_bag)
	btn_mark_neg.pressed.connect(_mark_negatives)
	chk_include_equipped.toggled.connect(_on_include_equipped_toggled)
	btn_continue.pressed.connect(_start_next_segment)
	btn_menu.pressed.connect(_to_menu)
	if embedded:
		btn_continue.text = "Close"
		btn_menu.visible = false
	if btn_augments != null:
		btn_augments.pressed.connect(_open_augments)
	btn_inventory.pressed.connect(_open_inventory)
	_create_ascension_button()
	_create_imprint_button()


	btn_clear_cart.pressed.connect(_clear_selection)
	btn_barter_cart.pressed.connect(_barter_pressed)

	btn_refresh_vendor.pressed.connect(_refresh_vendor_pressed)

	# Vendor filters
	_vendor_category = _remembered_vendor_category
	_vendor_search_q = _remembered_vendor_search
	_vendor_affordable_only = _remembered_vendor_affordable
	_setup_vendor_filters()
	if vendor_search != null:
		vendor_search.text = _vendor_search_q
	if btn_affordable != null:
		btn_affordable.button_pressed = _vendor_affordable_only
	_create_undo_button()
	_create_quick_actions_footer()
	_apply_vendor_filters()

	confirm_trade.confirmed.connect(_perform_trade)

	# Ascension Doctrine overlay (staged rewards after Segments 3, 6, and 9)
	if major_choice_scene != null:
		_major_choice = major_choice_scene.instantiate() as MajorChoice
		add_child(_major_choice)
		_major_choice.choice_committed.connect(func(_id: StringName) -> void:
			btn_continue.disabled = false
			_refresh_info()
		)

	if Global != null and Global.pending_big_choice and not embedded:
		btn_continue.disabled = true
		if _major_choice != null:
			_major_choice.open()

	if tooltip != null:
		_lift_tooltip()
		tooltip.hide_tooltip()

	_style_code_built_controls()
	_refresh_info()
	_refresh_cart()
	_queue_fit_grids()

func _process(_delta: float) -> void:
	# Keep tooltip near mouse when visible + refresh live hover (double-click/moves can change item under cursor).
	if tooltip != null and tooltip.visible:
		# Its own layer does not hide with the Exchange.
		if not is_visible_in_tree():
			tooltip.hide_tooltip()
			return
		_refresh_hover_tooltip_live()
		tooltip.global_position = _tooltip_pos_for_mouse(get_viewport().get_mouse_position())

func _create_undo_button() -> void:
	if _btn_undo_trade != null or btn_clear_cart == null:
		return
	_btn_undo_trade = Button.new()
	_btn_undo_trade.name = "UndoLastTrade"
	_btn_undo_trade.text = "Undo Last Trade"
	_btn_undo_trade.disabled = true
	_btn_undo_trade.tooltip_text = "Restores the immediately previous exchange while this HUB remains open."
	btn_clear_cart.get_parent().add_child(_btn_undo_trade)
	_btn_undo_trade.pressed.connect(_undo_last_trade)

func _create_quick_actions_footer() -> void:
	if _quick_actions_footer != null or btn_clear_cart == null:
		return
	var buttons: Control = btn_clear_cart.get_parent() as Control
	var host: Control = null
	if buttons != null:
		host = buttons.get_parent() as Control
	if host == null:
		return
	_quick_actions_footer = Label.new()
	_quick_actions_footer.name = "QuickActionsFooter"
	_quick_actions_footer.text = "Right-click Move   ·   Shift-click Trade   ·   Ctrl-click Lock   ·   Double-click Equip"
	_quick_actions_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quick_actions_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quick_actions_footer.add_theme_font_size_override("font_size", 10)
	_quick_actions_footer.modulate = Color(1.0, 1.0, 1.0, 0.62)
	host.add_child(_quick_actions_footer)

func _remember_vendor_state() -> void:
	_remembered_vendor_category = _vendor_category
	_remembered_vendor_search = _vendor_search_q
	_remembered_vendor_affordable = _vendor_affordable_only

func _reset_vendor_memory() -> void:
	_remembered_vendor_category = VendorCategory.ALL
	_remembered_vendor_search = ""
	_remembered_vendor_affordable = false

func _invalidate_trade_undo(message: String = "") -> void:
	if _undo_trade.is_empty():
		return
	_undo_trade.clear()
	if _btn_undo_trade != null:
		_btn_undo_trade.disabled = true
		_btn_undo_trade.text = "Undo Last Trade"
		_btn_undo_trade.tooltip_text = "Undo is available after the next completed exchange."
	if message != "" and trade_status != null:
		trade_status.text = message

func _toggle_item_lock(inst: ItemInstance) -> void:
	if inst == null:
		return
	_invalidate_trade_undo("UNDO CLEARED · Inventory state changed.")
	inst.toggle_locked()
	if inst.locked:
		# A newly locked item is immediately removed from any pending sale cart.
		for key: Variant in _sell_inv.keys():
			if Global.run_inventory != null and Global.run_inventory.get_at(int(key)) == inst:
				_sell_inv.erase(key)
		for key2: Variant in _sell_bag.keys():
			if Global.run_bag != null and Global.run_bag.get_at(int(key2)) == inst:
				_sell_bag.erase(key2)
		if trade_status != null:
			trade_status.text = "LOCKED · Protected from trade, movement, replacement and duplicate cleanup."
	elif trade_status != null:
		trade_status.text = "UNLOCKED · Item actions restored."
	_refresh_cart(trade_status.text if trade_status != null else "")
	_refresh_overlays()
	if Global != null:
		Global.save_current_profile()

func _snapshot_items(values: Array[ItemInstance]) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for inst: ItemInstance in values:
		result.append(inst.snapshot_copy() if inst != null else null)
	return result

func _restore_inventory_snapshot(values: Array) -> void:
	if Global == null or Global.run_inventory == null:
		return
	Global.run_inventory.items.clear()
	for value: Variant in values:
		Global.run_inventory.items.append(value as ItemInstance)
	Global.run_inventory._ensure_size()
	Global.run_inventory.emit_changed()

func _restore_bag_snapshot(target: BagInventory, values: Array) -> void:
	if target == null:
		return
	target.slots.clear()
	for value: Variant in values:
		target.slots.append(value as ItemInstance)
	target._ensure_size()
	target._rebuild_index()
	target.emit_changed()

func _capture_trade_undo() -> void:
	if Global == null or Global.run_inventory == null or Global.run_bag == null or _vendor_bag == null:
		return
	_undo_trade = {
		"followers": int(Global.followers),
		"inventory": _snapshot_items(Global.run_inventory.items),
		"bag": _snapshot_items(Global.run_bag.slots),
		"vendor": _snapshot_items(_vendor_bag.slots),
		"sold_count": _sell_inv.size() + _sell_bag.size(),
		"bought_count": _buy_vendor.size(),
	}
	if _btn_undo_trade != null:
		_btn_undo_trade.disabled = false
		_btn_undo_trade.text = "Undo Last Trade"

func _refresh_undo_button_details() -> void:
	if _btn_undo_trade == null or _undo_trade.is_empty() or Global == null:
		return
	var sold_count: int = int(_undo_trade.get("sold_count", 0))
	var bought_count: int = int(_undo_trade.get("bought_count", 0))
	var before_followers: int = int(_undo_trade.get("followers", Global.followers))
	var follower_delta: int = before_followers - int(Global.followers)
	var follower_text: String = "Restore follower balance"
	if follower_delta > 0:
		follower_text = "Return %d Followers" % follower_delta
	elif follower_delta < 0:
		follower_text = "Remove %d Followers" % abs(follower_delta)
	_btn_undo_trade.tooltip_text = "Restore %d sold item(s), return %d bought item(s), and %s." % [sold_count, bought_count, follower_text]

func _undo_last_trade() -> void:
	if _undo_trade.is_empty() or Global == null:
		return
	# Route the restore through the ledger so every follower mutation is
	# auditable under one reason stream.
	var restored_followers: int = int(_undo_trade.get("followers", Global.followers))
	var original_op := int(_undo_trade.get("op", 0))
	var sold_count := int(_undo_trade.get("sold_count", 0))
	var bought_count := int(_undo_trade.get("bought_count", 0))
	var op := BalanceItemContext.begin(&"undo", {"undoes": original_op})
	Global.transaction_followers(restored_followers - int(Global.followers), &"trade_undo", {"op": op, "undoes": original_op, "sold_count": sold_count, "bought_count": bought_count}, false, false)
	_restore_inventory_snapshot(_undo_trade.get("inventory", []) as Array)
	_restore_bag_snapshot(Global.run_bag, _undo_trade.get("bag", []) as Array)
	_restore_bag_snapshot(_vendor_bag, _undo_trade.get("vendor", []) as Array)
	Global.attempt_vendor_bag = _vendor_bag
	# The undo is tied to the trade it reverses; nothing about it is a new
	# acquisition or sale.
	BalanceItemContext.report(&"undo", null, {"undoes": original_op, "sold_count": sold_count, "bought_count": bought_count, "followers_restored": restored_followers})
	BalanceItemContext.end(op)
	_undo_trade.clear()
	if _btn_undo_trade != null:
		_btn_undo_trade.disabled = true
		_btn_undo_trade.text = "Undo Last Trade"
		_btn_undo_trade.tooltip_text = "Undo is available after the next completed exchange."
	_clear_selection()
	_refresh_info()
	_apply_vendor_filters()
	if trade_status != null:
		trade_status.text = "LAST TRADE UNDONE"
	Global.save_current_profile()

func _to_menu() -> void:
	_invalidate_trade_undo()
	_reset_vendor_memory()
	if Global != null:
		Global.save_current_profile()
	Global.goto_main_menu()

func _refresh_info() -> void:
	var seg: int = (Global.attempt_segment if Global != null else 1)
	var fol: int = (Global.followers if Global != null else 0)
	var completed_segment: int = maxi(0, seg - 1)
	var gear_count: int = _equipped_count()
	var bag_count: int = _backpack_count()
	var bag_capacity: int = _backpack_capacity()

	var extra: String = ""
	if Global != null and Global.pending_augment_pick:
		extra += "\n\nBINDING READY\nAn augment Binding opens the next segment"
	if Global != null and Global.pending_big_choice:
		extra += "\n\nDOCTRINE READY\nAscension thesis awaiting inscription"

	title.text = "Aftermath"
	var report_header: String = "SEGMENT %d CLEARED" % completed_segment if completed_segment > 0 else "PREPARING SEGMENT 1"
	info.text = "%s\n\nNEXT ROUTE\nArea 1 · Segment %d\n\nCURRENT SUPPORT\nFollowers: %d\nGear: %d / %d\nBackpack: %d / %d%s" % [
		report_header,
		seg,
		fol,
		gear_count,
		Inventory.SLOT_COUNT,
		bag_count,
		bag_capacity,
		extra,
	]
	# Embedded in the hub, this button RETURNS to the courtyard; departure
	# belongs to the gate. The full-screen legacy shop keeps its old label.
	btn_continue.text = "Return to Courtyard" if embedded else "Continue to Segment %d" % seg

	# Refresh button affordance
	if btn_refresh_vendor != null:
		var cost := _get_refresh_cost()
		btn_refresh_vendor.disabled = (Global == null or Global.followers < cost)
		btn_refresh_vendor.text = "Restock  −%d" % cost
		btn_refresh_vendor.tooltip_text = "%d Followers search the city's remaining exchange routes." % cost

	_refresh_ledger_view(report_header, seg, fol, gear_count, bag_count, bag_capacity)


func _equipped_count() -> int:
	if Global == null or Global.run_inventory == null:
		return 0
	var count: int = 0
	for inst: ItemInstance in Global.run_inventory.items:
		if inst != null:
			count += 1
	return count


func _backpack_count() -> int:
	if Global == null or Global.run_bag == null:
		return 0
	var count: int = 0
	for inst: ItemInstance in Global.run_bag.slots:
		if inst != null:
			count += 1
	return count


func _backpack_capacity() -> int:
	if Global == null or Global.run_bag == null:
		return BagInventory.SLOT_COUNT
	return Global.run_bag.get_slot_count()

func _setup_vendor_filters() -> void:
	# Defensive: scene might not have these nodes in older versions.
	if btn_cat_all == null or btn_cat_equip == null or btn_cat_bag == null or btn_cat_sets == null:
		return
	# Ensure buttons behave like a group
	btn_cat_all.pressed.connect(func() -> void: _set_vendor_category(VendorCategory.ALL))
	btn_cat_equip.pressed.connect(func() -> void: _set_vendor_category(VendorCategory.EQUIP))
	btn_cat_bag.pressed.connect(func() -> void: _set_vendor_category(VendorCategory.BAG))
	btn_cat_sets.pressed.connect(func() -> void: _set_vendor_category(VendorCategory.SETS))
	if btn_affordable != null:
		btn_affordable.toggled.connect(_set_vendor_affordable)
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

func _set_vendor_affordable(enabled: bool) -> void:
	_vendor_affordable_only = enabled
	_apply_vendor_filters()

func _sync_vendor_filter_buttons() -> void:
	# Use toggle state for clear readability.
	if btn_cat_all == null:
		return
	btn_cat_all.button_pressed = (_vendor_category == VendorCategory.ALL)
	btn_cat_equip.button_pressed = (_vendor_category == VendorCategory.EQUIP)
	btn_cat_bag.button_pressed = (_vendor_category == VendorCategory.BAG)
	btn_cat_sets.button_pressed = (_vendor_category == VendorCategory.SETS)
	if btn_affordable != null:
		btn_affordable.button_pressed = _vendor_affordable_only

func _vendor_affordable_budget() -> int:
	var followers: int = (Global.followers if Global != null else 0)
	return maxi(0, followers + _sell_total())

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
	# Affordable is evaluated against current Followers plus anything already offered.
	# It is deliberately per-item; the final combined cart is still validated separately.
	if _vendor_affordable_only and _buy_value(inst) > _vendor_affordable_budget():
		return false

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
	_remember_vendor_state()
	if vendor_grid == null or _vendor_bag == null:
		return
	# Hide empty + non-matching slots to produce a filtered “list” view.
	for i in range(_vendor_bag.slots.size()):
		var c: Control = vendor_grid.get_slot_control(i)
		if c == null:
			continue
		var inst: ItemInstance = _vendor_bag.slots[i]
		# Unfiltered, the base shelf also shows its empty places (where sold
		# goods come to rest); a filter shows only the matching lots.
		c.visible = _vendor_item_matches(inst) or (inst == null and i < BagInventory.SLOT_COUNT and not _vendor_filter_active())
	vendor_grid.queue_sort()
	_refresh_stock_count()
	_queue_fit_grids()
	# If we hid the slot currently under the mouse, clear hover/tooltip.
	# Cheap approach: always clear when filters change; the next hover will repopulate.
	_on_hover_clear()

func _vendor_filter_active() -> bool:
	return _vendor_category != VendorCategory.ALL or _vendor_affordable_only or _vendor_search_q.strip_edges() != ""


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
		_vendor_bag.auto_consolidate = false
		_vendor_bag._ensure_size()
		return

	var seg: int = maxi(1, int(Global.attempt_segment))

	# Reuse if the vendor snapshot matches this segment.
	if Global.attempt_vendor_segment == seg and Global.attempt_vendor_bag != null:
		_vendor_bag = Global.attempt_vendor_bag
		# Older saves persisted the vendor bag before the flag existed.
		_vendor_bag.auto_consolidate = false
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
	_vendor_bag.auto_consolidate = false
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

	# Vendor overlays are dynamic too: a sale past the shelf's empty places
	# grows it, and the grid rebuilds every slot control.
	_rebuild_vendor_overlays()
	if not vendor_grid.slots_rebuilt.is_connected(_on_vendor_slots_rebuilt):
		vendor_grid.slots_rebuilt.connect(_on_vendor_slots_rebuilt)

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
		ovo.set_pan(true)
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
		ovd.set_pan(true)
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
	_queue_fit_grids()

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

func _on_vendor_slots_rebuilt() -> void:
	if _vendor_overlay_rebuild_pending:
		return
	_vendor_overlay_rebuild_pending = true
	call_deferred("_finish_vendor_overlay_rebuild")

func _finish_vendor_overlay_rebuild() -> void:
	_vendor_overlay_rebuild_pending = false
	_rebuild_vendor_overlays()
	_refresh_overlays()

## Price marks and hover on every place of the shelf, however many it has.
func _rebuild_vendor_overlays() -> void:
	for old_overlay in _vendor_ov:
		if old_overlay != null and is_instance_valid(old_overlay):
			old_overlay.queue_free()
	_vendor_ov.clear()

	for k in range(vendor_grid.slot_count):
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

func _sell_value(inst: ItemInstance) -> int:
	if Global == null or inst == null:
		return 0
	return Global.compute_sell_value(inst) if Global.has_method("compute_sell_value") else 0


## Telemetry only: one item of the trade with its own value, reported and
## returned for the transaction's item list.
func _report_trade_item(kind: StringName, inst: ItemInstance, value: int, container: String, slot: int) -> Dictionary:
	var entry := {"kind": String(kind), "id": String(inst.data.id) if inst.data != null else "", "rarity": inst.rarity, "value": value}
	BalanceItemContext.report(kind, inst, {"value": value, "container": container, "slot": slot})
	return entry

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
		ov.set_ghost(_icon_of(inst) if selected else null)
		ov.set_selected(selected)
		ov.set_price(_sell_value(inst))

	# Bag
	for j in range(_bag_ov.size()):
		var ovb: SellMarkOverlay = _bag_ov[j]
		if ovb == null:
			continue
		var inst2: ItemInstance = (Global.run_bag.slots[j] if Global.run_bag != null and j < Global.run_bag.slots.size() else null)
		var selected2: bool = _sell_bag.has(j)
		ovb.set_ghost(_icon_of(inst2) if selected2 else null)
		ovb.set_selected(selected2)
		ovb.set_price(_sell_value(inst2))

	# Vendor
	for k in range(_vendor_ov.size()):
		var ovv: SellMarkOverlay = _vendor_ov[k]
		if ovv == null:
			continue
		var inst3: ItemInstance = (_vendor_bag.slots[k] if _vendor_bag != null and k < _vendor_bag.slots.size() else null)
		var selected3: bool = _buy_vendor.has(k)
		ovv.set_ghost(_icon_of(inst3) if selected3 else null)
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


func _on_include_equipped_toggled(enabled: bool) -> void:
	if enabled:
		return
	_sell_inv.clear()
	_refresh_cart()
	_refresh_overlays()


func _mark_all_bag() -> void:
	if Global.run_bag == null:
		return
	_sell_bag.clear()
	for i in range(Global.run_bag.slots.size()):
		var inst: ItemInstance = Global.run_bag.slots[i]
		if inst != null and not inst.locked:
			_sell_bag[i] = true
	_refresh_cart()
	_refresh_overlays()

func _mark_negatives() -> void:
	if Global.run_bag == null:
		return
	_sell_bag.clear()
	for i in range(Global.run_bag.slots.size()):
		var inst: ItemInstance = Global.run_bag.slots[i]
		if inst != null and not inst.locked and int(inst.polarity) == int(ItemInstance.Polarity.NEG):
			_sell_bag[i] = true
	_refresh_cart()
	_refresh_overlays()

func _quick_move_equipped_to_bag(slot: int) -> void:
	if Global == null or Global.run_inventory == null or Global.run_bag == null or InvRouter == null:
		return
	var inst: ItemInstance = Global.run_inventory.get_at(slot)
	if inst == null:
		return
	if inst.locked:
		if trade_status != null: trade_status.text = "ITEM LOCKED · Ctrl-click to unlock before moving it."
		return
	var dst: int = Global.run_bag.first_empty_slot()
	if dst < 0:
		if trade_status != null: trade_status.text = "BACKPACK FULL"
		return
	_invalidate_trade_undo("UNDO CLEARED · Equipment changed.")
	_sell_inv.erase(slot)
	if InvRouter.move_between(Global.run_inventory, slot, Global.run_bag, dst, null):
		_refresh_cart("MOVED TO BACKPACK")
		_refresh_overlays()
		Global.save_current_profile()

func _quick_equip_from_bag(slot: int) -> void:
	if Global == null or Global.run_inventory == null or Global.run_bag == null or InvRouter == null:
		return
	var inst: ItemInstance = Global.run_bag.get_at(slot)
	if inst == null or inst.data == null:
		return
	if inst.locked:
		if trade_status != null: trade_status.text = "ITEM LOCKED · Ctrl-click to unlock before equipping it."
		return
	var equip_slot: int = int(inst.data.equip_slot)
	if equip_slot < 0 or equip_slot >= Inventory.SLOT_COUNT:
		if trade_status != null: trade_status.text = "THIS ITEM CANNOT BE EQUIPPED"
		return
	var current: ItemInstance = Global.run_inventory.get_at(equip_slot)
	if current != null and current.locked:
		if trade_status != null: trade_status.text = "EQUIPPED ITEM LOCKED · Unlock it before replacement."
		return
	_invalidate_trade_undo("UNDO CLEARED · Equipment changed.")
	_sell_bag.erase(slot)
	if InvRouter.move_between(Global.run_bag, slot, Global.run_inventory, equip_slot, null):
		_refresh_cart("ITEM EQUIPPED")
		_refresh_overlays()
		Global.save_current_profile()

func _quick_move_bag_to_stash(slot: int) -> void:
	if Global == null or Global.run_bag == null or InvRouter == null:
		return
	var inst: ItemInstance = Global.run_bag.get_at(slot)
	if inst == null:
		return
	if inst.locked:
		if trade_status != null: trade_status.text = "ITEM LOCKED · Ctrl-click to unlock before moving it."
		return
	if Global.meta_stash == null:
		Global.meta_stash = StashInventory.new()
	var dst: int = Global.meta_stash.first_empty_slot()
	if dst < 0:
		if trade_status != null: trade_status.text = "STASH FULL"
		return
	_invalidate_trade_undo("UNDO CLEARED · Inventory state changed.")
	_sell_bag.erase(slot)
	if InvRouter.move_between(Global.run_bag, slot, Global.meta_stash, dst, null):
		_refresh_cart("MOVED TO STASH")
		_refresh_overlays()
		Global.save_current_profile()

func _on_inv_slot_clicked(slot: int, button: int, double_click: bool, shift: bool) -> void:
	if Global.run_inventory == null:
		return
	var inst: ItemInstance = Global.run_inventory.get_at(slot)
	if inst == null:
		return
	if Input.is_key_pressed(KEY_CTRL):
		_toggle_item_lock(inst)
		return
	if button == MOUSE_BUTTON_RIGHT or (button == MOUSE_BUTTON_LEFT and double_click):
		_quick_move_equipped_to_bag(slot)
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if inst.locked:
		if trade_status != null: trade_status.text = "ITEM LOCKED · Ctrl-click to unlock."
		return
	if chk_include_equipped != null and not chk_include_equipped.button_pressed:
		if shift and trade_status != null:
			trade_status.text = "Enable Worn gear before adding equipped items to the offer."
		return
	if _sell_inv.has(slot):
		_sell_inv.erase(slot)
	else:
		_sell_inv[slot] = true
	_refresh_cart()
	_refresh_overlays()

func _on_bag_slot_clicked(slot: int, button: int, double_click: bool, shift: bool, ctrl: bool) -> void:
	if Global.run_bag == null or slot < 0 or slot >= Global.run_bag.slots.size():
		return
	var inst: ItemInstance = Global.run_bag.slots[slot]
	if inst == null:
		return
	if ctrl:
		_toggle_item_lock(inst)
		return
	if button == MOUSE_BUTTON_RIGHT:
		_quick_move_bag_to_stash(slot)
		return
	if button == MOUSE_BUTTON_LEFT and double_click:
		_quick_equip_from_bag(slot)
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if inst.locked:
		if trade_status != null: trade_status.text = "ITEM LOCKED · Ctrl-click to unlock before adding it to the offer."
		return

	# Shift-click is the explicit trade shortcut; ordinary left-click remains
	# compatible with the existing exchange flow.
	var was_selected: bool = _sell_bag.has(slot)
	if was_selected:
		_sell_bag.erase(slot)
	else:
		_sell_bag[slot] = true
	if shift and trade_status != null:
		trade_status.text = "REMOVED FROM OFFER" if was_selected else "ADDED TO OFFER"

	if fly_vfx != null:
		var src_ctrl := bag_grid.get_slot_control(slot)
		if src_ctrl != null:
			var start := _ctrl_center(src_ctrl)
			if not was_selected:
				_fly(_pan_slot_for(offer_grid, _sell_bag, slot), inst, start, false)
			else:
				_fly(src_ctrl, inst, _ctrl_center(offer_grid), false)

	_refresh_cart()
	_refresh_overlays()

func _on_vendor_slot_clicked(slot: int, button: int, _double_click: bool, shift: bool, ctrl: bool) -> void:
	if _vendor_bag == null or slot < 0 or slot >= _vendor_bag.slots.size():
		return
	if ctrl:
		if trade_status != null:
			trade_status.text = "Vendor stock cannot be locked; lock owned items in Gear, Backpack or Stash."
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	var inst: ItemInstance = _vendor_bag.slots[slot]
	if inst == null:
		return

	var was_selected: bool = _buy_vendor.has(slot)
	if was_selected:
		_buy_vendor.erase(slot)
	else:
		_buy_vendor[slot] = true
	if shift and trade_status != null:
		trade_status.text = "REMOVED FROM REQUEST" if was_selected else "ADDED TO REQUEST"

	# VFX: vendor <-> demand
	if fly_vfx != null:
		var src_ctrl := vendor_grid.get_slot_control(slot)
		if src_ctrl != null:
			var start := _ctrl_center(src_ctrl)
			if not was_selected:
				_fly(_pan_slot_for(demand_grid, _buy_vendor, slot), inst, start, false)
			else:
				_fly(src_ctrl, inst, _ctrl_center(demand_grid), false)

	_refresh_cart()
	_refresh_overlays()
func _on_offer_slot_clicked(slot: int, _button: int, _double_click: bool, _shift: bool, _ctrl: bool) -> void:
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
			_fly(src_ctrl, inst_fx, _ctrl_center(sc), false)

	if src == "bag":
		_sell_bag.erase(s)
	elif src == "inv":
		_sell_inv.erase(s)

	_refresh_cart()
	_refresh_overlays()
func _on_demand_slot_clicked(slot: int, _button: int, _double_click: bool, _shift: bool, _ctrl: bool) -> void:
	if not _demand_map.has(slot):
		return
	var vs: int = int(_demand_map[slot])
	# VFX: demand -> vendor
	var inst_fx: ItemInstance = (_demand_bag.slots[slot] if _demand_bag != null and slot < _demand_bag.slots.size() else null)
	if fly_vfx != null and inst_fx != null:
		var vctrl := vendor_grid.get_slot_control(vs)
		var sc := demand_grid.get_slot_control(slot)
		if vctrl != null and sc != null:
			_fly(vctrl, inst_fx, _ctrl_center(sc), false)
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
			if inst != null and not inst.locked:
				total += _sell_value(inst)
	# bag
	if Global.run_bag != null:
		for k2 in _sell_bag.keys():
			var slot2: int = int(k2)
			if slot2 >= 0 and slot2 < Global.run_bag.slots.size():
				var inst2: ItemInstance = Global.run_bag.slots[slot2]
				if inst2 != null and not inst2.locked:
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
		_style_gear_slots()
	
	# Backpack + Vendor
	if bag_grid != null and bag_grid.has_method("set_hidden_slots"):
		bag_grid.set_hidden_slots(_sell_bag)
	if vendor_grid != null and vendor_grid.has_method("set_hidden_slots"):
		vendor_grid.set_hidden_slots(_buy_vendor)

func _trade_validation() -> Dictionary:
	if _sell_inv.is_empty() and _sell_bag.is_empty() and _buy_vendor.is_empty():
		return {"valid": false, "reason": "Choose goods from either side."}

	# Defence in depth: even if a stale selection survives a UI refresh, a
	# locked item can never contribute value or be removed by a transaction.
	if Global.run_inventory != null:
		for key: Variant in _sell_inv.keys():
			var equipped: ItemInstance = Global.run_inventory.get_at(int(key))
			if equipped != null and equipped.locked:
				return {"valid": false, "reason": "ITEM LOCKED · Remove it from the offer or Ctrl-click to unlock."}
	if Global.run_bag != null:
		for key2: Variant in _sell_bag.keys():
			var bag_item: ItemInstance = Global.run_bag.get_at(int(key2))
			if bag_item != null and bag_item.locked:
				return {"valid": false, "reason": "ITEM LOCKED · Remove it from the offer or Ctrl-click to unlock."}

	var needed_slots: int = _estimate_needed_bag_slots_for_buys()
	var empty_slots: int = _bag_empty_slots() + _bag_slots_freed_by_offer()
	if needed_slots > empty_slots:
		return {
			"valid": false,
			"reason": "Backpack full • need %d more free slot%s." % [needed_slots - empty_slots, "" if needed_slots - empty_slots == 1 else "s"],
		}

	var followers: int = (Global.followers if Global != null else 0)
	var after: int = followers - (_buy_total() - _sell_total())
	if after < 0:
		return {
			"valid": false,
			"reason": "Insufficient support • %d more Followers required." % (-after),
		}

	# Followers are also lives: warn before the player barters away their
	# next reconstruction.
	var respawn_cost: int = Global.reconstruction_cost_for(after) if Global != null and Global.has_method("reconstruction_cost_for") else 1
	if Global != null and Global.has_method("reconstruction_survivable") and not Global.reconstruction_survivable(after):
		return {
			"valid": true,
			"reason": "⚠ %d Followers left — not above the next reconstruction cost (%d). Death would end the Ascension." % [after, respawn_cost],
		}

	return {"valid": true, "reason": "Exchange is viable."}

func _refresh_cart(status_override: String = "") -> void:
	_rebuild_cart_previews()

	var sell_v: int = _sell_total()
	var buy_v: int = _buy_total()
	var net: int = buy_v - sell_v
	var followers: int = (Global.followers if Global != null else 0)
	var after: int = followers - net

	var net_txt: String
	if net > 0:
		net_txt = "Net Cost: %d" % net
	elif net < 0:
		net_txt = "Net Gain: %d" % (-net)
	else:
		net_txt = "Net: 0"

	if cart_totals != null:
		cart_totals.text = "Offer: %d    Request: %d\n%s\nFollowers after: %d" % [sell_v, buy_v, net_txt, after]

	var validation: Dictionary = _trade_validation()
	var can_trade: bool = bool(validation.get("valid", false))
	var overlay_open: bool = _augment_library != null and is_instance_valid(_augment_library)
	if trade_status != null:
		# A caller's action feedback ("MOVED TO BACKPACK", "LOCKED ...") must
		# survive this refresh instead of being clobbered by validation text
		# in the same frame.
		if status_override != "":
			trade_status.text = status_override
			trade_status.modulate = Color(ExchangeStyle.PARCHMENT, 0.95)
		else:
			trade_status.text = String(validation.get("reason", ""))
			trade_status.modulate = _status_colour(can_trade, String(validation.get("reason", "")))
	if btn_barter_cart != null:
		btn_barter_cart.disabled = (not can_trade) or overlay_open
		btn_barter_cart.tooltip_text = "Confirm this exchange." if can_trade else String(validation.get("reason", ""))

	_apply_hidden_slots()
	if _vendor_affordable_only:
		_apply_vendor_filters()
	_refresh_balance_view(sell_v, buy_v, followers, after, can_trade)


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
			if inst == null or inst.locked:
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
			if inst2 == null or inst2.locked:
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
	var validation: Dictionary = _trade_validation()
	if not bool(validation.get("valid", false)):
		if trade_status != null:
			trade_status.text = String(validation.get("reason", "Exchange unavailable."))
		return

	var sell_v: int = _sell_total()
	var buy_v: int = _buy_total()
	var net: int = buy_v - sell_v
	var followers: int = (Global.followers if Global != null else 0)
	var after: int = followers - net

	var commitment_line := "Followers recover supplies from this exchange."
	if net > 0:
		commitment_line = "%d Followers commit supplies, contacts and personal risk to secure this equipment." % net
	confirm_trade.open_trade(
		sell_v,
		buy_v,
		net,
		followers,
		after,
		commitment_line
	)

func _perform_trade() -> void:
	# Revalidate after the confirmation popup so inventory/follower changes cannot
	# turn a previously valid cart into an impossible transaction.
	var validation: Dictionary = _trade_validation()
	if not bool(validation.get("valid", false)):
		_refresh_cart()
		return

	var sell_v: int = _sell_total()
	var buy_v: int = _buy_total()
	var net: int = buy_v - sell_v

	_capture_trade_undo()
	var op := BalanceItemContext.begin(&"trade", {"buy_value": buy_v, "sell_value": sell_v})
	_undo_trade["op"] = op
	var trade_items: Array = []

	# --- SELL (remove items; keep them for the buyback shelf) ---
	var sold_instances: Array[ItemInstance] = []
	if Global.run_inventory != null:
		for k in _sell_inv.keys():
			var slot: int = int(k)
			var sold_equipped: ItemInstance = Global.run_inventory.get_at(slot)
			if sold_equipped != null:
				sold_instances.append(sold_equipped)
				trade_items.append(_report_trade_item(&"sold", sold_equipped, _sell_value(sold_equipped), "equipped", slot))
			Global.run_inventory.remove_at(slot, {"player_driven": true})

	if Global.run_bag != null:
		for k2 in _sell_bag.keys():
			var slot2: int = int(k2)
			var sold_bagged: ItemInstance = Global.run_bag.get_at(slot2)
			if sold_bagged != null:
				sold_instances.append(sold_bagged)
				trade_items.append(_report_trade_item(&"sold", sold_bagged, _sell_value(sold_bagged), "bag", slot2))
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

			# VFX: vendor -> backpack on buy, from where the item sat.
			var src_ctrl := vendor_grid.get_slot_control(vs)
			var fly_start := _ctrl_center(src_ctrl) if src_ctrl != null else _ctrl_center(demand_grid)

			# Remove from vendor first to avoid duplication exploits.
			_vendor_bag.remove_at(vs)

			# Add to player bag
			trade_items.append(_report_trade_item(&"purchased", inst, _buy_value(inst), "vendor", vs))
			Global.run_bag.add_instance(inst)
			if fly_vfx != null:
				# ...to the slot it landed in (the bag's centre if it merged).
				var landed: Control = bag_grid.get_slot_control(Global.run_bag.slots.find(inst))
				_fly(landed if landed != null else bag_grid, inst, fly_start, false)

	# --- BUYBACK: what you sold sits on the vendor's shelf, rebuyable
	# exactly as it was until the stock refreshes; the shelf grows to hold it.
	var shelf_grew := false
	if _vendor_bag != null:
		for sold_variant in sold_instances:
			var sold := sold_variant as ItemInstance
			if sold == null:
				continue
			var buyback_slot: int = _vendor_bag.first_empty_slot()
			if buyback_slot == -1:
				# The shelf grows rather than losing what you sold.
				if _vendor_bag.get_slot_count() >= VENDOR_SHELF_MAX:
					break
				_vendor_bag.extra_slots += 8
				_vendor_bag._ensure_size()
				shelf_grew = true
				buyback_slot = _vendor_bag.first_empty_slot()
				if buyback_slot == -1:
					break
			_vendor_bag.set_at(buyback_slot, sold)
		if shelf_grew and vendor_grid != null:
			vendor_grid.bind_bag(_vendor_bag)
		if not sold_instances.is_empty():
			_apply_vendor_filters()

	# Apply through the central transaction ledger. Positive net is a cost;
	# negative net is influence/resources returned to the movement. The
	# item-level values ride inside the same transaction for the recorder.
	if Global != null:
		Global.transaction_followers(-net, &"trade", {"buy_value": buy_v, "sell_value": sell_v, "op": op, "items": trade_items}, true, false)
		Global.save_current_profile()
	BalanceItemContext.end(op)
	_refresh_undo_button_details()

	_clear_selection()
	_refresh_info()
	var completion_text := "EXCHANGE COMPLETE"
	if net > 0:
		completion_text += " · %d Followers committed" % net
	elif net < 0:
		completion_text += " · %d Followers gained" % (-net)
	_refresh_cart(completion_text)
	_celebrate_trade()

func _refresh_vendor_pressed() -> void:
	if Global == null:
		return
	_invalidate_trade_undo("UNDO CLEARED · Vendor stock refreshed.")

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
	var op := BalanceItemContext.begin(&"vendor_stock", {"refresh": force, "seed": _vendor_seed})

	# wipe
	for i in range(_vendor_bag.slots.size()):
		_vendor_bag.slots[i] = null

	var keys: Array = Global.item_db.keys()
	if keys.is_empty():
		return

	# Rarity range grows with segment, but stays sane.
	# Loot loop pass L3: the band follows the segment's rarity cap instead of
	# outrunning it (R1-R3 through segment 2, R2-R4 at 3-5, R3-R5 at 6-8).
	var band := vendor_band(seg)
	var r_lo: int = band.x
	var r_hi: int = band.y

	# Segment 1 pass S10: fewer, weighed purchases at the first Hubs.
	var want: int = vendor_slot_count(seg)
	for _i2 in range(want):
		var slot_idx: int = _first_empty_vendor_slot()
		if slot_idx == -1:
			break

		var item_id: String = Global.pick_weighted_item_id(rng, keys)
		var data: ItemData = Global.get_item_data(item_id)
		if data == null:
			continue

		var context := Global.build_item_drop_context(r_lo, r_hi, &"vendor", 1)
		context.threat_level += LuckResolver.vendor_stock_bonus(Global.run_luck)
		var inst: ItemInstance = ItemGenerator.create_instance(data, context, rng)
		_vendor_bag.slots[slot_idx] = inst

	_vendor_bag.emit_changed()
	BalanceItemContext.end(op)

	# Persist seed so reopening the hub cannot reroll via Global._rng
	if Global != null:
		Global.attempt_vendor_seed = _vendor_seed

func _ctrl_center(c: Control) -> Vector2:
	if c == null:
		return Vector2.ZERO
	var r: Rect2 = c.get_global_rect()
	return r.position + r.size * 0.5

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
		_show_idle_hover()
		if tooltip != null:
			tooltip.hide_tooltip()
		return
	hover.modulate.a = 1.0

	var sell_v: int = _sell_value(inst)
	var buy_v: int = _buy_value(inst)
	var pol: String = ("NEG" if int(inst.polarity) == int(ItemInstance.Polarity.NEG) else "POS")
	hover.text = "%s\nR%d %s  ·  sells for %s  ·  costs %s" % [inst.data.display_name, int(inst.rarity), pol, ExchangeStyle.grouped(sell_v), ExchangeStyle.grouped(buy_v)]

	if tooltip != null:
		tooltip.show_item(inst)
		# Where _process keeps it, so the hover frame does not jump.
		tooltip.global_position = _tooltip_pos_for_mouse(get_viewport().get_mouse_position())

func _on_hover_clear() -> void:
	_hover_ctx_kind = ""
	_hover_ctx_slot = -1
	_hover_ctx_inst_id = 0
	_show_idle_hover()
	if tooltip != null:
		tooltip.hide_tooltip()

## Right of and below the cursor; past the right edge it flips to the cursor's
## left rather than being clamped back over the lot it describes.
func _tooltip_pos_for_mouse(mouse: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	var tip_size := (tooltip.size if tooltip != null else Vector2(260, 200))
	var out := mouse + TOOLTIP_OFFSET
	if out.x + tip_size.x > vp.x - TOOLTIP_MARGIN:
		out.x = mouse.x - TOOLTIP_OFFSET.x - tip_size.x
	out.x = clampf(out.x, TOOLTIP_MARGIN, maxf(TOOLTIP_MARGIN, vp.x - tip_size.x - TOOLTIP_MARGIN))
	out.y = clampf(out.y, TOOLTIP_MARGIN, maxf(TOOLTIP_MARGIN, vp.y - tip_size.y - TOOLTIP_MARGIN))
	return out

## The tooltip on a canvas layer of its own, over everything the hub raises
## above the Exchange; the Exchange's theme does not cross a layer by itself.
func _lift_tooltip() -> void:
	var tooltip_layer := CanvasLayer.new()
	tooltip_layer.name = "TooltipLayer"
	tooltip_layer.layer = TOOLTIP_LAYER
	add_child(tooltip_layer)
	tooltip.reparent(tooltip_layer, false)
	tooltip.theme = theme

# ---- Capacity helpers ----
func _bag_empty_slots() -> int:
	if Global == null or Global.run_bag == null:
		return 0
	var empty: int = 0
	for s in Global.run_bag.slots:
		if s == null:
			empty += 1
	return empty

func _bag_slots_freed_by_offer() -> int:
	if Global == null or Global.run_bag == null:
		return 0
	var freed: int = 0
	for key in _sell_bag.keys():
		var slot: int = int(key)
		if slot >= 0 and slot < Global.run_bag.slots.size() and Global.run_bag.slots[slot] != null:
			freed += 1
	return freed

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
	# Model the backpack *after* offered bag items are removed. Otherwise selling
	# the only stack of a key and buying that key plus another can undercount slots.
	for bag_slot in range(Global.run_bag.slots.size()):
		if _sell_bag.has(bag_slot):
			continue
		var inst: ItemInstance = Global.run_bag.slots[bag_slot]
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
	if not _sell_inv.is_empty() or not _sell_bag.is_empty() or not _buy_vendor.is_empty():
		if trade_status != null:
			trade_status.text = "Clear or confirm the exchange before reorganising reserved items."
		return
	_invalidate_trade_undo("UNDO CLEARED · Inventory management opened.")
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

var _btn_imprints: Button = null
var _imprint_screen: CanvasLayer = null
const IMPRINT_SCREEN := preload("res://ui/screens/ImprintScreen.gd")


## The imprinter: held Manifestation imprints onto worn or bagged items.
func _create_imprint_button() -> void:
	if _btn_imprints != null or btn_augments == null:
		return
	_btn_imprints = Button.new()
	_btn_imprints.name = "Imprints"
	_btn_imprints.text = "Imprints"
	_btn_imprints.tooltip_text = "Put a held Manifestation onto an item, for Followers. Rules dissolved by merges are kept here."
	var anchor: Node = _btn_ascension if _btn_ascension != null else btn_augments
	anchor.get_parent().add_child(_btn_imprints)
	anchor.get_parent().move_child(_btn_imprints, anchor.get_index() + 1)
	_btn_imprints.pressed.connect(_open_imprints)


func _open_imprints() -> void:
	if _imprint_screen != null and is_instance_valid(_imprint_screen):
		return
	var screen := IMPRINT_SCREEN.new() as CanvasLayer
	add_child(screen)
	_imprint_screen = screen
	if _btn_imprints != null:
		_btn_imprints.disabled = true
	screen.closed.connect(func() -> void:
		_imprint_screen = null
		if _btn_imprints != null:
			_btn_imprints.disabled = false
		_invalidate_trade_undo("UNDO CLEARED · Imprint applied.")
		_refresh_info()
	)


func _create_ascension_button() -> void:
	if _btn_ascension != null or btn_augments == null:
		return
	_btn_ascension = Button.new()
	_btn_ascension.name = "Ascension"
	_btn_ascension.text = "Ascension"
	_btn_ascension.tooltip_text = "Spend Followers on the advancement tree."
	btn_augments.get_parent().add_child(_btn_ascension)
	btn_augments.get_parent().move_child(_btn_ascension, btn_augments.get_index() + 1)
	_btn_ascension.pressed.connect(_open_ascension)


## The vendor's rarity band at a segment (x = min, y = max): it follows the
## segment's rarity cap instead of outrunning it.
## The vendor's shelf never drops what you sold: it grows by eight slots up
## to this many.
const VENDOR_SHELF_MAX := 64


## How many offers the vendor lays out: eight through segment 2, ten at
## 3-5, twelve from segment 6.
static func vendor_slot_count(seg: int) -> int:
	if seg <= 2:
		return 8
	if seg <= 5:
		return 10
	return 12


## The vendor's rarity band at a segment (x = min, y = max): one rank under
## the segment's rarity cap to two above it, so the shop is where rarity is
## bought without outrunning the run (R1-R4 at segments 1-2, R2-R5 at 3-5,
## R4-R7 at 9).
static func vendor_band(seg: int) -> Vector2i:
	var cap: int = int(floor(float(maxi(1, seg)) / 3.0)) + 2
	return Vector2i(clampi(cap - 1, 1, 8), clampi(cap + 2, 2, 10))


func _open_ascension() -> void:
	if _ascension_screen != null and is_instance_valid(_ascension_screen):
		return
	# A trade undo must not restore a Follower snapshot from before tree
	# purchases or refunds (RANK-07); the tree screen invalidates it like
	# every other state-changing overlay.
	_invalidate_trade_undo("UNDO CLEARED · Ascension state changed.")
	var inst := ASCENSION_SCREEN.instantiate() as AscensionScreen
	if inst == null:
		return
	add_child(inst)
	_ascension_screen = inst
	btn_continue.disabled = true
	if _btn_ascension != null:
		_btn_ascension.disabled = true
	if Global != null:
		Global.ascension_refund_context_hub = true
	inst.open(false)
	inst.closed.connect(func() -> void:
		if Global != null:
			Global.ascension_refund_context_hub = false
		# A pending mandatory choice gates DEPARTURE, never the way back to
		# the courtyard (the embedded panel's button only closes).
		btn_continue.disabled = false if (embedded or Global == null or not Global.pending_big_choice) else true
		_ascension_screen = null
		if _btn_ascension != null:
			_btn_ascension.disabled = false
		_refresh_info()
	)


func _open_augments() -> void:
	_invalidate_trade_undo("UNDO CLEARED · Augment state changed.")
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
	btn_barter_cart.disabled = true
	btn_augments.disabled = true
	inst.closed.connect(func() -> void:
		btn_continue.disabled = false if (embedded or Global == null or not Global.pending_big_choice) else true
		_augment_library = null
		_refresh_cart()
		btn_augments.disabled = false
	)

func _start_next_segment() -> void:
	if embedded:
		_invalidate_trade_undo()
		embedded_closed.emit()
		return
	_invalidate_trade_undo()
	_reset_vendor_memory()
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


# ============================================================================
# Presentation: the Exchange in the front-end register
# (docs/design/2026-10-02-front-end-arcane-register.md). Nothing below reads
# or writes the economy; it dresses the screen's own nodes and animates them.
# ============================================================================

const GEAR_CELL := 80.0
const SAYINGS: Array[String] = [
	"\"Everything the city lost comes through my hands eventually. Name a fair weight.\"",
	"\"I weigh a relic twice: once for what it is, once for who will miss it.\"",
	"\"Lay it on the pan. The scales have never lied to me, which is more than I can say for my customers.\"",
	"\"Recovered, not stolen. The difference is a matter of paperwork.\"",
]


## Panels, frames, type and buttons; then the open: the veil fades up and
## the panels settle in. Runs before the first frame is drawn.
## Items fly into the slot they land in; under reduced motion they are simply
## there (the move itself is unchanged).
func _fly(target: Control, inst: ItemInstance, start: Vector2, upgraded: bool) -> void:
	if fly_vfx == null or ArcaneMotion.reduced():
		return
	fly_vfx.fly_to(target, inst, start, upgraded)


func _apply_exchange_look() -> void:
	var still := ArcaneMotion.reduced()
	if _bg != null:
		_bg.set("embedded", embedded)
	var alpha := 0.93 if embedded else 0.9
	for panel_name: String in ["Left", "Equipped", "Backpack", "CartPanel", "Vendor"]:
		var panel := get_node_or_null("Root/HBox/" + panel_name) as PanelContainer
		if panel == null:
			continue
		var rite := panel_name == "CartPanel"
		panel.add_theme_stylebox_override(&"panel", ExchangeStyle.panel(rite, alpha))
		var frame := ArcaneFrameScript.new() as Control
		frame.name = "Frame"
		frame.set("inset", 6.0)
		frame.set("crown", rite)
		frame.set("glow", 0.12 if rite else 0.0)
		frame.set("colour", Color(0.66, 0.5, 0.3, 0.9) if rite else Color(0.55, 0.42, 0.26, 0.7))
		panel.add_child(frame)
		_panel_frames[panel_name] = frame

	for b: Button in [btn_augments, btn_inventory, btn_menu]:
		ExchangeStyle.style_button(b, ExchangeStyle.Btn.NAV, 15)
	ExchangeStyle.style_button(btn_continue, ExchangeStyle.Btn.NAV_PRIMARY, 15)
	for b2: Button in [btn_mark_all_bag, btn_mark_neg, btn_clear_cart, btn_refresh_vendor]:
		ExchangeStyle.style_button(b2, ExchangeStyle.Btn.SMALL, 14)
	ExchangeStyle.style_button(btn_barter_cart, ExchangeStyle.Btn.PRIMARY, 17)
	for b3: Button in [btn_cat_all, btn_cat_equip, btn_cat_bag, btn_cat_sets, btn_affordable]:
		ExchangeStyle.style_button(b3, ExchangeStyle.Btn.TAB, 14)
	if chk_include_equipped != null:
		chk_include_equipped.add_theme_font_size_override(&"font_size", 16)
	if vendor_search != null:
		vendor_search.add_theme_font_size_override(&"font_size", 16)
	if _divider != null:
		_divider.draw.connect(_draw_divider)
	if _grids_box != null:
		_grids_box.resized.connect(_sync_scale_arm)
	var saying := get_node_or_null("Root/HBox/Vendor/Margin/VBox/Identity/Words/Saying") as Label
	if saying != null:
		saying.text = SAYINGS[absi(_vendor_seed if _vendor_seed != 0 else int(Global.attempt_segment if Global != null else 1)) % SAYINGS.size()]

	# The worn gear: four across, the Exchange's own socket on each slot.
	if inv_bar != null:
		inv_bar.columns = 4
		_gear_styled.clear()
		for i in range(Inventory.SLOT_COUNT):
			var c := inv_bar.get_slot_control(i)
			_gear_styled.append(-1)
			if c == null:
				continue
			c.custom_minimum_size = Vector2(GEAR_CELL, GEAR_CELL)
			c.mouse_entered.connect(_on_gear_hover.bind(i, true))
			c.mouse_exited.connect(_on_gear_hover.bind(i, false))
		if Global != null and Global.run_inventory != null and not Global.run_inventory.changed.is_connected(_style_gear_slots):
			Global.run_inventory.changed.connect(_style_gear_slots)
		_style_gear_slots()
	if bag_grid != null:
		bag_grid.cell_size = 80.0
	if vendor_grid != null:
		vendor_grid.cell_size = 86.0
	for p: ShopBagGrid in [offer_grid, demand_grid]:
		if p != null:
			p.cell_size = 66.0
	var spacer := get_node_or_null("Root/HBox/Left/Margin/VBox/Spacer") as Control
	if spacer != null:
		spacer.draw.connect(_draw_seal.bind(spacer))
		spacer.resized.connect(spacer.queue_redraw)

	# The open: the panels settle in (ExchangeLayout) and the header comes up
	# in step with them.
	if _layout != null and _layout.has_method("play_intro"):
		if not still and _layout.has_signal("intro_progress"):
			_layout.connect("intro_progress", _on_intro_progress)
			_on_intro_progress(0.0)
		_layout.call("play_intro", still)
	_show_idle_hover()


const HEADER_NODES: Array[String] = ["BG", "ExchangeBanner", "ExchangeClassification", "HeaderRule", "LedgerAuthority", "Respite", "Purse"]


## The veil and the header fade up and the header rule draws out from its
## star, driven by the layout's intro so they share its real-time clock.
func _on_intro_progress(t: float) -> void:
	var bg_t := clampf(t / 0.35, 0.0, 1.0)
	var head_t := smoothstep(0.12, 0.85, t)
	for node_name in HEADER_NODES:
		var n := get_node_or_null(node_name) as CanvasItem
		if n != null:
			n.modulate.a = lerpf(0.35, 1.0, bg_t if node_name == "BG" else head_t)
	var rule := get_node_or_null("HeaderRule") as Control
	if rule != null:
		rule.pivot_offset = rule.size * 0.5
		var e := 1.0 - pow(1.0 - smoothstep(0.1, 1.0, t), 3.0)
		rule.scale = Vector2(lerpf(0.3, 1.0, e), 1.0)


const HOVER_IDLE := "Rest the cursor on a lot and the Exchanger will name its weight."


## The inspect line, when nothing is under the cursor.
func _show_idle_hover() -> void:
	if hover == null:
		return
	hover.text = HOVER_IDLE
	hover.modulate.a = 0.55


## Buttons and labels the controller builds after the first frame.
func _style_code_built_controls() -> void:
	for b: Button in [_btn_ascension, _btn_imprints]:
		if b != null and not b.has_meta(&"exchange_styled"):
			b.set_meta(&"exchange_styled", true)
			ExchangeStyle.style_button(b, ExchangeStyle.Btn.NAV, 15)
	if _btn_undo_trade != null and not _btn_undo_trade.has_meta(&"exchange_styled"):
		_btn_undo_trade.set_meta(&"exchange_styled", true)
		_btn_undo_trade.text = "Undo Last Trade"
		ExchangeStyle.style_button(_btn_undo_trade, ExchangeStyle.Btn.SMALL, 14)
	if _quick_actions_footer != null and not _quick_actions_footer.has_meta(&"exchange_styled"):
		_quick_actions_footer.set_meta(&"exchange_styled", true)
		_quick_actions_footer.theme_type_variation = &"ArcaneCaption"
		_quick_actions_footer.add_theme_font_size_override(&"font_size", 12)
		_quick_actions_footer.modulate = Color(1, 1, 1, 0.7)
		_quick_actions_footer.text = "Right-click  move   ·   Shift-click  trade   ·   Ctrl-click  lock   ·   Double-click  equip"


func _status_colour(valid: bool, reason: String) -> Color:
	if _sell_inv.is_empty() and _sell_bag.is_empty() and _buy_vendor.is_empty():
		return Color(ExchangeStyle.BODY, 0.62)
	if reason.begins_with("⚠"):
		return Color(ExchangeStyle.DANGER.lightened(0.15), 0.95)
	if valid:
		return Color(ExchangeStyle.GOLD_BRIGHT, 0.9)
	return Color(ExchangeStyle.EMBER, 0.92)


func _icon_of(inst: ItemInstance) -> Texture2D:
	return inst.data.icon if inst != null and inst.data != null else null


## The pan slot an item is about to land in (the previews are ordered by
## source slot), so the flying icon arrives where the item will sit.
func _pan_slot_for(grid: ShopBagGrid, picked: Dictionary, slot: int) -> Control:
	if grid == null:
		return null
	var index := 0
	for key: Variant in picked.keys():
		if int(key) < slot:
			index += 1
	var c := grid.get_slot_control(index)
	return c if c != null else grid


# ---- the ledger (left), the purse (header) and the shelves' counts ----

func _refresh_ledger_view(report_header: String, seg: int, fol: int, gear_count: int, bag_count: int, bag_capacity: int) -> void:
	if _report != null:
		_report.text = report_header.capitalize() if report_header != "" else ""
	if _respite != null:
		_respite.text = "A respite before Segment %d." % seg if not embedded else "The courtyard waits beyond the stall."
	_set_ledger_row("ROUTE", "Area 1 · Segment %d" % seg)
	_set_ledger_row("FOLLOWERS", ExchangeStyle.grouped(fol))
	_set_ledger_row("WORN GEAR", "%d / %d" % [gear_count, Inventory.SLOT_COUNT])
	_set_ledger_row("BACKPACK", "%d / %d" % [bag_count, bag_capacity])
	if _notices != null:
		for child in _notices.get_children():
			child.queue_free()
		if Global != null and Global.pending_augment_pick:
			_notices.add_child(_notice("BINDING READY", "An augment Binding opens the next segment."))
		if Global != null and Global.pending_big_choice:
			_notices.add_child(_notice("DOCTRINE READY", "An Ascension thesis awaits inscription."))
	if _purse != null and _purse.has_method("set_value"):
		_purse.call("set_value", fol, true)
	_refresh_goods_counts()


func _set_ledger_row(caption: String, value: String) -> void:
	if _ledger == null:
		return
	var label := _ledger_rows.get(caption, null) as Label
	if label == null:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cap := Label.new()
		cap.theme_type_variation = &"ArcaneCaption"
		cap.add_theme_font_size_override(&"font_size", 13)
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cap.text = caption
		row.add_child(cap)
		label = Label.new()
		label.theme_type_variation = &"ArcaneBody"
		label.add_theme_color_override(&"font_color", ExchangeStyle.PARCHMENT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(label)
		_ledger.add_child(row)
		_ledger_rows[caption] = label
	if label.text != value:
		label.text = value


func _notice(caption: String, body: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	var cap := Label.new()
	cap.theme_type_variation = &"ArcaneCaption"
	cap.add_theme_color_override(&"font_color", ExchangeStyle.EMBER)
	cap.add_theme_font_size_override(&"font_size", 13)
	cap.text = "◆  " + caption
	box.add_child(cap)
	var line := Label.new()
	line.theme_type_variation = &"ArcaneItalic"
	line.add_theme_font_size_override(&"font_size", 16)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.text = body
	box.add_child(line)
	return box


func _refresh_goods_counts() -> void:
	if _equipped_count_label != null:
		_equipped_count_label.text = "%d / %d" % [_equipped_count(), Inventory.SLOT_COUNT]
	if _backpack_count_label != null:
		_backpack_count_label.text = "%d / %d" % [_backpack_count(), _backpack_capacity()]
	if _bag_worth != null:
		var worth := 0
		if Global != null and Global.run_bag != null:
			for inst: ItemInstance in Global.run_bag.slots:
				if inst != null and not inst.locked:
					worth += _sell_value(inst)
		_bag_worth.text = "The Exchanger would weigh your pack at %s Followers." % ExchangeStyle.grouped(worth) if worth > 0 else "Nothing in the pack to weigh."


func _refresh_stock_count() -> void:
	if _stock_count == null or _vendor_bag == null:
		return
	var lots := 0
	var shown := 0
	for i in range(_vendor_bag.slots.size()):
		if _vendor_bag.slots[i] != null:
			lots += 1
			var c := vendor_grid.get_slot_control(i) if vendor_grid != null else null
			if c != null and c.visible:
				shown += 1
	var text := "%d LOT%s ON THE SHELF" % [lots, "" if lots == 1 else "S"]
	if shown != lots:
		text = "%d OF %d LOTS SHOWN" % [shown, lots]
	_stock_count.text = text


# ---- the Balance ----

func _refresh_balance_view(sell_v: int, buy_v: int, followers: int, after: int, valid: bool) -> void:
	if _scale != null and _scale.has_method("set_totals"):
		_scale.call("set_totals", sell_v, buy_v, is_node_ready())
	if _reckon_now != null:
		_reckon_now.call("set_value", followers, true)
	if _reckon_after != null:
		_reckon_after.call("set_value", after, true)
		var col := ExchangeStyle.GOLD_BRIGHT
		if after < 0:
			col = ExchangeStyle.DANGER.lightened(0.2)
		elif after < followers:
			col = ExchangeStyle.EMBER
		_reckon_after.call("set_colour", col)
	if _reckon_net != null:
		var net := buy_v - sell_v
		var line := "Nothing changes hands yet."
		if sell_v == 0 and buy_v == 0:
			line = "The scales stand empty."
		elif net > 0:
			line = "%s Followers committed to the exchange." % ExchangeStyle.grouped(net)
		elif net < 0:
			line = "A net gain of %s Followers." % ExchangeStyle.grouped(-net)
		else:
			line = "An even trade."
		if not valid and after < 0:
			line = "The pans do not balance: %s more Followers needed." % ExchangeStyle.grouped(-after)
		_reckon_net.text = line
	_refresh_goods_counts()


func _draw_divider() -> void:
	if _divider == null:
		return
	var x := _divider.size.x * 0.5
	var top := 28.0
	var bottom := _divider.size.y - 6.0
	var steps := 16
	for i in range(steps):
		var a := float(i) / steps
		var b := float(i + 1) / steps
		var fade := clampf(minf(a, 1.0 - b) * 5.0, 0.0, 1.0)
		_divider.draw_line(Vector2(x, lerpf(top, bottom, a)), Vector2(x, lerpf(top, bottom, b)), Color(ExchangeStyle.GOLD_DIM, 0.6 * fade), 1.0, true)
	var c := Vector2(x, (top + bottom) * 0.5)
	var pts := ExchangeStyle.diamond(c, 5.0)
	_divider.draw_colored_polygon(pts, Color(0.04, 0.034, 0.03))
	pts.append(pts[0])
	_divider.draw_polyline(pts, ExchangeStyle.GOLD, 1.2, true)
	_divider.draw_colored_polygon(ExchangeStyle.diamond(c, 1.8), ExchangeStyle.GOLD)
	for dir: float in [-1.0, 1.0]:
		var tip := c + Vector2(dir * 18.0, 0)
		_divider.draw_line(tip, tip + Vector2(-dir * 5.0, -4.0), Color(ExchangeStyle.GOLD_DIM, 0.8), 1.0, true)
		_divider.draw_line(tip, tip + Vector2(-dir * 5.0, 4.0), Color(ExchangeStyle.GOLD_DIM, 0.8), 1.0, true)


## Hangs each pan of the scales over its grid.
func _sync_scale_arm() -> void:
	if _scale == null or offer_grid == null or demand_grid == null:
		return
	var left := offer_grid.get_global_rect().get_center().x
	var right := demand_grid.get_global_rect().get_center().x
	if right - left < 10.0:
		return
	_scale.set("arm", (right - left) * 0.5)


## The trade is sealed: a star flares over the beam, the Balance's frame
## warms and fades, the Exchanger's lamp brightens and the purse counts to
## its new figure (that last through _refresh_info).
func _celebrate_trade() -> void:
	if not is_inside_tree():
		return
	var at := _ctrl_center(btn_barter_cart)
	if _scale != null:
		var r := _scale.get_global_rect()
		at = Vector2(r.get_center().x, r.position.y + 30.0)
		if _scale.has_method("flash"):
			_scale.call("flash")
	if _flare != null and _flare.has_method("burst"):
		_flare.call("burst", at, 1.0)
	if _portrait != null and _portrait.has_method("brighten"):
		_portrait.call("brighten")
	var frame := _panel_frames.get("CartPanel", null) as Control
	if frame != null:
		var tw := frame.create_tween().set_ignore_time_scale(true)
		tw.tween_property(frame, "glow", 1.0, 0.12)
		tw.tween_property(frame, "glow", 0.12, 0.9 if not ArcaneMotion.reduced() else 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ---- slot dressing and fitting ----

func _on_gear_hover(slot: int, on: bool) -> void:
	if on:
		_gear_hover = slot
	elif _gear_hover == slot:
		_gear_hover = -1
	_style_gear_slots()


## The worn-gear sockets: filled, empty or under the cursor. A style is set
## only when a slot's state changes.
func _style_gear_slots() -> void:
	if inv_bar == null or _gear_styled.is_empty():
		return
	var reserved: Dictionary = _sell_inv if (chk_include_equipped != null and chk_include_equipped.button_pressed) else {}
	for i in range(mini(_gear_styled.size(), Inventory.SLOT_COUNT)):
		var c := inv_bar.get_slot_control(i)
		if c == null:
			continue
		var inst: ItemInstance = Global.run_inventory.get_at(i) if Global != null and Global.run_inventory != null else null
		var filled := inst != null and not reserved.has(i)
		var state: int = ExchangeStyle.Slot.FILLED if filled else ExchangeStyle.Slot.EMPTY
		if filled and _gear_hover == i:
			state = ExchangeStyle.Slot.HOVER
		if _gear_styled[i] == state:
			continue
		_gear_styled[i] = state
		c.add_theme_stylebox_override(&"panel", ExchangeStyle.slot(state))


func _queue_fit_grids() -> void:
	if _fit_pending or not is_inside_tree():
		return
	_fit_pending = true
	call_deferred("_fit_grids")


## Sizes the backpack and the stock to the room their panels are given, so
## a grown satchel or a long shelf shrinks its slots instead of spilling out.
## The room is worked out from the screen, not from the panels' current
## size, which an overflowing grid would already have stretched.
func _fit_grids() -> void:
	_fit_pending = false
	var root := get_node_or_null("Root") as MarginContainer
	if root == null:
		return
	var body_h := size.y - float(root.get_theme_constant(&"margin_top")) - float(root.get_theme_constant(&"margin_bottom"))
	if bag_grid != null:
		var bag_panel := get_node_or_null("Root/HBox/Backpack") as Control
		var eq_panel := get_node_or_null("Root/HBox/Equipped") as Control
		if bag_panel != null:
			var allotted := body_h - (eq_panel.get_combined_minimum_size().y + 14.0 if eq_panel != null else 0.0)
			var others := bag_panel.get_combined_minimum_size().y - bag_grid.get_combined_minimum_size().y
			var room := Vector2((bag_grid.get_parent() as Control).size.x, allotted - others - 4.0)
			bag_grid.fit_within(room, bag_grid.slot_count, 80.0, 44.0, 4, 6)
	if vendor_grid != null:
		var vendor_panel := get_node_or_null("Root/HBox/Vendor") as Control
		var shown := 0
		for i in range(vendor_grid.slot_count):
			var c := vendor_grid.get_slot_control(i)
			if c != null and c.visible:
				shown += 1
		if vendor_panel != null:
			var vothers := vendor_panel.get_combined_minimum_size().y - vendor_grid.get_combined_minimum_size().y
			var vroom := Vector2((vendor_grid.get_parent() as Control).size.x, body_h - vothers - 4.0)
			vendor_grid.fit_within(vroom, maxi(shown, 8), 86.0, 40.0, 4, 7)
	if offer_grid != null and demand_grid != null and _grids_box != null:
		var half := (_grids_box.size.x - (_divider.custom_minimum_size.x if _divider != null else 0.0)) * 0.5
		for p: ShopBagGrid in [offer_grid, demand_grid]:
			p.fit_within(Vector2(half, 4.0 * 66.0 + 3.0 * p.gap), 16, 66.0, 44.0, 4, 4)
	_sync_scale_arm.call_deferred()


## The Exchange's seal, faint in the ledger's empty middle: two rings, a
## balance beam across them, a diamond at the heart. Drawn once per resize.
func _draw_seal(host: Control) -> void:
	if host.size.y < 110.0:
		return
	var c := host.size * 0.5
	var r := minf(58.0, host.size.y * 0.34)
	var col := Color(ExchangeStyle.GOLD_DIM, 0.32)
	host.draw_arc(c, r, 0.0, TAU, 72, col, 1.0, true)
	host.draw_arc(c, r * 0.8, 0.0, TAU, 72, Color(col, col.a * 0.7), 1.0, true)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var d := Vector2(cos(a), sin(a))
		host.draw_line(c + d * r, c + d * (r + (7.0 if i % 2 == 0 else 4.0)), col, 1.0, true)
	var beam := r * 0.62
	host.draw_line(c + Vector2(-beam, -r * 0.18), c + Vector2(beam, -r * 0.18), col, 1.2, true)
	host.draw_line(c + Vector2(0, -r * 0.18), c + Vector2(0, r * 0.5), col, 1.0, true)
	for side: float in [-1.0, 1.0]:
		var hook := c + Vector2(side * beam, -r * 0.18)
		host.draw_line(hook, hook + Vector2(-9, 18), Color(col, col.a * 0.8), 1.0, true)
		host.draw_line(hook, hook + Vector2(9, 18), Color(col, col.a * 0.8), 1.0, true)
		host.draw_line(hook + Vector2(-11, 18), hook + Vector2(11, 18), col, 1.0, true)
	var pts := ExchangeStyle.diamond(c + Vector2(0, -r * 0.18), 4.0)
	host.draw_colored_polygon(pts, Color(ExchangeStyle.GOLD, 0.45))
	host.draw_line(c + Vector2(-14, r * 0.5), c + Vector2(14, r * 0.5), col, 1.0, true)
