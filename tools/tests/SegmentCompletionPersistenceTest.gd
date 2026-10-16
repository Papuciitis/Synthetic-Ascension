extends Node

# Losing the window during EscapeRelease or a completion card must not turn
# an escaped segment back into a playable segment. Only presentation waits are
# controlled here; Game's completion method and all save/reward paths are real.

class CompletionGame:
	extends "res://scenes/game.gd"
	signal release_dismissed
	signal card_dismissed
	var show_card := false

	func _enter_tree() -> void:
		pass

	func _ready() -> void:
		pass

	func _play_escape_release() -> void:
		await release_dismissed

	func _present_chapter_close(_segment: int) -> void:
		if show_card:
			await card_dismissed

	func _present_segment1_overlay(_completion: bool) -> void:
		if show_card:
			await card_dismissed

var _passes := 0
var _failures := 0
var _completions: Array[int] = []


func _ready() -> void:
	get_tree().current_scene = null
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _pending(save: SaveData) -> int:
	for property in save.get_property_list():
		if String(property.name) == "attempt_pending_segment_completion":
			return int(save.get("attempt_pending_segment_completion"))
	return -1


func _fresh(segment: int = 6) -> SaveData:
	SaveManager.current_save = null
	var save := SaveData.new()
	SaveManager.current_save = save
	Global.apply_save(save)
	Global.start_new_attempt()
	Global.attempt_segment = segment
	Global.attempt_checkpoint_pos = Vector2(120, 240)
	Global.attempt_deaths_this_segment = 2
	Global.attempt_claimed_loot_ids = PackedInt32Array([11, 22])
	Global.attempt_vendor_segment = segment
	Global.attempt_vendor_seed = 12345
	Global.attempt_augment_levels = {"augment_tesla_aura": 8}
	Global.pending_augment_pick = false
	Global.pending_big_choice = false
	Global.set_followers(1234)
	Global.attempt_ascension["segments_completed"] = segment - 1
	Global.attempt_ascension["evolution_claims"] = 2
	Global.save_current_profile()
	_completions.clear()
	return save


func _game(show_card: bool = false) -> CompletionGame:
	var game := CompletionGame.new()
	game.show_card = show_card
	var player_node := Node2D.new()
	player_node.name = "Player"
	game.add_child(player_node)
	var ui := Node.new()
	ui.name = "UI"
	game.add_child(ui)
	var hud_node := Control.new()
	hud_node.name = "HUD"
	ui.add_child(hud_node)
	add_child(game)
	return game


func _disk() -> SaveData:
	return ResourceLoader.load(SaveManager._slot_path(0), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData


func _recover(save: SaveData) -> void:
	SaveManager.current_save = save
	Global.apply_save(save)


func _test_release_interruption() -> void:
	_fresh()
	var game := _game()
	game.complete_segment(6)
	var disk := _disk()
	_check(disk != null and _pending(disk) == 6, "completion intent is durable before the release awaits")
	_check(Global.attempt_segment == 6 and disk.attempt_segment == 6 and not Global.pending_augment_pick, "release keeps current segment and ungranted rewards")
	_check(_completions.is_empty(), "release has not emitted completion telemetry or story side effects")
	# Match the OS-close flush without terminating the test process.
	var hard_exit := Global.hard_exit_on_quit
	Global.hard_exit_on_quit = false
	Global.call("_notification", NOTIFICATION_WM_CLOSE_REQUEST)
	Global.hard_exit_on_quit = hard_exit
	game.free()
	_recover(_disk())
	disk = _disk()
	_check(Global.attempt_segment == 7 and disk.attempt_segment == 7 and Global.resume_scene_for(disk) == Global.PATH_HUB_WORLD, "closing during release resumes at the next Hub")
	_check(Global.pending_augment_pick and Global.pending_big_choice and Global.attempt_pending_doctrine_stage == &"doctrine", "recovered segment six grants its Binding and Doctrine")
	_check(int(Global.attempt_ascension.get("evolution_claims", -1)) == 3 and int(Global.attempt_ascension.get("segments_completed", -1)) == 6, "recovery grants exactly one Evolution claim to the loaded ledger")
	_check(Global.followers == 1234 and int(Global.attempt_augment_levels.get("augment_tesla_aura", 0)) == 8, "recovery preserves the loaded wallet and build")
	_check(Global.attempt_checkpoint_pos == Vector2.INF and Global.attempt_deaths_this_segment == 0 and Global.attempt_claimed_loot_ids.is_empty() and Global.attempt_vendor_seed == 0, "recovery clears only completed segment checkpoint, loot, death and vendor state")
	_check(_pending(disk) == 0 and _completions == [6], "the reward snapshot clears intent with one completion event")
	var story := disk.meta_story.duplicate(true)
	_recover(disk)
	_check(_completions == [6] and int(Global.attempt_ascension.get("evolution_claims", -1)) == 3 and StoryDirector.state_for_save() == story, "loading the settled save repeats no reward, story or completion event")


func _test_card_interruption(segment: int) -> void:
	_fresh(segment)
	var game := _game(true)
	game.complete_segment(segment)
	game.release_dismissed.emit()
	var disk := _disk()
	_check(_pending(disk) == segment and Global.attempt_segment == segment, "segment %d completion card retains durable intent and current segment" % segment)
	game.free()
	_recover(disk)
	_check(Global.attempt_segment == segment + 1 and Global.resume_scene_for(_disk()) == Global.PATH_HUB_WORLD and _completions == [segment], "closing segment %d's card recovers once to Hub" % segment)


func _test_invalid_and_reset() -> void:
	var save := _fresh()
	if _pending(save) < 0:
		_check(false, "save schema supports pending completion validation and reset")
		return
	for marker in [-1, 5, 7]:
		save = _fresh()
		save.set("attempt_pending_segment_completion", marker)
		_recover(save)
		_check(Global.attempt_segment == 6 and _pending(_disk()) == 0 and _completions.is_empty(), "invalid or stale marker %d cannot grant completion" % marker)
	save = _fresh()
	save.attempt_active = false
	save.set("attempt_pending_segment_completion", 6)
	_recover(save)
	_check(not Global.attempt_active and _pending(_disk()) == 0 and _completions.is_empty(), "inactive attempt cannot recover a completion")
	_fresh()
	var game := _game()
	game.complete_segment(6)
	game.free()
	Global.start_new_attempt()
	_check(Global.attempt_segment == 1 and _pending(_disk()) == 0 and _completions.is_empty(), "new attempt clears interrupted completion intent")
	_fresh()
	game = _game()
	game.complete_segment(6)
	game.free()
	Global.on_attempt_failed_die_die()
	_check(not Global.attempt_active and _pending(_disk()) == 0 and _completions.is_empty(), "attempt failure clears interrupted completion intent")


func _test_terminal_priority() -> void:
	_fresh()
	var game := _game()
	game.complete_segment(6)
	Global.set_followers(0)
	Global.begin_peep_continuation()
	var disk := _disk()
	_check(Global.has_pending_peep() and _pending(disk) == 0, "terminal continuation clears pending completion before its save")
	game.release_dismissed.emit()
	_check(Global.attempt_segment == 6 and _completions.is_empty(), "a suspended completion cannot settle after terminal continuation begins")
	game.free()
	# Also handle a contradictory snapshot from another build or interrupted migration.
	if _pending(disk) >= 0:
		disk.set("attempt_pending_segment_completion", 6)
	_recover(disk)
	_check(Global.has_pending_peep() and Global.attempt_segment == 6 and Global.resume_scene_for(_disk()) == Global.PATH_PEEP and _completions.is_empty(), "terminal continuation wins over a conflicting completion marker")
	Global.accept_peep_continuation()
	_check(Global.attempt_segment == 1 and _pending(_disk()) == 0 and _completions.is_empty(), "accepted continuation starts without the old completion")


func _test_remembered_commitment() -> void:
	_fresh(3)
	Global.meta_city_commitments = {"method": "doctrine_method_open_circuit"}
	Global.save_current_profile()
	var game := _game()
	game.complete_segment(3)
	game.free()
	_check(Global.attempt_stat_delta == null and Global.attempt_doctrine_stage_ids.is_empty(), "remembered Method grants no effects before the interrupted milestone settles")
	# Recovery must consume the commitment from the save, not leftover live state.
	Global.meta_city_commitments = {"method": "removed_definition"}
	_recover(_disk())
	_check(Global.attempt_segment == 4 and not Global.pending_big_choice and Global.attempt_doctrine_stage_ids.get(&"method") == &"doctrine_method_open_circuit", "recovered segment three reactivates its loaded remembered Method")
	_check(Global.attempt_stat_delta != null and is_equal_approx(Global.attempt_stat_delta.haste, 0.2) and int(Global.get_doctrine_rule(&"binding_extra_cards", 0)) == 1 and Global.attempt_major_choice_taken_ids.size() == 1, "recovery applies Open Circuit's haste and extra Binding card once")
	_recover(_disk())
	_recover(_disk())
	_check(_completions == [3] and Global.attempt_stat_delta != null and is_equal_approx(Global.attempt_stat_delta.haste, 0.2) and int(Global.get_doctrine_rule(&"binding_extra_cards", 0)) == 1 and Global.attempt_major_choice_taken_ids.size() == 1, "reloading recovered commitment repeats neither effects nor completion")


func _test_unselected_recovery() -> void:
	var selected := _fresh(2)
	var selected_seed := selected.attempt_world_seed
	var selected_story := selected.meta_story.duplicate(true)
	var selected_bytes := FileAccess.get_file_as_bytes(SaveManager._slot_path(0))
	var unselected := _disk()
	unselected.slot_index = 42
	unselected.profile_name = "Unselected pending attempt"
	unselected.attempt_segment = 6
	unselected.attempt_pending_segment_completion = 6
	unselected.attempt_followers = 876
	unselected.attempt_world_seed = 654321
	unselected.attempt_ascension["segments_completed"] = 5
	var writes := SaveManager.debug_save_writes
	Global.apply_save(unselected)
	_check(unselected.attempt_segment == 7 and unselected.attempt_pending_segment_completion == 0 and unselected.attempt_resume_scene == Global.PATH_HUB_WORLD and unselected.attempt_followers == 876, "unselected pending resource receives its settled Hub snapshot")
	_check(unselected.attempt_pending_augment_pick and unselected.attempt_pending_big_choice and int(unselected.attempt_ascension.get("evolution_claims", -1)) == 3 and _completions == [6], "unselected recovery applies its own rewards exactly once")
	_check(SaveManager.current_save == selected and selected.attempt_segment == 2 and selected.attempt_followers == 1234 and selected.attempt_world_seed == selected_seed and selected.attempt_resume_scene == Global.PATH_GAME and selected.attempt_pending_segment_completion == 0 and selected.meta_story == selected_story and int(selected.attempt_ascension.get("evolution_claims", -1)) == 2, "unselected recovery leaves selected save resource unchanged")
	_check(SaveManager.debug_save_writes == writes and FileAccess.get_file_as_bytes(SaveManager._slot_path(0)) == selected_bytes and not FileAccess.file_exists(SaveManager._slot_path(42)), "unselected recovery writes neither selected slot nor an unselected slot")


func _test_zero_marker_loads() -> void:
	for version in [0, SaveData.CURRENT_SAVE_VERSION]:
		var save := _fresh()
		save.save_version = version
		SaveManager.save_slot(save)
		var before := FileAccess.get_file_as_bytes(SaveManager._slot_path(0))
		var writes := SaveManager.debug_save_writes
		_recover(_disk())
		_check(Global.attempt_segment == 6 and _pending(SaveManager.current_save) == 0 and not Global.pending_augment_pick and not Global.pending_big_choice and int(Global.attempt_ascension.get("evolution_claims", -1)) == 2 and _completions.is_empty(), "zero-marker save version %d loads without completion or rewards" % version)
		_check(SaveManager.debug_save_writes == writes and FileAccess.get_file_as_bytes(SaveManager._slot_path(0)) == before, "zero-marker save version %d introduces no recovery write" % version)


func _test_normal_completion() -> void:
	_fresh()
	var game := _game(true)
	game.complete_segment(6)
	game.complete_segment(6)
	game.release_dismissed.emit()
	game.card_dismissed.emit()
	var disk := _disk()
	_check(disk.attempt_segment == 7 and _pending(disk) == 0 and disk.attempt_resume_scene == Global.PATH_HUB_WORLD, "normal presentation settles and saves Hub with no pending intent")
	_check(_completions == [6] and int(disk.attempt_ascension.get("evolution_claims", -1)) == 3, "duplicate Game callback cannot duplicate completion or its Evolution claim")
	game.free()


func _run() -> void:
	SaveManager.save_dir = "user://segment_completion_test_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	StoryDirector.cards_override = 0
	Global.balance_segment_completed.connect(func(segment: int) -> void: _completions.append(segment))
	_test_release_interruption()
	_test_card_interruption(1)
	_test_card_interruption(10)
	_test_invalid_and_reset()
	_test_terminal_priority()
	_test_remembered_commitment()
	_test_unselected_recovery()
	_test_zero_marker_loads()
	_test_normal_completion()
	SaveManager.current_save = null
	print("SegmentCompletionPersistenceTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
