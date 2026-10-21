extends "res://tools/tests/CityDomesticInteriorTest.gd"
## Actual seeded reward owners, with only the six new sampling exclusions
## switched synchronously. No physics frame runs while that grid is switched.

var _created_pickups: Array[ItemPickup] = []


func _run() -> void:
	var previous_segment: int = Global.attempt_segment
	var previous_seed: int = Global.attempt_world_seed
	var previous_run_state: int = Global._rng.state
	var previous_claims: PackedInt32Array = Global.attempt_claimed_loot_ids.duplicate()
	var previous_claim_set: Dictionary = Global._claimed_loot_set.duplicate()
	var previous_writes: int = SaveManager.debug_save_writes
	var dummy := Node2D.new()
	dummy.position = Vector2(-10000000,-10000000)
	dummy.add_to_group(&"player")
	add_child(dummy)
	Global.attempt_segment = 2
	# Both reviewed S2 households plus furnished homes in later segments: the
	# household fit must leave every seeded reward identity untouched there too.
	for sample: Dictionary in HOME_FIXTURES:
		await _check_reward_owner(sample)
	Global.attempt_segment = previous_segment
	Global.attempt_world_seed = previous_seed
	Global._rng.state = previous_run_state
	Global.attempt_claimed_loot_ids = previous_claims
	Global._claimed_loot_set = previous_claim_set
	dummy.free()
	_check(SaveManager.debug_save_writes == previous_writes,"Reward comparison writes no profile")
	print("DomesticRewardStabilityTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _owner(kit: Node2D, building_id: int) -> IndoorVolume:
	var roof := kit.get("_roof") as RoofOverlay
	var selected: IndoorVolume
	for child: Node in kit.get_parent().get_children():
		if not child is IndoorVolume or (child as IndoorVolume).building_id != building_id:
			continue
		for connection: Dictionary in child.body_entered.get_connections():
			if (connection.callable as Callable).get_object() == roof:
				var candidate := child as IndoorVolume
				if selected == null or candidate.small_loot_chance > selected.small_loot_chance:
					selected = candidate
	return selected


func _check_reward_owner(sample: Dictionary) -> void:
	Global.attempt_segment = int(sample.get("segment",2))
	Global.attempt_world_seed = int(sample.seed)
	var manager: ChunkManager = _manager(int(sample.seed),int(sample.get("segment",2)))
	var coord: Vector2i = sample.coord
	var chunk: Node2D = manager._create_chunk(coord)
	manager._chunks[coord] = chunk
	var kit: Node2D = _find_kit(chunk,int(sample.id))
	_check(kit != null,"Reward comparison uses the actual retained household")
	if kit == null:
		manager.free()
		return
	var volume: IndoorVolume = _owner(kit,int(sample.id))
	var domestic := kit.get_node_or_null("CityDomesticInterior") as Node2D
	_check(volume != null and domestic != null,"Actual reward owner and six-cell furniture owner coexist")
	if volume == null or domestic == null:
		manager.free()
		return
	_check(volume.small_count_min == 1 and volume.small_count_max == 1 and not volume.local_encounter_enabled and not volume.force_large_loot,"Kept production reward owner is the eligible single-item ambient policy")
	var cells: Array[Vector2i] = []
	for record: Dictionary in domestic.get_meta(&"domestic_layout",[]):
		for cell: Vector2i in record.reserved_cells:
			cells.append(coord*32+cell)
	_check(cells.size() == 6,"Baseline switch covers exactly the six explicit new furniture exclusions")
	var claims: PackedInt32Array = Global.attempt_claimed_loot_ids.duplicate()
	var claim_set: Dictionary = Global._claimed_loot_set.duplicate()
	var run_state: int = Global._rng.state
	var secondary: int = volume.secondary_objective_id
	var rights_before: String = _rights(volume)
	var blocked_before: Dictionary = manager._blocked_cells.duplicate()
	var broad_before: Dictionary = manager._near_blockers.duplicate()
	var baseline: Dictionary = _probe(volume,manager,cells,true,false,claims,claim_set,run_state,secondary)
	var furnished: Dictionary = _probe(volume,manager,cells,false,false,claims,claim_set,run_state,secondary)
	_check(var_to_str(baseline.items) == var_to_str(furnished.items),"Actual chance/count/item identity/full rolls match before and after furnishing id="+str(sample.id))
	_check(baseline.claimed == furnished.claimed and baseline.secondary_after == furnished.secondary_after,"Actual seeded claim and secondary ownership transitions are unchanged")
	_check(baseline.run_state == furnished.run_state,"Actual reward generation consumes the same run-owned manifestation RNG")
	_check(baseline.claimed == (baseline.items.size() > 0),"Actual reward claim is acquired exactly when its owner pays out")
	# Also exercise the actual item factory when the retained seeded chance
	# legitimately pays nothing. This preserves chance policy above.
	var factory_baseline: Dictionary = _probe(volume,manager,cells,true,true,claims,claim_set,run_state,secondary)
	var factory_furnished: Dictionary = _probe(volume,manager,cells,false,true,claims,claim_set,run_state,secondary)
	_check(factory_baseline.items.size() == 1 and factory_furnished.items.size() == 1,"Both actual single-item factories produce one real pickup for the comparison")
	_check(var_to_str(factory_baseline.items) == var_to_str(factory_furnished.items),"Single-item full rolled identity survives legal placement changes even when the chance control declines a reward")
	_check(factory_baseline.run_state == factory_furnished.run_state,"Single-item factory manifestation RNG consumption is unchanged")
	_check(_rights(volume) == rights_before,"Furniture comparison changes no building ID, reward range, encounter policy or exploration rights")
	_check(manager._blocked_cells == blocked_before and manager._near_blockers == broad_before,"Synchronous baseline sampling switch restores all blocker/broad-phase state")
	print("DomesticRewardStabilityTest evidence: "+JSON.stringify({"segment":int(sample.get("segment",2)),"seed":sample.seed,"building_id":sample.id,"actual_before":baseline,"actual_furnished":furnished,"factory_before":factory_baseline,"factory_furnished":factory_furnished,"limits":"Baseline disables only six new grid exclusions synchronously, because production loot placement queries walkability, not physics. No frame or physics movement occurs during the switch. Production chance and claim path run separately from the guaranteed factory control; pickup positions may differ."}))
	Global.attempt_claimed_loot_ids = claims
	Global._claimed_loot_set = claim_set
	Global._rng.state = run_state
	volume.secondary_objective_id = secondary
	await get_tree().process_frame
	for pickup: ItemPickup in _created_pickups:
		if is_instance_valid(pickup): pickup.queue_free()
	_created_pickups.clear()
	await get_tree().process_frame
	manager._unregister_chunk_cells(coord)
	manager._chunks.erase(coord)
	chunk.free()
	manager.free()


func _probe(volume: IndoorVolume, manager: ChunkManager, cells: Array[Vector2i], baseline: bool, factory: bool, claims: PackedInt32Array, claim_set: Dictionary, run_state: int, secondary: int) -> Dictionary:
	Global.attempt_claimed_loot_ids = claims.duplicate()
	Global._claimed_loot_set = claim_set.duplicate()
	Global._rng.state = run_state
	volume.secondary_objective_id = secondary
	volume._loot_attempted = false
	volume._reward_refs.clear()
	if baseline:
		for cell: Vector2i in cells:
			manager._blocker_erase(manager._blocked_cells,cell)
	if factory:
		var rng := RandomNumberGenerator.new()
		rng.seed = volume._mix_seed(Global.attempt_world_seed,volume.building_id)
		rng.randf() # Same chance draw precedes the production item factory.
		var bonus: int = volume.small_rarity_bonus_per_segment*maxi(0,Global.attempt_segment-1)
		volume._spawn_loot(rng,volume.small_count_min,volume.small_count_max,volume.small_rarity_min+bonus,volume.small_rarity_max+bonus)
	else:
		volume._try_spawn_loot()
	var items: Array[Dictionary] = []
	var positions: Array = []
	for reference: WeakRef in volume._reward_refs:
		var pickup := reference.get_ref() as ItemPickup
		if pickup == null:
			continue
		_created_pickups.append(pickup)
		items.append(_item(pickup))
		positions.append([pickup.global_position.x,pickup.global_position.y])
		_check(manager.is_cell_walkable(manager.world_to_cell(pickup.global_position)),"Actual reward placement respects the current baseline/furnished walkability side")
	if baseline:
		for cell: Vector2i in cells:
			manager._blocker_set(manager._blocked_cells,cell,true)
	return {"items":items,"positions":positions,"claimed":Global.has_claimed_loot(volume.building_id),"secondary_after":volume.secondary_objective_id,"run_state":str(Global._rng.state)}


func _item(pickup: ItemPickup) -> Dictionary:
	var inst: ItemInstance = pickup.item_instance
	_check(inst != null and inst.data != null,"Production reward carries a full ItemInstance")
	if inst == null or inst.data == null:
		return {}
	var mods: Dictionary = {}
	if inst.rolled_mods != null:
		for key: String in ["max_hp","armor","move_speed","power","haste","luck"]:
			mods[key] = inst.rolled_mods.get(key)
	return {"id":String(inst.data.id),"pickup_id":pickup.item_id,"amount":pickup.amount,"rarity":inst.rarity,"polarity":inst.polarity,"progress":inst.progress,"upgrade_meter":inst.upgrade_meter,"best_pct":inst.best_pct,"manifestation_id":String(inst.manifestation_id),"locked":inst.locked,"mods":mods}


func _rights(volume: IndoorVolume) -> String:
	var result: Dictionary = {}
	for key: String in ["building_id","exploration_loot_enabled","small_loot_chance","small_count_min","small_count_max","small_rarity_min","small_rarity_max","small_rarity_bonus_per_segment","local_encounter_enabled","force_large_loot","large_area_threshold_cells","site_area_cells","size_cells","cell_tl"]:
		result[key] = volume.get(key)
	return var_to_str(result)
