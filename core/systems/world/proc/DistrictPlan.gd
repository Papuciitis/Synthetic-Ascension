extends RefCounted
class_name DistrictPlan

# Chunk-connector bitmask (matches CoverWall.gd)
const N := 1
const E := 2
const S := 4
const W := 8

# Produces a Donjon-ish "makes sense" layout at the CHUNK scale:
# - A connected main route (cardinal steps)
# - A small number of side pockets (optional branches)
# - Optional loops (small extra connections) so it doesn't read as a straight hallway
# - Connector masks per chunk so ChunkManager can align streets across borders
#
# Themes:
# - Segment 2: explore (wide drift + branches)
# - Segment 3: escape (tighter, denser, straighter push outward)
# - Others: random mix per attempt/segment seed
# - Segment 5: includes a required miniboss encounter NEAR the exit gate (on the main route)
# - Segment 10: boss capstone (builder handles boss gating)

static func generate(segment: int, attempt_world_seed: int, chunk_size_px: int, theme: SegmentThemeData = null) -> Dictionary:
	segment = maxi(1, segment)

	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(attempt_world_seed, segment)

	# -----------------------------
	# Theme defaults (legacy-safe)
	# -----------------------------
	var goal_dist_offset: int = 0
	var ortho_limit: int = (4 if segment == 2 else 3 if segment >= 5 else 2)
	var ortho_guard_bonus: int = (1 if segment == 2 else 0)
	var waypoint_ch: float = (0.95 if segment == 2 else 0.80)
	var meander_ch: float = (0.30 if segment == 2 else 0.18 if segment == 3 else 0.22)
	var branch_min: int = (2 if segment == 2 else 1)
	var branch_max: int = (3 if segment == 2 else 2 if segment >= 4 else 1)
	var max_branch_len: int = (2 if segment >= 4 else 1 if segment == 3 else 2)
	var loop_min: int = 0
	var loop_max: int = 0
	if segment >= 4:
		loop_max = 1
		if segment >= 7:
			loop_max = 2

	var want_miniboss_arena: bool = false
	if theme != null:
		want_miniboss_arena = theme.has_miniboss_arena
	else:
		want_miniboss_arena = (segment == 5)

	# Segment 5 is a teaching beat: the miniboss is required and should be near the exit gate,
	# not hidden in a side pocket. Later segments may optionally place a miniboss as an explore pocket.
	var miniboss_near_gate: bool = (segment == 5)

	var want_boss_arena: bool = false
	if theme != null:
		want_boss_arena = theme.has_boss_arena
	else:
		want_boss_arena = (segment == 10)

	if theme != null:
		goal_dist_offset = theme.goal_dist_offset
		ortho_limit = maxi(1, theme.ortho_limit)
		ortho_guard_bonus = theme.ortho_guard_bonus
		waypoint_ch = clampf(theme.waypoint_chance, 0.0, 1.0)
		meander_ch = clampf(theme.meander_chance, 0.0, 1.0)

		branch_min = maxi(0, theme.branch_count_min)
		branch_max = maxi(branch_min, theme.branch_count_max)
		max_branch_len = maxi(1, theme.max_branch_len)

		loop_min = maxi(0, theme.loop_budget_min)
		loop_max = maxi(loop_min, theme.loop_budget_max)


	# How far the route pushes "outward" (campaign escalation) + randomness so replays don't feel identical.
	var base_dist := 5 + maxi(0, segment - 2)
	var goal_dist: int = clampi(base_dist + goal_dist_offset + rng.randi_range(-1, 3), 5, 14)

	# Start near origin but slightly jittered for replay variety.
	var start_x: int = rng.randi_range(-mini(1, ortho_limit), mini(1, ortho_limit))
	var start_y: int = rng.randi_range(-mini(1, ortho_limit), mini(1, ortho_limit))

	# Escape edge: 0=N,1=E,2=S,3=W (outward but varied).
	var exit_edge: int = rng.randi_range(0, 3)
	var exit_chunk_target: Vector2i = Vector2i.ZERO
	match exit_edge:
		0:
			exit_chunk_target = Vector2i(rng.randi_range(-ortho_limit, ortho_limit), -goal_dist)
		1:
			exit_chunk_target = Vector2i(goal_dist, rng.randi_range(-ortho_limit, ortho_limit))
		2:
			exit_chunk_target = Vector2i(rng.randi_range(-ortho_limit, ortho_limit), goal_dist)
		3:
			exit_chunk_target = Vector2i(-goal_dist, rng.randi_range(-ortho_limit, ortho_limit))

	var primary_dir: Vector2i = Vector2i.ZERO
	match exit_edge:
		0: primary_dir = Vector2i(0, -1)
		1: primary_dir = Vector2i(1, 0)
		2: primary_dir = Vector2i(0, 1)
		3: primary_dir = Vector2i(-1, 0)

	# ------------------------------------------------------------
	# 1) Build a connected main route (cardinal steps).
	# ------------------------------------------------------------
	var main_route: Array[Vector2i] = []
	var used: Dictionary = {} # Vector2i -> true

	var p: Vector2i = Vector2i(start_x, start_y)
	main_route.append(p)
	used[p] = true

	# Add a waypoint (usually) to force a bend so routes don't read as a straight hallway.
	var waypoint_enabled: bool = (goal_dist >= 7 and rng.randf() < waypoint_ch)
	var targets: Array[Vector2i] = []
	if waypoint_enabled:
		var wp: Vector2i = exit_chunk_target
		if exit_edge == 1 or exit_edge == 3:
			var midx: int = clampi(int(round(float(goal_dist) * 0.45)) + rng.randi_range(-1, 1), 2, goal_dist - 2)
			if exit_edge == 3:
				midx = -midx
			var midy: int = rng.randi_range(-ortho_limit, ortho_limit)
			if midy == start_y:
				midy = clampi(midy + (1 if midy < ortho_limit else -1), -ortho_limit, ortho_limit)
			wp = Vector2i(midx, midy)
		else:
			var midy2: int = clampi(int(round(float(goal_dist) * 0.45)) + rng.randi_range(-1, 1), 2, goal_dist - 2)
			if exit_edge == 0:
				midy2 = -midy2
			var midx2: int = rng.randi_range(-ortho_limit, ortho_limit)
			if midx2 == start_x:
				midx2 = clampi(midx2 + (1 if midx2 < ortho_limit else -1), -ortho_limit, ortho_limit)
			wp = Vector2i(midx2, midy2)

		if wp != p and wp != exit_chunk_target:
			targets.append(wp)

	targets.append(exit_chunk_target)

	var safety: int = 4096
	for t: Vector2i in targets:
		var guard: int = 2048
		while p != t and guard > 0 and safety > 0:
			guard -= 1
			safety -= 1

			var dx: int = signi(t.x - p.x)
			var dy: int = signi(t.y - p.y)

			var prefer_primary: bool = (rng.randf() > meander_ch)

			var cand_a: Vector2i = p
			var cand_b: Vector2i = p
			if exit_edge == 1 or exit_edge == 3:
				# Primary axis: X
				if dx != 0:
					cand_a = p + Vector2i(dx, 0)
				if dy != 0:
					cand_b = p + Vector2i(0, dy)
			else:
				# Primary axis: Y
				if dy != 0:
					cand_a = p + Vector2i(0, dy)
				if dx != 0:
					cand_b = p + Vector2i(dx, 0)

			var candidates: Array[Vector2i] = []
			if prefer_primary:
				if cand_a != p: candidates.append(cand_a)
				if cand_b != p: candidates.append(cand_b)
			else:
				if cand_b != p: candidates.append(cand_b)
				if cand_a != p: candidates.append(cand_a)

			# Occasional perpendicular nudge to keep handwriting less grid-straight.
			if rng.randf() < 0.25:
				if exit_edge == 1 or exit_edge == 3:
					candidates.append(p + Vector2i(0, (1 if rng.randf() < 0.5 else -1)))
				else:
					candidates.append(p + Vector2i((1 if rng.randf() < 0.5 else -1), 0))

			var chosen: Vector2i = p
			for c: Vector2i in candidates:
				var cc: Vector2i = c
				if exit_edge == 1 or exit_edge == 3:
					cc.y = clampi(cc.y, -ortho_limit, ortho_limit)
				else:
					cc.x = clampi(cc.x, -ortho_limit, ortho_limit)
				if not used.has(cc):
					chosen = cc
					break

			if chosen == p:
				# Fall back: move toward the target even if it revisits a chunk (rare).
				if candidates.size() > 0:
					chosen = candidates[0] as Vector2i
					if exit_edge == 1 or exit_edge == 3:
						chosen.y = clampi(chosen.y, -ortho_limit, ortho_limit)
					else:
						chosen.x = clampi(chosen.x, -ortho_limit, ortho_limit)
				else:
					break

			p = chosen
			main_route.append(p)
			used[p] = true

	var start_chunk: Vector2i = main_route[0]
	var exit_chunk: Vector2i = exit_chunk_target

	# ------------------------------------------------------------
	# 2) Side pockets ("risk rooms")
	# ------------------------------------------------------------
	var branch_count: int = 0
	if theme != null:
		branch_count = rng.randi_range(branch_min, branch_max)
	else:
		branch_count = (2 if segment == 2 else 1 if segment == 3 else clampi(1 + int(floor(float(segment - 3) / 3.0)), 1, 3))
		if rng.randf() < 0.25 and segment >= 4:
			branch_count = mini(branch_count + 1, 3)

	# If we want a miniboss arena pocket (optional explore beats), ensure enough side structure exists.
	# Segment 5 uses a near-gate miniboss instead, so we don't force extra branching just for it.
	if want_miniboss_arena and not miniboss_near_gate:
		branch_count = maxi(branch_count, 2)
		max_branch_len = maxi(max_branch_len, 2)

	var chunk_set: Dictionary = used.duplicate()
	var all_chunks: Array[Vector2i] = main_route.duplicate()

	for _i in range(branch_count):
		if main_route.size() < 4:
			break

		var anchor_index := rng.randi_range(1, main_route.size() - 2)
		var anchor: Vector2i = main_route[anchor_index]

		# Branch directions biased perpendicular to the escape flow (reads like side streets / pockets).
		var perp_a: Vector2i = Vector2i(primary_dir.y, -primary_dir.x)
		var perp_b: Vector2i = Vector2i(-primary_dir.y, primary_dir.x)

		var dirs: Array[Vector2i] = [perp_a, perp_b]
		dirs.shuffle()

		# Rare forward pocket, but never past the exit edge.
		if rng.randf() < 0.18:
			dirs = [primary_dir]

		var placed := false
		for d: Vector2i in dirs:
			var cur: Vector2i = anchor
			var blen: int = rng.randi_range(1, max_branch_len)
			for _k in range(blen):
				var nxt: Vector2i = cur + d

				# Guardrails: keep pockets within a band so the layout stays readable.
				var ortho_guard: int = ortho_limit + ortho_guard_bonus
				if primary_dir.x != 0:
					# Primary is X, orthogonal is Y.
					if absi(nxt.y) > ortho_guard:
						break
					# Don't extend beyond the exit edge.
					if d == primary_dir:
						if (primary_dir.x > 0 and nxt.x > exit_chunk.x) or (primary_dir.x < 0 and nxt.x < exit_chunk.x):
							break
				else:
					# Primary is Y, orthogonal is X.
					if absi(nxt.x) > ortho_guard:
						break
					if d == primary_dir:
						if (primary_dir.y > 0 and nxt.y > exit_chunk.y) or (primary_dir.y < 0 and nxt.y < exit_chunk.y):
							break

				if chunk_set.has(nxt):
					break
				chunk_set[nxt] = true
				all_chunks.append(nxt)
				cur = nxt
				placed = true

			if placed:
				break

	# ------------------------------------------------------------
	# 2b) Miniboss placement
	# - Segment 5: required miniboss near the exit gate (teaching beat)
	# - Later segments: optional miniboss as an explore pocket (branch)
	# ------------------------------------------------------------
	var miniboss_chunk: Vector2i = Vector2i(999999, 999999)
	var _miniboss_path: Array[Vector2i] = []

	if want_miniboss_arena:
		if miniboss_near_gate:
			miniboss_chunk = exit_chunk
		elif main_route.size() >= 6:
			var perp_a2: Vector2i = Vector2i(primary_dir.y, -primary_dir.x)
			var perp_b2: Vector2i = Vector2i(-primary_dir.y, primary_dir.x)

			var tries := 18
			while tries > 0:
				tries -= 1

				var low_i: int = int(round(float(main_route.size()) * 0.35))
				var high_i: int = int(round(float(main_route.size()) * 0.75))
				low_i = clampi(low_i, 2, main_route.size() - 3)
				high_i = clampi(high_i, low_i, main_route.size() - 3)

				var anchor_i := rng.randi_range(low_i, high_i)
				var anchor2: Vector2i = main_route[anchor_i]

				var dirs2: Array[Vector2i] = [perp_a2, perp_b2]
				dirs2.shuffle()

				var len2: int = 2
				if theme != null:
					len2 = maxi(2, theme.arena_branch_len)
				len2 += (1 if rng.randf() < 0.35 else 0)

				var placed2 := false
				for d2: Vector2i in dirs2:
					var cur2: Vector2i = anchor2
					var ok := true
					var temp: Array[Vector2i] = []

					for _s in range(len2):
						var nn2: Vector2i = cur2 + d2

						var ortho_guard2: int = ortho_limit + ortho_guard_bonus + 1
						if primary_dir.x != 0:
							if absi(nn2.y) > ortho_guard2:
								ok = false
								break
						else:
							if absi(nn2.x) > ortho_guard2:
								ok = false
								break

						if chunk_set.has(nn2):
							ok = false
							break

						temp.append(nn2)
						cur2 = nn2

					if ok:
						# Commit path chunks.
						for cc in temp:
							chunk_set[cc] = true
							all_chunks.append(cc)
						_miniboss_path = temp.duplicate()
						miniboss_chunk = cur2
						placed2 = true
						break

				if placed2:
					break



	# Fallback: if we wanted a miniboss arena but the search failed, pick a deep non-exit chunk.
	# Prevents softlocks if optional miniboss pocket placement fails.
	if want_miniboss_arena and miniboss_chunk.x == 999999:
		var best: Vector2i = Vector2i(999999, 999999)
		var best_d: float = -1.0
		for c3 in all_chunks:
			var cc3: Vector2i = c3
			if cc3 == exit_chunk or cc3 == start_chunk:
				continue
			var d3 := float(cc3.distance_to(start_chunk))
			if d3 > best_d:
				best_d = d3
				best = cc3
		if best.x != 999999:
			miniboss_chunk = best

	# 3) Optional loops (extra connections) for replayability
	# ------------------------------------------------------------
	var loop_budget: int = 0
	if theme != null:
		loop_budget = rng.randi_range(loop_min, loop_max)
	else:
		loop_budget = (1 if segment >= 4 and rng.randf() < 0.55 else 0)
		if segment >= 7 and rng.randf() < 0.35:
			loop_budget += 1

	if loop_budget > 0 and all_chunks.size() >= 8:
		for _l in range(loop_budget):
			var a: Vector2i = all_chunks[rng.randi_range(0, all_chunks.size() - 1)]
			var b: Vector2i = all_chunks[rng.randi_range(0, all_chunks.size() - 1)]
			if a == b:
				continue
			# only try short loops
			var md: int = abs(a.x - b.x) + abs(a.y - b.y)
			if md < 2 or md > 4:
				continue
			# carve a simple manhattan path between them by adding missing chunks
			var cur3: Vector2i = a
			var step_guard: int = 16
			while cur3 != b and step_guard > 0:
				step_guard -= 1
				var dx2: int = signi(b.x - cur3.x)
				var dy2: int = signi(b.y - cur3.y)
				var step_dir: Vector2i = Vector2i.ZERO
				if dx2 != 0 and (dy2 == 0 or rng.randf() < 0.65):
					step_dir = Vector2i(dx2, 0)
				else:
					step_dir = Vector2i(0, dy2)
				var nn: Vector2i = cur3 + step_dir
				if not chunk_set.has(nn):
					chunk_set[nn] = true
					all_chunks.append(nn)
				cur3 = nn

	# ------------------------------------------------------------
	# 4) Connector masks based on adjacency
	# ------------------------------------------------------------
	var connectors_by_chunk: Dictionary = {}
	for k in chunk_set.keys():
		var c: Vector2i = k
		var m: int = 0
		if chunk_set.has(c + Vector2i(0, -1)): m |= N
		if chunk_set.has(c + Vector2i(1, 0)): m |= E
		if chunk_set.has(c + Vector2i(0, 1)): m |= S
		if chunk_set.has(c + Vector2i(-1, 0)): m |= W
		connectors_by_chunk[c] = m

	# ------------------------------------------------------------
	# 5) Archetypes (special chunks: start / wardstones / gate / miniboss)
	# ------------------------------------------------------------
	# Exit chunk is the outward target on a randomly chosen edge (exit_edge).
	chunk_set[exit_chunk] = true
	if not all_chunks.has(exit_chunk):
		all_chunks.append(exit_chunk)

	var archetype_by_chunk: Dictionary = {}
	for k5 in chunk_set.keys():
		archetype_by_chunk[k5] = &"district"

	archetype_by_chunk[start_chunk] = &"plaza"
	archetype_by_chunk[exit_chunk] = &"gate"

	# Wardstones (2-4) on the main route only, but with jittered picks so repeats feel different.
	var ward_count: int = clampi(2 + int(floor(float(maxi(0, segment - 2)) / 3.0)), 2, 4)
	var wardstone_chunks: Array[Vector2i] = []

	var L := main_route.size()
	for i in range(ward_count):
		var t2 := float(i + 1) / float(ward_count + 1)
		var base_idx := int(round(t2 * float(L - 1)))
		var idx := clampi(base_idx + rng.randi_range(-1, 1), 1, L - 2)
		var ccw: Vector2i = main_route[idx]

		# Avoid start/exit and duplicates.
		var tries2 := 8
		while (ccw == start_chunk or ccw == exit_chunk or wardstone_chunks.has(ccw)) and tries2 > 0:
			tries2 -= 1
			idx = clampi(idx + rng.randi_range(-2, 2), 1, L - 2)
			ccw = main_route[idx]

		if ccw != start_chunk and ccw != exit_chunk and not wardstone_chunks.has(ccw):
			wardstone_chunks.append(ccw)
			archetype_by_chunk[ccw] = &"arena"

	# Miniboss arena chunk. If it's an explore pocket, mark it as an arena.
	# If it's in the exit/gate chunk (segment 5), keep the gate archetype intact.
	if want_miniboss_arena and miniboss_chunk.x != 999999 and miniboss_chunk != exit_chunk:
		archetype_by_chunk[miniboss_chunk] = &"arena"

	# Boss arena: by default, the boss lives in the exit/gate chunk.
	# (Builder spawns the boss and keeps the gate locked until it's dead.)
	var boss_chunk: Vector2i = Vector2i(999999, 999999)
	if want_boss_arena:
		boss_chunk = exit_chunk
		# For boss, slightly prefer "arena" feel in the gate chunk.
		archetype_by_chunk[exit_chunk] = &"arena"

	# ------------------------------------------------------------
	# 6) World-space key positions (centers; builder can add safe jitter)
	# ------------------------------------------------------------
	var start_world := _chunk_center_world(start_chunk, chunk_size_px)
	var exit_world := _chunk_center_world(exit_chunk, chunk_size_px)

	var wardstone_world: Array[Vector2] = []
	for cc6 in wardstone_chunks:
		wardstone_world.append(_chunk_center_world(cc6, chunk_size_px))

	var miniboss_world: Vector2 = Vector2.ZERO
	if want_miniboss_arena and miniboss_chunk.x != 999999:
		miniboss_world = _chunk_center_world(miniboss_chunk, chunk_size_px)

	var boss_world: Vector2 = Vector2.ZERO
	if want_boss_arena:
		boss_world = _chunk_center_world(boss_chunk, chunk_size_px)

	return {
		"seed": int(rng.seed),
		"segment": segment,

		"start_chunk": start_chunk,
		"exit_chunk": exit_chunk,
		"exit_edge": exit_edge,
		"wardstone_chunks": wardstone_chunks,
		"main_route": main_route,

		"start_world": start_world,
		"exit_world": exit_world,
		"wardstone_world": wardstone_world,

		"miniboss_chunk": miniboss_chunk,
		"miniboss_world": miniboss_world,
		"boss_chunk": boss_chunk,
		"boss_world": boss_world,

		"archetype_by_chunk": archetype_by_chunk,
		"connectors_by_chunk": connectors_by_chunk,
		"all_chunks": all_chunks,
	}

static func _chunk_center_world(c: Vector2i, chunk_size_px: int) -> Vector2:
	var half := float(chunk_size_px) * 0.5
	return Vector2(float(c.x * chunk_size_px) + half, float(c.y * chunk_size_px) + half)

static func _mix_seed(a: int, b: int) -> int:
	var h: int = int((a ^ (b * 0x9E3779B9)) & 0x7FFFFFFF)
	h = int((h * 1103515245 + 12345) & 0x7FFFFFFF)
	return h
