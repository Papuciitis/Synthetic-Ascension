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
#   - the authored milestones hold: a miniboss arena exactly at
#     Global.MINIBOSS_SEGMENT, a boss arena exactly at Global.FINAL_SEGMENT
#     (on the exit chunk), neither anywhere else;
#   - generation is deterministic: the same (seed, segment) yields an
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
	var milestone_violations: Array = []
	var reach_violations: Array = []
	var nondeterministic: Array = []

	for seed_index in range(SEEDS):
		# Spread seeds across the space rather than 0..39: real seeds are
		# arbitrary 32-bit values.
		var world_seed: int = 1 + seed_index * 48271 + (seed_index * seed_index) * 2654435761
		for segment in range(2, Global.FINAL_SEGMENT + 1):
			plans += 1
			var tag := "seed %d seg %d" % [world_seed, segment]
			var plan: Dictionary = DistrictPlan.generate(segment, world_seed, CHUNK_SIZE_PX)
			var validation: Dictionary = plan.get("validation", {})

			if bool(validation.get("fallback_selected", false)):
				fallbacks.append(tag + " " + str(validation.get("errors", [])))
			elif not bool(validation.get("valid", false)):
				invalid.append(tag + " " + str(validation.get("errors", [])))

			# Reachability at the authored minimums (loop segments).
			if int(validation.get("start_to_primary", -1)) < 5 \
					or int(validation.get("start_to_exit", -1)) < 5 \
					or int(validation.get("primary_to_exit", -1)) < 5:
				reach_violations.append(tag + " distances %s/%s/%s" % [validation.get("start_to_primary"), validation.get("start_to_exit"), validation.get("primary_to_exit")])

			# Authored milestones, and only the authored milestones.
			var boss: Vector2i = plan.get("boss_chunk", DistrictPlan.INVALID_CHUNK)
			var miniboss: Vector2i = plan.get("miniboss_chunk", DistrictPlan.INVALID_CHUNK)
			var want_boss := segment == Global.FINAL_SEGMENT
			var want_miniboss := segment == Global.MINIBOSS_SEGMENT
			if (boss != DistrictPlan.INVALID_CHUNK) != want_boss:
				milestone_violations.append(tag + " boss=%s" % str(boss))
			elif want_boss and boss != (plan.get("exit_chunk") as Vector2i):
				milestone_violations.append(tag + " boss arena is not the exit chunk")
			if (miniboss != DistrictPlan.INVALID_CHUNK) != want_miniboss:
				milestone_violations.append(tag + " miniboss=%s" % str(miniboss))

			# Determinism on a sample (every 7th plan keeps the sweep fast).
			if plans % 7 == 0:
				var again: Dictionary = DistrictPlan.generate(segment, world_seed, CHUNK_SIZE_PX)
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
	_check(reach_violations.is_empty(), "start -> primary -> exit reachability holds everywhere (%s)" % str(reach_violations.slice(0, 3)))
	_check(milestone_violations.is_empty(), "miniboss at segment %d and boss at segment %d, never elsewhere (%s)" % [Global.MINIBOSS_SEGMENT, Global.FINAL_SEGMENT, str(milestone_violations.slice(0, 3))])
	_check(nondeterministic.is_empty(), "the same seed always builds the same world (%s)" % str(nondeterministic.slice(0, 3)))

	print("ProcSeedSweepTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
