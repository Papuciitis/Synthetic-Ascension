extends RefCounted
## Plaza presentation (2026-10-21 plaza pass): squares framed by low planter
## edges, edged planting beds, a centrepiece and street furniture, after the
## concept plates (paved squares framed by buildings and contained planting,
## lamps, benches and stalls at their edges).
##
## Presentation first; physics changes in exactly one declared place: a
## plaza centrepiece (fountain or well) adds an explicit 2x2 HALF_COVER
## footprint in landmark squares and in service / civilian entry courts,
## placed with one open plaza cell all round and clear of objective anchors,
## protected route cells, connector sockets, boss courts, beds and the
## landmark sprite. Everything else keeps the generated physics: ring cells
## keep their WALL kind and mask (only presentation variant bits change),
## island planters reuse the island's existing half-cover cell, other props
## are visual or stand on an already blocked ring cell, and island cells that
## do not become a bed are re-paved with the plaza's own floor (ground only).
##
## Determinism: no generator RNG stream is read or advanced. Choices come from
## cell coordinates, already-made generator choices (ring, islands, landmark)
## and the named salts below mixed with the chunk seed, so reloads and any
## streaming order rebuild the same squares.
##
## Hooks (small, delimited): ChunkGenDistrict (island capture around the plaza
## floor decoration, ring mark after the walls spawn), ChunkGenImpl (island
## stamp capture, dressing post-pass after the environment deco),
## ChunkManager._add_environment_deco (landmark cell), and ChunkBlockRenderer /
## ChunkBlockVisualCatalog (PlazaEdgeKit pieces).

const KIT := preload("res://core/systems/world/chunks/PlazaEdgeKit.gd")
const DRESSING := preload("res://scenes/world/plazas/PlazaDressing.gd")

const SALT_CENTREPIECE := 0x51A7C0
const SALT_FURNITURE := 0x51A7F1
const SALT_BENCH := 0x51A7B3
const SALT_DRAIN := 0x51A7D7
const SALT_ACCENT := 0x51A7AC

const META_ISLANDS := &"_plaza_islands"
const META_PLAZA := &"_plaza_presentation"
const META_PLAN := &"_plaza_dressing_plan"
const META_LANDMARK := &"_landmark_cell"

## Plaza roles whose ring draws as a parapet (boss and miniboss courts,
## checkpoints and gates): no planting along an edge where tells must stay
## readable. Every other ring, ward courts included, is a planter.
const BALUSTRADE_ROLES: Array[StringName] = [&"checkpoint", &"miniboss_arena", &"boss_arena", &"gate"]
## Lamp pairs: the widest road mouths only, so a square is lit, not fenced.
const MAX_LAMP_PAIRS := 2
## Market stalls per square.
const MAX_STALLS := 2
## Families whose squares hold market stalls (plates 02, 05, 06, 15).
const MARKET_FAMILIES: Array[StringName] = [&"civilian_cutthrough", &"service_courtyards", &"inner_district_gate", &"gate_district"]
## Courts whose open, anchor-free squares take a centrepiece besides the
## landmark squares (plates 02 and 05).
const COURT_FAMILIES: Array[StringName] = [&"service_courtyards", &"civilian_cutthrough"]
## Civic / residential districts favour a fountain, working districts a well.
const FOUNTAIN_FAMILIES: Array[StringName] = [&"service_courtyards", &"civilian_cutthrough", &"inner_district_gate", &"gate_district", &"checkpoint_lanes", &"canal_services"]

## Dev and test toggle: false reproduces the pre-pass chunk exactly.
static var enabled := true
## Cost of the last dressing post-pass (plan, footprint and nodes), usec.
static var debug_last_usec := 0
static var debug_last_steps: Dictionary = {}

# Island capture state (generation is single threaded, one chunk at a time).
static var _capturing := false
static var _captured_stamps: Array = []
static var _capture_data: ChunkBuildData = null


# ------------------------------------------------------------- capture ----

## ChunkGenDistrict: before the plaza floor decoration.
static func begin_floor(gen: ChunkGenImpl) -> void:
	_captured_stamps = []
	_capture_data = _build_data(gen)
	_capturing = enabled


## ChunkGenImpl._stamp_floor_rect_cells_patchy: during the plaza floor
## decoration every patchy stamp is an island (the curb lip uses plain
## stamps). The blocker count at the stamp ties the island to the half-cover
## cell the decoration spawns for it right after.
static func note_island_stamp(rect: Rect2i, tex_index: int) -> void:
	if _capturing:
		_captured_stamps.append([rect, tex_index, _capture_data.occupied_indices().size() if _capture_data != null else -1])


## ChunkGenDistrict: after the plaza floor decoration. Records each island
## and the half-cover cell placed for it (if it survived the clear cells).
static func end_floor(_gen: ChunkGenImpl, chunk: Node2D) -> void:
	if not _capturing:
		return
	_capturing = false
	var data := _capture_data
	var islands: Array = []
	for k in _captured_stamps.size():
		var stamp: Array = _captured_stamps[k]
		var prop := Vector2i(-1, -1)
		if data != null and int(stamp[2]) >= 0:
			var occupied := data.occupied_indices()
			var stop: int = int(_captured_stamps[k + 1][2]) if k + 1 < _captured_stamps.size() else occupied.size()
			for i in range(int(stamp[2]), stop):
				var cell := data.cell_for_index(occupied[i])
				if data.kind_at(cell) == WorldBlockerGeometry.Kind.HALF_COVER:
					prop = cell
					break
		islands.append({"rect": stamp[0], "tex": int(stamp[1]), "prop": prop})
	_captured_stamps = []
	_capture_data = null
	chunk.set_meta(META_ISLANDS, islands)


## ChunkGenDistrict, after the walls are spawned: every ring cell that became
## a WALL keeps kind and mask and is marked as a low plaza edge.
static func mark_ring(gen: ChunkGenImpl, chunk: Node2D, role: StringName, archetype: StringName, plaza_cells: Dictionary, ring_cells: Dictionary) -> void:
	if not enabled or plaza_cells.is_empty():
		return
	var data := _build_data(gen)
	var balustrade := role in BALUSTRADE_ROLES or archetype == &"gate"
	var bits := KIT.VARIANT_PLAZA_EDGE | (KIT.VARIANT_BALUSTRADE if balustrade else 0)
	var marked: Array[Vector2i] = []
	if data != null:
		var ordered: Array = ring_cells.keys()
		ordered.sort()
		for cell: Vector2i in ordered:
			if data.kind_at(cell) != WorldBlockerGeometry.Kind.WALL:
				continue
			var index := data._index(cell)
			data.blocker_variant[index] = data.blocker_variant[index] | bits
			marked.append(cell)
	chunk.set_meta(META_PLAZA, {
		"role": role,
		"archetype": archetype,
		"balustrade": balustrade,
		"plaza": plaza_cells.duplicate(),
		"ring": marked,
	})


# ---------------------------------------------------------- post-pass -----

## ChunkGenImpl, after the environment deco (so the landmark sprite exists):
## the centrepiece footprint and the dressing node of a plaza chunk, or the
## notice boards of a street chunk with civic entries.
static func dress_chunk(gen: ChunkGenImpl, chunk: Node2D, coord: Vector2i) -> void:
	if not enabled or gen == null or gen.cm == null:
		return
	var started := Time.get_ticks_usec()
	_dress(gen, chunk, coord)
	debug_last_usec = Time.get_ticks_usec() - started


static func _dress(gen: ChunkGenImpl, chunk: Node2D, coord: Vector2i) -> void:
	if chunk.has_meta(META_PLAZA):
		var t0 := Time.get_ticks_usec()
		var plan := plan_plaza(gen, chunk, coord)
		var t1 := Time.get_ticks_usec()
		_apply_physical(gen, chunk, plan)
		chunk.set_meta(META_PLAN, plan)
		var t2 := Time.get_ticks_usec()
		_build_dressing(chunk, plan, gen.cell_size_px)
		debug_last_steps = {"plan": t1 - t0, "apply": t2 - t1, "nodes": Time.get_ticks_usec() - t2}
		return
	var boards := plan_notice_boards(chunk, gen.cell_size_px)
	if not boards.is_empty():
		var plan := {"notice_boards": boards}
		chunk.set_meta(META_PLAN, plan)
		_build_dressing(chunk, plan, gen.cell_size_px)


static func _build_dressing(chunk: Node2D, plan: Dictionary, cell_px: int) -> void:
	var node := DRESSING.new() as Node2D
	node.name = "PlazaDressing"
	chunk.add_child(node)
	node.call("compose", plan, cell_px)


## Pure plan of one plaza chunk from its generated state (no side effects).
static func plan_plaza(gen: ChunkGenImpl, chunk: Node2D, coord: Vector2i) -> Dictionary:
	var info: Dictionary = chunk.get_meta(META_PLAZA)
	var cells := gen._cells_per_chunk()
	var data := _build_data(gen)
	var plaza: Dictionary = info.plaza
	var ring: Array = info.ring
	var ring_set: Dictionary = {}
	for cell: Vector2i in ring:
		ring_set[cell] = true
	var role: StringName = info.role
	var family: StringName = gen.district_family
	var segment: int = Global.attempt_segment if Global != null else 2
	var base_seed := gen._seed_for_chunk(coord)
	var clear: Dictionary = chunk.get_meta(&"_proc_clear_cells", {})
	var boss: Rect2i = chunk.get_meta(&"_boss_arena_clear_rect", Rect2i())
	var anchor := anchor_box(role, segment, cells)
	var landmark := Rect2i()
	if chunk.has_meta(META_LANDMARK):
		var lc: Vector2i = chunk.get_meta(META_LANDMARK)
		landmark = Rect2i(lc - Vector2i(2, 2), Vector2i(4, 4))
	var sockets: Array[Vector2i] = socket_cells(chunk, gen.cell_size_px)
	# Islands become edged beds where they keep off the route; the part of an
	# island lying on (or beside) protected route cells is re-paved instead,
	# so no planting bed or grass patch ever sits in a road through a square.
	var islands: Array = []
	var reserved: Dictionary = {}
	for island: Dictionary in chunk.get_meta(META_ISLANDS, []):
		var bed := _bed_rect(island.rect, plaza, clear, data)
		var entry := island.duplicate()
		entry["bed"] = bed
		entry["route_sides"] = _route_sides(bed, clear) if bed.has_area() else 0
		islands.append(entry)
		if bed.has_area():
			ChunkShapeGen.add_rect(reserved, bed.grow(1))
	var plan := {
		"role": role, "family": family, "balustrade": bool(info.balustrade),
		"islands": islands, "centrepiece": {}, "lamps": [], "benches": [],
		"drains": [], "stalls": [],
	}
	var centroid := _centroid(plaza)
	# Ring cells a stall or wall fountain stands on (they stay physical and
	# keep their planter behind the prop); benches and lamps keep off them.
	var edge_taken: Dictionary = {}
	var market := not bool(info.balustrade) and family in MARKET_FAMILIES
	if market:
		plan.stalls = _plan_ring_stalls(ring_set, plaza, data, clear, anchor, landmark, base_seed)
		for stall: Dictionary in plan.stalls:
			edge_taken[stall.cell] = true
			edge_taken[(stall.cell as Vector2i) + Vector2i.RIGHT] = true
	if is_centrepiece_role(role, family) and not boss.has_area():
		var kind: StringName = &"plaza_fountain" if family in FOUNTAIN_FAMILIES else &"well_stone"
		var foot := _centrepiece_footprint(plaza, centroid, data, clear, anchor, landmark, sockets, reserved, cells, base_seed)
		if foot.has_area():
			plan.centrepiece = {"kind": kind, "cells": foot}
		elif kind == &"plaza_fountain":
			var wall := _wall_fountain(ring_set, plaza, data, clear, anchor, landmark, edge_taken, centroid, base_seed)
			if wall.has_area():
				plan.centrepiece = {"kind": &"wall_fountain", "cells": wall}
				for x in range(wall.position.x - 1, wall.end.x + 1):
					edge_taken[Vector2i(x, wall.position.y)] = true
	# Furniture keeps off beds, the centrepiece, the landmark and the cells
	# where an objective may spawn (its jitter box and one cell round it).
	var avoid: Dictionary = reserved.duplicate()
	if not (plan.centrepiece as Dictionary).is_empty():
		ChunkShapeGen.add_rect(avoid, (plan.centrepiece.cells as Rect2i).grow(1))
	if landmark.has_area():
		ChunkShapeGen.add_rect(avoid, landmark)
	if anchor.has_area():
		ChunkShapeGen.add_rect(avoid, anchor.grow(1))
	if market and (plan.stalls as Array).size() < MAX_STALLS:
		var open_stalls := _plan_open_stalls(plaza, ring_set, data, clear, anchor, avoid, MAX_STALLS - (plan.stalls as Array).size(), base_seed)
		for stall: Dictionary in open_stalls:
			ChunkShapeGen.add_rect(avoid, Rect2i(stall.cell, Vector2i(2, 1)).grow(1))
		plan.stalls.append_array(open_stalls)
	plan.lamps = _plan_lamps(plaza, ring_set, data, clear, centroid, avoid, edge_taken, boss, cells)
	if not bool(info.balustrade):
		plan.benches = _plan_benches(ring_set, plaza, data, clear, edge_taken, avoid, base_seed)
	plan.drains = _plan_drains(plaza, data, clear, avoid, boss, base_seed)
	if not bool(info.balustrade):
		plan["accents"] = _plan_accents(ring_set, data, plan.lamps, edge_taken, avoid, base_seed)
	plan["repave_tex"] = _plaza_floor_tex(data, plaza)
	return plan


## Cypress accents in up to two closed planter ends (a run end with one arm)
## that no lamp or stall uses: contained vertical planting on blocked support.
static func _plan_accents(ring_set: Dictionary, data: ChunkBuildData, lamps: Array, edge_taken: Dictionary, avoid: Dictionary, base_seed: int) -> Array:
	if data == null:
		return []
	var lit: Dictionary = {}
	for lamp: Dictionary in lamps:
		lit[lamp.cell] = true
	var ends: Array = []
	for key in ring_set.keys():
		var cell: Vector2i = key
		var mask := data.mask_at(cell) & 15
		if mask not in [WorldBlockerGeometry.N, WorldBlockerGeometry.E, WorldBlockerGeometry.S, WorldBlockerGeometry.W]:
			continue
		if lit.has(cell) or edge_taken.has(cell) or avoid.has(cell):
			continue
		ends.append(cell)
	var accents: Array = []
	for cell: Vector2i in _shuffled(ends, base_seed, SALT_ACCENT):
		if accents.size() >= 2:
			break
		var far := true
		for other: Dictionary in accents:
			if (other.cell as Vector2i).distance_squared_to(cell) < 36:
				far = false
		if far:
			accents.append({"cell": cell})
	return accents


## The largest rectangle of an island that stays inside the plaza and off
## every protected route cell; empty when it is smaller than 2 x 2.
static func _bed_rect(island: Rect2i, plaza: Dictionary, clear: Dictionary, data: ChunkBuildData) -> Rect2i:
	var table := _summed(island, plaza, clear, {}, data, island)
	var best := Rect2i()
	for y0 in range(island.size.y):
		for x0 in range(island.size.x):
			for y1 in range(y0 + 2, island.size.y + 1):
				for x1 in range(x0 + 2, island.size.x + 1):
					var area := (x1 - x0) * (y1 - y0)
					if area > best.get_area() and _window(table, island.size.x, x0, y0, x1, y1) == area:
						best = Rect2i(island.position + Vector2i(x0, y0), Vector2i(x1 - x0, y1 - y0))
	return best


## Sides of `rect` (N=1, E=2, S=4, W=8) with a protected route cell directly
## beyond them: the bed's kerb hugs those sides instead of spreading.
static func _route_sides(rect: Rect2i, clear: Dictionary) -> int:
	var sides := 0
	for x in range(rect.position.x - 1, rect.end.x + 1):
		if clear.has(Vector2i(x, rect.position.y - 1)): sides |= 1
		if clear.has(Vector2i(x, rect.end.y)): sides |= 4
	for y in range(rect.position.y - 1, rect.end.y + 1):
		if clear.has(Vector2i(rect.end.x, y)): sides |= 2
		if clear.has(Vector2i(rect.position.x - 1, y)): sides |= 8
	return sides


## Summed-area table over `area` ((w+1) x (h+1), row major) of the plaza
## cells that are off the route (`clear`), outside `reserved` and unblocked
## (blockers inside `own` excepted). An empty `clear` and null `data` count
## every plaza cell.
static func _summed(area: Rect2i, plaza: Dictionary, clear: Dictionary, reserved: Dictionary, data: ChunkBuildData, own: Rect2i) -> PackedInt32Array:
	var w := area.size.x + 1
	var table := PackedInt32Array()
	table.resize(w * (area.size.y + 1))
	for y in range(area.size.y):
		var row := 0
		for x in range(area.size.x):
			var cell := area.position + Vector2i(x, y)
			var ok := plaza.has(cell) and not clear.has(cell) and not reserved.has(cell)
			if ok and data != null and data.kind_at(cell) >= 0 and not own.has_point(cell):
				ok = false
			row += 1 if ok else 0
			table[(y + 1) * w + x + 1] = table[y * w + x + 1] + row
	return table


## Count of ok cells in the local window [x0, x1) x [y0, y1).
static func _window(table: PackedInt32Array, width: int, x0: int, y0: int, x1: int, y1: int) -> int:
	var w := width + 1
	return table[y1 * w + x1] - table[y0 * w + x1] - table[y1 * w + x0] + table[y0 * w + x0]


## The plaza's own paving index, read back from its recorded floor stamp.
static func _plaza_floor_tex(data: ChunkBuildData, plaza: Dictionary) -> int:
	if data == null:
		return -1
	var packed := data.floor_rect_and_style
	for i in data.floor_stamp_count():
		var at := i * 6
		if packed[at + 5] != -94 or absf(data.floor_alpha[i] - 0.95) > 0.011:
			continue
		var rect := Rect2i(packed[at], packed[at + 1], packed[at + 2], packed[at + 3])
		if ChunkShapeGen.intersects_rect(plaza, rect):
			return packed[at + 4]
	return -1


static func is_centrepiece_role(role: StringName, family: StringName) -> bool:
	if role == &"landmark_plaza":
		return true
	return role == &"entry_court" and family in COURT_FAMILIES


## Chunk-centred objective anchor box R(16-j, 16-j, 2j, 2j): wardstone j=5 in
## S2 (else 4), exit gate and wager shrine 3, cursed vault 2, primary 0; the
## player start (entry court) and a reward spawner (exploration end, which
## can also hold the vault) reserve 3. Empty for roles without an anchor.
static func anchor_box(role: StringName, segment: int, cells: int) -> Rect2i:
	var j := -1
	match role:
		&"wardstone_court":
			j = 5 if segment == 2 else 4
		&"gate", &"secondary_wager_shrine", &"entry_court", &"exploration_reward":
			j = 3
		&"secondary_reward_building", &"secondary_alley_cache":
			j = 3
		&"primary_objective":
			j = 0
	if j < 0:
		return Rect2i()
	var half := cells >> 1
	# A zero box still reserves the anchor's own cells around the centre.
	return Rect2i(half - j, half - j, 2 * j, 2 * j) if j > 0 else Rect2i(half - 1, half - 1, 2, 2)


static func socket_cells(chunk: Node2D, cell_px: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for child: Node in chunk.get_children():
		if child is Marker2D and child.is_in_group(&"enemy_spawn_socket"):
			out.append(Vector2i(((child as Marker2D).position / float(cell_px)).floor()))
	return out


# ----------------------------------------------------------- centrepiece --

static func _centrepiece_footprint(plaza: Dictionary, centroid: Vector2, data: ChunkBuildData, clear: Dictionary, anchor: Rect2i, landmark: Rect2i, sockets: Array[Vector2i], reserved: Dictionary, cells: int, base_seed: int) -> Rect2i:
	var bounds := ChunkShapeGen.bounds_of(plaza)
	# Cells a footprint or its one-cell walkway may use: open plaza paving off
	# the route, blockers and beds. One table makes each 4 x 4 test O(1).
	var free := _summed(bounds, plaza, clear, reserved, data, Rect2i())
	var paved := _summed(bounds, plaza, {}, {}, null, Rect2i())
	var inner := Rect2i(Vector2i(2, 2), Vector2i(cells - 4, cells - 4))
	var best := Rect2i()
	var best_score := INF
	for y in range(1, bounds.size.y - 2):
		for x in range(1, bounds.size.x - 2):
			# The 4 x 4 window: the 2 x 2 footprint and its walkway ring.
			if _window(free, bounds.size.x, x - 1, y - 1, x + 3, y + 3) != 16:
				continue
			var foot := Rect2i(bounds.position + Vector2i(x, y), Vector2i(2, 2))
			if not _footprint_ok(foot, inner, anchor, landmark, sockets):
				continue
			var centre := Vector2(foot.position) + Vector2.ONE
			var score := centre.distance_squared_to(centroid) + float(_hash(base_seed, SALT_CENTREPIECE, foot.position) % 997) * 0.0001
			# Prefer a second ring of paving round it where the square allows.
			var x0 := maxi(0, x - 2)
			var y0 := maxi(0, y - 2)
			var x1 := mini(bounds.size.x, x + 4)
			var y1 := mini(bounds.size.y, y + 4)
			if _window(paved, bounds.size.x, x0, y0, x1, y1) != 36:
				score += 40.0
			if score < best_score:
				best_score = score
				best = foot
	return best


static func _footprint_ok(foot: Rect2i, inner: Rect2i, anchor: Rect2i, landmark: Rect2i, sockets: Array[Vector2i]) -> bool:
	if not inner.encloses(foot):
		return false
	if anchor.has_area() and foot.grow(1).intersects(anchor):
		return false
	if landmark.has_area() and foot.intersects(landmark):
		return false
	for socket: Vector2i in sockets:
		if foot.grow(2).has_point(socket):
			return false
	return true


## A wall fountain standing on two consecutive north-edge ring cells (already
## blocked), its basin facing into the square: small squares where no free
## 2x2 fits. No new physics.
static func _wall_fountain(ring_set: Dictionary, plaza: Dictionary, data: ChunkBuildData, clear: Dictionary, anchor: Rect2i, landmark: Rect2i, edge_taken: Dictionary, centroid: Vector2, base_seed: int) -> Rect2i:
	var best := Rect2i()
	var best_score := INF
	for key in ring_set.keys():
		var cell: Vector2i = key
		var right := cell + Vector2i(1, 0)
		if not _north_edge(cell, ring_set, plaza, data) or not _north_edge(right, ring_set, plaza, data):
			continue
		if edge_taken.has(cell) or edge_taken.has(right):
			continue
		var front := Rect2i(cell + Vector2i(0, 1), Vector2i(2, 2))
		if not ChunkShapeGen.rect_inside(plaza, front) or ChunkShapeGen.intersects_rect(clear, front):
			continue
		var span := Rect2i(cell, Vector2i(2, 3))
		if (anchor.has_area() and span.intersects(anchor)) or (landmark.has_area() and span.intersects(landmark)):
			continue
		var score := (Vector2(cell) + Vector2(1.0, 1.0)).distance_squared_to(centroid) + float(_hash(base_seed, SALT_CENTREPIECE, cell) % 997) * 0.0001
		if score < best_score:
			best_score = score
			best = Rect2i(cell, Vector2i(2, 1))
	return best


## A straight east-west ring cell on the square's north side (plaza below).
static func _north_edge(cell: Vector2i, ring_set: Dictionary, plaza: Dictionary, data: ChunkBuildData) -> bool:
	if not ring_set.has(cell) or not plaza.has(cell + Vector2i(0, 1)):
		return false
	if data == null:
		return false
	var mask := data.mask_at(cell) & 15
	return (mask & (WorldBlockerGeometry.N | WorldBlockerGeometry.S)) == 0 and mask != 0


# ------------------------------------------------------------- furniture --

## Lamp pairs where a road enters the square: the outline cells flanking each
## run of protected route cells on the plaza outline, in angular order.
static func _plan_lamps(plaza: Dictionary, ring_set: Dictionary, data: ChunkBuildData, clear: Dictionary, centroid: Vector2, avoid: Dictionary, edge_taken: Dictionary, boss: Rect2i, cells: int) -> Array:
	var bounds := Rect2i(Vector2i(1, 1), Vector2i(cells - 2, cells - 2))
	var outline: Array = []
	for key in ChunkShapeGen.outline_of_fill(plaza).keys():
		var cell: Vector2i = key
		if bounds.has_point(cell):
			outline.append(cell)
	if outline.size() < 8:
		return []
	# Angular order around the square (one angle per cell; cell index ties).
	var keys := PackedInt64Array()
	for cell: Vector2i in outline:
		var angle := (Vector2(cell) + Vector2(0.5, 0.5) - centroid).angle()
		keys.append((int(round((angle + PI) * 1000000.0)) << 12) | (posmod(cell.y, 64) << 6) | posmod(cell.x, 64))
	keys.sort()
	outline.clear()
	for key in keys:
		var x := int(key & 63)
		var y := int((key >> 6) & 63)
		outline.append(Vector2i(x if x < 48 else x - 64, y if y < 48 else y - 64))
	var total := outline.size()
	var mouth: Array[bool] = []
	for cell: Vector2i in outline:
		mouth.append(clear.has(cell))
	if not mouth.has(true) or not mouth.has(false):
		return []
	# Start the walk on a non-mouth cell so every run is contiguous.
	var start := mouth.find(false)
	var runs: Array = []
	var i := 0
	while i < total:
		if not mouth[(start + i) % total]:
			i += 1
			continue
		var run_start := i
		while i < total and mouth[(start + i) % total]:
			i += 1
		if i - run_start >= 2:
			runs.append([i - run_start, run_start, i])
	# Widest mouths first (roads before courtyard passages); ties by order.
	runs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var lamps: Array = []
	var used: Dictionary = {}
	for run: Array in runs.slice(0, MAX_LAMP_PAIRS):
		var run_start: int = run[1]
		var run_end: int = run[2]
		var flanks := [[(start + run_start - 1 + total) % total, (start + run_start) % total], [(start + run_end) % total, (start + run_end - 1) % total]]
		for pair: Array in flanks:
			var cell: Vector2i = outline[pair[0]]
			var mouth_cell: Vector2i = outline[pair[1]]
			if clear.has(cell) or avoid.has(cell) or edge_taken.has(cell) or used.has(cell):
				continue
			# A lamp stands on a ring cell (blocked support) or open ground.
			if data != null and data.kind_at(cell) >= 0 and not ring_set.has(cell):
				continue
			if boss.has_area() and boss.has_point(cell):
				continue
			var crowded := false
			for other: Dictionary in lamps:
				if (other.cell as Vector2i).distance_squared_to(cell) < 5:
					crowded = true
			if crowded:
				continue
			used[cell] = true
			# Stand at the side facing the road mouth, not in the planting.
			var toward := Vector2(mouth_cell - cell).limit_length(1.0)
			lamps.append({"cell": cell, "support": ring_set.has(cell), "toward": toward})
	return lamps


## Stone benches facing the square: beside straight planter runs (in front of
## a north-edge planter, or behind a south-edge one, drawn under it), else on
## the last paving row of an open edge. Visual only; at most two.
static func _plan_benches(ring_set: Dictionary, plaza: Dictionary, data: ChunkBuildData, clear: Dictionary, edge_taken: Dictionary, avoid: Dictionary, base_seed: int) -> Array:
	if data == null:
		return []
	var straight := WorldBlockerGeometry.E | WorldBlockerGeometry.W
	var spans: Array = []
	for key in ring_set.keys():
		var cell: Vector2i = key
		var right := cell + Vector2i(1, 0)
		if not ring_set.has(right) or (data.mask_at(cell) & 15) != straight or (data.mask_at(right) & 15) != straight:
			continue
		if edge_taken.has(cell) or edge_taken.has(right):
			continue
		for side in [1, -1]:
			var seat := cell + Vector2i(0, side)
			var seat_right := right + Vector2i(0, side)
			if not plaza.has(seat) or not plaza.has(seat_right) or avoid.has(seat) or avoid.has(seat_right):
				continue
			if data.kind_at(seat) >= 0 or data.kind_at(seat_right) >= 0:
				continue
			spans.append([cell, side])
	spans = _shuffled_spans(spans, base_seed, SALT_BENCH)
	# Open edges (no surviving ring): a bench on the square's last paving row
	# facing in, purely visual, after the planter-backed ones.
	var open_spans: Array = []
	for key in plaza.keys():
		var cell: Vector2i = key
		# Only the square's north and south edge rows can hold one.
		if plaza.has(cell + Vector2i.UP) and plaza.has(cell + Vector2i.DOWN):
			continue
		var right := cell + Vector2i(1, 0)
		if not plaza.has(right):
			continue
		for side in [1, -1]:
			var back := cell - Vector2i(0, side)
			var back_right := right - Vector2i(0, side)
			if plaza.has(back) or plaza.has(back_right) or ring_set.has(back) or ring_set.has(back_right):
				continue
			if avoid.has(cell) or avoid.has(right) or data.kind_at(cell) >= 0 or data.kind_at(right) >= 0:
				continue
			if clear.has(cell) or clear.has(right) or clear.has(back) or clear.has(back_right):
				continue
			if data.kind_at(back) >= 0 or data.kind_at(back_right) >= 0:
				continue
			open_spans.append([cell, side])
	open_spans = _shuffled_spans(open_spans, base_seed, SALT_BENCH + 1)
	var benches: Array = []
	for group: Array in [spans, open_spans]:
		for span: Array in group:
			if benches.size() >= 2:
				break
			var cell: Vector2i = span[0]
			var far := true
			for other: Dictionary in benches:
				if absi((other.cell as Vector2i).x - cell.x) + absi((other.cell as Vector2i).y - cell.y) < 6:
					far = false
			if far:
				benches.append({"cell": cell, "side": int(span[1]), "open": group == open_spans})
	return benches


## [cell, side] spans in the stable salted order of their cells.
static func _shuffled_spans(spans: Array, base_seed: int, salt: int) -> Array:
	var by_cell: Dictionary = {}
	var cells: Array = []
	for span: Array in spans:
		if not by_cell.has(span[0]):
			by_cell[span[0]] = []
			cells.append(span[0])
		(by_cell[span[0]] as Array).append(span)
	var out: Array = []
	for cell: Vector2i in _shuffled(cells, base_seed, salt):
		out.append_array(by_cell[cell])
	return out


## Market stalls on the square's north side, counters facing in: first on
## two straight north-edge planter cells each (the ring stays physical behind
## them), as a pair where the run allows.
static func _plan_ring_stalls(ring_set: Dictionary, plaza: Dictionary, data: ChunkBuildData, clear: Dictionary, anchor: Rect2i, landmark: Rect2i, base_seed: int) -> Array:
	if data == null:
		return []
	var straight := WorldBlockerGeometry.E | WorldBlockerGeometry.W
	var starts: Dictionary = {}
	for key in ring_set.keys():
		var cell: Vector2i = key
		var ok := true
		for k in 2:
			var c := cell + Vector2i(k, 0)
			if not _north_edge(c, ring_set, plaza, data) or (data.mask_at(c) & 15) != straight:
				ok = false
		if not ok:
			continue
		var span := Rect2i(cell + Vector2i(0, -1), Vector2i(2, 3))
		if (anchor.has_area() and span.intersects(anchor)) or (landmark.has_area() and span.intersects(landmark)):
			continue
		if clear.has(cell + Vector2i(0, 1)) or clear.has(cell + Vector2i(1, 1)):
			continue
		starts[cell] = true
	var stalls := _stall_group(starts.keys(), starts, base_seed, MAX_STALLS)
	for stall: Dictionary in stalls:
		stall["ring"] = true
	return stalls


## Then, purely visual, on the square's last paving row where its north side
## opens onto unbuilt ground (no ring there), backs to that ground.
static func _plan_open_stalls(plaza: Dictionary, ring_set: Dictionary, data: ChunkBuildData, clear: Dictionary, anchor: Rect2i, avoid: Dictionary, wanted: int, base_seed: int) -> Array:
	var starts: Dictionary = {}
	for key in plaza.keys():
		var cell: Vector2i = key
		var ok := true
		for k in 2:
			var c := cell + Vector2i(k, 0)
			var back := c + Vector2i.UP
			if not plaza.has(c) or plaza.has(back) or ring_set.has(back) or clear.has(c) or clear.has(back) or avoid.has(c):
				ok = false
			elif data != null and (data.kind_at(c) >= 0 or data.kind_at(back) >= 0):
				ok = false
		if not ok:
			continue
		if anchor.has_area() and Rect2i(cell, Vector2i(2, 1)).grow(1).intersects(anchor):
			continue
		starts[cell] = true
	var stalls := _stall_group(starts.keys(), starts, base_seed + 1, wanted)
	for stall: Dictionary in stalls:
		stall["ring"] = false
	return stalls


## Up to `wanted` stalls: a seeded first stall, its neighbour two cells along
## when that also fits (a market row), else the next far enough away.
static func _stall_group(cells: Array, starts: Dictionary, base_seed: int, wanted: int) -> Array:
	var stalls: Array = []
	if wanted <= 0 or cells.is_empty():
		return stalls
	var order := _shuffled(cells, base_seed, SALT_FURNITURE)
	var first: Vector2i = order[0]
	stalls.append({"cell": first})
	if stalls.size() < wanted:
		for step in [Vector2i(2, 0), Vector2i(-2, 0)]:
			if starts.has(first + step):
				stalls.append({"cell": first + step})
				break
	for cell: Vector2i in order:
		if stalls.size() >= wanted:
			break
		var far := true
		for other: Dictionary in stalls:
			if absi((other.cell as Vector2i).x - cell.x) < 4 and absi((other.cell as Vector2i).y - cell.y) < 3:
				far = false
		if far:
			stalls.append({"cell": cell})
	return stalls


## Drain grates (ground decals) on the paving along a road's edge (gutter).
static func _plan_drains(plaza: Dictionary, data: ChunkBuildData, clear: Dictionary, avoid: Dictionary, boss: Rect2i, base_seed: int) -> Array:
	var candidates: Array = []
	for key in plaza.keys():
		var cell: Vector2i = key
		if clear.has(cell) or avoid.has(cell) or (boss.has_area() and boss.has_point(cell)):
			continue
		# A gutter cell: paving beside the route (cheap test first).
		if not (clear.has(cell + Vector2i.LEFT) or clear.has(cell + Vector2i.RIGHT) or clear.has(cell + Vector2i.UP) or clear.has(cell + Vector2i.DOWN)):
			continue
		# Off the planter's foot: a grate half under a raised edge reads wrong.
		if data != null and (data.kind_at(cell) >= 0 or data.kind_at(cell + Vector2i.LEFT) >= 0 or data.kind_at(cell + Vector2i.RIGHT) >= 0 or data.kind_at(cell + Vector2i.UP) >= 0 or data.kind_at(cell + Vector2i.DOWN) >= 0):
			continue
		candidates.append(cell)
	var drains: Array = []
	for cell: Vector2i in _shuffled(candidates, base_seed, SALT_DRAIN):
		if drains.size() >= 2:
			break
		var far := true
		for other: Dictionary in drains:
			if (other.cell as Vector2i).distance_squared_to(cell) < 64:
				far = false
		if far:
			drains.append({"cell": cell})
	return drains


## Civic street entries: one notice board beside each south door with room.
static func plan_notice_boards(chunk: Node2D, cell_px: int) -> Array:
	var boards: Array = []
	for child: Node in chunk.get_children():
		if not child.is_in_group(&"city_block_building") or not bool(child.get("civic")):
			continue
		var bounds: Rect2 = child.get("bounds")
		for door: Dictionary in child.get("_doors"):
			if door.get("dir", Vector2i.ZERO) != Vector2i.DOWN:
				continue
			var gap := _door_box(door, cell_px)
			if not is_equal_approx(gap.end.y, bounds.end.y):
				continue
			# Left of the doorway, clear of its frame and the entry lantern.
			var x := gap.position.x - 78.0
			if x - 32.0 < bounds.position.x + 12.0:
				continue
			boards.append({"foot": Vector2(x, bounds.end.y + 10.0)})
			break
	return boards


static func _door_box(door: Dictionary, cell_px: int) -> Rect2:
	var dir: Vector2i = door.dir
	var perp := Vector2i(-dir.y, dir.x)
	var width := int(door.get("width", 2))
	var first: Vector2i = door.pos + perp * -(width >> 1)
	var last := first + perp * (width - 1)
	return Rect2(Vector2(first) * cell_px, Vector2.ONE * cell_px).merge(Rect2(Vector2(last) * cell_px, Vector2.ONE * cell_px))


# -------------------------------------------------------------- physics ---

## The only physical change: the centrepiece's explicit HALF_COVER cells. Art
## ownership (VARIANT_FURNITURE_ART) goes to the HALF_COVER cells a prop now
## draws: the centrepiece footprint and each island's existing planter cell.
static func _apply_physical(gen: ChunkGenImpl, chunk: Node2D, plan: Dictionary) -> void:
	var data := _build_data(gen)
	var centre: Dictionary = plan.centrepiece
	if not centre.is_empty() and StringName(centre.kind) != &"wall_fountain":
		var foot: Rect2i = centre.cells
		for y in range(foot.position.y, foot.end.y):
			for x in range(foot.position.x, foot.end.x):
				gen._spawn_block(chunk, gen.cover_half_scene, x, y)
				_own_art(data, Vector2i(x, y))
	for island: Dictionary in plan.islands:
		var prop: Vector2i = island.prop
		if prop.x >= 0:
			_own_art(data, prop)
	# Ground presentation only: the island cells that are not a bed take the
	# plaza's own paving (stamped above the island; no blocker changes).
	var tex := int(plan.get("repave_tex", -1))
	if tex >= 0:
		var unused_rng := RandomNumberGenerator.new()
		for island: Dictionary in plan.islands:
			var cells := ChunkShapeGen.rect_cells(island.rect)
			ChunkShapeGen.subtract_rect(cells, island.bed)
			for rect: Rect2i in ChunkShapeGen.cells_to_rects(cells):
				gen._stamp_floor_rect_cells(chunk, rect, tex, unused_rng, 0.95, -92)


static func _own_art(data: ChunkBuildData, cell: Vector2i) -> void:
	if data == null or data.kind_at(cell) < 0:
		return
	var index := data._index(cell)
	data.blocker_variant[index] = data.blocker_variant[index] | ChunkBlockVisualCatalog.VARIANT_FURNITURE_ART


# --------------------------------------------------------------- helpers --

static func _build_data(gen: ChunkGenImpl) -> ChunkBuildData:
	if gen == null or gen.cm == null:
		return null
	return gen.cm.get("_active_build_data") as ChunkBuildData


static func _centroid(cells: Dictionary) -> Vector2:
	var sum := Vector2.ZERO
	for key in cells.keys():
		sum += Vector2(key as Vector2i) + Vector2(0.5, 0.5)
	return sum / maxf(1.0, float(cells.size()))


## Cells in a salted pseudo-random but stable order (one hash per cell; the
## local cell index breaks ties, so the order never depends on input order).
static func _shuffled(cells: Array, base_seed: int, salt: int) -> Array:
	var keys := PackedInt64Array()
	for cell: Vector2i in cells:
		keys.append((int(_hash(base_seed, salt, cell)) << 12) | (posmod(cell.y, 64) << 6) | posmod(cell.x, 64))
	keys.sort()
	var out: Array = []
	for key in keys:
		var x := int(key & 63)
		var y := int((key >> 6) & 63)
		out.append(Vector2i(x if x < 48 else x - 64, y if y < 48 else y - 64))
	return out


static func _hash(base_seed: int, salt: int, cell: Vector2i) -> int:
	var h := int((base_seed ^ (salt * 0x9E3779B9)) & 0x7FFFFFFF)
	h = int((h ^ (cell.x * 73856093)) & 0x7FFFFFFF)
	h = int((h ^ (cell.y * 19349663)) & 0x7FFFFFFF)
	return int((h * 1103515245 + 12345) & 0x7FFFFFFF)
