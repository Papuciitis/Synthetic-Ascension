extends Node

# Phase 3 (handoff 2026-09-25 §9): irregular parcel buildings on the real
# procedural path. An L-footprint building generates with agreeing floor,
# perimeter walls, collision, indoor volumes and a polygon roof; its open
# hall stays reachable through the door; generation is repeatable for a
# fixed seed; and the shallow-depth pass emits south faces beside the caps.
#
# Run: <godot> --headless --path . res://tools/tests/WorldFootprintTest.tscn

const SEED := 424242

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _configured_manager() -> ChunkManager:
	var manager := ChunkManager.new()
	manager.world_seed = SEED
	manager.ground_enabled = false
	manager.decals_enabled = false
	manager.deco_enabled = false
	manager.sites_enabled = true
	manager.batched_chunk_blockers = true
	manager.debug_draw_chunk_outlines = false
	manager.debug_show_blocks = false
	manager.tiled_world_rendering = false
	if "parcels_enabled" in manager:
		manager.set("parcels_enabled", true)
	if "parcels_chunk_chance" in manager:
		manager.set("parcels_chunk_chance", 1.0)
	var dummy_player := Node2D.new()
	dummy_player.add_to_group(&"player")
	add_child(dummy_player)
	manager.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn") as PackedScene
	manager.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn") as PackedScene
	manager.cover_half_scene = load("res://scenes/world/cover/CoverHalf.tscn") as PackedScene
	# A straight east-west secondary road through every probed chunk.
	var connectors: Dictionary = {}
	var roles: Dictionary = {}
	var archetypes: Dictionary = {}
	for x in range(0, 8):
		var coord := Vector2i(x, 0)
		connectors[coord] = 2 | 8
		roles[coord] = &"secondary"
		archetypes[coord] = &"street"
	manager.configure_procedural_world(SEED, connectors, {}, roles, {}, archetypes)
	add_child(manager)
	return manager


func _find_l_building(manager: ChunkManager) -> Dictionary:
	for x in range(0, 8):
		var coord := Vector2i(x, 0)
		var chunk := manager.call("_create_chunk", coord) as Node2D
		if chunk == null:
			continue
		for roof in chunk.find_children("*", "Node2D", true, false):
			if roof is not RoofOverlay:
				continue
			var poly := (roof.get_node("RoofPoly") as Polygon2D).polygon
			if poly.size() >= 6:
				var volumes: Array = []
				for volume in chunk.find_children("*", "Area2D", true, false):
					if volume is IndoorVolume:
						volumes.append(volume)
				return {"coord": coord, "roof": roof, "poly": poly, "chunk": chunk, "volumes": volumes}
	return {}


func _run() -> void:
	var manager := _configured_manager()
	var found := _find_l_building(manager)
	_check(not found.is_empty(), "an L-footprint building generates on the real parcel path (seed %d)" % SEED)
	if found.is_empty():
		_finish()
		return
	var poly: PackedVector2Array = found["poly"]
	var coord: Vector2i = found["coord"]
	print("  found at chunk %s with %d roof corners" % [coord, poly.size()])

	# The roof outline is a closed orthogonal ring beyond a plain rectangle.
	var orthogonal := true
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if not (is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y)):
			orthogonal = false
	_check(orthogonal and poly.size() % 2 == 0, "the roof polygon is orthogonal and closed (%d corners)" % poly.size())

	# The building carries two indoor volumes under one identity; exactly one
	# owns the loot rights.
	var by_id: Dictionary = {}
	for volume_variant in found["volumes"]:
		var volume := volume_variant as IndoorVolume
		var id := int(volume.get("building_id"))
		if not by_id.has(id):
			by_id[id] = []
		(by_id[id] as Array).append(volume)
	var l_volumes: Array = []
	for id in by_id:
		if (by_id[id] as Array).size() >= 2:
			l_volumes = by_id[id]
	_check(l_volumes.size() == 2, "the L building has exactly two indoor volumes under one building id")
	if l_volumes.size() == 2:
		var loot_owners := 0
		for volume_variant in l_volumes:
			if float((volume_variant as IndoorVolume).get("small_loot_chance")) > 0.0:
				loot_owners += 1
		_check(loot_owners <= 1, "only one sub-volume owns loot rights (%d)" % loot_owners)

		# Walkability, boundaries and indoor state agree: a covered cell is
		# either open hall floor or the recess's back wall (the volume rects
		# are honest approximations, as VisionRig requires), and the open
		# hall dominates.
		var cpc := int(manager.call("_cells_per_chunk"))
		var blocked_map: Dictionary = manager.get("_blocked_cells")
		var walkable_cells: Array[Vector2i] = []
		var covered := 0
		var strangers := 0
		for volume_variant in l_volumes:
			var volume := volume_variant as IndoorVolume
			var tl := volume.get("cell_tl") as Vector2i
			var size := volume.get("size_cells") as Vector2i
			for y in range(tl.y, tl.y + size.y):
				for x in range(tl.x, tl.x + size.x):
					covered += 1
					var cell := Vector2i(x, y)
					if _walkable(manager, cell):
						walkable_cells.append(cell)
					else:
						strangers += 1
		var wall_covered := 0
		for volume_variant in l_volumes:
			var volume := volume_variant as IndoorVolume
			var tl := volume.get("cell_tl") as Vector2i
			var size := volume.get("size_cells") as Vector2i
			for y in range(tl.y, tl.y + size.y):
				for x in range(tl.x, tl.x + size.x):
					if blocked_map.has(Vector2i(x, y)):
						wall_covered += 1
		_check(strangers == wall_covered and covered > 0, "every covered cell is hall floor or a wall of this building (%d strangers, %d walls)" % [strangers - wall_covered, wall_covered])
		_check(walkable_cells.size() >= int(0.75 * covered), "the open hall dominates the volume coverage (%d/%d walkable)" % [walkable_cells.size(), covered])

		# The hall is reachable from the street through its doorway: flood
		# fill over walkable cells from a road cell must reach the interior.
		var lane_cell := Vector2i(coord.x * cpc + cpc / 2, coord.y * cpc + cpc / 2)
		var reached := not walkable_cells.is_empty() and _flood_reaches(manager, lane_cell, walkable_cells[walkable_cells.size() / 2], coord, cpc)
		_check(reached, "the interior is reachable from the street through the doorway")

	# Repeatability: the same seed and plan regenerate the same blockers.
	var blocked_first: Dictionary = (manager.get("_blocked_cells") as Dictionary).duplicate()
	var again := _configured_manager()
	again.call("_create_chunk", coord)
	var blocked_again: Dictionary = (again.get("_blocked_cells") as Dictionary)
	var repeatable := true
	for cell in blocked_again:
		if (cell as Vector2i).x / int(manager.call("_cells_per_chunk")) == coord.x:
			if not blocked_first.has(cell):
				repeatable = false
	_check(repeatable and not blocked_again.is_empty(), "a fixed seed regenerates the same blocker cells")
	again.queue_free()

	# The shallow-depth pass: south faces exist beside the caps, and the cap
	# and shadow instance counts still agree one-to-one.
	if manager.has_method("get_block_batch_stats"):
		var stats := manager.call("get_block_batch_stats") as Dictionary
		_check(int(stats.get("face_instances", 0)) > 0, "exposed south edges carry wall faces (%d)" % int(stats.get("face_instances", 0)))
		_check(int(stats.get("instances", 0)) == int(stats.get("shadow_instances", 0)), "caps and their ground shadows stay one-to-one")

	manager.queue_free()
	_finish()


## Walkability from the blocker maps directly: _create_chunk builds content
## without registering into the streaming set, so is_cell_walkable would
## report void for every probed cell.
func _walkable(manager: ChunkManager, cell: Vector2i) -> bool:
	return not (manager.get("_blocked_cells") as Dictionary).has(cell) \
		and not (manager.get("_manual_blocked_cells") as Dictionary).has(cell)


func _flood_reaches(manager: ChunkManager, from_cell: Vector2i, to_cell: Vector2i, coord: Vector2i, cpc: int) -> bool:
	var bounds := Rect2i(Vector2i(coord.x * cpc - cpc, coord.y * cpc - cpc), Vector2i(cpc * 3, cpc * 3))
	if not _walkable(manager, from_cell):
		# Nudge off the exact lane centre if a prop landed there.
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2)]:
			if _walkable(manager, from_cell + offset):
				from_cell += offset
				break
	var seen: Dictionary = {from_cell: true}
	var frontier: Array[Vector2i] = [from_cell]
	var guard := 0
	while not frontier.is_empty() and guard < 20000:
		guard += 1
		var current: Vector2i = frontier.pop_back()
		if current == to_cell:
			return true
		for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var next: Vector2i = current + offset
			if seen.has(next) or not bounds.has_point(next):
				continue
			if not _walkable(manager, next):
				continue
			seen[next] = true
			frontier.append(next)
	return false


func _finish() -> void:
	print("WorldFootprintTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
