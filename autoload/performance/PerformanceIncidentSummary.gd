extends RefCounted
class_name PerformanceIncidentSummary

## The summary block of a flight-recorder incident: frame and wall-time
## percentiles, the engine monitors' peaks, the tree's peak cost, the events
## nearby and the hitch tags. Pure and static, like PerformanceHitchTagger,
## so the report writer builds it on its worker thread: on the frame that
## closes an incident it was 5-27 ms of recorder work (2026-10-01 captures).


static func build(samples: Array, events: Array) -> Dictionary:
	var frame_times: Array[float] = []
	var wall_times: Array[float] = []
	var worst := 0.0
	var worst_wall := 0.0
	var below_60 := 0
	var below_45 := 0
	var below_30 := 0
	var process_peak := 0.0
	var physics_peak := 0.0
	var ascension_peak_usec := 0
	var fragment_peak_usec := 0
	for sample_variant in samples:
		var sample := sample_variant as Dictionary
		var frame_ms := float(sample.get("frame_ms", 0.0))
		frame_times.append(frame_ms)
		worst = maxf(worst, frame_ms)
		var wall_ms := float(sample.get("wall_ms", frame_ms))
		wall_times.append(wall_ms)
		worst_wall = maxf(worst_wall, wall_ms)
		var ascension: Dictionary = sample.get("ascension", {})
		if not ascension.is_empty():
			ascension_peak_usec = maxi(ascension_peak_usec, int(ascension.get("tick_usec", 0)) + int(ascension.get("flush_usec", 0)) + int(ascension.get("hit_usec", 0)))
			var barrage: Dictionary = ascension.get("BR", {})
			fragment_peak_usec = maxi(fragment_peak_usec, int(barrage.get("fragment_usec", 0)))
		process_peak = maxf(process_peak, float(sample.get("process_ms", 0.0)))
		physics_peak = maxf(physics_peak, float(sample.get("physics_ms", 0.0)))
		if frame_ms > 1000.0 / 60.0: below_60 += 1
		if frame_ms > 1000.0 / 45.0: below_45 += 1
		if frame_ms > 1000.0 / 30.0: below_30 += 1
	frame_times.sort()
	wall_times.sort()
	var hitches := PerformanceHitchTagger.distribution(samples)
	return {
		"worst_frame_ms": worst,
		"median_frame_ms": percentile(frame_times, 0.50),
		"p95_frame_ms": percentile(frame_times, 0.95),
		"p99_frame_ms": percentile(frame_times, 0.99),
		# Wall-clock spacing between samples: the frame time the player felt.
		"worst_wall_ms": worst_wall,
		"median_wall_ms": percentile(wall_times, 0.50),
		"p95_wall_ms": percentile(wall_times, 0.95),
		"p99_wall_ms": percentile(wall_times, 0.99),
		"frames_below_60": below_60,
		"frames_below_45": below_45,
		"frames_below_30": below_30,
		# Windowed engine monitors (about one publish a second, rendering
		# synchronisation included): which side peaked, not which script.
		"peak_process_ms": process_peak,
		"peak_physics_ms": physics_peak,
		"dominant_thread": "physics" if physics_peak > process_peak else "process",
		"monitor_note": "process_ms/physics_ms are Godot's windowed monitors and include render sync; frame_ms/delta_ms are the capped process delta; wall_ms is real sample spacing.",
		"peak_ascension_usec": ascension_peak_usec,
		"peak_fragment_usec": fragment_peak_usec,
		"nearby_event_groups": event_groups(events),
		"note": "Events overlap the incident timeline; correlation does not prove causation.",
		# War room M3: every sample over 28 ms wall time named by its largest
		# measured cost (see PerformanceHitchTagger).
		"hitch_count": int(hitches.get("hitches", 0)),
		"hitch_tags": hitches.get("tags", []),
		"worst_hitches": hitches.get("worst", []),
	}


static func percentile(sorted_values: Array[float], fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(int(ceil(fraction * sorted_values.size())) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]


static func event_groups(events: Array) -> Array:
	var groups := {}
	for event_variant in events:
		var event := event_variant as Dictionary
		var key := "%s/%s" % [event.get("category", ""), event.get("name", "")]
		groups[key] = int(groups.get(key, 0)) + int(event.get("amount", 1))
	var output: Array = []
	for key in groups:
		output.append({"event": key, "count": groups[key]})
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["count"]) > int(b["count"]))
	return output.slice(0, mini(12, output.size()))
