extends Node
## External acceptance fixture; no Game, generation, screenshot, or runtime edits.
## Checks the real renderer's city-only paths against the shared sun and real
## half-cell contact anchors, then retires each streamed owner independently.
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const ART := preload("res://core/systems/world/objectives/ObjectiveWorldArt.gd")
const CELL := 64.0
const CHUNK := 256
const EPS := 0.02
var _passes := 0
var _failures := 0
var _checks: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	_checks.append({"ok": ok, "label": label})
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _feet(row: Dictionary) -> Vector2:
	return Vector2(row.coord) * float(CHUNK) + (Vector2(row.cell) + Vector2.ONE * 0.5) * CELL


func _data(coord: Vector2i, rows: Array[Dictionary]) -> ChunkBuildData:
	var data := ChunkBuildData.new(coord, 4)
	for row: Dictionary in rows:
		if row.coord == coord:
			data.add_blocker(row.cell, WorldBlockerGeometry.Kind.HALF_COVER, 0, int(row.variant))
	return data


func _prop_batch(renderer: ChunkBlockRenderer, texture: Texture2D) -> ChunkBlockRenderer.TextureBatch:
	for batch: ChunkBlockRenderer.TextureBatch in renderer.get("_batches").values():
		if not batch.shadowless and batch.texture == texture:
			return batch
	return null


func _ground_casts(renderer: ChunkBlockRenderer) -> Array[ChunkBlockRenderer.TextureBatch]:
	var found: Array[ChunkBlockRenderer.TextureBatch] = []
	for batch: ChunkBlockRenderer.TextureBatch in renderer.get("_batches").values():
		if batch.visual.material == DEPTH.SUN_SHADOW_MATERIAL and not batch.visual.z_as_relative and batch.visual.z_index == DEPTH.GROUND_SHADE_Z:
			found.append(batch)
	return found


func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	var prior_segment: int = Global.attempt_segment
	DEPTH.reset_light()
	_test_city()
	_test_authored()
	_test_ground_forms()
	Global.attempt_segment = prior_segment
	await get_tree().process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			var path := arg.trim_prefix("--out=")
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				_check(false, "acceptance manifest can be written")
			else:
				file.store_string(JSON.stringify({"suite": "CityPropShadowAcceptance", "passes": _passes, "failures": _failures, "checks": _checks}, "  ") + "\n")
	print("CityPropShadowAcceptance: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_city() -> void:
	Global.attempt_segment = 2
	var first := Vector2i(-1, 2)
	var second := Vector2i(2, -1)
	var rows: Array[Dictionary] = [
		{"coord": first, "cell": Vector2i.ZERO, "variant": 0, "atlas": true, "role": "crate"},
		{"coord": first, "cell": Vector2i(3, 3), "variant": 4 | (1 << 3), "atlas": false, "role": "long table"},
		{"coord": second, "cell": Vector2i.ZERO, "variant": 7, "atlas": true, "role": "statue"},
		{"coord": second, "cell": Vector2i(3, 3), "variant": 5 | (2 << 3), "atlas": false, "role": "small table"},
	]
	var host := Node2D.new()
	add_child(host)
	var renderer := ChunkBlockRenderer.new()
	renderer.configure(host, CHUNK, int(CELL))
	renderer.add_chunk(_data(first, rows))
	renderer.add_chunk(_data(second, rows))
	var casts := _ground_casts(renderer)
	_check(casts.size() == 1, "S2 props share one ground-sun cast batch")
	if casts.size() != 1:
		renderer.clear()
		host.free()
		return
	var cast := casts[0]
	_check(cast.shadowless and not cast.shadow.visible and cast.shadow_mesh.visible_instance_count == 0 and cast.visual.self_modulate == Color.WHITE, "cast has one full-strength ground layer and no recursive shadow")
	_check(cast.visual_mesh.visible_instance_count == rows.size() and cast.owners.size() == rows.size(), "four HALF cells have exactly four owned visible ground casts")
	var direction := DEPTH.offset_for_height(1.0).normalized()
	var reach: Dictionary = {}
	for row: Dictionary in rows:
		var label := String(row.role)
		var texture := ChunkBlockVisualCatalog.half_texture(int(row.variant))
		_check((texture is AtlasTexture) == bool(row.atlas), label + " exercises its requested Atlas or legacy path")
		var batch := _prop_batch(renderer, texture)
		_check(batch != null, label + " has its real catalog visual batch")
		if batch == null:
			continue
		var index := batch.owners.find(row.coord)
		_check(index >= 0, label + " visual retains its chunk owner")
		if index < 0:
			continue
		var visual := batch.visual_mesh.get_instance_transform_2d(index)
		var feet := _feet(row)
		var drawn_contact := visual * Vector2(0.0, -texture.get_height() * 0.5) if texture is AtlasTexture else visual.origin
		_check(drawn_contact.distance_to(feet) < EPS, label + " still stands on the actual blocked half-cell anchor")
		var old_shadow := batch.shadow_mesh.get_instance_transform_2d(index)
		_check(old_shadow.x.length() < EPS and old_shadow.y.length() < EPS, label + " suppresses the old silhouette in the uploaded MultiMesh")
		var matches: Array[int] = []
		var size := Vector2(cast.texture.get_size())
		for i: int in cast.owners.size():
			if cast.owners[i] != row.coord:
				continue
			var transform := cast.visual_mesh.get_instance_transform_2d(i)
			if Rect2(-size * 0.5, size).has_point(transform.affine_inverse() * feet):
				matches.append(i)
		_check(matches.size() == 1, label + " contact lies inside exactly its own ground cast")
		if matches.size() != 1:
			continue
		var transform := cast.visual_mesh.get_instance_transform_2d(matches[0])
		var half_length := transform.x.length() * size.x * 0.5
		var width := transform.y.length() * size.y
		var from_feet := transform.origin - feet
		var near_end := from_feet.dot(direction) - half_length
		var far_end := from_feet.dot(direction) + half_length
		_check(transform.x.normalized().dot(direction) > 0.999 and absf(transform.x.normalized().dot(transform.y.normalized())) < 0.001, label + " cast follows the shared sun with an orthogonal footprint")
		_check(near_end < -1.0 and far_end > 16.0 and width >= CELL * 0.25 and width <= CELL * 1.5 and absf(from_feet.cross(direction)) < width * 0.5, label + " has a contacting footprint and a bounded southwest reach")
		reach[label] = far_end
	_check(float(reach.get("statue", -1.0)) > float(reach.get("crate", INF)), "the tall statue projects farther than the low crate")
	var survivors: Array[Transform2D] = []
	for i: int in cast.owners.size():
		if cast.owners[i] == second:
			survivors.append(cast.visual_mesh.get_instance_transform_2d(i))
	renderer.remove_chunk(first)
	var retained := cast.owners.size() == 2 and cast.visual_mesh.visible_instance_count == 2
	for i: int in cast.owners.size():
		retained = retained and cast.owners[i] == second and survivors.has(cast.visual_mesh.get_instance_transform_2d(i))
	_check(retained and int(renderer.get_stats().instances) == 2, "retiring the first chunk leaves both other-owned casts and visuals unchanged")
	renderer.remove_chunk(second)
	_check(renderer.get("_batches").is_empty() and host.get_child_count() == 0, "retiring the final chunk releases every visual and cast node")
	renderer.clear()
	host.free()


func _test_authored() -> void:
	Global.attempt_segment = 1
	var coord := Vector2i(1, 1)
	var rows: Array[Dictionary] = [
		{"coord": coord, "cell": Vector2i.ZERO, "variant": 0},
		{"coord": coord, "cell": Vector2i(3, 3), "variant": 4 | (1 << 3)},
	]
	var host := Node2D.new()
	add_child(host)
	var renderer := ChunkBlockRenderer.new()
	renderer.configure(host, CHUNK, int(CELL))
	renderer.add_chunk(_data(coord, rows))
	_check(_ground_casts(renderer).is_empty(), "S1 control does not acquire the city footprint cast")
	for row: Dictionary in rows:
		var texture := ChunkBlockVisualCatalog.half_texture(int(row.variant))
		var batch := _prop_batch(renderer, texture)
		_check(batch != null, "S1 control retains its catalog visual")
		if batch == null:
			continue
		var visual := batch.visual_mesh.get_instance_transform_2d(0)
		var shadow := batch.shadow_mesh.get_instance_transform_2d(0)
		var expected := DEPTH.project_transform(visual, _feet(row)) if texture is AtlasTexture else Transform2D(visual.x, visual.y, visual.origin + DEPTH.offset_for_height(8.0))
		_check(batch.shadow.visible and batch.shadow_mesh.visible_instance_count == 1 and shadow.is_equal_approx(expected), "S1 control preserves its reviewed Atlas projection or legacy offset")
	renderer.clear()
	_check(host.get_child_count() == 0, "S1 clear removes its batch nodes")
	host.free()


func _test_ground_forms() -> void:
	var host := Node2D.new()
	add_child(host)
	for name: String in ["exit_rite", "vigil", "breach", "vault"]:
		var form := ART.install(host, name, 100.0)
		_check(bool(form.get("_ground")) and form.get_node_or_null("CastShadow") == null and not form.z_as_relative and form.z_index < DEPTH.SHADOW_Z, name + " remains a ground form below shadows with no upright cast")
	host.free()
