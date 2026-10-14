extends Button
## Rooted cloth marker. Its middle lies under the leaf; its printed tail is a button.
const FONT := preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
const Kit := preload("res://ui/widgets/chambers/ChamberKit.gd")
const CLOTH_PATH := "res://assets/ui/library/bookmark_cloth_pixel.png"
var label := "":
	set(value):
		label = value
		queue_redraw()
var active := false:
	set(value):
		active = value
		queue_redraw()
var tint := Color.WHITE:
	set(value):
		tint = value
		queue_redraw()
# Relative to the tail button. Root positions this above the paper's upper edge.
var root_rect := Rect2():
	set(value):
		root_rect = value
		queue_redraw()
var volume := 1
var rest_position := Vector2.ZERO
var _cloth: AtlasTexture
var _root: AtlasTexture
var _tail: AtlasTexture
var _tail_pull := 0.0:
	set(value):
		_tail_pull = clampf(value, 0.0, 6.0)
		queue_redraw()
var _pull_tween: Tween
var _held := false

func _atlas(source: Texture2D, rectangle: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = source
	result.region = rectangle
	result.filter_clip = true
	return result

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if ResourceLoader.exists(CLOTH_PATH):
		var source := load(CLOTH_PATH) as Texture2D
		_cloth = _atlas(source, Rect2(194, 101, 405, 1782))
		_root = _atlas(source, Rect2(194, 101, 405, 183))
		_tail = _atlas(source, Rect2(194, 1330, 405, 553))
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(_pull_down)
	button_up.connect(_pull_release)
	toggled.connect(func(_on: bool) -> void: queue_redraw())

func _process(_delta: float) -> void:
	if (disabled or not is_visible_in_tree() or Kit.reduced()) and (_tail_pull > 0.0 or _pull_tween != null):
		_reset_pull()

func _reset_pull() -> void:
	if is_instance_valid(_pull_tween):
		_pull_tween.kill()
	_pull_tween = null
	_held = false
	_tail_pull = 0.0

func _pull_down() -> void:
	if disabled or Kit.reduced():
		_reset_pull()
		return
	_held = true
	_animate_pull(6.0, 0.09)

func _pull_release() -> void:
	_held = false
	if disabled or Kit.reduced():
		_reset_pull()
		return
	_animate_pull(0.0, 0.18)

func _animate_pull(target: float, duration: float) -> void:
	if is_instance_valid(_pull_tween):
		_pull_tween.kill()
	_pull_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	_pull_tween.tween_property(self, "_tail_pull", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func tail_geometry() -> Dictionary:
	var engaged := not disabled and (has_focus() or is_hovered())
	var lift := -2.0 if engaged and not Kit.reduced() else 0.0
	var font_size := clampi(roundi(size.x * 0.16), 17, 24)
	while FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x * 0.86 and font_size > 17:
		font_size -= 1
	return {"root": root_rect, "tail": Rect2(Vector2(0, lift), Vector2(size.x, size.y + _tail_pull)), "font_size": font_size, "baseline": lift + size.y * 0.35 + FONT.get_ascent(font_size) * 0.4 + _tail_pull}

func set_book_open_progress(progress: float, book_width: float) -> void:
	var gutter := book_width * 0.5
	var left_attached := rest_position.x + size.x * 0.5 < gutter
	var reach := maxf(0.0, -cos(PI * clampf(progress, 0.0, 1.0))) if left_attached else 1.0
	position = Vector2(gutter + (rest_position.x - gutter) * reach, rest_position.y)
	scale.x = reach
	visible = reach > 0.001

func _draw() -> void:
	if _tail == null:
		return
	var selected := _held or button_pressed or has_focus() or is_hovered()
	var material := tint.lightened(0.05) if active else tint
	if selected and not disabled:
		material = material.lightened(0.10)
	if disabled:
		material = material.darkened(0.35)
	var geometry := tail_geometry()
	if _root != null and geometry.root.has_area():
		draw_texture_rect(_root, geometry.root, false, material)
	draw_texture_rect(_tail, geometry.tail, false, material)
	draw_string(FONT, Vector2(size.x * 0.07, geometry.baseline), label, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.86, geometry.font_size, Color(1.0, 0.93, 0.76))
