extends Control

@onready var btn_continue: Button = $Center/Panel/Padding/VBox/Continue
@onready var btn_saves: Button = $Center/Panel/Padding/VBox/Saves
@onready var btn_quit: Button = $Center/Panel/Padding/VBox/Quit

# Developer mode UI
@onready var chk_dev: CheckBox = $Center/Panel/Padding/VBox/DevMode
@onready var dev_panel: Control = $Center/Panel/Padding/VBox/DevPanel
@onready var spin_segment: SpinBox = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/RowSegment/Segment
@onready var opt_race: OptionButton = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/RowRace/Race
@onready var opt_style: OptionButton = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/RowStyle/Style
@onready var opt_loadout: OptionButton = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/RowWeapon/Weapon
@onready var spin_rarity: SpinBox = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/RowRarity/Rarity
@onready var edit_seed: LineEdit = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/RowSeed/Seed
@onready var chk_force_aug: CheckBox = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/ForceAug
@onready var chk_force_major: CheckBox = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/ForceMajor
@onready var chk_force_enemy_intros: CheckBox = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/ForceEnemyIntros
@onready var btn_reset_enemy_intros: Button = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/ResetEnemyIntros
@onready var btn_start_dev: Button = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/StartDev
@onready var btn_grant_augments: Button = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/GrantAugments
@onready var btn_start_dev_hub: Button = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/StartDevHub
@onready var btn_start_dev_segment: Button = $Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/StartDevSegment


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Global.debug_force_enemy_introductions = false
	Global.debug_projectile_stress_test = false
	Global.debug_set_collision_tools = false
	Global.debug_performance_lab = false
	Global.debug_dev_mode = false
	Global.debug_dev_segment = false
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.set_enabled(false)
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("to_menu")

	btn_continue.pressed.connect(_on_continue_pressed)
	btn_saves.pressed.connect(_on_saves_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	# Dev mode
	dev_panel.visible = false
	_set_dev_label(false)
	chk_dev.toggled.connect(func(on: bool) -> void:
		dev_panel.visible = on
		_set_dev_label(on)
		if on:
			_populate_dev_lists()
	)
	btn_start_dev.pressed.connect(_on_start_dev_pressed)
	btn_reset_enemy_intros.pressed.connect(_on_reset_enemy_intros_pressed)
	if btn_grant_augments != null:
		btn_grant_augments.pressed.connect(_dev_grant_test_augments)

	btn_start_dev_hub.pressed.connect(_on_start_dev_hub_pressed)
	btn_start_dev_segment.pressed.connect(_on_start_dev_segment_pressed)

func _set_dev_label(on: bool) -> void:
	# Keeps the dev panel compact + readable as it grows.
	chk_dev.text = "Developer Mode ▲" if on else "Developer Mode ▼"

func _on_continue_pressed() -> void:
	# If any save exists, go to Base (continue); otherwise go to SaveSelect
	var has_any_save := false
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var s: SaveData = SaveManager.load_slot(slot)
		if s != null:
			SaveManager.set_current(slot, s)
			has_any_save = true
			break

	# Defer to avoid changing scenes mid-callback
	if has_any_save:
		call_deferred("_go_to_base")
	else:
		call_deferred("_go_to_saves")


func _on_saves_pressed() -> void:
	call_deferred("_go_to_saves")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _go_to_saves() -> void:
	get_tree().paused = false
	Global.goto_save_select()


func _go_to_base() -> void:
	get_tree().paused = false
	Global.goto_resume()


func _populate_dev_lists() -> void:
	# Races / Styles / Weapons are already loaded by Global's DB scan.
	_fill_option_from_db(opt_race, Global.race_db, Global.selected_race_id)
	_fill_option_from_db(opt_style, Global.style_db, Global.selected_style_id)
	_fill_loadout_options(opt_loadout)

	# Segment default to current attempt, clamped
	var seg := clampi(Global.attempt_segment, 1, 10)
	spin_segment.value = float(seg)


func _fill_option_from_db(opt: OptionButton, db: Dictionary, current_id: String) -> void:
	opt.clear()

	var entries: Array[Dictionary] = []
	for k in db.keys():
		var id := String(k)
		var res: Variant = db[k]
		var label := id

		if res != null and res is Object:
			var dn: Variant = (res as Object).get("display_name")
			if dn != null and String(dn) != "":
				label = String(dn)

		entries.append({"id": id, "name": label})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]).to_lower() < String(b["name"]).to_lower()
	)

	var select_index := -1
	for e in entries:
		var idx := opt.item_count
		opt.add_item(String(e["name"]))
		opt.set_item_metadata(idx, String(e["id"]))
		if String(e["id"]) == current_id:
			select_index = idx

	if select_index >= 0:
		opt.select(select_index)
	elif opt.item_count > 0:
		opt.select(0)


func arm_developer_flight_recorder() -> void:
	PerformanceFlightRecorder.set_enabled(true)


func _on_start_dev_pressed(performance_capture: bool = false) -> void:
	var seg := clampi(int(spin_segment.value), 1, 10)

	var race_id := _get_opt_id(opt_race, Global.selected_race_id)
	var style_id := _get_opt_id(opt_style, Global.selected_style_id)
	var loadout_id := _get_opt_id(opt_loadout, "none")
	var rarity := clampi(int(spin_rarity.value), 0, 10)
	# Weapon is currently the same as Style in your project; keep it aligned.
	var weapon_id := style_id

	# Start a fresh attempt (doesn't require an active save slot)
	Global.start_new_attempt()

	# Override player setup
	Global.selected_race_id = race_id
	Global.selected_style_id = style_id
	Global.selected_weapon_id = weapon_id

	# Jump into any segment for testing
	Global.attempt_segment = seg

	# Optional seed override
	var seed_txt := edit_seed.text.strip_edges()
	if seed_txt != "" and seed_txt.is_valid_int():
		Global.attempt_world_seed = int(seed_txt)

	# Optional flags for UI testing
	if chk_force_aug.button_pressed:
		Global.pending_augment_pick = true
	if chk_force_major.button_pressed:
		Global.pending_big_choice = true
	Global.debug_force_enemy_introductions = chk_force_enemy_intros.button_pressed
	Global.debug_dev_mode = true
	Global.debug_projectile_stress_test = false
	Global.debug_performance_lab = performance_capture
	arm_developer_flight_recorder()
	Global.debug_set_collision_tools = false

	# Dev loadout (optional)
	if loadout_id != "none":
		_dev_grant_loadout(loadout_id, rarity)

	# Go straight into the run
	get_tree().paused = false
	Global.goto_game()


func _on_start_dev_segment_pressed() -> void:
	Global.debug_dev_segment = true
	_on_start_dev_pressed(true)


func _on_start_dev_hub_pressed() -> void:
	var seg := clampi(int(spin_segment.value), 1, 10)

	var race_id := _get_opt_id(opt_race, Global.selected_race_id)
	var style_id := _get_opt_id(opt_style, Global.selected_style_id)
	var loadout_id := _get_opt_id(opt_loadout, "none")
	var rarity := clampi(int(spin_rarity.value), 0, 10)

	# Weapon is currently the same as Style in your project; keep it aligned.
	var weapon_id := style_id

	# Start a fresh attempt
	Global.start_new_attempt()

	# Override player setup
	Global.selected_race_id = race_id
	Global.selected_style_id = style_id
	Global.selected_weapon_id = weapon_id

	# Start testing from any segment
	Global.attempt_segment = seg

	# Optional seed override
	var seed_txt := edit_seed.text.strip_edges()
	if seed_txt != "" and seed_txt.is_valid_int():
		Global.attempt_world_seed = int(seed_txt)

	# Optional flags for UI testing
	if chk_force_aug.button_pressed:
		Global.pending_augment_pick = true
	if chk_force_major.button_pressed:
		Global.pending_big_choice = true
	Global.debug_force_enemy_introductions = chk_force_enemy_intros.button_pressed
	Global.debug_dev_mode = true
	Global.debug_projectile_stress_test = false
	Global.debug_performance_lab = false
	arm_developer_flight_recorder()
	Global.debug_set_collision_tools = false

	# Dev loadout (optional) so you have stuff to sell
	if loadout_id != "none":
		_dev_grant_loadout(loadout_id, rarity)

	# Give enough followers to actually test buying
	Global.transaction_followers(200 - Global.followers, &"developer_grant", {}, false, false)

	# Go straight into Hub
	get_tree().paused = false
	if SaveManager != null and SaveManager.current_save != null:
		SaveManager.current_save.attempt_resume_scene = Global.PATH_HUB_SHOP
	Global.goto_hub_shop()

func _on_reset_enemy_intros_pressed() -> void:
	Global.reset_enemy_discoveries()
	btn_reset_enemy_intros.text = "Enemy Introductions Reset"


func _get_opt_id(opt: OptionButton, fallback: String) -> String:
	if opt.item_count <= 0:
		return fallback
	var md: Variant = opt.get_item_metadata(opt.selected)
	if md == null:
		return fallback
	var s := String(md)
	return s if s != "" else fallback


# ------------------------------------------------------------
# Dev Mode: Loadouts (repurposes the old "Weapon" row)
# ------------------------------------------------------------

func _fill_loadout_options(opt: OptionButton) -> void:
	opt.clear()

	# id -> display label
	var options: Array[Dictionary] = [
		{"id": "none", "label": "None"},
		{"id": "accessories", "label": "Accessories"},
		{"id": "conduit", "label": "Conduit Set"},
		{"id": "lattice", "label": "Lattice Set"},
		{"id": "gravemarch", "label": "Gravemarch Set"},
		{"id": "prototype", "label": "Prototype Relic"},
	]

	for e: Dictionary in options:
		var idx: int = opt.item_count
		opt.add_item(String(e["label"]))
		opt.set_item_metadata(idx, String(e["id"]))

	# Default selection: None
	if opt.item_count > 0:
		opt.select(0)


func _dev_grant_loadout(loadout_id: String, rarity: int) -> void:
	var ids: Array[String] = _dev_loadout_items(loadout_id)
	for item_id: String in ids:
		_dev_grant_item(item_id, rarity)


func _dev_loadout_items(loadout_id: String) -> Array[String]:
	# IMPORTANT: These IDs must match ItemData.id keys in Global.item_db
	match loadout_id:
		"accessories":
			return ["acc_firestone", "acc_oakheart", "ring_crusher", "ring_regeneration"]
		"conduit":
			return [
				"conduit_actuators",
				"conduit_charm",
				"conduit_greaves",
				"conduit_heart",
				"conduit_lens",
				"conduit_plating",
			]
		"lattice":
			return [
				"lattice_fingerprint",
				"lattice_focusnode",
				"lattice_pulsecoil",
				"lattice_shellplate",
				"lattice_strideframe",
				"lattice_tickspurs",
			]
		"gravemarch":
			return [
				"gravemarch_bonekey",
				"gravemarch_carapace",
				"gravemarch_censer",
				"gravemarch_clockjaw",
				"gravemarch_stompers",
				"gravemarch_vessel",
			]
		"prototype":
			# A single "super" item for quick testing.
			return ["ring_crusher"]
		_:
			return []


func _dev_grant_item(item_id: String, rarity: int) -> void:
	var db: Dictionary = Global.item_db
	var d: ItemData = db.get(item_id, null) as ItemData
	if d == null:
		push_warning("Dev loadout: item_id not found: " + item_id)
		return

	# Roll an instance at the selected rarity (positive polarity).
	var inst: ItemInstance = ItemInstance.from_roll(d, rarity, 1, 0.45)

	# Prefer equipping if the slot is empty; otherwise, put in bag.
	var inv: Inventory = Global.run_inventory as Inventory
	var bag: BagInventory = Global.run_bag as BagInventory

	if inv != null and int(d.equip_slot) >= 0 and int(d.equip_slot) < Inventory.SLOT_COUNT:
		var slot: int = int(d.equip_slot)
		if inv.is_slot_empty(slot):
			inv.set_item(slot, inst, {"type": Inventory.UIOriginType.SCREEN, "pos": Vector2.ZERO})
			return

	if bag != null:
		bag.add_instance(inst)

func _dev_grant_test_augments() -> void:
	if Global == null:
		return
	if Global.has_method("dev_grant_test_augments"):
		Global.dev_grant_test_augments()
		# feedback in UI
		if chk_dev != null:
			chk_dev.text = "Developer Mode ▲ (Augments granted)" if chk_dev.button_pressed else "Developer Mode ▼ (Augments granted)"
