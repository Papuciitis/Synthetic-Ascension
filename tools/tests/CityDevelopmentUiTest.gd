extends Node
## Real main-menu entry and native controls; isolated profile directory only.
const MENU_SCENE := preload("res://ui/screens/MainMenu.tscn")
const MISSILE := &"augment_magic_missile"
const TESLA := &"augment_tesla_aura"
const BASE_SCENE := preload("res://ui/screens/base.tscn")
const HUB_SCENE := preload("res://ui/screens/HubShop.tscn")
var _passes := 0
var _failures := 0

func _enter_tree() -> void:
	# Embedded popups route root input through Window::_window_input, including
	# PopupMenu’s native virtual handler; direct signals/Viewport input bypass it.
	get_window().gui_embed_subwindows = true
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/city_development_ui_%d/" % Time.get_ticks_usec()

func _ready() -> void:
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _frames(count: int = 2) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _run() -> void:
	var menu := MENU_SCENE.instantiate() as Control
	add_child(menu)
	await _frames()
	var development := menu.find_child("Development", true, false) as Button
	_check(development != null, "main menu exposes Development through an actual native button")
	if development == null:
		menu.queue_free()
		await _frames()
		_finish()
		return
	_check(not development.disabled, "Development can open profile selection before a profile is loaded")
	_check(development.tooltip_text.to_lower().contains("profile"), "the entry explains its profile selection")
	menu.queue_free()
	await _frames()
	_check(Global.has_method("get_city_development_summary"), "the cumulative development API exists")
	if not Global.has_method("get_city_development_summary"):
		_finish()
		return
	await _test_profile_flow()
	_finish()

func _finish() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	print("CityDevelopmentUiTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _summary() -> Dictionary:
	return Global.call("get_city_development_summary") as Dictionary

func _button(screen: Node, name_text: String) -> Button:
	return screen.find_child(name_text, true, false) as Button

func _text(screen: Node, name_text: String) -> String:
	var label := screen.find_child(name_text, true, false) as Label
	return label.text if label != null else ""

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames()

func _pad(code: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames()

func _reveal(screen: Node, control: Control) -> void:
	var scroll := screen.find_child("DevelopmentScroll", true, false) as ScrollContainer
	if scroll != null and scroll.is_ancestor_of(control):
		scroll.ensure_control_visible(control)
	await _frames()

func _activate(screen: Node, name_text: String, pad: bool = false) -> void:
	var button := _button(screen, name_text)
	_check(button != null, "%s exists as a native control" % name_text)
	if button == null:
		return
	await _reveal(screen, button)
	button.grab_focus()
	if pad:
		await _pad(JOY_BUTTON_A)
	else:
		await _key(KEY_ENTER)

func _click(screen: Node, name_text: String) -> void:
	var button := _button(screen, name_text)
	_check(button != null, "%s exists for pointer activation" % name_text)
	if button == null:
		return
	await _reveal(screen, button)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames()

func _development(parent: Node) -> Node:
	return parent.find_child("CityDevelopmentScreen", true, false)

func _test_profile_flow() -> void:
	var profile := SaveData.new()
	profile.slot_index = 1
	profile.profile_name = "City Development UI Test"
	SaveManager.current_save = profile
	SaveManager.current_slot = 1
	Global.apply_save(profile)
	Global.owned_augment_ids = [TESLA, MISSILE, &"missing_augment", StringName()]
	Global.permanent_augment_ids = [MISSILE, StringName(), StringName()]
	Global.start_new_attempt()
	# Research is granted through the real city-completion path, not injected.
	for segment in range(1, 8):
		Global.attempt_segment = segment
		_check(Global.begin_segment_completion(segment), "segment %d completion begins" % segment)
		_check(Global.finish_segment_completion(segment), "segment %d completion settles" % segment)
	Global.pending_big_choice = false
	Global.pending_augment_pick = false
	var before: Dictionary = (Global.get("attempt_city_development") as Dictionary).duplicate(true)
	var bag_before := Global.run_bag.get_slot_count()
	var stats_before := Stats.new()
	Global.apply_permanent_augments_to_stats(stats_before)
	var menu := MENU_SCENE.instantiate() as Control
	add_child(menu)
	await _frames()
	var entry := _button(menu, "Development")
	_check(entry != null and not entry.disabled, "a selected profile enables Development")
	await _activate(menu, "Development", true)
	var screen := _development(menu)
	_check(screen != null, "controller A opens the real Development panel")
	if screen == null:
		menu.queue_free()
		await _frames()
		return
	var initial_panel := screen.find_child("DevelopmentPanel", true, false) as Control
	_check(initial_panel != null and get_viewport().get_visible_rect().encloses(initial_panel.get_global_rect()), "the initial panel settles inside the normal viewport before any resize")
	_check(_text(screen, "DevelopmentTitle").to_lower().contains("choose one improvement"), "the heading presents one choice among alternatives")
	_check(_text(screen, "DevelopmentContinuity").contains("Your previous choices remain"), "the panel explains that earlier choices accumulate")
	_check(_summary().get("points", -1) == 7, "seven distinct first clears provide seven available Research")
	_check(_text(screen, "ResearchWallet").contains("7") and _text(screen, "ResearchWallet").contains("INVESTED"), "the wallet reports available and invested Research")
	_check(_text(screen, "ResearchSource").contains("first") and _text(screen, "ResearchSource").contains("1–10"), "the Research source is explicit and finite")
	_check(_text(screen, "NextAttemptSummary").to_lower().contains("next attempt"), "the panel states when development begins")
	_check(_text(screen, "ActiveAttemptSummary").to_lower().contains("this attempt"), "the active attempt has its own summary")
	await _activate(screen, "Invest_haste", true)
	var haste_ranks := _summary().get("ranks", {}) as Dictionary
	var only_haste := int(haste_ranks.get("haste", 0)) == 1
	for key: Variant in haste_ranks:
		if String(key) != "haste" and int(haste_ranks[key]) != 0:
			only_haste = false
	_check(only_haste and _summary().get("points", -1) == 6, "one haste choice consumes exactly one Research and leaves every other option unchanged")
	await _activate(screen, "Invest_health")
	_check(_summary().get("points", -1) == 5 and int((_summary().get("ranks", {}) as Dictionary).get("health", 0)) == 1, "Enter invests one Research in permanent +5 HP")
	await _click(screen, "Invest_armor")
	_check(_summary().get("points", -1) == 4 and int((_summary().get("ranks", {}) as Dictionary).get("armor", 0)) == 1, "a native pointer click invests in armor")
	var armor_button := _button(screen, "Invest_armor")
	armor_button.grab_focus()
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var moved_focus := get_viewport().gui_get_focus_owner()
	_check(moved_focus != null and moved_focus != armor_button and screen.is_ancestor_of(moved_focus), "D-pad navigation moves between native choices inside the panel")
	await _activate(screen, "Invest_bag", true)
	_check(_summary().get("points", -1) == 3 and int((_summary().get("ranks", {}) as Dictionary).get("bag", 0)) == 1, "controller A invests in permanent backpack capacity")
	var selector := screen.find_child("TrainedAugment", true, false) as OptionButton
	_check(selector != null and selector.item_count == 2, "the target selector includes owned real augments and excludes empty or missing resources")
	await _activate(screen, "Invest_augment", true)
	_check(_summary().get("points", -1) == 2 and int((_summary().get("ranks", {}) as Dictionary).get("augment", 0)) == 1, "augment training costs one permanent Research rank")
	_check(String(_summary().get("augment_id", "")) == String(TESLA), "training initially targets the chosen owned augment")
	if selector != null:
		await _reveal(screen, selector)
		selector.grab_focus()
		_selector_trace(selector, "before native open")
		await _key(KEY_ENTER)
		_selector_trace(selector, "after native open")
		await _popup_key(selector.get_popup(), KEY_DOWN)
		_selector_trace(selector, "after native Window Down")
		await _popup_key(selector.get_popup(), KEY_ENTER)
		_selector_trace(selector, "after native Window confirm")
	_check(String(_summary().get("augment_id", "")) == String(MISSILE) and _summary().get("points", -1) == 2, "native selector activation retargets purchased training for free")
	if selector != null and selector.get_popup().visible:
		# A failed activation must not let this modal intercept later test cases.
		selector.get_popup().hide()
		await _frames()
	_check(not bool(Global.call("select_trained_augment", &"missing_augment")) and not bool(Global.call("select_trained_augment", StringName())), "invalid and empty training targets cannot be selected")
	_check(Global.get("attempt_city_development") == before, "investment and reassignment leave the active development snapshot unchanged")
	var stats_after := Stats.new()
	Global.apply_permanent_augments_to_stats(stats_after)
	_check(stats_before.max_hp == stats_after.max_hp and stats_before.armor == stats_after.armor and Global.run_bag.get_slot_count() == bag_before and Global.get_augment_level(MISSILE) == 1, "the active build keeps its original HP, armor, bag and augment level")
	_check(_text(screen, "NextAttemptSummary").contains("+5 HP") and _text(screen, "NextAttemptSummary").contains("+1 armor") and _text(screen, "NextAttemptSummary").contains("+1 bag slot") and _text(screen, "NextAttemptSummary").contains("Lv.2"), "next-attempt totals show the exact cumulative gains")
	await _activate(screen, "Invest_health")
	await _activate(screen, "Invest_health")
	_check(int((_summary().get("ranks", {}) as Dictionary).get("health", 0)) == 3 and _summary().get("points", -1) == 0, "HP accumulates to its three-rank cap with no overspend")
	_check(_button(screen, "Invest_health").disabled and _button(screen, "Invest_health").text.contains("MAX"), "a fully developed option says that it is capped")
	_check(_button(screen, "Invest_armor").disabled, "an unaffordable investment is disabled")
	_check(get_viewport().gui_get_focus_owner() != null and screen.is_ancestor_of(get_viewport().gui_get_focus_owner()), "focus remains inside the panel when the last Research is spent")
	var original_owned := Global.owned_augment_ids.duplicate()
	Global.owned_augment_ids.clear()
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	screen.call("refresh")
	_check(selector.item_count == 0 and selector.disabled and _button(screen, "Invest_augment").disabled, "an empty owned library disables training selection safely")
	Global.owned_augment_ids.assign(original_owned)
	Global.permanent_augment_ids = [MISSILE, StringName(), StringName()]
	Global.call("select_trained_augment", MISSILE)
	screen.call("refresh")
	var original_scale := get_window().content_scale_size
	get_window().content_scale_size = Vector2i(640, 480)
	await _frames(4)
	var panel := screen.find_child("DevelopmentPanel", true, false) as Control
	var viewport_rect := get_viewport().get_visible_rect()
	_check(panel != null and viewport_rect.encloses(panel.get_global_rect()), "the panel stays within a small logical viewport")
	_check(screen.find_child("DevelopmentScroll", true, false) is ScrollContainer, "small screens can scroll every development option")
	await _activate(screen, "CloseDevelopment", true)
	_check(_development(menu) == null and get_viewport().gui_get_focus_owner() == entry, "Close returns focus to the invoking main-menu entry")
	_check(get_viewport().get_visible_rect().encloses(entry.get_global_rect()), "the actual main-menu Development entry remains inside a small logical viewport")
	get_window().content_scale_size = original_scale
	await _frames()
	await _activate(menu, "Development", true)
	await _pad(JOY_BUTTON_B)
	_check(_development(menu) == null and menu.is_inside_tree(), "controller B closes Development without navigating away from the menu")
	Global.save_current_profile()
	var reloaded := SaveManager.load_slot(1)
	_check(reloaded != null, "the cumulative profile can be read from its isolated slot")
	if reloaded != null:
		SaveManager.current_save = reloaded
		Global.apply_save(reloaded)
		_check(_summary().get("points", -1) == 0 and int((_summary().get("ranks", {}) as Dictionary).get("health", 0)) == 3 and String(_summary().get("augment_id", "")) == String(MISSILE), "Research, cumulative ranks and reassigned training survive an actual save/reload")
		_check(Global.get("attempt_city_development") == before, "Continue restores the original active snapshot despite newer profile development")
	menu.queue_free()
	await _frames()
	await _test_entry(BASE_SCENE, false)
	await _test_entry(HUB_SCENE, true)
	await _test_pending_peep()
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	var screen_resource := load("res://ui/screens/CityDevelopmentScreen.tscn") as PackedScene
	if screen_resource != null:
		var unbound := screen_resource.instantiate()
		add_child(unbound)
		await _frames()
		_check(_text(unbound, "DevelopmentStatus").to_lower().contains("profile") and _button(unbound, "Invest_health").disabled, "a screen without a profile explains why it cannot invest")
		await _activate(unbound, "CloseDevelopment")

func _test_entry(scene: PackedScene, embedded: bool) -> void:
	Global.pending_big_choice = false
	Global.pending_augment_pick = false
	var parent := scene.instantiate()
	if embedded:
		parent.set("embedded", true)
	add_child(parent)
	await _frames(3)
	var button := _button(parent, "Development")
	_check(button != null and not button.disabled, "%s exposes Development for the selected profile" % ("Hub" if embedded else "new-attempt setup"))
	if button != null:
		await _activate(parent, "Development", true)
		_check(_development(parent) != null, "the existing scene opens Development")
		await _pad(JOY_BUTTON_B)
		_check(_development(parent) == null and get_viewport().gui_get_focus_owner() == button, "controller B closes only Development and restores the invoking control")
	parent.queue_free()
	await _frames()

func _test_pending_peep() -> void:
	var profile := SaveData.new()
	profile.slot_index = 2
	profile.profile_name = "Preparation after terminal failure"
	SaveManager.current_save = profile
	SaveManager.current_slot = 2
	Global.apply_save(profile)
	Global.owned_augment_ids = [MISSILE]
	Global.permanent_augment_ids = [MISSILE, StringName(), StringName()]
	Global.start_new_attempt()
	Global.attempt_segment = 1
	Global.begin_segment_completion(1)
	Global.finish_segment_completion(1)
	Global.set_followers(0)
	Global.begin_peep_continuation()
	_check(Global.has_pending_peep(), "terminal failure leaves its durable continuation decision pending")
	var failed_snapshot := (Global.get("attempt_city_development") as Dictionary).duplicate(true)
	var menu := MENU_SCENE.instantiate() as Control
	add_child(menu)
	await _frames()
	var entry := _button(menu, "Development")
	_check(entry != null and not entry.disabled, "a selected failed profile can prepare through MainMenu Development before accepting continuation")
	await _activate(menu, "Development", true)
	var screen := _development(menu)
	_check(screen != null, "pending continuation does not block the preparation screen")
	if screen != null:
		await _activate(screen, "Invest_health")
		_check(_summary().get("points", -1) == 0 and int((_summary().get("ranks", {}) as Dictionary).get("health", 0)) == 1, "one retained choice can be spent before continuation")
		_check(Global.has_pending_peep() and Global.get("attempt_city_development") == failed_snapshot, "preparation preserves the unresolved failed attempt snapshot")
		await _pad(JOY_BUTTON_B)
	var runs_before := SaveManager.current_save.total_runs
	_check(Global.accept_peep_continuation(), "acceptance begins the prepared next attempt")
	_check(int((_summary().get("active_bonuses", {}) as Dictionary).get("hp", 0)) == 5 and not Global.has_pending_peep(), "the prepared +5 HP is captured by the new attempt exactly at continuation")
	_check(not Global.accept_peep_continuation() and SaveManager.current_save.total_runs == runs_before + 1, "a duplicate acceptance cannot start another attempt or duplicate preparation")
	menu.queue_free()
	await _frames()

func _selector_trace(selector: OptionButton, stage: String) -> void:
	var metadata: Array = []
	for index in range(selector.item_count):
		metadata.append(selector.get_item_metadata(index))
	print("CITY SELECTOR TRACE: ", {"stage": stage, "selected": selector.selected, "popup_visible": selector.get_popup().visible, "popup_focused": selector.get_popup().get_focused_item(), "metadata": metadata, "target": _summary().get("augment_id", ""), "points": _summary().get("points", -1), "ui_down_exists": InputMap.has_action(&"ui_down"), "embedded": selector.get_popup().is_embedded()})

func _popup_key(popup: PopupMenu, code: Key) -> void:
	_check(popup.is_embedded(), "the native popup uses the embedded Window input dispatch path")
	await _key(code)
