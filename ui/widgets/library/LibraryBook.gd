extends Button
## A physical binding. Titles use game fonts, never baked image lettering.
const Kit := preload("res://ui/widgets/chambers/ChamberKit.gd")
const TITLE_FONT := preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
const SPINE_PATH := "res://assets/ui/library/book_spine_pixel.png"
var book_title := ""
var volume := 1
var discovered_pages := 0
var total_pages := 0
var unread_pages := 0
var tint := Color.WHITE
var _spine: Texture2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if ResourceLoader.exists(SPINE_PATH):
		var source := load(SPINE_PATH) as Texture2D
		if source != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = source
			# Measured opaque binding, excluding faint generated alpha at the edges.
			atlas.region = Rect2(150, 70, 415, 2090)
			atlas.filter_clip = true
			_spine = atlas
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	refresh_marks()

func refresh_marks() -> void:
	tooltip_text = "%s\n%d of %d pages discovered · %d unread\nOpen this book" % [book_title, discovered_pages, total_pages, unread_pages]
	queue_redraw()

func _draw() -> void:
	var lifted := is_hovered() or has_focus()
	var lift := -4.0 if lifted else 0.0
	var rect := Rect2(Vector2(0, lift), size)
	var material := tint if discovered_pages > 0 else tint.darkened(0.28)
	if _spine != null:
		draw_set_transform(Vector2(3, size.y + lift + 4), -PI / 2.0)
		draw_texture_rect(_spine, Rect2(Vector2.ZERO, Vector2(size.y, size.x)), false, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2(0, size.y + lift), -PI / 2.0)
		draw_texture_rect(_spine, Rect2(Vector2.ZERO, Vector2(size.y, size.x)), false, material)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(rect, Color(0.22, 0.13, 0.09) * material)
		draw_rect(rect.grow(-2), Kit.GOLD_DIM, false, 2)
	var label_size := clampi(roundi(size.x / 9.0), 12, 22)
	while TITLE_FONT.get_string_size(book_title, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x > size.x - 16 and label_size > 10:
		label_size -= 1
	var ink := Kit.GOLD_BRIGHT if lifted else Kit.PARCHMENT
	var title_y := lift + size.y * 0.46 + TITLE_FONT.get_ascent(label_size) * 0.35
	draw_string(TITLE_FONT, Vector2(4, title_y), book_title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, label_size, ink)
	var marks := "%s  ·  %d/%d" % [Kit.roman(volume), discovered_pages, total_pages]
	draw_string(TITLE_FONT, Vector2(4, lift + size.y * 0.76), marks, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, maxi(10, label_size - 4), Kit.BODY)
	if unread_pages > 0:
		var x := size.x - 16.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, lift), Vector2(x + 8, lift), Vector2(x + 8, lift + 19), Vector2(x + 4, lift + 15), Vector2(x, lift + 19)]), Kit.GOLD)
