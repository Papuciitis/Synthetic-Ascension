extends Node
# Keep this scene's resource graph owned by the test, as production HubWorld
# does. A loose runtime load retained its script/scene resources at teardown.
const HUB_SHOP := preload("res://ui/screens/HubShop.tscn")

var _passes := 0
var _failures := 0
var _panel: Control
var _button: Button
var _toggle: CheckBox
var _option: OptionButton
var _list: ItemList
var _diagnostic_stopped := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _input_event() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F8
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()

func _ids() -> Array:
	return SfxManager.debug_requests.map(func(r: Dictionary) -> StringName: return r["id"])

func _clear() -> void:
	SfxManager.debug_requests.clear()

func _stop_after(section: String) -> bool:
	if not OS.get_cmdline_user_args().has("--stop-after=" + section):
		return false
	print("MenuAudioTest diagnostic prefix: ", section)
	_diagnostic_stopped = true
	_finish()
	return true

func _run() -> void:
	SaveManager.save_dir = "user://saves_test_menu_audio/"
	SaveManager.current_save = null
	SfxManager.debug_record = true
	_clear()
	_panel = Control.new()
	add_child(_panel)
	_button = Button.new()
	_button.text = "Select"
	_panel.add_child(_button)
	_toggle = CheckBox.new()
	_toggle.position.y = 50
	_panel.add_child(_toggle)
	_option = OptionButton.new()
	_option.add_item("First")
	_option.add_item("Second")
	_option.position.y = 100
	_panel.add_child(_option)
	_list = ItemList.new()
	_list.position.y = 150
	_list.size = Vector2(200,100)
	_list.add_item("Entry")
	_panel.add_child(_list)
	await _frames()
	_button.grab_focus()
	_toggle.set_pressed_no_signal(true)
	_option.select(1)
	_list.select(0)
	await _frames()
	_check(_ids().is_empty(), "screen construction and restored focus are silent")
	var router := SfxManager.get_node_or_null("UiSoundRouter")
	_check(router != null, "all menus have a shared feedback router")
	if router == null:
		_finish()
		return
	_check(router.process_mode == Node.PROCESS_MODE_ALWAYS, "navigation works while gameplay is paused")
	get_tree().paused = true
	_input_event()
	_button.pressed.emit()
	await _frames()
	_check(_ids() == [&"ui_click"], "an input-driven plain button plays once while paused")
	get_tree().paused = false
	_clear()
	_input_event()
	_button.mouse_entered.emit()
	_button.focus_entered.emit()
	await _frames()
	_check(_ids() == [&"ui_hover"], "hover and focus on the same input are one navigation sound")
	_clear()
	_input_event()
	_toggle.pressed.emit()
	await _frames()
	_check(_ids() == [&"ui_toggle"], "a checkbox gets a distinct short toggle sound")
	_clear()
	_input_event()
	_option.pressed.emit()
	_option.item_selected.emit(0)
	await _frames()
	_check(_ids() == [&"ui_toggle"], "option opening and selection do not double play")
	_clear()
	_input_event()
	_list.item_selected.emit(0)
	await _frames()
	_check(_ids() == [&"ui_click"], "a catalogue selection has feedback")
	_clear()
	_input_event()
	_button.pressed.emit()
	SfxManager.play_ui(&"ui_error")
	await _frames()
	_check(_ids() == [&"ui_error"], "an action failure replaces generic click feedback")
	_clear()
	_input_event()
	SfxManager.play_ui(&"library_open")
	_button.pressed.emit()
	await _frames()
	_check(_ids() == [&"library_open"], "authored sound wins even when it ran before the signal")
	_panel.set_meta("ui_sound_manual", true)
	_clear()
	_input_event()
	_button.pressed.emit()
	await _frames()
	_check(_ids().is_empty(), "manual book subtrees receive no generic activation")
	_panel.remove_meta("ui_sound_manual")
	_button.disabled = true
	_clear()
	_input_event()
	_button.pressed.emit()
	_button.mouse_entered.emit()
	await _frames()
	_check(_ids().is_empty(), "disabled controls do not imply a usable action")
	_button.disabled = false
	_clear()
	_button.pressed.emit()
	await _frames()
	_check(_ids().is_empty(), "programmatic signals without user input stay quiet")
	if _stop_after("base"): return
	await _test_assets_and_bus()
	if _stop_after("assets"): return
	await _test_real_controls()
	if _stop_after("controls"): return
	await _test_voice_priority()
	if _stop_after("voice"): return
	await _test_outcomes()
	if _diagnostic_stopped: return
	if _stop_after("outcomes"): return
	await _test_game_over_shortcuts()
	_finish()

func _click(button: Button) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await _frames()

func _test_real_controls() -> void:
	_button.position = Vector2(300, 300)
	_button.size = Vector2(180, 45)
	_button.release_focus()
	await _frames()
	_clear()
	await _click(_button)
	_check(_ids().count(&"ui_click") == 1, "a real mouse press/release produces exactly one activation")
	var late := Button.new()
	late.position = Vector2(300, 360)
	late.size = Vector2(180, 45)
	late.text = "Added later"
	_panel.add_child(late)
	await _frames()
	_clear()
	await _click(late)
	_check(_ids().count(&"ui_click") == 1, "buttons created after startup are audible")
	late.grab_focus()
	await _frames()
	_clear()
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	accept.pressure = 1.0
	# A test host may have no pad binding among built-in UI defaults. Use
	# a real mapped pad event without writing or replacing player bindings.
	var needs_mapping := not accept.is_action_pressed(&"ui_accept")
	if needs_mapping:
		InputMap.action_add_event(&"ui_accept", accept)
	get_viewport().push_input(accept, true)
	await get_tree().process_frame
	accept = InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = false
	get_viewport().push_input(accept, true)
	await _frames()
	_check(_ids().count(&"ui_click") == 1, "controller accept activates a focused button once: %s" % [_ids()])
	if needs_mapping:
		InputMap.action_erase_event(&"ui_accept", accept)
	_clear()
	var custom: Control = load("res://ui/bag/BagSlot.gd").new()
	custom.position = Vector2(520,300)
	custom.size = Vector2(48,48)
	_panel.add_child(custom)
	await _frames()
	_input_event()
	custom.emit_signal("clicked")
	await _frames()
	_check(_ids() == [&"ui_click"], "a real BagSlot's zero-argument click signal is supported")
	await get_tree().create_timer(0.1, true).timeout
	_button.focus_neighbor_bottom = _button.get_path_to(late)
	_button.focus_next = _button.get_path_to(late)
	_button.grab_focus()
	await _frames()
	_clear()
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	get_viewport().push_input(down, true)
	await _frames()
	_check(late.has_focus() and _ids() == [&"ui_hover"], "real keyboard Down focus navigation plays one quiet tick")
	await get_tree().create_timer(0.1, true).timeout
	_button.grab_focus()
	await _frames()
	_clear()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	get_viewport().push_input(tab, true)
	await _frames()
	_check(late.has_focus() and _ids() == [&"ui_hover"], "real keyboard Tab focus navigation plays one quiet tick")
	_clear()
	for pressed: bool in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.pressed = pressed
		get_viewport().push_input(enter, true)
		await get_tree().process_frame
	await _frames()
	_check(_ids().count(&"ui_click") == 1, "real Enter press/release activates the focused button once")
	for path: String in ["res://ui/components/TactileButton.gd", "res://ui/components/ArcaneMenuItem.gd"]:
		var shared: Button = load(path).new()
		shared.position = Vector2(600,400)
		shared.text = "Shared component"
		_panel.add_child(shared)
		await _frames()
		_clear()
		await _click(shared)
		_check(_ids().count(&"ui_click") == 1 and _ids().count(&"ui_hover") <= 1, "%s has no button-up hover or duplicate activation" % path.get_file())
		shared.queue_free()
		await _frames()
	var tabs := TabBar.new()
	tabs.position = Vector2(300, 440)
	tabs.size = Vector2(300, 45)
	tabs.focus_mode = Control.FOCUS_ALL
	tabs.add_tab("One")
	tabs.add_tab("Two")
	_panel.add_child(tabs)
	await _frames()
	tabs.grab_focus()
	await _frames()
	_clear()
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	get_viewport().push_input(right, true)
	await _frames()
	_check(tabs.current_tab == 1 and _ids() == [&"ui_toggle"], "real keyboard TabBar navigation has one selection cue")
	_clear()
	_input_event()
	tabs.tab_clicked.emit(0)
	tabs.tab_changed.emit(0)
	await _frames()
	_check(_ids() == [&"ui_toggle"], "TabBar click and change signals coalesce into one cue")
	var late_toggle := Button.new()
	late_toggle.position = Vector2(600, 460)
	late_toggle.text = "Late toggle"
	_panel.add_child(late_toggle)
	late_toggle.toggle_mode = true
	await _frames()
	_clear()
	await _click(late_toggle)
	_check(_ids().count(&"ui_toggle") == 1 and _ids().count(&"ui_click") == 0, "buttons configured as toggles after entering the tree receive toggle feedback")

func _test_outcomes() -> void:
	SaveManager.save_dir = "user://saves_test_menu_audio/"
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.followers = 0
	if _stop_after("fresh"): return
	var rite: Node = load("res://ui/screens/ReliquaryScreen.gd").new()
	add_child(rite)
	await _frames()
	_clear()
	rite.call("_on_buy_pressed", &"voucher_missing_audio_test")
	_check(_ids() == [&"ui_error"], "a refused voucher answers with failure feedback")
	_clear()
	rite.call("_on_transfuse_pressed")
	_check(_ids() == [&"ui_error"], "a stale invalid transfusion answers with failure feedback")
	_clear()
	rite.call("close")
	_check(_ids() == [&"ui_back"], "closing the Reliquary has the same back cue as its button")
	await _frames()
	if _stop_after("reliquary"): return
	var tree_screen: Node = load("res://ui/screens/AscensionScreen.tscn").instantiate()
	add_child(tree_screen)
	await _frames()
	_clear()
	tree_screen.call("_buy", "audio_missing_node", "")
	_check(_ids() == [&"ui_error"], "a refused Ascension purchase reports failure")
	_clear()
	tree_screen.call("close")
	_check(_ids() == [&"ui_back"], "closing Ascension reports back")
	await _frames()
	if _stop_after("ascension"): return
	var shop: Node = HUB_SHOP.instantiate()
	shop.set("embedded", true)
	add_child(shop)
	await _frames()
	_clear()
	shop.call("_barter_pressed")
	_check(_ids() == [&"ui_error"], "an unavailable trade reports failure without a click over it")
	_clear()
	shop.call("_refresh_vendor_pressed")
	_check(_ids() == [&"ui_error"], "an unaffordable restock reports failure")
	shop.queue_free()
	await _frames()
	if _stop_after("shop"): return
	var inventory: Node = load("res://ui/screens/InventoryStash.tscn").instantiate()
	var item := ItemData.new()
	item.id = "audio_locked_item"
	item.display_name = "Protected item"
	item.equip_slot = ItemData.EquipSlot.RING
	item.mods = StatDelta.new()
	item.rarity_base = StatDelta.new()
	var instance := ItemInstance.from_roll(item, 1, ItemInstance.Polarity.POS, 0.5, false)
	instance.locked = true
	Global.run_bag.set_item(0, instance)
	shop = HUB_SHOP.instantiate()
	shop.set("embedded", true)
	add_child(shop)
	await _frames()
	_clear()
	shop.call("_quick_equip_from_bag", 0)
	_check(_ids() == [&"ui_error"], "a locked exchange item does not sound like a successful equip")
	shop.queue_free()
	await _frames()
	if OS.get_cmdline_user_args().has("--stop-after=shop_locked"):
		inventory.free()
		if _stop_after("shop_locked"): return
	add_child(inventory)
	await _frames()
	if _stop_after("inventory_built"): return
	_clear()
	inventory.call("on_slot_rightclick", HubItemSlot.Kind.BAG, 0)
	_check(_ids() == [&"ui_error"] and Global.run_bag.get_at(0) == instance, "a locked item answers the refused move with failure and stays in place")
	_clear()
	inventory.call("toggle_item_lock", HubItemSlot.Kind.BAG, 0)
	_check(_ids() == [&"ui_toggle"] and not instance.locked, "locking changes have a toggle cue")
	_clear()
	inventory.call("on_slot_rightclick", HubItemSlot.Kind.BAG, 0)
	_check(_ids() == [&"ui_click"] and Global.run_bag.get_at(0) == null, "a successful item move answers once")
	_clear()
	inventory.call("handle_drop_item", {"kind": HubItemSlot.Kind.STASH, "idx": 0}, HubItemSlot.Kind.BAG, 1)
	_check(_ids() == [&"ui_click"] and Global.run_bag.get_at(1) == instance, "a successful drag/drop move has one result cue")
	inventory.queue_free()
	await _frames()

func _test_voice_priority() -> void:
	var headless: bool = SfxManager.get("_headless")
	SfxManager.set("_headless", false)
	var voice: AudioStreamPlayer = SfxManager.get("_ui")
	for id: StringName in [&"ui_error", &"library_page_1"]:
		SfxManager.play_ui(id)
		await _frames()
		_clear()
		await _click(_button)
		_check(_ids().is_empty() and voice.playing and SfxManager.get("_ui_current_id") == id, "a fresh plain click cannot cut ongoing %s feedback" % id)
	await get_tree().create_timer(0.9, true).timeout
	_clear()
	await _click(_button)
	_check(_ids().count(&"ui_click") == 1, "the next click works once the authored sound has finished")
	voice.stop()
	SfxManager.set("_headless", headless)

func _test_game_over_shortcuts() -> void:
	var screen: Node = load("res://ui/screens/GameOverUI.tscn").instantiate()
	add_child(screen)
	await _frames()
	_clear()
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	screen.call("_unhandled_input", key)
	_check(_ids() == [&"ui_click"], "the game-over Enter shortcut has the restart button's cue")
	_clear()
	key.keycode = KEY_ESCAPE
	screen.call("_unhandled_input", key)
	_check(_ids() == [&"ui_back"], "the game-over Escape shortcut has the menu button's back cue")
	screen.queue_free()
	await _frames()

func _test_assets_and_bus() -> void:
	for id: StringName in [&"ui_hover", &"ui_click", &"ui_toggle", &"ui_back", &"ui_error"]:
		var sound: Variant = SfxManager.get("_defs").get(id)
		_check(sound != null and sound.stream != null and sound.bus == &"UI", "%s is imported on the Interface bus" % id)
		if sound != null and id in [&"ui_hover", &"ui_click", &"ui_toggle"]:
			_check(sound.stream.get_length() < 0.12, "%s feedback ends before it can obscure the next action" % id)
	var bus := AudioServer.get_bus_index("UI")
	_check(bus >= 0, "Interface has an independent audio bus")
	if bus >= 0:
		var old_mute: bool = SettingsManager.get_value(&"audio", &"ui_muted", false)
		var old_volume: float = SettingsManager.get_value(&"audio", &"ui_volume", 1.0)
		SettingsManager.set_value(&"audio", &"ui_muted", true, false)
		SettingsManager.set_value(&"audio", &"ui_volume", 0.25, false)
		_clear()
		_input_event()
		_button.pressed.emit()
		await _frames()
		_check(AudioServer.is_bus_mute(bus) and _ids() == [&"ui_click"], "routing preserves the player's muted Interface setting")
		_check(is_equal_approx(AudioServer.get_bus_volume_linear(bus), 0.25), "routing preserves the Interface volume applied by Settings")
		SettingsManager.set_value(&"audio", &"ui_volume", old_volume, false)
		SettingsManager.set_value(&"audio", &"ui_muted", old_mute, false)
		var headless: bool = SfxManager.get("_headless")
		SfxManager.set("_headless", false)
		SfxManager.play_ui(&"library_page_1")
		await _frames()
		var voice: AudioStreamPlayer = SfxManager.get("_ui")
		_check(voice.playing and voice.bus == &"UI", "authored paper playback uses the paused-capable Interface voice")
		_clear()
		_input_event()
		_button.mouse_entered.emit()
		await _frames()
		_check(_ids().is_empty() and voice.playing, "moving focus cannot cut an authored paper sound short")
		voice.stop()
		SfxManager.set("_headless", headless)

func _finish() -> void:
	get_tree().paused = false
	if is_instance_valid(_panel):
		_panel.queue_free()
	for child in get_children():
		child.queue_free()
	await _frames()
	# Uncapped headless process frames can both finish before one physics
	# tick. Let retired UI tweens/coroutines and rendering cleanup settle.
	await get_tree().create_timer(0.2, true).timeout
	await get_tree().physics_frame
	SfxManager.debug_record = false
	_clear()
	print("MenuAudioTest: %d passed, %d failed" % [_passes, _failures])
	# Return from this async stack before beginning SceneTree teardown.
	get_tree().quit.call_deferred(1 if _failures > 0 else 0)
