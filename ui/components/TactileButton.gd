extends Button

@export var hover_scale: float = 1.02
@export var press_scale: float = 0.98
@export var tween_time: float = 0.08

@export var hover_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var press_tint: Color = Color(1.0, 1.0, 1.0, 0.96)

var _base_scale: Vector2 = Vector2.ONE
var _base_modulate: Color = Color(1, 1, 1, 1)
var _tw: Tween = null

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_base_scale = scale
	_base_modulate = modulate

	resized.connect(_set_pivot_center)
	call_deferred("_set_pivot_center")

	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(_on_pressed_sfx)

func _set_pivot_center() -> void:
	pivot_offset = size * 0.5

func _kill_tween() -> void:
	if _tw != null and _tw.is_running():
		_tw.kill()
	_tw = null

func _tween_to(target_scale: Vector2, target_mod: Color, ease_mode: int = Tween.EASE_OUT) -> void:
	_kill_tween()
	_tw = create_tween()
	_tw.set_trans(Tween.TRANS_QUAD)
	_tw.set_ease(ease_mode)
	_tw.set_parallel(true)
	_tw.tween_property(self, "scale", target_scale, tween_time)
	_tw.tween_property(self, "modulate", target_mod, tween_time)

func _on_hover() -> void:
	if disabled:
		return
	if not is_inside_tree():
		return
	if SfxManager != null:
		SfxManager.play_ui(&"ui_hover")
	_tween_to(_base_scale * hover_scale, hover_tint, Tween.EASE_OUT)

func _on_unhover() -> void:
	if disabled:
		return
	_tween_to(_base_scale, _base_modulate, Tween.EASE_OUT)

func _on_down() -> void:
	if disabled:
		return
	_tween_to(_base_scale * press_scale, press_tint, Tween.EASE_OUT)

func _on_up() -> void:
	if disabled:
		return
	_on_hover()

func _on_pressed_sfx() -> void:
	if not is_inside_tree():
		return
	if SfxManager != null:
		SfxManager.play_ui(&"ui_click")
