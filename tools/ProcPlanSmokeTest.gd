extends SceneTree

const SEGMENT_FIRST: int = 2
const SEGMENT_LAST: int = 10
const SEEDS_PER_SEGMENT: int = 40
const CHUNK_SIZE_PX: int = 2048

func _initialize() -> void:
	var failures: Array[String] = []
	var reachable_score: int = DistrictPlan.validation_score({
		"valid": false,
		"errors": ["exit_not_beyond_primary"],
		"start_to_primary": 5,
		"start_to_exit": 7,
		"primary_to_exit": 2,
		"secondary_count": 2,
	})
	var unreachable_score: int = DistrictPlan.validation_score({
		"valid": false,
		"errors": ["primary_unreachable_or_too_close"],
		"start_to_primary": -1,
		"start_to_exit": -1,
		"primary_to_exit": -1,
		"secondary_count": 3,
	})
	if reachable_score <= unreachable_score:
		failures.append("fallback scoring did not prioritize reachable candidate")
	var shortest_exit: int = 999999
	var shortest_primary_to_exit: int = 999999
	var narrow_route_plans: int = 0
	var secondary_counts: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}

	for segment in range(SEGMENT_FIRST, SEGMENT_LAST + 1):
		for seed_index in range(SEEDS_PER_SEGMENT):
			var seed_value: int = 100003 + segment * 7919 + seed_index * 104729
			var theme := SegmentThemePicker.get_theme(segment, seed_value)
			var plan := DistrictPlan.generate(segment, seed_value, CHUNK_SIZE_PX, theme)
			var validation: Dictionary = plan.get("validation", {}) as Dictionary
			if not bool(validation.get("valid", false)):
				failures.append("segment=%d seed=%d validation=%s" % [segment, seed_value, str(validation)])
				continue
			shortest_exit = mini(shortest_exit, int(validation.get("start_to_exit", 999999)))
			var primary_to_exit: int = int(validation.get("primary_to_exit", -1))
			shortest_primary_to_exit = mini(shortest_primary_to_exit, primary_to_exit)
			if primary_to_exit < 5:
				failures.append(
					"segment=%d seed=%d primary_to_exit=%d" % [segment, seed_value, primary_to_exit]
				)
			var secondary_count: int = int(validation.get("secondary_count", 0))
			secondary_counts[secondary_count] = int(secondary_counts.get(secondary_count, 0)) + 1
			var roles: Dictionary = plan.get("role_by_chunk", {}) as Dictionary
			if roles.values().has(&"dangerous_alley") or roles.values().has(&"secondary_alley_cache"):
				narrow_route_plans += 1

	print("[ProcPlanSmokeTest] plans=", (SEGMENT_LAST - SEGMENT_FIRST + 1) * SEEDS_PER_SEGMENT,
		" failures=", failures.size(),
		" shortest_exit_graph=", shortest_exit,
		" shortest_primary_to_exit=", shortest_primary_to_exit,
		" narrow_route_plans=", narrow_route_plans,
		" secondary_counts=", secondary_counts)
	for failure in failures.slice(0, 20):
		push_error("[ProcPlanSmokeTest] %s" % failure)
	quit(1 if not failures.is_empty() else 0)
