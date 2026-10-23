extends "res://tools/tests/CityServiceNaturalTest.gd"
## Generated reward streets use the same shared ground and short door
## approaches as ordinary streets. Their architecture/rewards still generate.

func _run() -> void:
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	Global.attempt_segment = 2
	var theme := SegmentThemePicker.get_theme(2, 16102026)
	var plan := DistrictPlan.generate(2, 16102026, 2048, theme)
	var fixtures := 0
	for coord: Vector2i in plan.role_by_chunk:
		if plan.role_by_chunk[coord] != &"secondary_reward_building":
			continue
		var fixture := actual_fixture(theme, plan, coord)
		var chunk: Node2D = fixture.chunk
		var kits := 0
		var approaches := 0
		for child: Node in chunk.get_children():
			if child.name == &"ConnectedStreetFrontages":
				approaches += child.get_child_count()
			if not child.is_in_group(&"city_block_building"):
				continue
			kits += 1
			for surface: Node in child.get_children():
				if surface.has_meta(&"city_paving"):
					failures.append("Generated reward street retains the broad parcel surround at " + str(coord))
		if kits == 0 or approaches == 0:
			failures.append("Generated reward street lacks real architecture or door approaches at " + str(coord))
		fixtures += 1
		(fixture.cm as ChunkManager).free()
	if fixtures == 0:
		failures.append("No generated reward street was exercised")
	for failure: String in failures:
		push_error(failure)
	print("CityStreetGroundAllocationTest: fixtures=%d failures=%d" % [fixtures, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
