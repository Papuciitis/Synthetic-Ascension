extends SceneTree

const CELLS := 6561
const RUNS := 100
const STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


func _init() -> void:
	var allocating: Array[int] = []
	var fixed: Array[int] = []
	var candidate_steps := PackedInt32Array()
	var candidate_penalties := PackedInt32Array()
	candidate_steps.resize(8)
	candidate_penalties.resize(8)
	_fixed_candidate_build(candidate_steps, candidate_penalties)
	var fixed_memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	for _run in range(RUNS):
		var start := Time.get_ticks_usec()
		_legacy_candidate_build()
		allocating.append(Time.get_ticks_usec() - start)
		start = Time.get_ticks_usec()
		_fixed_candidate_build(candidate_steps, candidate_penalties)
		fixed.append(Time.get_ticks_usec() - start)
	var fixed_memory_delta := Performance.get_monitor(Performance.MEMORY_STATIC) - fixed_memory_before
	allocating.sort()
	fixed.sort()
	var legacy_us := allocating[allocating.size() / 2]
	var fixed_us := fixed[fixed.size() / 2]
	print(
		"FlowFieldAllocationBenchmark cells=%d legacy_median_us=%d fixed_median_us=%d speedup=%.2fx"
		% [CELLS, legacy_us, fixed_us, float(legacy_us) / maxf(1.0, float(fixed_us))]
	)
	if fixed_memory_delta > 65536.0:
		push_error("Reusable flow buffers grew static memory by %d bytes" % int(fixed_memory_delta))
		quit(1)
		return
	print("FlowFieldAllocationBenchmark fixed_memory_delta=", int(fixed_memory_delta))
	quit(0)


func _legacy_candidate_build() -> void:
	for cell in range(CELLS):
		var steps := STEPS.duplicate()
		var candidate_steps: Array[Vector2i] = []
		var candidate_penalties: Array[int] = []
		for step_index in range(steps.size()):
			var penalty := (cell + step_index * 3) % 9
			var inserted := false
			for index in range(candidate_steps.size()):
				if penalty < candidate_penalties[index]:
					candidate_steps.insert(index, steps[step_index])
					candidate_penalties.insert(index, penalty)
					inserted = true
					break
			if not inserted:
				candidate_steps.append(steps[step_index])
				candidate_penalties.append(penalty)


func _fixed_candidate_build(candidate_steps: PackedInt32Array, candidate_penalties: PackedInt32Array) -> void:
	for cell in range(CELLS):
		var candidate_count := 0
		for step_index in range(STEPS.size()):
			var penalty := (cell + step_index * 3) % 9
			var insert_at := candidate_count
			while insert_at > 0 and penalty < candidate_penalties[insert_at - 1]:
				candidate_penalties[insert_at] = candidate_penalties[insert_at - 1]
				candidate_steps[insert_at] = candidate_steps[insert_at - 1]
				insert_at -= 1
			candidate_penalties[insert_at] = penalty
			candidate_steps[insert_at] = step_index
			candidate_count += 1
