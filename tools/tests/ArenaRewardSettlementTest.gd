extends Node

const BOSS := preload("res://scenes/world/events/BossArena.tscn")
const MINI := preload("res://scenes/world/events/MiniBossArena.tscn")
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
class ProgressBuilder:
	extends SegmentProcBuilder
	func _ready() -> void:
		_segment = Global.attempt_segment
		if has_method("restore_attempt_progress"):
			call("restore_attempt_progress")
		add_to_group(&"segment_proc_builder")
		set_process(false)

var passed := 0
var failed := 0
var world: Node2D
var player: Node2D

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func fixture() -> void:
	world = Node2D.new()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	player = Node2D.new()
	player.add_to_group(&"player")
	world.add_child(player)
	player.position = Vector2(2000, 2000)

func clear_world() -> void:
	get_tree().current_scene = self
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func pickups() -> Array:
	return get_tree().get_nodes_in_group(GroundLootCap.ITEM_GROUP).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())

func identity(item: ItemInstance) -> Array:
	return [item.data.id, item.rarity, item.polarity, item.best_pct, item.progress, item.upgrade_meter, item.manifestation_id, item.locked, item.rolled_mods.stack_key() if item.rolled_mods != null else ""]

func same_identity(expected: Array, actual: Array) -> bool:
	# Text resources round a float by one ULP (diagnostic: 0.09883309036180533
	# became 0.09883309036180532). All discrete identity fields remain exact.
	if expected.size() != actual.size():
		return false
	for index in range(expected.size()):
		if expected[index] is float and actual[index] is float:
			if absf(float(expected[index]) - float(actual[index])) > 0.00000000000001:
				return false
		elif expected[index] != actual[index]:
			return false
	return true

func reload_profile() -> void:
	Global.save_current_profile()
	var saved := SaveManager.load_slot(0)
	check(saved != null, "disk snapshot reloads")
	SaveManager.current_save = saved
	Global.apply_save(saved)

func _run() -> void:
	print("ISOLATED_USER_DIR: ", OS.get_user_data_dir())
	SaveManager.save_dir = "user://tests/arena_rewards/"
	SaveManager.current_slot = 0
	SaveManager.current_save = SaveManager.create_slot(0, "Arena reward regression")
	Global.debug_disable_autosave = true
	await test_live_restart()
	for tier in [0, 1]:
		for tank in [true, false]:
			await test_defeat(tier, tank)
	if Global.has_method("arena_reward_pending"):
		await test_recovery_and_claims()
		await test_rite_and_terminal()
	else:
		check(false, "durable pending reward claim API exists")
	await test_segment_progress()
	await test_progress_restore_scope()
	await test_progress_sources()
	await test_post_clear_quality()
	Global.meta_pending_peep.clear()
	Global.start_new_attempt()
	print("ArenaRewardSettlementTest: %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func test_defeat(tier: int, tank: bool) -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 5 if tier == 0 else 10
	Global.run_luck = -1000.0
	Global._rng.seed = 811 + tier
	ThreatDirector.resonance = 0.0
	fixture()
	var arena: Node = (MINI if tier == 0 else BOSS).instantiate()
	arena.set("tank_boss_scenes", [TANK] as Array[PackedScene] if tank else [] as Array[PackedScene])
	arena.set("mage_boss_scenes", [] as Array[PackedScene] if tank else [MAGE] as Array[PackedScene])
	world.add_child(arena)
	arena.call("_spawn")
	var enemy := arena.get("_enemy" if tier == 0 else "_boss") as EnemyActor
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.get_node("BossBrain").set_physics_process(false)
	var handle := EnemyWorld.handle_for_actor(enemy)
	EnemyWorld.set_health(handle, 1.0)
	var partial_writes: Array[bool] = []
	var force_save := func(_old: int, _change: int, _new: int, reason: StringName, _context: Dictionary, _feedback: bool, _aggregate: bool) -> void:
		if reason not in [&"boss_victory", &"miniboss_victory", &"combat_influence"]:
			return
		var before := SaveManager.debug_save_writes
		Global.save_current_profile()
		partial_writes.append(SaveManager.debug_save_writes != before)
	Global.followers_transaction.connect(force_save)
	EnemyCombat.apply_damage(handle, 50.0, 1, player)
	Global.followers_transaction.disconnect(force_save)
	check(partial_writes.size() == 2 and not partial_writes.has(true), "wallet listeners cannot save a partially settled encounter")
	if Global.has_method("settle_arena_rewards"):
		var wallet_before := Global.followers
		var random_before := Global._rng.state
		var repeated: bool = Global.call("settle_arena_rewards", enemy, &"miniboss" if tier == 0 else &"boss", 8 if tier == 0 else 25, 0.18 if tier == 0 else 1.0)
		check(not repeated and Global.followers == wallet_before and Global._rng.state == random_before, "a repeated death callback neither pays nor rerolls the settlement")
	# Settlement must be durable BEFORE any frame/deferred pickup can run.
	var disk := SaveManager.load_slot(0)
	var kind := &"miniboss" if tier == 0 else &"boss"
	check(disk != null and disk.attempt_cleared_arenas.has("%d:%s" % [Global.attempt_segment, kind]), "real death synchronously saves its clear before the release")
	check(disk != null and disk.attempt_followers == Global.followers, "real death saves the complete victory and ordinary kill wallet together")
	await get_tree().process_frame
	await get_tree().process_frame
	var drops := pickups()
	var floor_count := 2 if tier == 0 else 5
	check(drops.size() >= floor_count, "S%d %s grants at least %d items at minimum Luck/Resonance (got %d)" % [Global.attempt_segment, "tank" if tank else "mage", floor_count, drops.size()])
	for drop in drops:
		check(drop.item_instance != null and drop.item_instance.rarity >= (3 if tier == 0 else 7), "guaranteed items retain the existing rarity floor")
	var records: Variant = Global.get("attempt_arena_rewards")
	check(records is Dictionary and records.size() == 1, "defeat stores one encounter settlement with full rolled identities")
	await clear_world()

func test_recovery_and_claims() -> void:
	# The last real S10 kill above left an actual saved settlement.
	var wallet := Global.followers
	var records: Dictionary = Global.get("attempt_arena_rewards")
	var key: String = records.keys()[0]
	var stored: ItemInstance = records[key]["items"][0]
	var expected := identity(stored)
	reload_profile()
	fixture()
	Global.call("restore_pending_arena_rewards")
	Global.call("restore_pending_arena_rewards")
	var drops := pickups()
	check(drops.size() == records[key]["items"].size(), "Continue restores all pending drops once even on repeated recovery")
	var drop: ItemPickup = drops[0]
	check(same_identity(expected, identity(drop.item_instance)), "disk roundtrip preserves the full item roll and manifestation")
	# Fill every slot with locked items, preventing equip/feed/consolidation.
	for i in range(Inventory.SLOT_COUNT):
		for data: ItemData in Global.item_db.values():
			if data.equip_slot == i:
				var full := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.1, false)
				full.locked = true
				Global.run_inventory.set_item(i, full)
				break
	for i in range(Global.run_bag.get_slot_count()):
		var full := stored.snapshot_copy()
		full.locked = true
		Global.run_bag.slots[i] = full
	Global.run_bag._rebuild_index()
	drop.call("_collect")
	check(not drop.is_queued_for_deletion() and bool(Global.call("arena_reward_pending", key, 0)), "full inventory keeps the same reward pending and on the ground")
	reload_profile()
	await clear_world()
	fixture()
	Global.call("restore_pending_arena_rewards")
	drop = pickups()[0]
	check(same_identity(expected, identity(drop.item_instance)), "full bag Continue never rerolls the item")
	Global.run_bag.slots[0] = null
	Global.run_bag._rebuild_index()
	var claim_writes: Array[bool] = []
	var save_on_insert := func() -> void:
		var before := SaveManager.debug_save_writes
		Global.save_current_profile()
		claim_writes.append(SaveManager.debug_save_writes != before)
	Global.run_bag.changed.connect(save_on_insert)
	drop.call("_collect")
	Global.run_bag.changed.disconnect(save_on_insert)
	check(not claim_writes.is_empty() and not claim_writes.has(true), "inventory listeners cannot save the insertion before its claim marker")
	check(not bool(Global.call("arena_reward_pending", key, 0)) and drop.is_queued_for_deletion(), "successful pickup claims exactly that saved reward")
	check(same_identity(expected, identity(Global.run_bag.slots[0])), "claim adds exactly the stored item to the newly free slot")
	var claimed_snapshot := SaveManager.load_slot(0)
	check(claimed_snapshot.attempt_bag.slots[0] != null, "claim persists inventory synchronously with its claim marker")
	drop.call("_collect")
	check(Global.run_bag.slots[0].progress == stored.progress, "a repeated pickup callback cannot feed a duplicate")
	await clear_world()
	reload_profile()
	fixture()
	Global.call("restore_pending_arena_rewards")
	check(pickups().size() == records[key]["items"].size() - 1 and Global.followers == wallet, "Continue after claiming restores only unclaimed items and never pays wallet again")
	await clear_world()

func test_rite_and_terminal() -> void:
	var records: Dictionary = Global.get("attempt_arena_rewards")
	var key: String = records.keys()[0]
	var wallet := Global.followers
	check(Global.begin_segment_completion(10), "Rite completion accepts the defeated boss segment")
	# Reload the durable intent before its presentation finishes.
	reload_profile()
	check(Global.attempt_segment == 11 and Global.followers == wallet, "completed Rite recovery advances once without a second boss payout")
	fixture()
	Global.call("restore_pending_arena_rewards")
	check(pickups().size() == records[key]["items"].size() - 1, "unclaimed boss items remain recoverable after the Rite/segment handoff")
	await clear_world()
	Global.set_followers(0)
	Global.begin_peep_continuation()
	reload_profile()
	fixture()
	Global.call("restore_pending_arena_rewards")
	check(pickups().is_empty() and not bool(Global.call("arena_reward_pending", key, 1)), "terminal defeat takes precedence over pending reward recovery and claims")
	await clear_world()
	Global.meta_pending_peep.clear()
	Global.start_new_attempt()
	check((Global.get("attempt_arena_rewards") as Dictionary).is_empty(), "a new attempt clears the previous attempt's reward identities")

func test_segment_progress() -> void:
	Global.meta_pending_peep.clear()
	Global.start_new_attempt()
	Global.attempt_segment = 5
	fixture()
	var builder := ProgressBuilder.new()
	world.add_child(builder)
	builder.call("_on_primary_completed")
	builder.grant_resonance(0.25)
	Global.save_current_profile()
	var disk := SaveManager.load_slot(0)
	var progress: Variant = disk.get("attempt_segment_progress")
	check(progress is Dictionary and bool(progress.get("primary_completed", false)) and is_equal_approx(float(progress.get("resonance", 0.0)), 0.43), "save carries completed primary and actual Resonance before the Rite")
	await clear_world()
	Global.apply_save(disk)
	fixture()
	builder = ProgressBuilder.new()
	world.add_child(builder)
	if builder.has_method("restore_attempt_progress"):
		builder.call("restore_attempt_progress")
	check(bool(builder.get("_primary_completed")) and is_equal_approx(builder.resonance, 0.43), "Continue restores the primary without paying its Resonance twice")
	builder.call("_on_primary_completed")
	check(is_equal_approx(builder.resonance, 0.43), "a repeated primary completion cannot mint another reward")
	Global.reset_segment_pass()
	var fresh := SaveData.new()
	Global.write_save(fresh)
	var reset_progress: Variant = Global.get("attempt_segment_progress")
	check(reset_progress is Dictionary and reset_progress.is_empty(), "developer fresh-pass reset discards old primary/Resonance progress")
	await clear_world()

func test_live_restart() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 10
	fixture()
	var arena := BOSS.instantiate() as BossArena
	world.add_child(arena)
	Global.save_current_profile()
	var before_activation := SaveManager.load_slot(0)
	check(before_activation.attempt_cleared_arenas.is_empty(), "saving before activation does not settle a boss")
	arena.call("_spawn")
	var enemy := arena.get("_boss") as EnemyActor
	enemy.set_physics_process(false)
	enemy.get_node("BossBrain").set_physics_process(false)
	EnemyWorld.set_health(EnemyWorld.handle_for_actor(enemy), enemy.max_hp * 0.5)
	Global.save_current_profile()
	var midfight := SaveManager.load_slot(0)
	var wallet := Global.followers
	await clear_world()
	Global.apply_save(midfight)
	fixture()
	arena = BOSS.instantiate() as BossArena
	world.add_child(arena)
	arena.call("_spawn")
	enemy = arena.get("_boss") as EnemyActor
	check(enemy != null and is_equal_approx(enemy.hp, enemy.max_hp) and not Global.is_arena_cleared(&"boss") and Global.followers == wallet, "Continue during a live fight restarts a healthy boss without paying rewards")
	await clear_world()

func test_progress_restore_scope() -> void:
	for invalid_field in ["seed", "segment", "valid"]:
		Global.start_new_attempt()
		Global.attempt_segment = 5
		Global.note_arena_cleared(&"miniboss")
		Global.set("attempt_segment_progress", {
			"seed": Global.attempt_world_seed + (1 if invalid_field == "seed" else 0),
			"segment": 7 if invalid_field == "segment" else 5,
			"primary_completed": true, "resonance": 0.43,
		})
		fixture()
		var builder := ProgressBuilder.new()
		world.add_child(builder)
		world.add_child(MINI.instantiate())
		await get_tree().process_frame
		check(is_equal_approx(builder.resonance, 0.43 if invalid_field == "valid" else 0.18), "cleared S5 restores earned Resonance once with %s progress snapshot" % invalid_field)
		var restored := builder.resonance
		world.add_child(MINI.instantiate())
		await get_tree().process_frame
		check(is_equal_approx(builder.resonance, restored), "a repeated cleared arena restoration never multiplies Resonance")
		await clear_world()

func test_progress_sources() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 5
	fixture()
	var builder := ProgressBuilder.new()
	world.add_child(builder)
	Global.save_current_profile()
	Global.debug_disable_autosave = false
	builder.call("_on_wardstone_activated", null, 0)
	check(bool(Global.get("_autosave_dirty")), "new Resonance marks the profile dirty for the scene/quit save boundary")
	Global.debug_disable_autosave = true
	builder.call("_on_secondary_objective_completed", 88)
	check(is_equal_approx(builder.resonance, 0.11), "unique wardstone and secondary each pay their authored Resonance")
	Global.save_current_profile()
	var disk := SaveManager.load_slot(0)
	await clear_world()
	Global.apply_save(disk)
	fixture()
	builder = ProgressBuilder.new()
	world.add_child(builder)
	var rite := preload("res://scenes/world/gates/ExitRite.tscn").instantiate() as ExitRite
	world.add_child(rite)
	builder.set("_exit_rite", rite)
	builder.call("_replay_rite_safeguard_sources")
	check(rite.safeguard_count() == 2, "Continue carries the two earned safeguard sources to the rebuilt Rite")
	builder.set("_plan", {"wardstone_world": [Vector2(300, 300)]})
	builder.call("_spawn_wardstones")
	check(get_tree().get_nodes_in_group(&"wardstones_active").size() == 1, "Continue restores the earned wardstone sanctuary without another activation")
	builder.call("_on_wardstone_activated", null, 0)
	check(is_equal_approx(builder.resonance, 0.11), "Continue cannot farm an already rewarded wardstone's Resonance")
	builder.call("_on_secondary_objective_completed", 88)
	check(is_equal_approx(builder.resonance, 0.11), "Continue cannot farm an already completed secondary's rewards")
	await clear_world()

func test_post_clear_quality() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 10
	ThreatDirector.begin_segment()
	fixture()
	var builder := ProgressBuilder.new()
	world.add_child(builder)
	builder.set("_boss_required", true)
	builder.call("_on_primary_completed")
	check(ThreatDirector.resonance < 0.99, "quality fixture starts before the S10 fill")
	var contexts: Array[Dictionary] = []
	var on_generated := func(_item: ItemInstance, source: StringName, context: Dictionary) -> void:
		if source == &"boss":
			contexts.append(context.duplicate(true))
	RunEvents.item_generated.connect(on_generated)
	var arena := BOSS.instantiate() as BossArena
	world.add_child(arena)
	arena.call("_spawn")
	var enemy := arena.get("_boss") as EnemyActor
	var handle := EnemyWorld.handle_for_actor(enemy)
	EnemyWorld.set_health(handle, 1.0)
	EnemyCombat.apply_damage(handle, 50.0, 1, player)
	RunEvents.item_generated.disconnect(on_generated)
	check(ThreatDirector.resonance >= 0.999 and contexts.size() >= 5, "the real clear fills Resonance and generates the guaranteed payout")
	var quality_matches := true
	for context in contexts:
		quality_matches = quality_matches and int(context["rarity_min"]) == 7 + ThreatDirector.loot_rarity_bonus
	check(quality_matches, "stored boss rolls keep the original post-clear Resonance/rarity quality context")
	await clear_world()