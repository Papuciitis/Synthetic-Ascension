extends Control
## The end of an attempt, as a moment rather than a dialog: the frozen world
## drains to ash and sinks into the dark, embers drift down through it, the
## title settles out of the dark, the star rule draws itself out from its
## centre and the three choices arrive one after another, as front-end menu
## entries.
##
## The keys mean what they always meant: Enter restarts and Escape returns to
## the menu, whichever entry the cursor last lit. The entries take the mouse
## once they are visible. Everything honours Reduced Motion, and the tree is
## paused under this screen, so it runs in PROCESS_MODE_ALWAYS.

signal restart_requested
signal menu_requested
signal quit_requested

const ChamberKit := preload("res://ui/widgets/chambers/ChamberKit.gd")

@onready var btn_restart: Button = $CenterContainer/Panel/Margin/VBox/Buttons/Restart
@onready var btn_menu: Button = $CenterContainer/Panel/Margin/VBox/Buttons/Menu
@onready var btn_quit: Button = $CenterContainer/Panel/Margin/VBox/Buttons/Quit

var _veil: ShaderMaterial = null
var _glow: TextureRect = null
var _breath_tw: Tween = null

func _ready() -> void:
	# allow UI to work even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	btn_restart.pressed.connect(func(): restart_requested.emit())
	btn_menu.pressed.connect(func(): menu_requested.emit())
	btn_quit.pressed.connect(func(): quit_requested.emit())

	for b in [btn_restart, btn_menu, btn_quit]:
		# Hover lights an entry (focus is the front end's selection), but a
		# key press on a lit entry must not stand in for Enter/Escape.
		b.gui_input.connect(_on_entry_input.bind(b))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_dress()
	_play()

func _unhandled_input(event: InputEvent) -> void:
	# ESC -> menu, Enter -> restart
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			menu_requested.emit()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			restart_requested.emit()
			get_viewport().set_input_as_handled()


## The entries are pressed with the mouse. Keyboard and pad presses that
## would activate a lit entry go where they always went: Enter restarts,
## anything else that means "accept" does nothing.
func _on_entry_input(event: InputEvent, _entry: Button) -> void:
	if event is InputEventMouse:
		return
	# Enter always restarts and Escape always leaves, as before; the keys and
	# the pad must not walk the light onto an entry Enter would not take.
	for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]:
		if event.is_action(action):
			get_viewport().set_input_as_handled()
			return
	if not event.is_action(&"ui_accept"):
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			restart_requested.emit()


# ---------------------------------------------------------------------------
# Presentation
# ---------------------------------------------------------------------------

func _dress() -> void:
	var veil_rect := get_node_or_null("ColorRect") as ColorRect
	if veil_rect != null:
		_veil = veil_rect.material as ShaderMaterial
	var embers := get_node_or_null("Embers") as Control
	if embers != null:
		var screen := Vector2(1920, 1080)
		_glow = ChamberKit.light_pool(Vector2(screen.x * 0.5, screen.y + 90.0), Vector2(1000, 420), ChamberKit.EMBER, 1.0)
		_glow.modulate.a = 0.0
		embers.add_child(_glow)
		embers.add_child(ChamberKit.ember_fall(screen.x, screen.y))
	var hint := get_node_or_null("CenterContainer/Panel/Margin/VBox/Hint") as Label
	if hint != null:
		hint.add_theme_color_override("font_color", ChamberKit.BODY)
	var keys := get_node_or_null("CenterContainer/Panel/Margin/VBox/Keys") as Label
	if keys != null:
		keys.add_theme_color_override("font_color", Color(ChamberKit.GOLD_DIM, 0.9))


func _play() -> void:
	var still := ChamberKit.reduced()
	var vbox := "CenterContainer/Panel/Margin/VBox/"
	var title := get_node_or_null(vbox + "Title") as Control
	var hint := get_node_or_null(vbox + "Hint") as Control
	var rule := get_node_or_null(vbox + "Rule") as Control
	var keys := get_node_or_null(vbox + "Keys") as Control
	var entries: Array[Control] = [btn_restart, btn_menu, btn_quit]
	var embers := get_node_or_null("Embers") as Control
	for c in [title, hint, rule, keys, embers]:
		if c != null:
			c.modulate.a = 0.0
	for e in entries:
		e.modulate.a = 0.0
	if _veil != null:
		_veil.set_shader_parameter("amount", 0.0)

	# The death frame is heavy; begin once it has passed.
	if not await ChamberKit.settle(self):
		return

	var tw := ChamberKit.tween(self).set_parallel(true)
	if _veil != null:
		tw.tween_method(func(v: float) -> void: _veil.set_shader_parameter("amount", v), 0.0, 1.0, 0.35 if still else 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if embers != null:
		tw.tween_property(embers, "modulate:a", 1.0, 0.4 if still else 2.2).set_delay(0.0 if still else 0.3)
	if _glow != null:
		tw.tween_property(_glow, "modulate:a", 0.13, 0.4 if still else 2.4).set_delay(0.0 if still else 0.4)

	if still:
		for c in [title, hint, rule, keys]:
			if c != null:
				tw.tween_property(c, "modulate:a", 1.0, 0.3)
		for e in entries:
			tw.tween_property(e, "modulate:a", 1.0, 0.3)
		tw.chain().tween_callback(_arm)
		return

	if title != null:
		# Out of the dark, settling a little as it arrives.
		title.pivot_offset = title.size * 0.5
		title.scale = Vector2.ONE * 1.1
		tw.tween_property(title, "modulate:a", 1.0, 1.3).set_delay(0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_property(title, "scale", Vector2.ONE, 2.4).set_delay(0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if hint != null:
		tw.tween_property(hint, "modulate:a", 1.0, 0.9).set_delay(1.0)
	if rule != null:
		rule.pivot_offset = rule.size * 0.5
		rule.scale = Vector2(0.05, 1.0)
		tw.tween_property(rule, "modulate:a", 1.0, 0.3).set_delay(0.85)
		tw.tween_property(rule, "scale", Vector2.ONE, 0.9).set_delay(0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var i := 0
	for e in entries:
		tw.tween_property(e, "modulate:a", 1.0, 0.45).set_delay(1.35 + 0.11 * i)
		i += 1
	if keys != null:
		tw.tween_property(keys, "modulate:a", 1.0, 0.6).set_delay(1.9)
	tw.chain().tween_callback(_arm)
	# Arm the entries as soon as they can be seen, not when the last fade ends.
	var arm_tw := ChamberKit.tween(self)
	arm_tw.tween_interval(1.45)
	arm_tw.tween_callback(_arm)


## The entries take the mouse, and Restart (Enter's choice) is lit.
func _arm() -> void:
	if btn_restart.mouse_filter == Control.MOUSE_FILTER_STOP:
		return
	for b in [btn_restart, btn_menu, btn_quit]:
		b.mouse_filter = Control.MOUSE_FILTER_STOP
	if btn_restart.has_method("select_quietly"):
		btn_restart.call("select_quietly")
	_breathe()


## The ember light at the foot of the screen rises and falls, slowly.
func _breathe() -> void:
	if _glow == null or ChamberKit.reduced():
		return
	if _breath_tw != null and _breath_tw.is_running():
		return
	_breath_tw = ChamberKit.tween(self).set_loops()
	_breath_tw.tween_property(_glow, "modulate:a", 0.18, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tw.tween_property(_glow, "modulate:a", 0.11, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
