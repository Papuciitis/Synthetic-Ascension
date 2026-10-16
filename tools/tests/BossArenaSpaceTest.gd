extends Node

# Regressions: arena-ring walls/props must not consume the advertised fight
# space, dressing must not obscure it, and arena jitter must not move the
# encounter away from that protected space. Generate the real milestone
# themes and chunk contents; expectations below are independent of the new
# spatial helper so a broken reservation cannot redefine its own test.
const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
const CPC := 32
const CELL := 64.0
const SEED_COUNT := 40
var _passes := 0
var _failures := 0
var _generated_chunks := 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _fixture(plan: Dictionary, theme: SegmentThemeData, coord: Vector2i) -> Dictionary:
	var manager := ChunkManager.new()
	theme.apply_to_chunk_manager(manager)
	manager.world_seed = int(plan.seed)
	manager.generation_enabled = false
	manager.ground_enabled = false
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
	_generated_chunks += 1
	return {"manager": manager, "chunk": chunk, "data": data}

func _expected_court(segment: int) -> Rect2i:
	return Rect2i(6, 6, 20, 20) if segment == 5 else Rect2i(2, 2, 28, 28)

func _blocked_court_cells(data: ChunkBuildData, court: Rect2i) -> int:
	var blocked := 0
	for y in range(court.position.y, court.end.y):
		for x in range(court.position.x, court.end.x):
			if data.kind_at(Vector2i(x, y)) >= 0:
				blocked += 1
	return blocked

func _reachable(data: ChunkBuildData, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	var start_position := (Vector2(start) + Vector2(0.5, 0.5)) * CELL
	if not _path_is_clear(data, start_position, start_position, 45.0):
		return seen
	var pending: Array[Vector2i] = [start]
	seen[start] = true
	while not pending.is_empty():
		var at: Vector2i = pending.pop_back()
		for direction in ChunkShapeGen.DIRS_4:
			var cell := at + direction
			if cell.x < 0 or cell.y < 0 or cell.x >= CPC or cell.y >= CPC or seen.has(cell) or data.kind_at(cell) >= 0:
				continue
			var from_position := (Vector2(at) + Vector2(0.5, 0.5)) * CELL
			var to_position := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
			if not _path_is_clear(data, from_position, to_position, 45.0):
				continue
			seen[cell] = true
			pending.append(cell)
	return seen

func _path_is_clear(data: ChunkBuildData, from: Vector2, to: Vector2, radius: float) -> bool:
	# Every authoritative blocker lies inside its own 64px cell. Restrict
	# short BFS steps to their swept bounds so body-aware reachability is
	# cheap enough to run for every generated court.
	var x0 := maxi(0, floori((minf(from.x, to.x) - radius) / CELL))
	var x1 := mini(CPC - 1, floori((maxf(from.x, to.x) + radius) / CELL))
	var y0 := maxi(0, floori((minf(from.y, to.y) - radius) / CELL))
	var y1 := mini(CPC - 1, floori((maxf(from.y, to.y) + radius) / CELL))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var cell := Vector2i(x, y)
			var kind := data.kind_at(cell)
			if kind < 0:
				continue
			var descriptor := WorldBlockerGeometry.pack(kind, data.mask_at(cell))
			var center := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
			if WorldBlockerGeometry.swept_hit_t(descriptor, center, from, to, radius, CELL) >= 0.0:
				return false
	return true

func _check_arena(plan: Dictionary, segment: int, fixture: Dictionary, tag: String) -> void:
	var manager: ChunkManager = fixture.manager
	var chunk: Node2D = fixture.chunk
	var data: ChunkBuildData = fixture.data
	var court := _expected_court(segment)
	_check(_blocked_court_cells(data, court) == 0, tag + " full fighting court contains no walls, windows or half-cover")
	var reservations: Dictionary = chunk.get_meta(&"_proc_clear_cells", {})
	var reserved_count := 0
	for y in range(court.position.y, court.end.y):
		for x in range(court.position.x, court.end.x):
			if reservations.has(Vector2i(x, y)):
				reserved_count += 1
	_check(reserved_count == court.get_area(), tag + " full court is reserved before blocker and dressing placement")

	var coord: Vector2i = data.coord
	var mask: int = manager.get_chunk_connectors(coord)
	var gen: ChunkGenImpl = manager._content_gen
	var cx: int = gen._lane_center_for_col(coord.x, CPC)
	var cy: int = gen._lane_center_for_row(coord.y, CPC)
	var sockets: Array[Vector2i] = []
	if mask & 1: sockets.append(Vector2i(cx, 0))
	if mask & 2: sockets.append(Vector2i(CPC - 1, cy))
	if mask & 4: sockets.append(Vector2i(cx, CPC - 1))
	if mask & 8: sockets.append(Vector2i(0, cy))
	var reachable := _reachable(data, Vector2i(16, 16))
	var sockets_reachable := not sockets.is_empty()
	var sockets_body_safe := not sockets.is_empty()
	for socket in sockets:
		sockets_reachable = sockets_reachable and reachable.has(socket)
		var socket_position := (Vector2(socket) + Vector2(0.5, 0.5)) * CELL
		sockets_body_safe = sockets_body_safe and _path_is_clear(data, socket_position, socket_position, 45.0)
	_check(sockets_reachable, tag + " every connected street socket remains reachable along a 45px body-safe path")
	_check(sockets_body_safe, tag + " connected street sockets admit the player and a 45px boss body")

	var perimeter := Rect2(Vector2(court.position) * CELL, Vector2(court.size) * CELL).grow(-64.0)
	var corners: Array[Vector2] = [perimeter.position, Vector2(perimeter.end.x, perimeter.position.y), perimeter.end, Vector2(perimeter.position.x, perimeter.end.y)]
	var perimeter_safe := true
	for index in range(corners.size()):
		perimeter_safe = perimeter_safe and _path_is_clear(data, corners[index], corners[(index + 1) % corners.size()], 45.0)
	_check(perimeter_safe, tag + " a continuous perimeter accommodates player 25px and boss 45px bodies")

	var home := Vector2(1024.0, 944.0 if segment == 5 else 934.0)
	var attack_lanes_safe := true
	for direction_index in range(16):
		var direction := Vector2.RIGHT.rotated(TAU * float(direction_index) / 16.0)
		attack_lanes_safe = attack_lanes_safe and _path_is_clear(data, home, home + direction * 281.0, 45.0)
		# Last shock center 420px plus its 85px radius; the beam has 17px
		# half-width plus 25px of escape allowance around its edge.
		attack_lanes_safe = attack_lanes_safe and _path_is_clear(data, home, home + direction * 420.0, 85.0)
		if segment == 10:
			attack_lanes_safe = attack_lanes_safe and _path_is_clear(data, home, home + direction * 680.0, 42.0)
	_check(attack_lanes_safe, tag + " rush, fault-line and applicable beam lanes remain usable in 16 directions")

	var dressing_clear := chunk.get_node_or_null("Landmark") == null
	for placement in chunk.get_meta(&"_foliage_placements", []):
		if court.grow(1).has_point(placement.cell):
			dressing_clear = false
	_check(dressing_clear, tag + " foliage and center landmarks do not cover the reserved court")
	_check(plan.role_by_chunk.get(coord, &"") == (&"miniboss_arena" if segment == 5 else &"boss_arena"), tag + " fixture uses the production milestone arena role")

func _check_spawn_anchor(plan: Dictionary, segment: int, manager: ChunkManager, tag: String) -> void:
	# Do not enter this builder into the tree: _ready would start a full game.
	# Its real event-spawning method runs with the already-built fixture plan.
	var builder := SegmentProcBuilder.new()
	builder._cm = manager
	builder._segment = segment
	builder._plan = plan
	builder._rng.seed = int(plan.seed)
	builder._spawn_segment_events()
	var found := false
	var anchor_matches := false
	var expected: Vector2 = plan.miniboss_world if segment == 5 else plan.boss_world
	for child in builder.get_children():
		if (segment == 5 and child is MiniBossArena) or (segment == 10 and child is BossArena):
			found = true
			anchor_matches = (child as Node2D).global_position.is_equal_approx(expected)
	_check(found and anchor_matches, tag + " encounter anchor matches the center of its protected court")
	builder.free()

func _run() -> void:
	var started := Time.get_ticks_msec()
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	for seed_index in range(SEED_COUNT):
		var world_seed: int = 1 + seed_index * 48271 + seed_index * seed_index * 2654435761
		for segment in [5, 10]:
			var theme: SegmentThemeData = SegmentThemePicker.get_theme(segment, world_seed)
			var plan := DistrictPlan.generate(segment, world_seed, 2048, theme)
			var coord: Vector2i = plan.miniboss_chunk if segment == 5 else plan.boss_chunk
			var tag := "seed=%d segment=%d" % [world_seed, segment]
			var fixture := _fixture(plan, theme, coord)
			_check_arena(plan, segment, fixture, tag)
			_check_spawn_anchor(plan, segment, fixture.manager, tag)
			if seed_index % 10 == 0:
				var repeated := _fixture(plan, theme, coord)
				var first_data: ChunkBuildData = fixture.data
				var repeated_data: ChunkBuildData = repeated.data
				_check(first_data.blocker_kind_code == repeated_data.blocker_kind_code and first_data.blocker_mask == repeated_data.blocker_mask and fixture.chunk.get_meta(&"_foliage_placements", []) == repeated.chunk.get_meta(&"_foliage_placements", []), tag + " arena blockers and dressing regenerate deterministically")
				repeated.manager.free()
			fixture.manager.free()
	player.free()
	print("BossArenaSpaceTest: %d passed, %d failed; %d generated arena chunks across %d seeds; elapsed %dms" % [_passes, _failures, _generated_chunks, SEED_COUNT, Time.get_ticks_msec() - started])
	get_tree().quit(1 if _failures > 0 else 0)
