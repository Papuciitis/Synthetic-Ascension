extends Node2D
## Native GPU probe of the actual production footway material and geometry.
## A near-single-pixel alpha ramp is the reported hard rectangular apron bug.

const FIXTURE := preload("res://tools/tests/CitySceneDepthFixture.gd")
const FRONTAGE := preload("res://scenes/world/buildings/CityStreetFrontage.gd")
var _passes := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok: _passes += 1
	else:
		_failures += 1
		push_error(label)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CityFootwayEdgeRenderTest requires the native renderer; headless cannot prove its alpha transition")
		get_tree().quit(2)
		return
	var old_segment := Global.attempt_segment
	Global.attempt_segment = 2
	await _test_native_footway()
	Global.attempt_segment = old_segment
	print("CityFootwayEdgeRenderTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_native_footway() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1024,384)
	view.transparent_bg = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	view.canvas_transform = Transform2D(0,Vector2(0,-960))
	var chunk := Node2D.new()
	view.add_child(chunk)
	var fixture := FIXTURE.create(chunk)
	var placed: Array[Rect2i] = [FIXTURE.BED_RECT]
	FRONTAGE.compose(chunk,placed,64,32)
	var group := chunk.get_node_or_null("ConnectedStreetFrontages")
	_check(group != null and group.get_child_count() > 0,"native probe renders the production ParcelFootway overlay")
	for child: Node in chunk.get_children():
		if child != group and child is CanvasItem: (child as CanvasItem).hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	_check(pixels != null and pixels.get_width() == 1024,"native viewport provides actual footway RGBA pixels")
	if pixels != null:
		var row := 190 # chunk-local y1150, comfortably inside the south footway.
		var partial_left := 0
		var partial_right := 0
		for x in range(104,480):
			var alpha := pixels.get_pixel(x,row).a
			if alpha > 0.05 and alpha < 0.95: partial_left += 1
		for x in range(608,976):
			var alpha := pixels.get_pixel(x,row).a
			if alpha > 0.05 and alpha < 0.95: partial_right += 1
		_check(pixels.get_pixel(544,row).a > 0.98,"real bed door approach keeps a fully opaque core")
		_check(pixels.get_pixel(104,row).a < 0.01,"footway transition returns completely to underlying ground outside the frontage")
		_check(pixels.get_pixel(240,row).a < 0.01 and pixels.get_pixel(848,row).a < 0.01,"old house-wide pad corners reveal actual underlying ground")
		_check(partial_left >= 6 and partial_left <= 48,"actual left pavement edge has a bounded ground transition, partial pixels=%d" % partial_left)
		_check(partial_right >= 6 and partial_right <= 48,"actual right pavement edge has a bounded ground transition, partial pixels=%d" % partial_right)
		print("CityFootwayEdgeRenderTest edge samples: left=%d right=%d core_alpha=%.3f" % [partial_left,partial_right,pixels.get_pixel(544,row).a])
	_check((fixture.roof as RoofOverlay).footprint_outline_px == PackedVector2Array(FIXTURE.BED_OUTLINE),"native edge rendering leaves physical footprint source intact")
	# The real road already draws beneath the approach. A local pale apron
	# must blend into it instead of stamping another rectangular patch on top.
	group.free()
	FRONTAGE.compose(chunk,placed,64,32,Rect2i(0,18,32,2))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var joined := view.get_texture().get_image()
	_check(joined.get_pixel(544,160).a > 0.98,"actual approach stays solid before entering the paved lane")
	_check(joined.get_pixel(544,216).a < 0.35,"approach yields to the existing road within its join instead of adding a pale pad")
	# The shared base used to repaint the entire merged parcel hull underneath
	# this overlay. Test the actual base owner too: shaping only the overlay
	# cannot remove that older rectangular pavement.
	chunk.get_node("ConnectedStreetFrontages").hide()
	FIXTURE.KIT.compose_street(chunk,placed,Rect2i(0,20,32,2),Rect2i(),64,32)
	var kit: Node2D = fixture.kit
	kit.show()
	for child: Node in kit.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child.has_meta(&"city_paving")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var base := view.get_texture().get_image()
	_check(base.get_pixel(300,190).a < 0.01,"shared base reveals the ground away from the actual lane instead of repainting the parcel hull")
	_check(base.get_pixel(300,350).a > 0.98,"shared base preserves the actual paved road")
	var shoulder_pixels := 0
	for y: int in range(220,350):
		var alpha := base.get_pixel(300,y).a
		if alpha > 0.05 and alpha < 0.95: shoulder_pixels += 1
	_check(shoulder_pixels >= 12 and shoulder_pixels <= 70,"shared road shoulder has a bounded natural transition, partial pixels=%d" % shoulder_pixels)
	base = null
	joined = null
	pixels = null
	fixture.clear()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
