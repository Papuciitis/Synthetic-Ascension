extends RefCounted
class_name MajorChoiceDB

var defs_by_id: Dictionary = {} # StringName -> MajorChoiceDef
var defs: Array[MajorChoiceDef] = []

func load_from_dir(path: String) -> void:
	defs_by_id.clear()
	defs.clear()
	_scan_dir(path)

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("MajorChoiceDB: dir not found: " + path)
		return

	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if fn.begins_with("."):
			fn = dir.get_next()
			continue

		var full := path.path_join(fn)

		if dir.current_is_dir():
			_scan_dir(full)
		else:
			if fn.ends_with(".tres") or fn.ends_with(".res"):
				var res := ResourceLoader.load(full)
				var def := res as MajorChoiceDef
				if def != null and def.id != StringName():
					defs.append(def)
					defs_by_id[def.id] = def

		fn = dir.get_next()
	dir.list_dir_end()

func get_def(id: StringName) -> MajorChoiceDef:
	return defs_by_id.get(id, null) as MajorChoiceDef

func build_offer(g: Node, count: int, rng: RandomNumberGenerator) -> Array[MajorChoiceDef]:
	var taken: Array = g.get("attempt_major_choice_taken_ids") if g != null else []
	var taken_set: Dictionary = {}
	for t in taken:
		taken_set[StringName(str(t))] = true

	var candidates: Array[MajorChoiceDef] = []
	for d in defs:
		if d == null:
			continue
		if not d.is_available(g):
			continue
		if d.unique_per_attempt and taken_set.has(d.id):
			continue
		candidates.append(d)

	if candidates.is_empty():
		return []

	# Segment 5 "big choice" moment: ensure the offer hits distinct buckets.
	# (augment vs style vs utility), with graceful fallback if some buckets are empty.
	var seg: int = 1
	if g != null and g.has_method("get_major_choice_context_segment"):
		seg = int(g.call("get_major_choice_context_segment"))
	elif g != null and g.has_method("get"):
		seg = int(g.get("attempt_segment"))
	if seg == 5 and count >= 3:
		return _build_bucketed_offer(candidates, count, rng, [&"augment", &"style", &"utility"])

	# Default: shuffled sample
	_shuffle_in_place(candidates, rng)
	var out: Array[MajorChoiceDef] = []
	for k in range(min(count, candidates.size())):
		out.append(candidates[k])
	return out


func _build_bucketed_offer(
	candidates_in: Array[MajorChoiceDef],
	count: int,
	rng: RandomNumberGenerator,
	buckets: Array[StringName]
) -> Array[MajorChoiceDef]:
	# Copy so we can remove selections
	var candidates: Array[MajorChoiceDef] = []
	for d in candidates_in:
		candidates.append(d)

	var out: Array[MajorChoiceDef] = []

	# Pick 1 from each bucket first
	for b in buckets:
		var pool: Array[MajorChoiceDef] = []
		for d2 in candidates:
			if d2 == null:
				continue
			var cat: StringName = d2.category
			# Treat empty category as utility for safety.
			if cat == StringName():
				cat = &"utility"
			if cat == b:
				pool.append(d2)

		if pool.is_empty():
			continue

		_shuffle_in_place(pool, rng)
		var pick: MajorChoiceDef = pool[0]
		out.append(pick)
		candidates.erase(pick)

	# Fill remaining slots from whatever is left.
	if out.size() < count and not candidates.is_empty():
		_shuffle_in_place(candidates, rng)
		for d3 in candidates:
			out.append(d3)
			if out.size() >= count:
				break

	return out


func _shuffle_in_place(arr: Array, rng: RandomNumberGenerator) -> void:
	# Fisher–Yates with RNG
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
