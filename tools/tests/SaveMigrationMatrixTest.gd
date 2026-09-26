extends Node

# The save migration matrix (integration pass 2026-09-26, review P0 list):
# saves written by older builds must load into a CORRECT current state, not
# merely load. Every case drives the production Global.apply_save on a
# constructed SaveData — in memory only, nothing touches SaveManager or disk
# (decision D-18).
#
# Covered shapes:
#   - opening v0 (pre-cinematic saves): past-synthesis and past-segment-1
#     runs are never dragged back into the opening; a genuinely fresh v0
#     save still plays it.
#   - opening v1 -> v2: the inserted ADMISSION phase shifts saved phases.
#   - segment-1 layout v2 -> v3: stale checkpoints/spatial milestones reset,
#     narrative facts preserved; later segments keep their checkpoints.
#   - ascension state from before V5: missing keys (tree_version,
#     paid_ranks, equipped v2/reaction, reaction_trigger) are repaired.
#   - value hygiene: clamps, whitespace milestone ids, duplicate permanent
#     augment slots, empty mortal name, newer-build saves load best-effort.
#
# Run: <godot> --headless --path . res://tools/tests/SaveMigrationMatrixTest.tscn

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


## A minimal active-attempt save the way an older build would have shaped it.
func _old_save(segment: int) -> SaveData:
	var save := SaveData.new()
	save.slot_index = 97
	save.attempt_active = true
	save.attempt_segment = segment
	save.attempt_style_id = "ranged"
	save.last_style_id = "ranged"
	return save


func _run() -> void:
	SaveManager.current_save = null   # every write path must stay a no-op

	# --- Opening v0, run already past synthesis: never replay the cinematic.
	var save := _old_save(1)
	save.attempt_opening_version = 0
	save.attempt_segment1_layout_version = Global.SEGMENT1_LAYOUT_VERSION
	save.attempt_segment1_milestones = ["synthesis", "first_confrontation", "assistant_commitment"]
	Global.apply_save(save)
	_check(Global.attempt_opening_completed, "v0 past synthesis: the opening is marked completed")
	_check(Global.attempt_opening_version == Global.OPENING_SEQUENCE_VERSION, "v0 past synthesis: version is current (%d)" % Global.attempt_opening_version)
	_check(Global.attempt_opening_officer_completed and Global.attempt_opening_bren_committed, "v0 past synthesis: officer/assistant facts recovered from milestones")
	_check(String(Global.attempt_opening_mode) == "legacy", "v0 past synthesis: marked as a legacy opening")

	# --- Opening v0, run already in segment 4: same protection, no milestones needed.
	save = _old_save(4)
	save.attempt_opening_version = 0
	Global.apply_save(save)
	_check(Global.attempt_opening_completed, "v0 beyond segment 1: the opening is completed")
	_check(not Global.attempt_opening_officer_completed, "v0 beyond segment 1: unwitnessed facts stay false")

	# --- Opening v0, genuinely fresh segment-1 save: the opening still plays.
	save = _old_save(1)
	save.attempt_opening_version = 0
	save.attempt_segment1_layout_version = Global.SEGMENT1_LAYOUT_VERSION
	Global.apply_save(save)
	_check(not Global.attempt_opening_completed, "v0 fresh run: the opening still plays")
	_check(Global.attempt_opening_version == Global.OPENING_SEQUENCE_VERSION, "v0 fresh run: version is still bumped")

	# --- Opening v1 -> v2: ADMISSION inserted after HISTORICAL shifts phases.
	save = _old_save(1)
	save.attempt_opening_version = 1
	save.attempt_opening_phase = 2
	Global.apply_save(save)
	_check(Global.attempt_opening_phase == 3, "v1 phase 2 resumes at 3 after the ADMISSION insert (%d)" % Global.attempt_opening_phase)
	save = _old_save(1)
	save.attempt_opening_version = 1
	save.attempt_opening_phase = 1
	Global.apply_save(save)
	_check(Global.attempt_opening_phase == 1, "v1 phase 1 is untouched by the insert")

	# --- Segment-1 layout v2 -> v3: stale spatial state resets, narrative holds.
	save = _old_save(1)
	save.attempt_segment1_layout_version = 2
	save.attempt_checkpoint_pos = Vector2(500, 300)
	save.attempt_segment1_resonance = 0.7
	save.attempt_segment1_milestones = ["synthesis", "wardstone_1", "final_plaza"]
	save.attempt_opening_version = Global.OPENING_SEQUENCE_VERSION
	save.attempt_opening_completed = true
	save.attempt_opening_officer_completed = true
	Global.apply_save(save)
	_check(Global.attempt_checkpoint_pos == Vector2.INF, "layout v2: the stale checkpoint is unsafe and resets")
	_check(is_zero_approx(Global.attempt_segment1_resonance), "layout v2: spatial resonance resets")
	_check(not Global.attempt_segment1_milestones.has(&"final_plaza") and not Global.attempt_segment1_milestones.has(&"wardstone_1"), "layout v2: spatial milestones reset")
	_check(Global.attempt_segment1_milestones.has(&"synthesis") and Global.attempt_segment1_milestones.has(&"first_confrontation"), "layout v2: narrative facts are rebuilt, not lost")
	_check(Global.attempt_segment1_layout_version == Global.SEGMENT1_LAYOUT_VERSION, "layout v2: version is current")

	# --- The layout reset never touches a run beyond segment 1.
	save = _old_save(3)
	save.attempt_segment1_layout_version = 2
	save.attempt_checkpoint_pos = Vector2(500, 300)
	Global.apply_save(save)
	_check(Global.attempt_checkpoint_pos == Vector2(500, 300), "later segments keep their checkpoint through a layout bump")

	# --- A pre-Doctrine save (doctrine_version 0) retires its whole tree
	# state by design: a pending pre-Doctrine offer would open an empty modal
	# and soft-lock Hub Continue.
	save = _old_save(2)
	save.attempt_doctrine_version = 0
	save.attempt_ascension = {"native_core": "ranged", "owned": {"core.ranged": 1, "BR01": 1}}
	save.attempt_pending_big_choice = true
	Global.apply_save(save)
	_check(Global.attempt_ascension.is_empty(), "a pre-Doctrine save retires its obsolete ascension state")
	_check(not Global.pending_big_choice, "a pre-Doctrine pending offer is retired, never an empty modal")

	# --- Doctrine-era save whose ascension dict predates V5: missing keys are
	# repaired, ownership kept.
	save = _old_save(2)
	save.attempt_doctrine_version = Global.ASCENSION_DOCTRINE_VERSION
	save.attempt_ascension = {"native_core": "ranged", "owned": {"core.ranged": 1, "BR01": 1}, "paid": {"BR01": 200}}
	Global.apply_save(save)
	var ledger := Global.ascension_ledger()
	_check(ledger.tree_version() == "v4", "an old ascension state defaults to the untouched v4 control")
	_check(ledger.owns("BR01") and ledger.state["paid"]["BR01"] == 200, "old ownership and payments survive the repair")
	_check(ledger.state.has("paid_ranks") and ledger.state.has("history"), "missing V5-era keys are filled in")
	var equipped: Dictionary = ledger.state["equipped"]
	_check(equipped.has("reaction") and equipped.has("v2"), "newer equip slots exist on an old state")
	_check(String(ledger.state["reaction_trigger"]) == "catastrophe", "the reaction trigger gets its default")

	# --- Value hygiene across garbage saves.
	save = _old_save(2)
	save.attempt_opening_version = Global.OPENING_SEQUENCE_VERSION
	save.attempt_opening_phase = -5
	save.attempt_segment1_resonance = 7.0
	save.attempt_segment1_layout_version = Global.SEGMENT1_LAYOUT_VERSION
	save.attempt_segment1_milestones = [" synthesis ", "", "   "]
	save.attempt_mod_wardstone_radius_mul = 0.01
	save.attempt_mod_exit_hold_mul = 9.0
	save.mortal_name = "   "
	save.meta_permanent_augment_ids = ["augment_inversion_lens", "augment_inversion_lens", ""]
	Global.apply_save(save)
	_check(Global.attempt_opening_phase == 0, "a negative opening phase clamps to 0")
	_check(is_equal_approx(Global.attempt_segment1_resonance, 1.0), "overfilled resonance clamps to 1")
	_check(Global.attempt_segment1_milestones.size() == 1 and Global.attempt_segment1_milestones[0] == &"synthesis", "milestone ids are trimmed and empties dropped (%s)" % str(Global.attempt_segment1_milestones))
	_check(Global.attempt_wardstone_radius_mul >= 0.25, "attempt modifiers respect their floors (%.2f)" % Global.attempt_wardstone_radius_mul)
	_check(Global.attempt_exit_hold_mul <= 2.0, "attempt modifiers respect their ceilings (%.2f)" % Global.attempt_exit_hold_mul)
	_check(Global.mortal_name == "The Arcanist", "a blank mortal name falls back to the default")
	_check(Global.permanent_augment_ids[0] == &"augment_inversion_lens" and Global.permanent_augment_ids[1] == StringName(), "the duplicate-augment-slot corruption heals, first slot wins")

	# --- Migration -> save -> reload stability: a migrated state written by
	# the CURRENT build and loaded again is identical, and the migrations
	# never re-fire (they are idempotent on current-version saves).
	save = _old_save(1)
	save.attempt_opening_version = 1
	save.attempt_opening_phase = 2
	save.attempt_segment1_layout_version = 2
	save.attempt_segment1_resonance = 0.6
	save.attempt_segment1_milestones = ["synthesis"]
	save.attempt_opening_completed = true
	Global.apply_save(save)
	var migrated := {
		"phase": Global.attempt_opening_phase,
		"opening_version": Global.attempt_opening_version,
		"layout_version": Global.attempt_segment1_layout_version,
		"milestones": Global.attempt_segment1_milestones.duplicate(),
		"resonance": Global.attempt_segment1_resonance,
		"checkpoint": Global.attempt_checkpoint_pos,
	}
	var rewritten := SaveData.new()
	rewritten.slot_index = 97
	Global.write_save(rewritten)
	Global.apply_save(rewritten)
	var reloaded := {
		"phase": Global.attempt_opening_phase,
		"opening_version": Global.attempt_opening_version,
		"layout_version": Global.attempt_segment1_layout_version,
		"milestones": Global.attempt_segment1_milestones.duplicate(),
		"resonance": Global.attempt_segment1_resonance,
		"checkpoint": Global.attempt_checkpoint_pos,
	}
	_check(reloaded == migrated, "migrate -> save -> reload is a fixed point (%s vs %s)" % [str(reloaded), str(migrated)])
	_check(rewritten.attempt_opening_version == Global.OPENING_SEQUENCE_VERSION and rewritten.attempt_segment1_layout_version == Global.SEGMENT1_LAYOUT_VERSION, "the rewritten save carries current versions, so migrations never re-fire")

	# --- A save from a NEWER build loads best-effort instead of refusing.
	save = _old_save(2)
	save.save_version = SaveData.CURRENT_SAVE_VERSION + 5
	Global.apply_save(save)
	_check(Global.attempt_active and Global.attempt_segment == 2, "a newer-build save still loads best-effort")

	# --- The whole matrix ran without touching a save slot.
	_check(SaveManager.current_save == null, "no case registered a current save; disk was never in play")

	print("SaveMigrationMatrixTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
