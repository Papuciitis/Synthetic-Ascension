extends Node

## Every primary objective type must be buildable, self-describing and finishable.
##
## The catalog picks by seed, so a type that crashes or never completes would
## only surface on the unlucky run that rolled it - which is exactly the class
## of bug that survives playtesting for months.

var _passes: int = 0
var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _ready() -> void:
	var ids: Array = PrimaryObjectiveCatalog.all_ids()
	_check(ids.size() >= 3, "the catalog offers more than one objective (%d)" % ids.size())

	for id in ids:
		var script := PrimaryObjectiveCatalog.script_for(id)
		_check(script != null, "'%s' resolves to a script" % String(id))
		if script == null:
			continue
		var objective := script.new() as PrimaryObjective
		_check(objective != null, "'%s' is a PrimaryObjective" % String(id))
		if objective == null:
			continue
		objective.configure(4242)

		# describe() runs on a detached node in the HUD path, so it must not
		# depend on being in the tree or on a player existing.
		_check(objective.objective_title().strip_edges() != "", "'%s' has a title" % String(id))
		_check(objective.objective_detail().strip_edges() != "", "'%s' has a detail line" % String(id))
		_check(objective.checklist_label().strip_edges() != "", "'%s' has a checklist row" % String(id))
		_check(objective.checklist_id() != StringName(), "'%s' has a checklist id" % String(id))

		_check(objective.steps_total() >= 1, "'%s' has at least one step" % String(id))
		_check(objective.steps_done() == 0, "'%s' starts at zero progress" % String(id))
		_check(not objective.is_finished(), "'%s' does not start finished" % String(id))

		# finish() is the only route to `completed`, and it must latch.
		# An Array, not an int: GDScript lambdas capture by VALUE, so a counter
		# incremented inside one only ever moves a copy.
		var fired: Array[int] = [0]
		objective.completed.connect(func() -> void: fired[0] += 1)
		objective.finish()
		objective.finish()
		_check(fired[0] == 1, "'%s' emits completed exactly once (%d)" % [String(id), fired[0]])
		_check(objective.is_finished(), "'%s' latches finished" % String(id))
		objective.free()

	# Checklist ids must be distinct, or two objective types would collide on
	# the same Exit Rite row.
	var seen: Dictionary = {}
	for id in ids:
		var script := PrimaryObjectiveCatalog.script_for(id)
		if script == null:
			continue
		var probe := script.new() as PrimaryObjective
		if probe == null:
			continue
		var key := probe.checklist_id()
		_check(not seen.has(key), "checklist id '%s' is unique" % String(key))
		seen[key] = true
		probe.free()

	# The teaching segment must always be the gentlest template, and later
	# segments must actually vary.
	_check(
		PrimaryObjectiveCatalog.pick_id(2, 111) == &"district_relay"
		and PrimaryObjectiveCatalog.pick_id(2, 999) == &"district_relay",
		"segment 2 always teaches with the relay"
	)
	var picked: Dictionary = {}
	for seed_value in range(400):
		picked[PrimaryObjectiveCatalog.pick_id(6, seed_value)] = true
	_check(
		picked.size() == ids.size(),
		"later segments reach every objective type (%d of %d)" % [picked.size(), ids.size()]
	)
	# Same seed, same district: the plan validator and seed reproduction both
	# assume a seed fully determines a segment.
	_check(
		PrimaryObjectiveCatalog.pick_id(7, 31337) == PrimaryObjectiveCatalog.pick_id(7, 31337),
		"the pick is deterministic"
	)

	print("PrimaryObjectiveTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
