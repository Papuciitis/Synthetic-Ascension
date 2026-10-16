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
		_click(quitting.find_child("Quit", true, false) as Button)
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
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	small_view.push_input(down, true)
	down.pressed = false
	small_view.push_input(down, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(small_begin.has_focus() and small_begin.get_global_rect().position.y >= 24.0 and small_begin.get_global_rect().end.y <= 456.0, "Down from the small-window reading position brings the focused action fully into view")
	small_view.free()
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
	var begin := screen.find_child("Begin", true, false) as Button
	var menu := screen.find_child("Menu", true, false) as Button
	_check(begin.has_focus() and not begin.disabled and begin.is_visible_in_tree() and begin.modulate.a == 1.0, "paused-tree screen offers a visible focused action immediately")
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
	_click(begin)
	_check(not Global.has_pending_peep() and SaveManager.current_save.total_runs == runs + 1, "actual mouse hit accepts the visible continuation button")
	_click(begin)
	begin.pressed.emit()
	_check(not Global.has_pending_peep() and SaveManager.current_save.total_runs == runs + 1 and Global.attempt_segment == 1, "mouse continuation and repeated input create exactly one fresh attempt")
	_check(begin.disabled and _routes.back() == Global.PATH_GAME and _routes.count(Global.PATH_GAME) == 1, "acceptance disables repeat input and requests gameplay once")
	_check(not get_tree().paused, "continuing from a paused tree releases gameplay")
	_finish()

func _finish() -> void:
	SaveManager.current_save = null
	get_tree().paused = false
	print("PeePContinuationUiTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
