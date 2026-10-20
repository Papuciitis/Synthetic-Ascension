extends "res://tools/tests/DomesticWallMaterialTest.gd"
## S2 cool masonry gains relief without poisoning S3 or warm-home materials.


func _run() -> void:
	var previous_segment: int = Global.attempt_segment
	var host := Node2D.new()
	add_child(host)
	var renderer := ChunkBlockRenderer.new()
	renderer.configure(host,256,64)
	var originals: Dictionary = {}
	for specification: Dictionary in [
		{"coord":Vector2i.ZERO,"segment":2,"domestic":false},
		{"coord":Vector2i(1,0),"segment":2,"domestic":true},
		{"coord":Vector2i(2,0),"segment":3,"domestic":false},
		{"coord":Vector2i(3,0),"segment":2,"domestic":false},
	]:
		Global.attempt_segment = int(specification.segment)
		var data: ChunkBuildData = _wall_fixture(specification.coord)
		if bool(specification.domestic):
			for index: int in data.occupied_indices():
				data.blocker_variant[index] |= ChunkBlockVisualCatalog.VARIANT_DOMESTIC_STONE
		var before: String = var_to_str([data.blocker_kind_code,data.blocker_mask,data.blocker_variant])
		renderer.add_chunk(data)
		_check(var_to_str([data.blocker_kind_code,data.blocker_mask,data.blocker_variant]) == before,"Pale relief changes no blocker kind, connection mask or physical variant")
		originals[specification.coord] = data
	var materials: Dictionary = {}
	var counts: Dictionary = {}
	var fills: Dictionary = {}
	for batch: ChunkBlockRenderer.TextureBatch in (renderer.get("_batches") as Dictionary).values():
		var material := batch.visual.material as ShaderMaterial
		_check(material != null and material.shader != null,"Every owned stone batch has an explicit material")
		if material == null or material.shader == null: continue
		for owner: Vector2i in batch.owners:
			materials[owner] = material
			if batch.shadowless:
				fills[owner] = int(fills.get(owner,0))+1
			else:
				counts[owner] = int(counts.get(owner,0))+1
			var warm: bool = owner == Vector2i(1,0)
			_check(material.shader.resource_path == (DOMESTIC_SHADER if warm else CITY_SHADER),"Pale relief retains the correct warm/cool source shader owner")
			if warm: continue
			var raw: Variant = material.get_shader_parameter("source_relief")
			var relief: float = float(raw) if raw != null else 0.0
			_check(is_zero_approx(relief) if owner == Vector2i(2,0) else relief > 0.0,"Only actual S2 pale wall/window/partition/fill owners receive relief")
	for owner: Vector2i in originals:
		_check(int(counts.get(owner,0)) == 4 and int(fills.get(owner,0)) > 0,"Envelope, window, real under-roof partition and corner plugs keep their owned presentation")
	if materials.has_all([Vector2i.ZERO,Vector2i(2,0),Vector2i(3,0)]):
		_check(materials[Vector2i.ZERO] != materials[Vector2i(2,0)],"S2 pale material cache is separate from the untouched S3/default cache")
		_check(materials[Vector2i.ZERO] == materials[Vector2i(3,0)],"Returning to S2 reuses its own stable material after S3 loads")
	renderer.remove_chunk(Vector2i.ZERO)
	Global.attempt_segment = 3
	renderer.add_chunk(originals[Vector2i(2,0)])
	for batch: ChunkBlockRenderer.TextureBatch in (renderer.get("_batches") as Dictionary).values():
		if not batch.owners.has(Vector2i(3,0)): continue
		var material := batch.visual.material as ShaderMaterial
		var raw: Variant = material.get_shader_parameter("source_relief") if material != null else null
		_check(raw != null and float(raw) > 0.0,"S3 reload/unload cannot reset a surviving S2 owner's material")
	renderer.clear()
	host.free()
	Global.attempt_segment = previous_segment
	print("S2PaleMasonryTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)
