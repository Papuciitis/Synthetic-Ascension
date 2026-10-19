extends "res://tools/tests/DistrictFamilyVisualTest.gd"

func _run() -> void:
	KIT.preview_original_materials = false
	Global.attempt_segment = 3
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var selected: Dictionary = {}
	var samples: Array = []
	var seen_roles: Dictionary = {}
	var absence_seed := -1
	var seeds: Array[int] = [1,211,16102026]
	for seed_value in range(2,65):
		if not seeds.has(seed_value): seeds.append(seed_value)
	var directions := {str(Vector2i.UP):"north",str(Vector2i.RIGHT):"east",str(Vector2i.DOWN):"south",str(Vector2i.LEFT):"west"}
	for seed_value: int in seeds:
		var theme := SegmentThemePicker.get_theme(3,seed_value)
		var plan := DistrictPlan.generate(3,seed_value,2048,theme)
		if not plan.role_by_chunk.values().has(&"checkpoint"): absence_seed = seed_value
		for role: StringName in [&"secondary_reward_building",&"district_fill",&"main_street",&"secondary_route",&"service_lane"]:
			var coords: Array[Vector2i] = []
			for coord: Vector2i in plan.role_by_chunk:
				if plan.role_by_chunk[coord] == role: coords.append(coord)
			coords.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
			for coord: Vector2i in coords.slice(0,2):
				var common := _fixture(theme,plan,coord,true)
				var guard := _fixture(theme,plan,coord,false)
				var repeat := _fixture(theme,plan,coord,false)
				_check(common.snapshot == guard.snapshot,"Natural S3 guard/common geometry, doors, floor, reward and security state match")
				_check(guard.records == repeat.records,"Independent regeneration preserves the actual family form and identity")
				samples.append({"attempt_seed":seed_value,"plan_seed":int(plan.seed),"coord":str(coord),"role":String(role),"physical_equal":common.snapshot == guard.snapshot,"nodes_common":common.nodes,"nodes_guard":guard.nodes})
				for record: Dictionary in guard.records:
					if record.city_role != "civic":
						_check(record.profile == "common_base","Non-civic neighbours keep the accepted common family")
						continue
					_check(record.profile == "checkpoint_guard_loggia","Natural civic parcel consumes actual selected S3 identity")
					seen_roles[role] = true
					var key: String = "irregular" if record.irregular else String(directions.get(record.door_direction,"unknown"))
					if not selected.has(key):
						var capture := record.duplicate(true)
						capture.merge({"attempt_seed":seed_value,"plan_seed":int(plan.seed),"coord":str(coord),"chunk_x":coord.x,"chunk_y":coord.y,"role":String(role)},true)
						selected[key] = capture
		if selected.size() >= 5 and seen_roles.has(&"district_fill") and seen_roles.has(&"secondary_reward_building") and seen_roles.has(&"main_street"): break
	_check(seen_roles.has(&"main_street"),"Production sampling includes the real semantic main_street path")
	for key: String in ["north","east","south","west","irregular"]:
		_check(selected.has(key),"Natural production has a native-review candidate: "+key)
	var packet := {"samples":samples,"selected_native_cases":selected,"natural_no_checkpoint_attempt_seed":absence_seed,"no_checkpoint_case_limit":"If -1, no natural absence was found in this bounded scan; do not claim one.","failures":failed}
	var out := "res://docs/art/reference/2026-10-19-s3-guard-loggia-v1/production-samples.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var file := FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify(packet,"\t"))
	file.close()
	print("CheckpointOfficeProductionTest: %d passed, %d failed; %d actual chunks, %d native candidates" % [passed,failed,samples.size(),selected.size()])
	get_tree().quit(1 if failed else 0)
