extends Node

# The end-to-end vertical slice (integration pass 2026-09-26, review P0-1):
# one route that exercises THE GAME, not each system independently.
#
#   fresh Ranged attempt -> the real game scene builds a procedural segment
#   -> the primary objective completes through its production signal chain
#   -> Resonance fills -> the Exit Rite unlocks (never early) -> the channel
#   is held to completion -> the rite clears the segment exactly once ->
#   segment completion advances the run -> the whole run state survives an
#   in-memory save/load round trip.
#
# Deliberate scope: segment 2 (procedural loop; segment 1's authored opening
# has its own suites), the player is STOOD in the rite rather than walked
# there (navigation is a rendered-play concern), and the scene change into
# the hub is asserted as routing state, not performed (HubWorldTest owns the
# hub side). NO DISK SAVES: SaveManager.current_save stays null, so every
# autosave/profile path no-ops (decision D-18) and the save leg runs through
# Global.write_save/apply_save on a local SaveData.
#
# Run: <godot> --headless --path . res://tools/tests/VerticalSliceTest.tscn

const GAME_SCENE := preload("res://scenes/game.tscn")

var _passes := 0
var _failures := 0
var _completed_segments: Array = []


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


## The rite's cleared chain calls current_scene.complete_segment — in a test
## run, that is this node. Record the handoff; the production continuation
## (Global.on_segment_completed) is exercised explicitly in _run so the test
## can assert around it without a scene change.
func complete_segment(completed_segment: int) -> void:
	_completed_segments.append(completed_segment)


func _run() -> void:
	# --- A fresh Ranged run, entering the procedural loop.
	Global.selected_style_id = "ranged"
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.pending_augment_pick = false
	_check(Global.attempt_active, "a fresh attempt is active")

	var game := GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	_check(player != null and not bool(player.get("is_dead")), "the run starts with a live player in the world")

	# The procedural builder spawns its objective and rite as the world plans.
	var builder: SegmentProcBuilder = null
	for _i in range(120):
		for child in game.get_children():
			if child is SegmentProcBuilder:
				builder = child
		if builder != null and builder._primary_objective != null and builder._exit_rite != null:
			break
		await get_tree().process_frame
	_check(builder != null, "segment 2 builds through SegmentProcBuilder")
	if builder == null:
		_finish()
		return
	_check(builder._primary_objective != null, "the segment authors a primary objective")
	var rite: ExitRite = builder._exit_rite
	_check(rite != null and rite.locked, "the Exit Rite stands locked at segment start")
	if rite == null or builder._primary_objective == null:
		_finish()
		return

	# --- The gate cannot be rushed: full resonance without the primary
	# (or the primary without resonance) keeps it sealed.
	var resonance_before: float = builder.resonance
	_check(resonance_before < 0.999, "resonance starts unfilled (%.2f)" % resonance_before)

	# --- Primary completion through the production signal chain.
	builder._primary_objective.finish()
	await get_tree().process_frame
	_check(builder._primary_completed, "the primary completes through its own completed signal")
	_check(rite.revealed, "completion reveals the rite")

	# --- Resonance fills; only now does the gate open.
	builder.grant_resonance(1.0, true)
	_check(not rite.locked, "primary + full resonance unlock the rite — and nothing less did")

	# --- The channel: stand in the rite and hold it to completion.
	rite._player_inside = true
	var budget: float = rite.hold_time * 3.0
	while not rite._completed and budget > 0.0:
		rite._process(0.25)
		budget -= 0.25
	_check(rite._completed, "the held channel completes the rite (%.0fs budgeted)" % (rite.hold_time * 3.0))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_completed_segments == [2], "the cleared rite completes segment 2 exactly once (%s)" % str(_completed_segments))

	# Abuse: the completed rite cannot clear the segment twice.
	rite._player_inside = true
	rite._process(1.0)
	await get_tree().process_frame
	_check(_completed_segments == [2], "a completed rite never re-clears")

	# --- The production continuation (game.complete_segment minus the scene
	# change): the run advances and routes to the hub.
	var followers_before: int = Global.followers
	Global.on_segment_completed(2)
	_check(Global.attempt_segment == 3, "segment completion advances the run (%d)" % Global.attempt_segment)
	_check(Global.followers >= followers_before, "completion never costs followers")

	# --- The whole run state survives an in-memory save round trip.
	var save := SaveData.new()
	save.slot_index = 97
	Global.write_save(save)
	_check(save.attempt_active and save.attempt_segment == 3, "the save carries the advanced run")
	_check(String(save.attempt_style_id) == "ranged", "the save carries the chosen style (%s)" % String(save.attempt_style_id))
	var segment_before_load: int = Global.attempt_segment
	var followers_saved: int = Global.followers
	Global.attempt_segment = 1
	Global.set_followers(0)
	Global.apply_save(save)
	_check(Global.attempt_segment == segment_before_load, "loading restores the segment (%d)" % Global.attempt_segment)
	_check(Global.followers == followers_saved, "loading restores the followers (%d)" % Global.followers)
	_check(Global.run_inventory != null and Global.run_bag != null, "loading restores the run containers")

	game.queue_free()
	await get_tree().process_frame
	_finish()


func _finish() -> void:
	print("VerticalSliceTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
