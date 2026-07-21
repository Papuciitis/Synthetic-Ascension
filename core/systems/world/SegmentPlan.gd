extends RefCounted
class_name SegmentPlan

# Generates a coherent, forward-moving chunk route for segments 2-10.
# This is intentionally *lightweight*: it gives ChunkManager archetypes + special locations (wardstones, gate).
#
# Coherence comes from:
# - a main path that always advances +X
# - bounded Y drift
# - a small number of optional side-branches ("risk pockets")

static func generate(segment: int, attempt_world_seed: int, chunk_size_px: int) -> Dictionary:
	segment = maxi(1, segment)

	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(attempt_world_seed, segment)

	# --- main path ---
	var path_len: int = 4 + int(floor(float(maxi(0, segment - 2)) * 0.5)) # 2->4,3->4,4->5,...,10->8
	path_len = clampi(path_len, 4, 10)

	var y_limit: int = 2 if segment <= 5 else 3
	var y: int = 0

	var path: Array[Vector2i] = []
	path.append(Vector2i.ZERO)

	for i in range(path_len):
		# 35% chance to drift up/down by 1 (keeps route readable)
		if rng.randf() < 0.35:
			y += rng.randi_range(-1, 1)
			y = clampi(y, -y_limit, y_limit)
		path.append(Vector2i(i + 1, y))

	var start_chunk: Vector2i = path[0]
	var exit_chunk: Vector2i = path[path.size() - 1]

	# --- wardstones along the route ---
	var ward_count: int = clampi(2 + int(floor(float(maxi(0, segment - 2)) / 3.0)), 2, 4)

	var idxs: Array[int] = []
	idxs.append(clampi(int(round(float(path_len) * 0.33)), 1, path_len - 1))
	idxs.append(clampi(int(round(float(path_len) * 0.66)), 1, path_len - 1))
	if ward_count >= 3:
		idxs.append(clampi(int(round(float(path_len) * 0.50)), 1, path_len - 1))

	while idxs.size() < ward_count:
		idxs.append(rng.randi_range(1, path_len - 1))

	# unique + trim
	var uniq: Array[int] = []
	for id in idxs:
		if (not uniq.has(id)) and id != 0 and id != path_len:
			uniq.append(id)
	idxs = uniq
	while idxs.size() > ward_count:
		idxs.pop_back()

	var ward_chunks: Array[Vector2i] = []
	for id in idxs:
		ward_chunks.append(path[id])

	# --- optional risk pockets (branches) ---
	var branch_count: int = 0
	if segment == 2:
		branch_count = 2
	elif segment == 3:
		branch_count = 1
	else:
		branch_count = rng.randi_range(1, 2)

	var all_chunks: Array[Vector2i] = path.duplicate()
	var archetype_by_chunk: Dictionary = {}

	var base_arch: StringName = (&"courtyard" if segment == 2 else &"street")
	for c in path:
		archetype_by_chunk[c] = base_arch

	# Special chunks must be open-ish.
	for wc in ward_chunks:
		archetype_by_chunk[wc] = (&"courtyard" if segment == 2 else &"arena")
	archetype_by_chunk[exit_chunk] = &"arena"

	for b in range(branch_count):
		if path.size() < 3:
			break
		var base := path[rng.randi_range(1, path.size() - 2)]
		var dir := Vector2i(0, 1 if rng.randf() < 0.5 else -1)
		var blen := rng.randi_range(1, 2 if segment == 2 else 1)

		var cur := base
		for j in range(blen):
			cur += dir
			if not all_chunks.has(cur):
				all_chunks.append(cur)
				archetype_by_chunk[cur] = base_arch

	# --- world positions (center of chunk, with tiny jitter) ---
	var start_world := _chunk_center(start_chunk, chunk_size_px)
	var exit_world := _chunk_center(exit_chunk, chunk_size_px)

	# Give a little offset so you don't spawn exactly on the chunk's mathematical center every run.
	var jitter := float(chunk_size_px) * 0.18
	start_world += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
	exit_world += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))

	var ward_worlds: Array[Vector2] = []
	for wc in ward_chunks:
		var p := _chunk_center(wc, chunk_size_px) + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		ward_worlds.append(p)

	return {
		"segment": segment,
		"seed": int(rng.seed),
		"start_chunk": start_chunk,
		"exit_chunk": exit_chunk,
		"path_chunks": path,
		"wardstone_chunks": ward_chunks,
		"all_chunks": all_chunks,
		"archetype_by_chunk": archetype_by_chunk,
		"start_world": start_world,
		"exit_world": exit_world,
		"wardstone_world": ward_worlds,
	}

static func _chunk_center(cc: Vector2i, chunk_size_px: int) -> Vector2:
	return Vector2((float(cc.x) + 0.5) * float(chunk_size_px), (float(cc.y) + 0.5) * float(chunk_size_px))

static func _mix_seed(base_seed: int, segment: int) -> int:
	# Deterministic mix so each segment is different but stable within an attempt.
	var h: int = base_seed
	h = int((h ^ (segment * 104729)) & 0x7FFFFFFF)
	h = int((h * 48271) & 0x7FFFFFFF)
	if h == 0:
		h = 1337 + segment * 1009
	return h
