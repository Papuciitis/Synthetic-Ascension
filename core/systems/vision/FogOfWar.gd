extends Node2D

# Indoor-only fog-of-war overlay.
# Outdoors is always clear; we only draw fog where IndoorVolume areas exist.
# The VisionRig triggers queue_redraw() when its masks change.

@export var margin_cells: int = 6
@export var linear_filter: bool = true

var _spr: Sprite2D
var _tex: ImageTexture
var _img: Image
var _buf: PackedByteArray
var _w: int = 0
var _h: int = 0


func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.centered = false
	# Use a dark-gray base so "unseen" looks like your PNG (not pure black).
	_spr.modulate = Color(0.12, 0.12, 0.12, 1.0)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if linear_filter else CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)


func _ensure_buffers(w: int, h: int) -> void:
	if w == _w and h == _h and _img != null and _buf.size() == w * h * 4:
		return
	_w = w
	_h = h
	_buf = PackedByteArray()
	_buf.resize(w * h * 4)
	_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_tex = null


func _draw() -> void:
	# In the scene, FogOfWar lives under VisionRig/FogLayer/FogOfWar.
	var rig = get_node_or_null("../..")
	if rig == null:
		return
	if not rig.has_method("get_camera"):
		return

	var cam: Camera2D = rig.get_camera()
	if cam == null or not is_instance_valid(cam):
		return

	var cell: float = float(rig.cell_size_px)
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom: Vector2 = cam.zoom
	if zoom.x == 0.0:
		zoom.x = 1.0
	if zoom.y == 0.0:
		zoom.y = 1.0

	# Camera view rect in world coordinates.
	var half: Vector2 = (vp_size * 0.5) * Vector2(1.0 / zoom.x, 1.0 / zoom.y)
	var tl: Vector2 = cam.global_position - half
	var br: Vector2 = cam.global_position + half

	# Convert to cell bounds, with a margin.
	var x0: int = floori(tl.x / cell) - margin_cells
	var y0: int = floori(tl.y / cell) - margin_cells
	var x1: int = floori(br.x / cell) + margin_cells
	var y1: int = floori(br.y / cell) + margin_cells

	var w: int = (x1 - x0) + 1
	var h: int = (y1 - y0) + 1
	if w <= 0 or h <= 0:
		return

	# Pull cached masks from VisionRig.
	var indoor_bounds: Rect2i = rig.indoor_bounds
	var indoor_mask: PackedByteArray = rig.indoor_mask
	var vis_bounds: Rect2i = rig.visible_bounds
	var vis_mask: PackedByteArray = rig.visible_mask

	# If no indoor cells are in view, draw nothing.
	if indoor_mask.is_empty():
		_spr.texture = null
		return

	# If bounds don't match, rebuild a quick indoor mask from cached indoor rects.
	# This is rare, but avoids wrong alignment when editor changes happen.
	var use_cached_indoor := (indoor_bounds == Rect2i(Vector2i(x0, y0), Vector2i(w, h)) and indoor_mask.size() == w * h)
	if not use_cached_indoor:
		if rig.has_method("get_indoor_rects_cells"):
			indoor_mask = _build_indoor_mask_from_rects(rig.get_indoor_rects_cells(), x0, y0, w, h)
		else:
			# Worst case: just don't draw.
			_spr.texture = null
			return

	# Fast exit if there are actually no indoor pixels in this exact viewport.
	var any_indoor := false
	for b in indoor_mask:
		if int(b) != 0:
			any_indoor = true
			break
	if not any_indoor:
		_spr.texture = null
		return

	_ensure_buffers(w, h)

	var a_seen: float = rig.alpha_seen
	var a_unseen: float = rig.alpha_unseen

	var has_vis := (vis_mask.size() > 0 and vis_bounds.size.x > 0 and vis_bounds.size.y > 0)
	var vis_w := vis_bounds.size.x
	var vis_h := vis_bounds.size.y
	var vis_x0 := vis_bounds.position.x
	var vis_y0 := vis_bounds.position.y

	# Fill RGBA buffer: (0,0,0,alpha)
	var out_i := 0
	for py in range(h):
		var cell_y := y0 + py
		for px in range(w):
			var cell_x := x0 + px
			var idx := py * w + px

			var a := 0.0
			if indoor_mask[idx] != 0:
				var is_vis := false
				if has_vis and cell_x >= vis_x0 and cell_y >= vis_y0 and cell_x < (vis_x0 + vis_w) and cell_y < (vis_y0 + vis_h):
					var vidx := (cell_y - vis_y0) * vis_w + (cell_x - vis_x0)
					is_vis = (vis_mask[vidx] != 0)
				if not is_vis:
					# IMPORTANT: VisionRig.is_cell_seen expects (x,y) and internally uses Vector2i.
					a = a_seen if rig.is_cell_seen(cell_x, cell_y) else a_unseen

			_buf[out_i] = 0
			_buf[out_i + 1] = 0
			_buf[out_i + 2] = 0
			_buf[out_i + 3] = int(clampf(a, 0.0, 1.0) * 255.0)
			out_i += 4

	_img.set_data(w, h, false, Image.FORMAT_RGBA8, _buf)
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
	else:
		_tex.update(_img)

	_spr.texture = _tex
	_spr.position = Vector2(float(x0) * cell, float(y0) * cell)
	_spr.scale = Vector2(cell, cell)


func _build_indoor_mask_from_rects(rects: Array, x0: int, y0: int, w: int, h: int) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(w * h)
	var bounds := Rect2i(Vector2i(x0, y0), Vector2i(w, h))
	for r_any in rects:
		var r: Rect2i = r_any
		var ir := r.intersection(bounds)
		if ir.size.x <= 0 or ir.size.y <= 0:
			continue
		var sx := ir.position.x - x0
		var sy := ir.position.y - y0
		for yy in range(ir.size.y):
			var row := (sy + yy) * w
			for xx in range(ir.size.x):
				buf[row + sx + xx] = 1
	return buf
