extends RefCounted
class_name PerformanceHitchTagger

## Names the subsystem behind a slow flight-recorder sample from the fields
## the sample already carries (performance war room M3): the Ascension tree
## (tick / flush / hit handling), Barrage fragments, the projectile
## simulation, a chunk activation or one of its staged blocker steps, a flow
## field snapshot or publish, enemy lifecycle attach / detach / retire, the
## enemy scheduler's step, the recorder's own sampling, or Godot's physics
## monitor as a last resort. Pure and static, so the incident writer can
## call it from its worker thread. Correlation, not proof: the attribution
## says which measured cost was largest in that frame.

const HITCH_MS := 28.0
const BASE_MS := 16.7
## The largest attributable cost must reach this many ms and this share of
## the frame's excess over BASE_MS, else the hitch is "unattributed".
const MIN_ATTRIBUTED_MS := 2.0
const MIN_ATTRIBUTED_SHARE := 0.25
const PHYSICS_MONITOR_SHARE := 0.5
const WORST_LIMIT := 8


static func frame_ms(sample: Dictionary) -> float:
	return float(sample.get("wall_ms", sample.get("frame_ms", 0.0)))


## Attributable milliseconds per subsystem for one sample. `previous` is the
## sample before it (empty for the first), needed for the deltas.
static func attribution(sample: Dictionary, previous: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var ascension: Dictionary = sample.get("ascension", {})
	if not ascension.is_empty():
		var barrage: Dictionary = ascension.get("BR", {})
		var fragment_ms := float(int(barrage.get("fragment_usec", 0))) / 1000.0
		var tree_ms := float(int(ascension.get("tick_usec", 0)) + int(ascension.get("flush_usec", 0)) + int(ascension.get("hit_usec", 0))) / 1000.0
		# Fragment updates run inside the engine tick, so the tree's own
		# share is what is left once the fragments are taken out.
		out["ascension"] = maxf(0.0, tree_ms - fragment_ms)
		out["fragments"] = fragment_ms
	if sample.has("projectile_ms"):
		out["projectiles"] = float(sample.get("projectile_ms", 0.0))
	var stream: Dictionary = sample.get("chunk_stream", {})
	if not stream.is_empty():
		var chunk := _chunk_attribution(stream, previous.get("chunk_stream", {}) as Dictionary)
		if not chunk.is_empty():
			out[String(chunk["tag"])] = float(chunk["ms"])
	if sample.has("flow_revision"):
		var revision_changed := int(sample.get("flow_revision", 0)) != int(previous.get("flow_revision", 0))
		var build_started := bool(sample.get("flow_building", false)) and not bool(previous.get("flow_building", false))
		if revision_changed:
			out["flow"] = float(int(sample.get("flow_publish_usec", 0)) + int(sample.get("flow_snapshot_usec", 0))) / 1000.0
		elif build_started:
			out["flow"] = float(int(sample.get("flow_snapshot_usec", 0))) / 1000.0
	var lifecycle: Dictionary = sample.get("enemy_lifecycle", {})
	var previous_lifecycle: Dictionary = previous.get("enemy_lifecycle", {})
	if not lifecycle.is_empty() and not previous_lifecycle.is_empty():
		var delta_usec := 0
		for key in ["attach_total_usec", "detach_total_usec", "retire_total_usec"]:
			delta_usec += maxi(0, int(lifecycle.get(key, 0)) - int(previous_lifecycle.get(key, 0)))
		out["lifecycle"] = float(delta_usec) / 1000.0
	var scheduler: Dictionary = sample.get("enemy_scheduler", {})
	if scheduler.has("physics_step_ms"):
		out["enemy_step"] = float(scheduler.get("physics_step_ms", 0.0))
	if sample.has("sampling_overhead_usec"):
		out["sampling"] = float(int(sample.get("sampling_overhead_usec", 0))) / 1000.0
	return out


static func _chunk_attribution(stream: Dictionary, previous_stream: Dictionary) -> Dictionary:
	var phases: Dictionary = stream.get("last_phases", {})
	if phases.is_empty():
		return {}
	var previous_phases: Dictionary = previous_stream.get("last_phases", {})
	var coord := String(phases.get("coord", ""))
	var total := float(phases.get("total_ms", 0.0))
	var same_coord := not previous_phases.is_empty() and String(previous_phases.get("coord", "")) == coord
	if same_coord:
		var previous_total := float(previous_phases.get("total_ms", 0.0))
		if total <= previous_total:
			return {}
		# The same chunk grew: one of its staged blocker steps ran this frame.
		var physics_changed := float(phases.get("blocker_physics_ms", 0.0)) != float(previous_phases.get("blocker_physics_ms", 0.0))
		return {"tag": "chunk_blocker_physics" if physics_changed else "chunk_blocker_render", "ms": total - previous_total}
	var best_key := "content_ms"
	var best := -1.0
	var keys := ["setup_ms", "ground_ms", "content_ms", "floor_ms"]
	if phases.has("blocker_physics_ms") and (float(phases.get("blocker_physics_ms", 0.0)) > 0.0 or float(phases.get("blocker_render_ms", 0.0)) > 0.0):
		keys.append("blocker_physics_ms")
		keys.append("blocker_render_ms")
	else:
		keys.append("blocker_ms")
	for key in keys:
		var value := float(phases.get(key, 0.0))
		if value > best:
			best = value
			best_key = key
	return {"tag": "chunk_" + best_key.trim_suffix("_ms"), "ms": total}


## {"tag": String, "ms": float, "frame_ms": float}; tag is "" below HITCH_MS.
static func tag(sample: Dictionary, previous: Dictionary) -> Dictionary:
	var ms := frame_ms(sample)
	if ms <= HITCH_MS:
		return {"tag": "", "ms": 0.0, "frame_ms": ms}
	var costs := attribution(sample, previous)
	var best_key := ""
	var best := 0.0
	for key in costs:
		var value := float(costs[key])
		if value > best:
			best = value
			best_key = String(key)
	var excess := ms - BASE_MS
	if best_key.is_empty() or best < maxf(MIN_ATTRIBUTED_MS, MIN_ATTRIBUTED_SHARE * excess):
		var physics := float(sample.get("physics_ms", 0.0))
		if physics >= PHYSICS_MONITOR_SHARE * ms:
			return {"tag": "physics_monitor", "ms": physics, "frame_ms": ms}
		return {"tag": "unattributed", "ms": best, "frame_ms": ms}
	return {"tag": best_key, "ms": best, "frame_ms": ms}


## Tag distribution over an incident's samples:
## {"hitches": n, "tags": [{tag, count, worst_frame_ms, worst_ms}] by count,
##  "worst": [{t_usec, frame_ms, tag, ms}] the WORST_LIMIT slowest}.
static func distribution(samples: Array) -> Dictionary:
	var by_tag: Dictionary = {}
	var hitches: Array = []
	var previous: Dictionary = {}
	for sample_variant in samples:
		var sample := sample_variant as Dictionary
		if sample == null:
			continue
		var result := tag(sample, previous)
		previous = sample
		var name := String(result["tag"])
		if name.is_empty():
			continue
		var frame := float(result["frame_ms"])
		var ms := float(result["ms"])
		var entry: Dictionary = by_tag.get(name, {"tag": name, "count": 0, "worst_frame_ms": 0.0, "worst_ms": 0.0})
		entry["count"] = int(entry["count"]) + 1
		entry["worst_frame_ms"] = maxf(float(entry["worst_frame_ms"]), frame)
		entry["worst_ms"] = maxf(float(entry["worst_ms"]), ms)
		by_tag[name] = entry
		hitches.append({"t_usec": int(sample.get("t_usec", 0)), "frame_ms": frame, "tag": name, "ms": ms})
	var tags: Array = by_tag.values()
	tags.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["count"]) > int(b["count"]))
	hitches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["frame_ms"]) > float(b["frame_ms"]))
	return {
		"hitches": hitches.size(),
		"tags": tags,
		"worst": hitches.slice(0, mini(WORST_LIMIT, hitches.size())),
	}
