extends Control
## Shaped paper, captured front/back faces, and a rigid cover at the gutter.
const LeafMesh := preload("res://ui/widgets/library/LibraryLeafMesh.gd")
const TITLE_FONT := preload("res://assets/fonts/cinzel/Cinzel-Variable.ttf")
const BOOK_PATH := "res://assets/ui/library/open_book_pixel.png"
const PAPER_PATH := "res://assets/ui/library/right_leaf_pixel.png"
const COVER_PATH := "res://assets/ui/library/closed_book_pixel.png"
signal open_progress_changed(progress: float)
var open_progress: float = 1.0:
	set(value):
		open_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
		_update_open_contents()
		open_progress_changed.emit(open_progress)
		if is_instance_valid(_cover_plane):
			_cover_plane.queue_redraw()
		if is_instance_valid(_opening_plane):
			_opening_plane.queue_redraw()
var cover_title := "":
	set(value):
		cover_title = value
		if is_inside_tree():
			_capture_cover()
var cover_tint := Color.WHITE:
	set(value):
		cover_tint = value
		if is_instance_valid(_cover_plane):
			_cover_plane.queue_redraw()
var turn_progress: float = 1.0:
	set(value):
		turn_progress = clampf(value, 0.0, 1.0)
		if is_instance_valid(_turn_leaf):
			_turn_leaf.progress = turn_progress
		_update_turn_layers()
var turn_direction := 1:
	set(value):
		turn_direction = -1 if value < 0 else 1
		if is_instance_valid(_turn_leaf):
			_turn_leaf.direction = turn_direction
# Transitional property for old callers; print comes only from capture_leaf().
var turn_caption := ""
var _book: Texture2D
var _paper: AtlasTexture
var _cover: AtlasTexture
var _turn_leaf: Control
var _cover_plane: Control
var _opening_plane: Control
var _opening_left_viewport: SubViewport
var _opening_right_viewport: SubViewport
var _opening_left_page: Control
var _opening_right_page: Control
var _opening_left_source: Control
var _opening_right_source: Control
var _held_plane: Control
var _leaf_viewport: SubViewport
var _leaf_back_viewport: SubViewport
var _held_viewport: SubViewport
var _cover_viewport: SubViewport
var _captured_page: Control
var _captured_back_page: Control
var _held_page: Control
var _held_texture: Texture2D
var _held_side := 0
var _cover_texture: Texture2D
var _cover_rendered := false

func _atlas(path: String, region: Rect2) -> AtlasTexture:
	if not ResourceLoader.exists(path):
		return null
	var texture := AtlasTexture.new()
	texture.atlas = load(path) as Texture2D
	texture.region = region
	texture.filter_clip = true
	return texture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_book = load(BOOK_PATH) as Texture2D
	_paper = _atlas(PAPER_PATH, Rect2(75, 34, 983, 1295))
	_cover = _atlas(COVER_PATH, Rect2(90, 83, 958, 1265))
	_turn_leaf = LeafMesh.new()
	_turn_leaf.name = "PageTurnLeaf"
	_turn_leaf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_turn_leaf.z_index = 2
	_turn_leaf.source_texture = _paper
	_turn_leaf.paper_texture = _paper
	_turn_leaf.progress = turn_progress
	_turn_leaf.direction = turn_direction
	add_child(_turn_leaf)
	_cover_plane = Control.new()
	_cover_plane.name = "HingedLeatherCover"
	_cover_plane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover_plane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover_plane.z_index = 3
	_cover_plane.draw.connect(_draw_cover)
	add_child(_cover_plane)
	_held_plane = Control.new()
	_held_plane.name = "HeldFacingPage"
	_held_plane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_plane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_held_plane.z_index = 1
	_held_plane.draw.connect(_draw_held_face)
	add_child(_held_plane)
	_opening_plane = Control.new()
	_opening_plane.name = "HingedPrintedPaper"
	_opening_plane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opening_plane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_opening_plane.z_index = 1
	_opening_plane.draw.connect(_draw_opening_print)
	add_child(_opening_plane)
	resized.connect(_resize_art)
	child_entered_tree.connect(func(_child: Node) -> void: _update_open_contents())
	_update_open_contents()
	_capture_cover()

func _update_open_contents() -> void:
	for child: Node in get_children():
		if child.name == &"BookPages" and child is Control:
			# Frozen, fully printed leaves follow their physical projection while
			# the cover moves. Live controls take over at the identical resting pose.
			child.modulate.a = 1.0
			child.visible = open_progress >= 1.0
		elif child.has_method("set_book_open_progress"):
			child.call("set_book_open_progress", open_progress, size.x)
	if is_instance_valid(_opening_plane):
		_opening_plane.visible = open_progress < 1.0
	if is_instance_valid(_cover_plane):
		# Keep the opened inside cover in this book's draw group, before
		# the static stack, rather than behind unrelated courtyard artwork.
		_cover_plane.z_index = 3 if open_progress < 0.5 else 0
		_cover_plane.show_behind_parent = open_progress >= 0.5
	_update_turn_layers()

func _update_turn_layers() -> void:
	if is_instance_valid(_turn_leaf):
		_turn_leaf.visible = open_progress >= 0.92
	if is_instance_valid(_held_plane):
		_held_plane.visible = _held_texture != null and turn_progress < 1.0 and open_progress >= 0.92
		_held_plane.queue_redraw()

func paper_rect(side: int) -> Rect2:
	var position := Vector2(0.08 if side == 0 else 0.505, 0.08) * size
	return Rect2(position, size * Vector2(0.415, 0.84))

func opening_paper_rect(side: int, at: float = open_progress) -> Rect2:
	if side == 1:
		return paper_rect(1)
	var reach := maxf(0.0, -cos(clampf(at, 0.0, 1.0) * PI))
	return Rect2(size * Vector2(0.5 - 0.42 * reach, 0.08), size * Vector2(0.415 * reach, 0.84))

func capture_opening_pages(left: Control, right: Control) -> void:
	_opening_left_source = left
	_opening_right_source = right
	if is_instance_valid(_opening_left_viewport):
		_opening_left_viewport.queue_free()
	if is_instance_valid(_opening_right_viewport):
		_opening_right_viewport.queue_free()
	_opening_left_viewport = null
	_opening_right_viewport = null
	_opening_left_page = null
	_opening_right_page = null
	if DisplayServer.get_name() == "headless":
		return
	if is_instance_valid(left):
		var capture := _make_leaf_capture(left, 0, "OpeningLeftCapture")
		_opening_left_viewport = capture.viewport as SubViewport
		_opening_left_page = capture.page as Control
	if is_instance_valid(right):
		var capture := _make_leaf_capture(right, 1, "OpeningRightCapture")
		_opening_right_viewport = capture.viewport as SubViewport
		_opening_right_page = capture.page as Control
	if is_instance_valid(_opening_plane):
		_opening_plane.queue_redraw()

func _draw_opening_print() -> void:
	if open_progress >= 1.0:
		return
	if is_instance_valid(_opening_right_viewport):
		_opening_plane.draw_texture_rect(_opening_right_viewport.get_texture(), opening_paper_rect(1), false)
	if is_instance_valid(_opening_left_viewport):
		var left := opening_paper_rect(0)
		if left.size.x > 0.1:
			_opening_plane.draw_texture_rect(_opening_left_viewport.get_texture(), left, false)

func cover_geometry(at: float = open_progress) -> PackedVector2Array:
	var top := size * Vector2(0.5, 0.045)
	var height := size.y * 0.91
	var reach := cos(clampf(at, 0.0, 1.0) * PI) * size.x * 0.45
	return PackedVector2Array([top, top + Vector2(reach, 0), top + Vector2(reach, height), top + Vector2(0, height)])

func cover_texture() -> Texture2D:
	if not _cover_rendered or _cover_texture == null or DisplayServer.get_name() == "headless":
		return _cover
	var image := _cover_texture.get_image()
	if image == null or image.is_empty():
		return _cover
	# A newly allocated transparent render target is not a captured cover yet.
	if image.get_pixel(image.get_width() / 2, image.get_height() / 2).a <= 0.01:
		return _cover
	return ImageTexture.create_from_image(image)

func _mark_cover_rendered() -> void:
	if is_instance_valid(_cover_viewport):
		_cover_rendered = true

func cover_face_texture(at: float = open_progress) -> Texture2D:
	return _cover_texture if at < 0.5 else _cover

func hold_facing_page(page: Control, side: int) -> void:
	if is_instance_valid(_held_viewport):
		_held_viewport.queue_free()
	_held_viewport = null
	_held_page = null
	_held_side = clampi(side, 0, 1)
	_held_texture = _paper
	if page != null and DisplayServer.get_name() != "headless":
		var snapshot := _make_leaf_capture(page, _held_side, "FacingPageCapture")
		_held_viewport = snapshot.viewport as SubViewport
		_held_page = snapshot.page as Control
		_held_texture = _held_viewport.get_texture()
	_update_turn_layers()

func _draw_held_face() -> void:
	if _held_texture == null or turn_progress >= 1.0:
		return
	var rectangle := paper_rect(_held_side)
	if _held_texture == _paper and _held_side == 0:
		_held_plane.draw_set_transform(Vector2(rectangle.end.x, rectangle.position.y), 0.0, Vector2(-1, 1))
		_held_plane.draw_texture_rect(_held_texture, Rect2(Vector2.ZERO, rectangle.size), false)
		_held_plane.draw_set_transform(Vector2.ZERO)
	else:
		_held_plane.draw_texture_rect(_held_texture, rectangle, false)

func capture_leaf(page: Control, direction: int) -> void:
	turn_direction = direction
	if is_instance_valid(_leaf_viewport):
		_leaf_viewport.queue_free()
	if is_instance_valid(_leaf_back_viewport):
		_leaf_back_viewport.queue_free()
	_leaf_viewport = null
	_leaf_back_viewport = null
	_captured_page = null
	_captured_back_page = null
	_turn_leaf.source_texture = _paper
	_turn_leaf.back_texture = null
	if page == null or DisplayServer.get_name() == "headless":
		return
	var snapshot := _make_leaf_capture(page, 0 if turn_direction < 0 else 1, "PrintedLeafCapture")
	_leaf_viewport = snapshot.viewport as SubViewport
	_captured_page = snapshot.page as Control
	_turn_leaf.source_texture = _leaf_viewport.get_texture()

func capture_leaf_back(page: Control) -> void:
	if is_instance_valid(_leaf_back_viewport):
		_leaf_back_viewport.queue_free()
	_leaf_back_viewport = null
	_captured_back_page = null
	_turn_leaf.back_texture = null
	if page == null or DisplayServer.get_name() == "headless":
		return
	var snapshot := _make_leaf_capture(page, 1 if turn_direction < 0 else 0, "PrintedLeafBackCapture")
	_leaf_back_viewport = snapshot.viewport as SubViewport
	_captured_back_page = snapshot.page as Control
	_turn_leaf.back_texture = _leaf_back_viewport.get_texture()

func _make_leaf_capture(page: Control, side: int, capture_name: String) -> Dictionary:
	var rectangle := paper_rect(side)
	var viewport := SubViewport.new()
	viewport.name = capture_name
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.size = Vector2i(maxi(1, ceili(rectangle.size.x)), maxi(1, ceili(rectangle.size.y)))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var paper := TextureRect.new()
	paper.texture = _paper
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.size = rectangle.size
	paper.flip_h = side == 0
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(paper)
	var captured_page := page.duplicate(0) as Control
	captured_page.name = "CapturedPagePrint"
	captured_page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var local_transform := get_global_transform().affine_inverse() * page.get_global_transform()
	captured_page.position = local_transform.origin - rectangle.position
	captured_page.size = page.size
	captured_page.visible = true
	captured_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	captured_page.process_mode = Node.PROCESS_MODE_DISABLED
	_capture_raster_children(captured_page)
	viewport.add_child(captured_page)
	return {"viewport": viewport, "page": captured_page}

func _capture_raster_children(snapshot: Node) -> void:
	for child: Node in snapshot.get_children():
		_capture_raster_children(child)
	if snapshot is Control and snapshot.has_meta("library_capture_texture"):
		var raster := TextureRect.new()
		raster.name = "CapturedRaster"
		raster.texture = snapshot.get_meta("library_capture_texture") as Texture2D
		raster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		raster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		raster.mouse_filter = Control.MOUSE_FILTER_IGNORE
		raster.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		raster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		snapshot.add_child(raster)

func _resize_art() -> void:
	queue_redraw()
	if is_instance_valid(_turn_leaf):
		_turn_leaf.queue_redraw()
	if is_instance_valid(_cover_plane):
		_cover_plane.queue_redraw()
	_capture_cover()
	_update_open_contents()
	# Containers settle after the book's resized signal. Coalesce rapid changes
	# so a moving cover captures the latest laid-out print only once.
	if open_progress < 1.0 and is_instance_valid(_opening_left_source) and is_instance_valid(_opening_right_source):
		if not RenderingServer.frame_pre_draw.is_connected(_recapture_opening):
			RenderingServer.frame_pre_draw.connect(_recapture_opening, CONNECT_ONE_SHOT)

func _recapture_opening() -> void:
	if open_progress < 1.0 and is_instance_valid(_opening_left_source) and is_instance_valid(_opening_right_source):
		capture_opening_pages(_opening_left_source, _opening_right_source)

func _capture_cover() -> void:
	_cover_texture = _cover
	_cover_rendered = false
	if is_instance_valid(_cover_viewport):
		_cover_viewport.queue_free()
	_cover_viewport = null
	if _cover == null or DisplayServer.get_name() == "headless" or size.x <= 0.0:
		return
	_cover_viewport = SubViewport.new()
	_cover_viewport.name = "LeatherCoverPrint"
	_cover_viewport.transparent_bg = true
	_cover_viewport.disable_3d = true
	_cover_viewport.size = Vector2i(maxi(1, ceili(size.x * 0.45)), maxi(1, ceili(size.y * 0.91)))
	_cover_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_cover_viewport)
	var face := TextureRect.new()
	face.texture = _cover
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.size = Vector2(_cover_viewport.size)
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cover_viewport.add_child(face)
	var title := Label.new()
	title.text = cover_title
	title.add_theme_font_override("font", TITLE_FONT)
	var font_size := clampi(roundi(face.size.x * 0.045), 12, 24)
	while TITLE_FONT.get_string_size(cover_title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > face.size.x * 0.43 and font_size > 8:
		font_size -= 1
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", Color(0.24, 0.12, 0.065))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = face.size * Vector2(0.27, 0.155)
	title.size = face.size * Vector2(0.52, 0.09)
	_cover_viewport.add_child(title)
	_cover_texture = _cover_viewport.get_texture()
	# Several title/size updates can replace the viewport before the same draw.
	# One pending callback marks the latest surviving capture after that draw.
	if not RenderingServer.frame_post_draw.is_connected(_mark_cover_rendered):
		RenderingServer.frame_post_draw.connect(_mark_cover_rendered, CONNECT_ONE_SHOT)
	if is_instance_valid(_cover_plane):
		_cover_plane.queue_redraw()

func _draw() -> void:
	if _book == null:
		return
	# The fixed right stack is opaque from the first frame. The left stack
	# follows the hinge; neither paper nor ink dissolves into the courtyard.
	var texture_size := _book.get_size()
	draw_texture_rect_region(_book, Rect2(size * Vector2(0.5, 0), size * Vector2(0.5, 1)), Rect2(texture_size * Vector2(0.5, 0), texture_size * Vector2(0.5, 1)))
	var reach := maxf(0.0, -cos(open_progress * PI))
	if reach > 0.001:
		draw_texture_rect_region(_book, Rect2(size * Vector2(0.5 - 0.5 * reach, 0), size * Vector2(0.5 * reach, 1)), Rect2(Vector2.ZERO, texture_size * Vector2(0.5, 1)))
	if _paper != null:
		var right := paper_rect(1)
		draw_texture_rect(_paper, right, false)
		var left := opening_paper_rect(0)
		if left.size.x > 0.1:
			draw_set_transform(Vector2(left.end.x, left.position.y), 0.0, Vector2(-1, 1))
			draw_texture_rect(_paper, Rect2(Vector2.ZERO, left.size), false)
			draw_set_transform(Vector2.ZERO)

func _draw_cover() -> void:
	var texture := cover_face_texture()
	if texture == null:
		return
	var projection := cover_geometry()
	if absf(projection[1].x - projection[0].x) < 0.1:
		return
	var shade := 1.0 - sin(open_progress * PI) * 0.26
	var material := cover_tint * Color(shade, shade, shade, 1)
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		for index: int in uvs.size():
			uvs[index] = (atlas.region.position + uvs[index] * atlas.region.size) / atlas.atlas.get_size()
		texture = atlas.atlas
	_cover_plane.draw_polygon(projection, PackedColorArray([material]), uvs, texture)
