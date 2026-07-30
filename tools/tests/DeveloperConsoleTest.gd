extends SceneTree

var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var global: Node = root.get_node_or_null("Global")
	_check(global != null and "debug_dev_mode" in global, "global exposes developer-session gate")
	if global != null and "debug_dev_mode" in global:
		_check(not bool(global.get("debug_dev_mode")), "developer-session gate defaults off")

	var packed := load("res://ui/widgets/PerformanceOverlay.tscn") as PackedScene
	_check(packed != null, "developer console scene loads")
	if packed == null:
		_finish()
		return
	var console := packed.instantiate()
	root.add_child(console)
	await process_frame

	for path in [
		"Margin/Root/Header/Title",
		"Margin/Root/Tabs/Overview",
		"Margin/Root/Tabs/Enemies",
		"Margin/Root/Tabs/Performance",
		"Margin/Root/Tabs/Tests",
		"Margin/Root/Footer/MainMenu",
		"Margin/Root/Footer/ExitGame",
	]:
		_check(console.has_node(path), "console contains %s" % path)
	_check(console.has_method("toggle_overlay"), "console exposes toggle action")
	_check(console.has_method("request_main_menu"), "console exposes guarded menu action")
	_check(console.has_method("request_exit_game"), "console exposes guarded exit action")
	_check(console.has_method("resize_edges_at"), "console exposes resize edge detection")
	_check(console.has_method("resized_rect"), "console exposes resize geometry")
	_check(console.has_method("blocks_wasd_ui_navigation"), "console exposes WASD navigation policy")
	var panel_style := console.get_theme_stylebox("panel") as StyleBoxFlat
	_check(panel_style != null and is_equal_approx(panel_style.bg_color.a, 0.50), "console background is fifty percent transparent")
	if console.has_method("resize_edges_at"):
		_check(int(console.call("resize_edges_at", Vector2(999, 300), Vector2(1000, 600))) == 2, "right edge is detected")
		_check(int(console.call("resize_edges_at", Vector2(999, 599), Vector2(1000, 600))) == 10, "bottom-right corner is detected")
	if console.has_method("resized_rect"):
		var shrunk := console.call("resized_rect", Rect2(100, 100, 1000, 700), 10, Vector2(-900, -600), Vector2(1920, 1080)) as Rect2
		_check(shrunk.size == Vector2(720, 480), "resize clamps to the minimum size")
		var expanded := console.call("resized_rect", Rect2(100, 100, 1000, 700), 10, Vector2(1200, 900), Vector2(1920, 1080)) as Rect2
		_check(expanded.end.x <= 1920.0 and expanded.end.y <= 1080.0, "resize remains inside the viewport")
	if global != null and "debug_dev_mode" in global:
		global.set("debug_dev_mode", false)
		console.call("toggle_overlay")
		_check(not console.visible, "ordinary sessions cannot open the console")
		global.set("debug_dev_mode", true)
		console.call("toggle_overlay")
		_check(console.visible, "developer sessions can open the console")
		var wasd := InputEventKey.new()
		wasd.physical_keycode = KEY_W
		wasd.pressed = true
		var arrow := InputEventKey.new()
		arrow.keycode = KEY_UP
		arrow.pressed = true
		_check(bool(console.call("blocks_wasd_ui_navigation", wasd)), "visible console blocks W from UI navigation")
		_check(not bool(console.call("blocks_wasd_ui_navigation", arrow)), "visible console preserves arrow-key UI navigation")
		console.visible = false
		_check(not bool(console.call("blocks_wasd_ui_navigation", wasd)), "hidden console leaves W input untouched")
		console.visible = true
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		console.call("_input", escape)
		_check(not console.visible, "Escape closes the developer console")
		var backtick := InputEventKey.new()
		backtick.keycode = 96
		backtick.pressed = true
		console.call("_input", backtick)
		_check(console.visible, "backtick opens the developer console")
		console.visible = false
		var f8 := InputEventKey.new()
		f8.keycode = KEY_F8
		f8.pressed = true
		console.call("_input", f8)
		_check(not console.visible, "F8 does not toggle or stop the developer console")
		global.set("debug_dev_mode", false)

	if console.has_node("Margin/Root/Tabs/Performance/Content/ProjectileStress"):
		var stress := console.get_node("Margin/Root/Tabs/Performance/Content/ProjectileStress") as CheckBox
		_check(not stress.button_pressed, "projectile stress defaults off")
	else:
		_check(false, "performance tab contains projectile stress control")

	var hub := load("res://ui/screens/HubShop.tscn") as PackedScene
	_check(hub != null, "developer hub scene loads")
	if hub != null:
		var hub_instance := hub.instantiate()
		_check(hub_instance.has_node("DeveloperConsole"), "developer hub includes the developer console")
		hub_instance.free()

	var tools: Node = root.get_node_or_null("DevSetCollisionTools")
	_check(tools != null, "set/collision action service exists")
	if tools != null:
		for method in [
			"grant_set", "clear_sets", "force_breakpoint_notification",
			"spawn_collision_fixture", "restart_opening", "jump_to_segment",
		]:
			_check(tools.has_method(method), "action service exposes %s" % method)

	console.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("DeveloperConsoleTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
