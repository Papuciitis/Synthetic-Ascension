extends Node
## Renders the in-run "chambers" to PNGs with real fixtures (needs a display,
## not --headless): the augment library with owned and bound augments, the
## Ascension Doctrine with a pending stage and its three plates, Gear & Stash
## with worn, carried and kept items, and the Game Over moment over a frozen
## world. A throwaway attempt with no current save, so nothing is written to
## the player's slots.
## Run: <godot> --path . res://tools/dev/ChambersShotProbe.tscn -- --out=/abs/dir [--only=library|major|stash|gameover] [--reduced]

const WORLD := preload("res://assets/ui/menu/threshold_backdrop.jpg")

var _out := "/tmp"
var _only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg == "--reduced" and SettingsManager != null and SettingsManager.has_method("set_value"):
			SettingsManager.call("set_value", &"accessibility", &"reduced_motion", true, false)
	DirAccess.make_dir_recursive_absolute(_out)
	SaveManager.current_save = null
	if not Global.attempt_active:
		Global.start_new_attempt()
	Global.selected_style_id = "magic"
	_seed_augments()
	_seed_items()
	await _wait(0.3)
	if _want("library"):
		await _library()
	if _want("major"):
		await _major()
	if _want("stash"):
		await _stash()
	if _want("gameover"):
		await _gameover()
	if _only == "gameover_live":
		await _gameover_live()
		return
	print("ChambersShotProbe: done -> ", _out)
	get_tree().quit(0)


func _want(area: String) -> bool:
	return _only == "" or _only == area


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, shot_name])
	print("shot ", shot_name, " ", image.get_size())


## A stand-in for the frozen world behind an in-run screen.
func _world() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = WORLD
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	add_child(root)
	return root


func _hover(control: Control, offset: Vector2 = Vector2.ZERO) -> void:
	if control == null:
		return
	var rect := control.get_global_rect()
	_move_mouse(rect.get_center() + rect.size * offset)


## Warps the cursor (logical coordinates) and feeds a motion event so hover
## signals fire as they would under a real mouse.
func _move_mouse(at: Vector2) -> void:
	get_viewport().warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	var window_pos: Vector2 = get_viewport().get_final_transform() * at
	motion.position = window_pos
	motion.global_position = window_pos
	Input.parse_input_event(motion)


# ------------------------------------------------------------------ fixtures

func _seed_augments() -> void:
	var ids: Array = Global.augment_db.keys()
	ids.sort()
	var count := 0
	for id in ids:
		Global.add_owned_augment(id)
		count += 1
		if count >= 9:
			break
	Global.init_permanent_augments()
	if ids.size() >= 3:
		Global.set_permanent_augment(0, ids[1])
		Global.set_permanent_augment(1, ids[4] if ids.size() > 4 else ids[2])
		Global.set_permanent_augment(2, StringName())
	Global.set_augment_slot_locked(1, true)


func _seed_items() -> void:
	if Global.meta_stash == null:
		Global.meta_stash = StashInventory.new()
	var by_slot: Dictionary = {}
	var loose: Array = []
	var ids: Array = Global.item_db.keys()
	ids.sort()
	for id in ids:
		if String(id) == "item_test":
			continue
		var data := Global.item_db[id] as ItemData
		if data == null or data.icon == null:
			continue
		var slot := int(data.equip_slot)
		if slot >= 0 and not by_slot.has(slot):
			by_slot[slot] = data
		else:
			loose.append(data)
	var rarity := 0
	for slot in by_slot:
		if slot == 6:
			continue
		var inst := ItemInstance.from_roll(by_slot[slot], rarity % 5, ItemInstance.Polarity.POS, 0.4, false)
		Global.run_inventory.set_item(int(slot), inst, {"player_driven": true})
		rarity += 1
	for i in range(mini(7, loose.size())):
		var inst2 := ItemInstance.from_roll(loose[i], (i + 1) % 5, ItemInstance.Polarity.POS if i % 3 else ItemInstance.Polarity.NEG, 0.3, false)
		if i == 2:
			inst2.locked = true
		Global.run_bag.set_item(i, inst2)
	for j in range(mini(9, loose.size() - 7)):
		var inst3 := ItemInstance.from_roll(loose[7 + j], j % 4, ItemInstance.Polarity.POS, 0.5, false)
		Global.meta_stash.set_item(j * 2, inst3, null)


# ------------------------------------------------------------------ screens

func _library() -> void:
	var world := _world()
	var screen := (load("res://ui/screens/AugmentLibrary.tscn") as PackedScene).instantiate()
	add_child(screen)
	await _wait(0.42)
	await _shot("library_open_early")
	await _wait(1.0)
	await _shot("library")
	var entries := screen.find_children("*", "AugmentLibraryEntry", true, false)
	if entries.size() > 1:
		_hover(entries[1] as Control)
		await _wait(0.5)
		await _shot("library_hover_entry")
	var slots := screen.find_children("*", "AugmentEquipSlot", true, false)
	if slots.size() > 0:
		_hover(slots[0] as Control)
		await _wait(0.5)
		await _shot("library_hover_slot")
	# Bind an unbound augment into the empty key: the key flares.
	_move_mouse(Vector2(20, 20))
	for e in entries:
		var id: StringName = (e as AugmentLibraryEntry).augment_id
		if not Global.permanent_augment_ids.has(id):
			screen.call("_on_entry_quick_equip", id)
			break
	await _wait(0.12)
	await _shot("library_bind")
	screen.queue_free()
	world.queue_free()
	await _wait(0.2)


func _major() -> void:
	var world := _world()
	Global.pending_big_choice = true
	Global.attempt_pending_doctrine_stage = &"method"
	Global.attempt_major_choice_offer_ids = [
		"doctrine_method_open_circuit",
		"doctrine_method_frame_of_ash",
		"doctrine_method_black_archive",
	]
	Global.attempt_major_choice_taken_ids = []
	var screen := (load("res://ui/screens/MajorChoice.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	_move_mouse(Vector2(20, 20))
	screen.call("open")
	await _wait(0.25)
	await _shot("major_deal")
	await _wait(1.2)
	await _shot("major")
	var cards := screen.get_node("Center/Window/Margin/VBox/Cards")
	if cards.get_child_count() >= 3:
		_hover(cards.get_child(0) as Control, Vector2(0.3, -0.3))
		await _wait(0.6)
		await _shot("major_hover")
		(cards.get_child(1) as BaseButton).pressed.emit()
		_hover(cards.get_child(1) as Control, Vector2(-0.25, 0.2))
		await _wait(0.6)
		await _shot("major_selected")
		_move_mouse(Vector2(20, 20))
		var confirm := screen.get_node("Center/Window/Margin/VBox/Actions/Confirm") as Button
		_hover(confirm)
		await _wait(0.4)
		await _shot("major_confirm_hover")
		confirm.pressed.emit()
		await _wait(0.18)
		await _shot("major_inscribe")
		await _wait(1.0)
		await _shot("major_closed")
	screen.queue_free()
	world.queue_free()
	await _wait(0.2)


func _stash() -> void:
	var world := _world()
	var screen := (load("res://ui/screens/InventoryStash.tscn") as PackedScene).instantiate()
	add_child(screen)
	await _wait(0.42)
	await _shot("stash_open_early")
	await _wait(1.0)
	await _shot("stash")
	var eq := screen.get("eq_grid") as Control
	if eq != null and eq.get_child_count() > 1:
		_hover(eq.get_child(1) as Control)
		await _wait(0.5)
		await _shot("stash_hover")
	screen.queue_free()
	world.queue_free()
	await _wait(0.2)


func _gameover() -> void:
	var world := _world()
	var screen := (load("res://ui/screens/GameOverUI.tscn") as PackedScene).instantiate()
	add_child(screen)
	await _wait(0.35)
	await _shot("gameover_early")
	await _wait(0.8)
	await _shot("gameover_mid")
	await _wait(2.0)
	await _shot("gameover")
	var menu := screen.find_child("Menu", true, false) as Control
	if menu != null:
		_hover(menu)
		await _wait(0.6)
		await _shot("gameover_hover")
		print("gameover focus after hover: ", get_viewport().gui_get_focus_owner())
		await _wait(1.0)
		await _shot("gameover_hover_late")
	screen.queue_free()
	world.queue_free()
	await _wait(0.2)


## Game Over over a real (Dev Segment) run: the frozen world and HUD under
## the veil. Ends the probe (the scene change takes this node's tree along).
func _gameover_live() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Global.debug_dev_segment = true
	Global.debug_dev_mode = true
	# No story card may stop an unattended run (StoryDirector.cards_allowed).
	StoryDirector.cards_override = 0
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.pending_augment_pick = false
	# Survive the scene change: no longer the current scene, just a root child.
	get_tree().current_scene = null
	Global.goto_game()
	var wall := 0.0
	while wall < 30.0:
		await get_tree().process_frame
		wall += get_process_delta_time()
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == Global.PATH_GAME and scene.is_node_ready():
			break
	await _wait(2.5)
	var game := get_tree().current_scene
	var ui := game.get_node_or_null("UI") if game != null else null
	if ui != null:
		for child in ui.get_children():
			if child.has_method("open_choose_3"):
				child.queue_free()
	get_tree().paused = false
	await _wait(1.0)
	await _shot("live_before")
	game.call("end_run")
	await _wait(0.5)
	await _shot("live_gameover_early")
	await _wait(2.6)
	await _shot("live_gameover")
	print("ChambersShotProbe: done -> ", _out)
	get_tree().quit(0)
