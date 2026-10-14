extends Node
## Catches flat rectangular turns, wrong-direction UVs, closing squash, lost alpha,
## and titles that spill off their leather bindings.
const OPEN_BOOK := preload("res://ui/widgets/library/LibraryOpenBook.gd")
const LEAF_MESH := preload("res://ui/widgets/library/LibraryLeafMesh.gd")
const BOOK := preload("res://ui/widgets/library/LibraryBook.gd")
const RIBBON := preload("res://ui/widgets/library/LibraryRibbon.gd")
const SEAL := preload("res://ui/widgets/library/LibrarySeal.gd")
var _passes := 0
var _failures := 0
var _motion_out := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--art-motion-out="):
			_motion_out = argument.trim_prefix("--art-motion-out=")
			DirAccess.make_dir_recursive_absolute(_motion_out)
	call_deferred(&"_run")

func _save_frame(image: Image, name: String) -> void:
	if not _motion_out.is_empty():
		image.save_png(_motion_out.path_join(name))

func _blue_ink(image: Image, rectangle: Rect2i) -> int:
	var count := 0
	for y: int in range(rectangle.position.y, rectangle.end.y):
		for x: int in range(rectangle.position.x, rectangle.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.9 and pixel.b > 0.5 and pixel.r < 0.2:
				count += 1
	return count

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("LibraryPhysicalArtTest: " + message)

func _has_property(node: Object, key: String) -> bool:
	for property: Dictionary in node.get_property_list():
		if String(property.name) == key:
			return true
	return false

func _run() -> void:
	SaveManager.save_dir = "user://saves_test_library_art/"
	SaveManager.current_save = null
	var open: Control = OPEN_BOOK.new()
	open.size = Vector2(1000, 700)
	add_child(open)
	await get_tree().process_frame
	_check(open.has_method("paper_rect"), "paper placement follows the shaped leaf")
	_check(open.has_method("capture_leaf"), "turn captures the printed page before content changes")
	_check(open.has_method("capture_leaf_back"), "the incoming printed page has its own opaque paper back face")
	_check(open.has_method("hold_facing_page"), "the old stationary facing page survives incoming spread mutation")
	_check(_has_property(open, "open_progress"), "cover opens about its hinge independently of Control scale")
	_check(_has_property(open, "turn_direction"), "backward page turns have a mirrored direction")
	_check(open.has_method("cover_geometry"), "cover provides rigid hinge projection")
	if _has_property(open, "open_progress"):
		var pages := Control.new()
		pages.name = "BookPages"
		open.add_child(pages)
		open.set("open_progress", 0.0)
		_check(pages.modulate.a == 0.0, "closed cover conceals ordinary page print")
		open.set("open_progress", 0.5)
		_check(pages.modulate.a == 0.0, "paper print stays concealed until the cover is mostly open")
		open.set("open_progress", 1.0)
		_check(pages.modulate.a == 1.0 and open.scale.is_equal_approx(Vector2.ONE), "open book reveals its print without changing its geometry")
	if open.has_method("paper_rect"):
		var left: Rect2 = open.call("paper_rect", 0)
		var right: Rect2 = open.call("paper_rect", 1)
		_check(left.is_equal_approx(Rect2(80, 56, 415, 588)), "left reading region remains inside leather and gutter")
		_check(right.is_equal_approx(Rect2(505, 56, 415, 588)), "right reading region remains inside leather and gutter")
	if open.has_method("cover_geometry"):
		var closed: PackedVector2Array = open.call("cover_geometry", 0.0)
		var opened: PackedVector2Array = open.call("cover_geometry", 1.0)
		var half: PackedVector2Array = open.call("cover_geometry", 0.5)
		_check(closed.size() == 4 and opened.size() == 4, "cover is a rigid textured plane")
		if closed.size() == 4 and opened.size() == 4:
			_check(closed[0].is_equal_approx(opened[0]) and closed[3].is_equal_approx(opened[3]), "cover's gutter edge stays fixed through opening")
			_check(closed[1].x > 500 and opened[1].x < 500, "cover swings from right closed face to left open face")
			_check(absf(half[1].x - 500.0) < 1.0, "cover becomes edge-on midway without shrinking its parent")
		_check(open.scale.is_equal_approx(Vector2.ONE), "opening preserves parent geometry")
	var cover_plane: Control = open.get("_cover_plane")
	for phase: float in [0.25, 0.5, 0.75, 0.99, 1.0, 0.99, 0.75, 0.5, 0.25]:
		open.set("open_progress", phase)
		_check(cover_plane.z_index > 0 if phase < 0.5 else cover_plane.z_index <= 0 and cover_plane.show_behind_parent, "opening and closing put the inside cover behind paper at %.2f" % phase)
	open.set("open_progress", 1.0)
	var leaf: Node = open.find_child("PageTurnLeaf", true, false)
	_check(leaf != null and leaf.has_method("mesh_geometry"), "turn uses a subdivided paper mesh")
	if leaf != null and leaf.has_method("mesh_geometry"):
		leaf.set("size", Vector2(1000, 700))
		var forward: Dictionary = leaf.call("mesh_geometry", 0.25, 1)
		var backward: Dictionary = leaf.call("mesh_geometry", 0.25, -1)
		var vertices: PackedVector2Array = forward.get("vertices", PackedVector2Array())
		var reverse: PackedVector2Array = backward.get("vertices", PackedVector2Array())
		var uvs: PackedVector2Array = forward.get("uvs", PackedVector2Array())
		var reverse_uvs: PackedVector2Array = backward.get("uvs", PackedVector2Array())
		var forward_back: Dictionary = leaf.call("mesh_geometry", 0.75, 1)
		var backward_back: Dictionary = leaf.call("mesh_geometry", 0.75, -1)
		var forward_back_uv: PackedVector2Array = forward_back.uvs
		var backward_back_uv: PackedVector2Array = backward_back.uvs
		_check(forward_back_uv[0].x == 1.0 and forward_back_uv[16].x == 0.0, "forward back print reads normally when it lands on the left paper")
		_check(backward_back_uv[0].x == 0.0 and backward_back_uv[16].x == 1.0, "backward back print reads normally when it lands on the right paper")
		for toward: int in [1, -1]:
			for phase: float in [0.0, 0.18, 0.35, 0.49, 0.5, 0.51, 0.65, 0.82, 0.99, 1.0]:
				var sample: Dictionary = leaf.call("mesh_geometry", phase, toward)
				var sample_points: PackedVector2Array = sample.vertices
				var sample_uv: PackedVector2Array = sample.uvs
				var readable := true
				for column: int in range(16):
					var dx := sample_points[column + 1].x - sample_points[column].x
					var du := sample_uv[column + 1].x - sample_uv[column].x
					readable = readable and dx * du >= -0.001
				_check(readable, "every projected strip agrees with its printed face (%d, %.2f)" % [toward, phase])
				if phase == 0.5:
					var edge_on := true
					for point: Vector2 in sample_points:
						edge_on = edge_on and absf(point.x - 500.0) < 0.1
					_check(edge_on, "midpoint cannot display reversed front-face strips")
		var resting_forward: Dictionary = leaf.call("mesh_geometry", 0.0, 1)
		var resting_backward: Dictionary = leaf.call("mesh_geometry", 0.0, -1)
		var forward_start: PackedVector2Array = resting_forward.vertices
		var backward_start: PackedVector2Array = resting_backward.vertices
		_check(forward_start[0].x == 505.0 and forward_start[16].x == 920.0, "forward capture begins exactly at its static right paper edges")
		_check(backward_start[0].x == 495.0 and backward_start[16].x == 80.0, "backward capture begins exactly at its static left paper edges")
		_check(vertices.size() > 12 and forward.get("indices", PackedInt32Array()).size() > 6, "paper has enough subdivisions for an actual curve")
		if vertices.size() > 4 and reverse.size() == vertices.size():
			var mirrored := true
			for index: int in vertices.size():
				mirrored = mirrored and is_equal_approx(vertices[index].x + reverse[index].x, 1000.0)
			_check(mirrored, "backward paper projection mirrors about the gutter")
			_check(not is_equal_approx(vertices[1].x - vertices[0].x, vertices[2].x - vertices[1].x), "curl varies across the sheet instead of X-squashing a rectangle")
		if uvs.size() > 0 and reverse_uvs.size() == uvs.size():
			_check(uvs[0].x == 0.0 and reverse_uvs[0].x == 1.0, "backward capture keeps print readable on its starting left page")
		var paper: Texture2D = leaf.get("source_texture")
		_check(leaf.has_method("face_texture"), "the drawing consumer switches to the incoming face after edge-on")
		if leaf.has_method("face_texture"):
			var back: Texture2D = load("res://assets/ui/library/wax_seal_pixel.png") as Texture2D
			leaf.set("back_texture", back)
			_check(leaf.call("face_texture", 0.25) == paper and leaf.call("face_texture", 0.5) == paper, "source print stays on the first half of the physical turn")
			_check(leaf.call("face_texture", 0.75) == back, "the old source print cannot appear on the incoming back")
			leaf.set("back_texture", null)
			leaf.set("source_texture", back)
			_check(leaf.call("face_texture", 0.75) == paper, "a missing incoming face shows blank paper instead of mirrored departing print")
			leaf.set("source_texture", paper)
		_check(paper is AtlasTexture, "turn source is the actual generated paper silhouette")
		if paper is AtlasTexture:
			var alpha: float = paper.atlas.get_image().get_pixel(100, 50).a
			var center: float = paper.atlas.get_image().get_pixel(550, 650).a
			_check(alpha < 0.05 and center > 0.95, "paper texture preserves transparent stepped corners and opaque reading surface")
	if DisplayServer.get_name() != "headless" and open.has_method("capture_leaf"):
		open.set("open_progress", 0.5)
		await RenderingServer.frame_post_draw
		open.set("open_progress", 1.0)
		var page := VBoxContainer.new()
		page.name = "AccountPage"
		page.position = Vector2(550, 100)
		page.size = Vector2(320, 300)
		open.get_node("BookPages").add_child(page)
		var print_label := Label.new()
		print_label.name = "FrozenText"
		print_label.text = "Remembered"
		print_label.add_theme_font_size_override("font_size", 28)
		print_label.add_theme_color_override("font_color", Color(0.18, 0.08, 0.035))
		page.add_child(print_label)
		var seal_print: Control = SEAL.new()
		seal_print.name = "PrintedSeal"
		seal_print.custom_minimum_size = Vector2(48, 48)
		page.add_child(seal_print)
		await get_tree().process_frame
		open.call("capture_leaf", page, 1)
		print_label.text = "Changed after capture"
		var frozen: Control = open.get("_captured_page")
		_check(frozen != null and frozen.get_node("FrozenText").text == "Remembered", "turn freezes the old print before the reader edits its page")
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var captured: SubViewport = open.get("_leaf_viewport")
		var image := captured.get_texture().get_image()
		_check(image.get_pixel(0, 0).a < 0.05 and image.get_pixel(200, 200).a > 0.95, "rendered page capture retains paper alpha instead of a rectangular overlay")
		var ink_pixels := 0
		for y: int in range(44, 95):
			for x: int in range(45, 240):
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.9 and pixel.r < 0.3 and pixel.g < 0.2:
					ink_pixels += 1
		_check(ink_pixels > 40, "the same RGBA capture contains rendered readable print")
		var seal_center := seal_print.get_global_rect().get_center() - open.global_position - Vector2(505, 56)
		var seal_pixel := image.get_pixelv(Vector2i(seal_center))
		_check(seal_pixel.a > 0.95 and seal_pixel.b < 0.35, "capture preserves the illustrated seal when duplicate strips its draw script")
		if open.has_method("capture_leaf_back"):
			var incoming := VBoxContainer.new()
			incoming.position = Vector2(120, 100)
			incoming.size = Vector2(320, 300)
			open.get_node("BookPages").add_child(incoming)
			var incoming_print := Label.new()
			incoming_print.name = "IncomingText"
			incoming_print.text = "Incoming left"
			incoming_print.add_theme_font_size_override("font_size", 28)
			incoming_print.add_theme_color_override("font_color", Color(0.05, 0.2, 0.85))
			incoming.add_child(incoming_print)
			await get_tree().process_frame
			open.call("capture_leaf_back", incoming)
			incoming_print.text = "Edited after capture"
			var frozen_back: Control = open.get("_captured_back_page")
			_check(frozen_back != null and frozen_back.get_node("IncomingText").text == "Incoming left", "incoming back print is frozen independently from the old front")
			_check(frozen_back.position.is_equal_approx(Vector2(40, 44)), "forward incoming capture is offset from the destination left paper")
			_check(frozen.get_node("FrozenText").text == "Remembered", "capturing the back preserves the original front snapshot")
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var back_viewport: SubViewport = open.get("_leaf_back_viewport")
			var back_image := back_viewport.get_texture().get_image()
			_check(back_image.get_pixel(0, 0).a < 0.05 and back_image.get_pixel(200, 200).a > 0.95, "incoming back keeps the real transparent paper silhouette")
			var projection := SubViewport.new()
			projection.transparent_bg = true
			projection.disable_3d = true
			projection.size = Vector2i(1000, 700)
			projection.render_target_update_mode = SubViewport.UPDATE_ONCE
			add_child(projection)
			var curved: Control = LEAF_MESH.new()
			curved.size = Vector2(1000, 700)
			curved.set("source_texture", captured.get_texture())
			curved.set("back_texture", back_viewport.get_texture())
			curved.set("progress", 0.75)
			projection.add_child(curved)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var projected_image := projection.get_texture().get_image()
			var blue_pixels := 0
			for y: int in range(50, 180):
				for x: int in range(75, 495):
					var pixel := projected_image.get_pixel(x, y)
					if pixel.a > 0.9 and pixel.b > 0.5 and pixel.r < 0.2:
						blue_pixels += 1
			_check(blue_pixels > 40, "rendered second-half mesh displays incoming blue print instead of reversed old brown print")
			projection.queue_free()
			open.call("capture_leaf", incoming, -1)
			print_label.text = "Incoming right"
			open.call("capture_leaf_back", page)
			var reverse_back: Control = open.get("_captured_back_page")
			_check(reverse_back.position.is_equal_approx(Vector2(45, 44)), "backward incoming capture is offset from the destination right paper")
			_check(reverse_back.get_node("FrozenText").text == "Incoming right", "backward turn captures the new right face rather than the old left face")
		await _motion_regressions()
	var spine: Button = BOOK.new()
	add_child(spine)
	for title: String in ["Buildcraft", "Manifestations", "Pairs", "Enemies", "Items", "Augments", "Sets", "Recipes", "Chronicles"]:
		spine.size = Vector2(180, 44)
		spine.set("book_title", title)
		_check(spine.has_method("title_layout"), "spine title layout can be fitted for " + title)
		if spine.has_method("title_layout"):
			var layout: Dictionary = spine.call("title_layout")
			var inset: Rect2 = layout.get("bounds", Rect2())
			var widths: PackedFloat32Array = layout.get("line_widths", PackedFloat32Array())
			var fits := widths.size() > 0 and inset.position.x > 0 and inset.end.x < 180
			for width: float in widths:
				fits = fits and width <= inset.size.x + 0.01
			_check(fits, title + " lettering stays within measured binding inset")
			_check("".join(layout.get("lines", PackedStringArray())) == title.replace(" ", ""), "spine preserves complete category words")
	var ribbon: Button = RIBBON.new()
	add_child(ribbon)
	_check(_has_property(ribbon, "label") and _has_property(ribbon, "active"), "cloth markers expose purpose labels and active state")
	_check(ribbon.get("_cloth") is AtlasTexture, "bookmark button draws the generated rooted cloth texture")
	await _ribbon_pull_regressions(ribbon)
	var seal: Control = SEAL.new()
	add_child(seal)
	_check(seal.get("_seal") is AtlasTexture, "wax uses the irregular illustrated diamond seal")
	open.queue_free()
	spine.queue_free()
	ribbon.queue_free()
	seal.queue_free()
	await get_tree().process_frame
	print("LibraryPhysicalArtTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _motion_regressions() -> void:
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.size = Vector2i(1000, 700)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var book: Control = OPEN_BOOK.new()
	book.size = Vector2(1000, 700)
	book.set("cover_title", "Visible cover title")
	viewport.add_child(book)
	_check(book.call("cover_texture") == book.get("_cover"), "an unrendered cover safely falls back to its atlas before pickup")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var covered_pixel: Color
	for phase: float in [0.25, 0.5, 0.75, 0.99, 1.0, 0.99, 0.75, 0.5, 0.25]:
		book.set("open_progress", phase)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		_save_frame(image, "cover_%02d.png" % roundi(phase * 100))
		if phase >= 0.75:
			_check(image.get_pixel(300, 350).g > 0.45, "inside cover leaves left paper visible during opening and closing %.2f" % phase)
		if phase == 0.99:
			covered_pixel = image.get_pixel(300, 350)
		if phase == 1.0:
			_check(covered_pixel.is_equal_approx(image.get_pixel(300, 350)), "resting cover has no final-frame disappearance")
	book.set("open_progress", 1.0)
	if book.has_method("hold_facing_page"):
		var wrapper := Control.new()
		wrapper.name = "FullPaperWrapper"
		wrapper.size = book.size
		book.add_child(wrapper)
		var stationary := Label.new()
		stationary.name = "StationaryPrint"
		stationary.position = Vector2(120, 150)
		stationary.size = Vector2(310, 100)
		stationary.text = "Old facing account"
		stationary.add_theme_font_size_override("font_size", 32)
		stationary.add_theme_color_override("font_color", Color(0.05, 0.2, 0.85))
		wrapper.add_child(stationary)
		var footer := Label.new()
		footer.name = "FacingFolio"
		footer.position = Vector2(330, 600)
		footer.text = "Old folio"
		wrapper.add_child(footer)
		var departing := Label.new()
		departing.name = "DepartingPrint"
		departing.position = Vector2(550, 150)
		departing.size = Vector2(310, 100)
		departing.text = "Old departing page"
		departing.add_theme_font_size_override("font_size", 32)
		departing.add_theme_color_override("font_color", Color(0.20, 0.11, 0.04))
		wrapper.add_child(departing)
		await get_tree().process_frame
		book.call("hold_facing_page", wrapper, 0)
		book.call("capture_leaf", wrapper, 1)
		stationary.text = "Incoming facing account"
		stationary.add_theme_color_override("font_color", Color(0.85, 0.1, 0.05))
		footer.text = "New folio"
		departing.text = "Incoming departing page"
		book.call("capture_leaf_back", wrapper)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var held: Control = book.get("_held_page")
		_check(held.get_node("StationaryPrint").text == "Old facing account" and held.get_node("FacingFolio").text == "Old folio", "held full-page snapshot preserves old account and folio after incoming mutation")
		for phase: float in [0.0, 0.25, 0.35, 0.5, 0.75, 0.99, 1.0]:
			book.set("turn_progress", phase)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			_save_frame(image, "forward_%02d.png" % roundi(phase * 100))
			if phase <= 0.5:
				_check(_blue_ink(image, Rect2i(120, 140, 310, 100)) > 40, "old facing print remains visible until the incoming leaf covers it %.2f" % phase)
			if phase >= 0.99:
				_check(_blue_ink(image, Rect2i(120, 140, 310, 100)) < 5, "departed facing print is gone when the incoming sheet lands %.2f" % phase)
		var hold_plane: Control = book.get("_held_plane")
		_check(not hold_plane.visible, "hold disappears only after the turn finishes")
		stationary.text = "Backward departing page"
		departing.text = "Old right facing page"
		departing.add_theme_color_override("font_color", Color(0.05, 0.2, 0.85))
		book.call("hold_facing_page", wrapper, 1)
		book.call("capture_leaf", wrapper, -1)
		departing.text = "Incoming right facing"
		departing.add_theme_color_override("font_color", Color(0.85, 0.1, 0.05))
		book.call("capture_leaf_back", wrapper)
		book.set("turn_progress", 0.25)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var reverse_image := viewport.get_texture().get_image()
		_save_frame(reverse_image, "backward_25.png")
		_check(_blue_ink(reverse_image, Rect2i(550, 140, 310, 100)) > 40, "backward turn holds old right facing print above incoming content")
		book.set("turn_progress", 1.0)
		_check(not hold_plane.visible, "backward completion releases the held right face")
	var transfer: Texture2D = book.call("cover_texture")
	_check(transfer is ImageTexture, "a moving volume owns a frozen rendered cover rather than a live viewport")
	var old_cover: SubViewport = book.get("_cover_viewport")
	var original_pixels := transfer.get_image().get_data()
	book.set("cover_title", "Replacement volume")
	book.size = Vector2(1100, 770)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_check(not is_instance_valid(old_cover), "cover recapture releases the prior viewport during title and size changes")
	var surviving_image: Image = transfer.get_image()
	_check(surviving_image != null and not surviving_image.is_empty() and surviving_image.get_data() == original_pixels, "transfer texture survives prior viewport deletion without changing its old title or pixels")
	viewport.queue_free()

func _ribbon_input(ribbon: Button, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = ribbon.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	get_viewport().push_input(event, true)
	await get_tree().process_frame

func _ribbon_pull_regressions(ribbon: Button) -> void:
	_check(ribbon.has_method("tail_geometry"), "cloth tail has independent pull geometry and print placement")
	if not ribbon.has_method("tail_geometry"):
		return
	var original_reduced := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	var original_pause := get_tree().paused
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	ribbon.position = Vector2(700, 10)
	ribbon.size = Vector2(110, 100)
	ribbon.set("label", "First")
	ribbon.set("root_rect", Rect2(0, -130, 110, 28))
	ribbon.set("active", true)
	ribbon.release_focus()
	var available: Dictionary = ribbon.call("tail_geometry")
	_check(available.tail.position.y == 0.0, "availability changes cloth color without permanently lifting its tail")
	ribbon.grab_focus()
	await get_tree().process_frame
	var resting: Dictionary = ribbon.call("tail_geometry")
	var origin := ribbon.global_position
	get_tree().paused = true
	await _ribbon_input(ribbon, true)
	await get_tree().create_timer(0.14, true).timeout
	var pulled: Dictionary = ribbon.call("tail_geometry")
	_check(pulled.root == resting.root and ribbon.global_position == origin, "press keeps the sewn root and entire button fixed")
	_check(pulled.tail.size.y > resting.tail.size.y + 3.0 and pulled.baseline > resting.baseline + 3.0, "press pulls actual cloth pixels and their printed label while reading pauses the world")
	await _ribbon_input(ribbon, false)
	await get_tree().create_timer(0.25, true).timeout
	var released: Dictionary = ribbon.call("tail_geometry")
	_check(released.tail.is_equal_approx(resting.tail) and is_equal_approx(released.baseline, resting.baseline), "released cloth and print return to their resting position")
	ribbon.disabled = true
	await _ribbon_input(ribbon, true)
	await get_tree().create_timer(0.14, true).timeout
	var disabled: Dictionary = ribbon.call("tail_geometry")
	_check(disabled.tail.size.y == ribbon.size.y, "disabled ribbons cannot be pulled")
	await _ribbon_input(ribbon, false)
	ribbon.disabled = false
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	await _ribbon_input(ribbon, true)
	await get_tree().create_timer(0.14, true).timeout
	var reduced: Dictionary = ribbon.call("tail_geometry")
	_check(reduced.tail.size.y == ribbon.size.y and reduced.tail.position.y == 0.0, "Reduced Motion retains cloth feedback without animated pull or focus lift")
	await _ribbon_input(ribbon, false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", original_reduced, false)
	get_tree().paused = original_pause
