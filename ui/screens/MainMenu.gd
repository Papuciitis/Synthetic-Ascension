extends Control
## The front door: the painted threshold (the main-menu mock-up), an
## understated menu on its dark side, and a world that answers the selection.
## Continue resumes the most recently saved chronicle; New Run and Archives
## both open the Archives (SaveSelect), New Run on the first free slot.
## Developer Mode (debug builds only) unfolds the dev-start panel.

const SETTINGS_SCENE := preload("res://ui/screens/settings/SettingsScreen.tscn")
const SAVE_SELECT := preload("res://ui/screens/SaveSelect.gd")
const FLARE := preload("res://assets/ui/menu/flare_star.png")
const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")
const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

## How long the title takes to be drawn on (title_sheen.gdshader).
const TITLE_DRAW_SECONDS := 3.6

## Title-logo pixels of the stars painted into title_logo.png, which twinkle.
const TITLE_STARS: Array[Vector2] = [Vector2(290, 33), Vector2(291, 344), Vector2(449, 122)]

@onready var backdrop: ArcaneBackdrop = $Backdrop
@onready var title: TextureRect = $Title
@onready var menu: VBoxContainer = $Menu
@onready var curtain: ColorRect = $Curtain
@onready var version_label: Label = $Version
@onready var btn_continue: ArcaneMenuItem = $Menu/Continue
@onready var btn_new_run: ArcaneMenuItem = $Menu/NewRun
@onready var btn_archives: ArcaneMenuItem = $Menu/Archives
@onready var btn_settings: ArcaneMenuItem = $Menu/Settings
@onready var btn_quit: ArcaneMenuItem = $Menu/Quit

var _settings_screen: Control
var _twinkles: Array[Dictionary] = []
var _t := 0.0
## How far the title's draw-on has got (0..1.1); the star glints wait for it.
var _title_draw := 1.1

# Developer mode UI
@onready var chk_dev: ArcaneMenuItem = $Menu/DevMode
@onready var dev_panel: Control = $DevPanel
@onready var spin_segment: SpinBox = $DevPanel/Pad/Margin/VBox/RowSegment/Segment
@onready var opt_race: OptionButton = $DevPanel/Pad/Margin/VBox/RowRace/Race
@onready var opt_style: OptionButton = $DevPanel/Pad/Margin/VBox/RowStyle/Style
@onready var opt_loadout: OptionButton = $DevPanel/Pad/Margin/VBox/RowWeapon/Weapon
@onready var spin_rarity: SpinBox = $DevPanel/Pad/Margin/VBox/RowRarity/Rarity
@onready var edit_seed: LineEdit = $DevPanel/Pad/Margin/VBox/RowSeed/Seed
@onready var chk_force_aug: CheckBox = $DevPanel/Pad/Margin/VBox/ForceAug
@onready var chk_force_major: CheckBox = $DevPanel/Pad/Margin/VBox/ForceMajor
@onready var chk_force_enemy_intros: CheckBox = $DevPanel/Pad/Margin/VBox/ForceEnemyIntros
@onready var btn_reset_enemy_intros: Button = $DevPanel/Pad/Margin/VBox/ResetEnemyIntros
@onready var btn_start_dev: Button = $DevPanel/Pad/Margin/VBox/StartDev
@onready var btn_grant_augments: Button = $DevPanel/Pad/Margin/VBox/GrantAugments
@onready var btn_start_dev_hub: Button = $DevPanel/Pad/Margin/VBox/StartDevHub
@onready var btn_start_dev_segment: Button = $DevPanel/Pad/Margin/VBox/StartDevSegment


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
	btn_new_run.pressed.connect(_on_new_run_pressed)
	btn_archives.pressed.connect(_on_archives_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	for item in _menu_items():
		item.selected.connect(_on_item_selected)

	var version := String(ProjectSettings.get_setting("application/config/version", ""))
	version_label.text = ("v" + version) if version != "" else ""

	# Dev mode: the whole entry point (segment jump, free loadouts, follower
	# grants) disappears in release exports.
	chk_dev.visible = OS.is_debug_build()
	chk_dev.focus_mode = Control.FOCUS_ALL if chk_dev.visible else Control.FOCUS_NONE
	dev_panel.visible = false
	_set_dev_label(false)
	chk_dev.toggled.connect(func(on: bool) -> void:
		dev_panel.visible = on
		_set_dev_label(on)
		if on:
			_populate_dev_lists()
			_reveal_dev_panel()
	)
	btn_start_dev.pressed.connect(_on_start_dev_pressed)
	btn_reset_enemy_intros.pressed.connect(_on_reset_enemy_intros_pressed)
	if btn_grant_augments != null:
		btn_grant_augments.pressed.connect(_dev_grant_test_augments)

	btn_start_dev_hub.pressed.connect(_on_start_dev_hub_pressed)
	btn_start_dev_segment.pressed.connect(_on_start_dev_segment_pressed)

	_build_twinkles()
	resized.connect(_fit_layout)
	_fit_layout()
	_play_intro()


func _menu_items() -> Array[ArcaneMenuItem]:
	var items: Array[ArcaneMenuItem] = []
	for child in menu.get_children():
		if child is ArcaneMenuItem:
			items.append(child as ArcaneMenuItem)
	return items


func _on_item_selected(item: ArcaneMenuItem) -> void:
	backdrop.set_mood(item.mood)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _settings_screen != null and is_instance_valid(_settings_screen) and _settings_screen.visible:
		return
	get_viewport().set_input_as_handled()
	if dev_panel.visible:
		chk_dev.button_pressed = false
		chk_dev.grab_focus()
		return
	# Escape walks to Quit first; a second press does not quit by itself.
	btn_quit.grab_focus()


func _process(delta: float) -> void:
	_t += delta
	var still := ArcaneMotion.reduced()
	for twinkle in _twinkles:
		var node := twinkle["node"] as TextureRect
		var phase := fmod(_t + float(twinkle["offset"]), float(twinkle["period"])) / float(twinkle["period"])
		# A short glint once per period, a faint glow otherwise; under reduced
		# motion only the light changes, never the size or the angle.
		var glint := pow(maxf(0.0, sin(phase * PI)), 18.0)
		var lit := clampf((_title_draw - 0.92) / 0.1, 0.0, 1.0)
		node.modulate.a = (0.18 + glint * 0.82) * lit
		node.scale = Vector2.ONE * (0.8 if still else 0.55 + glint * 0.6)
		node.rotation = 0.0 if still else glint * 0.35


## The layout authored for 1080 lines; at a large UI Scale (a shorter logical
## viewport) the menu keeps its place above the bottom edge and the title shrinks
## to the room left above it, so every entry stays on screen.
const MENU_TOP := 522.0
const TITLE_RECT := Rect2(104, 40, 680, 445)


func _fit_layout() -> void:
	var menu_h := menu.get_combined_minimum_size().y
	var menu_top := minf(MENU_TOP, size.y - 96.0 - menu_h)
	menu.position = Vector2(menu.position.x, maxf(menu_top, 150.0))
	var title_h := clampf(menu.position.y - TITLE_RECT.position.y - 24.0, 120.0, TITLE_RECT.size.y)
	var title_w := title_h * TITLE_RECT.size.x / TITLE_RECT.size.y
	title.position = TITLE_RECT.position
	title.size = Vector2(title_w, title_h)
	dev_panel.size.y = minf(834.0, size.y - dev_panel.position.y - 24.0)
	dev_panel.position.x = minf(820.0, size.x - dev_panel.size.x - 24.0)
	_place_twinkles()


func _place_twinkles() -> void:
	if title.texture == null:
		return
	var tex_size := title.texture.get_size()
	var shown := title.size
	var k := minf(shown.x / tex_size.x, shown.y / tex_size.y)
	var offset := (shown - tex_size * k) * 0.5
	for twinkle in _twinkles:
		var node := twinkle["node"] as TextureRect
		node.size = Vector2.ONE * float(twinkle["size"]) * (k / (680.0 / 574.0))
		node.pivot_offset = node.size * 0.5
		node.position = offset + TITLE_STARS[int(twinkle["star"])] * k - node.size * 0.5


## Glints on the stars painted into the title.
func _build_twinkles() -> void:
	if title.texture == null:
		return
	var periods := [5.3, 6.1, 4.4]
	for i in range(TITLE_STARS.size()):
		var flare := TextureRect.new()
		flare.texture = FLARE
		flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flare.material = ArcaneParticles.additive()
		flare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flare.self_modulate = Color(1.0, 0.86, 0.6)
		title.add_child(flare)
		_twinkles.append({"node": flare, "period": periods[i], "offset": float(i) * 1.7, "star": i, "size": 74.0 if i < 2 else 58.0})
	_place_twinkles()


func _play_intro() -> void:
	var reduced := backdrop.reduced_motion
	curtain.visible = true
	curtain.color.a = 1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(curtain, "color:a", 0.0, 0.6 if reduced else 1.4).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func() -> void: curtain.visible = false)
	var title_mat := title.material as ShaderMaterial
	if title_mat != null:
		# Drawn on, line by line; under reduced motion it is simply there as the
		# curtain lifts.
		_set_title_draw(title_mat, 1.1 if reduced else 0.0)
		if not reduced:
			var drawing := create_tween()
			drawing.tween_interval(0.3)
			drawing.tween_method(func(v: float) -> void: _set_title_draw(title_mat, v), 0.0, 1.1, TITLE_DRAW_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var ember := create_tween().set_loops()
		ember.tween_method(func(v: float) -> void: title_mat.set_shader_parameter("ember", v), 0.0, 1.0, 3.2).set_trans(Tween.TRANS_SINE)
		ember.tween_method(func(v: float) -> void: title_mat.set_shader_parameter("ember", v), 1.0, 0.0, 3.2).set_trans(Tween.TRANS_SINE)
	var delay := 0.75
	for child in menu.get_children():
		var item := child as Control
		if item == null or not item.visible:
			continue
		item.modulate.a = 0.0
		var stagger := create_tween()
		stagger.tween_interval(delay)
		stagger.tween_property(item, "modulate:a", 1.0, 0.45)
		delay += 0.0 if reduced else 0.07
	# The first selection lands as Continue fades in, so its stroke wipes in
	# and its star flares as the menu arrives.
	var first := create_tween()
	first.tween_interval(0.0 if reduced else 0.8)
	first.tween_callback(func() -> void:
		if get_viewport().gui_get_focus_owner() == null:
			btn_continue.select_quietly()
	)


func _set_title_draw(title_mat: ShaderMaterial, v: float) -> void:
	_title_draw = v
	title_mat.set_shader_parameter("draw", v)


func _reveal_dev_panel() -> void:
	dev_panel.modulate.a = 0.0
	dev_panel.pivot_offset = Vector2(0, dev_panel.size.y * 0.5)
	var still := ArcaneMotion.reduced()
	dev_panel.scale = Vector2.ONE if still else Vector2(0.97, 0.97)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dev_panel, "modulate:a", 1.0, 0.22)
	if not still:
		tw.tween_property(dev_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_dev_label(on: bool) -> void:
	chk_dev.set_caption("DEVELOPER MODE  ·  OPEN" if on else "DEVELOPER MODE")


func _on_continue_pressed() -> void:
	# Resume the most recently written readable save; with none, open the
	# Archives so a chronicle can begin.
	var best_slot := -1
	var best_save: SaveData = null
	var best_time := -1
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var s: SaveData = SaveManager.load_slot(slot)
		if s == null:
			continue
		var written := s.updated_unix if s.updated_unix > 0 else int(SaveManager.slot_modified_time(slot))
		if written > best_time:
			best_time = written
			best_slot = slot
			best_save = s

	# Defer to avoid changing scenes mid-callback
	if best_save != null:
		SaveManager.set_current(best_slot, best_save)
		call_deferred("_go_to_base")
	else:
		SAVE_SELECT.open_intent = &"new"
		call_deferred("_go_to_saves")


func _on_new_run_pressed() -> void:
	SAVE_SELECT.open_intent = &"new"
	call_deferred("_go_to_saves")


func _on_archives_pressed() -> void:
	SAVE_SELECT.open_intent = &"browse"
	call_deferred("_go_to_saves")


func _on_settings_pressed() -> void:
	if _settings_screen == null or not is_instance_valid(_settings_screen):
		_settings_screen = SETTINGS_SCENE.instantiate() as Control
		_settings_screen.call("configure", SettingsManager)
		_settings_screen.connect("closed", _on_settings_closed)
		add_child(_settings_screen)
	_set_menu_dimmed(true)
	_settings_screen.call("open")


func _on_settings_closed() -> void:
	_set_menu_dimmed(false)
	btn_settings.call_deferred("grab_focus")


## While Settings is up the painting stays, the words step back: no caption is
## left half-cut beside the panel, and nothing behind it can take focus.
func _set_menu_dimmed(dimmed: bool) -> void:
	var to := 0.0 if dimmed else 1.0
	var tw := create_tween().set_parallel(true)
	for node: CanvasItem in [title, menu, version_label, dev_panel]:
		tw.tween_property(node, "modulate:a", to, 0.18)
	for item in _menu_items():
		item.focus_mode = Control.FOCUS_NONE if dimmed else Control.FOCUS_ALL
	if not OS.is_debug_build():
		chk_dev.focus_mode = Control.FOCUS_NONE


func _on_quit_pressed() -> void:
	Global.request_quit()


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
		Global.attempt_pending_doctrine_stage = &"apotheosis" if seg >= 10 else (&"doctrine" if seg >= 7 else &"method")
		Global.attempt_major_choice_offer_ids.clear()
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
		Global.attempt_pending_doctrine_stage = &"apotheosis" if seg >= 10 else (&"doctrine" if seg >= 7 else &"method")
		Global.attempt_major_choice_offer_ids.clear()
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
		if btn_grant_augments != null:
			btn_grant_augments.text = "Test Augments Granted"
