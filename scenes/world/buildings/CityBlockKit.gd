extends Node2D
## First playable block dressing. All coordinates come from the real parcel;
## this node owns no collision, encounters, rewards, or random generator state.

const ART := preload("res://core/systems/world/WorldArt.gd")
const ROOT := "res://assets/world/city_block/"
const GUARD_ROOT := "res://assets/world/districts/checkpoint_lanes/"
const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const FOOTPRINT_GEOMETRY := preload("res://scenes/world/buildings/CityFootprintGeometry.gd")
const COMPOSER := preload("res://scenes/world/buildings/CityFacadeComposer.gd")
## Share of ordinary houses roofed in slate (pale ashlar walls) per district;
## the rest keep clay over warm plaster. Civic halls are always slate.
const SLATE_SHARE := {
	&"service_courtyards": 0.30, &"checkpoint_lanes": 0.55, &"collapsed_ward": 0.35,
	&"civilian_cutthrough": 0.25, &"inner_district_gate": 0.60, &"industrial_cutthrough": 0.50,
	&"ruined_services": 0.40, &"underpass_veins": 0.55, &"canal_services": 0.45,
	&"rail_yard": 0.50, &"military_staging": 0.60, &"outer_wall": 0.45,
	&"siege_services": 0.50, &"gate_district": 0.65,
}
var bounds := Rect2()
var _cell_px := 64
var civic := false
var _door_x := 0.0
var _door_width := 128.0
var _front := 0.0
var _roof: RoofOverlay
var _records_board: Node2D
var _facade: Texture2D
var _south_front := false
var _facade_alpha := 1.0
var _facade_height := 116.0
var composed_street_area := Rect2()
var _street_h := Rect2()
var _street_v := Rect2()
var _chunk_extent := Vector2.ZERO
var _painted_planter := false
var _painted_lantern := false
var _lamp_light := Vector2.ZERO
var _awning_cast := Rect2()
var _doors: Array = []
var _irregular := false
var _district_profile: Dictionary = {}
static var preview_original_materials := false
static var _texture_cache: Dictionary = {}

static func enabled_for(_role: StringName, segment: int) -> bool:
	# Ordinary procedural architecture shares the accepted civic/domestic kit.
	# Authored Institution and Hub architecture have separate ownership.
	return not preview_original_materials and segment >= 2

func configure(rect: Rect2i, cell_px: int, doors: Array, roof: RoofOverlay, is_civic: bool, irregular_outline: PackedVector2Array = PackedVector2Array(), shared_ground: bool = false, visual_profile: Dictionary = {}) -> void:
	bounds = Rect2(Vector2(rect.position) * cell_px, Vector2(rect.size) * cell_px)
	_cell_px = cell_px
	civic = is_civic
	_district_profile = visual_profile.duplicate()
	set_meta(&"building_usage",StringName(visual_profile.get("building_usage",&"")))
	if not civic:
		for profile_key: String in ["profile_id", "roof_form_set_id", "facade_form_set_id"]:
			_district_profile[profile_key] = &"common_base"
	set_meta(&"district_visual_profile", StringName(_district_profile.get("profile_id", &"common_base")))
	_facade_height = 184.0 if civic else 148.0
	if _is_guard(): _facade_height = 192.0
	_roof = roof
	_doors = doors
	_irregular = not irregular_outline.is_empty()
	if _irregular: _facade_height = 112.0
	# The reviewed S2 street benchmark's wall/entry mass now applies to every
	# ordinary city segment; only the S3 guard loggia keeps its own proportions.
	if not _is_guard():
		_facade_height = (240.0 if civic else 208.0) if not _irregular else 176.0
		# A side (east/west) doorway near the front must stay visible below
		# the south facade's eave.
		for door: Dictionary in doors:
			var dir: Vector2i = door.get("dir", Vector2i.ZERO)
			if dir.x == 0: continue
			var side := COMPOSER.door_box(door,cell_px)
			_facade_height = minf(_facade_height,maxf(96.0,bounds.end.y-16.0-side.end.y))
	set_meta(&"city_roof_material", &"slate" if civic or _slate_roof() else &"clay")
	if _irregular: set_meta(&"city_irregular_outline", irregular_outline)
	add_to_group(&"city_block_building")
	set_meta(&"city_role", &"civic" if civic else &"residential")
	set_meta(&"footprint_cells", rect)
	z_index = -2
	# The visible south wall has height regardless of which wall has a door.
	# A closed window/arcade run replaces the painted entrance on other sides.
	var south := false
	for door: Dictionary in doors:
		if door.get("dir") == Vector2i.DOWN:
			var pos: Vector2i = door.pos
			_door_width = float(door.get("width", 2) * cell_px)
			var width := int(door.get("width", 2))
			_door_x = (float(pos.x) + 0.5 - (float(width - 1) * 0.5 - float(width >> 1))) * cell_px
			south = true
	_front = bounds.end.y - cell_px * 0.25
	if south:
		_south_front = true
	_facade = _texture("civic_arcade.png" if civic else "house_front.png")
	if not _irregular and not _is_guard(): _add_facade_faces(bounds.end.y)
	if roof != null:
		roof.cover_alpha_changed.connect(_on_roof_alpha)
		var roof_profile := _district_profile.duplicate()
		if _is_guard(): roof_profile["infill_texture"] = _texture(GUARD_ROOT+"guard_quiet_infill_v2.png")
		var slate := StringName(get_meta(&"city_roof_material")) == &"slate"
		roof_profile["roof_material"] = &"slate" if slate else &"clay"
		roof.apply_city_material(_texture("slate.png" if slate else "clay.png"), civic, _facade_height - ChunkBlockVisualCatalog.KIT_HEIGHT, not _irregular,roof_profile)
		if civic and not _irregular and not _is_guard():
			var plant := Sprite2D.new()
			plant.set_meta(&"district_optional_detail",true)
			plant.texture = _texture("pressure_plant.png")
			plant.scale = Vector2.ONE * ((96.0 if Global.attempt_segment == 2 else 64.0) / plant.texture.get_width())
			var roof_poly := roof.get_node("RoofPoly") as Polygon2D
			var plant_x := bounds.end.x-28
			for door: Dictionary in doors:
				if door.dir == Vector2i.RIGHT: plant_x = bounds.position.x+28
			plant.position = Vector2(plant_x-10 if Global.attempt_segment == 2 else plant_x, _front - 84 if Global.attempt_segment == 2 else _front - 78) - roof_poly.position
			roof_poly.add_child(plant)
	if not shared_ground: _add_frontage_ground()
	_add_ground_shadow()
	if not _irregular: _add_interior_floor(cell_px)
	if not _irregular: _add_entry_ground()
	if not _irregular:
		_add_records_board(cell_px, doors)
		_add_planting()
	elif Global.attempt_segment == 2 and StringName(_district_profile.get("building_usage",&"")) == &"row_house" and Geometry2D.is_point_in_polygon(Vector2(bounds.position.x+24,_front-8),irregular_outline):
		_add_planting()
	if _is_guard() and roof != null:
		preload("res://scenes/world/buildings/CheckpointOfficeForms.gd").compose_frontage(self,roof.get_meta(&"district_form_plan",{}),{"arch_open":_texture(GUARD_ROOT+"guard_arch_open.png"),"arch_closed":_texture(GUARD_ROOT+"guard_arch_closed.png"),"infill":_texture(GUARD_ROOT+"guard_quiet_infill_v2.png")})
	else:
		preload("res://scenes/world/buildings/CityBlockFrontages.gd").compose(self, doors, cell_px, irregular_outline, _texture("wall_lantern.png") if civic else null, _texture("house_front.png") if _irregular else null)
	if not _irregular: _add_frontage_details()
	if _is_guard():
		for detail: Node in get_children():
			if detail.name in [&"PaintedEntryLantern",&"PaintedCornerPlanter",&"CityTemperateTree",&"CityFoliageShadow"]: detail.set_meta(&"district_optional_detail",true)
		if _records_board != null: _records_board.set_meta(&"district_optional_detail",true)
	queue_redraw()

## Exact chunk-local use/footprint context for the shared ground's presentation.
## Noncivic is not sufficient: workshops and passages must retain rough ground.
func ground_care_spec() -> Dictionary:
	var seed_value: int = int(_district_profile.get("visual_seed",0))
	if Global.attempt_segment != 2 or civic or StringName(_district_profile.get("building_usage",&"")) != &"row_house" or absi(seed_value)%4 == 3:
		return {}
	if _roof == null or not is_instance_valid(_roof) or _roof.footprint_outline_px.size() < 3 or _doors.is_empty():
		return {}
	var spec := {"footprint_px":_roof.footprint_outline_px.duplicate(),"doors":_doors.duplicate(true),"visual_seed":seed_value}
	for child: Node in get_children():
		if child.name == &"DomesticHerbBed" and child.has_meta(&"city_garden_contact"):
			spec["garden_contact_px"] = child.get_meta(&"city_garden_contact")
			break
		if child.name == &"CityTemperateTree" and child.has_meta(&"city_ground_contact"):
			spec["garden_contact_px"] = child.get_meta(&"city_ground_contact")
	return spec


func _is_guard() -> bool:
	return StringName(_district_profile.get("profile_id",&"")) == &"checkpoint_guard_loggia"

func _slate_roof() -> bool:
	# Stable per building: the parcel's visual seed, never the generator RNG.
	var share: float = SLATE_SHARE.get(StringName(_district_profile.get("family_id",&"")),0.3)
	var seed_value := int(_district_profile.get("visual_seed",int(bounds.position.x)*7+int(bounds.position.y)))
	return float(posmod(hash(seed_value*2654435761),1000))/1000.0 < share

func _composed() -> bool:
	return not _irregular and COMPOSER.owns(self)

func _on_roof_alpha(alpha: float) -> void:
	_facade_alpha = alpha
	for child: Node in get_children():
		if child is CanvasItem and child.has_meta(&"city_facade_detail"): child.modulate.a = alpha
		if child is Polygon2D and child.has_meta(&"city_sun_shadow") and child.texture == null:
			child.modulate.a = 0.65+0.35*alpha
	queue_redraw()

func _add_ground_shadow() -> void:
	var offset := preload("res://core/systems/world/WorldDepthStyle.gd").offset_for_height(170.0 if civic else 126.0)
	var points := PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	var cast := points.duplicate()
	for point: Vector2 in points: cast.append(point+offset)
	var pieces: Array[PackedVector2Array] = Geometry2D.clip_polygons(Geometry2D.convex_hull(cast),points)
	if not _is_guard():
		pieces = FOOTPRINT_GEOMETRY.shadow(FOOTPRINT_GEOMETRY.outline_for(self),offset)
	for piece: PackedVector2Array in pieces:
		var shade := Polygon2D.new()
		shade.name = "CitySunShadow"
		shade.set_meta(&"city_sun_shadow",true)
		shade.polygon = piece
		shade.color = Color(0.10,0.15,0.20,0.21)
		shade.z_index = -90
		add_child(shade)

func _add_frontage_ground(area_override: Rect2 = Rect2()) -> void:
	var texture := _texture("paving.png")
	if texture == null: return
	# Parcel fixtures start with a local surround; the completed block replaces
	# these with one shared surface and a narrow, flush street boundary.
	var area := bounds.grow(92.0)
	area.size.y += 224.0
	if area_override.has_area(): area = area_override
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://scenes/world/buildings/city_ground.gdshader")
	surface.set_shader_parameter("area", Vector4(area.position.x, area.position.y, area.end.x, area.end.y))
	surface.set_shader_parameter("ground_origin", global_position)
	surface.set_shader_parameter("road_h", _road_vector(_street_h))
	surface.set_shader_parameter("road_v", _road_vector(_street_v))
	surface.set_shader_parameter("chunk_extent", _chunk_extent)
	surface.set_shader_parameter("limit_to_road", Global.attempt_segment == 2)
	surface.set_shader_parameter("plant_corner", Vector2(bounds.position.x+4,_front) if civic and _south_front else Vector2(-100000,-100000))
	surface.set_shader_parameter("road_texture", ART.ground_texture(2))
	if _has_texture("worn_setts.png"):
		surface.set_shader_parameter("road_texture",_texture("worn_setts.png"))
		surface.set_shader_parameter("road_source_tint",Vector3(0.87,0.93,0.96))
		surface.set_shader_parameter("road_mid",Vector3(0.49,0.52,0.51))
		surface.set_shader_parameter("road_contrast",0.30)
		surface.set_shader_parameter("road_repeat",272.0)
	surface.set_shader_parameter("grass_texture", ART.ground_texture(0))
	surface.set_shader_parameter("soil_texture", ART.ground_texture(1))
	area = area.grow(112.0)
	# Adjacent streamed chunks own their own interiors/materials. The local
	# subtraction below cannot safely paint beyond this generated chunk.
	if _chunk_extent.x > 0.0:
		area = area.intersection(Rect2(Vector2.ZERO,_chunk_extent))
	# Four broad strips exclude this room; the block pass subtracts all other
	# parcels. The indoor surface is owned separately below.
	for strip: Rect2 in [Rect2(area.position, Vector2(area.size.x, bounds.position.y-area.position.y)), Rect2(Vector2(area.position.x, bounds.end.y), Vector2(area.size.x, area.end.y-bounds.end.y)), Rect2(Vector2(area.position.x, bounds.position.y), Vector2(bounds.position.x-area.position.x, bounds.size.y)), Rect2(Vector2(bounds.end.x, bounds.position.y), Vector2(area.end.x-bounds.end.x, bounds.size.y))]:
		var paving := Polygon2D.new()
		paving.name = "QuietFrontagePaving"
		paving.set_meta(&"city_paving", true)
		paving.z_index = -92
		paving.polygon = PackedVector2Array([strip.position, Vector2(strip.end.x, strip.position.y), strip.end, Vector2(strip.position.x, strip.end.y)])
		paving.texture = texture
		paving.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		paving.texture_scale = Vector2.ONE * 3.5
		paving.material = surface
		add_child(paving)

static func _road_vector(rect: Rect2) -> Vector4:
	return Vector4(rect.position.x, rect.position.y, rect.end.x, rect.end.y) if rect.has_area() else Vector4.ZERO

func _add_interior_floor(cell_px: int) -> void:
	var interior_floor := Polygon2D.new()
	interior_floor.name = "CityInteriorFloor"
	var area := bounds.grow(-float(cell_px))
	interior_floor.polygon = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
	interior_floor.texture = _texture("paving.png")
	interior_floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	interior_floor.texture_scale = Vector2.ONE * 3.0
	interior_floor.color = Color(0.65, 0.71, 0.70)
	# Parent is -2: effective -93, above legacy indoor stamps at -94 in
	# both splat and non-splat rendering, still below walls and actors.
	interior_floor.z_index = -91
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://scenes/world/buildings/city_paving.gdshader")
	surface.set_shader_parameter("area", Vector4(area.position.x, area.position.y, area.end.x, area.end.y))
	surface.set_shader_parameter("edge_feather", 2.0)
	surface.set_shader_parameter("surface_contrast", 0.23)
	interior_floor.material = surface
	add_child(interior_floor)

func _add_entry_ground() -> void:
	if not _south_front: return
	var group := Node2D.new()
	group.name = "EntranceGround"
	group.z_index = -6
	group.set_meta(&"door_center", _door_x)
	add_child(group)
	var left := _door_x - _door_width * 0.5
	var right := _door_x + _door_width * 0.5
	# Shallow localized contact, with the real doorway left open. These are
	# flush surface marks, not a new step, blocking shape or street border.
	for span: Vector2 in [Vector2(bounds.position.x+16,left-6),Vector2(right+6,bounds.end.x-16)]:
		if span.y <= span.x: continue
		_flat(group, PackedVector2Array([Vector2(span.x,_front),Vector2(span.y,_front),Vector2(span.y-8,_front+20),Vector2(span.x-12,_front+20)]), Color(0.07,0.11,0.11,0.17))
		_flat(group, PackedVector2Array([Vector2(span.x-10,_front+15),Vector2(span.y-6,_front+15),Vector2(span.y-10,_front+29),Vector2(span.x-15,_front+29)]), Color(0.07,0.11,0.11,0.055))
	var depth := 49.0 if civic else 30.0
	var margin := 22.0 if civic else 10.0
	_flat(group, PackedVector2Array([Vector2(left-8,_front+4),Vector2(right+8,_front+4),Vector2(right+margin,_front+depth),Vector2(left-margin,_front+depth)]), Color(0.66,0.68,0.60,0.30))
	_flat(group, PackedVector2Array([Vector2(left+13,_front+8),Vector2(right-13,_front+8),Vector2(right-4,_front+depth-8),Vector2(left+4,_front+depth-8)]), Color(0.69,0.71,0.63,0.16))

func _add_records_board(cell_px: int, doors: Array) -> void:
	if not civic or _roof == null: return
	# This north-wall dressing is optional when generation carves an entrance
	# through that wall; never paint storage over a real traversable opening.
	for door: Dictionary in doors:
		if door.get("dir") == Vector2i.UP: return
	var group := Node2D.new()
	group.name = "CivicRecordsBoard"
	group.z_index = RoofOverlay.ROOF_Z
	var area := Rect2(bounds.get_center().x-cell_px*1.5,bounds.position.y+12,cell_px*3.0,42)
	group.set_meta(&"wall_bounds", area)
	# Interior corner fills are at -2. Share the roof's -1 draw layer but
	# precede its opaque polygon, so real paper faces show only in cutaway.
	_roof.add_child(group)
	_roof.move_child(group, 0)
	_records_board = group
	_panel(group, area, Color("3e4a41"))
	_panel(group, Rect2(area.position+Vector2(5,4),Vector2(area.size.x-10,3)), Color("858d77"))
	for index in range(2):
		var panel := Rect2(area.position+Vector2(7+index*(area.size.x-12)*0.5,9),Vector2((area.size.x-24)*0.5,25))
		var face := _panel(group,panel,Color("aaa78e") if index == 0 else Color("9e9e86"))
		face.set_meta(&"records_face",true)
		for row in range(2):
			_panel(group,Rect2(panel.position+Vector2(9,6+row*9),Vector2(panel.size.x-22-index*8,2.5)),Color("6a715e"))
	_panel(group, Rect2(area.position+Vector2(-3,35),Vector2(area.size.x+6,5)), Color("586456"))
	_panel(group, Rect2(area.position+Vector2(-3,40),Vector2(area.size.x+6,2)), Color("303f39"))

static func _flat(parent: Node2D, points: PackedVector2Array, color: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.polygon = points
	shape.color = color
	parent.add_child(shape)
	return shape

static func _panel(parent: Node2D, area: Rect2, color: Color) -> Polygon2D:
	return _flat(parent,PackedVector2Array([area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]),color)

static func compose_street(chunk: Node2D, footprints: Array[Rect2i], lane_h: Rect2i, lane_v: Rect2i, cell_px: int, chunk_cells: int = 32) -> void:
	if footprints.is_empty(): return
	var kits := []
	for child: Node in chunk.get_children():
		if child.is_in_group(&"city_block_building"): kits.append(child)
	if kits.is_empty(): return
	var hull := footprints[0]
	for footprint in footprints: hull = hull.merge(footprint)
	var area := Rect2(Vector2(hull.position-Vector2i.ONE)*cell_px, Vector2(hull.size+Vector2i(2,2))*cell_px)
	for lane: Rect2i in [lane_h,lane_v]:
		if lane.has_area(): area = area.merge(Rect2(Vector2(lane.position)*cell_px,Vector2(lane.size)*cell_px))
	for kit in kits:
		for child: Node in kit.get_children():
			if child.has_meta(&"city_paving"):
				kit.remove_child(child)
				child.queue_free()
		kit.set("composed_street_area", Rect2())
	var paving_owner: Node2D = kits[0]
	paving_owner.set("composed_street_area", area)
	paving_owner.set("_chunk_extent", Vector2.ONE*chunk_cells*cell_px)
	paving_owner.set("_street_h", Rect2(Vector2(lane_h.position)*cell_px, Vector2(lane_h.size)*cell_px))
	paving_owner.set("_street_v", Rect2(Vector2(lane_v.position)*cell_px, Vector2(lane_v.size)*cell_px))
	paving_owner.call("_add_frontage_ground", area)
	for kit in kits: kit.call("trim_paving", footprints, cell_px)
	paving_owner.queue_redraw()

func trim_paving(footprints: Array[Rect2i], cell_px: int) -> void:
	# Parcel composition knows all neighbours only after the frontage pass.
	# Subtract their real footprints so ground cannot paint a neighbour's room.
	var exact_cuts: Array[PackedVector2Array] = []
	if not _is_guard(): exact_cuts = FOOTPRINT_GEOMETRY.occupied_parts(get_parent(),footprints,cell_px)
	for child: Node in get_children():
		if not child is Polygon2D or not (child.has_meta(&"city_paving") or child.has_meta(&"city_sun_shadow")): continue
		var paving := child as Polygon2D
		if paving.has_meta(&"city_sun_shadow"):
			var shade_pieces: Array[PackedVector2Array] = [paving.polygon]
			if not _is_guard():
				shade_pieces = FOOTPRINT_GEOMETRY.difference(FOOTPRINT_GEOMETRY.convex_parts(paving.polygon),exact_cuts)
			else:
				for footprint: Rect2i in footprints:
					var cut := Rect2(Vector2(footprint.position)*cell_px,Vector2(footprint.size)*cell_px)
					var box := PackedVector2Array([cut.position,Vector2(cut.end.x,cut.position.y),cut.end,Vector2(cut.position.x,cut.end.y)])
					var remaining: Array[PackedVector2Array] = []
					for piece: PackedVector2Array in shade_pieces: remaining.append_array(Geometry2D.clip_polygons(piece,box))
					shade_pieces = remaining
			for piece: PackedVector2Array in shade_pieces:
				var shade := Polygon2D.new()
				shade.name = "CitySunShadow"
				shade.set_meta(&"city_sun_shadow",true)
				shade.polygon = piece
				shade.color = paving.color
				shade.z_index = paving.z_index
				shade.texture = paving.texture
				if not _is_guard(): shade.modulate = paving.modulate
				if paving.texture != null:
					var inverse: Transform2D = paving.get_meta(&"shadow_uv_transform")
					var uv_offset: Vector2 = paving.get_meta(&"shadow_uv_offset")
					var uv := PackedVector2Array()
					for point: Vector2 in piece: uv.append(inverse*point+uv_offset)
					shade.uv = uv
					shade.set_meta(&"shadow_uv_transform",inverse)
					shade.set_meta(&"shadow_uv_offset",uv_offset)
				add_child(shade)
			remove_child(paving)
			paving.queue_free()
			continue
		var rect := Rect2(paving.polygon[0], Vector2.ZERO)
		for point: Vector2 in paving.polygon: rect = rect.expand(point)
		var pieces: Array[Rect2] = [rect]
		for footprint in footprints:
			var cut := Rect2(Vector2(footprint.position)*cell_px, Vector2(footprint.size)*cell_px)
			var next: Array[Rect2] = []
			for piece in pieces:
				var overlap := piece.intersection(cut)
				if overlap.get_area() <= 0.0:
					next.append(piece)
					continue
				for remainder: Rect2 in [Rect2(piece.position, Vector2(piece.size.x, overlap.position.y-piece.position.y)), Rect2(Vector2(piece.position.x, overlap.end.y), Vector2(piece.size.x, piece.end.y-overlap.end.y)), Rect2(Vector2(piece.position.x, overlap.position.y), Vector2(overlap.position.x-piece.position.x, overlap.size.y)), Rect2(Vector2(overlap.end.x, overlap.position.y), Vector2(piece.end.x-overlap.end.x, overlap.size.y))]:
					if remainder.get_area() > 0: next.append(remainder)
			pieces = next
		for piece in pieces:
			var replacement := Polygon2D.new()
			replacement.name = "QuietFrontagePaving"
			replacement.set_meta(&"city_paving", true)
			replacement.z_index = paving.z_index
			replacement.texture = paving.texture
			replacement.texture_scale = paving.texture_scale
			replacement.texture_repeat = paving.texture_repeat
			replacement.material = paving.material
			replacement.polygon = PackedVector2Array([piece.position, Vector2(piece.end.x, piece.position.y), piece.end, Vector2(piece.position.x, piece.end.y)])
			add_child(replacement)
		remove_child(paving)
		paving.queue_free()

func _add_planting() -> void:
	# Small stable domestic groups join the public tree, without consuming
	# the parcel RNG or planting every doorway with the same finished object.
	var domestic_garden := not civic and Global.attempt_segment == 2 and StringName(_district_profile.get("building_usage",&"")) == &"row_house"
	var garden_variant := absi(int(_district_profile.get("visual_seed",int(bounds.position.x/64)+int(bounds.position.y/64)))) % 4
	if domestic_garden and garden_variant == 3: return
	if not civic and not domestic_garden and (int(bounds.position.x/64)+int(bounds.position.y/64)) % 3 != 0: return
	var texture := ART.dressing_texture(&"olive_shrub")
	if texture == null: return
	var tree: Texture2D = _texture("temperate_tree.png") if _has_texture("temperate_tree.png") else null
	if domestic_garden and garden_variant != 1: tree = null
	var tree_anchor := Vector2(650,1170)
	var tree_scale := 280.0/tree.get_width() if tree != null else 1.0
	if domestic_garden and garden_variant == 1:
		tree = _texture("res://assets/world/domestic_gardens/v1/fruit_tree_overhead_v2.png")
		tree_anchor = Vector2(660,1060)
		tree_scale = 135.0/1167.0
	var planter: Texture2D = _texture("planted_corner.png") if _has_texture("planted_corner.png") else null
	var planter_width := minf(160.0,_door_x-_door_width*0.5-bounds.position.x-24.0) if _south_front else 160.0
	if domestic_garden:
		planter_width = minf(planter_width,128.0)
		if _south_front and planter_width >= 80.0: _add_domestic_garden_bed(planter_width,garden_variant)
		planter = null
		if garden_variant != 1: return
	if planter != null and planter_width >= 80.0:
		var piece := Sprite2D.new()
		piece.name = "PaintedCornerPlanter"
		piece.texture = planter
		piece.scale = Vector2.ONE*(planter_width/planter.get_width())
		var foot := Vector2(bounds.position.x+8+planter_width*0.5,_front-3)
		piece.position = foot+(planter.get_size()*0.5-Vector2(800,870))*piece.scale
		piece.set_meta(&"city_ground_contact",foot)
		piece.z_index = 1
		add_child(piece)
		_painted_planter = true
	var anchor := Vector2(bounds.position.x + 4, _front - 30)
	var offsets := [Vector2(0,-38), Vector2(-22,18), Vector2(28,8)]
	for index in offsets.size():
		if domestic_garden and index > (0 if tree != null or _painted_planter else 1): continue
		if _painted_planter and index > 0: continue
		var source: Texture2D = tree if index == 0 and tree != null else texture
		var plant := Sprite2D.new()
		plant.texture = source
		plant.position = anchor + offsets[index]
		plant.scale = Vector2.ONE * (tree_scale if index == 0 and tree != null else ([60.0,44.0,36.0][index] if domestic_garden else [180.0,100.0,68.0][index])/source.get_width())
		var feet := plant.position+Vector2(0,source.get_height()*plant.scale.y*0.5)
		if index == 0 and tree != null:
			# Measured root contact in the original 1254-square transparent asset.
			# Keep its real foot on the existing blocked corner, not its canvas centre.
			feet = Vector2(bounds.position.x+8,_front-5)
			plant.position = feet+(source.get_size()*0.5-tree_anchor)*plant.scale
			plant.name = "CityTemperateTree"
			plant.set_meta(&"city_ground_contact",feet)
		plant.modulate = Color(1.04,1.08,0.99)
		plant.z_index = 1
		add_child(plant)
		if plant.name == &"CityTemperateTree":
			preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd").register(plant, feet)
		var projection := preload("res://core/systems/world/WorldDepthStyle.gd").project_transform(plant.transform,feet)
		var half := source.get_size()*0.5
		var uv := PackedVector2Array([Vector2.ZERO,Vector2(source.get_width(),0),source.get_size(),Vector2(0,source.get_height())])
		var points := PackedVector2Array()
		for pixel: Vector2 in uv: points.append(projection*(pixel-half))
		var shade := Polygon2D.new()
		shade.name = "CityFoliageShadow"
		shade.set_meta(&"city_sun_shadow",true)
		shade.set_meta(&"shadow_uv_transform",projection.affine_inverse())
		var region_offset := Vector2.ZERO
		var shadow_texture := source
		if source is AtlasTexture:
			region_offset = source.region.position
			shadow_texture = source.atlas
		shade.set_meta(&"shadow_uv_offset",half+region_offset)
		shade.polygon = points
		var atlas_uv := PackedVector2Array()
		for pixel: Vector2 in uv: atlas_uv.append(pixel+region_offset)
		shade.uv = atlas_uv
		shade.texture = shadow_texture
		shade.color = Color(0.06,0.10,0.13,0.25)
		shade.z_index = -90
		add_child(shade)

func _add_domestic_garden_bed(width: float, variant: int) -> void:
	# A trampled, flush herb/flower pocket at the inhabited edge. The root and
	# stone planter remain on the existing wall band; this soil owns no blocker.
	var left := bounds.position.x+10
	var front := _front+8
	var depth := 48.0 if variant == 0 else 72.0
	var bed := PackedVector2Array([Vector2(left,front),Vector2(left+width-14,front+3),Vector2(left+width,front+depth*0.52),Vector2(left+width-24,front+depth),Vector2(left+16,front+depth-9),Vector2(left-7,front+depth*0.42)])
	var soil := _flat(self,bed,Color("514b39"))
	soil.name = "TendedDomesticBed"
	soil.z_index = -90
	soil.set_meta(&"city_domestic_garden",variant)
	# A planted pocket sits in the same earth as the surrounding ground.
	# Feather its mesh edge instead of leaving an opaque flat polygon sticker.
	var center := Vector2.ZERO
	for point: Vector2 in bed: center += point
	center /= bed.size()
	var points := bed.duplicate()
	var colors := PackedColorArray()
	var faces: Array[PackedInt32Array] = []
	for point: Vector2 in bed:
		points.append(point.lerp(center,0.24))
		colors.append(Color(1,1,1,0))
	for index: int in bed.size(): colors.append(Color.WHITE)
	points.append(center)
	colors.append(Color.WHITE)
	for index: int in bed.size():
		var next := (index+1)%bed.size()
		faces.append(PackedInt32Array([index,next,next+bed.size(),index+bed.size()]))
		faces.append(PackedInt32Array([bed.size()*2,index+bed.size(),next+bed.size()]))
	soil.polygon = points
	soil.polygons = faces
	soil.vertex_colors = colors
	soil.texture = _texture("res://assets/world/ground/ground_dirt_01.png")
	soil.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	soil.color = Color(0.82,0.77,0.65)
	var soil_uv := PackedVector2Array()
	for point: Vector2 in points:
		soil_uv.append(to_global(point)*soil.texture.get_size()/300.0)
	soil.uv = soil_uv
	if variant != 1:
		var bed_sprite := Sprite2D.new()
		bed_sprite.name = "DomesticHerbBed"
		bed_sprite.texture = _texture("res://assets/world/domestic_gardens/v1/flower_herb_bed.png")
		bed_sprite.scale = Vector2.ONE*(minf(width,115.0)/1761.0)
		# Original art is reduced roughly fifteen-fold. Its mip chain keeps
		# fine leaves/stone from becoming isolated bright sampling speckles.
		bed_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		bed_sprite.modulate = Color(0.94,0.93,0.87)
		var contact := Vector2(left+width*0.5,front+22)
		bed_sprite.position = contact+(bed_sprite.texture.get_size()*0.5-Vector2(955,485))*bed_sprite.scale
		bed_sprite.z_index = 1
		bed_sprite.set_meta(&"city_garden_contact",contact)
		add_child(bed_sprite)
	for index in range(3 if variant == 2 else 2):
		var at := Vector2(left+22+index*width*0.24,front+depth*0.46+(index%2)*9)
		var herbs := _flat(self,PackedVector2Array([at-Vector2(9,5),at+Vector2(6,-8),at+Vector2(13,3),at+Vector2(-3,8)]),Color("737d53") if variant == 2 else Color("829365"))
		herbs.z_index = -89

func _add_frontage_details() -> void:
	if not _south_front: return
	var door_left := _door_x-_door_width*0.5
	if civic and _has_texture("wall_lantern.png"):
		var lamp := Sprite2D.new()
		lamp.name = "PaintedEntryLantern"
		lamp.texture = _texture("wall_lantern.png")
		lamp.scale = Vector2.ONE*(48.0/lamp.texture.get_height())
		var mount := Vector2(door_left-22,_front-80)
		lamp.position = mount+(lamp.texture.get_size()*0.5-Vector2(205,425))*lamp.scale
		lamp.z_index = 1
		lamp.modulate = Color(0.95,0.95,0.91)
		lamp.set_meta(&"city_facade_detail",true)
		add_child(lamp)
		_lamp_light = mount+(Vector2(630,980)-Vector2(205,425))*lamp.scale
		_painted_lantern = true
	elif not civic and not _composed() and _has_texture("domestic_awning.png"):
		var span := door_left-bounds.position.x-16.0
		if span < 104.0: return
		var awning := Sprite2D.new()
		awning.name = "PaintedDomesticAwning"
		awning.texture = _texture("domestic_awning.png")
		var width := minf(180.0,span-24.0)
		awning.scale = Vector2.ONE*(width/awning.texture.get_width())
		var mount := Vector2(bounds.position.x+16+span*0.5,_front-125)
		awning.position = mount+(awning.texture.get_size()*0.5-Vector2(768,150))*awning.scale
		awning.z_index = 1
		awning.set_meta(&"city_facade_detail",true)
		add_child(awning)
		_awning_cast = Rect2(mount.x-width*0.45,_front-70,width*0.90,32)

static func _has_texture(file: String) -> bool:
	# Imported/exported resources can be remapped even when their raw PNG
	# source is absent. Keep the source fallback for a fresh local import.
	return ResourceLoader.exists(ROOT+file,"Texture2D") or FileAccess.file_exists(ROOT+file)

static func _texture(file: String) -> Texture2D:
	if _texture_cache.has(file): return _texture_cache[file]
	var path := file if file.begins_with("res://") else ROOT+file
	var texture: Texture2D
	if ResourceLoader.exists(path, "Texture2D"):
		texture = load(path) as Texture2D
	else:
		var pixels := Image.load_from_file(path)
		texture = ImageTexture.create_from_image(pixels) if pixels != null and not pixels.is_empty() else null
	if texture != null: _texture_cache[file] = texture
	return texture

func _add_facade_faces(ground_y: float) -> void:
	if _facade == null: return
	# The former texture draw calls preceded every parent-drawn shadow and
	# service prop. Behind-parent sprites preserve that ordering and natural Z.
	var group := Node2D.new()
	group.name = "FacadeFaces"
	group.show_behind_parent = true
	group.set_meta(&"city_facade_detail",true)
	group.modulate.a = _facade_alpha
	add_child(group)
	if _composed():
		group.name = "ComposedFacade"
		COMPOSER.compose_run(group,self,Vector2(bounds.position.x+16.0,bounds.end.x-16.0),_front,_facade_height,ground_y,_doors,_cell_px)
		return
	var tex_size := _facade.get_size()
	if _south_front:
		var opening_left := 0.402 if civic else 0.425
		var opening_right := 0.598 if civic else 0.575
		var x0 := bounds.position.x+16.0
		var x1 := bounds.end.x-16.0
		var door_left := _door_x-_door_width*0.5
		var door_right := _door_x+_door_width*0.5
		var top := _front-_facade_height
		_facade_face(group,"FacadeLeft",Rect2(x0,top,door_left-x0,_facade_height),Rect2(0,0,tex_size.x*opening_left,tex_size.y),ground_y)
		_facade_face(group,"FacadeEntrance",Rect2(door_left,top,_door_width,_facade_height),Rect2(tex_size.x*opening_left,0,tex_size.x*(opening_right-opening_left),tex_size.y),ground_y)
		_facade_face(group,"FacadeRight",Rect2(door_right,top,x1-door_right,_facade_height),Rect2(tex_size.x*opening_right,0,tex_size.x*(1.0-opening_right),tex_size.y),ground_y)
	else:
		var source := Rect2(Vector2.ZERO,Vector2(tex_size.x*(0.39 if civic else 0.40),tex_size.y))
		var width := bounds.size.x-32.0
		var nominal := source.size.x/source.size.y*_facade_height
		var count := maxi(1,int(round(width/nominal)))
		var bay_width := width/count
		for index in count:
			var at := Vector2(bounds.position.x+16+index*bay_width,_front-_facade_height)
			_facade_face(group,"FacadeClosedBay",Rect2(at,Vector2(bay_width,_facade_height)),source,ground_y)

func _facade_face(parent: Node2D, face_name: String, target: Rect2, source: Rect2, ground_y: float) -> void:
	if not target.has_area() or not source.has_area(): return
	var face := Sprite2D.new()
	face.name = face_name
	face.texture = _facade
	face.region_enabled = true
	face.region_rect = source
	face.region_filter_clip_enabled = true
	face.centered = false
	face.position = target.position
	face.scale = target.size/source.size
	parent.add_child(face)
	FOREGROUND.register(face,Vector2(target.get_center().x,ground_y))

func _draw() -> void:
	if _is_guard(): return
	# Composed frontages carry their own eave shade, fittings and services.
	if _composed(): return
	if _facade != null and not _south_front and not _irregular:
		_draw_closed_frontage()
	if _facade != null and _south_front and not _irregular:
		# Slice into wings and entrance: generated opening is fitted to the
		# carver's exact two-cell gap, never used as a collision proxy.
		var door_left := _door_x - _door_width * 0.5
		var door_right := _door_x + _door_width * 0.5
		if _awning_cast.has_area():
			var awning_shadow := _awning_cast
			draw_polygon(PackedVector2Array([awning_shadow.position,Vector2(awning_shadow.end.x,awning_shadow.position.y),awning_shadow.end,Vector2(awning_shadow.position.x,awning_shadow.end.y)]),PackedColorArray([Color(0.08,0.14,0.16,0.22*_facade_alpha),Color(0.08,0.14,0.16,0.22*_facade_alpha),Color(0.08,0.14,0.16,0),Color(0.08,0.14,0.16,0)]))
		if civic:
			# Shaded soffit/jambs and a receding floor make the real opening a
			# volume, while actors continue drawing above this shallow frontage.
			var entry := PackedVector2Array()
			var shade_colors := PackedColorArray()
			for step in range(9):
				var angle := PI+PI*float(step)/8.0
				entry.append(Vector2(_door_x+cos(angle)*(_door_width-24)*0.5,_front-63+sin(angle)*50))
				shade_colors.append(Color(0.08,0.13,0.15,0.60*_facade_alpha))
			entry.append(Vector2(door_right-12,_front-12))
			entry.append(Vector2(door_left+12,_front-12))
			shade_colors.append(Color(0.16,0.22,0.21,0.10*_facade_alpha))
			shade_colors.append(Color(0.16,0.22,0.21,0.10*_facade_alpha))
			draw_polygon(entry,shade_colors)
			draw_colored_polygon(PackedVector2Array([Vector2(door_left+2,_front-70),Vector2(door_left+15,_front-64),Vector2(door_left+15,_front-13),Vector2(door_left+2,_front+1)]),Color(0.28,0.33,0.31,0.72*_facade_alpha))
			draw_colored_polygon(PackedVector2Array([Vector2(door_right-2,_front-70),Vector2(door_right-14,_front-64),Vector2(door_right-14,_front-13),Vector2(door_right-2,_front+1)]),Color(0.48,0.49,0.41,0.66*_facade_alpha))
			draw_polygon(PackedVector2Array([Vector2(door_left+15,_front-30),Vector2(door_right-14,_front-30),Vector2(door_right-2,_front+1),Vector2(door_left+2,_front+1)]),PackedColorArray([Color(0.32,0.37,0.35,0.7*_facade_alpha),Color(0.32,0.37,0.35,0.7*_facade_alpha),Color(0.52,0.54,0.48,0.65*_facade_alpha),Color(0.52,0.54,0.48,0.65*_facade_alpha)]))
			# One small shielded sconce at the real entry pier. Painted local light
			# fades with this frontage and never crosses into the room behind it.
			var lamp := _lamp_light if _painted_lantern else Vector2(door_left-16.0,_front-66.0)
			for ring in range(4,0,-1):
				draw_circle(lamp,8.0*ring,Color(0.88,0.65,0.32,0.018*_facade_alpha))
			if not _painted_lantern:
				draw_rect(Rect2(lamp-Vector2(6,11),Vector2(12,22)),Color(0.16,0.21,0.20,_facade_alpha))
				draw_rect(Rect2(lamp-Vector2(3,7),Vector2(6,13)),Color(0.83,0.69,0.41,_facade_alpha))
	# Foundation-mounted pipe and pressure cabinet, kept inside blocked wall
	# cells; service machinery therefore never implies an invisible blocker.
	# Only where the painted frontage has no services of its own: the civic
	# arcade's entrance slicing already carries its downpipe on the right wing.
	if _irregular or not _draws_services(): return
	var pipe_x := bounds.end.x - 25.0
	for door: Dictionary in _doors:
		if door.dir == Vector2i.RIGHT: pipe_x = bounds.position.x + 25.0
	var pipe_top := bounds.position.y + 66.0
	var pipe_bottom := _front - 12.0
	var pipe_width := 14.0 if civic else 7.0
	draw_line(Vector2(pipe_x + 4, pipe_top + 3), Vector2(pipe_x + 4, pipe_bottom + 3), Color("263736"), pipe_width+5)
	draw_line(Vector2(pipe_x, pipe_top), Vector2(pipe_x, pipe_bottom), Color("8f7c59") if civic else Color("688a80"), pipe_width)
	draw_line(Vector2(pipe_x - 3, pipe_top), Vector2(pipe_x - 3, pipe_bottom), Color("aaa183") if civic else Color("8a9b89"), 3.0 if civic else 2.0)
	if civic:
		# One grouped patina patch and plant coupling rather than many joints.
		draw_line(Vector2(pipe_x+2,pipe_bottom-74),Vector2(pipe_x+2,pipe_bottom-16),Color("587c6c"),6)
		draw_line(Vector2(pipe_x-25,_front-70),Vector2(pipe_x,_front-70),Color("3d4d42"),18)
		draw_line(Vector2(pipe_x-25,_front-72),Vector2(pipe_x,_front-72),Color("9a855d"),11)
	for t in [0.25, 0.8]:
		var at := Vector2(pipe_x, lerpf(pipe_top, pipe_bottom, t))
		draw_line(at - Vector2(8, 0), at + Vector2(8, 0), Color("465954"), 5.0)
	var cabinet := Rect2(pipe_x - 28.0, pipe_bottom - 66.0, 32.0, 46.0)
	draw_rect(cabinet.grow(3), Color("303d3e"))
	draw_rect(cabinet, Color("5c706a"))
	draw_rect(Rect2(cabinet.position + Vector2(7, 7), Vector2(18, 12)), Color("202f31"))
	draw_circle(cabinet.position + Vector2(16, 13), 4, Color("b6ac83"))
	if civic:
		# Restrained light belongs to this existing analog service indicator.
		draw_circle(cabinet.position+Vector2(16,13),17,Color(0.86,0.65,0.32,0.045))
		draw_circle(cabinet.position+Vector2(16,13),9,Color(0.92,0.75,0.43,0.07))
	draw_line(cabinet.position + Vector2(6, 30), cabinet.position + Vector2(25, 30), Color("354b49"), 2)
	# One connected block edge, with actual road portals left open. These
	# shallow gutters are surface treatment and own no collision geometry.
	# The shared ground material owns road-union curbs/gutters. No rectangular
	# outline around the block: unused edges transition through soil and grass.
	if not civic: return
	# The leafy group grows from a contained stone base on the blocked corner.
	if not _painted_planter:
		var bed := Rect2(bounds.position.x+2,_front-15,46,24)
		draw_rect(bed.grow(3),Color("38463d"))
		draw_rect(bed,Color("929789"))
		draw_rect(Rect2(bed.position+Vector2(4,3),bed.size-Vector2(8,10)),Color("454b36"))
	var drain := Rect2(pipe_x-3,_front+11,32,18)
	var outlet := Vector2(pipe_x+12,_front+3)
	# A mounted downpipe stops over a flush catch drain, with a short shaded
	# elbow. No graphic dogleg or raised pipe across the pedestrian surface.
	draw_colored_polygon(PackedVector2Array([drain.position-Vector2(9,2),drain.position+Vector2(35,-3),drain.end+Vector2(10,19),drain.end+Vector2(-13,12)]),Color(0.24,0.34,0.30,0.15))
	var spout := PackedVector2Array([Vector2(pipe_x,_front-35),Vector2(pipe_x,_front-7),outlet])
	var cast := PackedVector2Array()
	for point: Vector2 in spout: cast.append(point+Vector2(-4,3))
	draw_polyline(cast,Color("303d36"),15,true)
	draw_polyline(spout,Color("4b5143"),13,true)
	draw_polyline(spout,Color("8b7958"),9,true)
	var highlight := PackedVector2Array()
	for point: Vector2 in spout: highlight.append(point-Vector2(2,1))
	draw_polyline(highlight,Color("b0a37a"),2,true)
	draw_line(Vector2(pipe_x-8,_front-18),Vector2(pipe_x+8,_front-18),Color("50594a"),4)
	draw_circle(outlet,4.5,Color("34413c"))
	draw_rect(drain.grow(5),Color("7e8579"))
	draw_rect(drain.grow(2),Color("424e46"))
	draw_rect(drain, Color("293a37"))
	for x in range(5):
		draw_line(drain.position + Vector2(4 + x * 6, 3), drain.position + Vector2(4 + x * 6, 15), Color("75817a"), 2)

## Hand-drawn pipe, cabinet and drain: only for frontages whose painted art
## has no services. Composed fronts carry their own fittings and the sliced
## civic arcade entrance shows its downpipe; the closed civic bays do not.
func _draws_services() -> bool:
	if _is_guard() or _composed() or _irregular: return false
	return not (civic and _south_front)

## Kit-local x span the hand-drawn services occupy at the wall foot, so street
## dressing can keep clear of them (Vector2.ZERO when none are drawn).
func service_clear_span() -> Vector2:
	if not _draws_services(): return Vector2.ZERO
	var pipe_x := bounds.end.x - 25.0
	for door: Dictionary in _doors:
		if door.dir == Vector2i.RIGHT: pipe_x = bounds.position.x + 25.0
	return Vector2(pipe_x - 34.0, pipe_x + 34.0)

func _draw_closed_frontage() -> void:
	# Reuse only the closed side bay, at its native aspect ratio. Repeating
	# complete window/arcade bays avoids stretching an entire facade to fit.
	var width := bounds.size.x - 32.0
	draw_rect(Rect2(bounds.position.x+16,_front-_facade_height,width,12),Color(0.08,0.14,0.17,0.28*_facade_alpha))

func _draw_street_border(from: Vector2, to: Vector2, portal: Rect2) -> void:
	var horizontal := is_equal_approx(from.y, to.y)
	var start := from.x if horizontal else from.y
	var end := to.x if horizontal else to.y
	var gap_start := portal.position.x if horizontal else portal.position.y
	var gap_end := portal.end.x if horizontal else portal.end.y
	var spans: Array[Vector2] = [Vector2(start, end)]
	var reaches_edge := from.y >= portal.position.y and from.y <= portal.end.y if horizontal else from.x >= portal.position.x and from.x <= portal.end.x
	if portal.has_area() and reaches_edge and gap_end > start and gap_start < end:
		spans = [Vector2(start, maxf(start, gap_start-12)), Vector2(minf(end, gap_end+12), end)]
	for span in spans:
		if span.y <= span.x: continue
		var a := Vector2(span.x, from.y) if horizontal else Vector2(from.x, span.x)
		var b := Vector2(span.y, to.y) if horizontal else Vector2(to.x, span.y)
		draw_line(a, b, Color("43514f"), 10)
		draw_line(a+Vector2(2,2), b+Vector2(2,2), Color("9ca497"), 4)
