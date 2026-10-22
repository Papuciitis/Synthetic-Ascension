extends Node

# Plaza presentation contract (PlazaPresentation / PlazaEdgeKit / PlazaDressing)
# on real production plans across the city families:
#  - ring cells keep kind and mask; the plaza-edge bits sit only on ring WALL
#    cells; every other physical byte matches the pass switched off, except
#    the declared centrepiece footprint;
#  - the centrepiece never touches objective anchors (independent table
#    below), protected route cells, sockets, boss courts or the landmark, and
#    leaves every walkable cell reachable;
#  - furniture adds no blocker and stands on open ground or on an already
#    blocked ring / prop cell; generation is deterministic; assets load and
#    the props registered for actor cover share one small texture;
#  - maintenance states (plaza pass 2): each family's squares draw in their
#    own state (independent table below); only tended squares keep clipped
#    planting, benches beyond one, and a cypress (at most one); working,
#    ruined and military squares have no clipped beds or civic benches;
#    ring goods / rubble stand on ring cells of non-arena rings; debris only
#    in ruined squares, flat on open paving.
const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
const PLAZA := preload("res://core/systems/world/proc/chunkgen/PlazaPresentation.gd")
const KIT := preload("res://core/systems/world/chunks/PlazaEdgeKit.gd")
const DRESSING := preload("res://scenes/world/plazas/PlazaDressing.gd")
const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const CPC := 32
const CELL := 64.0
const EDGE := 16
const BALUSTRADE := 64
const FURNITURE := 32
## Objective anchors per role, written out independently of the code under
## test: R(16-j, 16-j, 2j, 2j); wardstone j=5 in S2 (else 4), exit and wager
## shrine 3, cursed vault 2, primary 0 (its own two cells), start 3.
const ANCHOR_J := {&"gate": 3, &"secondary_wager_shrine": 3, &"exploration_reward": 3, &"entry_court": 3, &"primary_objective": 0}
const TARGETS := [
	{"segment": 2, "theme": &"service_courtyards"},
	{"segment": 3, "theme": &"checkpoint_lanes"},
	{"segment": 4, "theme": &"civilian_cutthrough"},
	{"segment": 4, "theme": &"collapsed_ward"},
	{"segment": 5, "theme": &"inner_district_gate"},
	{"segment": 6, "theme": &"industrial_cutthrough"},
	{"segment": 6, "theme": &"ruined_services"},
	{"segment": 7, "theme": &"underpass_veins"},
	{"segment": 7, "theme": &"canal_services"},
	{"segment": 8, "theme": &"rail_yard"},
	{"segment": 8, "theme": &"military_staging"},
	{"segment": 9, "theme": &"outer_wall"},
	{"segment": 9, "theme": &"siege_services"},
	{"segment": 10, "theme": &"gate_district"},
]
## Maintenance state per family, written out independently of the code
## under test: 0 tended, 1 working, 2 ruined, 3 damp, 4 military.
const EXPECTED_STATE := {
	&"service_courtyards": 0, &"checkpoint_lanes": 0, &"civilian_cutthrough": 0,
	&"inner_district_gate": 0, &"gate_district": 0,
	&"industrial_cutthrough": 1, &"rail_yard": 1,
	&"collapsed_ward": 2, &"ruined_services": 2, &"siege_services": 2,
	&"underpass_veins": 3, &"canal_services": 3,
	&"military_staging": 4, &"outer_wall": 4,
}
const CLIPPED_PLANTING := [&"box_shrub", &"lavender", &"cypress", &"olive_planter"]
const PLANS_PER_THEME := 3

var _costs: Array[int] = []
var _step_costs: Dictionary = {}
var _passes := 0
var _failures := 0
var _stats := {"chunks": 0, "ring_cells": 0, "centrepieces": 0, "wall_fountains": 0, "skipped_centrepieces": 0, "beds": 0, "repaved_islands": 0, "bed_planters": 0, "lamps": 0, "benches": 0, "stalls": 0, "drains": 0, "notice_boards": 0, "accents": 0, "pots": 0, "ring_props": 0, "debris": 0, "worn_beds": 0, "chunks_by_state": {}}


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _fixture(theme: SegmentThemeData, plan: Dictionary, coord: Vector2i, enabled: bool) -> Dictionary:
	PLAZA.enabled = enabled
	var manager := ChunkManager.new()
	theme.apply_to_chunk_manager(manager)
	manager.world_seed = int(plan.seed)
	manager.generation_enabled = false
	manager.ground_enabled = true
	manager.ground_splat_enabled = false
	manager.decals_enabled = false
	manager.deco_enabled = true
	manager.sites_enabled = false
	manager.cover_full_scene = COVER_FULL
	manager.cover_window_scene = COVER_WINDOW
	manager.cover_half_scene = COVER_HALF
	manager._site_mgr = SiteManager.new()
	add_child(manager)
	manager._chunk_connectors = plan.connectors_by_chunk.duplicate()
	manager._chunk_urban_access = plan.urban_access_by_chunk.duplicate()
	manager._chunk_role = plan.role_by_chunk.duplicate()
	manager._chunk_archetype = plan.archetype_by_chunk.duplicate()
	manager._gen_coord = coord
	manager._chunk_blocked[coord] = []
	var data := ChunkBuildData.new(coord, CPC)
	manager._active_build_data = data
	var chunk := Node2D.new()
	chunk.position = Vector2(coord) * manager.chunk_size_px
	manager.add_child(chunk)
	manager._generate_chunk(coord, chunk)
	manager._active_build_data = null
	PLAZA.enabled = true
	return {"manager": manager, "chunk": chunk, "data": data}


func _anchor(role: StringName, segment: int) -> Rect2i:
	var j := -1
	if role == &"wardstone_court":
		j = 5 if segment == 2 else 4
	elif ANCHOR_J.has(role):
		j = ANCHOR_J[role]
	if j < 0:
		return Rect2i()
	if j == 0:
		return Rect2i(15, 15, 2, 2)
	return Rect2i(16 - j, 16 - j, 2 * j, 2 * j)


func _dressing_snapshot(chunk: Node2D) -> Array:
	var out: Array = []
	var node := chunk.get_node_or_null("PlazaDressing")
	if node == null:
		return out
	for child: Node in node.get_children():
		var item := [child.name, (child as Node2D).position, (child as CanvasItem).z_index]
		if child is Sprite2D:
			item.append((child as Sprite2D).region_rect)
		elif child is Polygon2D:
			item.append((child as Polygon2D).polygon)
		out.append(item)
	return out


func _reachable(data: ChunkBuildData, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	if data.kind_at(start) >= 0:
		return seen
	var pending: Array[Vector2i] = [start]
	seen[start] = true
	while not pending.is_empty():
		var at: Vector2i = pending.pop_back()
		for dir in ChunkShapeGen.DIRS_4:
			var cell := at + dir
			if cell.x < 0 or cell.y < 0 or cell.x >= CPC or cell.y >= CPC or seen.has(cell) or data.kind_at(cell) >= 0:
				continue
			seen[cell] = true
			pending.append(cell)
	return seen


func _check_plaza(theme: SegmentThemeData, plan: Dictionary, coord: Vector2i, segment: int) -> void:
	var role: StringName = plan.role_by_chunk[coord]
	var tag := "theme=%s seed=%d coord=%s role=%s" % [theme.id, int(plan.seed), coord, role]
	var base := _fixture(theme, plan, coord, false)
	var styled := _fixture(theme, plan, coord, true)
	_costs.append(PLAZA.debug_last_usec)
	for key: String in PLAZA.debug_last_steps:
		_step_costs[key] = int(_step_costs.get(key, 0)) + int(PLAZA.debug_last_steps[key])

	var again := _fixture(theme, plan, coord, true)
	var b: ChunkBuildData = base.data
	var s: ChunkBuildData = styled.data
	var a: ChunkBuildData = again.data
	var chunk: Node2D = styled.chunk
	_stats.chunks += 1
	_check(not base.chunk.has_meta(PLAZA.META_PLAZA) and base.chunk.get_node_or_null("PlazaDressing") == null, tag + " the switched-off pass leaves no trace")
	_check(chunk.has_meta(PLAZA.META_PLAZA), tag + " plaza chunk records its ring")
	if not chunk.has_meta(PLAZA.META_PLAZA):
		for fixture in [base, styled, again]: fixture.manager.free()
		return
	var info: Dictionary = chunk.get_meta(PLAZA.META_PLAZA)
	var state := int(EXPECTED_STATE.get(theme.district_family, 0))
	_check(int(info.get("state", -1)) == state and s_state(styled) == state and s_state(base) == 0, tag + " squares draw in the family's maintenance state %d (presentation field only)" % state)
	var by_state: Dictionary = _stats.chunks_by_state
	by_state[str(state)] = int(by_state.get(str(state), 0)) + 1
	var ring: Dictionary = {}
	for cell: Vector2i in info.ring:
		ring[cell] = true
	_stats.ring_cells += ring.size()
	var plaza_plan: Dictionary = chunk.get_meta(PLAZA.META_PLAN, {})
	var centre: Dictionary = plaza_plan.get("centrepiece", {})
	var foot := Rect2i()
	if not centre.is_empty() and StringName(centre.kind) != &"wall_fountain":
		foot = centre.cells
	var arena := role in [&"checkpoint", &"miniboss_arena", &"boss_arena", &"gate"] or StringName(plan.archetype_by_chunk.get(coord, &"")) == &"gate"

	# --- physical bytes: only the declared footprint differs ---
	var physical_ok := true
	var bits_ok := true
	for index in range(CPC * CPC):
		var cell := s.cell_for_index(index)
		if foot.has_point(cell):
			continue
		if s.blocker_kind_code[index] != b.blocker_kind_code[index] or s.blocker_mask[index] != b.blocker_mask[index]:
			physical_ok = false
		var kind := s.kind_at(cell)
		var styled_variant := int(s.blocker_variant[index])
		var base_variant := int(b.blocker_variant[index])
		if kind == WorldBlockerGeometry.Kind.WALL or kind == WorldBlockerGeometry.Kind.WINDOW:
			var expected := 0
			if ring.has(cell):
				expected = EDGE | (BALUSTRADE if arena else 0)
			if styled_variant != (base_variant | expected) or (base_variant & (EDGE | BALUSTRADE)) != 0:
				bits_ok = false
			if ring.has(cell) and kind != WorldBlockerGeometry.Kind.WALL:
				bits_ok = false
		elif kind == WorldBlockerGeometry.Kind.HALF_COVER:
			if (styled_variant & ~FURNITURE) != (base_variant & ~FURNITURE):
				bits_ok = false
	_check(physical_ok, tag + " every blocker keeps kind and mask outside the declared centrepiece footprint")
	_check(bits_ok, tag + " plaza-edge bits only on ring WALL cells (balustrade bit on arena and gate rings)")
	# Floor stamps: the generator's stamps are untouched; the pass only appends
	# plaza-paving stamps over island cells that do not become a bed.
	var base_count := b.floor_stamp_count()
	var stamps_ok := s.floor_stamp_count() >= base_count
	for i in range(base_count * 6):
		stamps_ok = stamps_ok and s.floor_rect_and_style[i] == b.floor_rect_and_style[i]
	for i in range(base_count):
		stamps_ok = stamps_ok and is_equal_approx(s.floor_alpha[i], b.floor_alpha[i])
	var island_cells: Dictionary = {}
	for island: Dictionary in chunk.get_meta(PLAZA.META_ISLANDS, []):
		ChunkShapeGen.add_rect(island_cells, island.rect)
	for i in range(base_count, s.floor_stamp_count()):
		var at := i * 6
		var rect := Rect2i(s.floor_rect_and_style[at], s.floor_rect_and_style[at + 1], s.floor_rect_and_style[at + 2], s.floor_rect_and_style[at + 3])
		var island_only := true
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				island_only = island_only and island_cells.has(Vector2i(x, y))
		stamps_ok = stamps_ok and island_only and s.floor_rect_and_style[at + 5] == -92 and s.floor_rect_and_style[at + 4] == int((chunk.get_meta(PLAZA.META_PLAN, {}) as Dictionary).get("repave_tex", -1))
	_check(stamps_ok, tag + " generator floor stamps untouched; added stamps only re-pave island cells with the plaza paving")
	_check(str(chunk.get_meta(&"_foliage_placements", [])) == str(base.chunk.get_meta(&"_foliage_placements", [])), tag + " foliage plan unchanged (no generator RNG drift)")
	_check(chunk.get_meta(&"_landmark_cell", Vector2i(-1, -1)) == base.chunk.get_meta(&"_landmark_cell", Vector2i(-1, -1)), tag + " landmark placement unchanged")
	_check(chunk.get_meta(&"_proc_clear_cells", {}) == base.chunk.get_meta(&"_proc_clear_cells", {}), tag + " protected route cells unchanged")
	for cell: Vector2i in ring:
		_check(b.kind_at(cell) == WorldBlockerGeometry.Kind.WALL and s.mask_at(cell) == b.mask_at(cell), tag + " ring cell %s stays the same WALL" % cell)

	# --- determinism ---
	_check(a.blocker_kind_code == s.blocker_kind_code and a.blocker_mask == s.blocker_mask and a.blocker_variant == s.blocker_variant, tag + " blockers regenerate identically")
	_check(str(again.chunk.get_meta(PLAZA.META_PLAN, {})) == str(plaza_plan), tag + " plaza plan regenerates identically")
	_check(str(_dressing_snapshot(again.chunk)) == str(_dressing_snapshot(chunk)), tag + " dressing regenerates identically")

	# --- centrepiece ---
	var clear: Dictionary = chunk.get_meta(&"_proc_clear_cells", {})
	var plaza: Dictionary = info.plaza
	if not centre.is_empty():
		var cells: Rect2i = centre.cells
		_check(role == &"landmark_plaza" or (role == &"entry_court" and theme.district_family in [&"service_courtyards", &"civilian_cutthrough"]), tag + " centrepiece only in landmark squares and anchor-free courts")
		var anchor := _anchor(role, segment)
		_check(not anchor.has_area() or not cells.grow(1).intersects(anchor), tag + " centrepiece never touches the objective anchor box")
		var boss: Rect2i = chunk.get_meta(&"_boss_arena_clear_rect", Rect2i())
		_check(not boss.has_area() or not cells.intersects(boss.grow(1)), tag + " centrepiece stays out of boss courts")
		var on_clear := false
		for y in range(cells.position.y, cells.end.y):
			for x in range(cells.position.x, cells.end.x):
				on_clear = on_clear or clear.has(Vector2i(x, y))
		_check(not on_clear, tag + " centrepiece never on protected route cells")
		if chunk.has_meta(&"_landmark_cell"):
			var landmark: Vector2i = chunk.get_meta(&"_landmark_cell")
			_check(not cells.intersects(Rect2i(landmark - Vector2i.ONE, Vector2i(2, 2))), tag + " centrepiece clear of the landmark sprite")
		for child: Node in chunk.get_children():
			if child is Marker2D and child.is_in_group(&"enemy_spawn_socket"):
				_check(not cells.grow(1).has_point(Vector2i(((child as Marker2D).position / CELL).floor())), tag + " centrepiece clear of spawn sockets")
		if StringName(centre.kind) == &"wall_fountain":
			_stats.wall_fountains += 1
			for x in range(cells.position.x, cells.end.x):
				_check(ring.has(Vector2i(x, cells.position.y)), tag + " wall fountain stands on ring cells")
		else:
			_stats.centrepieces += 1
			var ring_round := ChunkShapeGen.rect_inside(plaza, cells.grow(1))
			for y in range(cells.position.y - 1, cells.end.y + 1):
				for x in range(cells.position.x - 1, cells.end.x + 1):
					if not cells.has_point(Vector2i(x, y)):
						ring_round = ring_round and s.kind_at(Vector2i(x, y)) < 0 and not clear.has(Vector2i(x, y))
			_check(ring_round, tag + " centrepiece keeps an open plaza cell all round, off the route")
			for y in range(cells.position.y, cells.end.y):
				for x in range(cells.position.x, cells.end.x):
					var cell := Vector2i(x, y)
					_check(b.kind_at(cell) < 0 and s.kind_at(cell) == WorldBlockerGeometry.Kind.HALF_COVER and (s.variant_at(cell) & FURNITURE) != 0, tag + " centrepiece is an explicit HALF_COVER footprint owning its art")
	elif PLAZA.is_centrepiece_role(role, theme.district_family):
		_stats.skipped_centrepieces += 1

	# --- reachability: only the footprint itself is lost ---
	var start := Vector2i(-1, -1)
	for cell: Vector2i in clear:
		if b.kind_at(cell) < 0 and (start.x < 0 or cell.y < start.y or (cell.y == start.y and cell.x < start.x)):
			start = cell
	if start.x >= 0:
		var before := _reachable(b, start)
		var after := _reachable(s, start)
		var lost: Array[Vector2i] = []
		for cell: Vector2i in before:
			if not after.has(cell) and not foot.has_point(cell):
				lost.append(cell)
		_check(lost.is_empty(), tag + " no walkable cell is cut off by the centrepiece: %s" % [lost])

	# --- furniture: no new blockers; standing pieces on open ground or on support ---
	var node := chunk.get_node_or_null("PlazaDressing")
	_check(node != null, tag + " plaza dressing node exists")
	if node != null:
		_check(node.find_children("*", "CollisionObject2D", true, false).is_empty() and node.find_children("*", "CollisionShape2D", true, false).is_empty(), tag + " dressing owns no collision")
		for child: Node in node.get_children():
			if not child.has_meta(&"plaza_ground_contact"):
				continue
			var at: Vector2 = child.get_meta(&"plaza_ground_contact")
			var cell := Vector2i((at / CELL).floor())
			var kind := s.kind_at(cell)
			var piece: StringName = child.get_meta(&"plaza_piece", &"")
			var supported := kind < 0 or ring.has(cell) or foot.has_point(cell) or (kind == WorldBlockerGeometry.Kind.HALF_COVER and (s.variant_at(cell) & FURNITURE) != 0)
			# A prop's foot may sit just below its support cell (planter fronts).
			var above := cell - Vector2i(0, 1)
			supported = supported or ring.has(above) or foot.has_point(above)
			_check(supported, tag + " %s stands on open ground or on an already blocked support at %s" % [piece, cell])
			var boss: Rect2i = chunk.get_meta(&"_boss_arena_clear_rect", Rect2i())
			_check(not boss.has_area() or not boss.has_point(cell), tag + " %s stays out of the boss court" % piece)
		for sprite: Node in node.get_children():
			if sprite.is_in_group(FOREGROUND.GROUP):
				var texture := (sprite as Sprite2D).texture
				_check(texture == DRESSING.ATLAS and texture.get_width() <= 1024 and texture.get_height() <= 512, tag + " cover-registered props share the one small atlas")
	for island: Dictionary in plaza_plan.get("islands", []):
		if (island.get("bed", Rect2i()) as Rect2i).has_area():
			_stats.beds += 1
			var bed: Rect2i = island.bed
			var bed_clear := false
			for y in range(bed.position.y, bed.end.y):
				for x in range(bed.position.x, bed.end.x):
					bed_clear = bed_clear or clear.has(Vector2i(x, y))
			_check(not bed_clear and (island.rect as Rect2i).encloses(bed), tag + " beds stay inside their island and off the route")
		else:
			_stats.repaved_islands += 1
		var prop: Vector2i = island.prop
		if prop.x >= 0:
			_stats.bed_planters += 1
			_check(b.kind_at(prop) == WorldBlockerGeometry.Kind.HALF_COVER and (s.variant_at(prop) & FURNITURE) != 0, tag + " bed planter reuses the island's existing half-cover cell")
	var anchor_box := _anchor(role, segment)
	for lamp: Dictionary in plaza_plan.get("lamps", []):
		_stats.lamps += 1
		_check(not clear.has(lamp.cell), tag + " lamps flank the road mouth, never stand in it")
	for group: String in ["lamps", "benches", "drains", "stalls", "accents", "pots", "ring_props", "debris", "edge_goods", "edge_wear"]:
		for item: Dictionary in plaza_plan.get(group, []):
			_check(not anchor_box.has_area() or not anchor_box.grow(1).has_point(item.cell), tag + " %s keep off the objective anchor box" % group)
	_stats.benches += (plaza_plan.get("benches", []) as Array).size()
	_stats.stalls += (plaza_plan.get("stalls", []) as Array).size()
	for stall: Dictionary in plaza_plan.get("stalls", []):
		_check(theme.district_family in [&"civilian_cutthrough", &"service_courtyards", &"inner_district_gate", &"gate_district"] and not arena, tag + " stalls only in market districts, never on parapets")
		for k in 2:
			var at: Vector2i = (stall.cell as Vector2i) + Vector2i(k, 0)
			if bool(stall.ring):
				_check(ring.has(at), tag + " a ring stall stands on ring cells (blocked support)")
			else:
				_check(plaza.has(at) and s.kind_at(at) < 0 and not clear.has(at) and not plaza.has(at + Vector2i.UP), tag + " an open-edge stall stands on the square's open north edge row, off the route")
	for pots: Dictionary in plaza_plan.get("pots", []):
		_stats.pots += 1
		var at: Vector2i = pots.cell
		_check((ring.has(at) if bool(pots.ring) else (plaza.has(at) and s.kind_at(at) < 0)) and not clear.has(at), tag + " pots stand beside the stalls on a planter or the open edge, off the route")
	for accent: Dictionary in plaza_plan.get("accents", []):
		_stats.accents += 1
		_check(ring.has(accent.cell) and not bool(info.balustrade), tag + " cypress accents stand in planter ends (blocked support), never on parapets")
	for drain: Dictionary in plaza_plan.get("drains", []):
		_stats.drains += 1
		_check(plaza.has(drain.cell) and s.kind_at(drain.cell) < 0, tag + " drain grates lie on open plaza paving")
	_check_state(tag, state, info, plaza_plan, chunk, s, ring, plaza, clear)
	for fixture in [base, styled, again]:
		fixture.manager.free()


func s_state(fixture: Dictionary) -> int:
	return int((fixture.data as ChunkBuildData).plaza_edge_state)


## Maintenance-state presentation of one plaza chunk.
func _check_state(tag: String, state: int, info: Dictionary, plaza_plan: Dictionary, chunk: Node2D, s: ChunkBuildData, ring: Dictionary, plaza: Dictionary, clear: Dictionary) -> void:
	var arena := bool(info.balustrade)
	var accents: Array = plaza_plan.get("accents", [])
	_check(accents.size() <= 1 and (accents.is_empty() or state == 0), tag + " the frontal cypress stands in tended squares only, at most once")
	var benches: Array = plaza_plan.get("benches", [])
	_check(benches.is_empty() or state == 0 or (state == 3 and benches.size() <= 1), tag + " civic benches only in tended (and one in damp) squares")
	var ring_props: Array = plaza_plan.get("ring_props", [])
	_check(ring_props.is_empty() or (state in [1, 2, 3, 4] and not arena), tag + " ring goods / rubble only on non-arena rings of worn states")
	for item: Dictionary in ring_props:
		_stats.ring_props += 1
		var cell: Vector2i = item.cell
		_check(ring.has(cell) and s.kind_at(cell) == WorldBlockerGeometry.Kind.WALL and not clear.has(cell), tag + " ring prop %s stands on a ring WALL cell (blocked support)" % item.id)
		var allowed: Array = {1: [&"crates_stack", &"handcart", &"barrels_group", &"sacks_pile"], 2: [&"rubble_pile", &"scaffold_crates"], 3: [&"barrels_group"], 4: [&"crates_stack", &"sacks_pile"]}.get(state, [])
		_check(StringName(item.id) in allowed, tag + " ring prop %s belongs to state %d" % [item.id, state])
	var edge_goods: Array = plaza_plan.get("edge_goods", [])
	_check(edge_goods.size() <= 1 and (edge_goods.is_empty() or (state in [1, 4] and not arena)), tag + " edge goods (handcart / supplies) only in working and military squares, once")
	_stats.edge_goods = int(_stats.get("edge_goods", 0)) + edge_goods.size()
	var debris: Array = plaza_plan.get("debris", [])
	_check(debris.is_empty() or state == 2, tag + " debris decals only in ruined squares")
	for item: Dictionary in debris:
		_stats.debris += 1
		_check(plaza.has(item.cell) and s.kind_at(item.cell) < 0 and not clear.has(item.cell), tag + " debris lies flat on open plaza paving off the route")
	for item: Dictionary in plaza_plan.get("edge_wear", []):
		_check(state != 0 and plaza.has(item.cell) and s.kind_at(item.cell) < 0 and not clear.has(item.cell), tag + " flat edge wear stays on off-route open paving")
		_check(StringName(item.kind) != &"oil", tag + " oil needs an actual machinery owner")
	var node := chunk.get_node_or_null("PlazaDressing")
	if node == null:
		return
	var drawn_wear := 0
	var pieces: Dictionary = {}
	var contacts: Dictionary = {}
	for child: Node in node.get_children():
		if child.has_meta(&"plaza_edge_wear"):
			drawn_wear += 1
			_check(not child.is_in_group(FOREGROUND.GROUP) and (child as CanvasItem).z_index < -80, tag + " edge wear stays flat beneath actors")
		var piece := StringName(child.get_meta(&"plaza_piece", &""))
		pieces[piece] = int(pieces.get(piece, 0)) + 1
		if child.has_meta(&"plaza_ground_contact"):
			contacts[Vector2i((child.get_meta(&"plaza_ground_contact") as Vector2 / CELL).floor())] = piece
		if child is Sprite2D and (child as Sprite2D).texture.resource_path == KIT.WORN_ATLAS_PATH:
			_check(not child.is_in_group(FOREGROUND.GROUP), tag + " worn props are never registered as actor cover")
	_check(drawn_wear == (plaza_plan.get("edge_wear", []) as Array).size(), tag + " each planned edge patch has one drawn ground owner")
	if state in [1, 3, 4]:
		_check(int(pieces.get(&"kerb", 0)) == 0, tag + " working, damp and military islands have no ornamental closed kerb")
	if state != 0:
		var clipped := 0
		for piece: StringName in CLIPPED_PLANTING:
			clipped += int(pieces.get(piece, 0))
		_check(clipped == 0, tag + " no clipped planting (box, lavender, cypress, olive planter) outside tended squares: %s" % [pieces])
		if state in [1, 4]:
			_check(int(pieces.get(&"weeds", 0)) == 0, tag + " working and military ground is bare, not weedy")
	# Every island's existing half-cover cell still draws a prop.
	for island: Dictionary in plaza_plan.get("islands", []):
		var prop: Vector2i = island.prop
		if prop.x >= 0:
			_check(contacts.has(prop), tag + " island half-cover cell %s keeps a drawn prop in state %d" % [prop, state])
		if state != 0 and (island.get("bed", Rect2i()) as Rect2i).has_area():
			_stats.worn_beds += 1


## Street chunks: notice boards stand on open ground in front of a civic
## kit's south door, add no blocker and keep the street's bytes unchanged.
func _check_street(theme: SegmentThemeData, plan: Dictionary, coord: Vector2i) -> void:
	var tag := "theme=%s seed=%d coord=%s role=%s" % [theme.id, int(plan.seed), coord, plan.role_by_chunk[coord]]
	var base := _fixture(theme, plan, coord, false)
	var styled := _fixture(theme, plan, coord, true)
	var b: ChunkBuildData = base.data
	var s: ChunkBuildData = styled.data
	_check(s.blocker_kind_code == b.blocker_kind_code and s.blocker_mask == b.blocker_mask and s.blocker_variant == b.blocker_variant and s.floor_rect_and_style == b.floor_rect_and_style, tag + " street chunk physics and floors untouched")
	var node: Node = styled.chunk.get_node_or_null("PlazaDressing")
	var civic_doors := 0
	for child: Node in styled.chunk.get_children():
		if child.is_in_group(&"city_block_building") and bool(child.get("civic")):
			civic_doors += 1
	if node != null:
		_check(civic_doors > 0, tag + " notice boards only beside civic buildings")
		for child: Node in node.get_children():
			if child.get_meta(&"plaza_piece", &"") != &"notice_board":
				continue
			_stats.notice_boards += 1
			var at: Vector2 = child.get_meta(&"plaza_ground_contact")
			_check(s.kind_at(Vector2i((at / CELL).floor())) < 0, tag + " notice board stands on open ground")
	base.manager.free()
	styled.manager.free()


func _check_assets() -> void:
	var prefix := ["planter34_", "kerb34_", "ruin34_", "moss34_", "balustrade34_"]
	for state in 5:
		for style_variant in [0, KIT.VARIANT_BALUSTRADE]:
			for mask in 16:
				var data := ChunkBuildData.new(Vector2i.ZERO, 4)
				data.plaza_edge_state = state
				data.add_blocker(Vector2i(1, 1), WorldBlockerGeometry.Kind.WALL, mask, KIT.VARIANT_PLAZA_EDGE | style_variant)
				var texture := KIT.texture_for(data, Vector2i(1, 1))
				_check(texture != null and texture.get_size() == Vector2(128, 184), "plaza edge piece loads mask=%d style=%d state=%d" % [mask, style_variant, state])
				# The arena parapet wins in every state; military ground is a parapet too.
				var expected: String = "balustrade34_" if style_variant != 0 else prefix[state]
				_check(texture != null and texture.resource_path.begins_with("res://assets/world/plazas_v1/kit/" + expected), "plaza edge piece mask=%d state=%d draws %s*" % [mask, state, expected])
	for style in 5:
		_check(KIT.fill_texture(style) != null and KIT.fill_texture(style).get_width() > 0, "plaza edge fill loads style=%d" % style)
	var worn_atlas := KIT.dressing_texture(KIT.STATE_RUINED, &"worn_atlas")
	_check(worn_atlas != null and KIT.dressing_texture(KIT.STATE_RUINED, &"weeds_ground") != null and KIT.dressing_texture(KIT.STATE_DAMP, &"moss_soil") != null, "worn atlas and state-selected bed fills load")
	for id: StringName in DRESSING.WORN_REGIONS:
		_check(Rect2(Vector2.ZERO, worn_atlas.get_size()).encloses(DRESSING.WORN_REGIONS[id]), "worn atlas region %s inside the atlas" % id)
	_check(DRESSING.ATLAS != null and DRESSING.STONE != null, "plaza atlas and stone tile load")
	for id: StringName in DRESSING.REGIONS:
		var region: Rect2 = DRESSING.REGIONS[id]
		_check(Rect2(Vector2.ZERO, DRESSING.ATLAS.get_size()).encloses(region), "atlas region %s inside the atlas" % id)
	_check(ChunkBlockVisualCatalog.texture_count() >= KIT.texture_count(), "renderer batch bound counts the plaza kits")
	# The renderer draws a marked ring cell with a low piece, never the wall kit.
	var host := Node2D.new()
	add_child(host)
	var renderer := ChunkBlockRenderer.new()
	renderer.configure(host, 256, 64)
	var data := ChunkBuildData.new(Vector2i.ZERO, 4)
	data.add_blocker(Vector2i(0, 1), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.E, KIT.VARIANT_PLAZA_EDGE)
	data.add_blocker(Vector2i(1, 1), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.E | WorldBlockerGeometry.W, KIT.VARIANT_PLAZA_EDGE)
	data.add_blocker(Vector2i(2, 1), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.W, 0)
	renderer.add_chunk(data)
	var plaza_batches := 0
	var wall_batches := 0
	for batch: ChunkBlockRenderer.TextureBatch in renderer.get("_batches").values():
		if batch.texture.resource_path.contains("plazas_v1/kit"):
			plaza_batches += 1
		elif batch.texture.resource_path.contains("walls/kit"):
			wall_batches += 1
	_check(plaza_batches == 2 and wall_batches == 1, "marked ring cells draw with plaza pieces, unmarked walls keep the wall kit")
	_check(int(renderer.get_stats().instances) == 3, "one instance per edge cell")
	renderer.clear()
	# A ruined chunk's ordinary ring draws the broken planter; its parapet cell
	# (arena bit) keeps the balustrade.
	var ruined := ChunkBuildData.new(Vector2i(1, 0), 4)
	ruined.plaza_edge_state = KIT.STATE_RUINED
	ruined.add_blocker(Vector2i(0, 1), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.E, KIT.VARIANT_PLAZA_EDGE)
	ruined.add_blocker(Vector2i(1, 1), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.W, KIT.VARIANT_PLAZA_EDGE)
	ruined.add_blocker(Vector2i(3, 3), WorldBlockerGeometry.Kind.WALL, 0, KIT.VARIANT_PLAZA_EDGE | KIT.VARIANT_BALUSTRADE)
	renderer.add_chunk(ruined)
	var ruin_batches := 0
	var parapet_batches := 0
	for batch: ChunkBlockRenderer.TextureBatch in renderer.get("_batches").values():
		if batch.texture.resource_path.contains("plazas_v1/kit/ruin34_"):
			ruin_batches += 1
		elif batch.texture.resource_path.contains("plazas_v1/kit/balustrade34_"):
			parapet_batches += 1
	_check(ruin_batches == 2 and parapet_batches == 1, "a ruined chunk's ring draws broken planter pieces; arena cells keep the parapet")
	renderer.clear()
	host.free()


func _run() -> void:
	var started := Time.get_ticks_msec()
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	_check_assets()
	for target: Dictionary in TARGETS:
		var segment: int = target.segment
		Global.attempt_segment = segment
		var found := 0
		for seed_value in range(1, 400):
			if found >= PLANS_PER_THEME:
				break
			var theme := SegmentThemePicker.get_theme(segment, seed_value)
			if theme.id != target.theme:
				continue
			found += 1
			var plan := DistrictPlan.generate(segment, seed_value, 2048, theme)
			var picked: Dictionary = {}
			var coords: Array = plan.role_by_chunk.keys()
			coords.sort()
			for coord: Vector2i in coords:
				var role: StringName = plan.role_by_chunk[coord]
				if role in [&"landmark_plaza", &"entry_court", &"wardstone_court", &"exploration_reward", &"checkpoint", &"gate", &"miniboss_arena", &"boss_arena", &"primary_objective", &"secondary_wager_shrine"] and not picked.has(role):
					picked[role] = coord
			for role: StringName in picked:
				_check_plaza(theme, plan, picked[role], segment)
			var streets := 0
			for coord: Vector2i in coords:
				if streets >= 3:
					break
				if StringName(plan.role_by_chunk[coord]) in [&"main_street", &"secondary_route", &"district_fill"]:
					_check_street(theme, plan, coord)
					streets += 1
		_check(found > 0, "natural plans found for %s" % target.theme)
	player.free()
	_costs.sort()
	if not _costs.is_empty():
		_stats["post_pass_usec_median"] = _costs[_costs.size() >> 1]
		_stats["post_pass_usec_max"] = _costs[-1]
		for key: String in _step_costs:
			_stats["post_pass_usec_mean_" + key] = int(_step_costs[key]) / _costs.size()
	KIT.release_static_caches()
	print("PlazaPresentation stats: ", JSON.stringify(_stats))
	print("PlazaPresentationTest: %d passed, %d failed; elapsed %dms" % [_passes, _failures, Time.get_ticks_msec() - started])
	get_tree().quit(1 if _failures > 0 else 0)
