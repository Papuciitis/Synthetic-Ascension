extends Node

## Times raw chunk activation over a large area, where the blocker batch upload
## actually scales. The shipped audit runs radius 2 (25 chunks), which is too
## few for a quadratic to show above run-to-run noise.

const COVER_FULL: PackedScene = preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW: PackedScene = preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF: PackedScene = preload("res://scenes/world/cover/CoverHalf.tscn")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var manager: Node2D = load("res://core/systems/world/ChunkManager.gd").new()
	manager.world_seed = 251337
	manager.tiled_world_rendering = false
	manager.debug_draw_chunk_outlines = false
	manager.decals_enabled = true
	manager.deco_enabled = true
	manager.sites_enabled = true
	manager.cover_full_scene = COVER_FULL
	manager.cover_window_scene = COVER_WINDOW
	manager.cover_half_scene = COVER_HALF
	add_child(manager)
	await get_tree().process_frame

	var side: int = 11   # 121 chunks
	var half: int = side / 2
	var start := Time.get_ticks_usec()
	for y in range(-half, half + 1):
		for x in range(-half, half + 1):
			manager.call("_create_chunk", Vector2i(x, y))
	var elapsed_ms := float(Time.get_ticks_usec() - start) / 1000.0
	print("BENCH chunks=%d total_ms=%.1f per_chunk_ms=%.3f" % [side * side, elapsed_ms, elapsed_ms / float(side * side)])
	get_tree().quit(0)
