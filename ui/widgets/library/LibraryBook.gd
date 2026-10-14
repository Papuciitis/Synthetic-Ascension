extends Button
## Leather binding lettering is measured inside the inset, never across its bands.
const Kit := preload("res://ui/widgets/chambers/ChamberKit.gd")
const TITLE_FONT := preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
const SPINE_PATH := "res://assets/ui/library/book_spine_pixel.png"
const CLOTH_PATH := "res://assets/ui/library/bookmark_cloth_pixel.png"
var book_title := "":
	set(value):
		book_title = value
		queue_redraw()
var volume := 1
var discovered_pages := 0
var total_pages := 0
var unread_pages := 0
var research_target := false
var tint := Color.WHITE
var _spine: Texture2D
var _marker: AtlasTexture

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
			atlas.region = Rect2(150, 70, 415, 2090)
			atlas.filter_clip = true
			_spine = atlas
	if ResourceLoader.exists(CLOTH_PATH):
		_marker = AtlasTexture.new()
		_marker.atlas = load(CLOTH_PATH) as Texture2D
		_marker.region = Rect2(194, 101, 405, 1782)
		_marker.filter_clip = true
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	refresh_marks()

func refresh_marks() -> void:
	tooltip_text = "%s\n%d of %d pages discovered · %d unread\nOpen this book" % [book_title, discovered_pages, total_pages, unread_pages]
	queue_redraw()

func title_layout() -> Dictionary:
	var bounds := Rect2(size * Vector2(0.10, 0.16), size * Vector2(0.80, 0.68))
	var font_size := clampi(roundi(size.y * 0.43), 10, 22)
	var lines := PackedStringArray()
	var widths := PackedFloat32Array()
	while font_size >= 7:
		lines.clear()
		var line := ""
		for word: String in book_title.split(" ", false):
			var candidate := word if line.is_empty() else line + " " + word
			if not line.is_empty() and TITLE_FONT.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > bounds.size.x:
				lines.append(line)
				line = word
			else:
				line = candidate
		if not line.is_empty():
			lines.append(line)
		widths.clear()
		var fits := true
		for text: String in lines:
			var width := TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			widths.append(width)
			fits = fits and width <= bounds.size.x
		if fits and TITLE_FONT.get_height(font_size) * lines.size() <= bounds.size.y:
			break
		font_size -= 1
	font_size = maxi(7, font_size)
	return {"lines": lines, "font_size": font_size, "bounds": bounds, "line_widths": widths, "line_height": TITLE_FONT.get_height(font_size)}

func _draw() -> void:
	var lifted := is_hovered() or has_focus()
	var lift := -4.0 if lifted else 0.0
	var material := tint if discovered_pages > 0 else tint.darkened(0.12)
	if _spine != null:
		draw_set_transform(Vector2(3, size.y + lift + 4), -PI / 2.0)
		draw_texture_rect(_spine, Rect2(Vector2.ZERO, Vector2(size.y, size.x)), false, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2(0, size.y + lift), -PI / 2.0)
		draw_texture_rect(_spine, Rect2(Vector2.ZERO, Vector2(size.y, size.x)), false, material)
		draw_set_transform(Vector2.ZERO)
	var layout := title_layout()
	var bounds: Rect2 = layout.bounds
	var lines: PackedStringArray = layout.lines
	var line_height: float = layout.line_height
	var font_size: int = layout.font_size
	var baseline := bounds.position.y + (bounds.size.y - line_height * lines.size()) * 0.5 + TITLE_FONT.get_ascent(font_size) + lift
	var ink := Kit.GOLD_BRIGHT if lifted else Kit.PARCHMENT
	for text: String in lines:
		draw_string(TITLE_FONT, Vector2(bounds.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, font_size, ink)
		baseline += line_height
	# Keep completion counts in the tooltip; short leather bindings carry only words.
	if _marker != null and unread_pages > 0:
		draw_texture_rect(_marker, Rect2(Vector2(size.x - 15, lift), Vector2(8, minf(26, size.y * 0.6))), false, Color(1.0, 0.9, 0.66))
	if _marker != null and research_target:
		draw_texture_rect(_marker, Rect2(Vector2(9, lift), Vector2(8, minf(30, size.y * 0.7))), false)
