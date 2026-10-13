extends Node

const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const LAB := preload("res://scenes/world/cover/CoverHalfLab.tscn")
const HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
const LAB_TO_CATALOG := [4, 5, 0, 1, 3, 2, 6]
var _passes := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("AuthoredCoverDepthTest: " + message)


func _lab_variant(at: Vector2) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = int((floori(at.x) * 73856093) ^ (floori(at.y) * 19349663) ^ 0x6C4B1AB)
	var index := rng.randi_range(0, 6)
	return LAB_TO_CATALOG[index] | (rng.randi_range(0, 3) << 3)


func _sample_cells(lab: bool) -> Dictionary:
	var result: Dictionary = {}
	for y in range(-8, 9):
		for x in range(-8, 9):
			var at := (Vector2(x, y) + Vector2(0.5, 0.5)) * 64.0
			var variant := _lab_variant(at) if lab else ChunkBlockVisualCatalog.half_variant(at)
			if not result.has(variant & 7):
				result[variant & 7] = Vector2i(x, y)
	return result


func _assert_cover(cover: Node2D, expected: Texture2D, variant: int) -> void:
	var spr := cover.get_node("Sprite2D") as Sprite2D
	var shadow := cover.get_node("Shadow") as Sprite2D
	var collider := cover.get_node("CollisionShape2D") as CollisionShape2D
	_check(spr.texture == expected, "%s variant %d selects matching art with the original RNG" % [cover.name, variant & 7])
	_check(cover.scale == Vector2.ONE and collider.scale == Vector2.ONE and not collider.disabled and is_equal_approx((collider.shape as CircleShape2D).radius, WorldBlockerGeometry.HALF_COVER_RADIUS), "%s preserves its body and circular footprint" % cover.name)
	if expected is AtlasTexture:
		_check(is_zero_approx(spr.rotation) and is_equal_approx(spr.scale.x * expected.get_width(), 64.0) and spr.scale.is_equal_approx(Vector2.ONE * spr.scale.x), "%s preserves painted orientation, source aspect and cell width" % cover.name)
		var feet := Vector2(0, expected.get_height() * 0.5)
		_check((spr.transform * feet).length() < 0.01 and (shadow.transform * feet).length() < 0.01, "%s visual and shadow share the collision anchor" % cover.name)
		var cast_head := shadow.transform * -feet
		_check(cast_head.x < -1 and cast_head.y > 1, "%s casts southwest from its feet" % cover.name)
		_check(spr.material == null and shadow.texture == spr.texture and shadow.material is ShaderMaterial and (shadow.material as ShaderMaterial).shader == DEPTH.SHADOW_SHADER, "%s keeps native sprite atlas UV and the shared alpha shadow" % cover.name)
		if shadow.material is ShaderMaterial:
			_check((shadow.material as ShaderMaterial).get_shader_parameter("texture_region") == Vector4(0, 0, 1, 1) and shadow.modulate == Color.WHITE, "%s avoids atlas remapping and duplicate shadow alpha" % cover.name)
	else:
		_check(is_equal_approx(spr.rotation, float((variant >> 3) & 3) * PI * 0.5), "%s preserves legacy table rotation RNG" % cover.name)
	cover.call("_apply")
	_check(spr.texture == expected, "%s remains deterministic when reapplied" % cover.name)


func _run() -> void:
	var lab_cells := _sample_cells(true)
	_check(lab_cells.size() == 7, "fixture covers every original lab role")
	for cell: Vector2i in lab_cells.values():
		var cover := LAB.instantiate() as Node2D
		cover.position = (Vector2(cell) + Vector2(0.5, 0.5)) * 64.0
		add_child(cover)
		var variant := _lab_variant(cover.position)
		_assert_cover(cover, ChunkBlockVisualCatalog.half_texture(variant), variant)
		cover.queue_free()
	var half_cells := _sample_cells(false)
	_check(half_cells.size() == 8, "fixture covers every catalog role")
	for cell: Vector2i in half_cells.values():
		var cover := HALF.instantiate() as Node2D
		cover.position = (Vector2(cell) + Vector2(0.5, 0.5)) * 64.0
		add_child(cover)
		var variant := ChunkBlockVisualCatalog.half_variant(cover.position)
		_assert_cover(cover, ChunkBlockVisualCatalog.half_texture(variant), variant)
		cover.queue_free()
	_test_alpha_footprint(half_cells[0])
	await get_tree().process_frame
	await _test_authored_batches(lab_cells)
	print("AuthoredCoverDepthTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)


func _test_alpha_footprint(cell: Vector2i) -> void:
	var at := (Vector2(cell) + Vector2(0.5, 0.5)) * 64.0
	var variant := ChunkBlockVisualCatalog.half_variant(at)
	var baseline := HALF.instantiate() as Node2D
	var baseline_sprite := baseline.get_node("Sprite2D") as Sprite2D
	baseline_sprite.rotation = float((variant >> 3) & 3) * PI * 0.5
	baseline.call("_apply_alpha_collision", baseline_sprite, ChunkBlockVisualCatalog.HALF_TEXTURES[variant & 7])
	var cover := HALF.instantiate() as Node2D
	cover.position = at
	cover.set("use_alpha_collision", true)
	add_child(cover)
	var before := baseline.find_children("AlphaCol*", "CollisionPolygon2D", false, false)
	var after := cover.find_children("AlphaCol*", "CollisionPolygon2D", false, false)
	var equal := before.size() == after.size() and not before.is_empty()
	for i in range(mini(before.size(), after.size())):
		var old_poly := before[i] as CollisionPolygon2D
		var new_poly := after[i] as CollisionPolygon2D
		equal = equal and old_poly.polygon == new_poly.polygon and old_poly.transform.is_equal_approx(new_poly.transform)
	_check(equal, "optional alpha collision preserves the original legacy footprint despite visual grounding")
	cover.call("_apply")
	for i in range(mini(before.size(), after.size())):
		equal = equal and (before[i] as CollisionPolygon2D).polygon == (after[i] as CollisionPolygon2D).polygon and (before[i] as CollisionPolygon2D).transform.is_equal_approx((after[i] as CollisionPolygon2D).transform)
	_check(equal, "reapplying grounded visuals does not move optional alpha collision")
	baseline.free()
	cover.queue_free()


func _test_authored_batches(cells: Dictionary) -> void:
	var manager := ChunkManager.new()
	manager.tiled_world_rendering = true
	manager.ground_enabled = false
	manager.deco_enabled = false
	manager.decals_enabled = false
	add_child(manager)
	var geometry := Node2D.new()
	add_child(geometry)
	var level := Level1Builder.new()
	level.cover_half_lab_scene = LAB
	level._cm = manager
	level._geo = geometry
	for cell: Vector2i in cells.values():
		level._half_cells[cell] = true
	level.call("_spawn_planned_geometry")
	level.call("_register_manual_blocks")
	level.call("_tile_authored_geometry")
	await get_tree().process_frame
	_check(geometry.find_children("*", "Sprite2D", true, false).is_empty(), "real tile-repeat authored scenes keep zero per-prop sprites")
	_check(level._wall_renderer != null and int(level._wall_renderer.get_stats()["instances"]) == cells.size(), "real authored half-cover cells use the existing world batches")
	var actual_counts: Dictionary = {}
	if level._wall_renderer != null:
		for batch: ChunkBlockRenderer.TextureBatch in level._wall_renderer._batches.values():
			actual_counts[batch.texture.resource_path] = batch.transforms.size()
	var expected_counts: Dictionary = {}
	for cell: Vector2i in cells.values():
		var at := (Vector2(cell) + Vector2(0.5, 0.5)) * 64.0
		var path := ChunkBlockVisualCatalog.half_texture(_lab_variant(at)).resource_path
		expected_counts[path] = int(expected_counts.get(path, 0)) + 1
	_check(actual_counts == expected_counts, "authored batch texture counts preserve all seven lab RNG roles")
	var anchors := true
	if level._wall_renderer != null:
		for batch: ChunkBlockRenderer.TextureBatch in level._wall_renderer._batches.values():
			if not batch.texture is AtlasTexture:
				continue
			var mesh_feet := Vector2(0, -float(batch.texture.get_height()) * 0.5)
			for i in range(batch.transforms.size()):
				var feet := batch.transforms[i] * mesh_feet
				var cell := Vector2i(floori(feet.x / 64.0), floori(feet.y / 64.0))
				anchors = anchors and level._half_cells.has(cell) and (batch.shadow_transforms[i] * mesh_feet).distance_to(feet) < 0.01
	_check(anchors, "authored painted batches keep visual and cast feet on the registered cells")
	_check(manager._manual_blocked_cells.size() == cells.size(), "authored BFS blocker footprints remain registered")
	var collisions := geometry.find_children("*", "CollisionShape2D", true, false)
	var stable := collisions.size() == cells.size()
	for collider: CollisionShape2D in collisions:
		stable = stable and collider.shape is CircleShape2D and not collider.disabled and is_equal_approx((collider.shape as CircleShape2D).radius, WorldBlockerGeometry.HALF_COVER_RADIUS)
	_check(stable, "external visual batching retains the real authored scene collisions")
	if level._wall_renderer != null:
		level._wall_renderer.clear()
	level.free()
	geometry.queue_free()
	manager.queue_free()
	await get_tree().process_frame
