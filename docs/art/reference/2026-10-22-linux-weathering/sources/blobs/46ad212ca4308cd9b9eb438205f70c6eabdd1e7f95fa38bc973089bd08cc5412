extends RefCounted
## Composed south frontages for ordinary procedural homes, shops, passages and
## workshops in every city segment. Each visible south wall run becomes one
## continuous wall field from the modular facade kit (assets/world/facades/v1),
## with doorway, window, quoin and fitting modules placed around the actual
## doors and varied by usage and the building's stable visual seed. Presentation
## only: no collision, encounters, rewards or generator RNG are touched, and the
## physical doorway span stays exactly the carver's opening.
##
## Coverage contract: visible pieces never overlap (modules are opaque
## polygons composited over their family's wall tile and cut from the wall
## field), so the roof cutaway fades each pixel once. Actor cover comes from a
## few coverage-only rectangles per run (the run minus each walkable door
## column, threshold and arch interior included), which keeps WorldCover's
## per-frame face count small and adds no foreground alpha layers.

const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const SOLID_GROUP := &"foreground_solid_occluders"
const GROUND_META := &"foreground_ground_contact"
const WALL_SHADER := preload("res://scenes/world/buildings/facade_wall.gdshader")
const MODULE_SHADER := preload("res://scenes/world/buildings/facade_module.gdshader")
const COVERAGE_SHADER := preload("res://scenes/world/buildings/facade_coverage.gdshader")
const BASE_FRACTION := 0.18
const BASE_STRENGTH := 0.14
const ROOT := "res://assets/world/facades/v1/"
const LANTERN := "res://assets/world/city_block/wall_lantern.png"
const PLINTH_PX := 22.0
const EAVE_SHADE_PX := 28.0
## South faces turn from the top-right sun: a little below the lit paving.
const FACE_LIGHT := Color(0.86, 0.85, 0.84)
## Opaque tile means (offline measurement) anchor the contrast pull.
const FAMILIES := {
	&"warm": {"tile": "facade_plaster_warm.png", "mean": Vector3(0.9202, 0.8140, 0.6577), "tint": Color(0.97, 0.95, 0.92), "contrast": 0.70},
	&"pale": {"tile": "facade_plaster_pale.png", "mean": Vector3(0.8063, 0.7333, 0.6453), "tint": Color(1.0, 1.0, 1.0), "contrast": 0.55},
}
## Door frames are split offline into frame and opening art. The frame is drawn
## as opaque wall modules around the walkable opening (below the spring line);
## the opening with its inward leaves and lit floor stays an uncovered recess so
## actors standing in the doorway remain visible, as before.
const DOORS := {
	&"double": {"frame": "door_double_inward_frame.png", "inside": "door_double_inward_inside.png", "size": Vector2(768, 693), "opening": Rect2(150, 110, 468, 502), "spring": 110.0},
	&"arched": {"frame": "door_arched_inward_frame.png", "inside": "door_arched_inward_inside.png", "size": Vector2(768, 732), "opening": Rect2(180, 128, 416, 562), "spring": 300.0},
}
## World width of each wall module; its source aspect is always preserved.
const MODULES := {
	&"shutters": {"file": "window_closed_shutters.png", "size": Vector2(512, 462), "width": 74.0, "center": 0.52},
	&"flowers": {"file": "window_open_flowers.png", "size": Vector2(512, 386), "width": 82.0, "center": 0.50},
	&"small": {"file": "window_small_barred.png", "size": Vector2(384, 380), "width": 42.0, "center": 0.62},
	&"arched": {"file": "window_arched.png", "size": Vector2(262, 512), "width": 46.0, "center": 0.50},
	&"shopfront": {"file": "shopfront_open.png", "size": Vector2(640, 382), "width": 128.0, "center": 0.36},
	&"service": {"file": "wall_service_box.png", "size": Vector2(243, 384), "width": 34.0, "center": 0.30},
}
const QUOIN := {"file": "quoin_strip.png", "size": Vector2(124, 640)}
const IVY := {"file": "ivy_climber.png", "size": Vector2(245, 640)}

static var _cache: Dictionary = {}
static var _materials: Dictionary = {}
static var _coverage_material: ShaderMaterial
static var _white: ImageTexture

## True for buildings this composer owns. Civic arcades and the reviewed S3
## guard loggia keep their own authored frontages.
static func owns(kit: Node2D) -> bool:
	if bool(kit.get("civic")): return false
	return StringName(kit.get("_district_profile").get("profile_id", &"")) != &"checkpoint_guard_loggia"

## Stable material family. Slate-roofed houses get pale ashlar, clay-roofed
## houses warm lime plaster: one masonry vocabulary in two local stones.
static func family_for(kit: Node2D) -> StringName:
	return &"pale" if StringName(kit.get_meta(&"city_roof_material", &"clay")) == &"slate" else &"warm"

## One visible south wall run: x span, wall base (bottom) and height, all in the
## kit's local pixels. `corners` marks which run ends are outer building corners.
static func compose_run(group: Node2D, kit: Node2D, run: Vector2, bottom: float, height: float, ground_y: float, doors: Array, cell_px: int, corners: Vector2i = Vector2i.ONE) -> void:
	if run.y - run.x < 24.0 or height < 48.0: return
	var usage := StringName(kit.get_meta(&"building_usage", &"row_house"))
	var seed_value := int(kit.get("_district_profile").get("visual_seed", int(kit.get("bounds").position.x) * 31 + int(kit.get("bounds").position.y)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, int(run.x), int(bottom)])
	var family := family_for(kit)
	var top := bottom - height
	var ground := Vector2((run.x + run.y) * 0.5, ground_y)
	var cuts: Array[Rect2] = []
	var blocked: Array[Vector2] = []
	var walkways: Array[Rect2] = []
	var frames: Array[Rect2] = []
	# Doorways first: their frames own their wall area outright.
	for door: Dictionary in doors:
		if door.get("dir") != Vector2i.DOWN: continue
		var gap := door_box(door, cell_px)
		if gap.end.x <= run.x or gap.position.x >= run.y or not is_equal_approx(gap.end.y, ground_y): continue
		var style: StringName = &"arched" if usage == &"passage" else &"double"
		# A doorway beside a building corner keeps its frame on this wall.
		var placed := _door(group, family, style, gap, bottom, height, ground, Vector2(run.x - 16.0, run.y + 16.0))
		var frame: Rect2 = placed.frame
		cuts.append(frame)
		walkways.append(placed.walkway)
		frames.append(frame)
		blocked.append(Vector2(frame.position.x - 10.0, frame.end.x + 10.0))
	# Quoins dress only outer corners, never over a doorway or on a stub run.
	var quoin_size: Vector2 = QUOIN.size
	var quoin_h: float = height - 6.0 - PLINTH_PX
	var quoin_w: float = quoin_h * quoin_size.x / quoin_size.y
	var room := run.y - run.x >= quoin_w * 2.0 + 40.0
	for side: int in 2:
		if (corners.x if side == 0 else corners.y) == 0 or not room: continue
		var rect := Rect2(run.x if side == 0 else run.y - quoin_w, top + 6.0, quoin_w, quoin_h)
		if cuts.any(func(cut: Rect2) -> bool: return cut.intersects(rect)): continue
		cuts.append(_module(group, family, QUOIN.file, rect, side == 1, &"quoin", Rect2(), bottom, height))
		blocked.append(Vector2(rect.position.x - 6.0, rect.end.x + 6.0))
	# Some homes carry a climbing vine at one end of a free wall stretch.
	var spans := _free_spans(run, blocked)
	if usage == &"row_house" and rng.randf() < 0.55 and not spans.is_empty():
		var host: Vector2 = spans[rng.randi_range(0, spans.size() - 1)]
		var ivy_h: float = (height - PLINTH_PX) * rng.randf_range(0.70, 0.92)
		var ivy_size: Vector2 = IVY.size
		var ivy_w: float = ivy_h * ivy_size.x / ivy_size.y
		if host.y - host.x >= ivy_w + 60.0:
			var at: float = host.x + 6.0 if rng.randf() < 0.5 else host.y - ivy_w - 6.0
			cuts.append(_module(group, family, IVY.file, Rect2(at, bottom - PLINTH_PX - ivy_h, ivy_w, ivy_h), rng.randf() < 0.5, &"vine", Rect2(), bottom, height))
			blocked.append(Vector2(at - 8.0, at + ivy_w + 8.0))
			spans = _free_spans(run, blocked)
	# Window rhythm across each free span, chosen by use.
	for span: Vector2 in spans:
		cuts.append_array(_fill_span(group, family, usage, span, bottom, height, rng))
	_wall_field(group, family, Rect2(run.x, top, run.y - run.x, height), cuts)
	_plinth(group, Rect2(run.x, bottom - PLINTH_PX, run.y - run.x, PLINTH_PX), cuts)
	# Cover the wall's height over its run, widened to any doorway frame that
	# reaches into a corner zone; never below the wall base (the street).
	var cover_span := run
	for frame: Rect2 in frames: cover_span = Vector2(minf(cover_span.x, frame.position.x), maxf(cover_span.y, frame.end.x))
	var covered := Rect2(cover_span.x, top, cover_span.y - cover_span.x, height)
	_coverage(group, covered, walkways, ground)
	# A lantern at some doors; a broad eave shade over the whole run.
	for door: Dictionary in doors:
		if door.get("dir") != Vector2i.DOWN or (usage == &"row_house" and rng.randf() < 0.5): continue
		var gap := door_box(door, cell_px)
		if gap.end.x <= run.x or gap.position.x >= run.y: continue
		var x := gap.end.x + 34.0 if rng.randf() < 0.5 else gap.position.x - 34.0
		if x < run.x + quoin_w + 12.0 or x > run.y - quoin_w - 12.0: continue
		var lamp_h := 46.0
		var lamp_w := lamp_h * 1086.0 / 1448.0
		var lamp := _sprite(group, LANTERN, Rect2(x - lamp_w * 0.5, bottom - height * 0.72, lamp_w, lamp_h), false)
		if lamp != null:
			lamp.name = "FacadeLantern"
			# The shared lantern source has no mipmaps.
			lamp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		break
	_eave_shade(group, Rect2(run.x, top, run.y - run.x, EAVE_SHADE_PX))

static func door_box(door: Dictionary, cell_px: int) -> Rect2:
	var dir: Vector2i = door.dir
	var perp := Vector2i(-dir.y, dir.x)
	var width := int(door.get("width", 2))
	var first: Vector2i = door.pos + perp * -(width >> 1)
	var last := first + perp * (width - 1)
	return Rect2(Vector2(first) * cell_px, Vector2.ONE * cell_px).merge(Rect2(Vector2(last) * cell_px, Vector2.ONE * cell_px))

static func _door(group: Node2D, family: StringName, style: StringName, gap: Rect2, bottom: float, height: float, ground: Vector2, limit: Vector2) -> Dictionary:
	var spec: Dictionary = DOORS[style]
	var opening: Rect2 = spec.opening
	var source_size: Vector2 = spec.size
	# Opening edges land exactly on the physical gap. A doorway that would rise
	# above its wall (low irregular walls, wide doors) compresses vertically.
	var scale := Vector2.ONE * (gap.size.x / opening.size.x)
	scale.y = minf(scale.y, (height + 6.0) / source_size.y)
	var size: Vector2 = source_size * scale
	# The threshold sits on the wall base so the step reads flush with the street.
	var rect := Rect2(Vector2(gap.position.x - opening.position.x * scale.x, bottom + 4.0 - size.y), size)
	# Frame pieces around the walkable opening (below the spring line) are
	# opaque wall modules; an arch's intrados belongs to the top piece and is
	# then painted over by the opening art. The threshold keeps its own alpha.
	var walk := Rect2(opening.position.x, float(spec.spring), opening.size.x, opening.end.y - float(spec.spring))
	var drawn := Rect2()
	for region: Rect2 in [
		Rect2(0, 0, walk.position.x, source_size.y),
		Rect2(walk.end.x, 0, source_size.x - walk.end.x, source_size.y),
		Rect2(walk.position.x, 0, walk.size.x, walk.position.y),
		Rect2(walk.position.x, walk.end.y, walk.size.x, source_size.y - walk.end.y),
	]:
		# Crop to this wall's extent (a jamb never hangs past a corner).
		var target := Rect2(rect.position + region.position * scale, region.size * scale)
		var left := maxf(target.position.x, limit.x)
		var right := minf(target.end.x, limit.y)
		if right - left < 1.0: continue
		region = Rect2(region.position.x + (left - target.position.x) / scale.x, region.position.y, (right - left) / scale.x, region.size.y)
		target = Rect2(left, target.position.y, right - left, target.size.y)
		if not region.has_area(): continue
		var threshold := region.position.y >= walk.end.y
		var piece := _module(group, family, spec.frame, target, false, &"door_threshold" if threshold else &"door_frame", region, bottom, height, not threshold)
		if not piece.has_area(): continue
		group.get_child(-1).name = "FacadeThreshold" if threshold else "FacadeDoorFrame"
		drawn = piece if not drawn.has_area() else drawn.merge(piece)
	var inside := _sprite(group, ROOT + spec.inside, rect, false)
	if inside != null:
		inside.name = "FacadeDoorOpening"
		inside.set_meta(&"facade_door_opening", Rect2(rect.position + walk.position * scale, walk.size * scale))
		# The opening art shares the frame's crop at a corner.
		var crop_left := maxf(0.0, limit.x - rect.position.x)
		var crop_right := maxf(0.0, rect.end.x - limit.y)
		if crop_left > 0.0 or crop_right > 0.0:
			inside.region_enabled = true
			inside.region_rect = Rect2(crop_left / scale.x, 0.0, (rect.size.x - crop_left - crop_right) / scale.x, source_size.y)
			inside.position.x += crop_left
	# The walkable column stays uncovered from the opening's head (the arch
	# crown) down to the street, threshold included.
	var head := rect.position.y + opening.position.y * scale.y
	return {"frame": drawn if drawn.has_area() else rect.intersection(Rect2(limit.x, rect.position.y, limit.y - limit.x, rect.size.y)), "walkway": Rect2(gap.position.x, head, gap.size.x, ground.y + 16.0 - head)}

## A wall module: its texture composited over the family wall (opaque), or
## drawn with its own alpha (thresholds). Visible only; coverage is separate.
static func _module(group: Node2D, family: StringName, file: String, rect: Rect2, flip: bool, kind: StringName, region: Rect2 = Rect2(), bottom: float = 0.0, height: float = 0.0, composite: bool = true) -> Rect2:
	var texture := _texture(ROOT + file)
	if texture == null: return Rect2()
	var shape := _panel(group, rect, FACE_LIGHT)
	if shape == null: return Rect2()
	shape.name = "FacadeModule"
	shape.texture = texture
	shape.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if composite: shape.material = _family_material(family, true)
	var source := region if region.has_area() else Rect2(Vector2.ZERO, texture.get_size())
	var left := source.end.x if flip else source.position.x
	var right := source.position.x if flip else source.end.x
	shape.uv = PackedVector2Array([Vector2(left, source.position.y), Vector2(right, source.position.y), Vector2(right, source.end.y), Vector2(left, source.end.y)])
	if composite and height > 0.0:
		# Same contact shade above the plinth as the wall field around it.
		var colors := PackedColorArray()
		for point: Vector2 in shape.polygon:
			var v := clampf((point.y - (bottom - height)) / (height - PLINTH_PX), 0.0, 1.0)
			var shade := 1.0 - BASE_STRENGTH * smoothstep(1.0 - BASE_FRACTION, 1.0, v)
			colors.append(Color(FACE_LIGHT.r * shade, FACE_LIGHT.g * shade, FACE_LIGHT.b * shade))
		shape.vertex_colors = colors
	shape.set_meta(&"facade_module", kind)
	return rect

## Coverage-only faces: the run's opaque area minus every walkable doorway column.
static func _coverage(group: Node2D, rect: Rect2, walkways: Array[Rect2], ground: Vector2) -> void:
	var pieces: Array[Rect2] = [rect]
	for walkway: Rect2 in walkways:
		var next: Array[Rect2] = []
		for piece: Rect2 in pieces: next.append_array(subtract_rect(piece, walkway))
		pieces = next
	if _coverage_material == null:
		_coverage_material = ShaderMaterial.new()
		_coverage_material.shader = COVERAGE_SHADER
	for piece: Rect2 in pieces:
		var face := _panel(group, piece, Color.WHITE)
		if face == null: continue
		face.name = "FacadeCoverage"
		face.material = _coverage_material
		face.set_meta(&"facade_coverage", piece)
		_register_solid(face, ground)

static func _wall_field(group: Node2D, family: StringName, rect: Rect2, cuts: Array[Rect2]) -> void:
	var pieces: Array[Rect2] = [Rect2(rect.position, Vector2(rect.size.x, rect.size.y - PLINTH_PX))]
	for cut: Rect2 in cuts:
		var next: Array[Rect2] = []
		for piece: Rect2 in pieces: next.append_array(subtract_rect(piece, cut))
		pieces = next
	for piece: Rect2 in pieces:
		var field := _panel(group, piece, FACE_LIGHT)
		if field == null: continue
		field.name = "FacadeWallField"
		field.material = _family_material(family, false)
		# A 1x1 texture keeps polygon UVs unnormalised: UV.y is the 0..1 height.
		field.texture = _white_texture()
		var uv := PackedVector2Array()
		for point: Vector2 in field.polygon:
			uv.append(Vector2((point.x - rect.position.x) / rect.size.x, (point.y - rect.position.y) / (rect.size.y - PLINTH_PX)))
		field.uv = uv
		field.set_meta(&"facade_wall_field", rect)
		# Modules were placed first to find their cut-outs; the wall draws beneath.
		group.move_child(field, 0)

static func _plinth(group: Node2D, rect: Rect2, cuts: Array[Rect2]) -> void:
	var texture := _texture(ROOT + "facade_plinth.png")
	if texture == null: return
	var pieces: Array[Rect2] = [rect]
	for cut: Rect2 in cuts:
		var next: Array[Rect2] = []
		for piece: Rect2 in pieces: next.append_array(subtract_rect(piece, cut))
		pieces = next
	for piece: Rect2 in pieces:
		var plinth := _panel(group, piece, Color(0.80, 0.79, 0.77))
		if plinth == null: continue
		plinth.name = "FacadePlinth"
		plinth.texture = texture
		plinth.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		plinth.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var texels := float(texture.get_height()) / rect.size.y
		var uv := PackedVector2Array()
		for point: Vector2 in plinth.polygon:
			uv.append(Vector2(point.x * texels, (point.y - rect.position.y) * texels))
		plinth.uv = uv
		plinth.set_meta(&"facade_plinth", rect)
		group.move_child(plinth, 0)

static func _fill_span(group: Node2D, family: StringName, usage: StringName, span: Vector2, bottom: float, height: float, rng: RandomNumberGenerator) -> Array[Rect2]:
	var cuts: Array[Rect2] = []
	var width := span.y - span.x
	var kinds: Array[StringName] = []
	match usage:
		&"shop":
			kinds = [&"shopfront", &"flowers", &"shutters"]
		&"workshop":
			kinds = [&"small", &"shutters", &"service"]
		&"passage":
			kinds = [&"small", &"arched", &"shutters"]
		_:
			kinds = [&"shutters", &"flowers", &"shutters", &"small"]
	if height >= 230.0 and usage != &"shop": kinds.push_front(&"arched")
	var placed: Array[Dictionary] = []
	var cursor := span.x + 16.0
	for _attempt: int in 12:
		var kind: StringName = kinds[rng.randi_range(0, kinds.size() - 1)]
		# Shopfronts open onto the street once; services stay occasional.
		if kind == &"shopfront" and placed.any(func(item: Dictionary) -> bool: return item.kind == &"shopfront"): kind = &"shutters"
		if kind == &"service" and placed.any(func(item: Dictionary) -> bool: return item.kind == &"service"): kind = &"small"
		var w: float = minf(float(MODULES[kind].width), height * 0.62)
		if cursor + w > span.y - 16.0:
			# Try a narrow module before giving up on the remaining wall.
			var small_w: float = MODULES[&"small"].width
			if kind == &"small" or cursor + small_w > span.y - 16.0: break
			kind = &"small"
			w = small_w
		placed.append({"kind": kind, "x": cursor, "w": w})
		cursor += w + rng.randf_range(34.0, 58.0)
	if placed.is_empty(): return cuts
	# Centre the rhythm in its span so walls never pile modules at one end.
	var used: float = float(placed[-1].x) + float(placed[-1].w) - float(placed[0].x)
	var shift: float = (span.x + (width - used) * 0.5) - float(placed[0].x)
	for item: Dictionary in placed:
		var spec: Dictionary = MODULES[item.kind]
		var size: Vector2 = spec.size * (float(item.w) / spec.size.x)
		var center_y := bottom - PLINTH_PX - (height - PLINTH_PX) * float(spec.center)
		if item.kind == &"shopfront": center_y = bottom - PLINTH_PX - 6.0 - size.y * 0.5
		if item.kind == &"service": center_y = bottom - PLINTH_PX - 8.0 - size.y * 0.5
		var rect := Rect2(Vector2(float(item.x) + shift, center_y - size.y * 0.5), size)
		cuts.append(_module(group, family, spec.file, rect, item.kind == &"service" and rng.randf() < 0.5, item.kind, Rect2(), bottom, height))
	return cuts

static func _eave_shade(group: Node2D, rect: Rect2) -> void:
	var shade := Polygon2D.new()
	shade.name = "FacadeEaveShade"
	shade.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var dark := Color(0.10, 0.09, 0.10, 0.42)
	shade.vertex_colors = PackedColorArray([dark, dark, Color(dark, 0.0), Color(dark, 0.0)])
	group.add_child(shade)

static func _free_spans(run: Vector2, blocked: Array[Vector2]) -> Array[Vector2]:
	var spans: Array[Vector2] = [run]
	for cut: Vector2 in blocked:
		var next: Array[Vector2] = []
		for span: Vector2 in spans:
			if cut.y <= span.x or cut.x >= span.y:
				next.append(span)
				continue
			if cut.x > span.x: next.append(Vector2(span.x, cut.x))
			if cut.y < span.y: next.append(Vector2(cut.y, span.y))
		spans = next
	var result: Array[Vector2] = []
	for span: Vector2 in spans:
		if span.y - span.x >= 40.0: result.append(span)
	return result

static func subtract_rect(field: Rect2, cut: Rect2) -> Array[Rect2]:
	var overlap := field.intersection(cut)
	if not overlap.has_area(): return [field]
	var pieces: Array[Rect2] = []
	for piece: Rect2 in [
		Rect2(field.position, Vector2(overlap.position.x - field.position.x, field.size.y)),
		Rect2(Vector2(overlap.end.x, field.position.y), Vector2(field.end.x - overlap.end.x, field.size.y)),
		Rect2(Vector2(overlap.position.x, field.position.y), Vector2(overlap.size.x, overlap.position.y - field.position.y)),
		Rect2(Vector2(overlap.position.x, overlap.end.y), Vector2(overlap.size.x, field.end.y - overlap.end.y)),
	]:
		if piece.has_area(): pieces.append(piece)
	return pieces

static func _family_material(family: StringName, module: bool) -> ShaderMaterial:
	var key := String(family) + (":module" if module else ":wall")
	if _materials.has(key): return _materials[key]
	var spec: Dictionary = FAMILIES[family]
	var material := ShaderMaterial.new()
	material.shader = MODULE_SHADER if module else WALL_SHADER
	material.set_shader_parameter("wall_tex", _texture(ROOT + spec.tile))
	material.set_shader_parameter("tile_mean", spec.mean)
	material.set_shader_parameter("tint", Vector3(spec.tint.r, spec.tint.g, spec.tint.b))
	material.set_shader_parameter("contrast", spec.contrast)
	_materials[key] = material
	return material

static func _white_texture() -> ImageTexture:
	if _white == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(image)
	return _white

static func _sprite(group: Node2D, path: String, rect: Rect2, flip: bool) -> Sprite2D:
	var texture := _texture(path)
	if texture == null: return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.flip_h = flip
	sprite.position = rect.position
	sprite.scale = rect.size / texture.get_size()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.modulate = FACE_LIGHT
	group.add_child(sprite)
	return sprite

static func _panel(parent: Node2D, rect: Rect2, color: Color) -> Polygon2D:
	if not rect.has_area(): return null
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	shape.color = color
	parent.add_child(shape)
	return shape

static func _register_solid(shape: Polygon2D, ground_parent_local: Vector2) -> void:
	shape.set_meta(GROUND_META, ground_parent_local)
	shape.add_to_group(SOLID_GROUP)

static func _texture(path: String) -> Texture2D:
	if _cache.has(path): return _cache[path]
	var texture: Texture2D
	if ResourceLoader.exists(path, "Texture2D"):
		texture = load(path) as Texture2D
	else:
		var pixels := Image.load_from_file(path)
		if pixels != null and not pixels.is_empty():
			pixels.generate_mipmaps()
			texture = ImageTexture.create_from_image(pixels)
	if texture != null: _cache[path] = texture
	return texture
