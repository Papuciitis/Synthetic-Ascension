extends Node
## Opening reveals opaque, printed paper by cover occlusion, never by a fade.
const OPEN_BOOK := preload("res://ui/widgets/library/LibraryOpenBook.gd")
var _passes := 0
var _failures := 0

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("LibraryOpeningTest: " + message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.save_dir = "user://saves_test_library_opening/"
	SaveManager.current_save = null
	call_deferred(&"_run")

func _run() -> void:
	var book: Control = OPEN_BOOK.new()
	book.size = Vector2(1000, 700)
	add_child(book)
	var pages := Control.new()
	pages.name = "BookPages"
	book.add_child(pages)
	var left := Control.new()
	left.size = book.size
	pages.add_child(left)
	var right := Control.new()
	right.size = book.size
	pages.add_child(right)
	for side: int in [0, 1]:
		var print_label := Label.new()
		print_label.name = "Ink"
		print_label.text = "Printed before opening"
		print_label.position = Vector2(120 if side == 0 else 550, 140)
		print_label.add_theme_font_size_override("font_size", 30)
		print_label.add_theme_color_override("font_color", Color(0.05, 0.2, 0.85))
		(left if side == 0 else right).add_child(print_label)
	await get_tree().process_frame
	_check(book.has_method("capture_opening_pages"), "cover motion captures complete printed leaves before opening or closing")
	_check(book.has_method("opening_paper_rect"), "opening exposes a physical paper region")
	if book.has_method("capture_opening_pages"):
		book.call("capture_opening_pages", left, right)
	for phase: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		book.set("open_progress", phase)
		_check(pages.modulate.a == 1.0, "page ink never dissolves at %.2f" % phase)
		_check(pages.visible == (phase == 1.0), "frozen geometry replaces live print only while hinged at %.2f" % phase)
		if book.has_method("opening_paper_rect"):
			var fixed: Rect2 = book.call("opening_paper_rect", 1, phase)
			var moving: Rect2 = book.call("opening_paper_rect", 0, phase)
			_check(fixed.is_equal_approx(book.call("paper_rect", 1)), "right leaf never shrinks with the cover")
			_check(moving.size.x >= 0.0 and moving.end.x <= 500.0, "left leaf stays on its own side of the gutter")
	if DisplayServer.get_name() != "headless" and book.has_method("capture_opening_pages"):
		book.queue_free()
		await get_tree().process_frame
		await _rendered_opening()
	else:
		book.queue_free()
	await get_tree().process_frame
	print("LibraryOpeningTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _rendered_opening() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 700)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var book: Control = OPEN_BOOK.new()
	book.size = Vector2(viewport.size)
	viewport.add_child(book)
	var pages := Control.new()
	pages.name = "BookPages"
	book.add_child(pages)
	var wrappers: Array[Control] = []
	for side: int in [0, 1]:
		var wrapper := Control.new()
		wrapper.size = book.size
		pages.add_child(wrapper)
		wrappers.append(wrapper)
		var ink := Label.new()
		ink.name = "Ink"
		ink.text = "Printed before opening"
		ink.position = Vector2(120 if side == 0 else 550, 140)
		ink.add_theme_font_size_override("font_size", 30)
		ink.add_theme_color_override("font_color", Color(0.05, 0.2, 0.85))
		wrapper.add_child(ink)
	await get_tree().process_frame
	book.call("capture_opening_pages", wrappers[0], wrappers[1])
	wrappers[1].get_node("Ink").text = "Edited after snapshot"
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var captured: Control = book.get("_opening_right_page")
	_check(captured != null and captured.get_node("Ink").text == "Printed before opening", "opening freezes laid-out print before live changes")
	for phase: float in [0.15, 0.25, 0.5, 0.75, 0.99]:
		book.set("open_progress", phase)
		background.color = Color.MAGENTA
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var first := viewport.get_texture().get_image()
		background.color = Color.GREEN
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var second := viewport.get_texture().get_image()
		var opaque := true
		# The right paper is present even while its cover partly occludes it.
		for point: Vector2i in [Vector2i(600, 350), Vector2i(750, 350), Vector2i(880, 350)]:
			opaque = opaque and first.get_pixelv(point).is_equal_approx(second.get_pixelv(point))
		_check(opaque, "courtyard cannot bleed through the covered or uncovered paper at %.2f" % phase)
		if phase >= 0.5:
			var blue := 0
			for y: int in range(140, 185):
				for x: int in range(550, 880):
					var pixel := second.get_pixel(x, y)
					if pixel.b > 0.5 and pixel.r < 0.2 and pixel.g < 0.35:
						blue += 1
			_check(blue > 40, "already printed right leaf is exposed before the cover finishes opening %.2f" % phase)
	book.set("open_progress", 1.0)
	_check(pages.visible and pages.modulate.a == 1.0, "landing hands back fully opaque live controls")
	book.call("capture_opening_pages", wrappers[0], wrappers[1])
	book.set("open_progress", 0.75)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var closing: Control = book.get("_opening_right_page")
	_check(closing.get_node("Ink").text == "Edited after snapshot", "closing captures the latest live account instead of reusing the old opening print")
	var old_capture: SubViewport = book.get("_opening_right_viewport")
	book.size = Vector2(1200, 840)
	wrappers[1].get_node("Ink").position = Vector2(660, 168)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var resized_capture: SubViewport = book.get("_opening_right_viewport")
	_check(not is_instance_valid(old_capture) and resized_capture.size == Vector2i(498, 706), "resize replaces moving printed leaves at the new paper resolution")
	var resized_print: Control = book.get("_opening_right_page")
	var new_ink: Vector2 = resized_print.get_node("Ink").position + resized_print.position
	_check(new_ink.is_equal_approx(Vector2(54, 100.8)), "resize captures settled print relative to the new gutter and paper edge")
	viewport.queue_free()
