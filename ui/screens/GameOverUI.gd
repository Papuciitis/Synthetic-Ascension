extends Control

signal restart_requested
signal menu_requested
signal quit_requested

@onready var btn_restart: Button = $CenterContainer/Panel/Margin/VBox/Buttons/Restart
@onready var btn_menu: Button = $CenterContainer/Panel/Margin/VBox/Buttons/Menu
@onready var btn_quit: Button = $CenterContainer/Panel/Margin/VBox/Buttons/Quit

func _ready() -> void:
	# allow UI to work even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	btn_restart.focus_mode = Control.FOCUS_NONE
	btn_menu.focus_mode = Control.FOCUS_NONE
	btn_quit.focus_mode = Control.FOCUS_NONE

	btn_restart.pressed.connect(func(): restart_requested.emit())
	btn_menu.pressed.connect(func(): menu_requested.emit())
	btn_quit.pressed.connect(func(): quit_requested.emit())

func _unhandled_input(event: InputEvent) -> void:
	# ESC -> menu, Enter -> restart
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			menu_requested.emit()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			restart_requested.emit()
			get_viewport().set_input_as_handled()
