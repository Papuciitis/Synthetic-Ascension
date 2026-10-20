extends "res://tools/tests/ProcChunkReachabilityTest.gd"
## A small annex may use a missed safe lot; existing parcels/rewards stay exact.

func _run() -> void:
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	Global.attempt_segment = 2
	_check_irregular_upper()
	for seed_value in [17,211,2026,16102026]:
		for no_fit in [false,true]:
			var cm := ChunkManager.new()
			cm.world_seed = seed_value
			cm.generation_enabled = false
			cm.ground_enabled = false
			cm.ground_splat_enabled = false
			cm.deco_enabled = false
			cm.sites_enabled = false
			cm.cover_full_scene = COVER_FULL
			cm.cover_window_scene = COVER_WINDOW
			add_child(cm)
			cm._gen_coord = Vector2i.ZERO
			cm._chunk_blocked[Vector2i.ZERO] = []
			var data := ChunkBuildData.new(Vector2i.ZERO,32)
			cm._active_build_data = data
			var chunk := Node2D.new()
			cm.add_child(chunk)
			var generator := SiteParcelsImpl.new()
			var extent := Rect2i(0,0,32,32)
			var placed: Array[Rect2i] = []
			var cfg := {"city_block_style":true,"city_shared_ground":true,"secondary_objective_id":41,"local_encounter_enabled":true,"parcel_loot_chance":1.0}
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			generator._spawn_building_rect(cm,chunk,Vector2i.ZERO,Rect2i(3,10,12,7),Vector2i.DOWN,&"workshop",[],placed,cfg,rng,extent)
			var before_kinds := data.blocker_kind_code.duplicate()
			var before_masks := data.blocker_mask.duplicate()
			var before_rng := rng.state
			var reward: IndoorVolume
			for child: Node in chunk.get_children():
				if child is IndoorVolume: reward = child
			var before_reward := str([reward.building_id,reward.secondary_objective_id,reward.small_loot_chance,reward.local_encounter_count,reward.cell_tl,reward.size_cells])
			var keepouts: Array[Rect2i] = [Rect2i(0,18,32,5),Rect2i(18,0,5,32)]
			if no_fit: keepouts.append(extent)
			var bands: Array[Dictionary] = [{"rect":Rect2i(1,8,30,10),"door_dir":Vector2i.DOWN}]
			generator._complete_service_frontage(cm,chunk,Vector2i.ZERO,bands,keepouts,placed,cfg,extent)
			if placed.size() != (1 if no_fit else 2): failures.append("Annex must fit one safe lot or leave a no-fit lane unchanged")
			if rng.state != before_rng: failures.append("Annex changes original lot RNG")
			if before_reward != str([reward.building_id,reward.secondary_objective_id,reward.small_loot_chance,reward.local_encounter_count,reward.cell_tl,reward.size_cells]): failures.append("Annex changes existing reward")
			for index in before_kinds.size():
				var cell := data.cell_for_index(index)
				if not no_fit and placed[1].has_point(cell): continue
				if data.blocker_kind_code[index] != before_kinds[index] or data.blocker_mask[index] != before_masks[index]: failures.append("Annex changes unrelated physical cell")
			for keepout: Rect2i in keepouts:
				if no_fit: continue
				for y in range(keepout.position.y,keepout.end.y):
					for x in range(keepout.position.x,keepout.end.x):
						if data.kind_at(Vector2i(x,y)) >= 0: failures.append("Annex blocks protected route")
			var reachable := _reachable(data,Vector2i(20,20))
			for child: Node in chunk.get_children():
				if not child is IndoorVolume or child == reward: continue
				if child.secondary_objective_id != 0 or child.local_encounter_enabled or child.small_loot_chance > 0: failures.append("Service annex adds reward/security")
				if child.exploration_loot_enabled: failures.append("Annex must disable exploration loot even when positive Luck raises a zero base chance")
				var doorway := Vector2i(chunk.to_local(child.to_global(child.get("_presentation_entry")))/64)
				if not reachable.has(doorway): failures.append("Annex real entry is unreachable")
			cm.free()
	for failure: String in failures: push_error(failure)
	print("CityServiceFrontageTest: fixtures=8 failures=%d" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)

func _check_irregular_upper() -> void:
	var outline := PackedVector2Array([Vector2(128,128),Vector2(640,128),Vector2(640,640),Vector2(384,640),Vector2(384,512),Vector2(128,512)])
	for civic in [false,true]:
		var roof := preload("res://scenes/world/buildings/RoofOverlay.tscn").instantiate() as RoofOverlay
		add_child(roof)
		roof.configure_polygon(outline,Vector2(384,640),Vector2(640,640),[],&"workshop",17,[],64)
		var kit := preload("res://scenes/world/buildings/CityBlockKit.gd").new()
		add_child(kit)
		kit.configure(Rect2i(2,2,8,8),64,[],roof,civic,outline,true)
		var faces := kit.get_node("CardinalWallReturns")
		for point: Vector2 in [Vector2(512,480),Vector2(256,352)]:
			var covered := false
			for shape: Node in faces.get_children():
				if shape is Polygon2D and Geometry2D.is_point_in_polygon(point,shape.polygon): covered = true
			if not covered: failures.append("Raised irregular wall leaves upper face uncovered: civic=%s point=%s" % [civic,point])
		kit.free()
		roof.free()
