extends Node

# An in-session restart (death -> Restart, or a fresh attempt from the menu
# without reloading the profile) used to keep the previous attempt's
# Doctrine history, offer, stat delta, augment levels and mutations. The old
# taken ids then emptied the next segment-3 offer and the Hub's departure
# stayed blocked; the old run's +30% Power stayed without its price. Both
# attempt boundaries must now clear every choice the run wrote
# (docs/design/2026-10-03-bindings-and-theses.md §7).
#
# Run: <godot> --headless --path . res://tools/tests/AttemptResetTest.tscn

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


func _dirty() -> void:
	Global.start_new_attempt()
	Global.on_segment_completed(3)
	var plates: Array = Global.get_major_choice_offer(3)
	if not plates.is_empty():
		Global.apply_major_choice((plates[1] as MajorChoiceDef).id)
	Global.attempt_major_choice_offer_ids = [&"doctrine_method_open_circuit"]
	Global.add_mutation(&"mut_ranged_shotgun", true)
	Global.attempt_augment_levels = {"augment_tesla_aura": 9}
	Global.attempt_augment_transcended = {"augment_tesla_aura": true}
	Global.attempt_binding_offer = [{"kind": "rank", "id": "augment_tesla_aura", "grade": 1}]
	Global.attempt_binding_recasts = 3
	if Global.attempt_stat_delta == null:
		Global.attempt_stat_delta = StatDelta.new()
	Global.attempt_stat_delta.power += 0.3


func _clean(boundary: String) -> void:
	_check(Global.attempt_major_choice_taken_ids.is_empty(), "%s clears the taken Doctrine ids" % boundary)
	_check(Global.attempt_major_choice_offer_ids.is_empty(), "%s clears the stored Doctrine offer" % boundary)
	_check(Global.attempt_stat_delta == null, "%s clears the Doctrine stat delta" % boundary)
	_check(Global.attempt_augment_levels.is_empty(), "%s clears augment levels" % boundary)
	_check(Global.attempt_mutations.is_empty(), "%s clears mutations" % boundary)
	_check(Global.attempt_augment_transcended.is_empty(), "%s clears Transcendence" % boundary)
	_check(Global.attempt_binding_offer.is_empty() and Global.attempt_binding_recasts == 0, "%s clears the Binding" % boundary)


func _run() -> void:
	_dirty()
	_check(not Global.attempt_major_choice_taken_ids.is_empty(), "the first attempt inscribed a Method plate")
	Global.start_new_attempt()
	_clean("a new attempt")

	_dirty()
	Global.on_attempt_failed_die_die()
	_clean("a failed attempt")

	# The softlock itself: the next run's segment 3 must still deal plates.
	_dirty()
	Global.on_attempt_failed_die_die()
	Global.start_new_attempt()
	Global.on_segment_completed(3)
	var plates: Array = Global.get_major_choice_offer(3)
	_check(plates.size() == 3, "the next run's Method stage deals three plates again (%d)" % plates.size())
	_check(plates.size() > 0 and Global.apply_major_choice((plates[0] as MajorChoiceDef).id), "and one can be inscribed, so the Hub's departure opens")
	_check(not Global.pending_big_choice, "nothing is left pending")

	print("AttemptResetTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
