extends SceneTree

# Segment 1 story-pass progression checks: spawn stages must mirror into
# ThreatDirector phases (the recon damp used to pin the whole segment).
# Run: <godot> --headless --path . --script res://tools/tests/Segment1ProgressionTest.gd

# Loaded in _run(), not preloaded: parse-time preloads in --script mode drag
# gameplay scripts in before the autoloads register and spam compile errors.
var SpawnProfile: GDScript = null

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
	SpawnProfile = load("res://core/systems/spawner/Segment1SpawnProfile.gd")
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
	# Chunk streaming is budgeted per frame; wait until the start cell is
	# actually walkable so spawn-position probes below are deterministic.
	var chunk_manager := get_first_node_in_group(&"chunk_manager")
	var streamed := false
	for _frame in range(600):
		if chunk_manager != null and bool(chunk_manager.call("is_cell_walkable", Vector2i(15, 25))):
			streamed = true
			break
		await process_frame
	_check(streamed, "chunk streaming made the start cell walkable")
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

	# The authored spawn filter must actually be consulted (it was dead code):
	# a position in the void far outside the 75x91 footprint is rejected, a
	# position inside the facility is accepted.
	var spawner := get_first_node_in_group(&"enemy_spawner")
	if spawner != null:
		# Populate the indoor-volume snapshot now so the probes below do not
		# depend on whether a spawn tick has already refreshed it.
		spawner.set("_spawn_geometry_refresh_t", 0.0)
		spawner.call("_refresh_spawn_geometry_cache")
		_check(
			not bool(spawner.call("_is_spawn_position_valid", Vector2(-10000.0, -10000.0))),
			"spawner rejects void positions outside the authored footprint"
		)
		_check(
			bool(spawner.call("_is_spawn_position_valid", Vector2(0.0, 1280.0))),
			"spawner accepts a walkable facility position"
		)

	# Service-district rooms are tracked secondaries with guaranteed loot.
	var secondaries: Array = level1.get("_secondaries")
	_check(secondaries.size() == 3, "three secondaries registered (got %d)" % secondaries.size())
	var volumes_with_ids := 0
	var warehouse_has_encounter := false
	for volume in get_nodes_in_group(&"indoor_volume"):
		var sec_id := int(volume.get("secondary_objective_id"))
		if sec_id > 0:
			volumes_with_ids += 1
			if bool(volume.get("local_encounter_enabled")):
				warehouse_has_encounter = true
			_check(
				float(volume.get("small_loot_chance")) >= 0.999,
				"secondary room %d has guaranteed loot" % sec_id
			)
	_check(volumes_with_ids == 3, "three indoor volumes carry secondary ids (got %d)" % volumes_with_ids)
	_check(warehouse_has_encounter, "the warehouse secondary runs a local encounter")

	# Completion pays resonance exactly once per objective.
	var resonance_before := float(level1.get("resonance"))
	var first_id := int((secondaries[0] as Dictionary).get("id", 0))
	root.get_node("RunEvents").emit_signal("secondary_objective_completed", first_id)
	root.get_node("RunEvents").emit_signal("secondary_objective_completed", first_id)
	var resonance_after := float(level1.get("resonance"))
	var expected_gain := float(level1.get("resonance_secondary"))
	_check(
		absf((resonance_after - resonance_before) - expected_gain) < 0.0001,
		"secondary completion granted resonance exactly once"
	)

	# Restore path: milestones present after a reload must re-derive the phase.
	for milestone in [&"synthesis", &"first_confrontation", &"wardstone_1", &"assistant_commitment"]:
		global.call("record_segment1_milestone", milestone)
	level1.call("_apply_restored_spawn_stage")
	_check(
		StringName(director.get("segment_phase")) == &"disturbance",
		"restore with courtyard milestones re-enters disturbance"
	)

	# Gate checklist: LOCKED -> LOCATED -> READY with five structured items.
	var captured: Array = []
	root.get_node("RunEvents").gate_checklist_changed.connect(
		func(state: StringName, items: Array, next_hint: String) -> void:
			captured.append({"state": state, "items": items, "hint": next_hint})
	)
	level1.set("_last_checklist_key", "")
	level1.call("_update_gate_lock")
	_check(not captured.is_empty(), "checklist emitted on gate tick")
	if not captured.is_empty():
		var first: Dictionary = captured[-1]
		_check(StringName(first["state"]) == &"locked", "checklist starts LOCKED")
		_check((first["items"] as Array).size() == 5, "checklist carries five items")

	for milestone in [&"security_started", &"security_cleared", &"wardstone_2"]:
		global.call("record_segment1_milestone", milestone)
	level1.call("_refresh_progression_seals")
	level1.call("_update_gate_lock")
	_check(
		not captured.is_empty() and StringName((captured[-1] as Dictionary)["state"]) == &"located",
		"final checkpoint moves the checklist to LOCATED"
	)

	global.call("record_segment1_milestone", &"final_plaza")
	level1.set("resonance", 1.0)
	level1.call("_update_gate_lock")
	var last: Dictionary = captured[-1] if not captured.is_empty() else {}
	_check(
		not last.is_empty() and StringName(last["state"]) == &"ready",
		"plaza + full resonance moves the checklist to READY"
	)
	if not last.is_empty():
		var all_done: bool = (last["items"] as Array).all(
			func(item: Dictionary) -> bool: return bool(item["done"])
		)
		_check(all_done, "READY checklist shows every item done")
	# Admissions wing: geometry, milestone arms, and full-opening start rules.
	var wall_kind: Dictionary = level1.get("_wall_kind")
	_check(wall_kind.has(Vector2i(-2, 31)), "wing west wall exists")
	_check(wall_kind.has(Vector2i(21, 44)), "wing east wall exists")
	_check(not wall_kind.has(Vector2i(9, 45)), "street entrance gap is open")
	_check(not wall_kind.has(Vector2i(15, 30)), "lab door gap is open")
	_check(wall_kind.has(Vector2i(13, 30)) and wall_kind.has(Vector2i(17, 30)), "lab door is framed")

	var reached_ids: Array = []
	level1.connect("milestone_reached", func(id: StringName) -> void: reached_ids.append(id))
	level1.call("_on_milestone_reached", &"admitted")
	_check(bool(global.call("has_segment1_milestone", &"admitted")), "admissions milestone records")
	_check(reached_ids.has(&"admitted"), "milestone_reached signal fires")

	# Evidence beat: the route strip records; the veteran path stays silent.
	global.set("pending_augment_pick", false)
	level1.call("_on_milestone_reached", &"evidence_store")
	_check(bool(global.call("has_segment1_milestone", &"evidence_store")), "evidence milestone records")
	_check(current_scene.has_method("present_augment_pick_and_wait"), "game exposes awaitable augment pick")

	# City reveal: records once and survives a headless (cameraless) run.
	level1.call("_on_milestone_reached", &"city_reveal")
	_check(bool(global.call("has_segment1_milestone", &"city_reveal")), "city reveal milestone records")

	global.set("attempt_opening_completed", false)
	global.set("attempt_opening_mode", &"full")
	global.set("attempt_opening_phase", 0)
	_check(bool(level1.call("_opening_wants_entrance_start")), "full opening starts at the entrance")
	global.set("attempt_opening_phase", 4)
	_check(not bool(level1.call("_opening_wants_entrance_start")), "post-admission resume starts in the lab corridor")
	global.set("attempt_opening_mode", &"short")
	global.set("attempt_opening_phase", 0)
	_check(not bool(level1.call("_opening_wants_entrance_start")), "short mode keeps the corridor start")
	global.set("attempt_opening_completed", true)
	_finish()


func _finish() -> void:
	print("Segment1ProgressionTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
