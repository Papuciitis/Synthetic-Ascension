extends Node
## Catches stale outcome rendering, accidental pending consumption from menu,
## accept overriding focused actions, and duplicate fresh attempts from input.
const SCREEN := "res://ui/screens/PeePContinuation.tscn"
var _passes := 0
var _failures := 0
var _routes: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _fixture() -> void:
	SaveManager.current_save = SaveData.new()
	Global.apply_save(SaveManager.current_save)
	Global.start_new_attempt()
	Global.mortal_name = "[b]Mara & Echo[/b]"
	Global.attempt_segment = 7
	Global.set_followers(0)
	Global.begin_peep_continuation()
	Global.mortal_name = "Unrelated live name"

func _screen() -> Control:
	var screen := (load(SCREEN) as PackedScene).instantiate() as Control
	add_child(screen)
	return screen

func _settle_route() -> void:
	for i in range(5):
		await get_tree().process_frame
	# Let the real navigation scrim finish before removing its destination.
	# Otherwise this artificial driver would leave a scrim over the next screen.
	await get_tree().create_timer(0.5).timeout
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
	await get_tree().process_frame

func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		get_viewport().push_input(event, true)

func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)

func _pad(button_index: JoyButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button_index
		event.pressed = down
		get_viewport().push_input(event, true)

func _viewport_key(viewport: Viewport, code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		viewport.push_input(event, true)

func _viewport_pad(viewport: Viewport, button_index: JoyButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button_index
		event.pressed = down
		viewport.push_input(event, true)

func _run() -> void:
	get_tree().current_scene = null
	SaveManager.current_save = null
	SaveManager.save_dir = "user://peep_ui_test_%d/" % Time.get_ticks_usec()
	Global.debug_disable_autosave = true
	Global.hard_exit_on_quit = false
	Global.balance_scene_requested.connect(func(path: String) -> void: _routes.append(path))
	_check(ResourceLoader.exists(SCREEN), "terminal continuation has a usable screen")
	if not ResourceLoader.exists(SCREEN):
		_finish()
		return
	SaveManager.current_save = SaveData.new()
	Global.apply_save(SaveManager.current_save)
	var absent := _screen()
	_check(not absent.visible, "opening without pending does not show PeeP")
	_check(not StoryDirector.has_flag("seen:peep_first_conversation"), "an absent terminal decision does not spend the first conversation")
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	get_viewport().push_input(cancel, true)
	_check(not get_viewport().is_input_handled(), "absent pending does not capture input for an invisible screen")
	cancel.pressed = false
	get_viewport().push_input(cancel, true)
	await _settle_route()
	_check(_routes.back() == Global.PATH_MAIN_MENU, "absent pending safely routes to menu")
	absent.free()
	_fixture()
	var runs := SaveManager.current_save.total_runs
	if OS.get_cmdline_user_args().has("--peep-quit-check"):
		var quitting := _screen()
		await get_tree().process_frame
		await get_tree().process_frame
		# Failure to wire Quit leaves this watchdog to make the process fail.
		get_tree().create_timer(2.0).timeout.connect(func() -> void: get_tree().quit(1))
		var quit_button := quitting.find_child("Quit", true, false) as Button
		quit_button.grab_focus()
		await get_tree().process_frame
		await get_tree().process_frame
		_click(quit_button)
		_check(Global.has_pending_peep() and SaveManager.current_save.total_runs == runs, "Quit retains the unresolved decision and failed attempt")
		var disk := ResourceLoader.load(SaveManager._slot_path(0), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
		_check(disk != null and disk.meta_pending_peep.get("name") == "[b]Mara & Echo[/b]", "Quit leaves durable pending facts on isolated disk")
		print("PeePContinuationUiTest quit action: %d passed, %d failed" % [_passes, _failures])
		return
	var small_view := SubViewport.new()
	small_view.size = Vector2i(640, 480)
	add_child(small_view)
	var small := (load(SCREEN) as PackedScene).instantiate() as Control
	small_view.add_child(small)
	for i in range(4):
		await get_tree().process_frame
	var small_scroll := small.find_child("Scroll", true, false) as ScrollContainer
	var small_begin := small.find_child("Begin", true, false) as Button
	var greeting := small.find_child("Greeting", true, false) as Label
	_check(small_scroll.has_focus() and small_scroll.scroll_vertical == 0 and greeting.get_global_rect().position.y >= 24.0, "small-window arrival introduces PeeP at the top without focusing a hidden action")
	var first_dialogue := small.find_child("Invitation", true, false) as Label
	_check(first_dialogue != null and first_dialogue.text.contains("You wanted to get out.") and first_dialogue.text.contains("Do you give up?") and first_dialogue.text.contains("You don't have to answer now."), "the first encounter offers the full conversation immediately without requiring a spoken reply")
	_check(not small_begin.disabled, "the first conversation never delays the continuation action")
	_check(StoryDirector.has_flag("seen:peep_first_conversation") and Global.has_pending_peep() and SaveManager.current_save.total_runs == runs, "presenting the first conversation records profile memory without accepting continuation")
	var remembered := ResourceLoader.load(SaveManager._slot_path(0), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	_check(remembered != null and (remembered.meta_story.get("flags", []) as Array).has("seen:peep_first_conversation") and remembered.meta_pending_peep.get("name") == "[b]Mara & Echo[/b]", "first conversation memory and the untouched pending outcome are durable before acceptance")
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	small_view.push_input(down, true)
	down.pressed = false
	small_view.push_input(down, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(small_scroll.has_focus() and small_scroll.scroll_vertical > 0, "Down scrolls the first conversation without skipping to its hidden actions")
	var after_down := small_scroll.scroll_vertical
	var page_down := InputEventKey.new()
	page_down.keycode = KEY_PAGEDOWN
	page_down.pressed = true
	small_view.push_input(page_down, true)
	page_down.pressed = false
	small_view.push_input(page_down, true)
	await get_tree().process_frame
	_check(small_scroll.has_focus() and small_scroll.scroll_vertical > after_down, "Page Down advances the reading stack while retaining reading focus")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	small_view.push_input(tab, true)
	tab.pressed = false
	small_view.push_input(tab, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(small_begin.has_focus() and small_begin.get_global_rect().position.y >= 24.0 and small_begin.get_global_rect().end.y <= 456.0, "Tab from the small-window reading position brings the continuation action fully into view")
	small_view.free()
	if remembered != null:
		SaveManager.current_save = remembered
		Global.apply_save(remembered)
	var replay_view := SubViewport.new()
	replay_view.size = Vector2i(640, 480)
	add_child(replay_view)
	var replay_screen := (load(SCREEN) as PackedScene).instantiate() as Control
	replay_view.add_child(replay_screen)
	for i in range(4):
		await get_tree().process_frame
	var replay_disclosure := replay_screen.find_child("ReadFirstConversation", true, false) as Button
	_check(replay_disclosure != null, "small repeat encounter exposes the first conversation to keyboard and controller")
	if replay_disclosure != null:
		var replay_scroll := replay_screen.find_child("Scroll", true, false) as ScrollContainer
		replay_disclosure.grab_focus()
		_viewport_key(replay_view, KEY_ENTER)
		await get_tree().process_frame
		await get_tree().process_frame
		var before_reading := replay_scroll.scroll_vertical
		_viewport_key(replay_view, KEY_DOWN)
		await get_tree().process_frame
		_check(replay_scroll.has_focus() and replay_scroll.scroll_vertical > before_reading and replay_scroll.scroll_vertical - before_reading <= 64, "Down incrementally reads expanded first conversation instead of jumping to actions")
		var before_page := replay_scroll.scroll_vertical
		_viewport_key(replay_view, KEY_PAGEDOWN)
		await get_tree().process_frame
		_check(replay_scroll.has_focus() and replay_scroll.scroll_vertical > before_page, "Page Down reads the expanded first conversation with reading focus")
		var before_pad := replay_scroll.scroll_vertical
		_viewport_pad(replay_view, JOY_BUTTON_DPAD_DOWN)
		await get_tree().process_frame
		_check(replay_scroll.has_focus() and replay_scroll.scroll_vertical > before_pad and replay_scroll.scroll_vertical - before_pad <= 64, "controller Down incrementally reads expanded first conversation")
		_viewport_key(replay_view, KEY_TAB)
		await get_tree().process_frame
		await get_tree().process_frame
		var replay_begin := replay_screen.find_child("Begin", true, false) as Button
		_check(replay_begin.has_focus() and replay_begin.get_global_rect().position.y >= 24.0 and replay_begin.get_global_rect().end.y <= 456.0, "Tab leaves replay reading for the visible continuation action")
	replay_view.free()
	get_tree().paused = true
	var screen := _screen()
	await get_tree().process_frame
	await get_tree().process_frame
	var outcome := screen.find_child("Outcome", true, false) as Label
	_check(outcome != null and outcome.text.contains("[b]Mara & Echo[/b]") and outcome.text.contains("7") and not outcome.text.contains("Unrelated"), "plain Label renders only the frozen name and failed segment")
	var retained := screen.find_child("Retained", true, false) as Label
	var reset := screen.find_child("Reset", true, false) as Label
	_check(retained != null and retained.text.contains("Stash") and retained.text.contains("augment") and retained.text.contains("choices"), "visible retention summary covers stash, ownership and commitments")
	_check(reset != null and reset.text.contains("Followers") and reset.text.contains("gear") and reset.text.contains("tree") and reset.text.contains("upgrades"), "visible reset summary explains the new attempt cost")
	_check(retained != null and retained.text.contains("Library") and retained.text.contains("story history") and retained.text.contains("equipped preferences"), "retention explains records and owned access separately from an attempt build")
	_check(retained != null and retained.text.contains("lasting development") and retained.text.contains("unspent Research"), "retention includes chosen lasting development and unspent Research")
	_check(reset != null and reset.text.contains("Congregation") and reset.text.contains("mutations") and reset.text.contains("Transcendence") and reset.text.contains("Duos") and reset.text.contains("Facets") and reset.text.contains("corruptions") and reset.text.contains("checkpoints") and reset.text.contains("pressure"), "reset disclosure names the developed attempt systems and fresh world")
	var finality := screen.find_child("Finality", true, false) as Label
	_check(finality != null and finality.text.contains("Ordinary reconstruction") and finality.text.contains("Segment 1"), "the decision distinguishes terminal loss from ordinary reconstruction")
	var milestones := screen.find_child("Milestones", true, false) as Label
	_check(milestones != null and milestones.text.contains("3, 6 and 9"), "committed choice disclosure identifies when their effects return")
	var repeat_dialogue := screen.find_child("Invitation", true, false) as Label
	_check(repeat_dialogue != null and repeat_dialogue.text.contains("Another account.") and not repeat_dialogue.text.contains("Do you give up?"), "returning to the same saved decision uses the compact conversation")
	var disclosure := screen.find_child("ReadFirstConversation", true, false) as Button
	var conversation := screen.find_child("FirstConversation", true, false) as Label
	_check(disclosure != null and conversation != null and not conversation.visible, "repeat encounter offers a collapsed first conversation disclosure")
	if disclosure != null and conversation != null:
		var pending_before := Global.pending_peep_summary()
		var routes_before := _routes.size()
		disclosure.grab_focus()
		_key(KEY_ENTER)
		_check(conversation.visible and conversation.text.contains("Ah. There you are.") and conversation.text.contains("Do you give up?"), "the disclosure reopens the whole first conversation")
		_check(Global.pending_peep_summary() == pending_before and SaveManager.current_save.total_runs == runs and _routes.size() == routes_before, "reading the first conversation neither changes nor navigates the terminal decision")
		disclosure.grab_focus()
		_key(KEY_ENTER)
		_check(not conversation.visible, "the first conversation can be closed without a reply")
	var prepare := screen.find_child("Prepare", true, false) as Button
	_check(prepare != null and not prepare.disabled, "PeeP offers preparation even with no unspent Research")
	if prepare != null:
		var pending_before_preparation := Global.pending_peep_summary()
		var routes_before_preparation := _routes.size()
		_check(int(Global.get_city_development_summary().get("points", -1)) == 0, "preparation inspection fixture has no unspent Research")
		prepare.grab_focus()
		_key(KEY_ENTER)
		await get_tree().process_frame
		await get_tree().process_frame
		var development := screen.find_child("CityDevelopmentScreen", true, false) as CanvasLayer
		_check(development != null and development.visible, "Prepare opens the shared development overlay for inspection")
		_check(Global.pending_peep_summary() == pending_before_preparation and SaveManager.current_save.total_runs == runs and _routes.size() == routes_before_preparation, "opening preparation preserves the failed attempt and navigation")
		if development != null:
			_key(KEY_ESCAPE)
			await get_tree().process_frame
			await get_tree().process_frame
			_check(prepare.has_focus() and screen.find_child("CityDevelopmentScreen", true, false) == null, "closing preparation with Escape restores the invoking action")
			_check(Global.pending_peep_summary() == pending_before_preparation and SaveManager.current_save.total_runs == runs and _routes.size() == routes_before_preparation, "closing preparation defers PeeP without accepting or leaving")
			if is_instance_valid(development):
				development.call("close")
	var begin := screen.find_child("Begin", true, false) as Button
	var menu := screen.find_child("Menu", true, false) as Button
	_check(not begin.disabled and begin.is_visible_in_tree() and begin.modulate.a == 1.0, "paused-tree screen has usable actions without a timed conversation lock")
	begin.grab_focus()
	_pad(JOY_BUTTON_DPAD_DOWN)
	_check(menu.has_focus(), "controller navigation can focus taking a break")
	_pad(JOY_BUTTON_DPAD_UP)
	_key(KEY_DOWN)
	_check(menu.has_focus(), "keyboard navigation can focus taking a break")
	_key(KEY_ENTER)
	_check(Global.has_pending_peep() and SaveManager.current_save.total_runs == runs and _routes.back() == Global.PATH_MAIN_MENU, "Enter respects focused menu and retains pending")
	await _settle_route()
	screen.free()
	screen = _screen()
	await get_tree().process_frame
	_key(KEY_ESCAPE)
	_check(Global.has_pending_peep() and _routes.back() == Global.PATH_MAIN_MENU, "Escape returns to menu without resolving pending")
	await _settle_route()
	screen.free()
	get_tree().paused = true
	screen = _screen()
	await get_tree().process_frame
	await get_tree().process_frame
	begin = screen.find_child("Begin", true, false) as Button
	begin.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	_click(begin)
	_check(not Global.has_pending_peep() and SaveManager.current_save.total_runs == runs + 1, "actual mouse hit accepts the visible continuation button")
	_click(begin)
	begin.pressed.emit()
	_check(not Global.has_pending_peep() and SaveManager.current_save.total_runs == runs + 1 and Global.attempt_segment == 1, "mouse continuation and repeated input create exactly one fresh attempt")
	_check(begin.disabled and _routes.back() == Global.PATH_GAME and _routes.count(Global.PATH_GAME) == 1, "acceptance disables repeat input and requests gameplay once")
	_check(not get_tree().paused, "continuing from a paused tree releases gameplay")
	_check(StoryDirector.has_flag("seen:peep_first_conversation"), "starting another attempt keeps the profile's first conversation memory")
	_finish()

func _finish() -> void:
	SaveManager.current_save = null
	get_tree().paused = false
	print("PeePContinuationUiTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
