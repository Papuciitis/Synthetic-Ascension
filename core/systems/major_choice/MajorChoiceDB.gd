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


## One plate per role, in fixed order. Each role is a weighted draw: a
## plate's weight is its base score plus one per build tag the context
## carries, so a build leans its offer without fixing it (the old "highest
## score always wins" showed the same nine plates every run). An Apocrypha
## stage draws from every stage's untaken plates. A role with no candidate
## is left out rather than emptying the whole offer, so a stage can never
## open a screen with nothing to inscribe while any plate remains.
func build_stage_offer(context: RefCounted, taken_ids: Array, rng: RandomNumberGenerator) -> Array[MajorChoiceDef]:
	if context == null:
		return []
	var taken: Dictionary = {}
	for value in taken_ids:
		taken[StringName(str(value))] = true
	var stage_id := StringName(str(context.get("stage_id")))
	var any_stage := String(stage_id).begins_with("apocrypha_")
	var output: Array[MajorChoiceDef] = []
	for role in [&"amplify", &"transfigure", &"covenant"]:
		var candidates: Array[MajorChoiceDef] = []
		for definition in defs:
			if definition == null or not definition.is_doctrine_complete():
				continue
			if definition.offer_role != role:
				continue
			if not any_stage and definition.stage != stage_id:
				continue
			if definition.unique_per_attempt and taken.has(definition.id):
				continue
			candidates.append(definition)
		if candidates.is_empty():
			continue
		# A stable order first, so the seeded draw deals the same plate for
		# the same seed whatever order the directory scan produced.
		candidates.sort_custom(func(a: MajorChoiceDef, b: MajorChoiceDef) -> bool: return String(a.id) < String(b.id))
		output.append(_weighted_pick(candidates, context, rng))
	return output


func _weighted_pick(candidates: Array[MajorChoiceDef], context: RefCounted, rng: RandomNumberGenerator) -> MajorChoiceDef:
	var weights: Array[float] = []
	var total := 0.0
	for candidate in candidates:
		var weight := maxf(0.01, candidate.offer_weight_for(context))
		weights.append(weight)
		total += weight
	var roll := rng.randf() * total
	for i in range(candidates.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[candidates.size() - 1]


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
