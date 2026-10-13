extends Node

const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
const DISTRICT := preload("res://core/systems/world/proc/chunkgen/ChunkGenDistrict.gd")
const CPC := 32
var failures: Array[String] = []
var chunks := 0
var doors := 0
var rewards := 0

func _ready() -> void:
	call_deferred("_run")

func _fixture(seed_value: int, coord: Vector2i, mask: int, role: StringName, parcels: bool) -> Dictionary:
	var manager := ChunkManager.new()
	manager.world_seed = seed_value
	manager.generation_enabled = false
	manager.ground_enabled = false
	manager.ground_splat_enabled = false
	manager.decals_enabled = false
	manager.deco_enabled = false
	manager.sites_enabled = false
	manager.parcels_enabled = parcels
	manager.parcels_chunk_chance = 1.0
	manager.donjon_strength = 1.0
	manager.cover_full_scene = COVER_FULL
	manager.cover_window_scene = COVER_WINDOW
	manager.cover_half_scene = COVER_HALF
	manager._site_mgr = SiteManager.new()
	add_child(manager)
	manager._chunk_connectors[coord] = mask
	manager._chunk_role[coord] = role
	manager._chunk_archetype[coord] = &"gate" if role == &"checkpoint" else &"district"
	manager._gen_coord = coord
	manager._chunk_blocked[coord] = []
	var data := ChunkBuildData.new(coord, CPC)
	manager._active_build_data = data
	var chunk := Node2D.new()
	chunk.position = Vector2(coord) * manager.chunk_size_px
	manager.add_child(chunk)
	manager._generate_chunk(coord, chunk)
	return {"manager": manager, "chunk": chunk, "data": data}

func _reachable(data: ChunkBuildData, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	if data.kind_at(start) >= 0:
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for dir in ChunkShapeGen.DIRS_4:
			var cell := at + dir
			if cell.x < 0 or cell.y < 0 or cell.x >= CPC or cell.y >= CPC or seen.has(cell) or data.kind_at(cell) >= 0:
				continue
			seen[cell] = true
			queue.append(cell)
	return seen

func _run() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	for seed_index in range(64):
		var seed_value := 251337 + seed_index * 48271
		var coord := Vector2i(seed_index % 3 - 1, seed_index % 5 - 2)
		for mask in range(1, 16):
			for role in [&"main_route", &"checkpoint", &"secondary_alley_cache", &"secondary_reward_building"]:
				var tag := "seed=%d coord=%s mask=%d role=%s" % [seed_value, coord, mask, role]
				var fixture := _fixture(seed_value, coord, mask, role, role == &"secondary_reward_building")
				var manager: ChunkManager = fixture.manager
				var chunk: Node2D = fixture.chunk
				var data: ChunkBuildData = fixture.data
				var gen: ChunkGenImpl = manager._content_gen
				var cx: int = gen._lane_center_for_col(coord.x, CPC)
				var cy: int = gen._lane_center_for_row(coord.y, CPC)
				var sockets: Array[Vector2i] = []
				if mask & 1: sockets.append(Vector2i(cx, 0))
				if mask & 2: sockets.append(Vector2i(CPC - 1, cy))
				if mask & 4: sockets.append(Vector2i(cx, CPC - 1))
				if mask & 8: sockets.append(Vector2i(0, cy))
				var reachable := _reachable(data, sockets[0])
				for cell in chunk.get_meta(&"_proc_clear_cells", {}):
					if data.kind_at(cell) >= 0: failures.append(tag + " blocked protected route " + str(cell))
				for socket in sockets:
					if not reachable.has(socket): failures.append(tag + " disconnected connector " + str(socket))
				var secondary_interiors := 0
				for child in chunk.get_children():
					if child is Marker2D and child.get_meta("spawn_socket_kind", &"") == &"door":
						doors += 1
						var cell := Vector2i((child as Node2D).position / manager.cell_size_px)
						if not reachable.has(cell): failures.append(tag + " unreachable door " + str(cell))
					if child is IndoorVolume:
						var volume: IndoorVolume = child
						if volume.secondary_objective_id > 0: secondary_interiors += 1
						var local := volume.cell_tl - coord * CPC
						var has_reachable_floor := false
						for y in range(local.y, local.y + volume.size_cells.y):
							for x in range(local.x, local.x + volume.size_cells.x):
								if reachable.has(Vector2i(x, y)): has_reachable_floor = true
						if not has_reachable_floor: failures.append(tag + " sealed interior " + str(local))
					if child is Node2D and child.get_script() != null and child.get_script().resource_path.ends_with("ExplorationLootSpawner.gd"):
						rewards += 1
						var cell := Vector2i((child as Node2D).position / manager.cell_size_px)
						if not reachable.has(cell): failures.append(tag + " unreachable reward " + str(cell) + " blocker_kind=" + str(data.kind_at(cell)))
				if role == &"secondary_reward_building" and secondary_interiors != 1:
					failures.append(tag + " needs one searchable objective interior, got " + str(secondary_interiors))
				chunks += 1
				manager.free()
	for entry in failures.slice(0, 24):
		push_error(entry)
	print("ProcChunkReachabilityTest: %d chunks, %d doors, %d rewards, %d failures" % [chunks, doors, rewards, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
