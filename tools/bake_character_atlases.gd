extends SceneTree
## Bakes game-resolution character atlases from the supplied source sheets.
##
##     godot --headless --path . -s tools/bake_character_atlases.gd
##     godot --headless --path . --import
##
## Reads every RaceVisualDefinition / EnemyVisualDefinition listed below, cuts
## the cells they name out of the untouched source PNGs, scales them to screen
## size, composites enemy helmets onto their headless bodies, packs one atlas
## per character and writes a CharacterFrameSet (.tres) next to it under
## assets/textures/characters/baked/. Re-run after editing a definition.
##
## Nothing here assumes a regular grid: rows are found as alpha bands, every
## frame is cut around its own neck hole (the dark collar opening every body
## sheet has), and the ground line is the bottom of the row band.

const RACE_DEFINITIONS: Array[String] = [
	"res://data/visuals/races/human.tres",
	"res://data/visuals/races/elf.tres",
	"res://data/visuals/races/dragonborn.tres",
	"res://data/visuals/races/warforged.tres",
]
const ENEMY_DEFINITIONS: Array[String] = [
	"res://data/visuals/enemies/grunt.tres",
	"res://data/visuals/enemies/spitter.tres",
]
const FRAME_SET_SCRIPT := "res://data/visuals/CharacterFrameSet.gd"

const ALPHA_THRESHOLD := 40
const ROW_MERGE_GAP := 4
const HOLE_LUMINANCE := 28
const HOLE_ALPHA := 200
const HOLE_MIN_PIXELS := 50
const HOLE_SEARCH_FRACTION := 0.22
const SCARF_FRACTION := 0.18
## Transparent pixels around every atlas frame, so a frame sampled a hair
## outside its region never shows its neighbour.
const ATLAS_PADDING := 2
## How far (fraction of a cell) a column boundary may move off the grid line
## to the emptiest column between two sprites that lean into each other.
const VALLEY_SEARCH_FRACTION := 0.3
## Baked pixels fainter than this are resampling halo, not art.
const EDGE_ALPHA := 80
## Components smaller than this (source px) inside a cell are dust.
const DUST_PIXELS := 12

## Facings whose art can stand in for each other by flipping. Front and back
## are never mirrors of one another, so only the side pair is here.
const MIRROR_OF := {
	"left": "right", "right": "left",
}


class Sheet:
	var path := ""
	var image: Image
	var width := 0
	var height := 0
	var data := PackedByteArray()
	var bands: Array[Vector2i] = []
	var splits: Dictionary = {}  # row -> PackedInt32Array of column boundaries

	func alpha(x: int, y: int) -> int:
		return data[(y * width + x) * 4 + 3]

	func luminance(x: int, y: int) -> int:
		var base := (y * width + x) * 4
		return (data[base] + data[base + 1] + data[base + 2]) / 3


class Frame:
	var image: Image
	## Pixel of `image` that sits on the node origin.
	var anchor := Vector2.ZERO
	## Collar centre relative to the origin (bodies only).
	var collar := Vector2.ZERO


class Bake:
	var animations: Dictionary = {}  # name -> Array[Frame]
	var speeds: Dictionary = {}      # name -> fps
	var mirrored := PackedStringArray()

	func add(name: String, frames: Array, fps: float) -> void:
		animations[name] = frames
		speeds[name] = fps


var _failures := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/textures/characters/baked"))
	for path in RACE_DEFINITIONS:
		var definition := load(path) as RaceVisualDefinition
		if definition == null:
			_fail("cannot load " + path)
			continue
		_bake_race(definition)
	for path in ENEMY_DEFINITIONS:
		var definition := load(path) as EnemyVisualDefinition
		if definition == null:
			_fail("cannot load " + path)
			continue
		_bake_enemy(definition)
	if _failures > 0:
		push_error("bake finished with %d failure(s)" % _failures)
	else:
		print("bake finished cleanly")
	quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	_failures += 1
	push_error("[bake] " + message)


# ---------------------------------------------------------------------------
# Players
# ---------------------------------------------------------------------------

func _bake_race(definition: RaceVisualDefinition) -> void:
	var race := String(definition.race_id)
	print("== bake race ", race)
	var idle := _load_sheet(definition.idle_sheet)
	var run := _load_sheet(definition.run_sheet)
	var head := _load_sheet(definition.head_sheet)
	if idle == null or run == null or head == null:
		_fail("%s: missing sheet" % race)
		return

	# Scale: the idle "down" band is the reference; the run sheet is scaled so
	# its collar is as wide as the idle collar unless a height was given.
	var idle_down := _first_cell(definition.idle_cells, "down")
	var idle_band := _band(idle, idle_down.x)
	var idle_scale := definition.idle_height_px / float(idle_band.y - idle_band.x)
	var run_scale := 0.0
	var run_down_row := int(definition.run_rows.get("down", 0))
	var run_band := _band(run, run_down_row)
	if definition.run_height_px > 0.0:
		run_scale = definition.run_height_px / float(run_band.y - run_band.x)
	else:
		var idle_cell := _cell_sheet(idle, idle_down.x, idle_down.y, definition.idle_columns)
		var idle_hole := _hole(idle_cell, _bbox(idle_cell, _whole(idle_cell)))
		var run_hole_width := 0.0
		for column in range(definition.run_columns):
			var run_cell := _cell_sheet(run, run_down_row, column, definition.run_columns)
			var hole := _hole(run_cell, _bbox(run_cell, _whole(run_cell)))
			run_hole_width += float(hole.get("width", 0))
		run_hole_width /= float(definition.run_columns)
		if idle_hole.is_empty() or run_hole_width <= 0.0:
			_fail("%s: no neck hole found to match run scale; set run_height_px" % race)
			run_scale = idle_scale
		else:
			run_scale = idle_scale * float(idle_hole["width"]) / run_hole_width
	var head_down: Vector2i = definition.head_cells.get("down", Vector2i.ZERO)
	var head_cell := _cell_sheet(head, head_down.x, head_down.y, definition.head_columns)
	var head_bbox := _bbox(head_cell, _whole(head_cell))
	var head_scale := definition.head_height_px / float(head_bbox.size.y)
	print("  scales idle=%.4f run=%.4f head=%.4f" % [idle_scale, run_scale, head_scale])

	var bake := Bake.new()
	for direction in RaceVisualDefinition.DIRECTIONS:
		var key := String(direction)
		# Body idle: listed cells, in order.
		var cells: Array = definition.idle_cells.get(key, [])
		if cells.is_empty():
			_fail("%s: idle has no cells for %s" % [race, key])
			continue
		var idle_frames: Array = []
		for cell_variant in cells:
			var cell := cell_variant as Vector2i
			idle_frames.append(_cut_body(idle, cell.x, cell.y, definition.idle_columns, idle_scale))
		var idle_fps := float(idle_frames.size()) / maxf(definition.idle_cycle_seconds, 0.1)
		bake.add("body_idle_" + key, idle_frames, idle_fps)
		# Body run: every column of the row.
		if not definition.run_rows.has(key):
			_fail("%s: run has no row for %s" % [race, key])
			continue
		var row := int(definition.run_rows[key])
		var run_frames: Array = []
		var order: Array = definition.run_frame_order.get(key, range(definition.run_columns))
		for column_variant in order:
			var column := int(column_variant)
			if column < 0 or column >= definition.run_columns:
				_fail("%s: run_frame_order[%s] names column %d" % [race, key, column])
				continue
			run_frames.append(_cut_body(run, row, column, definition.run_columns, run_scale))
		bake.add("body_run_" + key, run_frames, definition.run_fps)
		# Head: one pose per facing; mirror the opposite facing when missing.
		var head_frame := _cut_head_for(definition, head, key, head_scale, definition.head_cells, bake, "head_idle_")
		if head_frame == null:
			_fail("%s: no head art for %s or its opposite" % [race, key])
			continue
		bake.add("head_idle_" + key, [head_frame], 1.0)
		if definition.head_run_cells.has(key) or definition.head_run_cells.has(MIRROR_OF.get(key, "")):
			var run_head := _cut_head_for(definition, head, key, head_scale, definition.head_run_cells, bake, "head_run_")
			if run_head != null:
				bake.add("head_run_" + key, [run_head], 1.0)
		# Where the head lands, for tuning head_offsets by eye.
		var first := idle_frames[0] as Frame
		print("  %-5s collar at %s (screen px from the feet)" % [key, first.collar])
	_write(bake, definition.baked_atlas_path(), definition.baked_frames_path())


func _cut_head_for(
	definition: RaceVisualDefinition,
	head: Sheet,
	key: String,
	scale: float,
	table: Dictionary,
	bake: Bake,
	prefix: String,
) -> Frame:
	if table.has(key):
		var cell := table[key] as Vector2i
		return _cut_head(head, cell.x, cell.y, definition.head_columns, scale, false)
	var mirror_source: String = MIRROR_OF.get(key, "")
	if not mirror_source.is_empty() and table.has(mirror_source):
		var cell := table[mirror_source] as Vector2i
		bake.mirrored.append(prefix + key)
		return _cut_head(head, cell.x, cell.y, definition.head_columns, scale, true)
	return null


## A body frame: tight horizontally, the full row band vertically (the band's
## bottom is the ground line), hung from the neck hole's centre.
func _cut_body(sheet: Sheet, row: int, column: int, columns: int, scale: float) -> Frame:
	var cell := _cell_sheet(sheet, row, column, columns)
	var bbox := _bbox(cell, _whole(cell))
	var hole := _hole(cell, bbox)
	var collar_x := float(hole.get("cx", bbox.position.x + bbox.size.x * 0.5))
	var collar_y := float(hole.get("cy", 0))
	var crop := Rect2i(bbox.position.x, 0, bbox.size.x, cell.height)
	var frame := Frame.new()
	frame.image = _downscale(_cut(cell, crop), scale)
	frame.anchor = Vector2(roundf((collar_x - crop.position.x) * scale), frame.image.get_height())
	frame.collar = Vector2(0.0, roundf(collar_y * scale) - frame.image.get_height())
	return frame


## A head frame: the tight cell, hung from the scarf's bottom centre.
func _cut_head(sheet: Sheet, row: int, column: int, columns: int, scale: float, mirror: bool) -> Frame:
	var cell := _cell_sheet(sheet, row, column, columns)
	var bbox := _bbox(cell, _whole(cell))
	var scarf_x := _mass_center_x(cell, bbox, 1.0 - SCARF_FRACTION, 1.0)
	var frame := Frame.new()
	frame.image = _downscale(_cut(cell, bbox), scale)
	var anchor_x := roundf((scarf_x - bbox.position.x) * scale)
	if mirror:
		frame.image.flip_x()
		anchor_x = frame.image.get_width() - anchor_x
	frame.anchor = Vector2(anchor_x, frame.image.get_height())
	return frame


# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------

func _bake_enemy(definition: EnemyVisualDefinition) -> void:
	var enemy := String(definition.enemy_id)
	print("== bake enemy ", enemy)
	var sheet := _load_sheet(definition.sheet)
	if sheet == null:
		_fail("%s: missing sheet" % enemy)
		return
	var down_row := int(definition.body_rows.get("down", 0))
	var down_band := _band(sheet, down_row)
	var scale := definition.body_height_px / float(down_band.y - down_band.x)
	var bake := Bake.new()
	for key_variant in definition.body_rows.keys():
		var key := String(key_variant)
		var row := int(definition.body_rows[key])
		if not definition.head_cells.has(key):
			_fail("%s: no head cell for %s" % [enemy, key])
			continue
		var head_cell := definition.head_cells[key] as Vector2i
		var frames := _composite_row(sheet, row, head_cell, definition, scale)
		bake.add("run_" + key, frames, definition.fps)
		var idle_index := definition.idle_column
		if idle_index < 0 or idle_index >= frames.size():
			idle_index = _narrowest_column(sheet, row, definition.columns)
		bake.add("idle_" + key, [frames[idle_index]], 1.0)
	_write(bake, definition.baked_atlas_path(), definition.baked_frames_path())


## Every stride frame of a row with the helmet seated in its neck hole. Frames
## of one row share a canvas size so the enemy's single centred Sprite2D never
## jumps between them.
func _composite_row(sheet: Sheet, row: int, head_cell: Vector2i, definition: EnemyVisualDefinition, scale: float) -> Array:
	var head_sheet := _cell_sheet(sheet, head_cell.x, head_cell.y, definition.columns)
	var head_bbox := _bbox(head_sheet, _whole(head_sheet))
	var head_image := _cut(head_sheet, head_bbox)
	var head_center_x := _mass_center_x(head_sheet, head_bbox, 1.0 - SCARF_FRACTION, 1.0) - head_bbox.position.x
	var placements: Array = []
	var half_width := 0
	var top := 0
	var cell_height := 0
	for column in range(definition.columns):
		var cell := _cell_sheet(sheet, row, column, definition.columns)
		cell_height = cell.height
		var bbox := _bbox(cell, _whole(cell))
		var hole := _hole(cell, bbox)
		var cx := roundi(float(hole.get("cx", bbox.position.x + bbox.size.x * 0.5)))
		var hole_top := int(hole.get("top", bbox.position.y))
		var hole_bottom := int(hole.get("bottom", bbox.position.y))
		var head_bottom := hole_top + roundi(definition.head_seat * float(hole_bottom - hole_top))
		var head_x := cx - roundi(head_center_x)
		var head_y := head_bottom - head_image.get_height()
		placements.append({"cell": cell, "bbox": bbox, "cx": cx, "head_x": head_x, "head_y": head_y})
		half_width = maxi(half_width, maxi(cx - mini(bbox.position.x, head_x), maxi(bbox.end.x, head_x + head_image.get_width()) - cx))
		top = mini(top, head_y)
	var width := half_width * 2 + 2
	var height := cell_height - top
	var frames: Array = []
	for placement_variant in placements:
		var placement := placement_variant as Dictionary
		var cell := placement["cell"] as Sheet
		var cx := int(placement["cx"])
		var origin := Vector2i(cx - half_width - 1, top)
		var canvas := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
		var bbox := placement["bbox"] as Rect2i
		var body_rect := Rect2i(bbox.position.x, 0, bbox.size.x, cell.height)
		canvas.blit_rect(cell.image, body_rect, body_rect.position - origin)
		var head_pos := Vector2i(int(placement["head_x"]), int(placement["head_y"])) - origin
		canvas.blend_rect(head_image, Rect2i(Vector2i.ZERO, head_image.get_size()), head_pos)
		var frame := Frame.new()
		frame.image = _downscale(canvas, scale)
		frame.anchor = Vector2(frame.image.get_width() * 0.5, frame.image.get_height())
		frames.append(frame)
	return frames


func _narrowest_column(sheet: Sheet, row: int, columns: int) -> int:
	var best := 0
	var best_width := 1 << 30
	for column in range(columns):
		var cell := _cell_sheet(sheet, row, column, columns)
		var bbox := _bbox(cell, _whole(cell))
		if bbox.size.x < best_width:
			best_width = bbox.size.x
			best = column
	return best


# ---------------------------------------------------------------------------
# Sheet measurement
# ---------------------------------------------------------------------------

func _load_sheet(texture: Texture2D) -> Sheet:
	if texture == null or texture.resource_path.is_empty():
		return null
	var sheet := Sheet.new()
	sheet.path = texture.resource_path
	sheet.image = Image.load_from_file(ProjectSettings.globalize_path(texture.resource_path))
	if sheet.image == null:
		_fail("cannot read " + texture.resource_path)
		return null
	sheet.image.convert(Image.FORMAT_RGBA8)
	sheet.width = sheet.image.get_width()
	sheet.height = sheet.image.get_height()
	sheet.data = sheet.image.get_data()
	sheet.bands = _row_bands(sheet)
	print("  %s: %dx%d, %d row bands" % [texture.resource_path.get_file(), sheet.width, sheet.height, sheet.bands.size()])
	return sheet


## Rows of art, as (y0, y1) bands of rows holding any opaque pixel.
func _row_bands(sheet: Sheet) -> Array[Vector2i]:
	var bands: Array[Vector2i] = []
	var start := -1
	var last_filled := -1
	for y in range(sheet.height):
		var filled := false
		var base := y * sheet.width * 4 + 3
		for x in range(sheet.width):
			if sheet.data[base + x * 4] > ALPHA_THRESHOLD:
				filled = true
				break
		if filled:
			if start < 0:
				start = y
			elif y - last_filled > ROW_MERGE_GAP:
				bands.append(Vector2i(start, last_filled + 1))
				start = y
			last_filled = y
	if start >= 0:
		bands.append(Vector2i(start, last_filled + 1))
	return bands


func _band(sheet: Sheet, row: int) -> Vector2i:
	if row < 0 or row >= sheet.bands.size():
		_fail("%s has no row %d (found %d)" % [sheet.path.get_file(), row, sheet.bands.size()])
		return Vector2i(0, sheet.height)
	return sheet.bands[row]


## The cell's columns: the grid line, moved to the emptiest column nearby so
## two sprites that lean into each other's cells are split where they touch.
func _cell_rect(sheet: Sheet, row: int, column: int, columns: int) -> Rect2i:
	var band := _band(sheet, row)
	var splits := _column_splits(sheet, row, columns)
	return Rect2i(splits[column], band.x, splits[column + 1] - splits[column], band.y - band.x)


func _column_splits(sheet: Sheet, row: int, columns: int) -> PackedInt32Array:
	if sheet.splits.has(row):
		return sheet.splits[row]
	var band := _band(sheet, row)
	var coverage := PackedInt32Array()
	coverage.resize(sheet.width)
	for x in range(sheet.width):
		var count := 0
		for y in range(band.x, band.y):
			if sheet.alpha(x, y) > ALPHA_THRESHOLD:
				count += 1
		coverage[x] = count
	var splits := PackedInt32Array([0])
	var cell_width := float(sheet.width) / float(columns)
	var radius := int(cell_width * VALLEY_SEARCH_FRACTION)
	for k in range(1, columns):
		var grid := int(cell_width * float(k))
		var best := grid
		for x in range(maxi(1, grid - radius), mini(sheet.width - 1, grid + radius + 1)):
			if coverage[x] < coverage[best] or (coverage[x] == coverage[best] and absi(x - grid) < absi(best - grid)):
				best = x
		splits.append(best)
	splits.append(sheet.width)
	sheet.splits[row] = splits
	return splits


## One cell cut out as its own sheet (y = 0 is the row band's top), with the
## neighbours' spill-over removed: every opaque component other than the
## largest is dropped when it touches the cell's left or right edge or is dust.
func _cell_sheet(sheet: Sheet, row: int, column: int, columns: int) -> Sheet:
	var rect := _cell_rect(sheet, row, column, columns)
	var cell := Sheet.new()
	cell.path = "%s[%d,%d]" % [sheet.path.get_file(), row, column]
	cell.image = _cut(sheet, rect)
	_isolate(cell.image)
	cell.width = cell.image.get_width()
	cell.height = cell.image.get_height()
	cell.data = cell.image.get_data()
	cell.bands = [Vector2i(0, cell.height)]
	return cell


func _whole(sheet: Sheet) -> Rect2i:
	return Rect2i(0, 0, sheet.width, sheet.height)


func _isolate(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var labels := PackedInt32Array()
	labels.resize(width * height)
	var stack := PackedInt32Array()
	stack.resize(width * height)
	var components: Array = []  # [size, min_x, max_x]
	for start in range(width * height):
		if labels[start] != 0 or data[start * 4 + 3] <= ALPHA_THRESHOLD:
			continue
		var id := components.size() + 1
		var size := 0
		var min_x := width
		var max_x := -1
		var top := 0
		stack[0] = start
		top = 1
		labels[start] = id
		while top > 0:
			top -= 1
			var index := stack[top]
			size += 1
			var x := index % width
			var y := index / width
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			for dy in range(-1, 2):
				var ny := y + dy
				if ny < 0 or ny >= height:
					continue
				for dx in range(-1, 2):
					var nx := x + dx
					if nx < 0 or nx >= width:
						continue
					var neighbour := ny * width + nx
					if labels[neighbour] == 0 and data[neighbour * 4 + 3] > ALPHA_THRESHOLD:
						labels[neighbour] = id
						stack[top] = neighbour
						top += 1
		components.append([size, min_x, max_x])
	if components.size() <= 1:
		return
	var largest := 0
	for i in range(components.size()):
		if int(components[i][0]) > int(components[largest][0]):
			largest = i
	var erase := PackedByteArray()
	erase.resize(components.size() + 1)
	var any := false
	for i in range(components.size()):
		if i == largest:
			continue
		var component: Array = components[i]
		if int(component[0]) < DUST_PIXELS or int(component[1]) == 0 or int(component[2]) == width - 1:
			erase[i + 1] = 1
			any = true
	if not any:
		return
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	for index in range(width * height):
		if labels[index] != 0 and erase[labels[index]] != 0:
			image.set_pixel(index % width, index / width, clear)


func _bbox(sheet: Sheet, rect: Rect2i) -> Rect2i:
	var min_x := rect.end.x
	var min_y := rect.end.y
	var max_x := rect.position.x - 1
	var max_y := rect.position.y - 1
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if sheet.alpha(x, y) > ALPHA_THRESHOLD:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < min_x:
		_fail("%s: empty cell at %s" % [sheet.path.get_file(), rect])
		return rect
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## The neck hole: the near-black opaque opening in the top of every body cell.
## Returns cx/cy (centre), top/bottom (rows) and width, or {} when absent.
func _hole(sheet: Sheet, bbox: Rect2i) -> Dictionary:
	var search_bottom := bbox.position.y + int(float(bbox.size.y) * HOLE_SEARCH_FRACTION)
	var count := 0
	var sum_x := 0
	var sum_y := 0
	var min_x := 1 << 30
	var max_x := -1
	var min_y := 1 << 30
	var max_y := -1
	for y in range(bbox.position.y, search_bottom):
		for x in range(bbox.position.x, bbox.end.x):
			if sheet.alpha(x, y) > HOLE_ALPHA and sheet.luminance(x, y) < HOLE_LUMINANCE:
				count += 1
				sum_x += x
				sum_y += y
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if count < HOLE_MIN_PIXELS:
		return {}
	return {
		"cx": float(sum_x) / float(count) + 0.5,
		"cy": float(sum_y) / float(count) + 0.5,
		"top": min_y,
		"bottom": max_y + 1,
		"width": max_x - min_x + 1,
	}


## Horizontal centre of opaque mass between two height fractions of a bbox.
func _mass_center_x(sheet: Sheet, bbox: Rect2i, from_fraction: float, to_fraction: float) -> float:
	var y0 := bbox.position.y + int(float(bbox.size.y) * from_fraction)
	var y1 := bbox.position.y + int(float(bbox.size.y) * to_fraction)
	var count := 0
	var sum_x := 0
	for y in range(y0, y1):
		for x in range(bbox.position.x, bbox.end.x):
			if sheet.alpha(x, y) > ALPHA_THRESHOLD:
				count += 1
				sum_x += x
	if count == 0:
		return bbox.position.x + bbox.size.x * 0.5
	return float(sum_x) / float(count) + 0.5


# ---------------------------------------------------------------------------
# Pixels
# ---------------------------------------------------------------------------

func _cut(sheet: Sheet, rect: Rect2i) -> Image:
	var image := Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	var inside := rect.intersection(Rect2i(0, 0, sheet.width, sheet.height))
	if inside.size.x > 0 and inside.size.y > 0:
		image.blit_rect(sheet.image, inside, inside.position - rect.position)
	return image


## Lanczos downscale on premultiplied colour so the transparent (black) pixels
## around every sprite do not bleed dark fringes into the edges.
func _downscale(image: Image, scale: float) -> Image:
	if is_equal_approx(scale, 1.0):
		return image
	var width := maxi(1, roundi(image.get_width() * scale))
	var height := maxi(1, roundi(image.get_height() * scale))
	var work := image.duplicate() as Image
	work.premultiply_alpha()
	work.resize(width, height, Image.INTERPOLATE_LANCZOS)
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	var floor_alpha := float(EDGE_ALPHA) / 255.0
	for y in range(height):
		for x in range(width):
			var color := work.get_pixel(x, y)
			if color.a < floor_alpha:
				work.set_pixel(x, y, clear)
			else:
				var inv := 1.0 / color.a
				work.set_pixel(x, y, Color(minf(color.r * inv, 1.0), minf(color.g * inv, 1.0), minf(color.b * inv, 1.0), color.a))
	# A pixel with no opaque 4-neighbour is resampling noise, not a detail.
	var lone := PackedInt32Array()
	for y in range(height):
		for x in range(width):
			if work.get_pixel(x, y).a <= 0.0:
				continue
			var attached := false
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + offset
				if n.x >= 0 and n.y >= 0 and n.x < width and n.y < height and work.get_pixel(n.x, n.y).a > 0.0:
					attached = true
					break
			if not attached:
				lone.append(y * width + x)
	for index in lone:
		work.set_pixel(index % width, index / width, clear)
	return work


func _first_cell(table: Dictionary, key: String) -> Vector2i:
	var cells: Array = table.get(key, [])
	return cells[0] as Vector2i if not cells.is_empty() else Vector2i.ZERO


# ---------------------------------------------------------------------------
# Atlas + resource output
# ---------------------------------------------------------------------------

func _write(bake: Bake, atlas_path: String, frames_path: String) -> void:
	# Shelf packing: one atlas row per animation.
	var names: Array = bake.animations.keys()
	names.sort()
	var atlas_width := 0
	var atlas_height := 0
	for name in names:
		var row_width := 0
		var row_height := 0
		for frame_variant in bake.animations[name]:
			var frame := frame_variant as Frame
			row_width += frame.image.get_width() + ATLAS_PADDING
			row_height = maxi(row_height, frame.image.get_height())
		atlas_width = maxi(atlas_width, row_width + ATLAS_PADDING)
		atlas_height += row_height + ATLAS_PADDING
	atlas_height += ATLAS_PADDING
	var atlas := Image.create_empty(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	var regions: Dictionary = {}
	var y := ATLAS_PADDING
	for name in names:
		var x := ATLAS_PADDING
		var row_height := 0
		var rects: Array[Rect2i] = []
		for frame_variant in bake.animations[name]:
			var frame := frame_variant as Frame
			atlas.blit_rect(frame.image, Rect2i(Vector2i.ZERO, frame.image.get_size()), Vector2i(x, y))
			rects.append(Rect2i(x, y, frame.image.get_width(), frame.image.get_height()))
			x += frame.image.get_width() + ATLAS_PADDING
			row_height = maxi(row_height, frame.image.get_height())
		regions[name] = rects
		y += row_height + ATLAS_PADDING
	var error := atlas.save_png(ProjectSettings.globalize_path(atlas_path))
	if error != OK:
		_fail("cannot write " + atlas_path)
		return

	# CharacterFrameSet as text, so the atlas it points at can be imported in
	# the same --import pass as the resource itself.
	var lines := PackedStringArray()
	var sub_count := 1
	for name in names:
		sub_count += (bake.animations[name] as Array).size()
	lines.append('[gd_resource type="Resource" script_class="CharacterFrameSet" load_steps=%d format=3]' % (sub_count + 3))
	lines.append("")
	lines.append('[ext_resource type="Script" path="%s" id="1_script"]' % FRAME_SET_SCRIPT)
	lines.append('[ext_resource type="Texture2D" path="%s" id="2_atlas"]' % atlas_path)
	lines.append("")
	var texture_ids: Dictionary = {}
	for name in names:
		var ids := PackedStringArray()
		var rects: Array[Rect2i] = regions[name]
		for index in range(rects.size()):
			var id := "AtlasTexture_%s_%d" % [name, index]
			ids.append(id)
			var rect := rects[index]
			lines.append('[sub_resource type="AtlasTexture" id="%s"]' % id)
			lines.append('atlas = ExtResource("2_atlas")')
			lines.append("region = Rect2(%d, %d, %d, %d)" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y])
			lines.append("")
		texture_ids[name] = ids
	lines.append('[sub_resource type="SpriteFrames" id="SpriteFrames_1"]')
	var animation_entries := PackedStringArray()
	for name in names:
		var frame_entries := PackedStringArray()
		for id in texture_ids[name]:
			frame_entries.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % id)
		animation_entries.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % [
			", ".join(frame_entries), name, _float_text(float(bake.speeds[name]))
		])
	lines.append("animations = [%s]" % ", ".join(animation_entries))
	lines.append("")
	lines.append("[resource]")
	lines.append('script = ExtResource("1_script")')
	lines.append('frames = SubResource("SpriteFrames_1")')
	lines.append("anchors = {")
	lines.append(_vector_table(bake, names, "anchor"))
	lines.append("}")
	lines.append("collars = {")
	lines.append(_vector_table(bake, names, "collar"))
	lines.append("}")
	var mirrored := PackedStringArray()
	for name in bake.mirrored:
		mirrored.append('"%s"' % name)
	lines.append("mirrored = PackedStringArray(%s)" % ", ".join(mirrored))
	var file := FileAccess.open(frames_path, FileAccess.WRITE)
	if file == null:
		_fail("cannot write " + frames_path)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("  wrote %s (%dx%d) and %s" % [atlas_path.get_file(), atlas_width, atlas_height, frames_path.get_file()])


func _vector_table(bake: Bake, names: Array, field: String) -> String:
	var rows := PackedStringArray()
	for name in names:
		var numbers := PackedStringArray()
		for frame_variant in bake.animations[name]:
			var frame := frame_variant as Frame
			var vector: Vector2 = frame.get(field)
			numbers.append(_float_text(vector.x))
			numbers.append(_float_text(vector.y))
		rows.append('"%s": PackedVector2Array(%s)' % [name, ", ".join(numbers)])
	return ",\n".join(rows)


func _float_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d.0" % int(roundf(value))
	return "%.3f" % value
