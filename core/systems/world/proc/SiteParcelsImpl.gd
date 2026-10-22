extends RefCounted
class_name SiteParcelsImpl

const RECT_FAC := preload("res://core/systems/world/proc/RectFacilityCarver.gd")
const INDOOR_VOLUME_SCENE: PackedScene = preload("res://scenes/world/volumes/IndoorVolume.tscn")
const ROOF_OVERLAY_SCENE: PackedScene = preload("res://scenes/world/buildings/RoofOverlay.tscn")
const CITY_KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const DOMESTIC := preload("res://scenes/world/buildings/CityDomesticInterior.gd")
const DISTRICT_PROFILES := preload("res://scenes/world/buildings/DistrictVisualProfiles.gd")
const _DIR_N: int = 1
const _DIR_E: int = 2
const _DIR_S: int = 4
const _DIR_W: int = 8
## Street continuity post-pass (2026-10-21). New salt family: 4903 street and
## courtyard infill, 4904 framed landmark squares. It runs after every original
## lot, forced reward and service annex decision, so those stay byte-identical.
const INFILL_SALT := 4903
const SQUARE_SALT := 4904
## The room carver needs 6x6 for a perimeter, so infill lots are at least 6
## long and 6 deep, and at most as long as an original lot (13).
const INFILL_MIN_LEN := 6
const INFILL_MAX_LEN := 13
const INFILL_MIN_DEPTH := 6
## Width of every opening the infill leaves in a frontage.
const INFILL_PASSAGE := 3
## Longest wall of buildings (1-2 cell slits count as wall) the infill builds
## or joins, along a band's front line and beside every lane of its chunk,
## before it leaves an opening of at least INFILL_PASSAGE cells: N = 24 cells
## (1536 px, about one and a quarter gameplay screens). Original lots alone
## already make walls of up to 27 cells; the pass never extends one.
const WALL_MAX := 24
## Cells beside a lane edge in which buildings make that lane's wall.
const WALL_WINDOW := 4
## A wall beside a lane never runs across a chunk seam: the infill leaves the
## first two cells and the last cell of a chunk unbuilt where a lane crosses
## that seam, so every seam keeps an opening of INFILL_PASSAGE (2 + 1) cells
## between the infill of the two chunks. Original lots never touch a seam cell
## and come no nearer than one cell, and a wall that an original already
## carries into those cells is never extended.
const SEAM_LOW_OPEN := 2
const SEAM_HIGH_OPEN := 1
## Depth of the clear apron kept in front of every doorway.
const DOOR_APRON := 4
## Medieval street pass (2026-10-21), new salts: 4905 the setback step of each
## infill segment, 4906 the open outskirts, 4908 the open sides of a framed
## square. Each is a stable hash of the world seed and a global cell, so no
## generator, parcel, chunk or infill RNG draw changes.
const FRONTAGE_SALT := 4905
const EDGE_SALT := 4906
const FRAME_SIDE_SALT := 4908
## Setback steps of an infill segment relative to its band's front line, in
## cells (positive steps back from the street): an attached run keeps one line,
## the next segment or the original next door stands on another.
const SETBACK_STEPS := [0, 1, -1]
const SETBACK_WEIGHTS := [40, 35, 25]
## Share (percent) of the district's outer courtyard rings (a ring of an
## envelope block backing onto a chunk outside the district plan) whose infill
## is left out, so the outskirts keep open ground and isolated houses.
const EDGE_OPEN_PERCENT := 50

# Dense street frontage generator. Roads define bands, bands are divided into lots,
# and every blank frontage is an intentional passage rather than an accidental field.
func decorate_district_parcels(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	lane_rect_h: Rect2i,
	lane_rect_v: Rect2i,
	keepout_rects: Array[Rect2i],
	cfg: Dictionary
) -> Array[Rect2i]:
	var placed: Array[Rect2i] = []
	var has_h: bool = lane_rect_h.size.x > 0 and lane_rect_h.size.y > 0
	var has_v: bool = lane_rect_v.size.x > 0 and lane_rect_v.size.y > 0
	if not has_h and not has_v:
		return placed

	var cpc: int = int(chunk_manager._cells_per_chunk())
	var chunk_rect := Rect2i(Vector2i.ZERO, Vector2i(cpc, cpc))
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4001)

	var depth: int = clampi(int(cfg.get("parcel_depth_cells", 10)), 8, maxi(8, int(cpc / 2.0) - 2))
	var street_gap: int = maxi(1, int(cfg.get("parcel_street_gap_cells", 1)))
	var bands: Array[Dictionary] = []

	# Each exact road arm contributes its own frontage. This preserves L-turns and
	# T-junctions: a missing west arm no longer receives west-facing "phantom" shops.
	# Overlaps at real intersections are resolved lot-by-lot against road keepouts and
	# already placed buildings.
	if has_h:
		var span_x0: int = clampi(lane_rect_h.position.x + 1, 2, cpc - 3)
		var span_x1: int = clampi(lane_rect_h.position.x + lane_rect_h.size.x - 1, span_x0 + 1, cpc - 2)
		_add_band(bands, Rect2i(Vector2i(span_x0, lane_rect_h.position.y - street_gap - depth), Vector2i(span_x1 - span_x0, depth)), Vector2i(0, 1))
		_add_band(bands, Rect2i(Vector2i(span_x0, lane_rect_h.position.y + lane_rect_h.size.y + street_gap), Vector2i(span_x1 - span_x0, depth)), Vector2i(0, -1))
	if has_v:
		var span_y0: int = clampi(lane_rect_v.position.y + 1, 2, cpc - 3)
		var span_y1: int = clampi(lane_rect_v.position.y + lane_rect_v.size.y - 1, span_y0 + 1, cpc - 2)
		_add_band(bands, Rect2i(Vector2i(lane_rect_v.position.x - street_gap - depth, span_y0), Vector2i(depth, span_y1 - span_y0)), Vector2i(1, 0))
		_add_band(bands, Rect2i(Vector2i(lane_rect_v.position.x + lane_rect_v.size.x + street_gap, span_y0), Vector2i(depth, span_y1 - span_y0)), Vector2i(-1, 0))

	var working_cfg: Dictionary = cfg.duplicate(true)
	working_cfg["_secondary_assigned"] = false
	var force_parcel: bool = bool(working_cfg.get("force_parcel", false))
	var filled_any: bool = false
	for band_variant in bands:
		var band_data: Dictionary = band_variant as Dictionary
		var band: Rect2i = band_data.get("rect", Rect2i()) as Rect2i
		var door_dir: Vector2i = band_data.get("door_dir", Vector2i.ZERO) as Vector2i
		if not _rect_inside_chunk(band, chunk_rect):
			continue
		if _fill_frontage_band(chunk_manager, chunk, coord, band, door_dir, keepout_rects, placed, working_cfg, rng, chunk_rect, force_parcel and not filled_any):
			filled_any = true
	# Courtyard access can cross the nominal full-depth frontage band. A
	# required reward must still use a smaller safe part of that same band,
	# rather than silently leaving a planned searchable objective empty.
	if force_parcel and not filled_any:
		for band_data: Dictionary in bands:
			var band: Rect2i = (band_data.rect as Rect2i).intersection(chunk_rect.grow(-2))
			var direction: Vector2i = band_data.door_dir
			var size := Vector2i(7,8) if direction.y != 0 else Vector2i(8,7)
			for y in range(band.position.y,band.end.y-size.y+1):
				for x in range(band.position.x,band.end.x-size.x+1):
					var candidate := Rect2i(Vector2i(x,y),size)
					if not _rect_can_place(candidate,chunk_rect,keepout_rects,placed): continue
					filled_any = _spawn_building_rect(chunk_manager,chunk,coord,candidate,direction,&"workshop",keepout_rects,placed,working_cfg,rng,chunk_rect)
					if filled_any: break
				if filled_any: break
			if filled_any: break
	if bool(working_cfg.get("complete_service_frontage",false)) and filled_any and placed.size() < 3:
		_complete_service_frontage(chunk_manager,chunk,coord,bands,keepout_rects,placed,working_cfg,chunk_rect)
	# Street continuity: only where the original pass built, so a chunk that
	# falls back to Donjon carving or ruin lines keeps its own rewards.
	if bool(working_cfg.get("street_continuity", false)) and not placed.is_empty():
		_infill_street_bands(chunk_manager, chunk, coord, bands, lane_rect_h, lane_rect_v, keepout_rects, placed, working_cfg, chunk_rect)
	if bool(working_cfg.get("city_block_style", false)):
		if not bool(working_cfg.get("city_shared_ground", false)):
			CITY_KIT.compose_street(chunk, placed, lane_rect_h, lane_rect_v, int(chunk_manager.cell_size_px), cpc)
		else:
			if Global.attempt_segment == 2:
				preload("res://scenes/world/buildings/CityStreetFrontage.gd").compose(chunk,placed,int(chunk_manager.cell_size_px),cpc,lane_rect_h,lane_rect_v)
			for kit: Node in chunk.get_children():
				if kit.is_in_group(&"city_block_building"): kit.trim_paving(placed, int(chunk_manager.cell_size_px))

	return placed


func _complete_service_frontage(cm: Node, chunk: Node2D, coord: Vector2i, bands: Array[Dictionary], keepouts: Array[Rect2i], placed: Array[Rect2i], cfg: Dictionary, extent: Rect2i) -> void:
	# One small service annex in a sparse lane. Fit against the same protected
	# road/access cells and parcel list, after all original lots/RNG decisions.
	var annex_cfg := cfg.duplicate(true)
	annex_cfg["secondary_objective_id"] = 0
	annex_cfg["local_encounter_enabled"] = false
	annex_cfg["parcel_loot_chance"] = 0.0
	annex_cfg["exploration_loot_enabled"] = false
	annex_cfg["city_service_annex"] = true
	var annex_rng := RandomNumberGenerator.new()
	annex_rng.seed = _mix_seed(int(cm.world_seed),coord.x,coord.y,4891)
	for size: Vector2i in [Vector2i(8,8),Vector2i(7,8)]:
		for band: Dictionary in bands:
			var usable: Rect2i = (band.rect as Rect2i).intersection(extent.grow(-1))
			var direction: Vector2i = band.door_dir
			var shape := size if direction.y != 0 else Vector2i(size.y,size.x)
			if usable.size.x < shape.x or usable.size.y < shape.y: continue
			var count: int = usable.size.x-shape.x+1 if direction.y != 0 else usable.size.y-shape.y+1
			for offset in count:
				var at := usable.position
				if direction.y != 0:
					at.x += offset
					if direction.y > 0: at.y = usable.end.y-shape.y
				else:
					at.y += offset
					if direction.x > 0: at.x = usable.end.x-shape.x
				var rect := Rect2i(at,shape)
				# Keep an honest narrow passage beside existing architecture.
				var separated := true
				for neighbor: Rect2i in placed:
					if neighbor.grow(1).intersects(rect): separated = false
				if not separated or not _rect_can_place(rect,extent,keepouts,placed): continue
				if _spawn_building_rect(cm,chunk,coord,rect,direction,&"workshop",keepouts,placed,annex_cfg,annex_rng,extent): return


# --- Street continuity (2026-10-21) -------------------------------------------
# The original pass leaves 1-11 cell slits between lots, drops any band that
# does not fit wholly inside the chunk and stops every through-street three
# cells short of the seam. This post-pass fills the remaining free stretches of
# every frontage band with lots attached (gap 0) to the buildings already there,
# ending at blocked columns, so streets read as continuous inhabited frontage.
# Access corridors, lane contracts, road cells, plaza keepouts and objective
# anchor boxes are keepouts, so their passages stay exactly as wide as before.
# Infill lots are architecture only: no secondary objective, no loot, no local
# encounter, no ambient spawn socket and no exploration visit.
#
# Combat space: along a band's front line (its two front rows) the infill plans
# its lots so that no wall of buildings - 1-2 cell slits count as wall - grows
# past WALL_MAX cells, measuring the wall it would join across original lots,
# slits and blocked columns, and leaves deliberate 3-cell openings instead.
# Every lot then passes the same bound beside every lane of the chunk
# (WALL_WINDOW cells from the lane edge, the corner lots of crossing bands
# included), and keeps the lane's seam cells open, so no lane wall runs across
# a chunk seam. Every opening the infill leaves is reserved for the rest of the
# chunk's infill, and every doorway keeps a 3-wide, DOOR_APRON-deep apron.

func _infill_cfg(cfg: Dictionary) -> Dictionary:
	var infill := cfg.duplicate(true)
	infill["secondary_objective_id"] = 0
	infill["local_encounter_enabled"] = false
	infill["parcel_loot_chance"] = 0.0
	infill["ambient_parcel_loot_chance"] = 0.0
	infill["exploration_loot_enabled"] = false
	infill["city_service_annex"] = false
	infill["city_street_infill"] = true
	infill["door_spawn_socket"] = false
	return infill


## Street bands: the original band list (including the bands the original pass
## dropped for not fitting the chunk). Inside bands keep the original margin, so
## infill shares the original lots' front line. Clipped bands keep the chunk's
## seam ring open and, when shallow, give up street setback (2 -> 1 -> 0 cells)
## before giving up the band. Bands on a through arm run to the chunk seam's
## open cells.
func _infill_street_bands(cm: Node, chunk: Node2D, coord: Vector2i, bands: Array[Dictionary], lane_rect_h: Rect2i, lane_rect_v: Rect2i, keepouts: Array[Rect2i], placed: Array[Rect2i], cfg: Dictionary, extent: Rect2i) -> void:
	var cpc: int = extent.size.x
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(int(cm.world_seed), coord.x, coord.y, INFILL_SALT)
	var margin: int = maxi(0, int(cfg.get("parcel_building_margin_cells", 1)))
	var reserved: Array[Rect2i] = []
	for box: Rect2i in cfg.get("infill_reserved", []):
		reserved.append(box)
	var infill_cfg := _infill_cfg(cfg)
	var lane_walls := _lane_walls(lane_rect_h, lane_rect_v, cpc)
	# The accepted S2 service-lane homes are pinned fixtures (exactly one home
	# per lane); their infill stays shops, workshops and passages.
	var allow_row_house := not bool(cfg.get("complete_service_frontage", false))
	for band_data: Dictionary in bands:
		var rect: Rect2i = band_data.get("rect", Rect2i()) as Rect2i
		var door_dir: Vector2i = band_data.get("door_dir", Vector2i.ZERO) as Vector2i
		var lane: Rect2i = lane_rect_h if door_dir.y != 0 else lane_rect_v
		var lane_lo: int = lane.position.x if door_dir.y != 0 else lane.position.y
		var lane_hi: int = lane.end.x if door_dir.y != 0 else lane.end.y
		var seam_lo: bool = lane.has_area() and lane_lo == 0
		var seam_hi: bool = lane.has_area() and lane_hi == cpc
		var usable := _infill_band_rect(rect, door_dir, margin, cpc, seam_lo, seam_hi)
		if not _rect_inside_chunk(rect, extent):
			for _trim in 2:
				if _infill_depth(usable, door_dir) >= INFILL_MIN_DEPTH:
					break
				usable = _infill_grow_front(usable, door_dir)
		_infill_band(cm, chunk, coord, usable, door_dir, keepouts, reserved, placed, infill_cfg, rng, extent, allow_row_house, lane_walls)


## Courtyard rings: an original band keeps its geometry; a ring too thin for an
## original band starts at the court keepout itself (one row closer) so a
## 6-deep lot can complete the block. Doors face the court like the original
## ring lots: a neighbouring street lies behind that chunk's own frontage band
## (lane centres are hashed to 11..21 of 32 cells), so an outward door would
## open onto the backs of the next row.
func _infill_courtyard(cm: Node, chunk: Node2D, coord: Vector2i, court: Rect2i, keepouts: Array[Rect2i], placed: Array[Rect2i], cfg: Dictionary, extent: Rect2i) -> void:
	var cpc: int = extent.size.x
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(int(cm.world_seed), coord.x, coord.y, INFILL_SALT)
	var infill_cfg := _infill_cfg(cfg)
	var no_reserved: Array[Rect2i] = []
	for ring: Dictionary in _courtyard_rings(court, cpc):
		var rect: Rect2i = ring.rect
		if rect.size.x < INFILL_MIN_DEPTH or rect.size.y < INFILL_MIN_DEPTH:
			continue
		var inward: Vector2i = ring.door_dir
		if _edge_left_open(cm, coord, -inward):
			continue
		var usable := _infill_band_rect(rect, inward, 0, cpc, false, false)
		_infill_band(cm, chunk, coord, usable, inward, keepouts, no_reserved, placed, infill_cfg, rng, extent, true, [])


static func _courtyard_rings(court: Rect2i, cpc: int) -> Array[Dictionary]:
	var north_h: int = maxi(0, court.position.y - 2)
	var south_y: int = court.end.y + 2
	var south_h: int = maxi(0, cpc - south_y - 1)
	var west_w: int = maxi(0, court.position.x - 2)
	var east_x: int = court.end.x + 2
	var east_w: int = maxi(0, cpc - east_x - 1)
	var rings: Array[Dictionary] = []
	rings.append({"rect": Rect2i(1, 1, cpc - 2, north_h), "door_dir": Vector2i(0, 1)})
	if south_h >= 7:
		rings.append({"rect": Rect2i(1, south_y, cpc - 2, south_h), "door_dir": Vector2i(0, -1)})
	else:
		rings.append({"rect": Rect2i(1, south_y - 1, cpc - 2, south_h + 1), "door_dir": Vector2i(0, -1)})
	rings.append({"rect": Rect2i(1, 1, west_w, cpc - 2), "door_dir": Vector2i(1, 0)})
	if east_w >= 7:
		rings.append({"rect": Rect2i(east_x, 1, east_w, cpc - 2), "door_dir": Vector2i(-1, 0)})
	else:
		rings.append({"rect": Rect2i(east_x - 1, 1, east_w + 1, cpc - 2), "door_dir": Vector2i(-1, 0)})
	return rings


## A landmark square is purely cosmetic: it is cut down (ChunkGenDistrict) and
## framed by buildings facing it, keeping square.grow(2), every lane, road and
## access corridor, and the chunk-centred landmark box open.
func decorate_square_frame(chunk_manager: Node, chunk: Node2D, coord: Vector2i, square: Rect2i, keepout_rects: Array[Rect2i], cfg: Dictionary) -> Array[Rect2i]:
	var placed: Array[Rect2i] = []
	var cpc: int = int(chunk_manager._cells_per_chunk())
	if cpc < 24 or not square.has_area():
		return placed
	var extent := Rect2i(Vector2i.ZERO, Vector2i(cpc, cpc))
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, SQUARE_SALT)
	var half: int = int(cpc / 2.0)
	var reserved: Array[Rect2i] = [square.grow(2), Rect2i(Vector2i(half - 5, half - 5), Vector2i(11, 11))]
	var infill_cfg := _infill_cfg(cfg)
	var lane_walls := _lane_walls(cfg.get("lane_rect_h", Rect2i()), cfg.get("lane_rect_v", Rect2i()), cpc)
	var rings: Array[Dictionary] = [
		{"rect": Rect2i(1, 1, cpc - 2, square.position.y - 3), "door_dir": Vector2i(0, 1)},
		{"rect": Rect2i(1, square.end.y + 2, cpc - 2, cpc - 1 - (square.end.y + 2)), "door_dir": Vector2i(0, -1)},
		{"rect": Rect2i(1, 1, square.position.x - 3, cpc - 2), "door_dir": Vector2i(1, 0)},
		{"rect": Rect2i(square.end.x + 2, 1, cpc - 1 - (square.end.x + 2), cpc - 2), "door_dir": Vector2i(-1, 0)},
	]
	# Not every landmark is the same ceremonial square: one or two sides
	# (stable hash) stay open to the street, so squares are framed on four,
	# three or two (a corner) sides.
	var open_sides := _frame_open_sides(chunk_manager, coord)
	for index in rings.size():
		var ring: Dictionary = rings[index]
		var rect: Rect2i = ring.rect
		if open_sides & (1 << index) or rect.size.x < INFILL_MIN_DEPTH or rect.size.y < INFILL_MIN_DEPTH:
			continue
		var door: Vector2i = ring.door_dir
		var usable := _infill_band_rect(rect, door, 0, cpc, false, false)
		_infill_band(chunk_manager, chunk, coord, usable, door, keepout_rects, reserved, placed, infill_cfg, rng, extent, true, lane_walls)
	if placed.is_empty():
		return placed
	chunk.set_meta(&"_proc_framed_square", square)
	chunk.set_meta(&"_proc_framed_open_sides", open_sides)
	if bool(cfg.get("city_block_style", false)):
		for kit: Node in chunk.get_children():
			if kit.is_in_group(&"city_block_building"):
				kit.set("_chunk_extent", Vector2.ONE * cpc * int(chunk_manager.cell_size_px))
				kit.trim_paving(placed, int(chunk_manager.cell_size_px))
	return placed


## The outskirts stay open: a courtyard ring whose block backs onto a chunk
## outside the district plan is left without infill for EDGE_OPEN_PERCENT of
## such rings, so the district edge keeps its original, looser lots, open
## ground and isolated houses; streets keep their continuous frontage. Plan
## data only (roles and terrain), so streaming order cannot change it; a chunk
## without plan terrain (a hand-built fixture) has no outskirts.
func _edge_left_open(cm: Node, coord: Vector2i, back: Vector2i) -> bool:
	if back == Vector2i.ZERO or not cm.has_method("get_chunk_terrain") or StringName(cm.get_chunk_terrain(coord)) == &"":
		return false
	if StringName(cm.get_chunk_role(coord + back)) != &"unplanned":
		return false
	var side := 0 if back == Vector2i(0, -1) else 1 if back == Vector2i(1, 0) else 2 if back == Vector2i(0, 1) else 3
	return absi(_mix_seed(int(cm.world_seed), coord.x * 4 + side, coord.y, EDGE_SALT)) % 100 < EDGE_OPEN_PERCENT


## Setback step of one infill segment: a stable hash of its first front cell
## picks 0, +1 (one cell back from the street) or -1 (one cell toward it), a
## step differing from the previous segment of the run where it can. +1 needs
## a cell of spare depth along the whole segment; -1 needs the two cells in
## front of it clear of every keepout, opening, apron and building, so the
## street contract and a one-cell walk stay open.
func _segment_setback(cm: Node, coord: Vector2i, usable: Rect2i, align: Vector2i, segment: Vector2i, free: PackedInt32Array, ahead: PackedByteArray, previous: int) -> int:
	var cpc: int = int(cm._cells_per_chunk())
	var global := coord * cpc + _infill_front_cell(usable, align, segment.x, 0)
	var roll := absi(_mix_seed(int(cm.world_seed), global.x, global.y, FRONTAGE_SALT)) % 100
	var pick := 0
	var acc := 0
	for index in SETBACK_STEPS.size():
		acc += int(SETBACK_WEIGHTS[index])
		if roll < acc:
			pick = index
			break
	var order: Array[int] = []
	for offset in SETBACK_STEPS.size():
		order.append(int(SETBACK_STEPS[(pick + offset) % SETBACK_STEPS.size()]))
	if order[0] == previous and previous != 0:
		order.push_back(order.pop_front())
	for step: int in order:
		var ok := true
		for t in range(segment.x, segment.y):
			if step > 0 and free[t] < INFILL_MIN_DEPTH + step:
				ok = false
			elif step < 0 and ahead[t] == 0:
				ok = false
			if not ok:
				break
		if ok:
			return step
	return 0


## Framed-square sides left open, as bits of the ring order (1 north, 2
## south, 4 west, 8 east): none for 40%, one side for 45%, two adjacent sides
## (a corner square) for 15%.
func _frame_open_sides(cm: Node, coord: Vector2i) -> int:
	var h := absi(_mix_seed(int(cm.world_seed), coord.x, coord.y, FRAME_SIDE_SALT))
	var roll := h % 100
	if roll < 40:
		return 0
	if roll < 85:
		return 1 << ((h >> 8) % 4)
	return [1 | 4, 1 | 8, 2 | 4, 2 | 8][(h >> 8) % 4]


## Infill extent of one band: the margin-inset band, its depth axis clipped to
## [1, cpc-1) so the chunk's seam ring stays open, its frontage axis run to the
## seam's open cells on a through arm.
static func _infill_band_rect(rect: Rect2i, align: Vector2i, margin: int, cpc: int, seam_lo: bool, seam_hi: bool) -> Rect2i:
	var usable := rect.grow(-margin)
	if align.y != 0:
		var x0: int = SEAM_LOW_OPEN if seam_lo else maxi(0, usable.position.x)
		var x1: int = cpc - SEAM_HIGH_OPEN if seam_hi else mini(cpc, usable.end.x)
		var y0: int = maxi(usable.position.y, 1)
		var y1: int = mini(usable.end.y, cpc - 1)
		return Rect2i(x0, y0, x1 - x0, y1 - y0)
	var top: int = SEAM_LOW_OPEN if seam_lo else maxi(0, usable.position.y)
	var bottom: int = cpc - SEAM_HIGH_OPEN if seam_hi else mini(cpc, usable.end.y)
	var left: int = maxi(usable.position.x, 1)
	var right: int = mini(usable.end.x, cpc - 1)
	return Rect2i(left, top, right - left, bottom - top)


static func _infill_depth(usable: Rect2i, align: Vector2i) -> int:
	return usable.size.y if align.y != 0 else usable.size.x


## One cell of setback given back to a shallow clipped band: its street edge
## moves toward the lane.
static func _infill_grow_front(usable: Rect2i, align: Vector2i) -> Rect2i:
	if align == Vector2i(0, 1):
		return Rect2i(usable.position, usable.size + Vector2i(0, 1))
	if align == Vector2i(0, -1):
		return Rect2i(usable.position - Vector2i(0, 1), usable.size + Vector2i(0, 1))
	if align == Vector2i(1, 0):
		return Rect2i(usable.position, usable.size + Vector2i(1, 0))
	return Rect2i(usable.position - Vector2i(1, 0), usable.size + Vector2i(1, 0))


## Cell `depth` steps behind the aligned front edge at frontage column `t`.
static func _infill_front_cell(usable: Rect2i, align: Vector2i, t: int, depth: int) -> Vector2i:
	if align == Vector2i(0, 1):
		return Vector2i(usable.position.x + t, usable.end.y - 1 - depth)
	if align == Vector2i(0, -1):
		return Vector2i(usable.position.x + t, usable.position.y + depth)
	if align == Vector2i(1, 0):
		return Vector2i(usable.end.x - 1 - depth, usable.position.y + t)
	return Vector2i(usable.position.x + depth, usable.position.y + t)


static func _infill_lot(usable: Rect2i, align: Vector2i, t: int, length: int, depth: int) -> Rect2i:
	if align == Vector2i(0, 1):
		return Rect2i(usable.position.x + t, usable.end.y - depth, length, depth)
	if align == Vector2i(0, -1):
		return Rect2i(usable.position.x + t, usable.position.y, length, depth)
	if align == Vector2i(1, 0):
		return Rect2i(usable.end.x - depth, usable.position.y + t, depth, length)
	return Rect2i(usable.position.x, usable.position.y + t, depth, length)


## A placed lot standing on the band's front line at column `t` (a frontage
## neighbour to attach to), or an empty rect for a crossing lot or none.
static func _infill_neighbour(placed: Array[Rect2i], usable: Rect2i, align: Vector2i, t: int, count: int) -> Rect2i:
	if t < 0 or t >= count:
		return Rect2i()
	var cell := _infill_front_cell(usable, align, t, 0)
	for rect: Rect2i in placed:
		if not rect.has_point(cell):
			continue
		var flush := false
		if align == Vector2i(0, 1):
			flush = rect.end.y == usable.end.y
		elif align == Vector2i(0, -1):
			flush = rect.position.y == usable.position.y
		elif align == Vector2i(1, 0):
			flush = rect.end.x == usable.end.x
		else:
			flush = rect.position.x == usable.position.x
		return rect if flush else Rect2i()
	return Rect2i()


## Every deliberate opening the chunk's infill has left so far (reserved for
## the rest of its infill).
static func _infill_openings(chunk: Node2D) -> Array[Rect2i]:
	var openings: Array[Rect2i] = []
	for rect: Variant in chunk.get_meta(&"_proc_infill_openings", []):
		openings.append(rect as Rect2i)
	return openings


static func _reserve_opening(chunk: Node2D, rect: Rect2i) -> void:
	if not rect.has_area():
		return
	var openings: Array = chunk.get_meta(&"_proc_infill_openings", [])
	openings.append(rect)
	chunk.set_meta(&"_proc_infill_openings", openings)
	if mini(rect.size.x, rect.size.y) >= INFILL_PASSAGE:
		var passages: Array = chunk.get_meta(&"_proc_frontage_passages", [])
		passages.append(rect)
		chunk.set_meta(&"_proc_frontage_passages", passages)


## The clear apron of every doorway standing in the chunk: DOOR_APRON cells
## outward from the door, three wide. The marker stands one cell outside its
## door and records the outward direction; a marker without one gets the old
## 3x3 threshold.
static func _door_aprons(chunk: Node2D, cell_px: float) -> Array[Rect2i]:
	var aprons: Array[Rect2i] = []
	for child: Node in chunk.get_children():
		if not (child is Marker2D and StringName(child.get_meta(&"spawn_socket_kind", &"")) == &"door"):
			continue
		var front := Vector2i(((child as Node2D).position / cell_px).floor())
		var outward: Vector2i = child.get_meta(&"door_dir", Vector2i.ZERO)
		if outward == Vector2i.ZERO:
			aprons.append(Rect2i(front - Vector2i.ONE, Vector2i(3, 3)))
			continue
		var across := Vector2i(absi(outward.y), absi(outward.x))
		var far := front + outward * (DOOR_APRON - 1)
		aprons.append(Rect2i(front - across, Vector2i.ONE).merge(Rect2i(far + across, Vector2i.ONE)))
	return aprons


func _infill_band(cm: Node, chunk: Node2D, coord: Vector2i, usable: Rect2i, align: Vector2i, keepouts: Array[Rect2i], reserved: Array[Rect2i], placed: Array[Rect2i], cfg: Dictionary, rng: RandomNumberGenerator, extent: Rect2i, allow_row_house: bool, lane_walls: Array) -> void:
	var count: int = usable.size.x if align.y != 0 else usable.size.y
	var max_depth: int = _infill_depth(usable, align)
	if count < INFILL_MIN_LEN or max_depth < INFILL_MIN_DEPTH:
		return
	var obstacles: Array[Rect2i] = []
	obstacles.append_array(keepouts)
	obstacles.append_array(reserved)
	obstacles.append_array(placed)
	obstacles.append_array(_infill_openings(chunk))
	obstacles.append_array(_door_aprons(chunk, float(cm.cell_size_px)))
	# A lane's seam cells stay open, so lots there keep their depth off them.
	for wall: Dictionary in lane_walls:
		for open: Rect2i in wall.open:
			obstacles.append(open)
	# One rasterized occupancy grid, then the free depth behind the front line
	# per frontage column (cell lookups instead of rect tests per cell).
	var size: int = extent.size.x
	var blocked := PackedByteArray()
	blocked.resize(size * size)
	for rect: Rect2i in obstacles:
		var clipped := rect.intersection(extent)
		for y in range(clipped.position.y, clipped.end.y):
			for x in range(clipped.position.x, clipped.end.x):
				blocked[y * size + x] = 1
	var houses := PackedByteArray()
	houses.resize(size * size)
	for rect: Rect2i in placed:
		var clipped := rect.intersection(extent)
		for y in range(clipped.position.y, clipped.end.y):
			for x in range(clipped.position.x, clipped.end.x):
				houses[y * size + x] = 1
	var free := PackedInt32Array()
	free.resize(count)
	# The front line's wall: a building in either of the band's two front rows
	# (a segment stepped one cell back or forward still stands in them).
	var built := PackedByteArray()
	built.resize(count)
	# Columns where a lot may step one cell toward the street: that cell and
	# the next one out are inside the chunk and clear of every obstacle.
	var ahead := PackedByteArray()
	ahead.resize(count)
	for t in count:
		var clear_ahead := true
		for out in [-1, -2]:
			var cell := _infill_front_cell(usable, align, t, out)
			if not extent.has_point(cell) or blocked[cell.y * size + cell.x] != 0 or houses[cell.y * size + cell.x] != 0:
				clear_ahead = false
		ahead[t] = 1 if clear_ahead else 0
		var depth := 0
		while depth < max_depth:
			var cell := _infill_front_cell(usable, align, t, depth)
			if not extent.has_point(cell) or blocked[cell.y * size + cell.x] != 0:
				break
			depth += 1
		free[t] = depth
		for row in mini(2, max_depth):
			var front := _infill_front_cell(usable, align, t, row)
			if extent.has_point(front) and houses[front.y * size + front.x] != 0:
				built[t] = 1
	var at := 0
	while at < count:
		if free[at] < INFILL_MIN_DEPTH:
			at += 1
			continue
		var run_start := at
		while at < count and free[at] >= INFILL_MIN_DEPTH:
			at += 1
		_infill_run(cm, chunk, coord, usable, align, run_start, at, free, built, ahead, keepouts, reserved, placed, cfg, rng, extent, allow_row_house, lane_walls)


## Wall a lot at the start of a run would join: Vector2i(length, gap), the
## stretch ending before `at` (1-2 cell slits included, its length counted to
## the run) and the unbuilt columns between; length 0 when an opening or the
## band end separates them (a band end at a seam is one).
static func _wall_before(built: PackedByteArray, at: int) -> Vector2i:
	var t := at - 1
	var gap := 0
	while t >= 0 and built[t] == 0 and gap < INFILL_PASSAGE:
		gap += 1
		t -= 1
	if gap >= INFILL_PASSAGE or t < 0:
		return Vector2i(0, gap)
	var length := 0
	var slit := 0
	while t >= 0:
		if built[t] != 0:
			length += slit + 1
			slit = 0
		else:
			slit += 1
			if slit >= INFILL_PASSAGE:
				break
		t -= 1
	return Vector2i(length + gap, gap)


static func _wall_after(built: PackedByteArray, at: int) -> Vector2i:
	var count := built.size()
	var t := at
	var gap := 0
	while t < count and built[t] == 0 and gap < INFILL_PASSAGE:
		gap += 1
		t += 1
	if gap >= INFILL_PASSAGE or t >= count:
		return Vector2i(0, gap)
	var length := 0
	var slit := 0
	while t < count:
		if built[t] != 0:
			length += slit + 1
			slit = 0
		else:
			slit += 1
			if slit >= INFILL_PASSAGE:
				break
		t += 1
	return Vector2i(length + gap, gap)


## The walls beside a chunk's lanes: per lane side, the WALL_WINDOW cells beside
## the lane edge over the lane's length, and the seam cells kept open where
## the lane meets a chunk seam.
static func _lane_walls(lane_h: Rect2i, lane_v: Rect2i, cpc: int) -> Array:
	var walls: Array = []
	if lane_h.has_area():
		for side in [-1, 1]:
			var y0 := lane_h.position.y - WALL_WINDOW if side < 0 else lane_h.end.y
			var window := Rect2i(lane_h.position.x, y0, lane_h.size.x, WALL_WINDOW).intersection(Rect2i(0, 0, cpc, cpc))
			if not window.has_area():
				continue
			var opens: Array[Rect2i] = []
			if lane_h.position.x == 0:
				opens.append(Rect2i(0, window.position.y, SEAM_LOW_OPEN, window.size.y))
			if lane_h.end.x == cpc:
				opens.append(Rect2i(cpc - SEAM_HIGH_OPEN, window.position.y, SEAM_HIGH_OPEN, window.size.y))
			walls.append({"window": window, "along_x": true, "open": opens})
	if lane_v.has_area():
		for side in [-1, 1]:
			var x0 := lane_v.position.x - WALL_WINDOW if side < 0 else lane_v.end.x
			var window := Rect2i(x0, lane_v.position.y, WALL_WINDOW, lane_v.size.y).intersection(Rect2i(0, 0, cpc, cpc))
			if not window.has_area():
				continue
			var opens: Array[Rect2i] = []
			if lane_v.position.y == 0:
				opens.append(Rect2i(window.position.x, 0, window.size.x, SEAM_LOW_OPEN))
			if lane_v.end.y == cpc:
				opens.append(Rect2i(window.position.x, cpc - SEAM_HIGH_OPEN, window.size.x, SEAM_HIGH_OPEN))
			walls.append({"window": window, "along_x": false, "open": opens})
	return walls


## A lot may stand only where every lane wall it joins (1-2 cell slits
## bridged) stays within WALL_MAX and keeps clear of the lane's seam cells.
static func _lane_walls_allow(lane_walls: Array, lot: Rect2i, placed: Array[Rect2i]) -> bool:
	for wall: Dictionary in lane_walls:
		var window: Rect2i = wall.window
		if not window.intersects(lot):
			continue
		for open: Rect2i in wall.open:
			if open.intersects(lot):
				return false
		var along_x: bool = wall.along_x
		var origin: int = window.position.x if along_x else window.position.y
		var covered := PackedByteArray()
		covered.resize(window.size.x if along_x else window.size.y)
		for rect: Rect2i in placed + [lot]:
			var part := rect.intersection(window)
			if not part.has_area():
				continue
			var from: int = (part.position.x if along_x else part.position.y) - origin
			var to: int = (part.end.x if along_x else part.end.y) - origin
			for index in range(from, to):
				covered[index] = 1
		var lot_part := lot.intersection(window)
		var first: int = (lot_part.position.x if along_x else lot_part.position.y) - origin
		var last: int = (lot_part.end.x if along_x else lot_part.end.y) - origin - 1
		var gap := 0
		var t := first - 1
		while t >= 0:
			if covered[t] != 0:
				first = t
				gap = 0
			else:
				gap += 1
				if gap > 2:
					break
			t -= 1
		gap = 0
		t = last + 1
		while t < covered.size():
			if covered[t] != 0:
				last = t
				gap = 0
			else:
				gap += 1
				if gap > 2:
					break
			t += 1
		if last - first + 1 > WALL_MAX:
			return false
		# A wall an original lot already carries next to a seam may continue in
		# the neighbouring chunk: never lengthen it.
		for open: Rect2i in wall.open:
			var span := Rect2i(origin + first, window.position.y, last - first + 1, window.size.y) if along_x else Rect2i(window.position.x, origin + first, window.size.x, last - first + 1)
			for rect: Rect2i in placed:
				if rect.intersects(open) and rect.intersects(span):
					return false
	return true


## Building segments for the free run [start, end): the fewest attached
## segments, 3-cell openings between them, such that no wall exceeds
## WALL_MAX with the walls `before` and `after` the run joined (lengths
## including the gaps; 0 when an opening separates them). A wall that leaves
## no room for a 6-cell lot gets an opening next to it first. When the run
## cannot be filled whole, one segment stands against one side with an
## opening toward the other.
static func _infill_segments(start: int, end: int, before: Vector2i, after: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var segments: Array[Vector2i] = []
	var carry_lo := before.x
	var carry_hi := after.x
	if carry_lo > 0 and carry_lo + INFILL_MIN_LEN > WALL_MAX:
		start += INFILL_PASSAGE - before.y
		carry_lo = 0
	if carry_hi > 0 and carry_hi + INFILL_MIN_LEN > WALL_MAX:
		end -= INFILL_PASSAGE - after.y
		carry_hi = 0
	var span := end - start
	if span < INFILL_MIN_LEN:
		return segments
	for k in range(1, 9):
		var walls := span - INFILL_PASSAGE * (k - 1)
		if walls < k * INFILL_MIN_LEN:
			break
		var caps: Array[int] = []
		var total := 0
		for index in k:
			var cap := WALL_MAX
			if index == 0:
				cap -= carry_lo
			if index == k - 1:
				cap -= carry_hi
			caps.append(cap)
			total += cap
		if caps.min() < INFILL_MIN_LEN or walls > total:
			continue
		var lengths: Array[int] = []
		for index in k:
			lengths.append(INFILL_MIN_LEN)
		var extra := walls - k * INFILL_MIN_LEN
		while extra > 0:
			for index in k:
				if extra > 0 and lengths[index] < caps[index]:
					lengths[index] += 1
					extra -= 1
		for index in range(k - 1):
			var low := maxi(INFILL_MIN_LEN - lengths[index], lengths[index + 1] - caps[index + 1])
			var high := mini(caps[index] - lengths[index], lengths[index + 1] - INFILL_MIN_LEN)
			var shift := clampi(rng.randi_range(-2, 2), low, high)
			lengths[index] += shift
			lengths[index + 1] -= shift
		var cursor := start
		for length: int in lengths:
			segments.append(Vector2i(cursor, cursor + length))
			cursor += length + INFILL_PASSAGE
		return segments
	var against_lo := mini(WALL_MAX - carry_lo, span - (INFILL_PASSAGE if carry_hi > 0 else 0))
	if against_lo >= INFILL_MIN_LEN:
		segments.append(Vector2i(start, start + against_lo))
		return segments
	var against_hi := mini(WALL_MAX - carry_hi, span - (INFILL_PASSAGE if carry_lo > 0 else 0))
	if against_hi >= INFILL_MIN_LEN:
		segments.append(Vector2i(end - against_hi, end))
	return segments


## Fill one free run with attached lots in wall-bounded segments. The run keeps
## one rear depth (the attached neighbour's, else 7-8); each segment stands on
## its own setback step (_segment_setback), so the frontage line breaks between
## an original and the infill attached to it and between infill segments. The
## run's columns between segments, and next to a wall it may not join, are
## reserved openings.
func _infill_run(cm: Node, chunk: Node2D, coord: Vector2i, usable: Rect2i, align: Vector2i, run_start: int, run_end: int, free: PackedInt32Array, built: PackedByteArray, ahead: PackedByteArray, keepouts: Array[Rect2i], reserved: Array[Rect2i], placed: Array[Rect2i], cfg: Dictionary, rng: RandomNumberGenerator, extent: Rect2i, allow_row_house: bool, lane_walls: Array) -> void:
	if run_end - run_start < INFILL_MIN_LEN:
		return
	var count: int = usable.size.x if align.y != 0 else usable.size.y
	var left := _infill_neighbour(placed, usable, align, run_start - 1, count)
	var right := _infill_neighbour(placed, usable, align, run_end, count)
	var run_depth: int = 0
	if left.has_area():
		run_depth = left.size.y if align.y != 0 else left.size.x
	elif right.has_area():
		run_depth = right.size.y if align.y != 0 else right.size.x
	else:
		run_depth = rng.randi_range(7, 8)
	var segments := _infill_segments(run_start, run_end, _wall_before(built, run_start), _wall_after(built, run_end), rng)
	# Run columns left open: before, between and after the segments.
	var open_from := run_start
	for segment: Vector2i in segments + [Vector2i(run_end, run_end)]:
		if segment.x > open_from:
			var shallowest := free[open_from]
			for index in range(open_from, segment.x):
				shallowest = mini(shallowest, free[index])
			_reserve_opening(chunk, _infill_lot(usable, align, open_from, segment.x - open_from, mini(run_depth, shallowest)))
		open_from = segment.y
	var blockers: Array[Rect2i] = []
	blockers.append_array(keepouts)
	blockers.append_array(reserved)
	blockers.append_array(_infill_openings(chunk))
	var previous_step := 0
	for segment: Vector2i in segments:
		var step := _segment_setback(cm, coord, usable, align, segment, free, ahead, previous_step)
		previous_step = step
		var cursor: int = segment.x
		var remaining: int = segment.y - segment.x
		while remaining >= INFILL_MIN_LEN:
			var lot_len: int = remaining
			if remaining > INFILL_MAX_LEN:
				lot_len = rng.randi_range(8, 12)
				if remaining - lot_len < INFILL_MIN_LEN:
					lot_len = remaining - INFILL_MIN_LEN
			var avail: int = free[cursor]
			for index in range(cursor, cursor + lot_len):
				avail = mini(avail, free[index])
			var depth: int = clampi(run_depth, INFILL_MIN_DEPTH, avail - maxi(step, 0))
			var lot := _infill_lot(usable, align, cursor, lot_len, depth)
			# Positive steps move the lot away from the street, negative ones
			# toward it (the band's door direction points at the street).
			lot.position -= align * step
			var usage := _infill_usage(rng, lot_len, depth, allow_row_house)
			# A doorway must open onto ground, never toward a neighbour's wall;
			# a walk-through passage whose rear would be walled keeps one door.
			if _rect_can_place(lot, extent, blockers, placed) and _infill_threshold_clear(lot, align, placed, extent) and _lane_walls_allow(lane_walls, lot, placed):
				if usage == &"passage" and not _infill_threshold_clear(lot, -align, placed, extent):
					usage = &"shop"
				cfg["_frontage_step"] = step
				if _spawn_building_rect(cm, chunk, coord, lot, align, usage, keepouts, placed, cfg, rng, extent):
					for index in range(cursor, cursor + lot_len):
						built[index] = 1
			cursor += lot_len
			remaining -= lot_len


## The DOOR_APRON cells in front of the doorway `_spawn_building_rect` would cut
## on side `dir` of `lot`, three wide, are inside the chunk and outside every
## building.
static func _infill_threshold_clear(lot: Rect2i, dir: Vector2i, placed: Array[Rect2i], extent: Rect2i) -> bool:
	var center := Vector2i(lot.position.x + int(round(float(lot.size.x - 1) * 0.5)), lot.position.y + int(round(float(lot.size.y - 1) * 0.5)))
	var door := Vector2i.ZERO
	if dir == Vector2i(0, -1):
		door = Vector2i(center.x, lot.position.y)
	elif dir == Vector2i(0, 1):
		door = Vector2i(center.x, lot.end.y - 1)
	elif dir == Vector2i(1, 0):
		door = Vector2i(lot.end.x - 1, center.y)
	else:
		door = Vector2i(lot.position.x, center.y)
	var across := Vector2i(absi(dir.y), absi(dir.x))
	for step in range(1, DOOR_APRON + 1):
		for side in range(-1, 2):
			var cell := door + dir * step + across * side
			if not extent.has_point(cell):
				return false
			for other: Rect2i in placed:
				if other.has_point(cell):
					return false
	return true


static func _infill_usage(rng: RandomNumberGenerator, lot_len: int, depth: int, allow_row_house: bool) -> StringName:
	var roll: float = rng.randf()
	if lot_len >= 9 and roll < 0.15:
		return &"workshop"
	if lot_len >= 8 and depth >= 8 and roll < 0.30:
		return &"passage"
	if roll < 0.65 or not allow_row_house:
		return &"shop"
	return &"row_house"


## Medieval street pass (2026-10-21): the one-cell slit between this house and
## a neighbour already standing on the same south front line (east or west,
## at least three rows of common wall, the same street-facing door side) closes
## into a party wall, so the two read as one attached group; this house's
## facade and roof then run over it (RoofOverlay.party_extra_px,
## CityBlockKit "party_extra_px"). Street continuity only, after every RNG
## draw of this lot, so the pass off is unchanged. Both houses are non-civic
## rectangles (composed fronts); the decision reads the lot records
## (_note_lot), never the kits, so the physical slit is the same whether or
## not the city style draws them. A slit stays open where any of its cells is protected
## route, a keepout, a reserved box, a recorded opening or a door apron, or
## where it is the only way from the ground behind the row to the street (a
## flood fill over the blockers built so far). 1-2 cell slits already count
## as wall for the WALL_MAX passage bound, so closing one never lengthens a
## measured wall. Returns {} or {"edge": _DIR_W/_DIR_E, "cells": slit rect}.
func _party_slit(cm: Node, chunk: Node2D, rect: Rect2i, door_dir: Vector2i, placed: Array[Rect2i], keepouts: Array[Rect2i], cfg: Dictionary, civic: bool) -> Dictionary:
	if civic or door_dir.y == 0 or not bool(cfg.get("street_continuity", false)):
		return {}
	var lots: Dictionary = chunk.get_meta(&"_proc_lot_info", {})
	var data: ChunkBuildData = cm.get("_active_build_data")
	if data == null:
		return {}
	var cpc: int = int(cm._cells_per_chunk())
	for other: Rect2i in placed:
		var west := other.end.x + 1 == rect.position.x
		var east := rect.end.x + 1 == other.position.x
		if not (west or east) or other.end.y != rect.end.y:
			continue
		var top := maxi(other.position.y, rect.position.y)
		if rect.end.y - top < 3:
			continue
		# The neighbour's own record (kept whether or not the city style
		# draws kits, so physical geometry never depends on the style).
		var info: Dictionary = lots.get(other, {})
		if info.is_empty() or bool(info.civic) or bool(info.irregular) or info.door != door_dir:
			continue
		var slit := Rect2i(other.end.x if west else rect.end.x, top, 1, rect.end.y - top)
		if not _slit_free(chunk, slit, keepouts, cfg, data, float(cm.cell_size_px)):
			continue
		var back := Vector2i(slit.position.x, slit.position.y - 1) if door_dir.y > 0 else Vector2i(slit.position.x, slit.end.y)
		if not _reaches_street(chunk, data, back, slit, cpc):
			continue
		var cells: Dictionary = {}
		for y in range(slit.position.y, slit.end.y):
			cells[Vector2i(slit.position.x, y)] = true
		if cm.has_method("spawn_roofed_wall_cells"):
			cm.spawn_roofed_wall_cells(chunk, cells, {}, cells)
		else:
			cm._spawn_wall_cells(chunk, cells, {})
		_mark_building_walls(cm, cells, bool(cfg.get("city_block_style", false)))
		var slits: Array = chunk.get_meta(&"_proc_party_slits", [])
		slits.append(slit)
		chunk.set_meta(&"_proc_party_slits", slits)
		return {"edge": _DIR_W if west else _DIR_E, "cells": slit}
	return {}


## Lot record for the party-slit pass: civic (taller arcade fronts),
## irregular (L halls) and the street-facing door side of every building.
static func _note_lot(chunk: Node2D, rect: Rect2i, door_dir: Vector2i, civic: bool, irregular: bool) -> void:
	var lots: Dictionary = chunk.get_meta(&"_proc_lot_info", {})
	lots[rect] = {"civic": civic, "irregular": irregular, "door": door_dir}
	chunk.set_meta(&"_proc_lot_info", lots)


## The kit's civic rule (taller arcade front), from the lot alone.
func _lot_civic(cm: Node, coord: Vector2i, rect: Rect2i, template: StringName, cfg: Dictionary, building_secondary_id: int, configured_secondary_id: int) -> bool:
	var global_tl: Vector2i = coord * int(cm._cells_per_chunk()) + rect.grow(-1).position
	var building_id: int = int(_mix_seed(int(cm.world_seed), global_tl.x, global_tl.y, 77) & 0x7fffffff) + 1
	return bool(cfg.get("city_service_annex",false)) or building_secondary_id > 0 or (configured_secondary_id == 0 and template == &"workshop" and building_id % 3 == 0)


func _slit_free(chunk: Node2D, slit: Rect2i, keepouts: Array[Rect2i], cfg: Dictionary, data: ChunkBuildData, cell_px: float) -> bool:
	var avoid: Array[Rect2i] = []
	avoid.append_array(keepouts)
	for box: Rect2i in cfg.get("infill_reserved", []):
		avoid.append(box)
	avoid.append_array(_infill_openings(chunk))
	avoid.append_array(_door_aprons(chunk, cell_px))
	for box: Rect2i in avoid:
		if box.intersects(slit):
			return false
	var clear: Dictionary = chunk.get_meta(&"_proc_clear_cells", {})
	for y in range(slit.position.y, slit.end.y):
		var cell := Vector2i(slit.position.x, y)
		if clear.has(cell) or data.kind_at(cell) >= 0:
			return false
	return true


## Whether the ground behind a slit reaches protected route cells or the
## chunk's open seam ring without passing through the slit.
static func _reaches_street(chunk: Node2D, data: ChunkBuildData, start: Vector2i, slit: Rect2i, cpc: int) -> bool:
	if start.x < 0 or start.y < 0 or start.x >= cpc or start.y >= cpc or data.kind_at(start) >= 0:
		return true
	var clear: Dictionary = chunk.get_meta(&"_proc_clear_cells", {})
	var seen := PackedByteArray()
	seen.resize(cpc * cpc)
	var queue: Array[Vector2i] = [start]
	seen[start.y * cpc + start.x] = 1
	var head := 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		if clear.has(at) or at.x == 0 or at.y == 0 or at.x == cpc - 1 or at.y == cpc - 1:
			return true
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = at + dir
			if next.x < 0 or next.y < 0 or next.x >= cpc or next.y >= cpc or seen[next.y * cpc + next.x] != 0:
				continue
			seen[next.y * cpc + next.x] = 1
			if slit.has_point(next) or data.kind_at(next) >= 0:
				continue
			queue.append(next)
	return false


## East/west party walls shared with lots already standing (at least two cells
## of common wall and the same front edge, so the joined facade run stays on
## one line), as RoofOverlay direction bits.
static func _party_edges(rect: Rect2i, placed: Array[Rect2i]) -> int:
	var edges := 0
	for other: Rect2i in placed:
		var overlap: int = mini(other.end.y, rect.end.y) - maxi(other.position.y, rect.position.y)
		if overlap < 2 or other.end.y != rect.end.y:
			continue
		if other.end.x == rect.position.x:
			edges |= _DIR_W
		elif other.position.x == rect.end.x:
			edges |= _DIR_E
	return edges


# Generates a complete courtyard block in a district-fill chunk. These chunks form
# the one-chunk urban envelope around roads and stop the district reading as a road
# laid across grass.
func decorate_urban_fill(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	cfg: Dictionary
) -> Array[Rect2i]:
	var placed: Array[Rect2i] = []
	var cpc: int = int(chunk_manager._cells_per_chunk())
	if cpc < 24:
		return placed
	var chunk_rect := Rect2i(Vector2i.ZERO, Vector2i(cpc, cpc))
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 8123)

	var court_w: int = clampi(rng.randi_range(9, 13), 8, cpc - 16)
	var court_h: int = clampi(rng.randi_range(9, 13), 8, cpc - 16)
	var court_x: int = clampi(int(cpc / 2.0) - int(court_w / 2.0) + rng.randi_range(-2, 2), 7, cpc - court_w - 7)
	var court_y: int = clampi(int(cpc / 2.0) - int(court_h / 2.0) + rng.randi_range(-2, 2), 7, cpc - court_h - 7)
	var courtyard := Rect2i(Vector2i(court_x, court_y), Vector2i(court_w, court_h))
	var keepouts: Array[Rect2i] = [courtyard.grow(1)]

	var floor_rng := RandomNumberGenerator.new()
	floor_rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 8131)
	chunk_manager._stamp_floor_rect_cells_patchy(chunk, courtyard, int(cfg.get("courtyard_floor_tex", 8)), floor_rng, 0.88, -95)

	# Urban-access masks are reciprocal with the neighbouring chunk. Passages meet
	# the chunk edge at its centre, so both independently generated sides align.
	var passage_dirs: Array[Vector2i] = _passage_dirs_from_mask(int(cfg.get("urban_access_mask", 0)))
	if passage_dirs.is_empty():
		passage_dirs = _pick_courtyard_passage_dirs(chunk_manager, coord, rng)
	var passage_w: int = 3
	var edge_center: int = int(cpc / 2.0) - int(passage_w / 2.0)
	for passage_dir in passage_dirs:
		var passage := Rect2i()
		if passage_dir == Vector2i(0, -1):
			passage = Rect2i(Vector2i(edge_center, 0), Vector2i(passage_w, court_y + 1))
		elif passage_dir == Vector2i(0, 1):
			var passage_south_y: int = court_y + court_h - 1
			passage = Rect2i(Vector2i(edge_center, passage_south_y), Vector2i(passage_w, cpc - passage_south_y))
		elif passage_dir == Vector2i(-1, 0):
			passage = Rect2i(Vector2i(0, edge_center), Vector2i(court_x + 1, passage_w))
		else:
			var passage_east_x: int = court_x + court_w - 1
			passage = Rect2i(Vector2i(passage_east_x, edge_center), Vector2i(cpc - passage_east_x, passage_w))
		if passage.size.x > 0 and passage.size.y > 0:
			keepouts.append(passage.grow(1).intersection(chunk_rect))
			chunk_manager._stamp_floor_rect_cells_patchy(chunk, passage, int(cfg.get("passage_floor_tex", 4)), floor_rng, 0.80, -94)

	var clear_cells: Dictionary = ChunkShapeGen.rect_cells(courtyard.grow(-3))
	for passage_keepout in keepouts.slice(1):
		ChunkShapeGen.add_cells(clear_cells, ChunkShapeGen.rect_cells(passage_keepout))
	chunk.set_meta(&"_proc_clear_cells", clear_cells)

	# Fill the ring between the chunk edge and the courtyard. Keep the bands deep
	# enough for real interiors even after clipping; pedestrian passages carve the
	# deliberate gaps through these rows via keepouts.
	var north_h: int = maxi(0, court_y - 2)
	var south_y: int = court_y + court_h + 2
	var south_h: int = maxi(0, cpc - south_y - 1)
	var west_w: int = maxi(0, court_x - 2)
	var east_x: int = court_x + court_w + 2
	var east_w: int = maxi(0, cpc - east_x - 1)
	var bands: Array[Dictionary] = []
	_add_band(bands, Rect2i(Vector2i(1, 1), Vector2i(cpc - 2, north_h)), Vector2i(0, 1))
	_add_band(bands, Rect2i(Vector2i(1, south_y), Vector2i(cpc - 2, south_h)), Vector2i(0, -1))
	_add_band(bands, Rect2i(Vector2i(1, 1), Vector2i(west_w, cpc - 2)), Vector2i(1, 0))
	_add_band(bands, Rect2i(Vector2i(east_x, 1), Vector2i(east_w, cpc - 2)), Vector2i(-1, 0))

	var fill_cfg: Dictionary = cfg.duplicate(true)
	fill_cfg["frontage_target"] = float(cfg.get("urban_fill_frontage_target", 0.78))
	fill_cfg["parcel_length_min_cells"] = 7
	fill_cfg["parcel_length_max_cells"] = 12
	fill_cfg["parcel_depth_cells"] = 10
	fill_cfg["parcel_building_margin_cells"] = 0
	fill_cfg["parcel_loot_chance"] = float(cfg.get("urban_fill_loot_chance", 0.18))
	fill_cfg["local_encounter_enabled"] = false

	for band_variant in bands:
		var band_data: Dictionary = band_variant as Dictionary
		var band: Rect2i = band_data.get("rect", Rect2i()) as Rect2i
		var door_dir: Vector2i = band_data.get("door_dir", Vector2i.ZERO) as Vector2i
		if not _rect_inside_chunk(band, chunk_rect):
			continue
		_fill_frontage_band(chunk_manager, chunk, coord, band, door_dir, keepouts, placed, fill_cfg, rng, chunk_rect, false)

	if bool(cfg.get("street_continuity", false)):
		_infill_courtyard(chunk_manager, chunk, coord, courtyard, keepouts, placed, fill_cfg, chunk_rect)

	_decorate_courtyard_props(chunk_manager, chunk, courtyard, passage_dirs, rng)
	if bool(fill_cfg.get("city_block_style", false)):
		# Keep courtyard/access material ownership in the shared ground map.
		# Only trim local surrounds and shadows; don't invent road arms here.
		for kit: Node in chunk.get_children():
			if kit.is_in_group(&"city_block_building"):
				kit.set("_chunk_extent", Vector2.ONE*cpc*int(chunk_manager.cell_size_px))
				kit.trim_paving(placed, int(chunk_manager.cell_size_px))

	# Courtyard combat/ambush sockets, but no dormant enemies are created here.
	for socket_offset in [Vector2(court_w * 0.25, court_h * 0.5), Vector2(court_w * 0.75, court_h * 0.5), Vector2(court_w * 0.5, court_h * 0.25)]:
		var socket := Marker2D.new()
		socket.name = "CourtyardSpawnSocket"
		socket.position = (Vector2(courtyard.position) + socket_offset) * float(chunk_manager.cell_size_px)
		socket.add_to_group(&"enemy_spawn_socket")
		socket.set_meta("spawn_socket_kind", &"courtyard")
		chunk.add_child(socket)

	return placed


func _decorate_courtyard_props(chunk_manager: Node, chunk: Node2D, courtyard: Rect2i, passage_dirs: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	if not chunk_manager.has_method("_spawn_block"):
		return
	var prop_scene: PackedScene = chunk_manager.get("cover_half_scene") as PackedScene
	if prop_scene == null:
		return
	var candidates: Array[Vector2i] = [
		courtyard.position + Vector2i(2, 2),
		Vector2i(courtyard.position.x + courtyard.size.x - 3, courtyard.position.y + 2),
		Vector2i(courtyard.position.x + 2, courtyard.position.y + courtyard.size.y - 3),
		courtyard.position + courtyard.size - Vector2i(3, 3),
	]
	var budget: int = rng.randi_range(2, 3)
	for _i in range(budget):
		if candidates.is_empty():
			break
		var pick_index: int = rng.randi_range(0, candidates.size() - 1)
		var prop_cell: Vector2i = candidates[pick_index]
		candidates.remove_at(pick_index)
		# Keep the edge-facing half of a courtyard clearer when it is a formal access.
		var blocked_by_access: bool = false
		for passage_dir in passage_dirs:
			if passage_dir == Vector2i(0, -1) and prop_cell.y <= courtyard.position.y + 2:
				blocked_by_access = true
			elif passage_dir == Vector2i(0, 1) and prop_cell.y >= courtyard.position.y + courtyard.size.y - 3:
				blocked_by_access = true
			elif passage_dir == Vector2i(-1, 0) and prop_cell.x <= courtyard.position.x + 2:
				blocked_by_access = true
			elif passage_dir == Vector2i(1, 0) and prop_cell.x >= courtyard.position.x + courtyard.size.x - 3:
				blocked_by_access = true
		if blocked_by_access:
			continue
		chunk_manager.call("_spawn_block", chunk, prop_scene, prop_cell.x, prop_cell.y)


func _passage_dirs_from_mask(mask: int) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	if (mask & _DIR_N) != 0:
		dirs.append(Vector2i(0, -1))
	if (mask & _DIR_E) != 0:
		dirs.append(Vector2i(1, 0))
	if (mask & _DIR_S) != 0:
		dirs.append(Vector2i(0, 1))
	if (mask & _DIR_W) != 0:
		dirs.append(Vector2i(-1, 0))
	return dirs


func _pick_courtyard_passage_dirs(chunk_manager: Node, coord: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	var candidates: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for dir in candidates:
		if not chunk_manager.has_method("get_chunk_role"):
			continue
		var neighbor_role: StringName = StringName(chunk_manager.call("get_chunk_role", coord + dir))
		if neighbor_role != &"unplanned":
			dirs.append(dir)
	if dirs.is_empty():
		dirs.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	return dirs


func _add_band(bands: Array[Dictionary], rect: Rect2i, door_dir: Vector2i) -> void:
	if rect.size.x < 7 or rect.size.y < 7:
		return
	bands.append({"rect": rect, "door_dir": door_dir})


func _fill_frontage_band(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	band: Rect2i,
	door_dir: Vector2i,
	keepout_rects: Array[Rect2i],
	placed: Array[Rect2i],
	cfg: Dictionary,
	rng: RandomNumberGenerator,
	chunk_rect: Rect2i,
	force_one: bool
) -> bool:
	var margin: int = maxi(0, int(cfg.get("parcel_building_margin_cells", 1)))
	var usable: Rect2i = band.grow(-margin)
	if usable.size.x < 7 or usable.size.y < 7:
		return false

	var frontage_horizontal: bool = door_dir.y != 0
	var frontage_len: int = usable.size.x if frontage_horizontal else usable.size.y
	var depth_available: int = usable.size.y if frontage_horizontal else usable.size.x
	if frontage_len < 7 or depth_available < 7:
		return false

	var target: float = clampf(float(cfg.get("frontage_target", 0.84)), 0.35, 0.96)
	var min_len: int = clampi(int(cfg.get("parcel_length_min_cells", 7)), 6, 16)
	var max_len: int = clampi(int(cfg.get("parcel_length_max_cells", 13)), min_len, 20)
	var desired_coverage: int = maxi(min_len, int(round(float(frontage_len) * target)))
	var cursor: int = 0
	var coverage: int = 0
	var made_any: bool = false
	var safety: int = 0

	while cursor + min_len <= frontage_len and coverage < desired_coverage and safety < 12:
		safety += 1
		var remaining: int = frontage_len - cursor
		var lot_len: int = mini(rng.randi_range(min_len, max_len), remaining)
		if lot_len < min_len:
			break
		var template: StringName = _pick_template(rng, lot_len, cfg)
		if template == &"workshop":
			lot_len = mini(maxi(lot_len, 11), remaining)
		var depth_roll_max: int = maxi(7, mini(12, depth_available))
		var building_depth: int = clampi(rng.randi_range(7, depth_roll_max), 7, depth_available)
		if template == &"workshop":
			building_depth = depth_available

		var build_rect := Rect2i()
		if frontage_horizontal:
			var x0: int = usable.position.x + cursor
			var y0: int = usable.position.y
			if door_dir == Vector2i(0, 1):
				y0 = usable.position.y + usable.size.y - building_depth
			build_rect = Rect2i(Vector2i(x0, y0), Vector2i(lot_len, building_depth))
		else:
			var y0v: int = usable.position.y + cursor
			var x0v: int = usable.position.x
			if door_dir == Vector2i(1, 0):
				x0v = usable.position.x + usable.size.x - building_depth
			build_rect = Rect2i(Vector2i(x0v, y0v), Vector2i(building_depth, lot_len))

		# Phase 3: workshops and row buildings sometimes take an L footprint
		# with a recessed entrance, so streets stop reading as pure rectangles.
		# The workshop that carries the district's secondary objective always
		# takes the rect path: the L path builds its volumes without a
		# secondary id and never marks it assigned.
		var carries_secondary: bool = template == &"workshop" \
			and int(cfg.get("secondary_objective_id", 0)) > 0 \
			and not bool(cfg.get("_secondary_assigned", false))
		var irregular: bool = (template == &"workshop" or template == &"row_house") \
			and not carries_secondary \
			and lot_len >= 9 and building_depth >= 8 \
			and rng.randf() < float(cfg.get("parcel_l_chance", 0.35))
		var spawned: bool = false
		if irregular:
			spawned = _spawn_building_footprint(chunk_manager, chunk, coord, build_rect, door_dir, template, keepout_rects, placed, cfg, rng, chunk_rect)
		else:
			spawned = _spawn_building_rect(chunk_manager, chunk, coord, build_rect, door_dir, template, keepout_rects, placed, cfg, rng, chunk_rect)
		if spawned:
			made_any = true
			coverage += lot_len
			cursor += lot_len
		else:
			cursor += 2

		# One-cell separations read as attached rows. Occasional wider gaps are
		# deliberate service passages and visual breathing points.
		var gap: int = 1
		if rng.randf() < float(cfg.get("frontage_passage_chance", 0.24)):
			gap = rng.randi_range(2, 3)
		cursor += gap

	if force_one and not made_any:
		var forced_len: int = mini(maxi(min_len, 9), frontage_len)
		var forced_depth: int = mini(maxi(8, depth_available), depth_available)
		var forced_rect := Rect2i()
		if frontage_horizontal:
			var fy: int = usable.position.y + usable.size.y - forced_depth if door_dir == Vector2i(0, 1) else usable.position.y
			forced_rect = Rect2i(Vector2i(usable.position.x, fy), Vector2i(forced_len, forced_depth))
		else:
			var fx: int = usable.position.x + usable.size.x - forced_depth if door_dir == Vector2i(1, 0) else usable.position.x
			forced_rect = Rect2i(Vector2i(fx, usable.position.y), Vector2i(forced_depth, forced_len))
		made_any = _spawn_building_rect(chunk_manager, chunk, coord, forced_rect, door_dir, &"workshop", keepout_rects, placed, cfg, rng, chunk_rect)

	return made_any


func _pick_template(rng: RandomNumberGenerator, frontage_len: int, cfg: Dictionary) -> StringName:
	if int(cfg.get("secondary_objective_id", 0)) > 0 and not bool(cfg.get("_secondary_assigned", false)):
		return &"workshop"
	var roll: float = rng.randf()
	if frontage_len >= 11 and roll < 0.20:
		return &"workshop"
	if roll < 0.43:
		return &"shop"
	if roll < 0.60 and bool(cfg.get("passage_buildings_enabled", true)):
		return &"passage"
	return &"row_house"


func _spawn_building_rect(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	build_rect: Rect2i,
	door_dir: Vector2i,
	template: StringName,
	keepout_rects: Array[Rect2i],
	placed: Array[Rect2i],
	cfg: Dictionary,
	_rng: RandomNumberGenerator,
	chunk_rect: Rect2i
) -> bool:
	if not _rect_can_place(build_rect, chunk_rect, keepout_rects, placed):
		return false

	var cpc: int = int(chunk_manager._cells_per_chunk())
	var door_w: int = maxi(2, int(cfg.get("parcel_door_width", 2)))
	var apron_len: int = maxi(1, int(cfg.get("parcel_apron_len", 2)))
	var center_x: int = build_rect.position.x + int(round(float(build_rect.size.x - 1) * 0.5))
	var center_y: int = build_rect.position.y + int(round(float(build_rect.size.y - 1) * 0.5))
	var door_pos := Vector2i.ZERO
	if door_dir == Vector2i(0, -1):
		door_pos = Vector2i(center_x, build_rect.position.y)
	elif door_dir == Vector2i(0, 1):
		door_pos = Vector2i(center_x, build_rect.position.y + build_rect.size.y - 1)
	elif door_dir == Vector2i(1, 0):
		door_pos = Vector2i(build_rect.position.x + build_rect.size.x - 1, center_y)
	else:
		door_pos = Vector2i(build_rect.position.x, center_y)

	var entrances: Array[Dictionary] = [{"pos": door_pos, "dir": door_dir, "width": door_w}]
	if template == &"passage" and build_rect.size.x >= 8 and build_rect.size.y >= 8:
		var rear_dir: Vector2i = -door_dir
		var rear_pos: Vector2i = door_pos
		if rear_dir == Vector2i(0, -1):
			rear_pos = Vector2i(center_x, build_rect.position.y)
		elif rear_dir == Vector2i(0, 1):
			rear_pos = Vector2i(center_x, build_rect.position.y + build_rect.size.y - 1)
		elif rear_dir == Vector2i(1, 0):
			rear_pos = Vector2i(build_rect.position.x + build_rect.size.x - 1, center_y)
		else:
			rear_pos = Vector2i(build_rect.position.x, center_y)
		entrances.append({"pos": rear_pos, "dir": rear_dir, "width": door_w})

	var floor_tex: int = int(cfg.get("indoor_floor_tex", 3))
	if template == &"workshop":
		floor_tex = int(cfg.get("workshop_floor_tex", 4))
	elif template == &"row_house":
		floor_tex = int(cfg.get("residential_floor_tex", 2))
	var stamp_rng := RandomNumberGenerator.new()
	stamp_rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4013 + build_rect.position.x * 17 + build_rect.position.y * 31)
	chunk_manager._stamp_floor_rect_cells(chunk, build_rect, floor_tex, stamp_rng, float(cfg.get("indoor_floor_alpha", 0.95)), int(cfg.get("indoor_floor_z", -94)))

	var carve_rng := RandomNumberGenerator.new()
	carve_rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4027 + build_rect.position.x * 19 + build_rect.position.y * 23)
	var room_attempts: int = int(cfg.get("facility_room_attempts", 24))
	if template == &"row_house":
		room_attempts = 12
	elif template == &"shop":
		room_attempts = 18
	elif template == &"workshop":
		room_attempts = 10
	var room_min: Vector2i = Vector2i(4, 4)
	var room_max: Vector2i = Vector2i(maxi(5, mini(9, build_rect.size.x - 2)), maxi(5, mini(8, build_rect.size.y - 2)))
	var carve := RECT_FAC.carve_room_first(
		build_rect,
		carve_rng,
		room_attempts,
		room_min,
		room_max,
		1,
		1,
		float(cfg.get("facility_window_chance", 0.18)),
		entrances,
		floor_tex,
		int(cfg.get("facility_floor_corr_tex", 2))
	)

	var wall_cells: Dictionary = {}
	var window_cells: Dictionary = {}
	for wall_key in carve.wall_cells.keys():
		wall_cells[wall_key] = true
	for window_key in carve.window_cells.keys():
		window_cells[window_key] = true
	for window_key in window_cells.keys():
		if not wall_cells.has(window_key):
			window_cells.erase(window_key)
	# The carve's room partitions stand inside the roof: they draw under it
	# and appear when it fades (building pass 2026-09-27). The perimeter's
	# south faces stay visible below the roof's eave as the façade.
	var interior_walls: Dictionary = {}
	var inner := build_rect.grow(-1)
	for wall_key in wall_cells.keys():
		if inner.has_point(wall_key as Vector2i):
			interior_walls[wall_key] = true
	if chunk_manager.has_method("spawn_roofed_wall_cells"):
		chunk_manager.spawn_roofed_wall_cells(chunk, wall_cells, window_cells, interior_walls)
	else:
		chunk_manager._spawn_wall_cells(chunk, wall_cells, window_cells)
	_mark_building_walls(chunk_manager,wall_cells,bool(cfg.get("city_block_style",false)))

	# Infill architecture keeps its doors on record (vegetation and reachability
	# read them) without joining the ambient spawn sockets, so a denser street
	# does not pull hordes toward doorways.
	var spawn_socket: bool = bool(cfg.get("door_spawn_socket", true))
	for entrance in entrances:
		var entrance_pos: Vector2i = entrance.get("pos", Vector2i.ZERO) as Vector2i
		var entrance_dir: Vector2i = entrance.get("dir", Vector2i.ZERO) as Vector2i
		_stamp_door_apron(chunk_manager, chunk, coord, build_rect, entrance_pos, entrance_dir, apron_len, cfg, chunk_rect)
		var door_socket := Marker2D.new()
		door_socket.name = "DoorSpawnSocket" if spawn_socket else "DoorMarker"
		door_socket.position = (Vector2(entrance_pos + entrance_dir) + Vector2(0.5, 0.5)) * float(chunk_manager.cell_size_px)
		if spawn_socket:
			door_socket.add_to_group(&"enemy_spawn_socket")
		door_socket.set_meta("spawn_socket_kind", &"door")
		door_socket.set_meta(&"door_dir", entrance_dir)
		chunk.add_child(door_socket)

	var configured_secondary_id: int = int(cfg.get("secondary_objective_id", 0))
	var building_secondary_id: int = 0
	var building_local_encounter: bool = false
	if configured_secondary_id > 0 and not bool(cfg.get("_secondary_assigned", false)):
		building_secondary_id = configured_secondary_id
		building_local_encounter = bool(cfg.get("local_encounter_enabled", false))
		cfg["_secondary_assigned"] = true
	var building_loot_chance: float = float(cfg.get("parcel_loot_chance", 0.22))
	if configured_secondary_id > 0 and building_secondary_id == 0:
		building_loot_chance = float(cfg.get("ambient_parcel_loot_chance", 0.24))

	if INDOOR_VOLUME_SCENE != null:
		var interior: Rect2i = build_rect.grow(-1)
		if interior.size.x > 0 and interior.size.y > 0:
			var volume := INDOOR_VOLUME_SCENE.instantiate() as IndoorVolume
			if volume != null:
				var global_tl: Vector2i = coord * cpc + interior.position
				var building_id: int = int(_mix_seed(int(chunk_manager.world_seed), global_tl.x, global_tl.y, 77) & 0x7fffffff) + 1
				var loot_cfg: Dictionary = {
					"exploration_loot_enabled": bool(cfg.get("exploration_loot_enabled",true)),
					"small_loot_chance": building_loot_chance,
					"small_count_min": int(cfg.get("parcel_loot_count_min", 1)),
					"small_count_max": int(cfg.get("parcel_loot_count_max", 1)),
					"small_rarity_min": int(cfg.get("parcel_loot_rarity_min", 3)),
					"small_rarity_max": int(cfg.get("parcel_loot_rarity_max", 6)),
					"small_rarity_bonus_per_segment": int(cfg.get("parcel_loot_rarity_bonus_per_segment", 0)),
					"scatter_radius_px": float(cfg.get("parcel_loot_scatter_radius", 24.0)),
					"pickup_delay": float(cfg.get("parcel_loot_pickup_delay", 0.15)),
					"local_encounter_enabled": building_local_encounter,
					"local_encounter_count": int(cfg.get("local_encounter_count", 5)),
					"secondary_objective_id": building_secondary_id,
				}
				volume.configure(global_tl, interior.size, int(chunk_manager.cell_size_px), building_id, loot_cfg)
				if bool(cfg.get("city_street_infill", false)):
					volume.set_meta(&"city_street_infill", true)
					volume.visit_counts_as_exploration = false
				chunk.add_child(volume)
				var entry_perp := Vector2(-door_dir.y, door_dir.x)
				var entry_center := Vector2(door_pos) + Vector2(0.5, 0.5) + entry_perp * (float(door_w - 1) * 0.5 - float(door_w >> 1))
				volume.configure_presentation_entry(chunk.to_global(entry_center * float(chunk_manager.cell_size_px)), Vector2(door_dir), float(door_w * chunk_manager.cell_size_px))
				if ROOF_OVERLAY_SCENE != null:
					var roof := ROOF_OVERLAY_SCENE.instantiate()
					chunk.add_child(roof)
					var street_infill := bool(cfg.get("city_street_infill", false))
					var party_edges := _party_edges(build_rect, placed) if street_infill else 0
					var civic := _lot_civic(chunk_manager, coord, build_rect, template, cfg, building_secondary_id, configured_secondary_id)
					# Medieval street pass: a one-cell slit to a neighbour on the
					# same front line closes into a party wall (house groups).
					var slit := _party_slit(chunk_manager, chunk, build_rect, door_dir, placed, keepout_rects, cfg, civic)
					var party_extra := Vector2.ZERO
					if not slit.is_empty():
						party_edges |= int(slit.edge)
						party_extra = Vector2(float(chunk_manager.cell_size_px), 0.0) if int(slit.edge) == _DIR_W else Vector2(0.0, float(chunk_manager.cell_size_px))
						roof.set(&"party_extra_px", party_extra)
					if street_infill or not slit.is_empty():
						# Join the terrace: the roof runs over an east/west party
						# wall (and a closed slit) to the eave of the neighbour
						# already standing there.
						roof.set(&"party_edges", party_edges)
					if roof.has_method("configure"):
						roof.configure(build_rect, int(chunk_manager.cell_size_px), door_dir, volume, template, building_id, entrances)
					if bool(cfg.get("city_block_style", false)):
						var kit := CITY_KIT.new()
						if party_edges != 0: kit.set_meta(&"party_edges", party_edges)
						if party_extra != Vector2.ZERO: kit.set_meta(&"party_extra_px", party_extra)
						chunk.add_child(kit)
						kit.configure(build_rect, int(chunk_manager.cell_size_px), entrances, roof, civic, PackedVector2Array(), bool(cfg.get("city_shared_ground", false)), _district_profile(cfg, building_id, template))
						if bool(cfg.get("city_service_annex",false)): kit.set_meta(&"city_service_annex",true)
						if street_infill:
							kit.set_meta(&"city_street_infill",true)
							kit.set_meta(&"frontage_step",int(cfg.get("_frontage_step",0)))
						_add_domestic_interior(chunk_manager,kit,wall_cells,building_id)

	_note_lot(chunk, build_rect, door_dir, _lot_civic(chunk_manager, coord, build_rect, template, cfg, building_secondary_id, configured_secondary_id), false)
	placed.append(build_rect)
	return true


## Phase 3 (2026-09-25 handoff): an irregular hall building. The rect loses a
## rear-corner notch (an L) and may gain a one-cell recessed entrance bay;
## perimeter walls derive from the footprint cells, the interior stays one
## open hall (always reachable), and floor, collision, indoor volumes and the
## roof polygon all follow the same cells. Interior rooms stay a rectangle
## luxury — halls read as workshops and row buildings from the street.
func _spawn_building_footprint(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	build_rect: Rect2i,
	door_dir: Vector2i,
	template: StringName,
	keepout_rects: Array[Rect2i],
	placed: Array[Rect2i],
	cfg: Dictionary,
	rng: RandomNumberGenerator,
	chunk_rect: Rect2i
) -> bool:
	if not _rect_can_place(build_rect, chunk_rect, keepout_rects, placed):
		return false
	var cpc: int = int(chunk_manager._cells_per_chunk())
	var cell_px: int = int(chunk_manager.cell_size_px)
	var door_w: int = maxi(2, int(cfg.get("parcel_door_width", 2)))
	var apron_len: int = maxi(1, int(cfg.get("parcel_apron_len", 2)))

	# The notch bites the rear corner away from the street; wings A (front
	# slab, full frontage) and B (rear slab, flush to one side) tile the L.
	var horizontal: bool = door_dir.y != 0
	var front_len: int = build_rect.size.x if horizontal else build_rect.size.y
	var depth: int = build_rect.size.y if horizontal else build_rect.size.x
	@warning_ignore("integer_division")
	var notch_len: int = clampi(rng.randi_range(3, front_len / 2), 3, front_len - 5)
	@warning_ignore("integer_division")
	var notch_deep: int = clampi(rng.randi_range(2, depth / 2), 2, depth - 5)
	var flush_left: bool = rng.randf() < 0.5

	var wing_a := Rect2i()
	var wing_b := Rect2i()
	if horizontal:
		var front_at_top := door_dir == Vector2i(0, -1)
		var a_y := build_rect.position.y if front_at_top else build_rect.position.y + notch_deep
		wing_a = Rect2i(Vector2i(build_rect.position.x, a_y), Vector2i(front_len, depth - notch_deep))
		var b_y := build_rect.position.y + depth - notch_deep if front_at_top else build_rect.position.y
		var b_x := build_rect.position.x if flush_left else build_rect.position.x + notch_len
		wing_b = Rect2i(Vector2i(b_x, b_y), Vector2i(front_len - notch_len, notch_deep))
	else:
		var front_at_left := door_dir == Vector2i(-1, 0)
		var a_x := build_rect.position.x if front_at_left else build_rect.position.x + notch_deep
		wing_a = Rect2i(Vector2i(a_x, build_rect.position.y), Vector2i(depth - notch_deep, front_len))
		var b_x2 := build_rect.position.x + depth - notch_deep if front_at_left else build_rect.position.x
		var b_y2 := build_rect.position.y if flush_left else build_rect.position.y + notch_len
		wing_b = Rect2i(Vector2i(b_x2, b_y2), Vector2i(notch_deep, front_len - notch_len))

	var footprint: Dictionary = {}
	for wing in [wing_a, wing_b]:
		for y in range(wing.position.y, wing.position.y + wing.size.y):
			for x in range(wing.position.x, wing.position.x + wing.size.x):
				footprint[Vector2i(x, y)] = true

	# The door sits on the street edge of wing A; a recessed bay pulls it one
	# cell inward by removing the bay cells from the footprint, so the
	# perimeter wraps into the alcove by itself.
	@warning_ignore("integer_division")
	var center_along: int = wing_a.position.x + wing_a.size.x / 2 if horizontal else wing_a.position.y + wing_a.size.y / 2
	var door_pos := Vector2i.ZERO
	if door_dir == Vector2i(0, -1):
		door_pos = Vector2i(center_along, wing_a.position.y)
	elif door_dir == Vector2i(0, 1):
		door_pos = Vector2i(center_along, wing_a.position.y + wing_a.size.y - 1)
	elif door_dir == Vector2i(1, 0):
		door_pos = Vector2i(wing_a.position.x + wing_a.size.x - 1, center_along)
	else:
		door_pos = Vector2i(wing_a.position.x, center_along)
	var recess: bool = front_len >= 9 and rng.randf() < float(cfg.get("parcel_recess_chance", 0.5))
	var across := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
	if recess:
		@warning_ignore("integer_division")
		for step in range(-(door_w / 2) - 1, door_w / 2 + 2):
			footprint.erase(door_pos + across * step)
		door_pos += door_dir * -1  # one cell inward; the alcove is outside now

	# Perimeter walls come straight from the footprint; the interior is open.
	var wall_cells: Dictionary = {}
	var legacy_window_boundary: Dictionary = {}
	for cell_key in footprint.keys():
		var cell := cell_key as Vector2i
		# Include diagonal exposure at reflex corners. The wall kit/colliders
		# connect cardinal arms; a four-neighbor boundary alone leaves diagonal
		# gaps and isolated bars around the L and recessed entrance.
		for offset in [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]:
			if not footprint.has(cell + offset):
				wall_cells[cell] = true
				if offset.x == 0 or offset.y == 0: legacy_window_boundary[cell] = true
				break
	# The doorway: an opening of door_w in the (possibly recessed) front wall.
	@warning_ignore("integer_division")
	for step in range(-(door_w - 1) / 2, door_w / 2 + 1):
		wall_cells.erase(door_pos + across * step)
		legacy_window_boundary.erase(door_pos + across * step)
	# Windows on straight runs only, at the authored chance.
	var window_cells: Dictionary = {}
	var window_chance := float(cfg.get("facility_window_chance", 0.18))
	# Preserve the old window-roll schedule so healing a corner cannot change
	# the RNG state used for later parcel layouts and building identities.
	for cell_key in legacy_window_boundary.keys():
		var cell := cell_key as Vector2i
		var mask := 0
		if legacy_window_boundary.has(cell + Vector2i(0, -1)):
			mask |= 1
		if legacy_window_boundary.has(cell + Vector2i(1, 0)):
			mask |= 2
		if legacy_window_boundary.has(cell + Vector2i(0, 1)):
			mask |= 4
		if legacy_window_boundary.has(cell + Vector2i(-1, 0)):
			mask |= 8
		if (mask == 5 or mask == 10) and rng.randf() < window_chance:
			var actual_mask := 0
			for pair: Array in [[Vector2i.UP,1],[Vector2i.RIGHT,2],[Vector2i.DOWN,4],[Vector2i.LEFT,8]]:
				if wall_cells.has(cell+pair[0]): actual_mask |= int(pair[1])
			if actual_mask == 5 or actual_mask == 10: window_cells[cell] = true

	# Floors per wing, then the shared spawn/collision path.
	var floor_tex: int = int(cfg.get("workshop_floor_tex", 4)) if template == &"workshop" else int(cfg.get("residential_floor_tex", 2))
	var stamp_rng := RandomNumberGenerator.new()
	stamp_rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 5013 + build_rect.position.x * 17 + build_rect.position.y * 31)
	for wing in [wing_a, wing_b]:
		chunk_manager._stamp_floor_rect_cells(chunk, wing, floor_tex, stamp_rng, float(cfg.get("indoor_floor_alpha", 0.95)), int(cfg.get("indoor_floor_z", -94)))
	chunk_manager._spawn_wall_cells(chunk, wall_cells, window_cells)
	_mark_building_walls(chunk_manager,wall_cells,bool(cfg.get("city_block_style",false)))
	# This carver opens even-width doors along positive `across`; normalize
	# the north/east anchor for the city's signed doorway-core stamp, just
	# as the visual door record below does. Physical cells stay unchanged.
	var apron_door_pos := door_pos
	if bool(cfg.get("city_block_style", false)) and door_w % 2 == 0 and (door_dir == Vector2i.UP or door_dir == Vector2i.RIGHT):
		apron_door_pos += across
	_stamp_door_apron(chunk_manager, chunk, coord, build_rect, apron_door_pos, door_dir, apron_len + (1 if recess else 0), cfg, chunk_rect)
	var door_socket := Marker2D.new()
	door_socket.name = "DoorSpawnSocket"
	door_socket.position = (Vector2(door_pos + door_dir) + Vector2(0.5, 0.5)) * float(cell_px)
	door_socket.add_to_group(&"enemy_spawn_socket")
	door_socket.set_meta("spawn_socket_kind", &"door")
	door_socket.set_meta(&"door_dir", door_dir)
	chunk.add_child(door_socket)

	# Two indoor volumes tile the open interior exactly (wing A's grow(-1)
	# plus wing B's interior extended one row/column across the seam); both
	# carry one building identity, only the first carries loot rights.
	if INDOOR_VOLUME_SCENE != null:
		var interior_a: Rect2i = wing_a.grow(-1)
		# Wing B's interior drops its three walled margins and extends one
		# cell across the open seam into wing A, so the two volumes tile the
		# whole hall with no uncovered row at the join.
		var interior_b := Rect2i()
		if horizontal:
			if wing_a.position.y > wing_b.position.y:
				interior_b = Rect2i(wing_b.position + Vector2i(1, 1), Vector2i(wing_b.size.x - 2, wing_b.size.y))
			else:
				interior_b = Rect2i(wing_b.position + Vector2i(1, -1), Vector2i(wing_b.size.x - 2, wing_b.size.y))
		else:
			if wing_a.position.x > wing_b.position.x:
				interior_b = Rect2i(wing_b.position + Vector2i(1, 1), Vector2i(wing_b.size.x, wing_b.size.y - 2))
			else:
				interior_b = Rect2i(Vector2i(wing_b.position.x - 1, wing_b.position.y + 1), Vector2i(wing_b.size.x, wing_b.size.y - 2))
		var global_tl: Vector2i = coord * cpc + interior_a.position
		var building_id: int = int(_mix_seed(int(chunk_manager.world_seed), global_tl.x, global_tl.y, 78) & 0x7fffffff) + 1
		var loot_cfg: Dictionary = {
			"small_loot_chance": float(cfg.get("parcel_loot_chance", 0.22)),
			"small_count_min": int(cfg.get("parcel_loot_count_min", 1)),
			"small_count_max": int(cfg.get("parcel_loot_count_max", 1)),
			"small_rarity_min": int(cfg.get("parcel_loot_rarity_min", 3)),
			"small_rarity_max": int(cfg.get("parcel_loot_rarity_max", 6)),
			"small_rarity_bonus_per_segment": int(cfg.get("parcel_loot_rarity_bonus_per_segment", 0)),
			"scatter_radius_px": float(cfg.get("parcel_loot_scatter_radius", 24.0)),
			"pickup_delay": float(cfg.get("parcel_loot_pickup_delay", 0.15)),
			"local_encounter_enabled": false,
			"local_encounter_count": int(cfg.get("local_encounter_count", 5)),
			"secondary_objective_id": 0,
		}
		var volumes: Array = []
		for pair in [[interior_a, loot_cfg], [interior_b, {"small_loot_chance": 0.0}]]:
			var rect := pair[0] as Rect2i
			if rect.size.x <= 0 or rect.size.y <= 0:
				continue
			var volume := INDOOR_VOLUME_SCENE.instantiate() as IndoorVolume
			if volume == null:
				continue
			volume.configure(coord * cpc + rect.position, rect.size, cell_px, building_id, pair[1] as Dictionary)
			chunk.add_child(volume)
			if volumes.is_empty():
				var entry_center := Vector2(door_pos) + Vector2(0.5, 0.5) + Vector2(across) * (0.5 if door_w % 2 == 0 else 0.0)
				volume.configure_presentation_entry(chunk.to_global(entry_center * float(cell_px)), Vector2(door_dir), float(door_w * cell_px))
			volumes.append(volume)
		if ROOF_OVERLAY_SCENE != null and not volumes.is_empty():
			var roof := ROOF_OVERLAY_SCENE.instantiate()
			chunk.add_child(roof)
			if roof.has_method("configure_polygon"):
				var outline := _footprint_outline(footprint, cell_px)
				var facade := _edge_span_px(wing_a, door_dir, cell_px)
				# The irregular carver uses positive across coordinates. Roof and
				# dressing use signed perpendicular records; normalize the even
				# north/east anchor without moving any physically carved cell.
				var visual_door_pos := door_pos
				if door_w % 2 == 0 and (door_dir == Vector2i.UP or door_dir == Vector2i.RIGHT): visual_door_pos += across
				var visual_doors: Array = [{"pos":visual_door_pos,"dir":door_dir,"width":door_w}]
				roof.configure_polygon(outline, facade[0], facade[1], volumes, template, building_id,
					visual_doors, cell_px)
				if bool(cfg.get("city_block_style", false)):
					var kit := CITY_KIT.new()
					chunk.add_child(kit)
					kit.configure(build_rect, cell_px, visual_doors, roof, template == &"workshop" and building_id % 3 == 0, outline, bool(cfg.get("city_shared_ground", false)), _district_profile(cfg, building_id, template))
					_add_domestic_interior(chunk_manager,kit,wall_cells,building_id)

	_note_lot(chunk, build_rect, door_dir, true, true)
	placed.append(build_rect)
	return true


func _add_domestic_interior(chunk_manager: Node, kit: Node2D, wall_cells: Dictionary, building_id: int) -> void:
	var data := chunk_manager.get("_active_build_data") as ChunkBuildData
	if data == null:
		return
	# Only a building that will be furnished or get warm domestic masonry
	# (CityDomesticInterior._eligible / _stone_eligible) needs the context; it
	# is pure but scans the building's cells, so every other building skips it
	# (2026-10-21: the scan of all 1024 chunk cells was about half of each
	# building's build cost in every segment).
	if not DOMESTIC.eligible_kit(kit):
		return
	var context := DOMESTIC.context_for(kit,data,wall_cells,building_id)
	DOMESTIC.mark_walls(data,wall_cells,context)
	DOMESTIC.compose(kit,chunk_manager as ChunkManager,data,context)


func _district_profile(cfg: Dictionary, building_id: int, usage: StringName = &"") -> Dictionary:
	var family := StringName(cfg.get("district_family", &""))
	var profile := DISTRICT_PROFILES.resolve(&"" if bool(cfg.get("district_common_base_preview", false)) else family)
	profile["family_id"] = family
	profile["visual_seed"] = building_id
	profile["building_usage"] = usage
	return profile


## The closed outline of an orthogonal cell set, in pixels: boundary edges
## between footprint and outside, chained into one loop.
func _footprint_outline(footprint: Dictionary, cell_px: int) -> PackedVector2Array:
	var edges: Dictionary = {}   # corner -> Array of next corners
	for cell_key in footprint.keys():
		var cell := cell_key as Vector2i
		var corners := [cell, cell + Vector2i(1, 0), cell + Vector2i(1, 1), cell + Vector2i(0, 1)]
		var sides := [[Vector2i(0, -1), 0, 1], [Vector2i(1, 0), 1, 2], [Vector2i(0, 1), 2, 3], [Vector2i(-1, 0), 3, 0]]
		for side in sides:
			if not footprint.has(cell + (side[0] as Vector2i)):
				var from_corner: Vector2i = corners[side[1]]
				var to_corner: Vector2i = corners[side[2]]
				if not edges.has(from_corner):
					edges[from_corner] = []
				(edges[from_corner] as Array).append(to_corner)
	var chained: Array[Vector2i] = []
	if edges.is_empty():
		return PackedVector2Array()
	var start := edges.keys()[0] as Vector2i
	var current := start
	var guard := 0
	while guard < 4096:
		guard += 1
		chained.append(current)
		var nexts: Array = edges.get(current, [])
		if nexts.is_empty():
			break
		var next_corner := nexts.pop_back() as Vector2i
		if nexts.is_empty():
			edges.erase(current)
		current = next_corner
		if current == start:
			break
	# Merge collinear runs so the polygon carries real corners only.
	var out := PackedVector2Array()
	var count := chained.size()
	for i in range(count):
		var prev := chained[(i - 1 + count) % count]
		var here := chained[i]
		var next := chained[(i + 1) % count]
		if (here - prev).sign() != (next - here).sign():
			out.append(Vector2(here) * float(cell_px))
	return out


func _mark_building_walls(chunk_manager: Node, wall_cells: Dictionary, city_stone: bool) -> void:
	var data: ChunkBuildData = chunk_manager.get("_active_build_data")
	if data == null: return
	for cell: Vector2i in wall_cells:
		var index := data._index(cell)
		if index < 0: continue
		data.blocker_variant[index] |= ChunkBlockVisualCatalog.VARIANT_BUILDING_ENVELOPE
		if city_stone: data.blocker_variant[index] |= ChunkBlockVisualCatalog.VARIANT_CITY_STONE

func _edge_span_px(rect: Rect2i, door_dir: Vector2i, cell_px: int) -> Array:
	var tl := Vector2(rect.position) * float(cell_px)
	var br := Vector2(rect.position + rect.size) * float(cell_px)
	if door_dir == Vector2i(0, -1):
		return [tl, Vector2(br.x, tl.y)]
	if door_dir == Vector2i(0, 1):
		return [Vector2(tl.x, br.y), br]
	if door_dir == Vector2i(1, 0):
		return [Vector2(br.x, tl.y), br]
	return [tl, Vector2(tl.x, br.y)]


func _stamp_door_apron(chunk_manager: Node, chunk: Node2D, coord: Vector2i, build_rect: Rect2i, door_pos: Vector2i, door_dir: Vector2i, apron_len: int, cfg: Dictionary, chunk_rect: Rect2i) -> void:
	var apron := Rect2i()
	if bool(cfg.get("city_block_style", false)):
		# Only the actual doorway core owns opaque lane material. The fitted
		# footway and shared ground supply its shoulders; a five-cell stamp
		# underneath them would leave a visible rectangular paved yard.
		# Start at the real opening, including a recessed L-home threshold.
		var width := maxi(2, int(cfg.get("parcel_door_width", 2)))
		var perpendicular := Vector2i(-door_dir.y, door_dir.x)
		var first := door_pos + door_dir - perpendicular * (width >> 1)
		var last := first + perpendicular * (width - 1) + door_dir * (apron_len - 1)
		apron = Rect2i(first, Vector2i.ONE).merge(Rect2i(last, Vector2i.ONE))
	elif door_dir == Vector2i(0, -1):
		apron = Rect2i(Vector2i(door_pos.x - 2, build_rect.position.y - apron_len), Vector2i(5, apron_len))
	elif door_dir == Vector2i(0, 1):
		apron = Rect2i(Vector2i(door_pos.x - 2, build_rect.position.y + build_rect.size.y), Vector2i(5, apron_len))
	elif door_dir == Vector2i(1, 0):
		apron = Rect2i(Vector2i(build_rect.position.x + build_rect.size.x, door_pos.y - 2), Vector2i(apron_len, 5))
	else:
		apron = Rect2i(Vector2i(build_rect.position.x - apron_len, door_pos.y - 2), Vector2i(apron_len, 5))
	var clipped: Rect2i = apron.intersection(chunk_rect)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	var apron_rng := RandomNumberGenerator.new()
	apron_rng.seed = _mix_seed(int(chunk_manager.world_seed), coord.x, coord.y, 4099 + clipped.position.x * 7 + clipped.position.y * 11)
	chunk_manager._stamp_floor_rect_cells(chunk, clipped, int(cfg.get("door_apron_tex", 4)), apron_rng, float(cfg.get("door_apron_alpha", 0.92)), int(cfg.get("door_apron_z", -93)))


func _rect_inside_chunk(rect: Rect2i, chunk_rect: Rect2i) -> bool:
	return rect.size.x > 0 and rect.size.y > 0 and chunk_rect.encloses(rect)


func _rect_can_place(rect: Rect2i, chunk_rect: Rect2i, keepout_rects: Array[Rect2i], placed: Array[Rect2i]) -> bool:
	if not _rect_inside_chunk(rect, chunk_rect):
		return false
	for keepout in keepout_rects:
		if keepout.size.x > 0 and keepout.size.y > 0 and keepout.intersects(rect):
			return false
	for existing in placed:
		if existing.intersects(rect):
			return false
	return true


func _mix_seed(a: int, b: int, c: int, d: int) -> int:
	var x: int = a * 1103515245 + 12345
	x = int(x ^ (b * 374761393))
	x = int(x ^ (c * 668265263))
	x = int(x ^ (d * 2246822519))
	x = int((x ^ (x >> 13)) * 1274126177)
	x = int(x ^ (x >> 16))
	return x
