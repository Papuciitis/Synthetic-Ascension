extends Node

## The authored level must be the same place every time it loads.
##
## Interior dressing and exploration caches are generated, not hand-placed, so a
## non-seeded RNG anywhere in that path would quietly make Segment 1 different
## on every load - which is the one thing an AUTHORED level must never be.
## Prints a fingerprint of the generated geometry; run twice and compare.

var _is_worker: bool = false


func _ready() -> void:
	if _is_worker:
		get_tree().create_timer(120.0).timeout.connect(func() -> void:
			push_error("Level1DeterminismProbe timed out")
			get_tree().quit(1)
		)
		_run.call_deferred()
		return
	var worker := Node.new()
	worker.name = "Level1DeterminismWorker"
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	worker.set_script(get_script())
	worker.set("_is_worker", true)
	get_tree().root.add_child.call_deferred(worker)


func _run() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 1
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.debug_dev_mode = true
	# Pin the run seed. Cache POSITIONS are authored and must never move; the
	# loot inside them is rolled against the world seed and is supposed to vary,
	# so without pinning this the two things are indistinguishable.
	Global.attempt_world_seed = 424242
	Global.goto_game()
	var builder: Node = null
	for _wait in range(400):
		await get_tree().process_frame
		builder = _find_builder(get_tree().root)
		if builder != null:
			break
	if builder == null:
		push_error("FAIL: no Level1Builder")
		get_tree().quit(1)
		return

	# ExplorationLootSpawner waits for Global.item_db before dropping.
	for _settle in range(240):
		await get_tree().process_frame

	var half_cells: Dictionary = builder.get("_half_cells")
	var keys: Array = half_cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	var cover_fingerprint: String = ""
	for key in keys:
		var cell: Vector2i = key
		cover_fingerprint += "%d,%d;" % [cell.x, cell.y]

	# The spawners free themselves the moment they have dropped, so fingerprint
	# what they LEFT rather than the spawners themselves.
	var caches: Array[Vector2] = []
	_collect_pickups(get_tree().root, caches)
	caches.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.y < b.y or (is_equal_approx(a.y, b.y) and a.x < b.x))
	var cache_fingerprint: String = ""
	for at in caches:
		cache_fingerprint += "%d,%d;" % [int(at.x), int(at.y)]

	print("LEVEL1 cover_cells=%d cover_hash=%d" % [keys.size(), hash(cover_fingerprint)])
	print("LEVEL1 caches=%d cache_hash=%d" % [caches.size(), hash(cache_fingerprint)])
	get_tree().quit(0)


func _collect_pickups(node: Node, out: Array[Vector2]) -> void:
	if node is ItemPickup:
		out.append((node as Node2D).global_position)
	for child in node.get_children():
		_collect_pickups(child, out)


func _find_builder(node: Node) -> Node:
	var script: Variant = node.get_script()
	if script != null and String(script.resource_path).ends_with("Level1Builder.gd"):
		return node
	for child in node.get_children():
		var found := _find_builder(child)
		if found != null:
			return found
	return null
