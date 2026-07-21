extends Object
# Auto-extracted from ChunkGenImpl.gd to keep the generator modular.
# Do not keep state here; use the passed `gen` (ChunkGenImpl) as context.

static func _stamp_floor_rect_cells(gen: ChunkGenImpl, chunk: Node2D, rect: Rect2i, tex_index: int, rng: RandomNumberGenerator, alpha: float, z: int) -> void:
	if not gen.ground_enabled:
		return
	if tex_index < 0 or tex_index >= WorldArt.GROUND_TEX.size():
		return
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var spr := Sprite2D.new()
	spr.name = "FloorStamp"
	spr.z_index = z
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.texture = WorldArt.GROUND_TEX[tex_index]

	spr.region_enabled = true
	var ox: float = float(rng.randi_range(0, WorldArt.TEX_TILE_PX - 1))
	var oy: float = float(rng.randi_range(0, WorldArt.TEX_TILE_PX - 1))
	spr.region_rect = Rect2(ox, oy, float(WorldArt.TEX_TILE_PX * rect.size.x), float(WorldArt.TEX_TILE_PX * rect.size.y))

	var s: float = float(gen.cell_size_px) / float(WorldArt.TEX_TILE_PX)
	spr.scale = Vector2(s, s)
	spr.modulate = Color(1, 1, 1, alpha)

	var cx: float = (float(rect.position.x) + float(rect.size.x) * 0.5) * float(gen.cell_size_px)
	var cy: float = (float(rect.position.y) + float(rect.size.y) * 0.5) * float(gen.cell_size_px)
	spr.position = Vector2(cx, cy)

	chunk.add_child(spr)


static func _stamp_floor_rect_cells_patchy(gen: ChunkGenImpl, chunk: Node2D, rect: Rect2i, tex_index: int, rng: RandomNumberGenerator, alpha: float, z: int) -> void:
	# Break large uniform rectangles into a handful of smaller stamps to avoid "texture carpet" feel.
	# Uses its own RNG (caller should pass a dedicated rng) so walls/props remain stable.
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var x_end: int = rect.position.x + rect.size.x
	var y_end: int = rect.position.y + rect.size.y
	var patch_min: int = 6
	var patch_max: int = 12
	var y: int = rect.position.y
	while y < y_end:
		var ph: int = clampi(rng.randi_range(patch_min, patch_max), 1, y_end - y)
		var x: int = rect.position.x
		while x < x_end:
			var pw: int = clampi(rng.randi_range(patch_min, patch_max), 1, x_end - x)
			var r := Rect2i(Vector2i(x, y), Vector2i(pw, ph))
			var a := clampf(alpha + rng.randf_range(-0.06, 0.06), 0.0, 1.0)
			gen._stamp_floor_rect_cells(chunk, r, tex_index, rng, a, z)
			x += pw
		y += ph



static func _stamp_district_sidewalks(gen: ChunkGenImpl, chunk: Node2D, bounds: Rect2i, lane_rect_h: Rect2i, lane_rect_v: Rect2i, rng: RandomNumberGenerator) -> void:
	var w: int = maxi(0, gen.district_sidewalk_width_cells)
	if w <= 0:
		return
	var a: float = clampf(gen.district_sidewalk_alpha, 0.0, 1.0)

	# Side strips (cobble)
	if lane_rect_h.size.y > 0:
		var top := Rect2i(lane_rect_h.position + Vector2i(0, -w), Vector2i(lane_rect_h.size.x, w)).intersection(bounds)
		var bot := Rect2i(lane_rect_h.position + Vector2i(0, lane_rect_h.size.y), Vector2i(lane_rect_h.size.x, w)).intersection(bounds)
		if top.size.x > 0 and top.size.y > 0:
			gen._stamp_floor_rect_cells_patchy(chunk, top, 2, rng, a, -94)
		if bot.size.x > 0 and bot.size.y > 0:
			gen._stamp_floor_rect_cells_patchy(chunk, bot, 2, rng, a, -94)

	if lane_rect_v.size.x > 0:
		var left := Rect2i(lane_rect_v.position + Vector2i(-w, 0), Vector2i(w, lane_rect_v.size.y)).intersection(bounds)
		var right := Rect2i(lane_rect_v.position + Vector2i(lane_rect_v.size.x, 0), Vector2i(w, lane_rect_v.size.y)).intersection(bounds)
		if left.size.x > 0 and left.size.y > 0:
			gen._stamp_floor_rect_cells_patchy(chunk, left, 2, rng, a, -94)
		if right.size.x > 0 and right.size.y > 0:
			gen._stamp_floor_rect_cells_patchy(chunk, right, 2, rng, a, -94)

	# Corner pads at intersections (stone tiles)
	var pad: int = maxi(0, gen.district_sidewalk_corner_pad_cells)
	if pad <= 0:
		return
	if lane_rect_h.size.y > 0 and lane_rect_v.size.x > 0:
		var ix0: int = lane_rect_v.position.x
		var ix1: int = lane_rect_v.position.x + lane_rect_v.size.x
		var iy0: int = lane_rect_h.position.y
		var iy1: int = lane_rect_h.position.y + lane_rect_h.size.y
		var nw := Rect2i(Vector2i(ix0 - pad, iy0 - pad), Vector2i(pad, pad)).intersection(bounds)
		var ne := Rect2i(Vector2i(ix1, iy0 - pad), Vector2i(pad, pad)).intersection(bounds)
		var sw := Rect2i(Vector2i(ix0 - pad, iy1), Vector2i(pad, pad)).intersection(bounds)
		var se := Rect2i(Vector2i(ix1, iy1), Vector2i(pad, pad)).intersection(bounds)
		var pad_alpha: float = clampf(a + 0.06, 0.0, 1.0)
		for r in [nw, ne, sw, se]:
			if r.size.x > 0 and r.size.y > 0:
				gen._stamp_floor_rect_cells_patchy(chunk, r, 3, rng, pad_alpha, -93)



static func _stamp_district_road_edge_noise(gen: ChunkGenImpl, chunk: Node2D, bounds: Rect2i, lane_rect_h: Rect2i, lane_rect_v: Rect2i, rng: RandomNumberGenerator) -> void:
	# Small "mud chips" around road edges to break perfect rectangles.
	var ch: float = clampf(gen.district_road_edge_noise_chance, 0.0, 1.0)
	if ch <= 0.0:
		return
	var n: int = rng.randi_range(4, 9)
	for _i in range(n):
		if rng.randf() > ch:
			continue
		var use_h: bool = (lane_rect_h.size.y > 0 and (lane_rect_v.size.x == 0 or rng.randf() < 0.55))
		var rect := Rect2i()
		if use_h:
			var x := rng.randi_range(lane_rect_h.position.x, lane_rect_h.position.x + lane_rect_h.size.x - 1)
			var y_edge := (lane_rect_h.position.y if rng.randf() < 0.5 else (lane_rect_h.position.y + lane_rect_h.size.y - 1))
			var y := y_edge + ( -1 if rng.randf() < 0.5 else 1 ) * rng.randi_range(0, 2)
			rect = Rect2i(Vector2i(x, y), Vector2i(rng.randi_range(1, 2), rng.randi_range(1, 2)))
		else:
			if lane_rect_v.size.x <= 0:
				continue
			var y2 := rng.randi_range(lane_rect_v.position.y, lane_rect_v.position.y + lane_rect_v.size.y - 1)
			var x_edge := (lane_rect_v.position.x if rng.randf() < 0.5 else (lane_rect_v.position.x + lane_rect_v.size.x - 1))
			var x2 := x_edge + ( -1 if rng.randf() < 0.5 else 1 ) * rng.randi_range(0, 2)
			rect = Rect2i(Vector2i(x2, y2), Vector2i(rng.randi_range(1, 2), rng.randi_range(1, 2)))

		rect = rect.intersection(bounds)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue

		# Mud/wet (index 5) at low alpha.
		gen._stamp_floor_rect_cells(chunk, rect, 5, rng, 0.22, -94)



static func _decorate_plaza_floor(gen: ChunkGenImpl, chunk: Node2D, bounds: Rect2i, plaza_rect: Rect2i, rng: RandomNumberGenerator, archetype: StringName) -> void:
	# Break up huge slabs with "islands" and a faint inner curb band.
	var inner := plaza_rect.grow(-2).intersection(bounds)
	if inner.size.x <= 0 or inner.size.y <= 0:
		return

	# Inner curb lip: subtle tiles ring
	var curb := plaza_rect.grow(-1).intersection(bounds)
	if curb.size.x > 0 and curb.size.y > 0:
		# top/bot strips
		var top := Rect2i(curb.position, Vector2i(curb.size.x, 1))
		var bot := Rect2i(Vector2i(curb.position.x, curb.position.y + curb.size.y - 1), Vector2i(curb.size.x, 1))
		var left := Rect2i(curb.position, Vector2i(1, curb.size.y))
		var right := Rect2i(Vector2i(curb.position.x + curb.size.x - 1, curb.position.y), Vector2i(1, curb.size.y))
		for r in [top, bot, left, right]:
			var rr: Rect2i = (r as Rect2i).intersection(bounds)
			if rr.size.x > 0 and rr.size.y > 0:
				gen._stamp_floor_rect_cells(chunk, rr, 3, rng, 0.75, -93)

	# Islands (grass/dirt) to cut the carpet.
	var islands_max: int = maxi(0, gen.district_plaza_islands_max)
	var islands: int = rng.randi_range(1, maxi(1, islands_max))
	for _i in range(islands):
		if rng.randf() > clampf(gen.district_plaza_island_chance, 0.0, 1.0):
			continue
		var iw: int = rng.randi_range(3, 6)
		var ih: int = rng.randi_range(3, 6)
		if inner.size.x <= iw or inner.size.y <= ih:
			continue
		var ix := rng.randi_range(inner.position.x, inner.position.x + inner.size.x - iw)
		var iy := rng.randi_range(inner.position.y, inner.position.y + inner.size.y - ih)

		# Keep center cleaner for gate.
		if archetype == &"gate":
			var cx: int = inner.position.x + int(inner.size.x / 2.0)
			var cy: int = inner.position.y + int(inner.size.y / 2.0)
			if absi(ix - cx) < 4 and absi(iy - cy) < 4:
				continue

		var tex := (0 if rng.randf() < 0.55 else 1) # grass/dirt
		gen._stamp_floor_rect_cells_patchy(chunk, Rect2i(Vector2i(ix, iy), Vector2i(iw, ih)), tex, rng, 0.95, -93)

		# A couple of "planter/pillar" blocks near the island edge for authored feel.
		if gen.cover_half_scene != null and rng.randf() < 0.65:
			var px := clampi(ix + rng.randi_range(0, iw - 1), bounds.position.x + 1, bounds.position.x + bounds.size.x - 2)
			var py := clampi(iy + rng.randi_range(0, ih - 1), bounds.position.y + 1, bounds.position.y + bounds.size.y - 2)
			gen._spawn_block(chunk, gen.cover_half_scene, px, py)


static func _erase_cells_in_rect(_gen: ChunkGenImpl, wall_cells: Dictionary, window_cells: Dictionary, rect: Rect2i) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var x0: int = rect.position.x
	var y0: int = rect.position.y
	var x1: int = rect.position.x + rect.size.x
	var y1: int = rect.position.y + rect.size.y
	for y in range(y0, y1):
		for x in range(x0, x1):
			var c: Vector2i = Vector2i(x, y)
			if wall_cells.has(c):
				wall_cells.erase(c)
			if window_cells.has(c):
				window_cells.erase(c)



static func _add_plaza_ring(_gen: ChunkGenImpl, wall_cells: Dictionary, plaza_rect: Rect2i, cells_per_chunk: int, rng: RandomNumberGenerator, archetype: StringName) -> void:
	# Stronger perimeter language for plaza/arena/gate:
	# - corners solid (no "fence posts")
	# - thickness for gate/arena
	# - clustered segments instead of per-cell random breaks
	var bounds: Rect2i = Rect2i(Vector2i(1, 1), Vector2i(cells_per_chunk - 2, cells_per_chunk - 2))
	var ring: Rect2i = plaza_rect.grow(1).intersection(bounds)
	if ring.size.x <= 0 or ring.size.y <= 0:
		return

	var thickness: int = 1
	var break_ch: float = 0.22
	if archetype == &"arena":
		thickness = 2
		break_ch = 0.12
	elif archetype == &"gate":
		thickness = 2
		break_ch = 0.06

	var x0: int = ring.position.x
	var y0: int = ring.position.y
	var x1: int = ring.position.x + ring.size.x - 1
	var y1: int = ring.position.y + ring.size.y - 1

	# North side (thicken downward)
	var len_n: int = x1 - x0 + 1
	var idx: int = 0
	while idx < len_n:
		var seg_len: int = clampi(rng.randi_range(4, 9), 1, len_n - idx)
		if rng.randf() < break_ch and len_n - idx > 7:
			idx += rng.randi_range(2, 4)
			continue
		for i in range(seg_len):
			var c := Vector2i(x0 + idx + i, y0)
			for t in range(thickness):
				wall_cells[c + Vector2i(0, 1) * t] = true
		if rng.randf() < 0.18 and thickness == 1 and seg_len >= 5:
			var base := Vector2i(x0 + idx + rng.randi_range(1, seg_len - 2), y0)
			wall_cells[base + Vector2i(0, 1)] = true
		idx += seg_len + rng.randi_range(1, 3)

	# South side (thicken upward)
	var len_s: int = len_n
	idx = 0
	while idx < len_s:
		var seg_len2: int = clampi(rng.randi_range(4, 9), 1, len_s - idx)
		if rng.randf() < break_ch and len_s - idx > 7:
			idx += rng.randi_range(2, 4)
			continue
		for i2 in range(seg_len2):
			var c2 := Vector2i(x0 + idx + i2, y1)
			for t2 in range(thickness):
				wall_cells[c2 + Vector2i(0, -1) * t2] = true
		if rng.randf() < 0.18 and thickness == 1 and seg_len2 >= 5:
			var base2 := Vector2i(x0 + idx + rng.randi_range(1, seg_len2 - 2), y1)
			wall_cells[base2 + Vector2i(0, -1)] = true
		idx += seg_len2 + rng.randi_range(1, 3)

	# West side (thicken right)
	var len_w: int = y1 - y0 + 1
	idx = 0
	while idx < len_w:
		var seg_len3: int = clampi(rng.randi_range(4, 9), 1, len_w - idx)
		if rng.randf() < break_ch and len_w - idx > 7:
			idx += rng.randi_range(2, 4)
			continue
		for i3 in range(seg_len3):
			var c3 := Vector2i(x0, y0 + idx + i3)
			for t3 in range(thickness):
				wall_cells[c3 + Vector2i(1, 0) * t3] = true
		if rng.randf() < 0.18 and thickness == 1 and seg_len3 >= 5:
			var base3 := Vector2i(x0, y0 + idx + rng.randi_range(1, seg_len3 - 2))
			wall_cells[base3 + Vector2i(1, 0)] = true
		idx += seg_len3 + rng.randi_range(1, 3)

	# East side (thicken left)
	var len_e: int = len_w
	idx = 0
	while idx < len_e:
		var seg_len4: int = clampi(rng.randi_range(4, 9), 1, len_e - idx)
		if rng.randf() < break_ch and len_e - idx > 7:
			idx += rng.randi_range(2, 4)
			continue
		for i4 in range(seg_len4):
			var c4 := Vector2i(x1, y0 + idx + i4)
			for t4 in range(thickness):
				wall_cells[c4 + Vector2i(-1, 0) * t4] = true
		if rng.randf() < 0.18 and thickness == 1 and seg_len4 >= 5:
			var base4 := Vector2i(x1, y0 + idx + rng.randi_range(1, seg_len4 - 2))
			wall_cells[base4 + Vector2i(-1, 0)] = true
		idx += seg_len4 + rng.randi_range(1, 3)

	# Force corners solid (and thick if needed)
	for t5 in range(thickness):
		wall_cells[Vector2i(x0 + t5, y0)] = true
		wall_cells[Vector2i(x1 - t5, y0)] = true
		wall_cells[Vector2i(x0 + t5, y1)] = true
		wall_cells[Vector2i(x1 - t5, y1)] = true
		wall_cells[Vector2i(x0, y0 + t5)] = true
		wall_cells[Vector2i(x1, y0 + t5)] = true
		wall_cells[Vector2i(x0, y1 - t5)] = true
		wall_cells[Vector2i(x1, y1 - t5)] = true

	# Optional deliberate breach (plaza/arena only)
	if archetype != &"gate" and rng.randf() < 0.45:
		var side: int = rng.randi_range(0, 3)
		var gap_w: int = 4
		var half_gap: int = gap_w >> 1
		match side:
			0: # N
				var gx: int = rng.randi_range(x0 + 3, x1 - 3)
				for i5 in range(gap_w):
					wall_cells.erase(Vector2i(gx + i5 - half_gap, y0))
			1: # E
				var gy: int = rng.randi_range(y0 + 3, y1 - 3)
				for i6 in range(gap_w):
					wall_cells.erase(Vector2i(x1, gy + i6 - half_gap))
			2: # S
				var gx2: int = rng.randi_range(x0 + 3, x1 - 3)
				for i7 in range(gap_w):
					wall_cells.erase(Vector2i(gx2 + i7 - half_gap, y1))
			3: # W
				var gy2: int = rng.randi_range(y0 + 3, y1 - 3)
				for i8 in range(gap_w):
					wall_cells.erase(Vector2i(x0, gy2 + i8 - half_gap))
