extends SceneTree

# Segment 1 story-pass progression checks: spawn stages must mirror into
# ThreatDirector phases (the recon damp used to pin the whole segment).
# Run: <godot> --headless --path . --script res://tools/tests/Segment1ProgressionTest.gd

const SpawnProfile := preload("res://core/systems/spawner/Segment1SpawnProfile.gd")

var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var global := root.get_node("Global")
	global.set("attempt_active", true)
	global.set("attempt_segment", 1)
	global.set("attempt_opening_completed", true)
	if global.get("run_inventory") == null:
		global.call("reset_run_inventory")
	if global.get("run_bag") == null:
		global.call("reset_run_bag_inventory")
	_check(change_scene_to_file("res://scenes/game.tscn") == OK, "segment 1 game scene starts")
	for _frame in range(12):
		await process_frame
	var level1 := current_scene.get_node_or_null("Level1")
	_check(level1 != null, "Level1 builder exists")
	var director := root.get_node_or_null("ThreatDirector")
	_check(director != null, "ThreatDirector autoload exists")
	if level1 == null or director == null:
		_finish()
		return

	var expected := {
		SpawnProfile.Stage.BEFORE_SYNTHESIS: &"recon",
		SpawnProfile.Stage.INITIAL_CONTAINMENT: &"recon",
		SpawnProfile.Stage.ARCHIVE: &"recon",
		SpawnProfile.Stage.COURTYARD: &"disturbance",
		SpawnProfile.Stage.SERVICE: &"disturbance",
		SpawnProfile.Stage.OUTER_APPROACH: &"ascension",
		SpawnProfile.Stage.EXIT_RITE: &"collapse",
	}
	for stage: int in expected:
		level1.call("_set_spawn_stage", stage)
		_check(
			StringName(director.get("segment_phase")) == StringName(expected[stage]),
			"stage %d mirrors phase %s" % [stage, expected[stage]]
		)

	# Restore path: milestones present after a reload must re-derive the phase.
	for milestone in [&"synthesis", &"first_confrontation", &"wardstone_1", &"assistant_commitment"]:
		global.call("record_segment1_milestone", milestone)
	level1.call("_apply_restored_spawn_stage")
	_check(
		StringName(director.get("segment_phase")) == &"disturbance",
		"restore with courtyard milestones re-enters disturbance"
	)
	_finish()


func _finish() -> void:
	print("Segment1ProgressionTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
