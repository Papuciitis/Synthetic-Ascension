extends Node

# Behavioral contract: removing pending persistence revives a dead city; replaying
# a saved commitment twice duplicates its benefits. All saves are throwaway.
# Keep boot unrelated to the boundary out of the fixture. These inherited
# methods remain the production Game presentation/end_run implementation.
class DeathGame:
	extends "res://scenes/game.gd"
	func _ready() -> void:
		_tutorial_modals = TUTORIAL_MODAL_CONTROLLER.new()
		add_child(_tutorial_modals)

class WorldStepWitness:
	extends Node2D
	var frames := 0
	var physics_frames := 0
	var scheduled_steps := 0
	func _process(_delta: float) -> void:
		frames += 1
	func _physics_process(_delta: float) -> void:
		physics_frames += 1
	func simulation_tier() -> int:
		return 1
	func run_scheduled_simulation(_delta: float) -> void:
		scheduled_steps += 1

var _passes := 0
var _failures := 0
var _boundaries: Array[StringName] = []
var _routes: Array[String] = []

func _ready() -> void:
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	# Keep this driver alive across the real scene transitions below.
	get_tree().current_scene = null
	SaveManager.current_save = null
	SaveManager.save_dir = "user://city_continuity_test_%d/" % Time.get_ticks_usec()
	Global.debug_disable_autosave = true
	_check(Global.has_method("begin_peep_continuation"), "terminal defeat has a durable pending continuation API")
	if not Global.has_method("begin_peep_continuation"):
		_finish()
		return
	Global.balance_attempt_boundary.connect(func(reason: StringName) -> void: _boundaries.append(reason))
	_test_pending()
	_test_commitments()
	_test_legacy()
	await _test_real_reconstruction()
	await _test_real_terminal_death()
	await _test_routes()
	await _test_scheduled_route()
	_finish()

func _fresh() -> SaveData:
	var save := SaveData.new()
	SaveManager.current_save = save
	Global.apply_save(save)
	Global.start_new_attempt()
	return save

func _test_pending() -> void:
	var save := _fresh()
	_check(not bool(Global.call("has_pending_peep")), "old empty-default profile has no pending choice")
	Global.mortal_name = "Test Arcanist"
	Global.attempt_segment = 7
	Global.attempt_world_seed = 123456
	Global.attempt_congregation = 42
	Global.attempt_augment_levels = {"augment_tesla_aura": 8}
	Global.owned_augment_ids = [&"augment_tesla_aura"]
	Global.permanent_augment_ids = [&"augment_tesla_aura", &"", &""]
	Global.grimoire_entries = ["thesis:circuit"]
	Global.opening_full_intro_seen = true
	var stored := ItemInstance.from_roll(load("res://data/items/defs/accessories/acc_firestone.tres") as ItemData, 24, 1, 0.6, false)
	Global.meta_stash.slots[0] = stored
	Global.run_bag.slots[0] = stored.snapshot_copy()
	Global.set_followers(100)
	StoryDirector.note_reconstruction()
	_check(not bool(Global.call("has_pending_peep")), "ordinary reconstruction retains the attempt without PeeP")
	Global.call("begin_peep_continuation")
	_check(not bool(Global.call("has_pending_peep")), "nonterminal Followers cannot create a PeeP decision")
	Global.set_followers(0)
	var accounts := int(StoryDirector.state_for_save().get("accounts", 0))
	var runs := save.total_runs
	_boundaries.clear()
	Global.call("begin_peep_continuation")
	Global.call("begin_peep_continuation")
	var summary: Dictionary = Global.call("pending_peep_summary")
	_check(summary.get("name") == "Test Arcanist" and summary.get("segment") == 7 and summary.get("attempt_seed") == 123456, "pending summary captures this failed name, segment and seed")
	summary["name"] = "Changed outside"
	_check((Global.call("pending_peep_summary") as Dictionary).get("name") == "Test Arcanist", "presentation cannot mutate the frozen outcome")
	_check(Global.attempt_segment == 7 and Global.attempt_augment_levels.get("augment_tesla_aura") == 8 and Global.attempt_active, "failed attempt remains intact until acceptance")
	_check(_boundaries.count(&"failed") == 0 and int(StoryDirector.state_for_save().get("accounts", 0)) == accounts, "pending does not prematurely close the story account")
	_check(Global.resume_scene_for(save) == "res://ui/screens/PeePContinuation.tscn", "saved gameplay target resolves to PeeP while pending")
	Global.start_new_attempt()
	_check(save.total_runs == runs and Global.attempt_segment == 7, "fresh-attempt API cannot bypass a pending decision")
	Global.on_attempt_failed_die_die()
	_check(Global.attempt_segment == 7 and _boundaries.count(&"failed") == 0, "legacy reset caller cannot erase an unresolved decision")
	var disk := ResourceLoader.load(SaveManager._slot_path(0), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	_check(disk != null and not (disk.get("meta_pending_peep") as Dictionary).is_empty(), "terminal transition writes pending before any reset")
	if disk != null:
		Global.apply_save(disk)
		SaveManager.current_save = disk
		_check(bool(Global.call("has_pending_peep")) and Global.attempt_segment == 7, "reload retains pending and failed snapshot")
	_check(bool(Global.call("accept_peep_continuation")), "continuation accepts once")
	var seed := Global.attempt_world_seed
	_check(not bool(Global.call("accept_peep_continuation")), "repeated continuation does nothing")
	_check(not bool(Global.call("has_pending_peep")) and Global.attempt_segment == 1 and Global.attempt_world_seed == seed, "one fresh attempt replaces the frozen failure")
	_check(SaveManager.current_save.total_runs == runs + 1 and _boundaries.count(&"failed") == 1 and _boundaries.count(&"restarted") == 1, "one acceptance closes and starts exactly one account")
	_check(int(StoryDirector.state_for_save().get("accounts", 0)) == accounts + 1 and StoryDirector.last_account().get("segment") == 7 and StoryDirector.last_account().get("peak") == 42, "story closes once with the failed attempt facts")
	_check(Global.attempt_augment_levels.is_empty(), "acceptance resets active augment levels")
	_check(Global.meta_stash.slots[0] != null and Global.meta_stash.slots[0].rarity == 24, "stash item retains its exact uncapped rank")
	_check(Global.owned_augment_ids.has(&"augment_tesla_aura") and Global.permanent_augment_ids[0] == &"augment_tesla_aura" and Global.grimoire_entries.has("thesis:circuit") and Global.opening_full_intro_seen, "augment library, slot preference, knowledge and opening memory survive")
	_check(Global.followers == 0 and Global.attempt_congregation == 0 and Global.run_bag.slots[0] == null and Global.attempt_checkpoint_pos == Vector2.INF, "Followers, Congregation, carried bag and checkpoint reset")
	var saved := SaveData.new()
	Global.write_save(saved)
	Global.apply_save(saved)
	_check(not bool(Global.call("has_pending_peep")) and not bool(Global.call("accept_peep_continuation")), "reloading accepted continuation cannot resolve it again")

func _choose(stage: int, id: StringName) -> void:
	Global.on_segment_completed(stage)
	Global.attempt_major_choice_offer_ids = [id]
	_check(Global.apply_major_choice(id), "normal application accepts selected stage %d" % stage)

func _test_commitments() -> void:
	_fresh()
	_choose(3, &"doctrine_method_open_circuit")
	_choose(6, &"doctrine_tithe_ledger")
	_choose(9, &"doctrine_apotheosis_perfected_engine")
	var commitments: Dictionary = Global.get("meta_city_commitments")
	_check(commitments.size() == 3, "only the three city stages become profile commitments")
	Global.start_new_attempt()
	_check(Global.attempt_doctrine_stage_ids.is_empty() and Global.attempt_stat_delta == null, "commitments grant no immediate fresh-attempt effects")
	Global.on_segment_completed(2)
	_check(Global.attempt_doctrine_stage_ids.is_empty(), "commitments do not activate before their completed milestone")
	Global.on_segment_completed(3)
	_check(not Global.pending_big_choice and Global.attempt_doctrine_stage_ids.get(&"method") == &"doctrine_method_open_circuit", "Method reactivates automatically only after completed 3")
	_check(is_equal_approx(Global.attempt_stat_delta.haste, 0.2) and int(Global.get_doctrine_rule(&"binding_extra_cards", 0)) == 1, "replay uses the ordinary Method effects once")
	Global.on_segment_completed(3)
	_check(is_equal_approx(Global.attempt_stat_delta.haste, 0.2) and Global.attempt_major_choice_taken_ids.size() == 1, "repeated milestone cannot double commitment effects")
	var save := SaveData.new()
	Global.write_save(save)
	Global.apply_save(save)
	_check(is_equal_approx(Global.attempt_stat_delta.haste, 0.2) and Global.attempt_major_choice_taken_ids.size() == 1, "loading saved active effects never replays a commitment")
	Global.on_segment_completed(6)
	_check(not Global.pending_big_choice and Global.attempt_doctrine_stage_ids.has(&"doctrine"), "Doctrine activates only at completed 6")
	Global.on_segment_completed(9)
	_check(not Global.pending_big_choice and Global.attempt_doctrine_stage_ids.has(&"apotheosis"), "Apotheosis activates only at completed 9")
	Global.on_segment_completed(12)
	var offer := Global.get_major_choice_offer(3)
	_check(Global.pending_big_choice and not offer.is_empty(), "later Apocrypha remains a normal per-attempt choice")
	if not offer.is_empty():
		Global.apply_major_choice((offer[0] as MajorChoiceDef).id)
	_check((Global.get("meta_city_commitments") as Dictionary).size() == 3, "Apocrypha never adds a persistent commitment")
	Global.set("meta_city_commitments", {"method": "removed_definition", "doctrine": "doctrine_method_open_circuit"})
	Global.start_new_attempt()
	Global.on_segment_completed(3)
	_check(Global.pending_big_choice and Global.get_major_choice_offer(3).size() == 3, "removed commitment falls back to a usable normal offer")
	Global.on_segment_completed(6)
	_check(Global.pending_big_choice and Global.get_major_choice_offer(3).size() == 3, "wrong-stage commitment falls back to a usable normal offer")

func _test_legacy() -> void:
	_fresh()
	_choose(3, &"doctrine_method_open_circuit")
	var legacy := SaveData.new()
	Global.write_save(legacy)
	legacy.set("meta_city_commitments", {})
	Global.apply_save(legacy)
	_check((Global.get("meta_city_commitments") as Dictionary).get("method") == "doctrine_method_open_circuit", "empty legacy profile imports its active city choice")
	_check(is_equal_approx(Global.attempt_stat_delta.haste, 0.2), "legacy import preserves active effects without reapplying")
	legacy.set("meta_city_commitments", {"method": "another_profile_choice"})
	Global.apply_save(legacy)
	_check(Global.attempt_doctrine_stage_ids.get(&"method") == &"doctrine_method_open_circuit" and is_equal_approx(Global.attempt_stat_delta.haste, 0.2), "existing profile commitment never overwrites an ongoing active choice")

func _death_game() -> DeathGame:
	var game := DeathGame.new()
	var player := (load("res://core/actors/player/player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	game.add_child(player)
	var ui := Node.new()
	ui.name = "UI"
	game.add_child(ui)
	var hud := Control.new()
	hud.name = "HUD"
	ui.add_child(hud)
	add_child(game)
	return game

func _dismiss_reconstruction_card(game: Node) -> void:
	for child in game.get_children():
		if child is TutorialCardOverlay:
			child.call("_dismiss")

func _test_real_reconstruction() -> void:
	_fresh()
	Global.attempt_segment = 2
	Global.set_followers(100)
	var seed := Global.attempt_world_seed
	var game := _death_game()
	var player := game.get_node("Player")
	player.call("die")
	_check(not bool(Global.call("has_pending_peep")) and Global.followers == 80 and get_tree().paused, "real paid reconstruction keeps its ordinary modal without PeeP")
	_dismiss_reconstruction_card(game)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not bool(player.get("is_dead")) and Global.attempt_world_seed == seed and not get_tree().paused, "real paid reconstruction restores the same attempt after its card")
	game.queue_free()
	await get_tree().process_frame

func _test_real_terminal_death() -> void:
	_fresh()
	Global.attempt_segment = 2
	Global.set_followers(1)
	var game := _death_game()
	var witness := WorldStepWitness.new()
	game.add_child(witness)
	var always_witness := WorldStepWitness.new()
	always_witness.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(always_witness)
	var bucket: Array = [[witness.get_instance_id()]]
	EnemySimulationScheduler.call("_run_next_group", bucket, 0, 0.016, 1, &"mid_steps")
	_check(witness.scheduled_steps == 1, "the real scheduler dispatches the live scene witness before defeat")
	var spawn := EnemySpawnState.new(&"continuity_burn_fixture", "", Vector2.ZERO, 100.0, 0.0, 8.0, 0)
	var handle: int = EnemyWorld.create_enemy(spawn)
	_check(EnemyStatus.apply_burn(handle, 1, 10.0, 0.05, 1.0), "the real status service holds an active burn before defeat")
	var player := game.get_node("Player")
	player.call("die")
	_check(bool(Global.call("has_pending_peep")) and Global.followers == 0, "real terminal death saves pending before any presentation can await input")
	Global.save_current_profile()
	var disk := ResourceLoader.load(SaveManager._slot_path(0), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	_check(disk != null and Global.resume_scene_for(disk) == "res://ui/screens/PeePContinuation.tscn", "quit during the real death boundary saves continuation instead of resumable gameplay")
	if disk != null:
		Global.apply_save(disk)
		SaveManager.current_save = disk
	_check(bool(Global.call("has_pending_peep")) and Global.attempt_segment == 2, "reload before dismissing any old terminal card cannot revive the dead city")
	EnemySimulationScheduler.call("_run_next_group", bucket, 0, 0.016, 1, &"mid_steps")
	_check(witness.scheduled_steps == 1, "root enemy scheduler cannot manually step the disabled failed world")
	EnemyStatus.advance(0.5)
	_check(is_equal_approx(EnemyWorld.get_health(handle), 100.0), "root status service cannot damage enemies or award a post-defeat kill")
	var old_terminal_cards := 0
	for child in game.get_children():
		if child is TutorialCardOverlay:
			old_terminal_cards += 1
	_check(old_terminal_cards == 0, "terminal defeat routes directly to PeeP without a second failure modal")
	# Cleanup the pre-fix modal after observing persistence, so RED can finish.
	_dismiss_reconstruction_card(game)
	var before := witness.frames
	var always_before := always_witness.frames
	var physics_before := witness.physics_frames
	var always_physics_before := always_witness.physics_frames
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(game.process_mode == Node.PROCESS_MODE_DISABLED and witness.frames == before and always_witness.frames == always_before and witness.physics_frames == physics_before and always_witness.physics_frames == always_physics_before, "failed world including ALWAYS descendants stops during asynchronous scene routing")
	EnemyWorld.remove_enemy(handle, &"test_cleanup")
	EnemyStatus.clear_all()
	game.queue_free()
	get_tree().paused = false
	await get_tree().process_frame

func _test_routes() -> void:
	var save := _fresh()
	Global.attempt_segment = 5
	Global.set_followers(0)
	Global.call("begin_peep_continuation")
	var runs := save.total_runs
	Global.balance_scene_requested.connect(func(route: String) -> void: _routes.append(route))
	var expected := "res://ui/screens/PeePContinuation.tscn" if ResourceLoader.exists("res://ui/screens/PeePContinuation.tscn") else Global.PATH_MAIN_MENU
	get_tree().paused = true
	Global.goto_game()
	_check(_routes.back() == expected and not get_tree().paused, "game route presents pending continuation unpaused (or preserves it through menu fallback)")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	Global.goto_resume()
	_check(_routes.back() == expected, "Continue honors the pending decision before saved gameplay")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var base := (load("res://ui/screens/base.gd") as Script).new() as Control
	base.call("_on_start_run_pressed")
	_check(_routes.back() == expected and save.total_runs == runs, "Base start cannot overwrite an unresolved failed attempt")
	base.free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# Minimal scene shell: the production Game entry guard must return before
	# allocating world services, binding a player, or rewriting the resume target.
	var game := (load("res://scenes/game.gd") as Script).new() as Node2D
	var player := Node.new()
	player.name = "Player"
	game.add_child(player)
	var ui := Node.new()
	ui.name = "UI"
	game.add_child(ui)
	var hud := Control.new()
	hud.name = "HUD"
	ui.add_child(hud)
	add_child(game)
	_check(_routes.back() == expected and save.total_runs == runs and Global.attempt_segment == 5, "direct Game entry cannot revive the dead attempt")
	_check(game.process_mode == Node.PROCESS_MODE_DISABLED, "direct pending Game entry disables its world during routing")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	game.call("end_run")
	_check(_routes.back() == expected and not get_tree().paused and bool(Global.call("has_pending_peep")), "terminal end_run with no GameOverUI routes pending without a softlock")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	game.queue_free()
	_check(bool(Global.call("has_pending_peep")) and save.total_runs == runs, "menu and scene changes retain the unresolved pending decision")

func _test_scheduled_route() -> void:
	_fresh()
	Global.pending_augment_pick = false
	Global.goto_hub_shop()
	# The Hub target has been chosen, but its scene switch is still awaiting
	# the loading frames. A lethal boundary must supersede that old target.
	Global.set_followers(0)
	Global.begin_peep_continuation()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var current := get_tree().current_scene
	var expected := "res://ui/screens/PeePContinuation.tscn" if ResourceLoader.exists("res://ui/screens/PeePContinuation.tscn") else Global.PATH_MAIN_MENU
	_check(current != null and current.scene_file_path == expected and Global.has_pending_peep(), "an already scheduled Hub switch rechecks pending at the actual transition")
	get_tree().paused = false

func _finish() -> void:
	SaveManager.current_save = null
	print("CityContinuationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
