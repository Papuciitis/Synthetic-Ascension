extends Node
## Camera focus must never become a second persistent zoom state: closing a
## service, moving away or choosing a wheel zoom returns control to the player.

const HUB := preload("res://scenes/hub/HubWorld.tscn")
var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _wheel(hub: HubWorld, button: MouseButton, factor: float = 1.0) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.factor = factor
	hub._unhandled_input(event)


func _settle(hub: HubWorld) -> void:
	for i in range(30):
		hub.call("_update_camera_view", 0.1)


func _run() -> void:
	SaveManager.current_save = null
	StoryDirector.cards_override = 0
	Global.start_new_attempt()
	var hub := HUB.instantiate() as HubWorld
	hub.departure_scene_change_enabled = false
	add_child(hub)
	await get_tree().process_frame
	hub.set_process(false)
	hub.crowd.set_process(false)
	var camera := hub._player.get_node("Camera2D") as Camera2D
	_wheel(hub, MOUSE_BUTTON_WHEEL_UP, 0.5)
	_check(is_equal_approx(hub.hub_zoom, 1.125), "a fractional wheel notch preserves trackpad precision")
	for i in range(20):
		_wheel(hub, MOUSE_BUTTON_WHEEL_UP)
	_check(is_equal_approx(hub.hub_zoom, 3.0), "manual wheel zoom is bounded at the upper edge")
	for i in range(20):
		_wheel(hub, MOUSE_BUTTON_WHEEL_DOWN)
	_check(is_equal_approx(hub.hub_zoom, 1.0), "manual wheel zoom is bounded at the lower edge")
	var has_focus: bool = hub.has_method("_focus_conversation") and hub.has_method("_update_camera_view")
	_check(has_focus, "person interaction exposes temporary camera focus")
	if has_focus:
		SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
		hub.set_hub_zoom(1.25)
		var person: Node2D = hub.crowd.service[0]["p"]
		hub._player.global_position = person.global_position + Vector2(-65, 25)
		hub.call("_focus_conversation", person, 10.0)
		hub.call("_update_camera_view", 0.1)
		_check(camera.zoom.x > 1.25 and camera.zoom.x < 1.85, "interaction zoom moves smoothly toward the person")
		_check(is_equal_approx(hub.hub_zoom, 1.25), "temporary focus preserves the chosen manual zoom")
		_settle(hub)
		_check(camera.position.distance_to(hub._camera_home) > 5.0, "interaction frames the speaker and player")
		hub._player.global_position += Vector2(90, 0)
		_settle(hub)
		_check(camera.position.distance_to(hub._camera_home) < 0.1 and is_equal_approx(camera.zoom.x, 1.25), "walking away restores player framing and the previous zoom")
		hub.call("_focus_conversation", person, 0.25)
		_settle(hub)
		_check(is_equal_approx(camera.zoom.x, 1.25), "a short interaction returns after its speech finishes")
		hub.call("_focus_conversation", person, 10.0)
		_settle(hub)
		_wheel(hub, MOUSE_BUTTON_WHEEL_UP)
		_settle(hub)
		_check(is_equal_approx(hub.hub_zoom, 2.1) and is_equal_approx(camera.zoom.x, 2.1), "wheel up from a closeup zooms further in and keeps that view after the closeup ends")
		hub.set_hub_zoom(1.5)
		hub._open_merchant()
		_settle(hub)
		_check(camera.zoom.x > 1.5 and camera.position.distance_to(hub._camera_home) > 5.0, "opening the merchant focuses its person without changing manual zoom")
		var before := hub.hub_zoom
		_wheel(hub, MOUSE_BUTTON_WHEEL_UP)
		_check(is_equal_approx(hub.hub_zoom, before), "scrolling a service panel never zooms the courtyard behind it")
		hub._on_panel_closed()
		_settle(hub)
		_check(is_equal_approx(camera.zoom.x, 1.5) and camera.position.distance_to(hub._camera_home) < 0.1, "closing a person service restores the manual camera context")
		hub.call("_focus_conversation", person, 10.0)
		_settle(hub)
		get_tree().paused = true
		_settle(hub)
		_check(is_equal_approx(camera.zoom.x, 1.5), "pausing interrupts a temporary closeup")
		get_tree().paused = false
		hub._open_library()
		_settle(hub)
		_check(get_tree().paused and camera.zoom.x > 1.5, "a paused person service still settles its camera")
		hub._on_panel_closed()
		_settle(hub)
		_check(not get_tree().paused and is_equal_approx(camera.zoom.x, 1.5), "closing a paused service restores the camera and the courtyard")
		hub.call("_focus_conversation", person, 10.0)
		_settle(hub)
		SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
		hub.call("_update_camera_view", 0.1)
		_check(is_equal_approx(camera.zoom.x, 1.5) and camera.position.distance_to(hub._camera_home) < 0.1, "Reduced Motion immediately restores the camera and suppresses automatic closeups")
		hub.call("_focus_conversation", person, 10.0)
		_settle(hub)
		_check(is_equal_approx(camera.zoom.x, 1.5), "Reduced Motion keeps service interactions at the chosen manual zoom")
		SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	hub.queue_free()
	await get_tree().process_frame
	print("HubCameraFocusTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
