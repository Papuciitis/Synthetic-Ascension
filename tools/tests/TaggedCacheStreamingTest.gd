extends Node
## Reproduce the omitted capture's real seed/chunk through production generation.
const SEED := 16102026
const COORD := Vector2i(1, 9)
const ID := 1736497563
var _failures := 0
var _spawn_inventory: Array[Dictionary] = []

func _enter_tree() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/tagged_cache_streaming/"
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	PerformanceFlightRecorder.set_enabled(false)
	BalanceRecorder.set_enabled(false)

func _ready() -> void:
	get_tree().create_timer(12.0).timeout.connect(func() -> void:
		push_error("TaggedCacheStreamingTest incomplete or timed out")
		get_tree().quit(1))
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var writes := SaveManager.debug_save_writes
	Global.apply_save(SaveData.new())
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.attempt_world_seed = SEED
	var plan := DistrictPlan.generate(2, SEED, 2048, SegmentThemePicker.get_theme(2, SEED))
	var plan_seed := int(plan["seed"])
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is ExplorationLootSpawner:
			var manager := get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
			_spawn_inventory.append({"loot_id": node.loot_id, "objective_id": node.secondary_objective_id, "world": str((node as Node2D).global_position), "chunk_registered_at_ready": (manager.get("_chunks") as Dictionary).has(COORD), "walkable_at_ready": manager.is_cell_walkable(manager.world_to_cell((node as Node2D).global_position))})
		if node is ItemPickup:
			node.set_process(false)
			node.collision_mask = 0)
	var cm := ChunkManager.new()
	var player := Node2D.new()
	player.add_to_group(&"player")
	player.position = Vector2(COORD) * 2048.0 + Vector2(1024, 1024)
	add_child(player)
	cm.ground_enabled = false
	cm.decals_enabled = false
	cm.deco_enabled = false
	cm.world_atmosphere_enabled = false
	cm.ground_splat_enabled = false
	cm.load_radius = 0
	cm.unload_radius = 1
	cm.use_camera_stream_bounds = false
	cm.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn")
	cm.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn")
	cm.cover_half_scene = load("res://scenes/world/cover/CoverHalf.tscn")
	cm.configure_procedural_world(plan_seed, plan["connectors_by_chunk"], plan["urban_access_by_chunk"], plan["role_by_chunk"], plan["terrain_by_chunk"], plan["archetype_by_chunk"])
	add_child(cm)
	cm.set_process(false)
	cm.start_streaming(player.position)
	for _frame in range(30):
		await get_tree().process_frame
	var matches: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(GroundLootCap.ITEM_GROUP):
		if int(node.get("secondary_objective_id")) == ID:
			matches.append(node)
	print("CACHE_SPAWNER_INVENTORY ", _spawn_inventory)
	_check(DistrictPlan.secondary_objective_id(plan_seed, COORD, &"dangerous_alley_cache") == ID, "reproduction matches the exact omitted objective identity")
	_check(matches.size() >= 1 and matches.size() <= 2, "production cache creates its one or two genuine tagged pickups after chunk registration (%d)" % matches.size())
	for pickup: Node2D in matches:
		_check(cm.is_cell_walkable(cm.world_to_cell(pickup.global_position)), "real cache reward lands on a loaded walkable cell")
	if not matches.is_empty():
		cm.set("_current_center", Vector2i(50, 50))
		cm.call("_update_streaming")
		await get_tree().process_frame
		cm.set("_current_center", COORD)
		cm.call("_update_streaming")
		for _frame in range(3):
			await get_tree().process_frame
		var after_reload := 0
		for node: Node in get_tree().get_nodes_in_group(GroundLootCap.ITEM_GROUP):
			if int(node.get("secondary_objective_id")) == ID:
				after_reload += 1
		_check(after_reload == matches.size(), "uncollected genuine rewards survive streaming without a duplicate payout")
	for pickup: Node2D in matches:
		pickup.queue_free()
	cm.queue_free()
	player.queue_free()
	await get_tree().process_frame
	_check(SaveManager.debug_save_writes == writes, "cache reproduction writes no saves")
	print("TaggedCacheStreamingTest: %d failed" % _failures)
	get_tree().quit(1 if _failures else 0)
