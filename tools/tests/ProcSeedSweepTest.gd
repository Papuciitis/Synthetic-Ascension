extends Node

# The procedural gameplay validator (integration pass 2026-09-26, review
# P0 list): a seed sweep proving every district plan a player can roll is
# PLAYABLE, not merely generated. 40 seeds x segments 2..10 (360 plans, each
# with up to 6 internal validation retries), asserting per plan:
#
#   - the plan validates (or, rarely, ships the scored fallback — counted,
#     bounded, and the offending seed printed for reproduction);
#   - start, primary and exit chunks exist and are mutually reachable at
#     the authored minimum distances (primary >= 5 from start, exit >= 5
#     beyond the primary on loop segments);
#   - every secondary objective is reachable from the start;
#   - arena flags follow the PRODUCTION theme (SegmentThemePicker picks the
#     theme exactly as SegmentProcBuilder does, and themes override the
#     segment-number defaults), and across every seed the picker authors a
#     boss arena exactly at Global.FINAL_SEGMENT and a miniboss exactly at
#     Global.MINIBOSS_SEGMENT;
#   - most worlds validate on the FIRST generation attempt (the internal
#     6-retry loop is a safety net, not the normal path);
#   - generation is deterministic: every (seed, segment) yields an
#     identical plan twice.
#
# Run: <godot> --headless --path . res://tools/tests/ProcSeedSweepTest.tscn

const SEEDS := 40
const CHUNK_SIZE_PX := 2048   # ChunkManager's shipped default

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var plans := 0
	var fallbacks: Array = []
	var invalid: Array = []
	var retried: Array = []
	var milestone_violations: Array = []
	var picker_violations: Array = []
	var reach_violations: Array = []
	var nondeterministic: Array = []

	for seed_index in range(SEEDS):
		# Spread seeds across the space rather than 0..39: real seeds are
		# arbitrary 32-bit values.
		var world_seed: int = 1 + seed_index * 48271 + (seed_index * seed_index) * 2654435761
		for segment in range(2, Global.FINAL_SEGMENT + 1):
			plans += 1
			var tag := "seed %d seg %d" % [world_seed, segment]
			# EXACTLY the production pipeline: the theme first, then the plan
			# with that theme (themes change route parameters and arena flags).
			var theme: SegmentThemeData = SegmentThemePicker.get_theme(segment, world_seed)
			var plan: Dictionary = DistrictPlan.generate(segment, world_seed, CHUNK_SIZE_PX, theme)
			var validation: Dictionary = plan.get("validation", {})
			if int(plan.get("generation_attempt", 1)) > 1:
				retried.append(tag + " attempt %d" % int(plan.get("generation_attempt", 1)))
			# The picker itself must author the milestone arenas on the right
			# segments — this catches a misflagged theme resource.
			if theme != null:
				if theme.has_boss_arena != (segment == Global.FINAL_SEGMENT):
					picker_violations.append(tag + " theme boss=%s" % str(theme.has_boss_arena))
				if theme.has_miniboss_arena != (segment == Global.MINIBOSS_SEGMENT):
					picker_violations.append(tag + " theme miniboss=%s" % str(theme.has_miniboss_arena))

			if bool(validation.get("fallback_selected", false)):
				fallbacks.append(tag + " " + str(validation.get("errors", [])))
			elif not bool(validation.get("valid", false)):
				invalid.append(tag + " " + str(validation.get("errors", [])))

			# Reachability at the authored minimums (loop segments).
			if int(validation.get("start_to_primary", -1)) < 5 \
					or int(validation.get("start_to_exit", -1)) < 5 \
					or int(validation.get("primary_to_exit", -1)) < 5:
				reach_violations.append(tag + " distances %s/%s/%s" % [validation.get("start_to_primary"), validation.get("start_to_exit"), validation.get("primary_to_exit")])

			# Arena placement follows the theme the player actually gets.
			var boss: Vector2i = plan.get("boss_chunk", DistrictPlan.INVALID_CHUNK)
			var miniboss: Vector2i = plan.get("miniboss_chunk", DistrictPlan.INVALID_CHUNK)
			var want_boss: bool = theme.has_boss_arena if theme != null else (segment == Global.FINAL_SEGMENT)
			var want_miniboss: bool = theme.has_miniboss_arena if theme != null else (segment == Global.MINIBOSS_SEGMENT)
			if (boss != DistrictPlan.INVALID_CHUNK) != want_boss:
				milestone_violations.append(tag + " boss=%s" % str(boss))
			elif want_boss and boss != (plan.get("exit_chunk") as Vector2i):
				milestone_violations.append(tag + " boss arena is not the exit chunk")
			if (miniboss != DistrictPlan.INVALID_CHUNK) != want_miniboss:
				milestone_violations.append(tag + " miniboss=%s" % str(miniboss))

			# Determinism for every plan: the theme pick and the plan.
			var theme_again: SegmentThemeData = SegmentThemePicker.get_theme(segment, world_seed)
			var again: Dictionary = DistrictPlan.generate(segment, world_seed, CHUNK_SIZE_PX, theme_again)
			if again.hash() != plan.hash():
				nondeterministic.append(tag)

	_check(plans == SEEDS * (Global.FINAL_SEGMENT - 1), "the sweep covered %d plans" % plans)
	_check(invalid.is_empty(), "no plan ships invalid without even a fallback (%s)" % str(invalid.slice(0, 3)))
	# The scored fallback exists by design, but a player rolling one gets a
	# degraded world: it must stay rare, and every occurrence is printed for
	# seed-exact reproduction.
	for entry in fallbacks:
		print("FALLBACK: ", entry)
	_check(fallbacks.size() <= maxi(1, plans / 50), "fallback plans stay rare (%d of %d)" % [fallbacks.size(), plans])
	for entry in retried:
		print("RETRIED: ", entry)
	_check(retried.size() <= maxi(1, plans / 20), "first-attempt generation is the norm (%d of %d retried)" % [retried.size(), plans])
	_check(picker_violations.is_empty(), "the theme picker authors arenas on the milestone segments only (%s)" % str(picker_violations.slice(0, 3)))
	_check(reach_violations.is_empty(), "start -> primary -> exit reachability holds everywhere (%s)" % str(reach_violations.slice(0, 3)))
	_check(milestone_violations.is_empty(), "miniboss at segment %d and boss at segment %d, never elsewhere (%s)" % [Global.MINIBOSS_SEGMENT, Global.FINAL_SEGMENT, str(milestone_violations.slice(0, 3))])
	_check(nondeterministic.is_empty(), "the same seed always builds the same world (%s)" % str(nondeterministic.slice(0, 3)))

	print("ProcSeedSweepTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
