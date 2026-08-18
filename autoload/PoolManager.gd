extends Node

# Simple node pooling for high-churn gameplay objects (bullets, missiles, VFX).
# Keeps visuals/feel identical while cutting instantiate()/queue_free() spikes.

var _pools: Dictionary = {} # String (scene path) -> Array[Node]
var _limits: Dictionary = {} # String -> maximum retained nodes; absent means unbounded
var _reuse_hits: int = 0
var _releases: int = 0
var _discarded: int = 0
var _additive_material: CanvasItemMaterial = null


func _scene_key(scene: PackedScene) -> String:
	if scene == null:
		return ""
	return scene.resource_path if scene.resource_path != "" else str(scene.get_instance_id())

func _get_pool(key: String) -> Array:
	# Dictionary.get() returns Nil when missing; avoid assigning Nil to a typed Array.
	var p = _pools.get(key)
	if p is Array:
		return p
	var arr: Array = []
	_pools[key] = arr
	return arr

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_material()

func _ensure_material() -> void:
	if _additive_material != null:
		return
	_additive_material = CanvasItemMaterial.new()
	_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

func get_additive_material() -> CanvasItemMaterial:
	_ensure_material()
	return _additive_material

func obtain(scene: PackedScene, parent: Node = null) -> Node:
	if scene == null:
		return null
	var key := _scene_key(scene)

	var pool: Array = _get_pool(key)
	var node: Node = null
	while not pool.is_empty():
		# A late queue_free() can run after recycle and leave a freed Object Variant
		# in this array. Validate the raw value before any typed cast.
		var candidate: Variant = pool.pop_back()
		if not is_instance_valid(candidate):
			_discarded += 1
			continue
		node = candidate as Node
		if node != null and not node.is_queued_for_deletion():
			_reuse_hits += 1
			break
		_discarded += 1
		node = null
	if node == null:
		node = scene.instantiate()

	if node == null:
		return null

	node.set_meta("__pool_key", key)
	node.set_meta("__in_pool", false)

	# Attach first (some scripts expect to be in-tree during reset)
	var target_parent: Node = null
	if parent != null and is_instance_valid(parent):
		target_parent = parent
	else:
		var cs := get_tree().current_scene
		target_parent = cs if cs != null else self

	# Nodes pulled from the pool are usually still parented under PoolManager.
	# Detach before attaching to the requested parent/current scene.
	if node.get_parent() != target_parent:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		target_parent.add_child(node)
		
	# Re-enable after attach
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node.has_method("set_process"):
		node.set_process(true)
	if node.has_method("set_physics_process"):
		node.set_physics_process(true)
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	if "monitoring" in node:
		node.set("monitoring", true)
	if "monitorable" in node:
		node.set("monitorable", true)

	if node.has_method("_on_pool_obtain"):
		node.call("_on_pool_obtain")

	return node

func recycle(node: Node) -> void:
	if node == null:
		return
	if not is_instance_valid(node):
		return
	if node.is_queued_for_deletion():
		return

	var key: String = ""
	if node.has_meta("__pool_key"):
		key = str(node.get_meta("__pool_key"))

	if key == "":
		node.queue_free()
		return
	if bool(node.get_meta("__in_pool", false)):
		return

	# custom hook first (so scripts can reset internal state while still in tree)
	if node.has_method("_on_pool_recycle"):
		node.call("_on_pool_recycle")

	var pool: Array = _get_pool(key)
	var limit := int(_limits.get(key, -1))
	if limit >= 0 and pool.size() >= limit:
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is CanvasItem:
			(node as CanvasItem).visible = false
		_discarded += 1
		node.queue_free()
		return

	# detach
	if node.get_parent() != null:
		node.get_parent().remove_child(node)

	# disable
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node.has_method("set_process"):
		node.set_process(false)
	if node.has_method("set_physics_process"):
		node.set_physics_process(false)
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	if "monitoring" in node:
		node.set("monitoring", false)
	if "monitorable" in node:
		node.set("monitorable", false)

	# keep pooled nodes under PoolManager (so they stay alive & valid)
	add_child(node)
	node.set_meta("__in_pool", true)
	pool.append(node)
	_releases += 1

func warm(scene: PackedScene, count: int) -> void:
	if scene == null or count <= 0:
		return
	var key := _scene_key(scene)
	var pool: Array = _get_pool(key)
	var limit := int(_limits.get(key, -1))
	var target := mini(count, limit) if limit >= 0 else count
	while pool.size() < target:
		var n: Node = scene.instantiate()
		if n == null:
			break
		n.set_meta("__pool_key", key)
		n.process_mode = Node.PROCESS_MODE_DISABLED
		if n is CanvasItem:
			(n as CanvasItem).visible = false
		add_child(n)
		n.set_meta("__in_pool", true)
		pool.append(n)


func set_limit_for_scene(scene: PackedScene, limit: int) -> void:
	var key := _scene_key(scene)
	if key == "":
		return
	_limits[key] = maxi(0, limit)
	var pool := _get_pool(key)
	while pool.size() > int(_limits[key]):
		var node := pool.pop_back() as Node
		if node != null and is_instance_valid(node):
			_discarded += 1
			node.queue_free()


func pool_size_for_scene(scene: PackedScene) -> int:
	var key := _scene_key(scene)
	if key == "":
		return 0
	return _get_pool(key).size()


func get_debug_counters() -> Dictionary:
	var inactive := 0
	for pool_variant in _pools.values():
		if pool_variant is Array:
			inactive += (pool_variant as Array).size()
	return {
		"reuse_hits": _reuse_hits,
		"releases": _releases,
		"inactive": inactive,
		"discarded": _discarded,
	}
