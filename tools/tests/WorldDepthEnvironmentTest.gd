extends Node

const FOLIAGE := preload("res://core/systems/world/chunks/ChunkFoliageRenderer.gd")
const ART := preload("res://core/systems/world/WorldArt.gd")
const MATERIALS := preload("res://core/systems/world/WorldDressingMaterials.gd")
var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("WorldDepthEnvironmentTest: " + message)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("WorldDepthEnvironmentTest skipped: real renderer required for MultiMesh geometry readback")
		get_tree().quit()
		return
	var chunk := Node2D.new()
	add_child(chunk)
	var placements: Array[Dictionary] = [
		{"cell": Vector2i(2, 3), "species": 0, "scale": 1.0, "alpha": 0.9, "turns": 1},
		{"cell": Vector2i(5, 3), "species": 1, "scale": 1.2, "alpha": 0.8, "turns": 2},
		{"cell": Vector2i(8, 3), "species": 2, "scale": 0.8, "alpha": 0.9, "turns": 3},
	]
	FOLIAGE.add_to_chunk(chunk, placements, 64, Color.WHITE)
	await RenderingServer.frame_post_draw
	for species in range(3):
		var plant := chunk.get_node("FoliageBatches/Plants_%d" % species) as MultiMeshInstance2D
		var shadow := chunk.get_node("FoliageBatches/Shadows_%d" % species) as MultiMeshInstance2D
		var mesh := plant.multimesh.mesh as QuadMesh
		var transform := plant.multimesh.get_instance_transform_2d(0)
		var cast := shadow.multimesh.get_instance_transform_2d(0)
		var source: Texture2D = FOLIAGE.ART.vegetation_texture(species)
		var source_ratio := float(source.get_height()) / float(source.get_width())
		_check(is_equal_approx(mesh.size.y / mesh.size.x, source_ratio), "foliage %d keeps the painted texture proportions" % species)
		_check(absf(transform.x.y) < 0.001 and absf(transform.y.x) < 0.001 and transform.y.y < 0.0, "foliage %d stays upright despite old quarter-turn placement metadata" % species)
		var local_feet := Vector2(0.0, -mesh.size.y * 0.5)
		var feet := transform * local_feet
		var expected_feet := (Vector2(placements[species].cell) + Vector2(0.5, 0.5)) * 64.0
		_check(feet.distance_to(expected_feet) < 0.01, "foliage %d stays planted at its reserved cell" % species)
		_check((cast * local_feet).distance_to(feet) < 0.01, "foliage %d shadow starts at its feet" % species)
		var head_cast := cast * Vector2(0.0, mesh.size.y * 0.5) - feet
		_check(head_cast.x < -1.0 and head_cast.y > 1.0, "foliage %d casts southwest from the top-right light" % species)
		_check(plant.texture == MATERIALS.base_texture(source), "foliage %d binds the atlas source without a pixel readback" % species)
		_check(absf(shadow.multimesh.get_instance_color(0).a - float(placements[species].alpha)) < 0.005, "foliage %d applies placement alpha once before the shared shadow shader" % species)
	_check(chunk.get_node("FoliageBatches").get_child_count() == 6, "foliage keeps one visual and one shadow batch per species")
	var host := Node2D.new()
	add_child(host)
	var blocks := ChunkBlockRenderer.new()
	blocks.configure(host, 256, 64)
	var data := ChunkBuildData.new(Vector2i.ZERO, 4)
	data.add_blocker(Vector2i(1, 1), WorldBlockerGeometry.Kind.HALF_COVER, 0, 0)
	blocks.add_chunk(data)
	for batch: ChunkBlockRenderer.TextureBatch in blocks._batches.values():
		var offset := batch.shadow_transforms[0].origin - batch.transforms[0].origin
		_check(offset.x < 0.0 and offset.y > 0.0, "low props share the actors' southwest shadow direction")
		_check(batch.texture is AtlasTexture, "generated low props replace matching placeholders")
		_check(batch.visual.texture == MATERIALS.base_texture(batch.texture), "low props bind the raw atlas with explicit region mapping")
		var texture_size := batch.texture.get_size()
		var feet := Vector2(96, 96)
		_check((batch.transforms[0] * Vector2(0, -texture_size.y * 0.5)).distance_to(feet) < 0.01, "generated low prop feet remain on the blocked cell")
		_check((batch.shadow_transforms[0] * Vector2(0, -texture_size.y * 0.5)).distance_to(feet) < 0.01, "generated low prop shadow starts at the same feet")
	_check(data.kind_at(Vector2i(1, 1)) == WorldBlockerGeometry.Kind.HALF_COVER and data.occupied_indices().size() == 1, "visual dressing preserves the solid blocker footprint")
	for id: StringName in [&"fern", &"olive_shrub", &"mossy_rubble", &"crate", &"broken_pillar", &"hooded_statue"]:
		var texture := ART.dressing_texture(id) as AtlasTexture
		_check(texture != null and texture.region.has_area(), "%s has a whole-silhouette atlas resource" % id)
	for variant in [0, 1, 2, 3, 6, 7]:
		_check(is_zero_approx(ChunkBlockVisualCatalog.half_rotation(variant | (3 << 3))), "painted prop variant %d preserves its baked light direction" % variant)
	blocks.clear()
	chunk.queue_free()
	host.queue_free()
	print("WorldDepthEnvironmentTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
