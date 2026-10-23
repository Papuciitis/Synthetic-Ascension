extends Node

const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var host := Node2D.new()
	host.name = "BlockBatchHost"
	add_child(host)
	var renderer := ChunkBlockRenderer.new()
	renderer.configure(host, 256, 64)

	var first := ChunkBuildData.new(Vector2i.ZERO, 4)
	first.add_blocker(Vector2i(0, 0), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.E | WorldBlockerGeometry.W)
	first.add_blocker(Vector2i(1, 0), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.N | WorldBlockerGeometry.E)
	first.add_blocker(Vector2i(2, 0), WorldBlockerGeometry.Kind.HALF_COVER, 0, 11)
	var second := ChunkBuildData.new(Vector2i(1, 0), 4)
	second.add_blocker(Vector2i(0, 0), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.E | WorldBlockerGeometry.W)
	second.add_blocker(Vector2i(1, 0), WorldBlockerGeometry.Kind.WINDOW, WorldBlockerGeometry.N | WorldBlockerGeometry.S)

	renderer.add_chunk(first)
	renderer.add_chunk(second)
	var stats := renderer.get_stats()
	_check(int(stats.instances) == 5, "one visual instance is emitted per occupied blocker cell")
	_check(int(stats.shadow_instances) == 5, "shadow batches retain blocker readability")
	_check(int(stats.batches) <= ChunkBlockVisualCatalog.texture_count() * 2, "renderer node count is bounded by texture variants")
	_check(int(stats.runtime_images_created) == 0, "streaming creates no runtime image textures")
	_check(host.find_children("*", "MultiMeshInstance2D", true, false).size() == int(stats.batches), "host owns only the reported visual batches")
	_check(host.find_children("*", "Sprite2D", true, false).is_empty(), "renderer creates no per-cell sprites")
	_check(host.find_children("*", "TileMapLayer", true, false).is_empty(), "renderer creates no tile layers")
	_check(host.get_child_count() == int(stats.batches), "renderer adds no per-cell helper nodes")

	renderer.remove_chunk(Vector2i.ZERO)
	_check(int(renderer.get_stats().instances) == 2, "chunk removal retires only its instances")
	_check(int(renderer.get_stats().shadow_instances) == 2, "chunk removal retires matching shadow instances")
	renderer.clear()
	_check(renderer.get_stats().instances == 0 and host.get_child_count() == 0, "clear releases all visual batches")
	var occupied_building := ChunkBuildData.new(Vector2i(3,0),4)
	occupied_building.add_blocker(Vector2i.ZERO,WorldBlockerGeometry.Kind.WALL,10,ChunkBlockVisualCatalog.VARIANT_BUILDING_ENVELOPE)
	renderer.add_chunk(occupied_building)
	for batch: ChunkBlockRenderer.TextureBatch in renderer.get("_batches").values():
		_check(batch.texture == ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL,10),"renderer carries intact-building state through texture selection at a ruin-pier coordinate")
	renderer.clear()
	_check_prop_casts(renderer)
	host.queue_free()
	print("ChunkBlockRendererTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## Procedural city (S2+): a half-cover prop, painted three-quarter or legacy,
## casts one soft footprint from its base along the shared sun instead of a
## projected sprite silhouette; the authored Institution (S1) keeps its own.
func _check_prop_casts(renderer: ChunkBlockRenderer) -> void:
	var previous_segment := Global.attempt_segment
	DEPTH.reset_light()
	var direction := DEPTH.SHADOW_DIRECTION.normalized()
	var base := Vector2(5 * 256, 0) + Vector2(1.5, 1.5) * 64.0 - Vector2(0.0, ChunkBlockRenderer.PROP_BASE_LIFT)
	for variant: int in [0, 4, 7]:
		Global.attempt_segment = 2
		var data := ChunkBuildData.new(Vector2i(5, 0), 4)
		data.add_blocker(Vector2i(1, 1), WorldBlockerGeometry.Kind.HALF_COVER, 0, variant)
		renderer.add_chunk(data)
		var batches: Dictionary = renderer.get("_batches")
		var cast := batches.get(ChunkBlockRenderer.PROP_CAST_KEY) as ChunkBlockRenderer.TextureBatch
		_check(cast != null and cast.transforms.size() == 1, "city prop %d casts exactly one footprint" % variant)
		if cast != null and cast.transforms.size() == 1:
			var size: Vector2 = ChunkBlockRenderer.PROP_CASTS[variant]
			var length := size.x * DEPTH.BUILDING_SHADOW_K * DEPTH.length_scale
			var transform: Transform2D = cast.transforms[0]
			var half := float(cast.texture.get_width()) * 0.5
			var near := transform * Vector2(-half, 0.0)
			var far := transform * Vector2(half, 0.0)
			_check(transform.x.normalized().is_equal_approx(direction), "city prop %d casts along the shared sun direction" % variant)
			_check(near.distance_to(base) < 0.01, "city prop %d's cast starts on its footprint, neither detached below it nor poking out on the lit side" % variant)
			_check(absf((far - base).dot(direction) - (length + size.y * 0.5)) < 0.01, "city prop %d's cast is as long as the buildings' rule for its height" % variant)
			_check(cast.visual.material == DEPTH.SUN_SHADOW_MATERIAL and cast.visual.z_index == DEPTH.GROUND_SHADE_Z and not cast.visual.z_as_relative and not cast.shadow.visible, "city prop %d's cast multiplies the ground shade layer under the shared sun" % variant)
		var prop := batches.get(ChunkBlockRenderer._texture_key(ChunkBlockVisualCatalog.half_texture(variant))) as ChunkBlockRenderer.TextureBatch
		_check(prop != null and prop.shadow_transforms.size() == 1 and is_zero_approx(prop.shadow_transforms[0].determinant()), "city prop %d no longer projects its sprite silhouette" % variant)
		renderer.clear()
		Global.attempt_segment = 1
		renderer.add_chunk(data)
		_check(not (renderer.get("_batches") as Dictionary).has(ChunkBlockRenderer.PROP_CAST_KEY), "the authored Institution's prop %d keeps its reviewed silhouette, without a footprint cast" % variant)
		renderer.clear()
	Global.attempt_segment = previous_segment
