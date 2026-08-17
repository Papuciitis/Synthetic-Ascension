extends Node

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
	host.queue_free()
	print("ChunkBlockRendererTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
