extends Node

var passed := 0
var failed := 0
var boundaries: Array[StringName] = []

class Witness:
	extends Node
	var frames := 0
	func _process(_delta: float) -> void:
		frames += 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func frames(count: int = 3) -> void:
	for _i in range(count):
		await get_tree().process_frame

func cancel() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await frames()
	key.pressed = false
	Input.parse_input_event(key)
	await frames()

func press_key(code: Key, shift: bool = false) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.shift_pressed = shift
	key.pressed = true
	Input.parse_input_event(key)
	await frames()
	key.pressed = false
	Input.parse_input_event(key)
	await frames()

func controller_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()

func conflicting_activation(menu: Node, hud: Node, action: StringName, controller: bool) -> void:
	var original := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var binding: InputEvent
	if controller:
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_A
		binding = pad
	else:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		binding = key
	InputMap.action_add_event(action, binding)
	(menu.get("_settings_button") as Button).grab_focus()
	await frames()
	if controller:
		await controller_button(JOY_BUTTON_A)
	else:
		await press_key(KEY_ENTER)
	check((menu.get("_settings") as Control).visible and not is_instance_valid(hud.get("_ascension_screen")) and not bool((hud.get("bag_ctl") as Node).call("is_management_mode")), "%s remapped to %s still activates native pause button without underlying management" % [action, "controller A" if controller else "Enter"])
	if (menu.get("_settings") as Control).visible:
		await cancel()
	InputMap.action_erase_events(action)
	for event in original:
		InputMap.action_add_event(action, event)

func _run() -> void:
	SaveManager.current_save = null
	SaveManager.save_dir = "user://pause_menu_test_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	StoryDirector.cards_override = 0
	SaveManager.current_save = SaveData.new()
	Global.apply_save(SaveManager.current_save)
	Global.start_new_attempt()
	Global.pending_augment_pick = false
	Global.attempt_segment = 2
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.debug_dev_mode = true
	Global.debug_player_god_mode = true
	Global.balance_attempt_boundary.connect(func(reason: StringName) -> void: boundaries.append(reason))
	Global.goto_game()
	await frames(8)
	var game := get_tree().current_scene
	check(game != null and game.scene_file_path == Global.PATH_GAME, "real Game loads")
	if game == null:
		finish()
		return
	# Incidental first-enemy dossiers are unrelated to this input contract.
	var controller: Node = game.get("_tutorial_modals")
	if RunEvents.enemy_archetype_encountered.is_connected(controller._on_enemy_encountered):
		RunEvents.enemy_archetype_encountered.disconnect(controller._on_enemy_encountered)
	controller.set("_queue", [])
	for card in game.get_children():
		if card is TutorialCardOverlay:
			card.call("_dismiss")
	await frames()
	get_tree().paused = false
	await cancel()
	var menu := game.get_node_or_null("PauseMenu")
	check(menu != null and bool(menu.get("is_open")) and get_tree().paused, "Escape opens the real Game pause menu")
	if menu == null:
		finish()
		return
	await _preview_pause(menu)
	(menu.get("_resume_button") as Button).grab_focus()
	var ui_events := InputMap.action_get_events(&"ui_accept")
	SettingsManager.call("_ensure_ui_controller_defaults")
	check(InputMap.action_get_events(&"ui_accept") == ui_events, "shared controller defaults preserve existing UI events without duplicates")
	await controller_button(JOY_BUTTON_DPAD_DOWN)
	check(get_viewport().gui_get_focus_owner() == menu.get("_settings_button"), "native controller D-pad navigates pause buttons")
	await controller_button(JOY_BUTTON_A)
	check((menu.get("_settings") as Control).visible and get_tree().paused, "native controller A opens Settings while paused")
	await controller_button(JOY_BUTTON_B)
	check(not (menu.get("_settings") as Control).visible and bool(menu.get("is_open")) and get_tree().paused, "native controller B closes Settings back to pause")
	await controller_button(JOY_BUTTON_B)
	check(not bool(menu.get("is_open")) and not get_tree().paused, "native controller B resumes the world")
	await controller_button(JOY_BUTTON_B)
	check(bool(menu.get("is_open")) and get_tree().paused, "native controller B opens pause through shared cancel binding")
	var witness := Witness.new()
	game.add_child(witness)
	var before := witness.frames
	await frames(5)
	check(witness.frames == before, "paused live world does not process")
	var hud := game.get_node("UI/HUD")
	check(not bool(hud.get("_owns_pause")), "pause menu owns pause independently of inventory")
	await cancel()
	check(not get_tree().paused and not bool(menu.get("is_open")), "Escape resumes safely")
	await frames(2)
	check(witness.frames > before, "world resumes processing")
	# Escape can arrive during the first-enemy recognition's temporary freeze.
	# Its expiry must transfer ownership instead of leaving Resume with a stale
	# snapshot of that temporary pause.
	var encounter := (load("res://ui/overlays/FirstEncounterOverlay.tscn") as PackedScene).instantiate()
	game.add_child(encounter)
	encounter.call("present", {"name": "Pause regression", "role": "Test", "counter": "Resume."}, game.get_node("Player"))
	await cancel()
	check(bool(menu.get("is_open")), "Escape opens pause during first-encounter freeze")
	encounter.call("_process", 1.0)
	check(get_tree().paused, "recognition expiry keeps the open pause menu frozen")
	await cancel()
	check(not get_tree().paused and not bool(menu.get("is_open")), "Escape resumes after first-encounter freeze expires")
	encounter.queue_free()
	get_tree().paused = false
	Engine.time_scale = 0.6
	menu.call("open")
	menu.call("resume")
	check(is_equal_approx(Engine.time_scale, 0.6), "Resume preserves active time scale")
	Engine.time_scale = 1.0
	get_tree().paused = true
	Global.pending_big_choice = true
	Global.attempt_major_choice_offer_ids = [&"doctrine_method_open_circuit"]
	var choice := (load("res://ui/screens/MajorChoice.tscn") as PackedScene).instantiate()
	game.add_child(choice)
	choice.open()
	await frames()
	await cancel()
	check(bool(menu.get("is_open")), "unhandled Escape can open pause over a mandatory paused choice")
	await cancel()
	check(get_tree().paused and Global.pending_big_choice and Global.attempt_major_choice_offer_ids == [&"doctrine_method_open_circuit"], "Resume restores prior modal pause and pending offer")
	# Use the real offer, without coupling the fixture to its resource directory.
	var offer := Global.get_major_choice_offer(3)
	if not offer.is_empty():
		choice.focus_choice(offer[0])
	var selected: StringName = choice.get("_focused_id")
	(menu.get("_entry") as Button).pressed.emit()
	(menu.get("_settings_button") as Button).pressed.emit()
	await cancel()
	check(selected != &"" and choice.get("_focused_id") == selected and get_tree().paused and bool(menu.get("is_open")), "Settings cancel over focused real choice leaves its pending selection intact")
	(menu.get("_menu_button") as Button).pressed.emit()
	await cancel()
	await cancel()
	check(choice.get("_focused_id") == selected and not bool(menu.get("is_open")) and get_tree().paused, "confirmation and pause Escape never cancel the underlying focused choice")
	choice.queue_free()
	Global.pending_big_choice = false
	get_tree().paused = false
	var bag: Node = hud.get("bag_ctl")
	bag.call("toggle_bag_open")
	await frames()
	await cancel()
	check(not bool(bag.call("is_management_mode")) and not bool(menu.get("is_open")) and not get_tree().paused, "inventory gets first Escape without stacking pause")
	menu.call("open")
	await press_key(KEY_TAB)
	check(get_viewport().gui_get_focus_owner() == menu.get("_settings_button"), "native Tab traverses paused menu without opening inventory")
	await press_key(KEY_TAB, true)
	check(get_viewport().gui_get_focus_owner() == menu.get("_resume_button"), "native Shift-Tab returns focus to Resume")
	await press_key(KEY_TAB)
	await press_key(KEY_ENTER)
	await frames()
	check((menu.get("_settings") as Control).visible and get_tree().paused, "Settings opens while world remains paused")
	await press_key(KEY_T)
	check(not is_instance_valid(hud.get("_ascension_screen")) and (menu.get("_settings") as Control).visible, "Settings owns input without opening underlying Ascension")
	await cancel()
	check(not (menu.get("_settings") as Control).visible and bool(menu.get("is_open")) and get_tree().paused, "Settings Escape returns to paused menu")
	await conflicting_activation(menu, hud, &"bag_toggle", false)
	await conflicting_activation(menu, hud, &"ascension_open", true)
	var bag_bindings := InputMap.action_get_events(&"bag_toggle")
	InputMap.action_erase_events(&"bag_toggle")
	var escape_binding := InputEventKey.new()
	escape_binding.keycode = KEY_ESCAPE
	InputMap.action_add_event(&"bag_toggle", escape_binding)
	await cancel()
	check(not bool(menu.get("is_open")) and not get_tree().paused and not bool(bag.call("is_management_mode")), "Escape overlapping management still resumes active pause safely")
	InputMap.action_erase_events(&"bag_toggle")
	for binding in bag_bindings:
		InputMap.action_add_event(&"bag_toggle", binding)
	menu.call("open")
	(menu.get("_quit_button") as Button).pressed.emit()
	await frames()
	await cancel()
	check(bool(menu.get("is_open")) and get_tree().paused and not (menu.get("_confirm") as Control).visible, "Quit confirmation can cancel without leaving")
	Global.attempt_checkpoint_pos = Vector2(100, 200)
	Global.attempt_deaths_this_segment = 2
	Global.set_followers(37)
	Global.attempt_congregation = 50
	var seed := Global.attempt_world_seed
	var runs: int = SaveManager.current_save.total_runs
	var accounts: int = int(StoryDirector.state_for_save().get("accounts", 0))
	(menu.get("_menu_button") as Button).pressed.emit()
	await frames()
	await cancel()
	check(get_tree().paused and bool(menu.get("is_open")), "Main Menu confirmation cancellation keeps pause")
	(menu.get("_menu_button") as Button).pressed.emit()
	await frames()
	(menu.get("_confirm") as Control).call("_on_confirm")
	check(get_tree().paused, "world remains frozen through navigation loading frames")
	await frames(10)
	check(get_tree().current_scene.scene_file_path == Global.PATH_MAIN_MENU and not get_tree().paused, "Main Menu arrives without pause leakage")
	var disk := ResourceLoader.load(SaveManager._slot_path(0), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	check(disk != null and disk.attempt_resume_scene == Global.PATH_GAME and disk.attempt_checkpoint_pos == Vector2(100, 200) and disk.attempt_world_seed == seed and disk.attempt_deaths_this_segment == 2 and disk.attempt_followers == 37 and disk.attempt_congregation == 50, "Game exit durably saves current attempt and existing Wardstone")
	check(SaveManager.current_save.total_runs == runs and int(StoryDirector.state_for_save().get("accounts", 0)) == accounts and boundaries.is_empty(), "exit creates no attempt, failure or story account")
	SaveManager.current_save = disk
	Global.apply_save(disk)
	Global.debug_dev_mode = true
	Global.goto_resume()
	await frames(40)
	game = get_tree().current_scene
	check(game.scene_file_path == Global.PATH_GAME and Global.attempt_checkpoint_pos == Vector2(100, 200), "Continue follows saved Game checkpoint semantics")
	Global.goto_hub_shop()
	await frames(25)
	var hub := get_tree().current_scene
	menu = hub.get_node_or_null("PauseMenu")
	check(hub.scene_file_path == Global.PATH_HUB_WORLD and menu != null, "real HubWorld installs same pause flow")
	if menu == null:
		finish()
		return
	hub.call("_open_merchant")
	await frames(5)
	await cancel()
	check(not bool(hub.call("_panel_is_open")) and not bool(menu.get("is_open")), "hub panel gets Escape before pause")
	Global.pending_augment_pick = true
	Global.attempt_vendor_seed = 4242
	Global.attempt_vendor_refreshes = 2
	Global.pending_big_choice = true
	Global.attempt_major_choice_offer_ids = [&"doctrine_method_open_circuit"]
	await cancel()
	check(get_tree().paused and bool(menu.get("is_open")), "Escape pauses hub")
	(menu.get("_menu_button") as Button).pressed.emit()
	await frames()
	(menu.get("_confirm") as Control).call("_on_confirm")
	await frames(10)
	disk = ResourceLoader.load(SaveManager._slot_path(0), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	check(disk.attempt_resume_scene == Global.PATH_HUB_WORLD and disk.attempt_vendor_seed == 4242 and disk.attempt_vendor_refreshes == 2 and disk.attempt_pending_augment_pick and disk.attempt_pending_big_choice and disk.attempt_major_choice_offer_ids == ["doctrine_method_open_circuit"], "hub exit saves hub destination, vendor and pending reward unchanged")
	SaveManager.current_save = disk
	Global.apply_save(disk)
	Global.goto_resume()
	await frames(25)
	check(get_tree().current_scene.scene_file_path == Global.PATH_HUB_WORLD and not get_tree().paused and Global.pending_big_choice, "Continue returns to hub without pause leakage")
	finish()

func _preview_pause(_menu: Node) -> void:
	pass

func finish() -> void:
	print("PauseMenuFlowTest: %d passed, %d failed" % [passed, failed])
	SaveManager.current_save = null
	get_tree().quit(1 if failed else 0)
