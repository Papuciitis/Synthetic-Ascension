extends Control
## Page furniture and a turning leaf; reading state belongs to HubLibrary.
const BOOK_PATH := "res://assets/ui/library/open_book_pixel.png"
var turn_progress: float = 1.0:
	set(value):
		turn_progress = clampf(value, 0.0, 1.0)
		if is_instance_valid(_turn_leaf):
			_turn_leaf.queue_redraw()
			_update_turn_print()
var turn_caption := "":
	set(value):
		turn_caption = value
		if is_instance_valid(_turn_print):
			_turn_print.text = value
var _book: Texture2D
var _turn_leaf: Control
var _turn_print: RichTextLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(BOOK_PATH):
		_book = load(BOOK_PATH) as Texture2D
	resized.connect(queue_redraw)
	_turn_leaf = Control.new()
	_turn_leaf.name = "PageTurnLeaf"
	_turn_leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_leaf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_turn_leaf.z_index = 2
	_turn_leaf.draw.connect(_draw_turn_leaf)
	add_child(_turn_leaf)
	_turn_print = RichTextLabel.new()
	_turn_print.name = "TurningPagePrint"
	_turn_print.bbcode_enabled = true
	_turn_print.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_print.scroll_active = false
	_turn_print.clip_contents = true
	_turn_print.add_theme_font_size_override("normal_font_size", 20)
	_turn_print.add_theme_font_size_override("bold_font_size", 20)
	_turn_print.add_theme_color_override("default_color", Color(0.20, 0.115, 0.065))
	_turn_leaf.add_child(_turn_print)
	resized.connect(_update_turn_print)
	_update_turn_print()

func _draw() -> void:
	if _book != null:
		draw_texture_rect(_book, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.09, 0.045))
		draw_rect(Rect2(size * Vector2(0.07, 0.08), size * Vector2(0.86, 0.84)), Color(0.72, 0.60, 0.41))

func _draw_turn_leaf() -> void:
	if turn_progress >= 1.0:
		return
	var hinge := size * Vector2(0.5, 0.12)
	var reach := cos(turn_progress * PI) * size.x * 0.39
	var curl := sin(turn_progress * PI) * size.y * 0.045
	var bottom := size.y * 0.72
	var leaf := PackedVector2Array([hinge, hinge + Vector2(reach, -curl), hinge + Vector2(reach, bottom + curl), hinge + Vector2(0, bottom)])
	if _book != null:
		var paper_uv := PackedVector2Array([Vector2(0.55, 0.14), Vector2(0.88, 0.14), Vector2(0.88, 0.84), Vector2(0.55, 0.84)])
		_turn_leaf.draw_polygon(leaf, PackedColorArray([Color.WHITE]), paper_uv, _book)
	else:
		_turn_leaf.draw_colored_polygon(leaf, Color(0.78, 0.68, 0.48))
	_turn_leaf.draw_line(hinge + Vector2(reach, -curl), hinge + Vector2(reach, bottom + curl), Color(0.27, 0.17, 0.08, 0.65), 2)

func _update_turn_print() -> void:
	if not is_instance_valid(_turn_print):
		return
	var projection := cos(turn_progress * PI)
	_turn_print.visible = turn_progress < 0.5 and not turn_caption.is_empty()
	_turn_print.position = size * Vector2(0.5 + 0.03 * maxf(0.0, projection), 0.15)
	_turn_print.size = size * Vector2(0.32, 0.63)
	_turn_print.scale = Vector2(maxf(0.001, projection), 1.0)
