extends Button
## Cloth subject markers tucked beneath the cover. Matches the stall's bindings.
const Kit := preload("res://ui/widgets/chambers/ChamberKit.gd")
const FONT := preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
var volume := 1
var tint := Color.WHITE

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool) -> void: queue_redraw())

func _draw() -> void:
	var selected := button_pressed or has_focus() or is_hovered()
	var reach := size.x if selected else size.x * 0.85
	var cloth := Color(0.46, 0.25, 0.16).lerp(tint.darkened(0.40), 0.65)
	if selected:
		cloth = cloth.lightened(0.13)
	var points := PackedVector2Array([Vector2.ZERO, Vector2(reach, 0), Vector2(reach - 5, size.y * 0.5), Vector2(reach, size.y), Vector2(0, size.y)])
	draw_colored_polygon(points, cloth)
	draw_line(Vector2(2, 3), Vector2(reach - 5, 3), Color(Kit.GOLD, 0.6), 2)
	var font_size := clampi(roundi(size.y * 0.48), 12, 18)
	draw_string(FONT, Vector2(0, (size.y + FONT.get_ascent(font_size)) * 0.5 - 2), Kit.roman(volume), HORIZONTAL_ALIGNMENT_CENTER, reach - 4, font_size, Kit.GOLD_BRIGHT if selected else Kit.PARCHMENT)
