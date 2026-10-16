extends CanvasLayer
## Shared pause owner. Children consume their own cancellation first; this
## layer is installed first so its unhandled Escape is the final UI fallback.
const THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const FRAME := preload("res://ui/components/ArcaneFrame.gd")
const RULE := preload("res://ui/components/ArcaneRule.gd")
const SETTINGS := preload("res://ui/screens/settings/SettingsScreen.tscn")
const DIALOG := preload("res://ui/components/ArcaneDialog.gd")

var resume_scene: String = ""
var can_open: Callable
var is_open := false
var _prior_paused := false
var _prior_focus: Control
var _leaving := false
var _destination := &"menu"
var _root: Control
var _surface: Control
var _panel: PanelContainer
var _entry: Button
var _resume_button: Button
var _settings_button: Button
var _menu_button: Button
var _quit_button: Button
var _settings: Control
var _confirm: Control

func _ready() -> void:
	name = "PauseMenu"
	layer = 240
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"pause_handoff_owner")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = THEME
	add_child(_root)
	_entry = Button.new()
	_entry.name = "Pause"
	_entry.text = "Pause"
	_entry.tooltip_text = "Pause / Escape / Controller Cancel"
	_root.add_child(_entry)
	# The upper-right edge belongs to the backpack (Game) and zoom controls
	# (Hub); the lower-right edge is free in both gameplay HUDs.
	_entry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_entry.offset_left = -112
	_entry.offset_right = -20
	_entry.offset_top = -58
	_entry.offset_bottom = -18
	_entry.pressed.connect(open)
	_surface = Control.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_surface)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.005, 0.004, 0.003, 0.8)
	_surface.add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"ArcanePanel"
	var panel_style := THEME.get_stylebox("panel", "ArcanePanel").duplicate() as StyleBoxFlat
	panel_style.bg_color.a = 1.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.custom_minimum_size = Vector2(400, 0)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for edge in [&"left", &"right", &"top", &"bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.theme_type_variation = &"ArcaneHeading"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(RULE.new())
	_resume_button = _button(box, "Resume", resume)
	_settings_button = _button(box, "Settings", _open_settings)
	_menu_button = _button(box, "Main Menu", _ask_leave.bind(&"menu"))
	_quit_button = _button(box, "Quit", _ask_leave.bind(&"quit"))
	var buttons: Array[Button] = [_resume_button, _settings_button, _menu_button, _quit_button]
	for i in range(buttons.size()):
		var button := buttons[i]
		var previous := button.get_path_to(buttons[(i + buttons.size() - 1) % buttons.size()])
		var next := button.get_path_to(buttons[(i + 1) % buttons.size()])
		button.focus_previous = previous
		button.focus_next = next
		button.focus_neighbor_top = previous
		button.focus_neighbor_bottom = next
	_panel.add_child(FRAME.new())
	_settings = SETTINGS.instantiate()
	_surface.add_child(_settings)
	_settings.closed.connect(func() -> void: _settings_button.call_deferred("grab_focus"))
	_confirm = DIALOG.new()
	_surface.add_child(_confirm)
	_confirm.cancelled.connect(_return_from_confirmation)
	_confirm.confirmed.connect(_leave)
	_surface.hide()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _button(box: VBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = text.replace(" ", "")
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	box.add_child(button)
	return button

func open() -> void:
	if is_open or _leaving or Global.has_pending_peep() or (can_open.is_valid() and not can_open.call()):
		return
	_prior_paused = get_tree().paused
	_prior_focus = get_viewport().gui_get_focus_owner()
	is_open = true
	# Closed: final fallback after the scene's own cancellation handlers.
	# Open: this modal and its Settings/dialog children own cancellation first.
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	get_tree().paused = true
	_entry.hide()
	_surface.show()
	_resume_button.grab_focus()

## The recognition overlay releases its temporary freeze while this menu is
## open. Take over that pause and discard the snapshot of its expired freeze.
func adopt_pause_handoff() -> bool:
	if not is_open or _leaving:
		return false
	_prior_paused = false
	return true

func resume() -> void:
	if not is_open or _leaving:
		return
	_settings.hide()
	_confirm.hide()
	_surface.hide()
	_entry.show()
	is_open = false
	get_parent().move_child(self, 0)
	get_tree().paused = _prior_paused
	if is_instance_valid(_prior_focus) and _prior_focus.is_visible_in_tree() and _prior_focus != _entry:
		_prior_focus.call_deferred("grab_focus")
	else:
		get_viewport().gui_release_focus()

func _open_settings() -> void:
	if is_open and not _leaving:
		_settings.open()

func _ask_leave(destination: StringName) -> void:
	if not is_open or _leaving:
		return
	_destination = destination
	var message: String
	if SaveManager.current_save == null:
		message = "This test run has no save slot. Its progress cannot be continued after leaving."
	elif Global.has_pending_peep():
		message = "Your pending continuation decision will be saved for Continue."
	elif resume_scene == Global.PATH_HUB_WORLD:
		message = "Your attempt will be saved. Continue returns to the hub, with your gear and pending choices."
	else:
		message = "Your attempt will be saved. Continue returns to your Wardstone, or the segment start if none is active. Your current position is not a checkpoint."
	_confirm.present("Return to Main Menu?" if destination == &"menu" else "Quit the Game?", message, "Save & Leave" if SaveManager.current_save != null else "Leave", "Stay Paused")

	(_confirm.get("_cancel") as Button).call_deferred("grab_focus")

func _return_from_confirmation() -> void:
	var button := _menu_button if _destination == &"menu" else _quit_button
	button.call_deferred("grab_focus")

func _leave(_text: String) -> void:
	if not is_open or _leaving:
		return
	_leaving = true
	# Explicit snapshot even when the deferred autosave has no dirty timer.
	# Preserve pending terminal continuation's original resume target.
	if SaveManager.current_save != null and not Global.has_pending_peep():
		SaveManager.current_save.attempt_resume_scene = resume_scene
	Global.save_current_profile()
	Engine.time_scale = 1.0
	if _destination == &"quit":
		Global.request_quit()
	else:
		# Keep PAUSABLE root services frozen through goto_scene's awaited frames.
		# MainMenu._ready owns the unpause at the actual destination.
		Global.goto_main_menu()

func _on_focus_changed(control: Control) -> void:
	if not is_open or _leaving or _settings.visible or _confirm.visible or control == null:
		return
	if not _panel.is_ancestor_of(control):
		_resume_button.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if is_open and _leaving:
		get_viewport().set_input_as_handled()
		return
	# Settings capture and GUI focus have had first refusal. Remaining
	# management shortcuts must not reach the HUD underneath this modal.
	# Cancel has priority even if a management action was rebound to it.
	if is_open and not event.is_action_pressed(&"ui_cancel") and (event.is_action_pressed(&"bag_toggle") or event.is_action_pressed(&"ascension_open")):
		get_viewport().set_input_as_handled()
		return
	if event.is_echo() or not event.is_action_pressed(&"ui_cancel"):
		return
	var was_open := is_open
	if is_open:
		if _leaving or _settings.visible or _confirm.visible:
			return
		resume()
	else:
		open()
	if is_open or was_open:
		get_viewport().set_input_as_handled()
