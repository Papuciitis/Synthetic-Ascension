extends "res://tools/tests/DistrictFamilyVisualTest.gd"

func _run() -> void:
	KIT.preview_original_materials = false
	Global.attempt_segment = 3
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var input := FileAccess.open("res://docs/art/reference/2026-10-19-s3-guard-loggia-v1/production-samples.json",FileAccess.READ)
	var packet: Dictionary = JSON.parse_string(input.get_as_text())
	input.close()
	var warm_theme := SegmentThemePicker.get_theme(3,1)
	var warm_plan := DistrictPlan.generate(3,1,2048,warm_theme)
	_fixture(warm_theme,warm_plan,Vector2i(2,-5),false,null,true)
	var rows: Array = []
	for key: String in ["south","north","east","west","irregular"]:
		var sample: Dictionary = packet.selected_native_cases[key]
		var theme := SegmentThemePicker.get_theme(3,int(sample.attempt_seed))
		var plan := DistrictPlan.generate(3,int(sample.attempt_seed),2048,theme)
		var coord := Vector2i(int(sample.chunk_x),int(sample.chunk_y))
		for repetition: int in 3:
			var common := _fixture(theme,plan,coord,true,null,true)
			var guard := _fixture(theme,plan,coord,false,null,true)
			_check(common.snapshot == guard.snapshot,"Full chunk activation keeps identical physical/building state")
			_check(not common.phase.is_empty() and not guard.phase.is_empty(),"Managed chunk creation records actual content and blocker costs")
			rows.append({"case":key,"repetition":repetition,"common":common.phase,"guard":guard.phase,"nodes_common":common.nodes,"nodes_guard":guard.nodes,"physical_equal":common.snapshot == guard.snapshot})
	var report := {"rows":rows,"failures":failed,"limits":"Warmed headless CPU fixture, three paired full chunk creations for each of five natural selected chunks. Ground rendering, ambient decoration and sites are disabled. Includes the real content/floor/blocker activation path; excludes GPU drawing and is not human play or whole-run loading/performance acceptance. Common-base override isolates family form costs on current routing source, not routing overhead against the historical commit."}
	var file := FileAccess.open("res://docs/art/reference/2026-10-19-s3-guard-loggia-v1/chunk-cost-probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("CheckpointOfficeCostProbe: %d passed, %d failed; %d paired managed builds" % [passed,failed,rows.size()])
	get_tree().quit(1 if failed else 0)
